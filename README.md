# flutter_application_1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

EcoTag QR Management Setup

1. Install packages:
   flutter pub add mobile_scanner
   flutter pub add pdf
   flutter pub add printing

2. Run sql/qr_setup.sql in Supabase SQL Editor.

3. Copy the lib/ files into your project.

4. Merge main_routes_snippet.dart into your real main.dart.

5. QR Management supports:
   - Generate many QR tags first
   - Save them as available in Supabase
   - Print available tags in batch
   - Scan an available tag and open registration
   - Register a plant first and automatically generate a QR
   - Mark assigned QR tags as assigned

6. Location behavior:
   Town is selected first.
   Barangay is filtered by barangay.town_id.
   ZIP code comes from the selected town.

7. Plant type behavior:
   Tree, Shrub, Herb, Vine are always shown.
   Common Name is then filtered from plant_classification.

8. Your existing Dashboard/Login files are not replaced here.

## Super Admin setup

1. Apply `supabase/migrations/202608260001_super_admin_module.sql` in Supabase.
2. Ensure the initial account in `users` has the `super_admin` role.
3. Super Admin opens `/super-admin` after login and can create, list, activate, and deactivate university, campus, and college administrators.
4. University Admin is university-wide; Campus Admin requires a campus; College Admin requires a campus and a college from that campus.
5. Apply `supabase/migrations/202608260002_active_admin_limits.sql` to allow only one active University Admin, one active Campus Admin per campus, and one active College Admin per college.

## Inspection Team account setup

Apply `supabase/migrations/202609200001_college_admin_inspection_accounts.sql`. College Admins can then create, list, activate, and deactivate Inspection Team accounts assigned automatically to their own campus and college.
