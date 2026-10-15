# QR problem reports

Run `migrations/202610150001_qr_problem_reports.sql` in the project's Supabase SQL Editor after the existing migrations. The script runs in a transaction and is safe to rerun.

Inspection Team: open a plant from Plants (or by scanning an assigned label), choose **Report QR problem**, select a problem, and describe what happened. Missing or unreadable labels can be reported from Plants without scanning. **More → QR problem reports** shows the team's own reports and review notes.

College Admin: open **QR Management → QR problem reports** or the mobile More menu. Confirming a pending report marks its label damaged; dismissing leaves the label unchanged. Confirmed labels are handled through the existing **Damaged → Replace label** workflow. Reprinting and reactivation are separate features and are not added by this migration.

Reports preserve the QR ID at the time of submission. Reports for an old label cannot mark a newer replacement damaged. All writes validate the active application session and assigned campus/college in the database. Inspection Team members cannot review reports or change QR lifecycle state. Repeated pending reports from the same person for the same label are rejected. Reporting alone does not block scanning.

After deployment, verify with real accounts:

1. Inspection Team submits a report for an active plant in its college.
2. The report appears in that person's history and its College Admin's queue.
3. Another college cannot submit or review the report; another team member cannot see the reporter's history.
4. Confirming changes the QR to damaged and records audit history. Dismissing leaves its lifecycle unchanged.
5. Replace the QR before reviewing an older report: confirmation must fail and dismissal must remain available.

Check installation with this read-only query:

```sql
select p.oid::regprocedure as function_signature
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('report_qr_problem', 'list_qr_problem_reports', 'review_qr_problem_report');
```

The result should contain three functions.
