# EcoTag responsive design pass

The active root Flutter app keeps its green/white identity, Roboto typography,
role permissions, database values, and existing routes. The UI reference project
is not changed. No new SQL migration is needed for this design pass.

## Changes

- Shared cards use 16 px padding on phones and 24 px on larger screens unless a
  screen explicitly sets its own padding. Controls retain 48 px minimum targets.
- All staff navigation uses four destinations around the docked scanner. Active
  destinations have a visible background. Registration highlights Plants.
- AppShell reserves scanner clearance centrally. Navigation and scanner hide
  while the keyboard is open; registration actions remain above the keyboard.
- Phone/tablet registration follows Plant → Location → Photo → Review. Back and
  Continue stay outside the scrolling form. Existing controller values and the
  selected photo survive step changes; this is not an offline/autosaved draft.
- Registration navigation and logout check for unsaved work. Saving
  blocks leaving the form. Desktop registration retains its full-form layout.
- Phone plant records use a single lazy scrolling page, including filters and
  registration. Cards show health, physical planting location, managing college
  and campus, and the last inspection date. Managing campus is never presented
  as the physical location when that location is unknown.
- Plant, QR, and inspection filters share a height-limited sheet with scrollable
  choices and fixed Reset/Apply controls. Plant and inspection sheets preview the
  matching result count; QR filtering reloads server-scoped results on Apply.
- Desktop plant health choices wrap instead of disappearing in a horizontal row.
- Desktop Plant Records and Reports use a compact two-row filter toolbar: search
  and actions above health choices and the result count. Repeated headings and
  helper text are removed. Report date/type/growth/scope options remain available
  through Filters, with active selections summarized beside the result count.
- College Admin and Inspection Team dashboards lead with inspection work and
  health overview; Scan QR is the primary work-card action. Charts stay hidden
  for zero/one plant, and recent plants remain alongside quick actions on desktop.
- Health wording is Healthy / Needs attention / Dead, including reports. Raw
  database enum strings and IDs are not changed.
- Manual refresh buttons are removed across staff and guest pages, including
  detail and QR report headers. QR Management also removes its status-guide
  help button. Automatic reloads after changes, existing pull-to-refresh gestures,
  and error-recovery Retry/Try again controls are retained.
- Desktop QR columns fill the whole list panel proportionally. The table scrolls
  horizontally when narrow or enlarged text needs more room; long codes wrap.
  Inspection overview uses full-width count tiles, a full-width last-inspection
  strip, and expanding action buttons within the equal-height dashboard row.
  Phone widths and enlarged text stack these controls instead of clipping them.
- Admin account lists (University/Campus/College Admin and Inspection Team) share
  an Active/Inactive status-access button and directly visible Edit/Archive
  actions. Mobile identity and action layouts are shared and wrap for large text.
  Existing account-management authority, deactivate/archive confirmations, archive
  reasons, and restore-as-inactive behavior remain unchanged. Pending account
  actions disable repeat clicks for that account.
- QR tag rows also show their actions directly, without a three-dot menu:
  Available → Retire label; Assigned → Mark damaged; Damaged → Replace label.
  Print remains available under its existing rules; final states do not gain
  new lifecycle actions. QR status is informational, not an arbitrary toggle.
  Mobile actions wrap below the tag details, and desktop rows expand as needed.

## Verification

`test/mobile_design_layout_test.dart` checks every staff role at 320×600,
390×844, and 844×390 with enlarged text, scanner clearance, keyboard clearance,
navigation guards, four-step progress, and wrapping plant cards. Cards also run
at 1440×1000. The filter footer is tested in short landscape with enlarged text.
A generated component preview is written to `build/layout_previews/` for visual
inspection. Existing tests cover dashboard grid and detail presentation layouts.

Dashboard neighbors now share equal widths and the tallest content height:
Inspection Overview/Plant Health Overview, Quick Actions/Recent Plants, and
all four statistic cards within their grid. Stacked mobile sections keep natural
heights. The shared layout measures actual content, including LayoutBuilder-based
tables, rather than assigning a fixed height. `equal_height_cards_test.dart`
checks matching sizes, enlarged text, narrow widths, resizing, and taps.

Typography uses shared logical sizes in `AppTypography`: page titles 24,
section headings 18, body/item titles/control labels 14, captions 12, and
dashboard/report metrics 26. Matching dashboard, report, inspection, account,
plant-detail and common form levels use these tokens or the matching theme
styles. Roboto, compact tracking and system text scaling remain enabled.
Landing-page display lettering, branding, navigation and PDF export typography
retain their distinct purposes. `app_typography_test.dart` checks theme/control
sizes and real section headings at normal and enlarged text scales.

