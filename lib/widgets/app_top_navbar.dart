import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/app_session.dart';

class AppTopNavbar extends StatelessWidget {
  final String userName;
  final String userRole;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;

  const AppTopNavbar({
    super.key,
    this.userName = 'Delacruz, Jumi',
    this.userRole = 'College Admin',
    this.onNotificationTap,
    this.onProfileTap,
    this.onLogoutTap,
  });

  String _initialsOf(String name) {
    final parts = name
        .split(RegExp(r'[ ,]+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.navbarBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 10),
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
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationTap,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.green,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(30),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.green,
                  child: Text(
                    _initialsOf(userName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      userRole,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.green,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Logout',
            onPressed:
                onLogoutTap ??
                () async {
                  await AppSession.end();
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
