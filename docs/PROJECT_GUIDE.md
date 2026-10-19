# EcoTag project guide

EcoTag is Cagayan State University's plant registration and monitoring app. It
connects plant records to QR labels, gives staff role-scoped tools for
registration and recurring inspections, and provides public read-only access to
plant profiles. The Flutter client uses Supabase for authentication/session
validation, data access, storage, and database-enforced operations.

This guide describes the current implementation. For setup, deployment, and
important operational caveats, see the [README](../README.md).

## Application at a glance

```text
Flutter app
  ├─ Screens and reusable widgets
  ├─ Services for Supabase, local drafts, session storage, sync, and exports
  └─ Models and shared role/business rules
        │
        ├─ Supabase Auth/session RPCs and database RPCs
        ├─ Supabase tables and storage (plant photos)
        └─ Device-secure storage for remembered staff sessions and drafts
```

The app starts in `lib/main.dart`. It initializes Supabase using build-time
configuration in `lib/config/supabase_config.dart`, then opens the session
bootstrap route. Named routes validate the navigation data they require and
show an error page for invalid arguments. Those route and UI checks improve
navigation consistency; database functions remain the authorization boundary.

## Roles and responsibility

| Role | Main responsibilities |
| --- | --- |
| Super Admin | Manage administrator accounts and access university-wide records. |
| University Admin | Monitor university-wide plants, inspections, and reports. |
| Campus Admin | Monitor records and reports for the assigned campus. |
| College Admin | Register and manage plants in the assigned college, manage QR tags, schedules, archives, and Inspection Team accounts. |
| Inspection Team | Register assigned-college plants and carry out inspections, including offline field work. |
| Guest | Read-only plant information through public QR access. |

Campus and college assignments are passed to relevant screens as scope context.
The database independently checks the authenticated account, role, and scope;
client-side role capabilities are not a security boundary.

## Main user flows

### Staff sign-in and startup

1. A visitor can use the public landing and guest entry flow without signing in.
2. Staff choose staff access and submit credentials on the staff login screen.
3. On later launches, the bootstrap screen checks a saved session token with the
   server. It routes valid users to the correct staff dashboard, returns invalid
   sessions to sign-in, and provides a retry path for temporary network errors.
4. The token is stored in platform-secure device storage; passwords and guest
   visit details are not remembered.
5. Logout removes the local token and attempts server-side revocation.

The session lifetime, transient failure behavior, and platform storage details
are documented in [persistent sign-in](./PERSISTENT_SIGN_IN.md).

### Guest QR access

1. A guest enters the public experience and can provide visit information.
2. The app records/uses the visit context to enter the guest dashboard.
3. A guest scans or selects a plant to open its public profile.
4. Guest plant details are read-only; staff-only management and inspection
   actions are not available in this flow.

### Plant registration

1. An authorized College Admin or Inspection Team opens registration for its
   assigned campus and college.
2. The user completes the plant identity, classification, location, and photo
   information and reviews the registration.
3. Registration can be saved as a device-local draft and resumed in the same
   account/assignment context.
4. Submission writes the plant record and QR association through the app's
   database workflow. A newly supplied scientific name is saved atomically
   with registration when the required migration is deployed.

See [registration drafts](./REGISTRATION_DRAFTS.md) for persistence rules and
the handling of missing scientific names.

### QR labels and scanning

- Staff scan EcoTag QR labels to resolve records and perform role-appropriate
  actions.
- College Admins manage available labels, assignments, and replacement/reprint
  flows. Batch printing and QR rendering are implemented in the QR screens,
  widgets, and print services.
- Public scanning opens read-only plant details.
- Users can report QR problems; the app records these for staff follow-up.

Relevant implementation areas are `lib/screens/qr/`,
`lib/screens/public/guest_qr_scanner_screen.dart`, `lib/services/qr_service.dart`,
`lib/services/qr_print_service.dart`, and `lib/services/qr_problem_service.dart`.

### Inspections and offline work

1. Staff download their assigned plant profiles while online.
2. In the field, they record observations, health/growth information, and
   photos. Work can be saved locally as a draft.
3. Reviewing and saving creates a pending submission; the app attempts to
   upload it when connectivity is available.
4. Failed uploads remain in the outbox for retry. Stable request IDs help
   prevent duplicate submissions.
