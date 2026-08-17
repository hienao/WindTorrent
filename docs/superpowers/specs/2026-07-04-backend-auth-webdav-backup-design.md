# Backend Auth and WebDAV Backup Design

Date: 2026-07-04
Status: Approved in conversation, written for review

## Summary

WindWalker currently uses Google Sign-In through Firebase Auth and has a hidden Google Drive backup flow. The next version will replace Google login with the WindWalker backend auth API and replace Google Drive backup with user-configured WebDAV backup.

The selected approach is a broader layered refactor. Auth, backup storage, backup business logic, and settings UI will be separated into explicit API, store, repository, and controller boundaries. This creates more implementation work than a direct replacement, but removes Google-specific coupling and gives future account, subscription, and sync work a cleaner base.

## Confirmed Decisions

- Login will use the backend API at `https://appapi.51cloud.de`.
- Registration will use email verification code plus password.
- Normal login will use email plus password.
- The app will not use Google Sign-In for user auth.
- `X-App-Id` and `X-App-Key` will be Dart code constants for this implementation.
- WebDAV will be user-configured. Users provide WebDAV URL, username, and password or app token.
- Backup supports export, restore, automatic retention cleanup, and manual deletion.
- Automatic retention keeps the newest two backup versions after a successful upload.
- Manual deletion can delete any listed version, including the newest version, after confirmation.
- Firebase Analytics may remain. Firebase Auth and Google Sign-In should be removed if no remaining code needs them.

## Goals

- Replace Google/Firebase Auth with the WindWalker backend auth API.
- Provide email-code registration and password login.
- Persist and refresh backend access and refresh tokens.
- Restore the settings backup UI using WebDAV instead of Google Drive.
- Preserve the existing downloader backup JSON format where possible.
- Keep restore behavior safe: parse first, create rollback snapshot, then atomically replace local downloader configs.
- Keep analytics privacy-safe by never logging email, password, verification code, token, host, username, or downloader credentials.
- Make the new layers independently testable.

## Non-Goals

- No Google Sign-In compatibility mode.
- No Google Drive backup compatibility or migration in this implementation.
- No built-in hosted WebDAV from the WindWalker backend.
- No end-to-end encryption for backup files beyond the security provided by the user's WebDAV server.
- No backup of task history, runtime task state, theme, language, or app settings beyond downloader configuration.
- No manual conflict merge when restoring a backup. Restore remains full replacement.

## OpenAPI Usage

The backend auth API requires `X-App-Id` and `X-App-Key` for unauthenticated auth actions. These values will be provided from app constants in this implementation.

Used endpoints:

- `POST /api/auth/email/send-code`
  - Headers: `X-App-Id`, `X-App-Key`
  - Body: `{ "email": "...", "scene": "REGISTER" }`
  - Expected success: `204`

- `POST /api/auth/register`
  - Headers: `X-App-Id`, `X-App-Key`
  - Body: `{ "email": "...", "code": "...", "password": "...", "name": "..." }`
  - Expected success: `200 AuthTokenResponse`

- `POST /api/auth/login/password`
  - Headers: `X-App-Id`, `X-App-Key`
  - Body: `{ "email": "...", "password": "..." }`
  - Expected success: `200 AuthTokenResponse`

- `POST /api/auth/token/refresh`
  - Header: `X-App-Id`
  - Body: `{ "refresh_token": "..." }`
  - Expected success: `200 AuthTokenResponse`

- `GET /api/auth/me`
  - Header: `Authorization: Bearer <accessToken>`
  - Expected success: `200 UserInfoResponse`

- `POST /api/auth/logout`
  - Header: `Authorization: Bearer <accessToken>`
  - Expected success: `204`

## Architecture

### Auth Domain

Create a backend-oriented auth data layer under `lib/features/auth/data/`:

- `AppBackendAuthApi`
  - Owns HTTP calls to the OpenAPI auth endpoints.
  - Adds app headers and bearer headers.
  - Converts HTTP statuses and `ApiErrorResponse.code` into typed auth exceptions.
  - Does not read or write local storage.

- `AuthTokenStore`
  - Owns local persistence for `accessToken`, `refreshToken`, `sessionId`, and cached user info.
  - Uses `GetStorage` for this implementation, matching the current project storage pattern.
  - Exposes explicit read, save, and clear methods.

