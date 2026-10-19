# EcoTag user guide

EcoTag helps Cagayan State University staff register and monitor campus plants
using EcoTag QR labels. Guests can scan labels to view public plant
information. This guide explains the main tasks in the app; the options you see
depend on your account role and assigned campus or college.

## Getting started

### Staff sign-in

1. Open EcoTag and choose the staff access/sign-in option.
2. Enter the username and password provided by your administrator.
3. After a successful sign-in, EcoTag opens the dashboard for your account.
4. Staff can normally reopen the app on the same device without signing in
   again while the saved session is valid.

If you cannot sign in, check your username and password and confirm that your
account is active. Contact your administrator if the account is inactive, has
no assigned role or scope, or you do not know your credentials. Do not share
your password or device session token.

### Guest access

1. Choose guest access from the access screen.
2. Enter your age (required). Your name is optional.
3. Select **Continue As Guest**.
4. Use the guest dashboard to scan a plant QR label and view its public
   profile.

Guest profiles are read-only. The app records age for statistics; an optional
name stays within the current visit and is not sent to the database.

## What you can do by role

| Your account | Typical tasks |
| --- | --- |
| Super Admin | Manage administrator accounts and review university-wide information. |
| University Admin | Review university-wide plants, monitoring, and reports. |
| Campus Admin | Review plant monitoring and reports for the assigned campus. |
| College Admin | Register and manage plants in the assigned college, manage QR tags and schedules, restore or archive records, and manage Inspection Team accounts. |
| Inspection Team | Register plants in the assigned college and complete assigned inspections, including offline work. |
| Guest | Scan QR labels and view public plant profiles. |

Some screens and actions may not appear for your account. Access also depends
on the campus/college assignment configured by your administrator.

## Dashboard and navigation

The dashboard is the main starting point for staff tasks. Depending on your
role, it can show plant and inspection summaries, recent records, shortcuts,
and due or overdue inspection reminders. Select a dashboard action or use the
app navigation to open the relevant plant, inspection, QR, report, or account
area.

Reminders are displayed in the app. They are not email, push, or background
notifications. A reminder dismissal lasts until the next Philippine calendar
day.

## Find and view a plant

1. Open the plant list or scan a QR label using the staff scanner.
2. Use available search and filters to narrow the list.
3. Select a plant to open its details.
4. Review its EcoTag code, classification, campus/location, photos, condition,
   and inspection/change history as available to your role.

The staff profile can include a chronological timeline of registration,
inspection evidence, and audited record changes. Public guest details are
read-only and show only information intended for public viewing.

## Register a plant

Plant registration is available to authorized College Admin and Inspection
Team accounts in their assigned college.

1. Open **Register Plant** from the dashboard or staff navigation.
2. Complete the required plant details and select the appropriate
   classification and location options. Type directly into **Common Name**,
   including when it is not already listed; a new name is saved with the plant
   registration. Scientific Name can be typed when no name is already saved
   for the matching classification.
3. Add a plant photo if available and complete the remaining form sections.
4. Review the information before submitting.
5. Submit the registration and wait for the success or error message before
   leaving the screen.

Campus and college scope come from your account assignment. Choose from the
available location options; Campus, Town, and Barangay are selection-only in
the current app.

### Save a registration draft

Registration drafts are saved only when you explicitly choose **Save draft on
device**. If leaving the form, choose whether to save, discard, or stay. Reopen
registration using the same account and assignment to resume the draft. Drafts
are not shared between devices and may be lost if app/browser data is cleared
or the app is uninstalled. Save before force-closing the app.

See [registration draft details](./REGISTRATION_DRAFTS.md) for photo limits,
scientific-name behavior, and important recovery instructions.

## QR labels

### Scan a label

- Staff: open the staff QR scanner. The action available after scanning depends
  on your role and the label/plant status.
- Guest: use the scanner from guest access to open the public plant profile.

Allow camera access when prompted. If the camera cannot read the code, make
sure the label is visible, well-lit, and not badly damaged, then retry. Staff
can report a QR problem from the available reporting flow.

### Manage, print, or replace labels

