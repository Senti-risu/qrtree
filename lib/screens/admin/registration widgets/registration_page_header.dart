import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';

class RegistrationPageHeader extends StatelessWidget {
  const RegistrationPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Register Plant',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add a new plant to the EcoTag Campus Plant Profiling System.',
                  style: TextStyle(fontSize: 12, color: AppColors.green),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE2F7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.green,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
