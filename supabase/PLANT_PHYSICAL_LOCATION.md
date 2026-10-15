# Plant ownership and planting location

Run `migrations/202610150002_plant_physical_location.sql` in Supabase SQL Editor after the existing migrations. It runs in a transaction and can be rerun. Restart the updated app afterward.

College Admin and Inspection Team can register plants for their assigned campus and college. Registration shows these locked managing fields in Plant Classification. Location separately requires a campus or **Outside campus**, plus planting town and barangay. Changing planting location never changes the owner IDs used for access control, dashboards, QR scope, or college reports.

Example: managing campus **CSU Lasam**, managing college **CICS**, planting location **Outside campus**, town **Tuguegarao**. This is a CSU Lasam-managed plant physically planted in Tuguegarao.

Existing plants retain their recorded town and barangay. Their new physical campus field starts as **Not recorded yet** because ownership alone does not prove where a plant was planted. College Admin and Inspection Team can open Plant Details → Update planting location to confirm this information. Public scan details display managing campus/college separately from planting location.

The new `register_plant_at_location` function calls the established registration function and saves planting location in the same transaction. Invalid location rolls back both the plant and QR assignment. The migration updates the existing registration function to admit scoped Inspection Team accounts, preserving server-generated QR numbers, actor validation, scope checks, and audit events. QR batch management, replacement, account management, and plant archiving remain College Admin responsibilities.

After applying, verify:

1. Both College Admin and Inspection Team can register a plant in their own college; managing fields stay locked.
2. Outside campus + Tuguegarao saves without changing the managing campus/college.
3. Selecting a different physical campus does not grant its users access to the plant.
4. A barangay from another town, a forged registering user, or a different managing college is rejected.
5. Inspection Team can register by scanning an available QR and can also generate its plant QR during registration.
6. An invalid location does not leave a plant or assigned QR behind.
7. Existing plants show an unconfirmed physical location; updating it preserves QR history and ownership.

The SQL migration must be applied to the live database before the new save functions work. Flutter tests do not execute these database functions.
