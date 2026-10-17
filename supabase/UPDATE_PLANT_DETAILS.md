# Update plant details

Run `migrations/202610170001_update_plant_details.sql` in the Supabase SQL Editor
for the same project used by EcoTag. This migration has **not** been applied by
the coding agent. Apply it before using the new Save changes button.

Prerequisites: the secure session/production-readiness, physical-location, and
dead-plant-lock migrations already used by the app. The script adds one RPC;
it does not rename columns, migrate existing records, change ownership, or
generate replacement QR codes. It can be run again safely.

Verify installation:

```sql
select to_regprocedure(
  'public.update_plant_details(text,integer,integer,text,text,date,text,text,integer,integer,integer)'
) is not null as update_plant_details_installed;
```

Expected result: `true`. Then hot restart/rebuild the app. As College Admin or
Inspection Team, open an active plant from your assigned college and choose
**Update plant details**. Change a variety or planter and physical location,
save, reopen the plant, and verify persistence and Activity Log entries.

Editable: classification (type/common name; scientific name follows the chosen
classification), variety, planting date, tree planter, photo, planting campus
or outside campus, town, and barangay. Blank optional fields are stored as null.
Selecting a different common name changes only this plant's classification
reference, not the shared classification record or other plants.

Unchanged: managing campus/college, QR code, registering account, inspection
history and schedule. Health and growth updates stay in the inspection workflow.
Dead/archived plants and plants outside the staff member's college cannot be
edited. The RPC rechecks these rules even if the app page is stale.

Both details and location changes are atomic: a validation error rolls back all
database changes. Photo uploads occur separately in Storage; old images are not
deleted (they may be referenced by historical inspections). A failed or uncertain
save can leave a newly uploaded image unreferenced; the editor retains its URL
for retry and never deletes it when the commit outcome is unknown.

Automated checks cover UI saving, retries, form validation, responsive sizes,
locks, payload fields and migration guards. The RPC still needs live verification
in your Supabase project after installation; static tests do not execute SQL.
