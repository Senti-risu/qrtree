import 'package:flutter/material.dart';

import '../../../widgets/app_page_header.dart';

class DashboardPageHeader extends StatelessWidget {
  final String description;
  final String userRole;
  final VoidCallback onRefresh;

  const DashboardPageHeader({
    super.key,
    required this.description,
    required this.userRole,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: 'Dashboard',
      subtitle: description,
      trailing: OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
    );
  }
}
