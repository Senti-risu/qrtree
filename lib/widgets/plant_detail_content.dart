import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'app_card.dart';
import 'equal_height_cards.dart';

class PlantDetailHero extends StatelessWidget {
  const PlantDetailHero({
    super.key,
    required this.name,
    required this.scientificName,
    required this.plantId,
    required this.imageUrl,
  });
  final String name, scientificName, plantId, imageUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final split =
          constraints.maxWidth >= 720 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.6;
      final image = ClipRRect(
        borderRadius: AppRadii.large,
        child: Container(
          height: split
              ? 160
              : (constraints.maxWidth * .56).clamp(160.0, 240.0),
          width: double.infinity,
          color: AppColors.primaryContainer,
          child: imageUrl.isEmpty
              ? const Icon(
                  Icons.park_outlined,
                  size: 64,
                  color: AppColors.green,
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, size: 48),
                ),
        ),
      );
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: AppTypography.pageTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scientificName,
            style: const TextStyle(
              fontSize: AppTypography.body,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Plant #$plantId',
            style: const TextStyle(
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: split
              ? Row(
                  children: [
                    SizedBox(width: 220, child: image),
                    const SizedBox(width: 20),
                    Expanded(child: heading),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [image, const SizedBox(height: 16), heading],
                ),
        ),
      );
    },
  );
}

class PlantDetailSectionPair extends StatelessWidget {
  const PlantDetailSectionPair({
    super.key,
    required this.first,
    required this.second,
  });
  final Widget first, second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 720 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.6) {
        return EqualHeightCards(children: [first, second]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, second],
      );
    },
  );
}

class PlantDetailFields extends StatelessWidget {
  const PlantDetailFields({
    super.key,
    required this.title,
    required this.rows,
    this.trailing,
    this.badge,
  });
  final String title;
  final Map<String, String> rows;
  final Widget? trailing;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadii.large,
      border: AppBorders.subtle,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTypography.sectionTitle,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreen,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (badge != null) ...[const SizedBox(height: 8), badge!],
            const SizedBox(height: 12),
            for (final row in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: stack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.key,
                            style: const TextStyle(
                              fontSize: AppTypography.label,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            row.value,
                            style: const TextStyle(
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              row.key,
                              style: const TextStyle(
                                fontSize: AppTypography.label,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Text(
                              row.value,
                              style: const TextStyle(
                                fontSize: AppTypography.body,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        );
      },
    ),
  );
}

/// Related actions share a surface and wrap rather than spanning a wide dialog.
class PlantDetailActions extends StatelessWidget {
  const PlantDetailActions({
    super.key,
    required this.children,
    this.singleColumn = false,
  });
  final List<Widget> children;
  final bool singleColumn;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Plant actions',
          style: TextStyle(
            fontSize: AppTypography.sectionTitle,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                singleColumn || MediaQuery.textScalerOf(context).scale(1) >= 1.5
                ? 1
                : constraints.maxWidth >= 780
                ? 3
                : constraints.maxWidth >= 500
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final child in children)
                  SizedBox(width: width, child: child),
              ],
            );
          },
        ),
      ],
    ),
  );
}
