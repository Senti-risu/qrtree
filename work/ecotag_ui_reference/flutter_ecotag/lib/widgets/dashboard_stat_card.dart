import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class DashboardStatCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final String supporting;
  final Color iconColor;
  final Color iconBg;
  final Color valueColor;
  final double? progress;

  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.supporting,
    required this.iconColor,
    required this.iconBg,
    required this.valueColor,
    this.progress,
  });

  @override
  State<DashboardStatCard> createState() => _DashboardStatCardState();
}

class _DashboardStatCardState extends State<DashboardStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(color: AppColors.outline),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A2E7D32),
              blurRadius: _hovered ? 24 : 8,
              offset: Offset(0, _hovered ? 6 : 2),
            ),
          ],
        ),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: widget.iconBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(widget.icon, color: widget.iconColor, size: 22),
                  ),
                  if (widget.progress != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.progress!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: widget.valueColor,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.supporting,
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              if (widget.progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.progress! / 100,
                    backgroundColor: const Color(0xFFE8F5E9),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.iconColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardStatCardSkeleton extends StatelessWidget {
  const DashboardStatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      padding: AppSpacing.cardPadding,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE8F5E8),
        highlightColor: const Color(0xFFF5FBF5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            const SizedBox(height: 16),
            Container(width: 64, height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 8),
            Container(width: 100, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}