- `BackendAuthRepository`
  - Coordinates API and token store.
  - Supports send register code, register, password login, refresh, current user, and logout.
  - Handles 401 during session validation by refreshing once and retrying `/me`.
  - Clears the local session when refresh fails.

- `AuthController`
  - Remains the UI-facing `ChangeNotifier`.
  - No longer knows about Google, Firebase Auth, OAuth scopes, or Drive permissions.
  - Exposes state for login, register, send-code, startup session restoration, error messages, and current user.

The current `AuthProvider` abstraction should be removed. `AuthController` will depend on `BackendAuthRepository`, and tests will inject fake repositories. `AuthUser` must be detached from Firebase types.

### Backup Domain

Introduce a storage abstraction under `lib/features/backup/data/` and move WebDAV details below it:

- `BackupStorageApi`
  - `Future<List<DownloaderBackupVersion>> listVersions()`
  - `Future<void> uploadBackup(DownloaderBackupBundle bundle)`
  - `Future<List<int>> downloadBackup(String versionId)`
  - `Future<void> deleteBackup(String versionId)`

- `WebDavBackupStorageApi`
  - Implements `BackupStorageApi`.
  - Owns WebDAV HTTP behavior: `PROPFIND`, `MKCOL`, `PUT`, `GET`, `DELETE`.
  - Builds Basic Auth headers from user WebDAV credentials.
  - Ensures the configured backup directory exists before upload.
  - Filters files by `windwalker_downloaders_backup_*.json`.

- `WebDavConfigStore`
  - Persists WebDAV root URL, optional remote directory, username, and password or app token.
  - Uses `GetStorage` in this implementation.
  - Never exposes the saved password in normal display text.

- `DownloaderBackupRepository`
  - Replaces the current Google-specific orchestration dependency.
  - Builds `DownloaderBackupBundle`.
  - Parses downloaded backup JSON.
  - Runs upload, restore, automatic cleanup, and manual delete.
  - Delegates local downloader replacement and rollback to `DownloaderController`.

- `SettingsBackupController`
  - Remains the settings UI state machine.
  - Tracks export, restore, list, test connection, and delete states.
  - Distinguishes backup upload success from automatic cleanup failure.

## Auth Data Flow

### Startup

1. `AuthController` asks `BackendAuthRepository` for a cached session.
2. If cached user data exists, the UI may show signed-in state immediately.
3. The repository calls `/api/auth/me` with the cached access token.
4. If `/me` succeeds, the cached user is updated from the server response.
5. If `/me` returns 401, the repository calls `/api/auth/token/refresh`.
6. If refresh succeeds, the repository saves the rotated tokens and retries `/me`.
7. If refresh fails, the repository clears tokens and the controller becomes signed out.

### Login

1. User enters email and password.
2. `AuthController.loginWithPassword` validates non-empty input and calls the repository.
3. Repository calls `/api/auth/login/password`.
4. On success, tokens and user cache are saved.
5. Controller updates `AppUser` and clears error state.

### Registration

1. User switches to register mode.
2. User enters email and taps send code.
3. Repository calls `/api/auth/email/send-code` with scene `REGISTER`.
4. UI starts a resend countdown after success.
5. User enters verification code, password, confirm password, and optional nickname.
6. Repository calls `/api/auth/register`.
7. On success, tokens and user cache are saved and the user is signed in.

### Logout

1. Controller calls repository logout.
2. Repository calls `/api/auth/logout`.
3. On `204`, local tokens are cleared.
4. On `401`, local tokens are also cleared because the session is already invalid.
5. Other errors are surfaced to the UI and logged.

## Auth Error Model

Use typed errors instead of string matching in controllers:

- `invalidCredentials`
- `invalidCode`
- `emailAlreadyRegistered`
- `rateLimited`
- `sessionExpired`
- `network`
- `server`
- `unknown`

Controllers map typed errors to localized UI messages.

## WebDAV Data Flow

### Configuration

Settings provides a dedicated WebDAV configuration page:

- WebDAV root URL, for example `https://example.com/dav/`
- Remote directory, default `WindWalker/Backups`
- Username
- Password or app token
- Test connection action
- Save action

