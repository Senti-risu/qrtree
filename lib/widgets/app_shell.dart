import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_sidebar.dart';
import 'app_top_navbar.dart';
import 'app_mobile_navbar.dart';

class AppShell extends StatelessWidget {
  final String activeRoute;

  final String mobileTitle;
  final String? mobileSubtitle;

  final Widget child;

  // ============================================================
  // LOGGED-IN USER DATA
  // ============================================================

  final int userId;
  final String username;
  final String role;

  final int? campusId;
  final int? collegeId;

  final String userName;
  final String userRole;

  // ============================================================
  // ACTIONS
  // ============================================================

  final VoidCallback? onRefresh;
  final VoidCallback? onQrPressed;

  final bool showMobileNavigation;
  final bool showQrButton;

  final EdgeInsetsGeometry desktopPadding;
  final EdgeInsetsGeometry mobilePadding;

  const AppShell({
    super.key,

    required this.activeRoute,
    required this.mobileTitle,
    required this.child,

    required this.userId,
    required this.username,
    required this.role,

    this.campusId,
    this.collegeId,

    this.mobileSubtitle,

    this.userName = '',
    this.userRole = '',

    this.onRefresh,
    this.onQrPressed,

    this.showMobileNavigation = true,
    this.showQrButton = true,

    this.desktopPadding = const EdgeInsets.all(24),

    this.mobilePadding = const EdgeInsets.fromLTRB(14, 10, 14, 100),
  });

  // ============================================================
  // SESSION ARGUMENTS
  // ============================================================

  Map<String, dynamic> get _userArguments {
    return {
      'user_id': userId,
      'username': username,
      'role': role,
      'campus_id': campusId,
      'college_id': collegeId,
    };
  }

  bool get _canScanQr =>
      showQrButton &&
      (role == 'college_admin' || role == 'inspection_team') &&
      campusId != null &&
      collegeId != null;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (isDesktop) {
      return _desktopLayout(context);
    }

    return _mobileLayout(context);
  }

  // ============================================================
  // DESKTOP
  // ============================================================

  Widget _desktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: Column(
        children: [
          AppTopNavbar(userName: _displayUserName, userRole: _displayUserRole),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSidebar(
                  activeRoute: activeRoute,

                  userId: userId,

                  username: username,

                  role: role,

                  campusId: campusId,

                  collegeId: collegeId,
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: desktopPadding,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1520),
                          child: SizedBox(width: double.infinity, child: child),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE
  // ============================================================

  Widget _mobileLayout(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleAdjustment = (textScale - 1).clamp(0.0, 1.0).toDouble();
    final toolbarHeight = 68.0 + (18 * scaleAdjustment);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        automaticallyImplyLeading: false,

        backgroundColor: AppColors.background,

        surfaceTintColor: Colors.transparent,

        elevation: 0,

        toolbarHeight: toolbarHeight,

        titleSpacing: 16,

        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mobileTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  Text(
                    mobileSubtitle?.trim().isNotEmpty == true
                        ? mobileSubtitle!
                        : _displayUserRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          if (onRefresh != null)
            IconButton(
              tooltip: 'Refresh',

              onPressed: onRefresh,

              icon: const Icon(Icons.refresh_rounded, color: AppColors.green),
            ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        top: false,

        child: SingleChildScrollView(padding: mobilePadding, child: child),
      ),

      // ========================================================
      // QR SCANNER BUTTON
      // ========================================================
      floatingActionButton: _canScanQr && showMobileNavigation
          ? FloatingActionButton(
              tooltip: 'Scan QR code',

              onPressed:
                  onQrPressed ??
                  () {
                    Navigator.pushNamed(
                      context,
                      '/qr-scanner',

                      arguments: _userArguments,
                    );
                  },

              backgroundColor: AppColors.green,

              foregroundColor: Colors.white,

              elevation: 4,

              shape: const CircleBorder(),

              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 30,
                semanticLabel: 'Scan QR code',
              ),
            )
          : null,

      floatingActionButtonLocation: _canScanQr && showMobileNavigation
          ? FloatingActionButtonLocation.centerDocked
          : null,

      // ========================================================
      // MOBILE NAVIGATION
      // ========================================================
      bottomNavigationBar: showMobileNavigation
          ? AppMobileNavbar(
              activeRoute: activeRoute,

              userId: userId,

              username: username,

              role: role,

              campusId: campusId,

              collegeId: collegeId,

              canScanQr: _canScanQr,

              displayName: _displayUserName,

              displayRole: _displayUserRole,
            )
          : null,
    );
  }

  // ============================================================
  // DISPLAY USER NAME
  // ============================================================

  String get _displayUserName {
    if (userName.trim().isNotEmpty) {
      return userName;
    }

    if (username.trim().isNotEmpty) {
      return username;
    }

    return 'EcoTag User';
  }

  // ============================================================
  // DISPLAY ROLE
  // ============================================================

  String get _displayUserRole {
    if (userRole.trim().isNotEmpty) {
      return userRole;
    }

    switch (role) {
      case 'super_admin':
        return 'Super Admin';

      case 'university_admin':
        return 'University Admin';

      case 'campus_admin':
        return 'Campus Admin';

      case 'college_admin':
        return 'College Admin';

      case 'inspection_team':
        return 'Inspection Team';

      case 'guest':
        return 'Guest';

      default:
        return role;
    }
  }
}
