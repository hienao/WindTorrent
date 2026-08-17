# WindWalker Unified Design Specification

Last updated: 2026-04-27

## 1. Design Goal

This document defines the unified UI style for WindWalker.

Design keywords:
- Clear
- Lightweight
- Professional tool-like

Core principle:
- Show only data and interactions that current APIs can provide.
- Remove non-implementable visuals and pseudo-features.

## 2. Visual Style

### 2.1 Color System

- Primary: `#1677FF` (main actions, selected states, links)
- Success/Online: `#14B8A6`
- Warning/Running: `#F59E0B`
- Error: `#EF4444`
- Page Background: `#F6F8FB`
- Card Background: `#FFFFFF`
- Primary Text: `#0F172A`
- Secondary Text: `#64748B`
- Border/Divider: `#E2E8F0`

Usage rules:
- Use one primary action color per screen (`#1677FF`).
- Status colors are semantic only (success/warning/error).
- Do not introduce random accent colors per page.

### 2.2 Typography

Recommended font stack:
- `system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Noto Sans CJK SC", sans-serif`

Type scale:
- Page title: 20 / 700
- Section title: 16 / 600
- Card title: 15 / 600
- Body text: 14 / 400-500
- Secondary/meta: 12 / 400

### 2.3 Shape, Spacing, Elevation

- Global spacing base: 8
- Page horizontal padding: 16
- Card padding: 16
- Item gap in lists: 12
- Card radius: 16
- Input radius: 12
- Button radius: 12
- Primary button height: 48
- Divider: 1px `#E2E8F0`
- Shadow: light and stable, avoid heavy/glow effects

## 3. Component Rules

### 3.1 Buttons

- Primary button: filled `#1677FF`, white text, height 48
- Secondary button: white background, `#E2E8F0` border
- Danger button: use `#EF4444` only for destructive actions

### 3.2 Status Chip

Unified status chip component:
- Online/Success: `#14B8A6`
- Running/Waiting: `#F59E0B`
- Paused/Offline: neutral gray text with border
- Error: `#EF4444`

### 3.3 Cards

Cards are the default information container.
Each card should contain:
- Clear title
- Key values first
- Secondary information below
- Actions aligned at the bottom or trailing side

### 3.4 Inputs

- Use outlined or soft-filled input style consistently
- Keep labels explicit
- Validate and show errors inline

## 4. Information Architecture Rules

- Prioritize actionable information.
- Do not display charts/trends without real API support.
- Each screen should have at most one dominant CTA.
- Keep operations discoverable: search/filter/action menu in stable positions.

## 5. Screen Functional Scope (Confirmed)

### 5.1 Overview (`DataTab`)

Must include:
- Task counts by status: downloading, waiting, paused, seeding, completed, error
- Downloader distribution list (per downloader counts)
- Pull-to-refresh
- Entry to add task

Must NOT include:
- Speed trend charts (no corresponding API)

### 5.2 Downloaders Management (`DownloadersPage`)

Must include:
- Downloader list: name, type, host:port, status, task counts
- Actions: add, edit, delete, config

Must NOT include:
- Speed-test button/feature

### 5.3 Task List (`TasksPage`)

Must include:
- Status filters
- Search
- Refresh
- Task actions: pause/resume/delete
- Navigate to task detail

### 5.4 Task Detail (`TaskDetailPage`)

Must include:
- File info (name, task ID)
- Download info (status, progress, current speeds, downloaded/total, remaining time if available)
- Connection info (downloader, tracker, connections, seeds, peers)
- Actions: pause/resume/delete

Must NOT include:
- Upload/download speed trend charts
- Piece health view
- Favorite/bookmark feature

### 5.5 Add Task (`AddTaskPage`)

Must include:
- Downloader selection
- URL/magnet input
- Paste action
- Torrent file pick entry (if existing flow uses it)
- Save path (optional)
- Submit/start download

Must NOT include:
- Advanced options panels
- Scheduling/category/speed strategy extras

### 5.6 Downloader Config (`DownloaderConfigPage`)

Must include:
- Basic connection/config info
- Speed limit related fields already supported by model/API
- Save config

Must NOT include:
- Automation rules

### 5.7 Profile (`ProfileTab`)

Must include:
- Account info (based on login state)
- Login/logout actions
- Settings entry

Must NOT include:
- Storage space panel
- Recent activity timeline

### 5.8 Settings (`SettingsPage`)

Must include:
- Language
- Theme mode (light/dark/system)
- About/version
- Optional app rating entry

Must NOT include:
- Storage space section
- Recent activity/history section

### 5.9 Auth (`LoginPage`, `EmailLoginPage`, `EmailRegisterPage`)

Must include:
- Login entry
- Email login
- Email register
- Basic validation and error feedback

## 6. Responsive Rules

- Mobile first
- Tablet/desktop may use grid for cards/lists, but keep the same visual language
- Do not create separate color systems across breakpoints
- Ensure minimum touch target height is 44

## 7. Interaction and Feedback

- Pull-to-refresh for data-heavy pages
- Loading: use lightweight progress indicators
- Empty states: clear message + single next action
- Error states: concise message + retry when possible
- Confirm dialogs for destructive actions (delete/remove)

## 8. Do and Don’t

Do:
- Keep visual style consistent across all screens
- Keep hierarchy simple and scannable
- Map every displayed metric to real data

Don’t:
- Add unsupported charts, trends, or pseudo analytics
- Add features not in current product scope
- Change page color tone independently per screen
