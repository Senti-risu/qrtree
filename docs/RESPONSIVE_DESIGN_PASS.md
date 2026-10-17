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
- Registration navigation, refresh, and logout check for unsaved work. Saving
  blocks leaving the form. Desktop registration retains its full-form layout.
- Phone plant records use a single lazy scrolling page, including filters and
  registration. Cards show health, physical planting location, managing college
  and campus, and the last inspection date. Managing campus is never presented
  as the physical location when that location is unknown.
- Plant, QR, and inspection filters share a height-limited sheet with scrollable
  choices and fixed Reset/Apply controls. Plant and inspection sheets preview the
  matching result count; QR filtering reloads server-scoped results on Apply.
- Desktop plant health choices wrap instead of disappearing in a horizontal row.
- College Admin and Inspection Team dashboards lead with inspection work and
  health overview; Scan QR is the primary work-card action. Charts stay hidden
  for zero/one plant, and recent plants remain alongside quick actions on desktop.
- Health wording is Healthy / Needs attention / Dead, including reports. Raw
  database enum strings and IDs are not changed.

## Verification

`test/mobile_design_layout_test.dart` checks every staff role at 320×600,
390×844, and 844×390 with enlarged text, scanner clearance, keyboard clearance,
navigation guards, four-step progress, and wrapping plant cards. Cards also run
at 1440×1000. The filter footer is tested in short landscape with enlarged text.
A generated component preview is written to `build/layout_previews/` for visual
inspection. Existing tests cover dashboard grid and detail presentation layouts.

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
