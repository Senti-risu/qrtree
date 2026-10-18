# Monitoring workflows

Apply `supabase/migrations/202610180003_monitoring_outcomes.sql` after all previous
migrations. No new Flutter package is required.

## Offline outbox

Each inspection is stored separately in secure storage, keyed by account and a
random request ID. Photos are retained as base64 bytes; temporary camera paths are
not required for restoration. Choices and downloaded plant snapshots are cached
per account. Downloaded profiles show the last fetched state; the server decides
whether upload is allowed.

Drafts are explicitly saved. Leaving unsaved work prompts before discard. Pending
submissions are persisted before network calls. Upload runs serially and stops at
the first error, preserving remaining work. Unconfirmed drafts are not uploaded.
Signing out does not delete saved work; another account's outbox is not listed.

The submission RPC validates the account, scope, statuses, plant locks, and date.
A transaction lock and unique request index make retries safe, including a retry
after a successful submission marked the plant Dead. Observation time is separate
from server receipt time. Scheduling uses the observation date in Asia/Manila;
delayed upload does not falsely postpone inspections. Older drafts cannot
overwrite newer observations. Keep the device clock accurate. Review stale work
against the current record and make a new observation rather than changing the
date on old evidence.

Startup requires online session validation. Offline field work is supported after
sign-in, rather than offline authentication. Clearing app storage can erase local
work. Large photos increase secure-storage use; the picker resizes form photos.

## Reminders

The digest uses the existing server-scoped queue. It refreshes every minute while
mounted and on resume. Dismissal is stored per account/role/assignment for the
Philippine calendar day. Escalation means days overdue are at least twice the
inspection interval. This is an in-app attention flag, not a message sent to
another person. The full queue remains accessible after dismissal.

## Report definitions

- Planting batch: planting calendar month; missing dates are shown separately.
- Survival: known non-Dead plants divided by all records in that batch. Unknown
  health remains in the denominator. Archived records remain included so
  archiving losses cannot improve the rate.
- Coverage: active non-Dead plants inspected within the last 30 Philippine
  calendar days divided by active non-Dead plants. Empty denominators show N/A.
  This measures coverage, not inspection punctuality.
- Health trend: inspection observations grouped by month and status. Repeated
  inspections count separately; these are not unique-plant population estimates.
  Legacy records without observation time use submission time.

Outcome tables cover the authenticated account's full scope independently of the
older detailed-report filters. The existing PDF export remains its filtered plant
report; outcome tables are displayed in-app.

## Device and database acceptance checks

1. Download assigned profiles and choices. Enable airplane mode, inspect a
   downloaded plant, save a photo and notes, and reopen the draft.
2. Confirm health and submit offline. Verify pending upload, reconnect, and upload.
   The draft disappears only after a successful server response.
3. Interrupt after server commit and retry the same request ID. Verify one
   inspection and one audit event, including when the result is Dead.
4. Submit a newer observation on another device, then an older draft. Verify the
   draft remains local and the newer plant state is retained.
5. Change assignment or archive/mark the plant Dead before upload. Verify rejection
   without losing the local draft.
6. Check timeline order, evidence photos, audit labels, load errors, and earlier
   events. Guest profiles must not expose staff audit events.
7. Check due today, overdue, two intervals overdue, dismissal, resume, and
   Philippine midnight rollover.
8. Compare outcome tables with known fixtures: archived losses, unknown statuses,
   empty denominators, and repeated observations in the same month.
9. Test each role across campus/college boundaries. Invalid sessions and forged
   owner/plant IDs must fail direct RPC calls.

These checks require a migrated staging database and physical-device testing;
unit tests alone cannot validate deployment or OS storage behavior.
