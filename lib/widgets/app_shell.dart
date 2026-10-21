import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

import '../models/app_role.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_sidebar.dart';
import 'app_mobile_navbar.dart';
import 'app_top_navbar.dart';

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

  final VoidCallback? onQrPressed;

  final bool showMobileNavigation;
  final bool showQrButton;
  final Widget? bottomAction;

  final EdgeInsetsGeometry desktopPadding;
  final EdgeInsetsGeometry mobilePadding;
  final bool? platformIsWeb;

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

    this.onQrPressed,

    this.showMobileNavigation = true,
    this.showQrButton = true,
    this.bottomAction,

    this.desktopPadding = const EdgeInsets.fromLTRB(32, 20, 32, 20),

    this.mobilePadding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    this.platformIsWeb,
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
      showQrButton && RoleCapabilities.fromValue(role).canScanQr;

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = platformIsWeb ?? kIsWeb;
    final isDesktop = width >= AppBreakpoints.desktop;

    if (isWeb && !isDesktop) {
      return _responsiveWebLayout(context);
    }
    if (isDesktop) {
      return _desktopLayout(context);
    }

    return _mobileLayout(context);
  }

  Widget _responsiveWebLayout(BuildContext context) {
    final compactPadding = EdgeInsets.all(
      AppBreakpoints.isPhone(MediaQuery.sizeOf(context).width)
          ? AppSpacing.md
          : AppSpacing.lg,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: Drawer(
        width: 272,
        child: SafeArea(
          child: AppSidebar(
            showBrand: true,
            activeRoute: activeRoute,
            userId: userId,
            username: username,
            role: role,
            campusId: campusId,
            collegeId: collegeId,
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppTopNavbar(
          compact: true,
          showBrand: false,
          pageTitle: mobileTitle,
          userName: _displayUserName,
          userRole: _displayUserRole,
          onScanTap: _canScanQr
              ? onQrPressed ??
                    () => Navigator.pushNamed(
                      context,
                      '/qr-scanner',
                      arguments: _userArguments,
                    )
              : null,
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Open navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: compactPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.maxContentWidth,
                  minHeight: constraints.maxHeight,
                  maxHeight: constraints.maxHeight,
                ),
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottomAction == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: bottomAction,
              ),
            ),
    );
  }

  // ============================================================
  // DESKTOP
  // ============================================================

  Widget _desktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSidebar(
            showBrand: true,
            activeRoute: activeRoute,
            userId: userId,
            username: username,
            role: role,
            campusId: campusId,
            collegeId: collegeId,
          ),
          Expanded(
            child: Column(
              children: [
                AppTopNavbar(
                  showBrand: false,
                  pageTitle: mobileTitle,
                  userName: _displayUserName,
                  userRole: _displayUserRole,
                ),

                Expanded(
                  child: Padding(
                    padding: desktopPadding,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: AppLayout.maxContentWidth,
                            minHeight: constraints.maxHeight,
                            maxHeight: constraints.maxHeight,
                          ),
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        automaticallyImplyLeading: false,

        backgroundColor: AppColors.background,

        surfaceTintColor: Colors.transparent,

        elevation: 0,

        toolbarHeight: toolbarHeight,

        titleSpacing: AppSpacing.lg,

        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: AppRadii.medium,
              ),
              child: const Icon(
                Icons.eco,
                color: AppColors.onPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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
                      fontSize: AppTypography.pageTitle,
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
      ),

      body: SafeArea(
        top: false,
        child: Padding(
          padding: mobilePadding.add(
            EdgeInsets.only(
              bottom: _canScanQr && showMobileNavigation && !keyboardVisible
                  ? 28
                  : 0,
            ),
          ),
          child: child,
        ),
      ),

      // ========================================================
      // QR SCANNER BUTTON
      // ========================================================
      floatingActionButton:
          _canScanQr && showMobileNavigation && !keyboardVisible
          ? FloatingActionButton(
              tooltip: 'Scan QR Code',

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

              foregroundColor: AppColors.onPrimary,

              elevation: 4,

              shape: const CircleBorder(),

              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 30,
                semanticLabel: 'Scan QR Code',
              ),
            )
          : null,

      floatingActionButtonLocation: _canScanQr && showMobileNavigation
          ? FloatingActionButtonLocation.centerDocked
          : null,

      // ========================================================
      // MOBILE NAVIGATION
      // ========================================================
      bottomNavigationBar: showMobileNavigation || bottomAction != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bottomAction != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      keyboardVisible
                          ? MediaQuery.viewInsetsOf(context).bottom
                          : 4,
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: keyboardVisible,
                      child: bottomAction!,
                    ),
                  ),
                if (showMobileNavigation && !keyboardVisible)
                  AppMobileNavbar(
                    activeRoute: activeRoute,

                    userId: userId,

                    username: username,

                    role: role,

                    campusId: campusId,

                    collegeId: collegeId,

                    canScanQr: _canScanQr,

                    displayName: _displayUserName,

                    displayRole: _displayUserRole,
                  ),
              ],
            )
          : null,
    );
  }

  // ============================================================
  // DISPLAY USER NAME
  // ============================================================

  String get _displayUserName {
    if (userName.trim().isNotEmpty) {
      return userName.trim();
    }

    return username.trim();
  }

  // ============================================================
  // DISPLAY ROLE
  // ============================================================

  String get _displayUserRole {
    final appRole = AppRole.fromValue(role);
    if (appRole != AppRole.unknown) {
      return appRole.label;
    }

    if (userRole.trim().isNotEmpty) {
      return userRole.trim();
    }

    return role.trim();
  }
}
