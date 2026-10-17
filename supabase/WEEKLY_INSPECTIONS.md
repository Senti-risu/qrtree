# Weekly plant inspections

Run `migrations/202610180001_weekly_plant_inspections.sql` in the Supabase SQL
Editor for this app's database, after the physical-location and Dead-plant-lock
migrations. Updating/pushing the Flutter app does not apply database migrations.

New plants use 7 days. Existing active, non-Dead plants using the old 90-day
interval switch to 7 days. Their next due date is recalculated from the last
inspection, or planting date/creation date if never inspected. This can correctly
make older plants overdue; it does not restart their waiting period from today.
Other custom intervals and Dead/archived records remain unchanged. Dead plants
still have routine inspections stopped. Later inspections use the saved interval.

Apply this migration once using your normal migration process. In the app, verify
a new registration shows Every 7 days, an inspection sets next due 7 days ahead,
and existing converted records have the expected due dates. Confirm a custom
interval and a Dead record remain unchanged. This script has not been run against
the live database by the coding agent.
