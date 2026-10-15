import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

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
              ? 220
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
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scientificName,
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Plant #$plantId',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: split
            ? Row(
                children: [
                  SizedBox(width: 320, child: image),
                  const SizedBox(width: 24),
                  Expanded(child: heading),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [image, const SizedBox(height: 16), heading],
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, second],
      );
    },
  );
}

class PlantDetailFields extends StatelessWidget {
  const PlantDetailFields({super.key, required this.title, required this.rows});
  final String title;
  final Map<String, String> rows;

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
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
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            row.value,
                            style: const TextStyle(
                              fontSize: 14,
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
                                fontSize: 13,
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
                                fontSize: 14,
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