5. The server rechecks assignment and plant locks when a queued inspection is
   uploaded.

An online sign-in is required after an application restart. Offline inspection
work is tied to the signed-in account and this device; clearing app data or
uninstalling can remove local work. See
[monitoring workflows](./MONITORING_WORKFLOWS.md).

### Monitoring, dashboard, and reports

- Staff dashboards summarize plant/inspection state, recent records, and due or
  overdue work.
- Plant profiles combine the plant record with QR information, inspection
  evidence, and a chronological record-change timeline.
- Inspection history and the outbox let staff review submissions and pending
  uploads.
- Reports provide role-scoped plant data and monitoring outcomes. The existing
  PDF export is the filtered plant report.
- Reminder digests are in-app; they are not push, email, or background
  notifications.

The monitoring guide explains outcome metrics, denominators, date handling,
and exclusions. In particular, inspection coverage is not a measure of
on-time schedule compliance.

### Administrator account management and activity

- Super Admin screens create and manage administrator accounts.
- College Admin screens manage Inspection Team accounts within their assigned
  college.
- Administrator activity logs show audited record changes, subject to role
  and assignment scope.

## Code map

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Supabase startup, app theme, named routes, route argument checks. |
| `lib/config/` | Build-time backend configuration. |
| `lib/models/` | Shared role, schedule, account, and record models. |
| `lib/screens/auth/` | Access choice, staff login, and session bootstrap. |
| `lib/screens/public/` | Landing, guest entry/dashboard, public scan and plant detail. |
| `lib/screens/admin/` | Dashboard, registration, reports, activity, and inspection accounts. |
| `lib/screens/inspections/` | Inspection form, history, and pending-upload outbox. |
| `lib/screens/plants/` | Plant listing, scanning, and staff details. |
| `lib/screens/qr/` | Staff QR management, scanning, and QR problem reports. |
| `lib/screens/super_admin/` | Super Admin dashboard and account management. |
| `lib/services/` | Backend operations, session persistence, drafts, sync, QR, and exports. |
| `lib/widgets/` | Shared application shell, responsive UI, forms, plant views, and dialogs. |
| `lib/theme/`, `lib/utils/` | Shared visual styling and small formatting/error helpers. |
| `supabase/migrations/` | Ordered incremental SQL changes to the existing database schema. |
| `test/unit/`, `test/widget/` | Model/service/migration checks and UI/navigation/workflow tests. |

Feature-specific widget files are colocated with their screens; `lib/widgets/`
contains components shared across features. `docs/PROJECT_STRUCTURE.md` gives
the expanded folder layout and file-placement conventions.

## Important data and deployment boundaries

- Database migrations are incremental upgrades, not a complete empty-database
  bootstrap. A new Supabase project also needs the original schema and reference
  data.
- Apply migrations in filename order and deploy the required server functions
  before using client features that depend on them.
- Plant images use the Supabase `plant-images` bucket.
- Location lookups are selection-only in the current app; older lookup-creation
  migrations remain in history but are no longer called by the app.
- Client build configuration accepts `SUPABASE_URL` and
  `SUPABASE_PUBLISHABLE_KEY` (or the legacy `SUPABASE_ANON_KEY`). Never ship a
  service-role key in a client build.
- The active initial account must be provisioned as a Super Admin through a
  trusted administrative process.

See the root [README](../README.md) for the current migration range,
environment configuration, release workflow, and the complete set of
operational guides.

## Development and validation

The project is a Flutter/Dart application with Supabase integration. Common
commands from the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Before releasing, also verify real-device camera permissions and QR scanning,
secure session persistence, role/scope enforcement, offline draft recovery,
and inspection upload retries. Automated unit and widget tests do not replace
deployment checks against a staging Supabase project or device testing.

## Further reading

- [Project structure](./PROJECT_STRUCTURE.md)
- [Monitoring workflows](./MONITORING_WORKFLOWS.md)
- [Registration drafts](./REGISTRATION_DRAFTS.md)
- [Persistent sign-in](./PERSISTENT_SIGN_IN.md)
- [Location lookups](./LOCATION_LOOKUPS.md)
- [APK releases](./APK_RELEASES.md)
- [Weekly inspections](../supabase/WEEKLY_INSPECTIONS.md)
- [QR problem reports](../supabase/QR_PROBLEM_REPORTS.md)
