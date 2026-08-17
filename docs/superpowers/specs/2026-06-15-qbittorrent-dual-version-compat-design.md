# qBittorrent 4.x / 5.x Dual-Version Compatibility Design

Date: 2026-06-15
Status: Approved for spec review
Scope: WindWalker qBittorrent integration

## Summary

WindWalker currently treats qBittorrent `5.0+` as the only supported server generation and rejects `4.x` during connection testing, even though most existing WebUI API calls already use endpoints shared by both generations. The main confirmed protocol split in the currently implemented feature set is torrent pause/resume naming:

- qBittorrent `4.1-v4.6.x`: `/api/v2/torrents/pause`, `/api/v2/torrents/resume`
- qBittorrent `5.0+`: `/api/v2/torrents/stop`, `/api/v2/torrents/start`

The goal of this design is to make WindWalker automatically detect and transparently support both qBittorrent `4.x` and `5.x` without exposing version choices to the user.

This design covers the architecture for a complete dual-version WebUI API compatibility layer, while the first implementation phase will migrate the qBittorrent capabilities already present in WindWalker.

## Goals

- Support qBittorrent `4.1-v4.6.x` and `5.0+` from the same WindWalker UI flow
- Auto-detect the server version without requiring user input
- Fail fast when version detection is missing, malformed, or unsupported
- Keep version-specific logic out of controllers and UI
- Create an adapter structure that can scale beyond the currently implemented API surface

## Non-Goals

- Do not add a manual "select qBittorrent version" setting
- Do not guess a version by trying random endpoints after detection fails
- Do not implement the entire qBittorrent WebUI API in the first delivery
- Do not leak low-level API generation details into the user-facing model unless a later product need appears

## Current State

Current service behavior is centered in `lib/services/qbit_service.dart`.

- `testConnection()` logs in, reads `/api/v2/app/version`, and rejects any major version lower than `5`
- `pauseTask()` and `resumeTask()` already assume the `5.0+` endpoint names `stop` and `start`
- Most other currently used endpoints are common across `4.x` and `5.x`
- Session handling, request headers, logging, protocol mapping, and version enforcement all live in one service class

This makes the current implementation simple for one server generation, but it does not scale well to multi-version support because version branches would accumulate inside a single class.

## Constraints

- Follow the repository fail-fast policy
- Preserve the existing `DownloaderService`-style calling model for higher layers
- Keep `DownloaderController`, `TaskController`, and UI flows unaware of qBittorrent protocol generation
- Align with the current error model based on `ConnectionResult` and `DownloaderServiceException`

## Proposed Architecture

The qBittorrent integration will be split into five main parts:

1. `QBitServiceFacade`
2. `QBitSession`
3. `QBitVersionDetector`
4. `QBitServerProfile`
5. `QBitApiAdapter` with versioned implementations

### 1. QBitServiceFacade

`QBitServiceFacade` becomes the public qBittorrent service entry point used by the rest of the app. It preserves the current higher-level contract but delegates all protocol-specific work to a detected adapter.

Responsibilities:

- Lazily initialize the session and version profile
- Trigger detection on first connection test or first real qBittorrent operation
- Cache the resolved adapter for the lifetime of the service instance
- Delegate calls to the appropriate version adapter
- Reset its cached detection state when the downloader configuration changes

It must not contain version branches inside business operations beyond one-time adapter selection.

### 2. QBitSession

`QBitSession` centralizes shared transport concerns that are independent of qBittorrent generation.

Responsibilities:

- Manage the `SID` cookie
- Build shared headers such as `Referer` and `Cookie`
- Perform login
- Send authenticated HTTP requests
- Handle one-time re-login on `403`
- Convert network failures into `DownloaderServiceException`

This prevents `QBitV4Adapter` and `QBitV5Adapter` from duplicating session lifecycle logic.

### 3. QBitVersionDetector

`QBitVersionDetector` is responsible only for identifying the server generation and producing a stable profile.

Detection flow:

1. Login through `QBitSession`
2. Read `/api/v2/app/version`
3. Read `/api/v2/app/webapiVersion`
4. Parse and validate both values
5. Produce a `QBitServerProfile`

Detection rules:

- `app/version` major `4` => `QBitApiGeneration.v4Legacy`
- `app/version` major `5` or higher => `QBitApiGeneration.v5Modern`
- Missing endpoint, invalid payload, or malformed version string => fail fast
- Unknown major version policy is explicit:
  - if it is intentionally supported by code, map it
  - otherwise report unsupported

