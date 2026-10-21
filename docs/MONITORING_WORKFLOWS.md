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
- Survival: plants with a recorded non-Dead health status divided by all records
  in that batch. Missing or unrecognized health statuses count as Needs
  Attention and remain in the denominator, but are not confirmed survivors.
  Archived records remain included so archiving losses cannot improve the rate.
- Coverage: active non-Dead plants inspected within the last 30 Philippine
  calendar days divided by active non-Dead plants. Empty denominators show N/A.
  This measures coverage, not inspection punctuality.
- Health trend: inspection observations grouped by month and status. Repeated
  inspections count separately; these are not unique-plant population estimates.
  Legacy records without observation time use submission time.

Outcome tables cover the authenticated account's full scope independently of the
other plant-report filters. Monitoring outcomes are available in-app and through
the Export Report dialog. They retain these same definitions in PDF and CSV.

## Printable reports and spreadsheets

Reports > Export Report offers plant inventory, inspection schedule, inspection
history, plant health summary, monitoring outcomes, and plants needing action.
Choose Print / Save PDF or Spreadsheet (CSV for Excel). CSV is not an XLSX workbook.
On native devices CSV uses the system save dialog; on web it uses a browser download.
PDF uses the existing print preview, including Save as PDF where supported.

All reports include account scope, preparer, generation time in Asia/Manila, and
filter/coverage notes. PDFs have repeating table headings and page numbers.
Long remarks continue across rows without being discarded. CSV quotes commas,
quotes and embedded newlines, uses UTF-8 with BOM, and neutralizes formula prefixes.

Except monitoring outcomes, exports use the matching active plants on the report
page. The page date range means **registration dates**. History additionally offers
an independent, inclusive inspection-observation date range in Asia/Manila.
Recorded observation health/stage are not replaced with a plant's current health.
The history's Current Next Due column is explicitly the current schedule, not a
historical next-due snapshot. Schedules exclude archived and Dead plants.
Action reports flag Needs Attention, overdue, due-today, or unscheduled plants;
follow-up suggestions are workflow prompts rather than treatment advice.

Before enabling exports in a deployed app, apply
`supabase/migrations/202610190005_report_inspection_history.sql` to Supabase.
It adds session-checked plant-scope validation and a role-scoped history RPC.
History batches contain at most 200 requested plant IDs and 500 observations per
page. Staff cannot request another assignment's observations. Outcome exports
reuse the existing session-checked `monitoring_outcomes` RPC. Failed validation or
history/outcome loading stops export rather than creating an incomplete report.

Rebuild the APK after dependency changes. Device acceptance: save a CSV to a chosen
folder, open it in Excel/Sheets, print/save each PDF type, cancel both dialogs, and
try all staff scopes plus an expired session. Verify database rejection for foreign
plant IDs, mixed permitted/foreign IDs, inactive staff and guests. Database and
installed-device acceptance remain required; local fixture tests do not prove them.

## Device and database acceptance checks

### Automatic damage reporting

Apply `supabase/migrations/202610200002_automatic_qr_damage.sql` to enable the
automatic damage flow. An assigned College Admin or Inspection Team member can
report Damaged Or Broken from a plant. It immediately marks that current QR
damaged and logs the report without requiring approval. Valid existing pending
damage reports are applied by the migration; obsolete assignments are closed
without changing their QR. No reports or audit history are deleted.

The plant record and QR code string stay unchanged. College Admins can reprint
the damaged QR in QR Management. The existing post-print confirmation still
restores the label only after it is physically ready. Inspection Teams do not
gain QR printing, restoration, replacement or retirement permissions.

QR Management's top Print action supports selecting a batch from Available,
Assigned or Damaged tags, using the current search across all matching pages.
Single and batch labels measure 2 × 2 inches (including title and QR code).
Batch PDFs use A4 sheets with three columns and five rows (15 labels per page).
Print at Actual Size / 100%, not Fit to Page, to preserve these measurements.
All Statuses keeps the available-only printing default. Retired and replaced
tags cannot be batch printed. On phones, use Print Batch. A damaged batch
retains the same QR codes; cancelling printing or choosing Keep Damaged does
not change status. Confirm All Ready only after every selected label has been
printed correctly and attached. Failed confirmations are reported separately
and can be retried. No additional migration is needed for batch selection;
restoring labels uses the existing QR reprint confirmation migration.

Damage history has no Confirm/Dismiss buttons or review note. Other problem
types retain their existing review flow. New clients use `report_qr_damage` so
an unapplied migration cannot silently create a pending report while claiming
the QR was damaged. Plants without an assigned QR, retired/replaced labels,
archived plants and foreign assignments are rejected. Repeated submissions while the same
QR remains damaged reuse the reporter's existing damage report.

After deployment, verify reporting, duplicate retries, foreign-assignment
rejection, preservation of retired/replaced labels, same-code reprinting and
post-print restoration against a live database and installed APK.

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