Testing connection should verify credentials and directory access using `PROPFIND`. If the configured backup directory does not exist, the test action creates it with `MKCOL` and then verifies it with a second `PROPFIND`. Upload also ensures the directory exists, so saving a valid config does not depend on the user running the test first.

### Listing Versions

1. `WebDavBackupStorageApi` sends `PROPFIND` with `Depth: 1` to the configured backup directory.
2. It parses XML multistatus responses.
3. It filters backup files by prefix and `.json` suffix.
4. It sorts versions by timestamp descending.
5. It marks the newest version as `isLatest`.
6. For each matching backup file, the implementation downloads the JSON and parses `backupId`, `appVersion`, `createdAt`, and `downloaderCount`. This keeps the restore picker accurate across WebDAV servers, which do not provide custom app metadata consistently. If a matching backup file cannot be parsed, listing fails with `parseFailed` so the user sees that the remote backup directory contains an invalid WindWalker backup file.

### Export

1. Repository builds `DownloaderBackupBundle` from current downloaders, app version, and current backend user ID.
2. `WebDavBackupStorageApi` ensures the remote directory exists.
3. It uploads the JSON with `PUT`.
4. Repository lists versions again.
5. Repository automatically deletes versions beyond the newest two.
6. If upload succeeds but automatic cleanup fails, the export result is a partial success with a visible cleanup warning.

### Restore

1. User selects a backup version.
2. UI shows a confirmation dialog explaining full replacement and rollback.
3. Repository downloads the selected JSON with `GET`.
4. Repository parses and validates the bundle.
5. `DownloaderController` creates a local rollback snapshot.
6. `DownloaderController` atomically replaces all downloader configs.
7. UI offers undo last restore when a rollback snapshot exists.

### Manual Delete

1. User taps delete for a listed backup version.
2. UI shows a confirmation dialog explaining deletion is irreversible.
3. Repository calls `deleteBackup`.
4. UI refreshes the version list after success.
5. Manual delete is allowed for any version, including the latest version.

## Backup Retention

Automatic retention keeps the newest two versions after successful upload.

The cleanup algorithm:

1. List versions after upload.
2. Sort by `createdAt` descending.
3. Keep the first two.
4. Delete the rest.

Manual deletion is independent of retention. If the user manually deletes all backups, the app should show the empty state on the next list refresh.

## Backup File Format

The existing `DownloaderBackupBundle` schema remains compatible where possible:

```json
{
  "schemaVersion": 1,
  "backupId": "2026-07-04T12:30:15Z_12345",
  "createdAt": "2026-07-04T12:30:15Z",
  "appVersion": "1.1.1+2026062702",
  "user": {
    "uid": "backend-user-id"
  },
  "downloaders": []
}
```

Only downloader configuration is backed up. Runtime status, speeds, task counts, and task details are excluded.

Backup filenames use sortable UTC timestamps:

`windwalker_downloaders_backup_2026-07-04T12-30-15Z.json`

## WebDAV Error Model

Use typed WebDAV or backup errors:

- `notConfigured`
- `unauthorized`
- `forbidden`
- `notFound`
- `directoryCreateFailed`
- `uploadFailed`
- `downloadFailed`
- `deleteFailed`
- `parseFailed`
- `network`
- `server`

Controllers map these errors to localized messages. Sensitive request details and credentials must not appear in logs or analytics.

## UI Design

### Login Page

Default mode is password login:

- Email field
- Password field
- Login button
- Segmented control to switch to registration

Registration mode:

- Email field
- Send verification code button with loading and resend countdown
- Verification code field
- Password field
- Confirm password field
- Optional nickname field
- Register button
- Segmented control back to login

The page should continue using existing neumorphic components and route behavior. On success, it returns to the previous page when possible or navigates home.

### Profile and Settings

Profile and settings should show backend user identity:

- Email
- Nickname if present
- Sign out action when authenticated

Settings restores the Backup & Restore section:

- If not signed in: prompt user to sign in.
- If signed in but WebDAV is not configured: prompt user to configure WebDAV.
- If signed in and WebDAV is configured: show backup, restore, and configuration actions.

Restore version picker:

- Shows available versions sorted newest first.
- Shows created time, downloader count when available, and app version when available.
- Offers restore action.
- Offers delete action per version.

Restore and delete both require confirmation dialogs.

### WebDAV Configuration UI

