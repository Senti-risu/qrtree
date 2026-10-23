# Project structure

EcoTag keeps Flutter's root layout and groups screens by feature. Moving files
does not change route names, public widget classes, permissions, or app identity.

```text
lib/
  main.dart                         Startup and named routes
  config/                           Client configuration
  models/                           Shared data and business rules
  screens/
    admin/
      dashboard/                    Dashboard screen and widgets/
      registration/                 Registration screen and widgets/
      reports/                      Report screen, widgets/, models/, legacy/
      activity_log_screen.dart
      inspection_accounts_screen.dart
    auth/                           Login and saved-session bootstrap
    inspections/                    Inspection form, history, offline outbox
    plants/                         Plant list, details, scan entry
    public/                         Guest pages and public scanner
    qr/                             QR management, scanner, problem reports
    super_admin/                    Administrator-account screens
  services/                         Database, sessions, secure storage and sync
  theme/                            Colors, typography, spacing and theme
  utils/                            Formatting and error helpers
  widgets/                          Reusable UI, including forms/
test/
  unit/                             Models, services, validation, SQL checks
  widget/                           Layout, navigation and screen-flow tests
assets/                             Fonts, images, launcher-icon source
docs/                               Setup, workflows and design guides
  archive/                          Historical notes, not current instructions
supabase/migrations/                SQL upgrades in original filename order
.github/workflows/                  Build and release automation
```

## Finding moved files

| Previously under `lib/screens/admin/` | Current path |
| --- | --- |
| `dashboard.dart` | `lib/screens/admin/dashboard/dashboard_screen.dart` |
| `register_plants.dart` | `lib/screens/admin/registration/register_plant_screen.dart` |
| `college_plant_report_screen.dart` | `lib/screens/admin/reports/plant_report_screen.dart` |
| `plant_list_screen.dart` | `lib/screens/plants/plant_list_screen.dart` |
| `qr_management.dart` | `lib/screens/qr/qr_management_screen.dart` |
| `plant_service.dart` | `lib/services/plant_service.dart` |

Folders formerly named `dashboard widgets`, `registration widgets`, `report
widgets`, and `report models` are now `widgets/` and `models/` inside their
features. Test filenames are unchanged, inside `test/unit` or `test/widget`.
Tests containing both unit and widget cases live in `test/widget`.

The old project structure note and the unused legacy `PlantListPage` screen
have been removed; they are available in git history.

## Working conventions

- Use `snake_case` filenames and folders without spaces.
- Keep feature-specific UI in its feature's `widgets/`. Use `lib/widgets/` for
  UI actually shared by features, and `lib/services/` for database/storage logic.
- Update imports, source-file checks, and docs when moving files.
- Preserve unfinished local work; untracked does not mean disposable.
- Do not rename or reorder existing migrations. A Git push does not apply SQL
  migrations to Supabase.

```powershell
flutter analyze --fatal-infos
flutter test
flutter test test/unit
flutter test test/widget
```

The normal `flutter test` command still discovers every test. Generated preview
images go under `build/layout_previews/`, not source/assets directories.

Native folders (`android`, `ios`, `web`, `windows`, `macos`, `linux`) remain at the
root. `pubspec.yaml`, package name `flutter_application_1`, and app IDs are
unchanged. Generated/local folders (`build`, `.dart_tool`, `.idea`,
`.widget_preview`) keep their ignore rules. Generated files and reference
worktrees were not deleted.
