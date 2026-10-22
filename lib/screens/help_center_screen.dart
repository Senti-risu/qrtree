import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../widgets/app_card.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_shell.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  static const _guides = <_RoleGuide>[
    _RoleGuide(
      role: AppRole.superAdmin,
      pages: [
        _GuidePage(
          'Dashboard',
          'Shows administrator account totals and how many are active.',
        ),
        _GuidePage(
          'Manage Accounts',
          'Lists University, Campus, and College Admin accounts. Create, edit, activate, deactivate, archive, or restore them here.',
        ),
        _GuidePage('Activity Log', 'Read-only record of system changes.'),
        _GuidePage('Help', 'This page.'),
      ],
      steps: [
        'Open Dashboard to review administrator account totals and active accounts.',
        'Choose Manage Accounts, then Create Account to add a University Admin, Campus Admin, or College Admin. Set the role and required campus or college assignment.',
        'Search and filter accounts to activate, deactivate, archive, or restore access.',
        'Open Activity Log to review recorded system changes.',
      ],
    ),
    _RoleGuide(
      role: AppRole.universityAdmin,
      pages: [
        _GuidePage(
          'Dashboard',
          'University-wide plant counts, health summary, and inspection reminders.',
        ),
        _GuidePage(
          'Plant Catalog',
          'Plant types and classifications that appear when plants are registered.',
        ),
        _GuidePage(
          'Inspection Schedule',
          'The university-wide inspection interval, in days.',
        ),
        _GuidePage(
          'Plant List',
          'All plant records across campuses. Open one to see its profile and timeline.',
        ),
        _GuidePage(
          'Reports',
          'Filter plant records, review outcomes, and export reports.',
        ),
        _GuidePage('Activity Log', 'Read-only record of changes.'),
      ],
      steps: [
        'Review university-wide monitoring summaries and reminders on Dashboard.',
        'Use Plant List to find records and open a plant profile or timeline.',
        'Use Reports to review monitoring outcomes and export the filtered plant report.',
        'Use Plant Catalog to add plant types and classifications for registration.',
        'Use Inspection Schedule to change the university-wide interval. Confirm carefully: this resets next inspection dates for active plants across all campuses.',
        'Use Activity Log to review recorded changes.',
      ],
    ),
    _RoleGuide(
      role: AppRole.campusAdmin,
      pages: [
        _GuidePage(
          'Dashboard',
          'Summary and reminders for your assigned campus.',
        ),
        _GuidePage(
          'Plant List',
          'Plant records in your campus. Open one to see its profile and timeline.',
        ),
        _GuidePage('Reports', 'Campus-scope analytics and exports.'),
        _GuidePage('Activity Log', 'Read-only record of changes.'),
      ],
      steps: [
        'Review assigned-campus summaries and reminders on Dashboard.',
        'Use Plant List to search and filter campus records, then open a profile to review its details and timeline.',
        'Use Reports to review available analytics and export the filtered plant report.',
        'Use Activity Log to review recorded changes.',
        'Contact the appropriate administrator if a plant, account, or assignment needs correction; this role does not have plant registration or QR management controls.',
      ],
    ),
    _RoleGuide(
      role: AppRole.collegeAdmin,
      pages: [
        _GuidePage(
          'Dashboard',
          'Summary and reminders for your assigned college.',
        ),
        _GuidePage(
          'Register Plant',
          'Form for adding a new plant to your college.',
        ),
        _GuidePage(
          'QR Management',
          'Generate, print, scan, and manage QR tags, including damaged and replacement tags and QR problem reports.',
        ),
        _GuidePage(
          'Inspection Accounts',
          'Create and manage Inspection Team accounts for your college (called User Management on phones).',
        ),
        _GuidePage(
          'Plant List',
          'Your college plant records. Open one to inspect, edit, report a QR problem, or archive.',
        ),
        _GuidePage(
          'Inspections',
          'Queue of plants to inspect and the inspection history.',
        ),
        _GuidePage('Reports', 'College-scope analytics and exports.'),
        _GuidePage('Activity Log', 'Read-only record of changes.'),
      ],
      steps: [
        'Review assigned-college summaries and reminders on Dashboard.',
        'Use Plant List to find records or Register Plant to add a plant to your assigned college.',
        'Open a plant profile to review its timeline, edit available details, report a QR problem, or archive an active plant. Archived records can be restored from Plant List.',
        'Use QR Management to generate, print, scan, and manage QR labels, including damaged or replacement tags.',
        'Use Inspection Accounts to create, update, archive, or restore Inspection Team accounts for your college.',
        'Use Inspections to review the queue and history. Individual plant schedules can be managed from plant records where available; the university-wide interval is set by University Admins.',
        'Use Reports and Activity Log to review college-scope monitoring and recorded changes.',
      ],
    ),
    _RoleGuide(
      role: AppRole.inspectionTeam,
      pages: [
        _GuidePage(
          'Dashboard',
          'Monitoring summary and reminders for your college.',
        ),
        _GuidePage('Scan button', 'Opens the camera to scan a plant QR label.'),
        _GuidePage(
          'Register Plant',
          'Form for adding a plant; unfinished forms can be saved as a device draft.',
        ),
        _GuidePage('Plant List', 'Plant records in your college.'),
        _GuidePage(
          'Inspections',
          'Assigned plants to inspect and your inspection records.',
        ),
        _GuidePage('Reports', 'Monitoring information for your scope.'),
      ],
      steps: [
        'Review assigned-college monitoring and reminders on Dashboard.',
        'Find a plant in Plant List or scan its QR label, then review its profile.',
        'Use Register Plant to add a plant to your assigned college. Save a device draft if the form is unfinished.',
        'Open Inspections, select an assigned plant, record its condition and observations, add an optional photo, then choose Review and save.',
        'For offline field work, sign in online and download assigned plants first. Save and review inspections on the same device, then upload pending inspections after reconnecting.',
        'Report damaged or incorrect QR labels from the plant profile or scanner. Use QR Problem Reports to follow reports where available.',
        'Use Reports to review monitoring information for your assigned scope.',
      ],
    ),
    _RoleGuide(
      role: AppRole.unknown,
      title: 'Guest',
      pages: [
        _GuidePage(
          'Guest dashboard',
          'Public counts of registered, healthy, needing-attention, and dead plants, plus an About EcoTag section.',
        ),
        _GuidePage(
          'Scan a plant QR',
          'Opens the camera to read a plant label.',
        ),
        _GuidePage(
          'Plant Details',
          'Read-only plant information, who manages it, and where it is planted.',
        ),
      ],
      steps: [
        'Choose Guest Access, enter your age, optionally enter your name, and continue.',
        'Choose Scan A Plant QR, allow camera access if prompted, and center the label in the camera view.',
        'Open the scan result to review the public plant profile. Guest access is read-only.',
        'Exit Guest View or end the visit from the guest account/navigation area when finished.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final userRole = AppRole.fromValue(role);
    final visibleGuides = _guides
        .where((guide) => guide.role == userRole)
        .toList();
    final guides = visibleGuides.isEmpty ? _guides : visibleGuides;
    return AppShell(
      activeRoute: '/help',
      mobileTitle: 'Help',
      mobileSubtitle: 'Role guides and common tasks',
      userId: userId,
      username: username,
      role: role,
      campusId: campusId,
      collegeId: collegeId,
      userName: username,
      userRole: userRole.label,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: 'Help Center',
              subtitle: guides.length == 1
                  ? 'Step-by-step instructions for your ${guides.first.label} account.'
                  : 'Step-by-step instructions for EcoTag users. Expand a role to see its main tasks.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: AppColors.surface,
                child: Column(
                  children: [
                    for (var index = 0; index < guides.length; index++) ...[
                      _GuideExpansion(
                        guide: guides[index],
                        initiallyExpanded: guides.length == 1,
                      ),
                      if (index < guides.length - 1)
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Useful reminders',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  _ReminderLine(
                    text:
                        'Your role and campus/college assignment determine which records and actions are available.',
                  ),
                  _ReminderLine(
                    text:
                        'Offline inspections must be prepared while online. Pending work stays on the same device until uploaded.',
                  ),
                  _ReminderLine(
                    text:
                        'Inspection reminders appear in the app. They are not email, push, or background notifications.',
                  ),
                  _ReminderLine(
                    text:
                        'On phones, use the bottom navigation and More for extra features. This Help Center is available from web navigation.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleGuide {
  const _RoleGuide({
    required this.role,
    required this.steps,
    this.pages = const [],
    this.title,
  });

  final AppRole role;
  final List<String> steps;
  final List<_GuidePage> pages;
  final String? title;

  String get label => title ?? role.label;
}

class _GuidePage {
  const _GuidePage(this.name, this.description);

  final String name;
  final String description;
}

class _GuideHeading extends StatelessWidget {
  const _GuideHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    ),
  );
}

class _PageDescription extends StatelessWidget {
  const _PageDescription({required this.page});

  final _GuidePage page;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${page.name}: ',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: page.description),
        ],
      ),
      style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
    ),
  );
}

class _GuideExpansion extends StatelessWidget {
  const _GuideExpansion({required this.guide, required this.initiallyExpanded});

  final _RoleGuide guide;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    leading: const Icon(Icons.menu_book_outlined, color: AppColors.green),
    title: Text(
      guide.label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    childrenPadding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    children: [
      if (guide.pages.isNotEmpty) ...[
        const _GuideHeading('Pages you can open'),
        for (final page in guide.pages) _PageDescription(page: page),
      ],
      const _GuideHeading('Step by step'),
      for (var index = 0; index < guide.steps.length; index++)
        _NumberedStep(number: index + 1, text: guide.steps[index]),
    ],
  );
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppColors.green,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _ReminderLine extends StatelessWidget {
  const _ReminderLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppColors.green,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