No endpoint probing fallback is allowed after detection failure.

### 4. QBitServerProfile

`QBitServerProfile` is a read-only description of the connected server.

Suggested fields:

- `appVersion`
- `webApiVersion`
- `apiGeneration`
- `rawAppVersion`
- `rawWebApiVersion`
- optional capability flags derived from generation

This object exists for routing, diagnostics, and testing. It is not primarily a user-facing model.

### 5. QBitApiAdapter

`QBitApiAdapter` defines the unified qBittorrent capability contract. Concrete implementations:

- `QBitV4Adapter`
- `QBitV5Adapter`

The adapter layer owns all protocol differences. Higher layers call semantic operations such as `pauseTorrents()` and `resumeTorrents()` without caring whether the underlying endpoint is `pause/resume` or `stop/start`.

## API Surface Organization

The adapter layer should not be a single unstructured interface with every API method mixed together. It should be grouped by WebUI API domains so the codebase can scale to broader API coverage.

Suggested domain interfaces:

- `QBitAuthApi`
- `QBitAppApi`
- `QBitTransferApi`
- `QBitTorrentApi`
- `QBitSyncApi`
- `QBitLogApi`
- `QBitRssApi`
- `QBitSearchApi`

`QBitApiAdapter` can either implement these interfaces directly or aggregate domain-specific helper objects internally. The important rule is that version differences remain isolated within the adapter layer.

### Shared vs Overridden Behavior

Many endpoints are currently common between `4.x` and `5.x`. To avoid duplication, a `BaseQBitApiAdapter` can provide shared implementations for endpoints whose path, parameters, and response semantics are the same.

Versioned adapters override only the operations that differ. Today the confirmed difference in implemented features is pause/resume naming, but the architecture must assume future divergence in:

- endpoint names
- request parameter names
- response field names
- response semantics
- capability availability

## Runtime Data Flow

The runtime flow should be deterministic and cached:

1. Create qBittorrent service instance
2. Create `QBitSession`
3. Keep version profile unresolved at construction time
4. On first `testConnection()` or first real operation, run `QBitVersionDetector.detect()`
5. Build `QBitServerProfile`
6. Resolve and cache one adapter instance from the profile
7. Route all later operations through the cached adapter
8. If downloader host, port, protocol, username, or password changes, drop the cached profile and adapter

Important behavior:

- Session expiration triggers re-login only
- Session expiration does not trigger re-detection
- Detection is tied to connection identity, not to every request

## Version Mapping Policy

The version policy must be explicit.

### Supported

- qBittorrent `4.1-v4.6.x`
- qBittorrent `5.0+`

### Unsupported

- Versions below `4.1`
- Versions with malformed `app/version` or missing detection data
- Any future major version that is not intentionally mapped and tested

If support for a future major version is desired later, it should be added through a deliberate profile rule and adapter review, not by accidental fallback.

## Known Endpoint Differences

### Pause / Resume

These operations must be normalized at the contract layer:

- v4 pause => `/api/v2/torrents/pause`
- v4 resume => `/api/v2/torrents/resume`
- v5 pause => `/api/v2/torrents/stop`
- v5 resume => `/api/v2/torrents/start`

Unified semantic operations remain:

- `pauseTorrents(hashes)`
- `resumeTorrents(hashes)`

### Currently Shared Endpoints Used By WindWalker

The following currently used endpoints appear compatible across the documented `4.x` and `5.x` surfaces, but should still remain inside adapter implementations:

- `/api/v2/auth/login`
- `/api/v2/app/version`
- `/api/v2/app/webapiVersion`
- `/api/v2/app/preferences`
- `/api/v2/app/setPreferences`
- `/api/v2/transfer/info`
- `/api/v2/transfer/speedLimitsMode`
- `/api/v2/transfer/toggleSpeedLimitsMode`
- `/api/v2/torrents/info`
- `/api/v2/torrents/add`
- `/api/v2/torrents/delete`
- `/api/v2/torrents/properties`

Keeping them inside the adapter layer avoids future architectural churn if more differences appear.

## Error Handling

Error handling must preserve the repository's fail-fast style.

### Detection Errors

- Login failure => `ConnectionFailureCategory.authFailed`
- Version endpoint unavailable or unreadable => `ConnectionFailureCategory.unknown`
- Parsed version unsupported => `ConnectionFailureCategory.versionUnsupported`

