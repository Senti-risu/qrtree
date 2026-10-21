# Android inspection reminders

Open More → Inspection Reminders, enable reminders, choose a Philippine time
(default 8 AM), and allow Android notifications. Use Test Notification to check
the channel. Summaries are scheduled for the next 30 days from the last downloaded
inspection queue; reopen the app regularly to refresh. Completed, Dead, and
archived plants are excluded. Registration, inspection sync, schedule changes,
archive/restore/reopen and app resume refresh reminders. Logout cancels them.

No Firebase or server push is used. Inexact Android alarms avoid requiring exact
alarm access. Notification banners, reboot delivery, battery restrictions and
timing depend on device settings. Force-stopping EcoTag can stop alarms until
it is reopened. A network connection is required to update schedules and validate
the session when opening the queue from a notification.

Device acceptance check:
1. Install the updated APK and sign in as a scoped staff account.
2. Enable reminders, allow notifications and tap Test Notification.
3. With a due inspection, set the reminder time a few minutes ahead.
4. Close the app normally (do not force-stop), wait and tap the notification.
5. Verify the inspection queue opens after session validation.
6. Complete/archive a plant and reopen the app; verify pending counts update.
7. Log out, sign in with a different account, and verify no previous-account
   reminders remain. Also check reboot and denied-permission behavior.