Plant Details now uses a compact bordered photo/identity panel, a horizontal
EcoTag copy action on wide screens, equal-height paired information cards, and
one wrapping Plant actions panel. Schedule fields share the same label/value
layout as other details. Dates and health labels are formatted for display only;
record values, permissions, dead-plant locks and action callbacks are unchanged.
`plant_detail_design_test.dart` covers 320/600/1080 widths, double text size,
neighboring card geometry and action taps, and renders a desktop preview.

The staff Plant Details view now uses the requested phone-style presentation on
web as well: a floating dialog capped at 640 logical pixels, with QR, photo/name,
managing assignment, classification (in registration field order), physical
location, inspection schedule, and stacked actions. Narrow web screens still
use the full-screen route. The general paired-card component remains available
for other views, but staff details no longer uses side-by-side sections.

Inspections now uses the shared full-width page heading, aligned filters and
content, 16-pixel section gaps, and a content-sized empty-state card rather than
stretching it to the remaining window height. Desktop queue filters wrap;
phone filters scroll horizontally. Short windows and enlarged text can scroll
the page header/filter sections without overflowing. Empty queue views offer
View upcoming or View history using the existing queue selection behavior.
`inspection_queue_layout_test.dart` checks alignment, short windows, text scale,
all mobile filter taps, and a rendered desktop preview.

## Consistent staff workspace layout

- List/report pages share `AppWorkspacePage`: full-width heading/actions, tools,
  then independently scrolling results with 16-pixel gaps. This is used by Plant
  Records (desktop), QR Management (desktop), account management, activity logs,
  reports and the inspection queue. Existing mobile plant/QR sliver lists stay
  intact so long lists retain lazy loading and scanner clearance.
- All page headings use a 20-pixel inset; filter cards use `AppToolbarCard` with
  a 16-pixel inset. Titles/subtitles and primary/secondary action styles share
  theme sizes. Long headings/actions stack on smaller or enlarged-text layouts.
- `AppTablePanel` lets QR/account table surfaces end after the last row instead
  of filling the unused window with white. Table headings default to 48 pixels,
  rows to at least 56 pixels, and cells may grow for wrapping/large text.
- Plant, QR, account, activity and inspection empty states share one content-sized card.
  Existing reset/history/upcoming actions retain their callbacks.
- Short windows and text scaling of 1.4 or above let heading/tools scroll out of
  the way. Dashboard and registration retain their task-specific content flow,
  but use the same full-width headers, 16-pixel section gaps and aligned cards.
- No database, role permissions, exports, QR lifecycle or registration rules
  change in this visual pass. Landing/auth screens retain their separate layout.

`app_workspace_page_test.dart` checks seven heading/action configurations at
320/600/1440 widths and 1x/2x text, compact tables, short-window reachability and
adoption of the shared component. QR/account preview PNGs are rendered from the
shared widgets with sample records, not a live signed-in Supabase session.

## Guest scanner retry

Guest scanning now uses normal camera detection rather than permanent native
duplicate suppression. The UI accepts the same code again on Try again/Scan
again or explicit manual entry. It still blocks concurrent requests and holds
the previous label after a result so it cannot flood lookup requests or reopen
a profile immediately on return. A different label remains scannable. Camera
frames are ignored while the manual-entry dialog is open. The existing public
guest lookup RPC and read-only access rules are unchanged; no new SQL is needed.
`guest_scanner_retry_test.dart` exercises these paths using simulated camera
events and a fake guest lookup. Camera permission and actual device scanning
still need a check on the installed APK or supported secure browser.

Before distributing an APK, manually test on an actual phone:

1. Register as College Admin and Inspection Team. Move backward through all four
   steps and confirm selections, typed values, and the optional photo remain.
2. Open the keyboard, rotate the phone, and confirm form fields and actions remain
   reachable. Cancel a discard prompt from Plants, More, and desktop navigation.
3. Check inside-campus and outside-campus plant cards against Plant Details.
4. Apply, reset, and dismiss each filter sheet; dismissal must not apply pending
   changes. Scroll through a long QR/plant list and reach the final record.
5. Confirm scanner, camera/gallery permissions, registration, and inspection
   submission on the installed app. Automated layout checks do not replace these
   native-device tests.
