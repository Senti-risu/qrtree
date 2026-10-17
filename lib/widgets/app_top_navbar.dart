import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../services/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_navigation_guard.dart';

class AppTopNavbar extends StatelessWidget {
  final String userName;
  final String userRole;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;

  const AppTopNavbar({
    super.key,
    this.userName = '',
    this.userRole = '',
    this.onNotificationTap,
    this.onProfileTap,
    this.onLogoutTap,
  });

  String _initialsOf(String name) {
    final parts = name
        .split(RegExp(r'[ ,]+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'E';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedName = userName.trim();
    final role = AppRole.fromValue(userRole);
    final resolvedRole = role == AppRole.unknown ? userRole.trim() : role.label;
    final hasIdentity = resolvedName.isNotEmpty || resolvedRole.isNotEmpty;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.navbarBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: AppRadii.medium,
            ),
            child: const Icon(Icons.eco, color: AppColors.onPrimary, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EcoTag',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.darkGreen,
                ),
              ),
              Text(
                'Campus Plant Profiling System',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (onNotificationTap != null) ...[
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotificationTap,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.green,
                size: 21,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          if (hasIdentity)
            _ProfileSummary(
              userName: resolvedName,
              userRole: resolvedRole,
              initials: _initialsOf(resolvedName),
              onTap: onProfileTap,
            ),
          if (hasIdentity) const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Logout',
            onPressed:
                onLogoutTap ??
                () async {
                  if (!await AppNavigationGuard.confirm(context) ||
                      !context.mounted) {
                    return;
                  }
                  try {
                    await AppSession.end();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This device could not remove '
                            'the saved sign-in. Please try logging out again.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  );
                },
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.green,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final String userName;
  final String userRole;
  final String initials;
  final VoidCallback? onTap;

  const _ProfileSummary({
    required this.userName,
    required this.userRole,
    required this.initials,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppLayout.minimumTapTarget,
        maxWidth: 260,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.green,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userName.isNotEmpty)
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreen,
                    ),
                  ),
                if (userRole.isNotEmpty)
                  Text(
                    userRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.green,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.green,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.fullyRounded,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: content,
      ),
    );
  }
}
