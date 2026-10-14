import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _ActionItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color bg;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.bg,
  });
}

const _actions = [
  _ActionItem(
    icon: Icons.add_circle_rounded,
    title: 'Register New Plant',
    description: 'Add a new plant to EcoTag',
    color: AppColors.primary,
    bg: AppColors.primaryContainer,
  ),
  _ActionItem(
    icon: Icons.park_rounded,
    title: 'View Plant List',
    description: 'Browse registered plants',
    color: AppColors.secondary,
    bg: AppColors.secondaryContainer,
  ),
  _ActionItem(
    icon: Icons.assessment_rounded,
    title: 'Create Report',
    description: 'Generate plant monitoring reports',
    color: AppColors.info,
    bg: AppColors.infoContainer,
  ),
];

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.outline),
        boxShadow: const [BoxShadow(color: Color(0x062E7D32), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Common plant management tasks',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...(_actions.map((a) => _ActionButton(action: a))),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final _ActionItem action;

  const _ActionButton({required this.action});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? a.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? a.color.withOpacity(0.3) : AppColors.outline),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: a.bg, borderRadius: BorderRadius.circular(10)),
                      child: Icon(a.icon, color: a.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: a.color)),
                        const SizedBox(height: 2),
                        Text(a.description, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: a.color.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
