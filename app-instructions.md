# App-building instructions — Budget Forecast Flutter app

Summary

- Build a small, conservative Flutter app that forecasts savings over a range of months toward a target goal.
- Keep changes localized to `lib/`. Use `lib/main.dart` as entry point. Add new widgets under `lib/screens/` and new services under `lib/services/`.
- Persist data locally with SQLite (sqflite). Auto-backup each change to Google Sheets and provide restore means.

Primary features

- Create/Edit/Delete forecast items (rent, subscriptions, misc (custom items)).
- Input: start date, end date (goal month), expected incoming budget up to goal, target savings, monthly desired saving amount.
- Show forecast: projected saved amount over time, progress percentage (e.g., 60%/90% to goal), months remaining, breach warnings (if spending > inflow).
- Add miscellaneous/unplanned item category.
- Auto-backup every item change to a Google Sheet row.
- Restore from Google Sheet to local SQLite.
- Pleasant, responsive UI with clear charts/summary, mobile-first UX.

High-level architecture

- UI layer: StatefulWidgets + small widget classes under `lib/screens/` and `lib/widgets/`.
- Data layer: local SQLite (sqflite) + a lightweight storage service singleton (e.g., `lib/services/storage_service.dart`).
- Backup layer: Google Sheets sync service (e.g., `lib/services/gsheet_service.dart`) handling auth and incremental sync.
- Models: plain Dart classes in `lib/models/` (e.g., ForecastItem, ForecastMeta).
- Tests: small unit tests for forecasting logic and storage operations under `test/`.

Data model (suggested)

- ForecastMeta
  - id
  - startDate (ISO)
  - endDate (ISO)
  - goalAmount
  - expectedIncomingTotal
  - monthlyTargetSaving
- ForecastItem
  - id
  - metaId
  - name (e.g., Rent)
  - monthlyAmount
  - type (expense / planned saving / misc)
  - createdAt
  - updatedAt

Local persistence

- Use sqflite + path_provider. Keep tables: forecasts_meta, forecast_items, sync_queue (optional).
- On each create/update/delete: write to SQLite and enqueue a sync record.
- Expose storage API: createMeta(), addItem(), updateItem(), deleteItem(), listItems(metaId), importFromSheet().

Google Sheets backup (recommended approach)

- Auth: use google_sign_in to authenticate the user and obtain OAuth credentials. Use the Google Sheets API (googleapis: sheets.v4) with appropriate scopes (https://www.googleapis.com/auth/spreadsheets).
- Sheet layout (one row per item change or per item):
  - Columns: item_id | meta_id | name | monthlyAmount | type | createdAt | updatedAt | action (create/update/delete)
- Sync flow:
  - On item change: write to SQLite → add to sync_queue → attempt upload immediately (background isolate/future).
  - If offline or upload fails: keep sync_queue and retry with exponential backoff when connectivity resumes.
  - Use a last_synced timestamp and a simple idempotency key (item_id + updatedAt) to avoid duplicates.
- Restore:
  - User triggers restore or app on first run: authenticate → read rows from sheet → map to local models → merge into SQLite (resolve conflicts using updatedAt, prefer latest).
- Security notes:
  - Prefer user-owned sheet via OAuth rather than embedding service account keys in the app.
  - Document required Google Cloud Console setup (OAuth client ID for Android/iOS) and required scopes.

Sync reliability & conflict resolution

- Use a queue with retry and backoff.
- Use lastUpdated timestamps. On conflict, prefer the newest updatedAt.
- Allow manual "Force restore from cloud" in settings to fully replace local DB (with confirmation).

UI/UX guidance (brief)

- Dashboard screen: progress ring (percentage to goal), months remaining, target vs projected savings.
- Forecast list screen: editable cards for each item (monthly cost and type). Inline editing and quick add FAB.
- Timeline / chart screen: simple line or bar chart of cumulative savings over months (use built-in CustomPaint or add a lightweight chart package if necessary).
- Settings: Google account connect, backup status, manual sync, restore, export (CSV).
- Animations: subtle transitions, card elevation, and primary color accents. Keep UI accessible: large tappable areas, readable fonts.

Packages to consider (add to pubspec.yaml)

- sqflite
- path_provider
- google_sign_in
- googleapis (sheets v4)
- connectivity_plus (for network status)
- intl (date formatting)
- optionally a chart package: fl_chart (if needed)
  When adding packages: update `pubspec.yaml` and run `flutter pub get`.

Developer tasks (small incremental work items)

1. Create models: `lib/models/forecast_meta.dart`, `lib/models/forecast_item.dart`.
2. Implement storage service: `lib/services/storage_service.dart` (SQLite initialization, CRUD, sync_queue).
3. Implement forecasting logic module: `lib/services/forecast_service.dart` — compute monthly projections, percent-to-goal, month-by-month balances.
4. Build core screens:
   - `lib/screens/home_screen.dart` (dashboard)
   - `lib/screens/forecast_edit_screen.dart`
   - `lib/screens/forecast_detail_screen.dart` (chart + month list)
5. Implement Google Sheets service: `lib/services/gsheet_service.dart` (auth + push/pull functions).
6. Hook UI to services in `lib/main.dart`. Keep state local or a minimal app-state singleton.
7. Add small tests for forecast calculations and storage CRUD under `test/`.
8. Document Google Cloud OAuth setup and user flow in README.

Testing & running

- Run on device/emulator: `flutter run`
- Analyze: `flutter analyze`
- Tests: `flutter test`
- Ensure lints from `analysis_options.yaml` are satisfied.

Edge cases & UX flows to handle

- Partial offline usage: queue and auto-retry.
- Duplicate rows in sheet: dedupe via idempotency keys.
- User revokes Google access: detect and prompt re-auth.
- Large restores: show progress, allow cancel.

Deliverables expected from the chatbot

- Minimal, runnable Flutter changes under `lib/` implementing:
  - models + storage service (sqflite)
  - forecasting algorithm + unit tests
  - UI screens (dashboard, item list, edit)
  - Google Sheets sync service with setup notes
- README updates documenting setup steps for Google Cloud Console and how to run & test.

Short example folder layout (suggested)

- lib/
  - main.dart
  - models/
    - forecast_meta.dart
    - forecast_item.dart
  - services/
    - storage_service.dart
    - gsheet_service.dart
    - forecast_service.dart
  - screens/
    - home_screen.dart
    - forecast_edit_screen.dart
    - forecast_detail_screen.dart
  - widgets/
    - item_card.dart
    - progress_ring.dart

If you want, I can now scaffold the minimal files (models + storage + a simple dashboard screen) using the current project conventions so you can run and iterate. Specify which part to scaffold first (models, storage, UI, or Google Sheets integration).
