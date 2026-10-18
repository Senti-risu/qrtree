# EcoTag

Cagayan State University's Flutter and Supabase application for plant profiling,
QR identification, recurring inspections, and monitoring reports.

See [Project structure](docs/PROJECT_STRUCTURE.md) for source folders, screen
locations, and test groups.

## Run locally

Use the Flutter version pinned in `.github/workflows/build-apk.yml` (currently
3.47.1) or a compatible SDK with Dart 3.12.2 or later. Install the Android SDK for
Android builds, or enable a supported desktop/web target.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Supabase configuration reads the `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`
build defines. `SUPABASE_ANON_KEY` is also supported for the existing GitHub
workflow; `SUPABASE_PUBLISHABLE_KEY` takes precedence if both are supplied.
Without build defines, `lib/config/supabase_config.dart` retains the local
development defaults. Set both URL and client key for a different deployment.
Never put a service-role key in the client. Test camera permissions and scanning
on a phone.

## Database setup and upgrades

The files in `supabase/migrations` are incremental upgrades to the original EcoTag
schema. They assume existing tables and reference data; this repository does not
include a complete empty-database bootstrap. Restore the original schema and seed
data before using a fresh Supabase project.

Apply unapplied migrations in filename order, beginning with
`202608230001_add_plant_inspections.sql` and ending with
`202610190001_campus_only_lookup_creation.sql`. Use Supabase SQL Editor or your established
migration runner, and record applied filenames. Do not reapply older function
definitions after newer migrations. Verify upgrades against a staging copy first.

Deploy the unapplied migrations before distributing this client. Monitoring adds request
IDs and observation timestamps to inspections, the staff timeline, and scope-checked
outcome reporting. Existing inspections remain readable, using their submission
time when no observation timestamp exists. Images use the `plant-images` bucket.

Campus, Town and Barangay are selection-only in the current app. The older
lookup-creation migrations remain in history; the app no longer calls them.
See [Adding location options](docs/LOCATION_LOOKUPS.md).

The initial active `users` account must have the `super_admin` role. Provision it
through your trusted administrative setup, then create other accounts in EcoTag.
Reference data must include campuses, colleges, plant classifications,
health/growth statuses, towns, and barangays.

## Roles

| Role | Scope and primary tasks |
| --- | --- |
| Super Admin | Administrator accounts and university-wide access |
| University Admin | University-wide monitoring and reports |
| Campus Admin | Monitoring and reports for the assigned campus |
| College Admin | Assigned college registration, schedules, archive/restore, and Inspection Team accounts |
| Inspection Team | Assigned college registration and inspections, including offline drafts |
| Guest | Public, read-only QR plant profiles |

Server functions enforce the active account and assigned scope. UI role checks
are conveniences, not authorization boundaries.

## Offline field inspections

1. Sign in online. Open Dashboard → Offline inspections and pending uploads.
2. Select Download assigned plants for offline work before entering the field.
3. Open a downloaded plant and add observations, health/growth selections, and photos.
4. Save draft stores unfinished work locally. Review and save confirms the
   condition, stores a pending submission, and attempts upload.
5. Once connected, choose Upload pending inspections. Failed submissions stay
   on the device. Stable request IDs prevent duplicate inspections on retry.

An online sign-in is required after restarting the application. Offline work is
available within an established signed-in session. Drafts and downloaded profiles
are account-specific device data; clearing app storage or uninstalling can erase
them. Unfinished drafts require review before upload. Upload rechecks assignment,
archive/Dead locks, and newer observations. Remove obsolete drafts explicitly.

## Timeline, reminders, and outcomes

Staff plant profiles show registration, inspection evidence, and audited record
changes chronologically. Expand earlier events to read more history. Treatments
are not included because the application has no treatment-task workflow yet.

The dashboard shows a daily in-app due/overdue digest and flags plants overdue by
two inspection intervals for College Admin attention. It refreshes while open and
on resume; dismissal lasts until the next Philippine calendar day. It does not
send email, push, or background notifications.

Reports include scope-wide survival by planting month, 30-day inspection coverage
by college, and monthly health observations. These tables are independent of the
existing plant filters and explain their denominators. Archived records remain in
survival/history. Archived and Dead plants are excluded from current inspection
coverage. Coverage measures plants inspected, not on-time schedule compliance.
The existing PDF export remains the filtered plant report.

See [monitoring behavior and validation](docs/MONITORING_WORKFLOWS.md).

## Validation and releases

Run analysis and the test suite before release. GitHub Actions builds APKs on
`main` and manual dispatch, with version/build release tags and increasing Android
version codes. Follow [APK release setup](docs/APK_RELEASES.md) for signing secrets,
keystores, and update requirements. Validate airplane-mode drafts, interruption
recovery, photos, guest access, role scope, and Dead/archived locks on a phone.

Additional guides: [registration drafts](docs/REGISTRATION_DRAFTS.md),
[persistent sign-in](docs/PERSISTENT_SIGN_IN.md),
[weekly inspections](supabase/WEEKLY_INSPECTIONS.md),
[physical location](supabase/PLANT_PHYSICAL_LOCATION.md), and
[QR problems](supabase/QR_PROBLEM_REPORTS.md).
