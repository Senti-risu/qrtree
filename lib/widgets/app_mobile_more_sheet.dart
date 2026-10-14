import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../services/account_profile_service.dart';
import '../theme/app_colors.dart';

enum AppMobileMoreAction {
  profile,
  registerPlant,
  qrManagement,
  userManagement,
  reports,
  activityLog,
  help,
  logout,
}

Future<AppMobileMoreAction?> showAppMobileMoreSheet(
  BuildContext context, {
  required String displayName,
  required String displayRole,
  required String role,
}) {
  final groups = <_MoreGroup>[
    const _MoreGroup(
      label: 'Account',
      items: [
        _MoreItem(
          action: AppMobileMoreAction.profile,
          icon: Icons.person_outline_rounded,
          title: 'My Profile',
          subtitle: 'View your account and access details',
        ),
      ],
    ),
    if (role == 'college_admin')
      const _MoreGroup(
        label: 'Management',
        items: [
          _MoreItem(
            action: AppMobileMoreAction.registerPlant,
            icon: Icons.add_circle_outline_rounded,
            title: 'Register Plant',
            subtitle: 'Add a new campus plant',
          ),
          _MoreItem(
            action: AppMobileMoreAction.qrManagement,
            icon: Icons.qr_code_2_rounded,
            title: 'QR Management',
            subtitle: 'Generate, print, and manage QR tags',
          ),
          _MoreItem(
            action: AppMobileMoreAction.userManagement,
            icon: Icons.manage_accounts_outlined,
            title: 'User Management',
            subtitle: 'Manage Inspection Team accounts',
          ),
        ],
      ),
    if (const {
      'super_admin',
      'university_admin',
      'campus_admin',
      'college_admin',
      'inspection_team',
    }.contains(role))
      _MoreGroup(
        label: 'Insights',
        items: [
          if (role != 'super_admin')
            const _MoreItem(
              action: AppMobileMoreAction.reports,
              icon: Icons.bar_chart_rounded,
              title: 'Reports',
              subtitle: 'View plant monitoring reports',
            ),
          if (role != 'inspection_team')
            const _MoreItem(
              action: AppMobileMoreAction.activityLog,
              icon: Icons.history_rounded,
              title: 'Activity Log',
              subtitle: 'Review important account and plant changes',
            ),
        ],
      ),
    const _MoreGroup(
      label: 'Help',
      items: [
        _MoreItem(
          action: AppMobileMoreAction.help,
          icon: Icons.help_outline_rounded,
          title: 'How to use EcoTag',
          subtitle: 'Quick guidance for scanning, plants, and inspections',
        ),
      ],
    ),
    const _MoreGroup(
      label: 'Session',
      items: [
        _MoreItem(
          action: AppMobileMoreAction.logout,
          icon: Icons.logout_rounded,
          title: 'Sign out',
          subtitle: 'Return to the EcoTag login screen',
          destructive: true,
        ),
      ],
    ),
  ];

  return showModalBottomSheet<AppMobileMoreAction>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final size = MediaQuery.sizeOf(sheetContext);

      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: size.height * 0.96,
          ),
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ListView(
              shrinkWrap: true,
              scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'More',
                        style: TextStyle(
                          color: AppColors.darkGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _AccountHeader(
                  displayName: displayName,
                  displayRole: displayRole,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                for (final group in groups) ...[
                  _MoreSectionLabel(group.label),
                  for (final item in group.items)
                    _MoreTile(
                      item: item,
                      onTap: () => Navigator.pop(sheetContext, item.action),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showAppMobileProfileSheet(
  BuildContext context, {
  required String username,
  required String displayName,
  required String displayRole,
  required String role,
  required Future<AccountScopeNames> Function() loadScopeNames,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _MobileProfileSheet(
        username: username,
        displayName: displayName,
        displayRole: displayRole,
        role: role,
        loadScopeNames: loadScopeNames,
      );
    },
  );
}

class _MobileProfileSheet extends StatefulWidget {
  final String username;
  final String displayName;
  final String displayRole;
  final String role;
  final Future<AccountScopeNames> Function() loadScopeNames;

  const _MobileProfileSheet({
    required this.username,
    required this.displayName,
    required this.displayRole,
    required this.role,
    required this.loadScopeNames,
  });

  @override
  State<_MobileProfileSheet> createState() => _MobileProfileSheetState();
}

class _MobileProfileSheetState extends State<_MobileProfileSheet> {
  late Future<AccountScopeNames> _scopeNames;

  @override
  void initState() {
    super.initState();
    _scopeNames = widget.loadScopeNames();
  }

  void _retry() {
    setState(() {
      _scopeNames = widget.loadScopeNames();
    });
  }

  String _campusValue(AccountScopeNames names) {
    if (names.campusName != null) return names.campusName!;
    if (widget.role == 'super_admin' || widget.role == 'university_admin') {
      return 'All campuses';
    }
    return 'Not assigned';
  }

  String _collegeValue(AccountScopeNames names) {
    if (names.collegeName != null) return names.collegeName!;
    if (widget.role == 'super_admin' ||
        widget.role == 'university_admin' ||
        widget.role == 'campus_admin') {
      return 'All colleges';
    }
    return 'Not assigned';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.90,
        ),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _AccountHeader(
                  displayName: widget.displayName,
                  displayRole: widget.displayRole,
                  centered: true,
                ),
                const SizedBox(height: 24),
                _ProfileField(
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: widget.username,
                ),
                _ProfileField(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: widget.displayRole,
                ),
                FutureBuilder<AccountScopeNames>(
                  future: _scopeNames,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _ProfileLoadingCard();
                    }

                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _ProfileField(
                            icon: Icons.location_city_outlined,
                            label: 'Campus',
                            value: 'Unable to load',
                          ),
                          const _ProfileField(
                            icon: Icons.school_outlined,
                            label: 'College',
                            value: 'Unable to load',
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      );
                    }

                    final names = snapshot.data ?? const AccountScopeNames();
                    return Column(
                      children: [
                        _ProfileField(
                          icon: Icons.location_city_outlined,
                          label: 'Campus',
                          value: _campusValue(names),
                        ),
                        _ProfileField(
                          icon: Icons.school_outlined,
                          label: 'College',
                          value: _collegeValue(names),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  const _ProfileLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Loading campus and college...')),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  final String displayName;
  final String displayRole;
  final bool centered;

  const _AccountHeader({
    required this.displayName,
    required this.displayRole,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: AppColors.darkGreen,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          displayRole,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );

    final avatar = CircleAvatar(
      radius: centered ? 34 : 27,
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.green,
      child: Text(
        _initialsOf(displayName),
        style: TextStyle(
          fontSize: centered ? 18 : 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (centered) {
      return Column(children: [avatar, const SizedBox(height: 12), details]);
    }

    return Row(
      children: [
        avatar,
        const SizedBox(width: 14),
        Expanded(child: details),
      ],
    );
  }
}

class _MoreGroup {
  final String label;
  final List<_MoreItem> items;

  const _MoreGroup({required this.label, required this.items});
}

class _MoreSectionLabel extends StatelessWidget {
  final String label;

  const _MoreSectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 2),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    ),
  );
}

class _MoreItem {
  final AppMobileMoreAction action;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;

  const _MoreItem({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
  });
}

class _MoreTile extends StatelessWidget {
  final _MoreItem item;
  final VoidCallback onTap;

  const _MoreTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.destructive ? AppColors.danger : AppColors.green;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ListTile(
        dense: true,
        minTileHeight: 54,
        minVerticalPadding: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: item.destructive
            ? AppColors.danger.withValues(alpha: 0.055)
            : Colors.transparent,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: color, size: 22),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: item.destructive ? AppColors.danger : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          item.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: item.destructive ? AppColors.danger : AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initialsOf(String name) {
  final parts = name
      .split(RegExp(r'[ ,]+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'E';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
