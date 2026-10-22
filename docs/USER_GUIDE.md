![EcoTag campus trees](../assets/images/ecotag-campus-trees.png)

# USER GUIDE

## QR Code-Based Plant Management and Monitoring System

### Cagayan State University

2026

---

## Table of contents

1. [Introduction](#1-introduction)
2. [Target users](#2-target-users)
3. [System requirements](#3-system-requirements)
4. [Accessing the system](#4-accessing-the-system)
5. [Using the system by user role](#5-using-the-system-by-user-role)
   - [5.1 Super Admin](#51-super-admin)
   - [5.2 University Admin](#52-university-admin)
   - [5.3 Campus Admin](#53-campus-admin)
   - [5.4 College Admin](#54-college-admin)
   - [5.5 Inspection Team](#55-inspection-team)
   - [5.6 Guest](#56-guest)
6. [QR code scanning and plant monitoring](#6-qr-code-scanning-and-plant-monitoring)
7. [Generating reports](#7-generating-reports)
8. [Troubleshooting and frequently asked questions](#8-troubleshooting-and-frequently-asked-questions)
9. [Safe use and privacy](#9-safe-use-and-privacy)
10. [Related help](#10-related-help)

## 1. Introduction

EcoTag helps Cagayan State University staff register and monitor campus plants
using EcoTag QR labels. Guests can scan labels to view public plant
information. This guide explains what each page of the system is for and gives
step-by-step instructions for the tasks each account can perform.

Each account's instructions are in its own section in
[Section 5](#5-using-the-system-by-user-role). Read the section for your role;
you do not need the others. Each section first explains the pages you can open,
then walks through the processes you perform on that account.

## 2. Target users

EcoTag supports the following user roles. Staff access is limited by the
campus or college assignment configured for the account.

| User role | Typical tasks |
| --- | --- |
| Super Admin | Create and manage administrator accounts and review the activity log. |
| University Admin | Review university-wide plants, monitoring, and reports; manage the plant catalog and inspection interval. |
| Campus Admin | Review plant monitoring and reports for the assigned campus. |
| College Admin | Register and manage plants in the assigned college, manage QR tags and plant schedules, archive or restore records, and manage Inspection Team accounts. |
| Inspection Team | Register plants in the assigned college and complete assigned inspections, including offline work. |
| Guest | Scan QR labels and view public plant profiles without an account. |

## 3. System requirements

- A computer, tablet, or smartphone with access to the EcoTag website or
  installed application provided by the university.
- A current web browser when using the website. The project does not publish a
  minimum browser version; use a browser version supported by your device.
- An internet connection for staff sign-in, loading current records, and
  synchronizing changes. Inspection Team members can prepare assigned plants
  while online and record inspections offline within an established signed-in
  session.
- A camera and permission to use it when scanning a QR label in the app.
- A printer is optional and is needed only when printing QR labels or exported
  reports.

The project does not specify minimum device hardware or operating-system
versions. Ask your administrator for the approved site address or app build.

## 4. Accessing the system

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

Guests do not need an account. The full guest process is in
[5.6 Guest](#56-guest).

### Sign out

On the web, select the sign-out icon beside your name in the upper-right
corner. On a phone, open **More** and choose the sign-out option. Always sign
out on a shared device. Guests end their visit with **End Guest Visit** or the
**Exit Guest View** control.

### Getting around: web and phone

- **Web:** the left sidebar is the main navigation. It lists only the pages
  your role can open. **Help** in the sidebar opens the Help Center, where you
  expand your role to see its main tasks.
- **Phone:** use the bottom navigation for the main pages and tap **More** for
  the others. Roles that can scan show a round **Scan** button in the middle of
  the bottom bar. The Help Center is available from the web sidebar, not the
  phone **More** menu.

![EcoTag web Help Center with College Admin instructions expanded](./images/ecotag-web-help-center.png)

*Figure 4.1. Web Help Center with the College Admin guide expanded. The sidebar
on the left shows the pages available to this account.*

### Quick help on the phone dashboard

The phone dashboard can show a short **How To Use EcoTag** panel. It is only a
reminder; the full instructions are in your role's section.

![EcoTag dashboard quick-help panel](./images/ecotag-quick-help.png)

*Figure 4.2. Dashboard and quick-help panel on a phone.*

- **Scan A QR:** use the center **Scan** button, place the QR code inside the
  frame, and follow the result shown.
- **Find A Plant:** open **Plants**, search by name or tag, then tap a card to
  see its details.
- **Record An Inspection:** confirm the plant, add a current photo, select its
  condition, and save your observations.
- **Need more help?:** contact your College Admin, and open **Profile** to
  confirm your role, campus, and college.
- **Got It:** closes the panel. EcoTag only shows actions your account is
  allowed to use.

## 5. Using the system by user role

Each role section follows the same pattern:

1. **What this account is for.**
2. **Pages you can open:** each sidebar page, what it shows, and what you can
   do there.
3. **Processes:** numbered steps for the main tasks on that account.

Screenshot slots marked *Insert actual screenshot* must be filled with
screenshots captured from the deployed system while signed in as that role. Do
not use example images from another system.

---

### 5.1 Super Admin

**What this account is for.** The Super Admin account creates and controls the
administrator accounts (University Admin, Campus Admin, and College Admin). It
does not register plants and does not create Inspection Team accounts.

#### Pages you can open

The web sidebar shows **Dashboard**, **Manage Accounts**, **Activity Log**, and
**Help**. On a phone, the bottom bar shows **Dashboard**, **Accounts**, and
**Plants**, plus **More**.

**Dashboard**

> *Insert actual screenshot:* Figure 5.1. Super Admin dashboard.

An overview of EcoTag administrator accounts: how many exist and how many are
active. Select **Manage Accounts** on this page to go to account management.

**Manage Accounts**

> *Insert actual screenshot:* Figure 5.2. Manage Accounts list.

Lists every administrator account in a table with these columns:

- **ACCOUNT:** the username.
- **ROLE:** University Admin, Campus Admin, or College Admin.
- **ASSIGNMENT:** the campus or college the account is limited to.
- **STATUS / ACCESS:** whether the account is active or inactive.
- **ACTIONS:** the controls to edit, deactivate or activate, or archive it.

Use the search and the filters (**All Roles** or one role; **All Statuses**,
**Active**, or **Inactive**) to find an account. **Reset** clears the filters.
**Archived** shows archived accounts, and **Create Account** opens the new
account form.

**Activity Log**

A record of important changes made in EcoTag, so administrators can review who
changed what. It is read-only.

**Help**

The Help Center, with a step-by-step guide for each role.

#### Process: sign in and open the dashboard

1. Open the system website.
2. Enter the Super Admin username and password.
3. Select the sign-in button.
4. EcoTag opens the Super Admin dashboard.

#### Process: create an administrator account

1. Open **Manage Accounts**.
2. Select **Create Account**. The **Create Admin Account** form opens.
3. Enter the **Username** and a **Temporary Password**.
4. Choose the **Role**: University Admin, Campus Admin, or College Admin.
5. For a Campus Admin, choose the **Campus**. For a College Admin, choose the
   campus and **College**. A University Admin covers the whole university, so
   no campus or college is needed.
6. Save the account. Wait for the message *Admin account created.* and check
   that the account appears in the list.
7. Give the username and temporary password to the new administrator through a
   secure channel.

#### Process: edit, deactivate, or archive an account

1. Open **Manage Accounts** and find the account.
2. To change it, open **Edit Admin Account**. Update the username, role, or
   assignment. Enter a **New Password (optional)** only if you want to replace
   the password, then save.
3. To stop someone signing in without deleting the account, choose
   **Deactivate** and confirm. Activate the account again from the same
   controls when access should resume.
4. To retire an account, choose the archive action, enter the **Reason**, and
   select **Archive Account**. Open **Archived** to view archived accounts and
   restore one if needed.

#### Process: review the activity log

1. Open **Activity Log** from the sidebar (or **More** on a phone).
2. Read the entries and their dates to see which changes were made.

---

### 5.2 University Admin

**What this account is for.** The University Admin monitors plants across all
campuses, produces reports, maintains the plant catalog used during
registration, and sets the university-wide inspection interval. It does not
register plants or manage QR tags.

#### Pages you can open

The web sidebar shows **Dashboard**, **Plant Catalog**, **Inspection
Schedule**, **Plant List**, **Reports**, **Activity Log**, and **Help**.

**Dashboard**

> *Insert actual screenshot:* Figure 5.3. University Admin dashboard.

University-wide summary cards (such as **Total Plants**, **Healthy Plants**,
**Needs Attention**, and **Dead Plants**), campus overview, recent plants, and
due or overdue inspection reminders. Reminders appear inside the app only;
they are not email or push notifications.

**Plant Catalog**

> *Insert actual screenshot:* Figure 5.4. University Plant Catalog.

The list of plant classifications that staff pick from when registering a plant.
Each entry has a **Plant Type**, **Common Name**, and **Scientific Name**. You
can add a plant type (**Add type**), rename one (**Edit type**), add or edit a
classification, and remove a classification from the catalog.

**Inspection Schedule**

> *Insert actual screenshot:* Figure 5.5. Inspection Schedule settings.

Sets how often plants are inspected across the university, in days. Choose
from the interval options shown or enter a **Custom interval**.

**Plant List**

Browse and search every plant record in the university, filter by campus and
health status, and open a plant to read its profile and timeline. This page is
read-only for this role.

**Reports**

Analytics and exports for the whole university. See
[Section 7](#7-generating-reports).

**Activity Log**

Recorded changes to accounts and plants.

#### Process: add a plant type or classification

1. Open **Plant Catalog**.
2. To add a new type, select **Add type**, enter the **Plant Type**, and
   select **Add Type**.
3. To add a classification, choose the **Plant Type**, then enter the
   **Common Name** and **Scientific Name** and save.
4. To correct an entry, edit it and select **Save Changes**. To retire an
   entry, remove it and confirm **Remove from Catalog**.
5. Staff will see the entry the next time they register a plant.

#### Process: change the inspection interval

1. Open **Inspection Schedule**.
2. Choose an interval option or enter a **Custom interval** in days.
3. Read the confirmation carefully. The change applies to all campuses and
   resets the next inspection date of every active plant.
4. Select **Update Schedule** to confirm.

#### Process: find a plant and read its profile

1. Open **Plant List**.
2. Search by plant name, tag, variety, or campus. Use the campus and health
   filters to narrow the results.
3. Select a plant. Review its EcoTag code, classification, location, photos,
   condition, and its timeline of registration, inspections, and changes.

#### Process: generate a report

Follow [Section 7](#7-generating-reports).

---

### 5.3 Campus Admin

**What this account is for.** The Campus Admin monitors plants and reports for
one assigned campus. This account cannot register plants, manage QR tags, or
change schedules. If a record needs correcting, contact the College Admin or
administrator responsible for it.

#### Pages you can open

The web sidebar shows **Dashboard**, **Plant List**, **Reports**, **Activity
Log**, and **Help**.

**Dashboard**

> *Insert actual screenshot:* Figure 5.6. Campus Admin dashboard.

Summary cards, recent plants, and due or overdue reminders for your campus
only.

**Plant List**

Search and filter the plants in your campus and open a plant to read its
profile and timeline. Read-only for this role.

**Reports**

Analytics and exports for your campus. See
[Section 7](#7-generating-reports).

**Activity Log**

Recorded changes to accounts and plants in your scope.

#### Process: review campus monitoring

1. Sign in and open **Dashboard**. Check the totals and any due or overdue
   reminders.
2. Open **Plant List** and select **Needs Attention** or **Dead** to see plants
   that need action.
3. Select a plant to read its timeline and latest inspection.
4. Report problems to the College Admin of the plant's college.

#### Process: generate a report

Follow [Section 7](#7-generating-reports).

---

### 5.4 College Admin

**What this account is for.** The College Admin manages the plants of one
assigned college: registering plants, assigning and printing QR labels,
archiving and restoring records, managing inspection schedules, and creating
Inspection Team accounts for the college.

#### Pages you can open

The web sidebar shows **Dashboard**, **Register Plant**, **QR Management**,
**Inspection Accounts**, **Plant List**, **Inspections**, **Reports**,
**Activity Log**, and **Help**. On a phone, the bottom bar shows **Dashboard**,
**Plants**, **Inspections**, and **More**, with a center **Scan** button;
**Inspection Accounts** is named **User Management** in **More**.

**Dashboard**

> *Insert actual screenshot:* Figure 5.7. College Admin dashboard.

The starting point. It shows summary cards for your college (**Total Plants**,
**Healthy Plants**, **Needs Attention**, **Dead Plants**), recent plants,
shortcuts such as **Scan QR**, and due or overdue inspection reminders.

**Register Plant**

> *Insert actual screenshot:* Figure 5.8. Register Plant form.

The form for adding a new plant to your college. It asks for the plant's
classification, planting location, and optional photo. See the registration
process below.

**QR Management**

> *Insert actual screenshot:* Figure 5.9. QR Management.

Where QR tags are created, printed, and tracked. You can search by QR code or
ID, filter by **Tag Status**, **Generate** new tags, **Print Batch**, **Scan
QR**, mark a tag as damaged, and open **QR Problem Reports**.

**Inspection Accounts**

> *Insert actual screenshot:* Figure 5.10. Inspection Team accounts.

The list of Inspection Team accounts for your college. Use **Create Account**
to add one, and the row actions to edit, deactivate, or archive. **Archived**
shows archived accounts.

**Plant List**

> *Insert actual screenshot:* Figure 5.11. Plant Records list.

Browse and search your college's plants by name, tag, variety, or planter. Filter by
health status. Select **Register Plant** to add a plant. Archived plants can be
shown and restored from here.

**Inspections**

> *Insert actual screenshot:* Figure 5.12. Inspections queue.

The inspection queue and history. Filters separate plants that are overdue, due
today, or scheduled, and **History** lists past inspections (use **Load Older
Inspections** for more). **View Plant** opens the plant profile.

**Reports and Activity Log**

Reports for your college ([Section 7](#7-generating-reports)) and the log of
recorded changes in your scope.

**Plant profile**

> *Insert actual screenshot:* Figure 5.13. Plant Details.

Opening a plant from **Plant List** or **Inspections** shows its profile and
timeline. The buttons you may see are **Inspect Plant**, **Update Plant
Details**, **Report QR Problem**, **Archive**, and a pencil control to edit the
plant's **Inspection Schedule**.

#### Process: sign in and open the dashboard

1. Open the system website and enter your College Admin username and password.
2. Select the sign-in button.
3. Review the dashboard summary cards and reminders.

#### Process: register a plant

1. Select **Register Plant** from the sidebar (or the button on **Plant List**).
2. Enter the required plant details and choose the classification. Type a name
   directly into **Common Name**; a new name is saved with the plant.
3. Choose the planting campus and location from the available options. Campus
   and college come from your account.
4. Add a plant photo if you have one.
5. Review the information, then submit. Wait for the success message.
6. If you cannot finish, choose **Save draft on device**. Reopen registration
   with the same account to resume the draft. Drafts stay on that device.
7. Next, assign a QR tag to the plant (see the QR process below).

#### Process: generate and print QR tags

1. Open **QR Management**.
2. Select **Generate QR**, enter the **Number Of QR Tags**, and select
   **Generate**.
3. Select the tags you want to print and choose **Print Batch**, or print an
   individual tag from its row.
4. Stick the printed label on the plant, and keep the label and the plant record
   matched.

#### Process: replace a damaged QR tag

1. Open **QR Management** and find the tag by searching its QR code or ID.
2. Mark it as damaged, enter the **Reason**, and confirm.
3. Print the replacement tag and place it on the plant.
4. When the new label is on the plant, confirm **Confirm QR Ready**. Choose
   **Keep Damaged** if it is not ready yet.
5. Open **QR Problem Reports** to follow problems reported by staff.

#### Process: update, archive, or restore a plant

1. Open **Plant List** and select the plant.
2. Select **Update Plant Details**, change what is needed, and save.
3. To retire a plant, select **Archive**, enter the **Reason**, and confirm.
   Archiving removes it from active lists but keeps its profile and history.
4. To bring it back, open the archived records in **Plant List**, find the
   plant, and choose **Restore**.
5. To change how often one plant is visited, edit its **Inspection Schedule**,
   enter **Repeat Every (days)**, and select **Save Schedule**. The
   university-wide interval is set by the University Admin.

#### Process: create an Inspection Team account

1. Open **Inspection Accounts**.
2. Select **Create Account**.
3. In **Create Inspection Account**, enter the **Username** and a **Temporary
   Password**. The account is limited to your college automatically.
4. Save. Wait for *Inspection Team account created.*
5. Give the credentials to the inspector through a secure channel.
6. To stop access, choose **Deactivate**. To retire the account, archive it
   with a reason; restore it from **Archived** if needed.

#### Process: review inspections

1. Open **Inspections** and pick a filter such as overdue or due today.
2. Select a plant, or **View Plant**, to open its profile.
3. Choose **Inspect Plant** if you need to record an inspection yourself.
   Follow [Record an inspection](#process-record-an-inspection) in 5.5 (the
   form is the same).
4. Open **History** to read earlier inspections.

#### Process: generate a report

Follow [Section 7](#7-generating-reports).

---

### 5.5 Inspection Team

**What this account is for.** Inspection Team members work in the field. They
scan plant QR codes, inspect plants assigned to their college, record condition
and photos, register new plants, and can work offline and upload later. This
account cannot manage QR tags, accounts, or archive records.

#### Pages you can open

The web sidebar shows **Dashboard**, **Register Plant**, **Plant List**,
**Inspections**, **Reports**, and **Help**. On a phone, the bottom bar shows
**Dashboard**, **Plants**, **Inspections**, and **More**, with a center
**Scan** button.

**Dashboard**

> *Insert actual screenshot:* Figure 5.14. Inspection Team dashboard.

Summary cards for your college, due and overdue reminders, a **Scan QR**
shortcut, and **Offline Inspections And Pending Uploads**.

**Register Plant**

The form for adding a plant to your college. Use **Save draft on device** if
you cannot finish.

**Plant List**

Search your college's plants by name or tag and open a plant to read its
profile.

**Inspections**

> *Insert actual screenshot:* Figure 5.15. Inspection queue.

The queue of plants due for inspection and the history of past inspections.

**Offline Inspections**

> *Insert actual screenshot:* Figure 5.16. Offline Inspections.

Opened from the dashboard. It lets you **Download Assigned Plants For Offline
Work**, **Scan QR To Start An Offline Inspection**, review inspections saved on
the device, delete a local draft, and **Upload Pending Inspections**.

**Reports**

Monitoring information for your assigned scope.

#### Process: sign in

1. Open the system website or app.
2. Enter your Inspection Team username and password.
3. Select the sign-in button. EcoTag opens the dashboard.

#### Process: scan a plant QR code

1. On a phone, tap the round **Scan** button in the bottom bar. On the web,
   select **Scan QR** on the dashboard.
2. Allow camera access if asked.
3. Hold the code inside the frame, steady and well lit.
4. When the code is read, open the result and confirm that the plant matches
   the label.
5. Select **Inspect Plant** to begin an inspection, or just review the profile.
6. If the label is damaged or wrong, choose **Report QR Problem**.

#### Process: record an inspection

1. Open **Inspections** and select a plant due for inspection, or scan its QR
   code.
2. Check that the plant name, QR code, and location match the plant in front of
   you.
3. **Step 1, Photo (optional):** tap **Take Or Choose A Photo** and add a
   current picture of the plant.
4. **Step 2, Confirm The Condition:** choose the observed health condition and
   the growth stage. Both are required.
5. **Step 3, Add Observations:** describe what you see, for example yellow
   leaves on lower branches. Do not enter private personal information.
6. Select **Review and save** and confirm. Wait for *Inspection saved
   successfully.*
7. If the app says the inspection was saved on the device and is pending
   upload, keep it and upload it when you are connected.
8. Use **Save Draft** if you must stop before finishing.

#### Process: work offline and upload later

1. While online and signed in, open **Dashboard** and select **Offline
   Inspections And Pending Uploads**.
2. Select **Download Assigned Plants For Offline Work** before you go into the
   field.
3. In the field, scan the plant QR (**Scan QR To Start An Offline Inspection**)
   or open a downloaded plant and record the inspection as above.
4. Save a draft if unfinished, or review and save to store it as pending.
5. When connected again, select **Upload Pending Inspections**.
6. If an upload fails, keep the saved item and try again later. Do not record
   the same inspection twice.

Offline work needs an online sign-in first. After you close and restart the
app, sign in online again. Drafts and downloaded plants stay on that device and
may be lost if app data is cleared or the app is uninstalled.

#### Process: register a plant

1. Select **Register Plant**.
2. Enter the plant details, classification, and location, and add a photo.
3. Review and submit. Use **Save draft on device** if unfinished. Drafts do not
   move between devices.

#### Process: report a QR problem

1. Open the plant profile, or scan the code.
2. Select **Report QR Problem**, describe the problem, and submit.
3. The College Admin handles the replacement.

---

### 5.6 Guest

**What this account is for.** Guests are members of the public. They need no
account and no password. They can scan a plant's physical QR label and read its
public details. Guest access is read-only: guests cannot edit, register, or
inspect plants.

#### Pages you can see

**Access screen**

Choose **Guest Access** to continue without signing in. Staff choose the sign-in
option instead.

**Guest entry**

Asks for your age (required) and an optional name. Age is used for visitor
statistics. The name stays in the current visit and is not saved to the
database. Select **Continue As Guest**.

**Guest dashboard**

> *Insert actual screenshot:* Figure 5.17. Guest dashboard.

A public overview. Cards show **Registered Plants**, **Healthy Plants**, **Need
Attention**, and **Recorded Dead**, followed by a **Plant Health Overview** and
an **About EcoTag** section. The **Scan A Plant QR** button opens the scanner.
**Admin Or Inspection Team Sign In** is for staff only.

**Plant Details**

> *Insert actual screenshot:* Figure 5.18. Guest plant details.

The public profile shown after a scan, with **Plant Information**, **Managed
By**, and **Planting Location**.

#### Process: scan a plant and view its details

1. Choose **Guest Access** on the access screen.
2. Enter your age and, if you like, your name, then select **Continue As
   Guest**.
3. Select **Scan A Plant QR** (or the **Scan EcoTag** button).
4. Allow camera access if asked.
5. Hold the plant's QR label inside the frame until it is read.
6. Read **Plant Details**.
7. Select **Close Plant Details** to return to the dashboard. Scan another plant
   if you wish.

#### Process: leave the guest view

1. Select **End Guest Visit** (or the **Exit Guest View** control).
2. Confirm **End Visit**. Choose **Stay** to keep browsing.

---

## 6. QR code scanning and plant monitoring

This section explains the ideas behind the pages above. Do the tasks from your
own role section.

### Scanning tips

- Allow camera access when asked; scanning cannot work without it.
- Keep the whole QR code in the frame, steady, and well lit.
- If the code will not scan, clean the label, change the angle, or report it as
  a QR problem. Staff can report problems from the plant profile or scanner.
- Guests see only the public profile. Staff see the full profile and the actions
  their role allows.

### Plant profile and timeline

Staff profiles show the plant's EcoTag code, classification, campus and
location, photos, and current condition, together with a timeline of its
registration, inspections, and audited changes. Public profiles show only the
information meant for the public.

### Health conditions and inspection schedule

Plants are shown as **Healthy**, **Needs Attention**, or **Dead**. Every plant
has a schedule: the university-wide interval set by the University Admin, which
a College Admin can adjust for a single plant. An inspection is **Due Today** on
its due date and **Overdue** afterwards. Reminders appear inside the app only.

### Archived and Dead plants

Archived and Dead plants are locked. If the app blocks an action, contact your
College Admin instead of trying to work around it.

## 7. Generating reports

Reports are available to the University Admin, Campus Admin, College Admin, and
Inspection Team, each limited to their own scope. The Super Admin sidebar and
the guest view have no Reports page.

> *Insert actual screenshot:* Figure 7.1. Reports & Analytics with filters and
> result summary.

Open **Reports** from staff navigation to see the information available for
your assigned scope. Report content varies by role. Current monitoring
outcomes include survival by planting month, 30-day inspection coverage by
college, and monthly health observations.

1. Use the search box to find plants by plant name, QR code, campus, college,
   or variety. On desktop, choose **Filters**; on a phone, tap the filter
   control.
2. Select the available registration date range, campus, college, plant type,
   health status, and growth stage filters. Campus and college choices depend
   on your role and scope.
3. Choose **Apply Filters** to update the report. Review the matching plant
   count and analytics; use **Reset** or **Clear All** to remove filters.
4. To create a file, choose **Export Report**. Select the report type and
   either **Print / Save PDF** or **Spreadsheet (CSV for Excel)**, then choose
   **Continue**. For an Inspection History export, you can set or clear an
   inspection date range.
5. Follow the print dialog to print or save the PDF, or check your device's
   downloads for the CSV file.

> *Insert actual screenshot:* Figure 7.2. Export Report options.

Plant inventory, schedule, history, health, and action exports use the matching
active plants and page filters. The page's date filter is the plant
registration date, not its planting or inspection date. Monitoring Outcomes
use the full assigned scope and are not changed by the page filters.

Read report titles and definitions before comparing values:

- The monitoring outcome tables are independent of the current plant-list
  filters.
- Inspection coverage counts plants inspected during the period; it does not
  measure whether inspections were completed on schedule.
- Archived records remain part of survival/history reporting, while archived
  and Dead plants are excluded from current inspection coverage.

## 8. Troubleshooting and frequently asked questions

| Issue | What to do |
| --- | --- |
| Sign-in rejected | Check credentials and connectivity; ask an administrator to confirm the account is active and correctly assigned. |
| Dashboard or report is missing records | Check the selected filters and your role's campus/college scope. Ask an administrator if your assignment appears wrong. |
| Camera does not scan a label | Grant camera permission, improve lighting, center the QR code, and retry. Report a damaged or incorrect tag through the QR problem flow. |
| Offline plant or lookup is unavailable | Download assigned plants and inspection options while online before leaving for the field. |
| Inspection upload fails | Keep the pending inspection on the device, reconnect, and retry upload. Contact support if it continues to fail. |
| A plant cannot be changed or inspected | The record may be archived or Dead, or your role may not have permission. Contact the College Admin. |
| Registration or inspection draft is missing | Check the same device and account. Drafts do not sync between devices; cleared app/browser storage may remove them. |

## 9. Safe use and privacy

- Sign out on shared devices and keep your staff credentials private.
- Do not clear app/browser storage while offline work or drafts are still
  needed.
- Do not rely on an offline draft as a completed server submission; verify
  upload status after reconnecting.
- Guests should not enter staff credentials. Guest access is designed for
  read-only plant information.
- If you see an incorrect plant record, QR assignment, or account scope, report
  it to the appropriate administrator instead of making an unrelated change.

## 10. Related help

- [Project overview and feature map](./PROJECT_GUIDE.md)
- [Monitoring and report definitions](./MONITORING_WORKFLOWS.md)
- [Registration drafts](./REGISTRATION_DRAFTS.md)
- [Remembered sign-in](./PERSISTENT_SIGN_IN.md)
- [QR problem reporting](../supabase/QR_PROBLEM_REPORTS.md)