Provide a dedicated page with route `/settings/webdav` and the following fields:

- URL field
- Remote directory field
- Username field
- Password or token field
- Show/hide password toggle
- Test connection button
- Save button

The saved password should not be displayed as plaintext after saving.

## Localization

Update English, Chinese, and Japanese strings. Remove Google-specific auth and backup labels where they no longer apply:

- `signInWithGoogle` becomes backend-neutral login/register strings.
- `backupToGoogleDrive` becomes WebDAV backup wording.
- `restoreFromGoogleDrive` becomes WebDAV restore wording.
- `signInToUseBackup` no longer mentions Google.

Generated localization files should be regenerated through the project Flutter l10n workflow during implementation.

## Analytics

Rename Google-specific auth events:

- `auth_login_result`
- `auth_register_result`
- `auth_send_code_result`
- `auth_logout_result`
- `downloader_backup_export_result`
- `downloader_backup_import_result`
- `downloader_backup_delete_result`
- `webdav_config_test_result`

Do not include email, password, verification code, access token, refresh token, WebDAV URL, WebDAV username, WebDAV password, downloader host, downloader username, downloader password, or downloader secret in analytics parameters.

## Dependency and Cleanup Plan

Remove during this implementation:

- `firebase_auth`
- `google_sign_in`
- `FirebaseAuthProvider`
- `GoogleDriveBackupApi`
- `DriveAuthException`
- Google Drive scope methods from auth abstractions

Keep if analytics still uses it:

- `firebase_core`
- `firebase_analytics`

`main.dart` should no longer initialize Firebase Auth language if Firebase Auth is removed.

## Testing Strategy

### Unit Tests

- `AppBackendAuthApi`
  - send-code success and rate limit
  - register success, invalid code, duplicate email
  - password login success and invalid credentials
  - refresh success and expired refresh token
  - `/me` success and unauthorized
  - logout success and unauthorized

- `AuthTokenStore`
  - save, read, overwrite, and clear tokens
  - save and read cached user

- `BackendAuthRepository`
  - startup `/me` success
  - 401 then refresh then retry `/me`
  - refresh failure clears session
  - logout clears session on 204 and 401

- `AuthController`
  - login state transitions
  - registration state transitions
  - send-code countdown state
  - startup cached session restoration
  - error mapping

- `WebDavBackupStorageApi`
  - `PROPFIND` XML parsing
  - backup file filtering
  - directory creation with `MKCOL`
  - `PUT`, `GET`, and `DELETE` success
  - 401, 403, 404, 5xx, and network exception mapping

- `DownloaderBackupRepository`
  - export uploads valid bundle
  - automatic retention deletes versions beyond newest two
  - upload success plus cleanup failure returns partial success
  - restore parses bundle and replaces through `DownloaderController`
  - parse failure leaves current config untouched
  - manual delete calls storage and tracks result

- `SettingsBackupController`
  - not configured state
  - list, export, restore, delete state transitions
  - partial cleanup warning state

### Widget Tests

- Login page default password-login mode.
- Registration mode toggle and fields.
- Send-code button loading/countdown behavior.
- Settings backup section for signed-out, unconfigured, and configured states.
- WebDAV config form validation and password visibility toggle.
- Restore picker shows versions and confirm restore.
- Delete version confirmation and refresh behavior.

## Migration Notes

Existing Google Drive backups will not be migrated. Because the Drive backup UI is currently hidden, the new WebDAV UI can launch without presenting a migration path. If a future migration is needed, it should be a separate design because it would require users to reauthorize Google Drive solely to export old backups.

Existing local downloader configurations remain untouched. Only auth session storage keys and backup storage behavior change.

## Risks

- Storing backend tokens and WebDAV passwords in `GetStorage` is convenient but less secure than platform secure storage. This is accepted for this implementation to match the current project storage pattern, but should be revisited.
- WebDAV server behavior varies. Some servers may have incomplete `PROPFIND` metadata or strict path handling. The implementation should normalize paths and keep XML parsing tested.
- App constants for `X-App-Key` are visible in the client binary. This is accepted by the selected decision, but the backend should still rate-limit and treat app keys as app identification, not as a high-trust secret.
- Removing Firebase Auth while keeping Firebase Analytics requires careful dependency cleanup so startup still initializes the analytics stack correctly.
