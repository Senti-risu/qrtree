import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class RecentPlantsTable extends StatelessWidget {
  final List<RecentPlant> plants;
  final bool loading;
  final VoidCallback? onViewAll;

  const RecentPlantsTable({
    super.key,
    required this.plants,
    this.loading = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.outline),
        boxShadow: const [BoxShadow(color: Color(0x062E7D32), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Plants', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    const Text(
                      'Recently registered or updated plants',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outline),

          if (loading)
            _TableSkeleton()
          else if (plants.isEmpty)
            _EmptyState()
          else
            _TableContent(plants: plants),
        ],
      ),
    );
  }
}

class _TableContent extends StatelessWidget {
  final List<RecentPlant> plants;

  const _TableContent({required this.plants});

  @override
  Widget build(BuildContext context) {
    const columns = ['Plant', 'Type', 'Variety', 'Campus', 'Growth Stage', 'Health', 'Date Planted'];
    const colWidths = [160.0, 80.0, 120.0, 120.0, 110.0, 100.0, 130.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          // Column headers
          Container(
            color: const Color(0xFFF8FBF8),
            child: Row(
              children: List.generate(columns.length, (i) => SizedBox(
                width: colWidths[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    columns[i],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              )),
            ),
          ),
          const Divider(height: 1, color: AppColors.outline),
          ...plants.map((p) => _PlantRow(plant: p, colWidths: colWidths)),
        ],
      ),
    );
  }
}

class _PlantRow extends StatefulWidget {
  final RecentPlant plant;
  final List<double> colWidths;

  const _PlantRow({required this.plant, required this.colWidths});

  @override
  State<_PlantRow> createState() => _PlantRowState();
}

class _PlantRowState extends State<_PlantRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plant;
    final w = widget.colWidths;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? const Color(0xFFF0F9F0) : Colors.transparent,
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: w[0],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.park_rounded, size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            p.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...[p.type, p.variety, p.campus].asMap().entries.map((e) => SizedBox(
                  width: w[e.key + 1],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(e.value, style: const TextStyle(fontSize: 13, color: AppColors.onSurface), overflow: TextOverflow.ellipsis),
                  ),
                )),
                SizedBox(
                  width: w[4],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: _GrowthBadge(stage: p.growthStage),
                  ),
                ),
                SizedBox(
                  width: w[5],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: StatusBadge(status: p.health),
                  ),
                ),
                SizedBox(
                  width: w[6],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(p.datePlanted, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _GrowthBadge extends StatelessWidget {
  final String stage;

  const _GrowthBadge({required this.stage});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (stage.toLowerCase()) {
      'mature' => (const Color(0xFF7B1FA2), const Color(0xFFF3E5F5)),
      'growing' => (const Color(0xFF0288D1), const Color(0xFFE1F5FE)),
      'sapling' => (AppColors.secondary, AppColors.secondaryContainer),
      _ => (AppColors.primary, AppColors.primaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(stage, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No plants registered yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Start building your campus plant database by registering your first plant.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Register Plant'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8F5E8),
      highlightColor: const Color(0xFFF5FBF5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