### Runtime Errors

- Network I/O failure => `DownloaderServiceException.network`
- Protocol-level bad status or invalid body => `DownloaderServiceException.protocol`
- Session expiration (`403`) => one re-login and one retry
- Retry still failing => propagate the corresponding auth or protocol exception

### Forbidden Behaviors

- No silent fallback from detection failure into "try v5 then try v4"
- No adapter switching during normal request execution
- No silent downgrading to partial compatibility mode

## Logging And Diagnostics

Successful connection and detection should log:

- downloader identifier
- resolved `appVersion`
- resolved `webApiVersion`
- resolved `apiGeneration`

Operation failures should log:

- semantic operation name
- resolved adapter generation
- concrete endpoint path
- HTTP status when available

This makes protocol mismatches diagnosable without surfacing technical noise to users.

## State And Persistence

The design separates internal routing state from persisted user data.

### Runtime Cache

Cached inside the service instance:

- `QBitServerProfile`
- resolved adapter instance
- authenticated session state

### Persisted Model

`Downloader.version` should continue storing the application version string for display and diagnostics.

The first implementation should not extend `Downloader` with stored `apiGeneration` or `webApiVersion`. Those are internal transport details unless a later product requirement proves they are valuable in persisted state or UI.

## Testing Strategy

The test strategy should be layered so protocol differences are easy to verify and easy to extend.

### 1. Detector Unit Tests

Cover:

- `4.x` detection selects `QBitV4Adapter`
- `5.x` detection selects `QBitV5Adapter`
- malformed `app/version`
- malformed `webapiVersion`
- missing version endpoint response
- unsupported version classification

### 2. Adapter Contract Tests

The same semantic behavior suite should be run against both adapters.

Examples:

- `pauseTorrents()`:
  - v4 must call `/torrents/pause`
  - v5 must call `/torrents/stop`
- `resumeTorrents()`:
  - v4 must call `/torrents/resume`
  - v5 must call `/torrents/start`
- `addTorrent()`, `getTasks()`, `getTransferInfo()`, `deleteTorrent()` must satisfy the same semantic contract on both versions

### 3. Facade Integration Tests

Cover:

- first call triggers detection
- later calls reuse cached adapter
- `403` causes re-login without re-detection
- editing downloader connection data clears the cached profile
- `testConnection()` reports version support correctly for both generations

## Rollout Plan

Although this design targets complete dual-version compatibility architecture, implementation should be phased.

### Phase 1: Core Compatibility Infrastructure

- Introduce `QBitSession`
- Introduce `QBitVersionDetector`
- Introduce `QBitServerProfile`
- Introduce `QBitApiAdapter`, `QBitV4Adapter`, `QBitV5Adapter`
- Introduce `QBitServiceFacade`

### Phase 2: Migrate Current WindWalker qBittorrent Features

- connection testing
- task listing
- task detail
- add torrent / add download
- pause / resume
- delete
- speed configuration

### Phase 3: Testing And Regression Hardening

- detector tests
- adapter contract tests
- facade integration tests
- regression coverage for existing controllers

### Phase 4: Progressive API Expansion

After the compatibility infrastructure is stable, expand additional domains such as:

- sync
- log
- RSS
- search
- broader torrent management operations

This expansion should be incremental and domain-based rather than a single large compatibility dump.

## Alternatives Considered

### Alternative 1: Keep One QBitService With Inline Version Branches

Pros:

- small upfront diff
- minimal class churn

Cons:

- version logic spreads across methods
- hard to test at scale
- poor fit for complete WebUI API compatibility

Rejected because it would turn the service into a long-lived branching hotspot.

### Alternative 2: Endpoint Registry Without Explicit Adapters

Pros:

- attractive for simple path substitutions
- compact for a small number of differences

Cons:

- weak fit once parameters or response semantics diverge
- tends to become half configuration and half custom code

Rejected because qBittorrent compatibility is likely to involve semantic differences, not just endpoint renames.

### Selected Approach: Facade + Detector + Versioned Adapters

Chosen because it keeps version decisions centralized, makes testing clean, and gives WindWalker a scalable structure for future WebUI API growth.

## References

- `lib/services/qbit_service.dart`
- `test/unit/downloader_services_test_connection_test.dart`
- `docs/api/qbitorrent/WebUI-API-(qBittorrent-4.1).md`
- `docs/api/qbitorrent/WebUI-API-(qBittorrent-5.0).md`
