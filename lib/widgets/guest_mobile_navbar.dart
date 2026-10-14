import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Mobile navigation used only by anonymous EcoTag visitors.
///
/// The center space belongs to the scan button supplied by the parent
/// [Scaffold]. Keeping this separate from the authenticated navigation prevents
/// guest users from seeing management destinations.
class GuestMobileNavbar extends StatelessWidget {
  const GuestMobileNavbar({
    super.key,
    required this.selectedIndex,
    required this.onHome,
    required this.onAccount,
  });

  final int selectedIndex;
  final VoidCallback onHome;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleAdjustment = (textScale - 1).clamp(0.0, 1.0).toDouble();
    final contentHeight = 68.0 + (18 * scaleAdjustment);

    return BottomAppBar(
      height: contentHeight + bottomInset,
      padding: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 7,
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                Expanded(
                  child: _GuestNavButton(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    selected: selectedIndex == 0,
                    onTap: onHome,
                  ),
                ),
                const SizedBox(width: 76),
                Expanded(
                  child: _GuestNavButton(
                    label: 'Account',
                    icon: Icons.person_rounded,
                    selected: selectedIndex == 1,
                    onTap: onAccount,
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 5,
              child: IgnorePointer(
                child: Text(
                  'Scan',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestNavButton extends StatelessWidget {
  const _GuestNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.inactiveNav;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