QR tag management is available to College Admin accounts. Use the QR
management area to review tag availability and assignment, then follow the
screen prompts for assigning or replacing a label. Confirm reprints or
replacements carefully so the physical label and plant record remain in sync.
Use the print or batch-print actions when provided by the screen.

## Complete an inspection

Inspection Team members use the inspection queue and plant inspection form.
College Admins may also manage inspection schedules.

1. Open the inspection queue/history and choose an assigned plant that is due
   for inspection.
2. Record the observation, select the applicable health and growth statuses,
   and add photos/evidence as appropriate.
3. Review the information and confirm/save the inspection.
4. Check the inspection history or pending uploads to confirm its status.

An inspection records the observed condition and the time it was observed.
Archived and Dead plants are subject to restrictions; if the app blocks an
action, contact your College Admin rather than trying to work around the lock.

## Work offline and upload later

Offline inspection work must be prepared while online and signed in:

1. Open **Dashboard → Offline inspections and pending uploads**.
2. Choose **Download Assigned Plants For Offline Work** before going into the
   field.
3. Open a downloaded plant and record the inspection. Save a draft if it is
   unfinished.
4. When ready, review and save it as a pending inspection.
5. Once connected again, choose **Upload Pending Inspections**.
6. If an upload fails, leave the saved submission in place and retry when the
   connection is available.

Sign in online before a field session. Offline work is available only within
the established signed-in session; after restarting the app, an online sign-in
is required. Drafts, cached plants, and photos stay on that device and may be
lost if its app data is cleared or the app is uninstalled. Do not create a
second inspection to replace a pending one unless the original is obsolete and
has been explicitly removed.

## Reports and exports

Open **Reports** from staff navigation to see the information available for
your assigned scope. Report content varies by role. Current monitoring
outcomes include survival by planting month, 30-day inspection coverage by
college, and monthly health observations. The existing PDF export is the
filtered plant report.

Read report titles and definitions before comparing values:

- The monitoring outcome tables are independent of the current plant-list
  filters.
- Inspection coverage counts plants inspected during the period; it does not
  measure whether inspections were completed on schedule.
- Archived records remain part of survival/history reporting, while archived
  and Dead plants are excluded from current inspection coverage.

## Account management and activity

Account tools depend on your role. Super Admins manage administrator accounts.
College Admins can manage Inspection Team accounts in their college. Where
available, the activity log provides an audit trail of record changes. Ask
your administrator to correct account scope or access; changing roles or
assignments is not a guest/staff self-service action.

## Common issues

| Issue | What to do |
| --- | --- |
| Sign-in rejected | Check credentials and connectivity; ask an administrator to confirm the account is active and correctly assigned. |
| Dashboard or report is missing records | Check the selected filters and your role's campus/college scope. Ask an administrator if your assignment appears wrong. |
| Camera does not scan a label | Grant camera permission, improve lighting, center the QR code, and retry. Report a damaged or incorrect tag through the QR problem flow. |
| Offline plant or lookup is unavailable | Download assigned plants and inspection options while online before leaving for the field. |
| Inspection upload fails | Keep the pending inspection on the device, reconnect, and retry upload. Contact support if it continues to fail. |
| A plant cannot be changed or inspected | The record may be archived or Dead, or your role may not have permission. Contact the College Admin. |
| Registration or inspection draft is missing | Check the same device and account. Drafts do not sync between devices; cleared app/browser storage may remove them. |

## Safe use and privacy

- Sign out on shared devices and keep your staff credentials private.
- Do not clear app/browser storage while offline work or drafts are still
  needed.
- Do not rely on an offline draft as a completed server submission; verify
  upload status after reconnecting.
- Guests should not enter staff credentials. Guest access is designed for
  read-only plant information.
- If you see an incorrect plant record, QR assignment, or account scope, report
  it to the appropriate administrator instead of making an unrelated change.

## Related help

- [Project overview and feature map](./PROJECT_GUIDE.md)
- [Monitoring and report definitions](./MONITORING_WORKFLOWS.md)
- [Registration drafts](./REGISTRATION_DRAFTS.md)
- [Remembered sign-in](./PERSISTENT_SIGN_IN.md)
- [QR problem reporting](../supabase/QR_PROBLEM_REPORTS.md)
