# HRM Mobile App

Flutter mobile client for the Meltice Tech HRM platform. The app lets authenticated users view their profile, manage employees when permitted, submit and approve leave requests, and view or download payslips.

## Requirements

- Flutter SDK with Dart `>=3.3.0 <4.0.0`
- Android Studio or an Android SDK/emulator for Android development
- Access to the HRM API and a valid HRM user account

Company API URLs are configured in `lib/core/api.dart`. Replace the SBG placeholder with its actual API base URL before selecting SBG:

```dart
Company.sbg: 'https://hrms.melticetech.com/api/v1', 
Company.meltis: 'https://mithrms.melticetech.com/api/v1',
```

The selected company is saved and restored before the app checks for a saved login session.

## Setup

From the repository root:

```bash
flutter pub get
flutter devices
flutter run
```

Useful verification commands:

```bash
flutter analyze
flutter test
flutter build apk --release
```

The app starts on the login screen. After a successful login, the session token is stored with `flutter_secure_storage` and restored when the app starts again. A `401` response clears the session and returns the user to login.

## Features

- Login, logout, session restore, and automatic unauthorized-session handling
- Permission-aware home navigation and quick actions
- Employee list with search, pull-to-refresh, and paginated loading
- Employee details, editing, document uploads, and external document links
- Leave balances, leave requests, and approval/rejection workflow
- Payslip list, breakdown details, and approved-payslip PDF downloads
- Shared Material 3 theme and reusable panels, sections, key/value rows, and status chips

## Project Structure

```text
lib/
	main.dart                 App entry point and session-based routing
	core/
		api.dart                HTTP client, auth headers, pagination, uploads, downloads
		session.dart            Login state, user data, permissions, and lookup options
		ui.dart                 Theme, colors, shared widgets, and UI helpers
	screens/
		login.dart              Login form
		shell.dart              Authenticated shell, home dashboard, and navigation
		employees.dart          Employee list and employee details
		employee_form.dart      Create/edit employee form and multipart uploads
		leave.dart              Leave balances, requests, and approvals
		payslips.dart           Payslip list, details, and PDF downloads
		profile.dart            Current-user profile and account actions
assets/
	images/                   App image assets, including the launcher icon source
test/
	widget_test.dart          Flutter widget tests
```

## How Data Flows

1. `main.dart` restores the stored token through `Session.i.restore()`.
2. `Session` calls `/auth/session/` and exposes user details, pages, and permissions through `has()` and `can()`.
3. Screens use the singleton `Api.i` for all HTTP requests; it adds the bearer token and converts API errors to `ApiException`.
4. Screens refresh their own data after create, edit, approve, reject, or pull-to-refresh actions.

Keep API calls in `Api` and session-wide state in `Session`. Screen widgets should use `errText()` for user-facing request errors and should check permissions before showing actions.

## API Endpoints Used

| Area | Endpoints |
| --- | --- |
| Authentication | `/auth/login/`, `/auth/session/`, `/auth/logout/` |
| Metadata | `/meta/options/` |
| Employees | `/employees/`, `/employees/{id}/` |
| Leave | `/leave/`, `/leave/balance/`, `/leave/{id}/approve/`, `/leave/{id}/reject/` |
| Payslips | `/payroll/payslips/`, `/payroll/payslips/{id}/breakdown/`, `/payroll/payslips/{id}/download/` |

List endpoints may be paginated. Use `Api.i.getAll()` when all pages are required; employee scrolling intentionally follows the API `next` URL as the user reaches the end of the list.

## Permissions

The server supplies `pages` and `permissions` in the session response. Current page keys include:

- `employee_list`
- `leave_management`
- `salary`

Actions use permission names such as `create` and `edit`. Do not rely on hiding a button for security; the API remains the source of truth and can reject unauthorized requests.

## Contribution Notes

- Keep the API base URL in `lib/core/api.dart`; do not duplicate it in screens.
- Preserve trailing slashes on relative API paths because the backend expects them.
- Do not send a calculated `days` value when creating leave; the server calculates the duration from the dates.
- Payslip PDF files are downloaded to the device temporary directory and opened with the platform file handler.
- Use the existing colors and shared widgets in `lib/core/ui.dart` for new screens unless a feature needs a deliberate change to the design system.
- Keep secrets and real user credentials out of source control, screenshots, logs, and tests.

Before opening a pull request, run `flutter analyze` and `flutter test`, then manually verify login, logout, refresh, permission-gated actions, and any changed API workflow on a connected device or emulator.
