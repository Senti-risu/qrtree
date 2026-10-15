# Dead plant record lock

Apply `migrations/202610160001_dead_plant_lock.sql` in the Supabase SQL Editor
after the previous physical-location migration. Then rebuild/install EcoTag.
The migration is transactional and can be run again. No plants, QR labels, or
inspection history are deleted. Existing Dead plants have their future due dates
cleared.

## Behavior

- Registration or inspection selecting Dead asks for explicit confirmation.
- Dead records cannot receive new inspections or routine edits, even from an
  older client. Inspection queues exclude dead plants except completed history.
- QR reporting, printing/replacement, viewing, and archive/restore remain
  available. Restoring an archived Dead plant does **not** unlock it.
- Only the College Admin of the plant's managing campus **and** college can
  reopen an unarchived Dead record, selecting a non-Dead status and supplying a
  3–250 character reason. The change is recorded as `plant.dead_record_reopened`
  in the Activity Log. Existing inspection history remains unchanged.
- Reopening starts a new due date using the existing inspection interval.
- A replacement plant must be registered as a separate record.

## Verify after applying

1. Inspect a live plant, choose Dead, cancel confirmation: nothing is saved.
2. Confirm Dead: the inspection is saved, future due date cleared, record locked.
3. As Inspection Team, verify Inspect/location/schedule edits are unavailable;
   QR reporting and history still work. Old clients must receive a lock error.
4. As the assigned College Admin, reopen with a status and reason. Confirm the
   audit event, unchanged history, and resumed inspection schedule.
5. Another college's admin and all other roles must be rejected by the reopening
   RPC. Empty/short reasons and a Dead target status must also be rejected.

Read-only installation check:

```sql
select tgname from pg_trigger
where not tgisinternal
  and tgname in ('enforce_dead_plant_lock', 'prevent_dead_plant_inspection');
```

Expected: two rows. The app does not apply this database update automatically.
