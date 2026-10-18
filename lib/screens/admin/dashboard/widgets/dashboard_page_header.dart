import 'package:flutter/material.dart';

import '../../../../widgets/app_page_header.dart';

class DashboardPageHeader extends StatelessWidget {
  final String description;
  final String userRole;

  const DashboardPageHeader({
    super.key,
    required this.description,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(title: 'Dashboard', subtitle: description);
  }
}
