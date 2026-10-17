import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../utils/health_status_label.dart';

class PlantListPage extends StatefulWidget {
  const PlantListPage({super.key});

  @override
  State<PlantListPage> createState() => _PlantListPageState();
}

class _PlantListPageState extends State<PlantListPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> plants = [];

  bool isLoading = true;

  String selectedFilter = 'All';

  // Logged-in admin information
  String? currentRole;
  int? currentCampusId;
  int? currentCollegeId;

  String? campusName;
  String? collegeName;

  @override
  void initState() {
    super.initState();
    loadPlantList();
  }

  // =========================================================
  // LOAD USER ROLE + PLANTS
  // =========================================================

  Future<void> loadPlantList() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No logged-in user found.');
      }

      // Get logged-in user's role, campus, and college.
      final profile = await supabase
          .from('profiles')
          .select('''
            user_id,
            role_id,
            campus_id,
            college_id,
            roles (
              role_name
            ),
            campus (
              campus_name
            ),
            college (
              college_name
            )
          ''')
          .eq('user_id', user.id)
          .single();

      currentRole = profile['roles']?['role_name']?.toString().toLowerCase();

      currentCampusId = profile['campus_id'];
      currentCollegeId = profile['college_id'];

      campusName = profile['campus']?['campus_name']?.toString();

      collegeName = profile['college']?['college_name']?.toString();

      await fetchPlants();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load plant list: $e')));
    }
  }

  // =========================================================
  // FETCH PLANTS BASED ON USER ROLE
  // =========================================================

  Future<void> fetchPlants() async {
    try {
      dynamic query = supabase
          .from('plant')
          .select('''
        plant_id,
        tag_id,
        common_name,
        scientific_name,
        variety,
        planter_name,
        growth_stage,
        health_status,
        date_planted,
        last_inspected,
        created_at,
        campus_id,
        college_id,
        campus:campus!plant_campus_id_fkey (
          campus_name
        ),
        college (
          college_name
        )
      ''')
          .isFilter('archived_at', null);

      // UNIVERSITY ADMIN
      // Can see all campuses and colleges.
      if (currentRole == 'university_admin' || currentRole == 'super_admin') {
        // No filtering needed.
      }
      // CAMPUS ADMIN
      // Can only see plants from their assigned campus.
      else if (currentRole == 'campus_admin') {
        if (currentCampusId == null) {
          throw Exception('Campus Admin has no assigned campus.');
        }

        query = query.eq('campus_id', currentCampusId!);
      }
      // COLLEGE ADMIN
      // Can only see plants from their assigned college.
      else if (currentRole == 'college_admin') {
        if (currentCollegeId == null) {
          throw Exception('College Admin has no assigned college.');
        }

        query = query.eq('college_id', currentCollegeId!);
      }
      // ROLE NOT ALLOWED
      else {
        throw Exception('You do not have permission to view plant records.');
      }

      final response = await query.order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        plants = List<Map<String, dynamic>>.from(response);

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load plants: $e')));
    }
  }

  // =========================================================
  // HEALTH FILTER
  // =========================================================

  List<Map<String, dynamic>> get filteredPlants {
    if (selectedFilter == 'All') {
      return plants;
    }

    return plants.where((plant) {
      final health = plant['health_status']?.toString().toLowerCase() ?? '';

      return healthStatusLabel(health) == selectedFilter;
    }).toList();
  }

  // =========================================================
  // COUNTS
  // =========================================================

  int get totalCount => plants.length;

  int get aliveCount {
    return plants.where((plant) {
      return plant['health_status']?.toString().toLowerCase() == 'alive';
    }).length;
  }

  int get dyingCount {
    return plants.where((plant) {
      return plant['health_status']?.toString().toLowerCase() == 'dying';
    }).length;
  }

  int get deadCount {
    return plants.where((plant) {
      return plant['health_status']?.toString().toLowerCase() == 'dead';
    }).length;
  }

  // =========================================================
  // PAGE SCOPE
  // =========================================================

  String get pageScope {
    switch (currentRole) {
      case 'super_admin':
      case 'university_admin':
        return 'All Campuses';

      case 'campus_admin':
        return campusName ?? 'Assigned Campus';

      case 'college_admin':
        return collegeName ?? 'Assigned College';

      default:
        return '';
    }
  }

  // =========================================================
  // DATE FORMATTER
  // =========================================================

  String formatDate(dynamic value) {
    if (value == null) {
      return '—';
    }

    try {
      final date = DateTime.parse(value.toString());

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${months[date.month - 1]} '
          '${date.day}, ${date.year}';
    } catch (_) {
      return value.toString();
    }
  }

  // =========================================================
  // HEALTH FILTER BUTTON
  // =========================================================

  Widget filterButton(String title, {int? count}) {
    final bool selected = selectedFilter == title;

    return OutlinedButton(
      onPressed: () {
        setState(() {
          selectedFilter = title;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? AppColors.primaryContainer
            : AppColors.surface,
        foregroundColor: selected ? AppColors.primary : Colors.black87,
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.grey.shade400,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      child: Text(
        count == null ? title : '$title ($count)',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // =========================================================
  // HEALTH DISPLAY
  // =========================================================

  Widget healthText(dynamic status) {
    final health = status?.toString().toLowerCase() ?? '';

    IconData icon;

    switch (health) {
      case 'alive':
        icon = Icons.check_circle_outline;
        break;

      case 'dying':
        icon = Icons.warning_amber_rounded;
        break;

      case 'dead':
        icon = Icons.cancel_outlined;
        break;

      default:
        icon = Icons.help_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(healthStatusLabel(health)),
      ],
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          'Plant Records',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadPlantList,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================
            // HEADER
            // ================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plant Records',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),

                  if (pageScope.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Coverage: $pageScope',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ================================================
            // FILTER BUTTONS
            // ================================================
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                filterButton('All', count: totalCount),
                filterButton('Healthy', count: aliveCount),
                filterButton('Needs attention', count: dyingCount),
                filterButton('Dead', count: deadCount),
              ],
            ),

            const SizedBox(height: 24),

            // ================================================
            // PLANT TABLE
            // ================================================
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedFilter == 'All'
                          ? 'All Plants'
                          : '$selectedFilter Plants',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Divider(),

                    const SizedBox(height: 10),

                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredPlants.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.park_outlined, size: 45),
                                  SizedBox(height: 12),
                                  Text(
                                    'No plant records found.',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 32,

                                    headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),

                                    columns: const [
                                      DataColumn(label: Text('Plant name')),
                                      DataColumn(label: Text('Tag ID')),
                                      DataColumn(label: Text('Variety')),
                                      DataColumn(label: Text('Tree Planter')),
                                      DataColumn(label: Text('Campus')),
                                      DataColumn(label: Text('College')),
                                      DataColumn(label: Text('Stage')),
                                      DataColumn(label: Text('Health')),
                                      DataColumn(label: Text('Date planted')),
                                      DataColumn(label: Text('Last inspected')),
                                    ],

                                    rows: filteredPlants.map((plant) {
                                      final campus = plant['campus'];

                                      final college = plant['college'];

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              plant['common_name']
                                                      ?.toString() ??
                                                  '—',
                                            ),
                                          ),

                                          DataCell(
                                            Text(
                                              plant['tag_id']?.toString() ??
                                                  '—',
                                            ),
                                          ),

                                          DataCell(
                                            Text(
                                              plant['variety']?.toString() ??
                                                  '—',
                                            ),
                                          ),

                                          DataCell(
                                            Text(
                                              plant['planter_name']
                                                      ?.toString() ??
                                                  '—',
                                            ),
                                          ),

                                          DataCell(
                                            Text(
                                              campus?['campus_name']
                                                      ?.toString() ??
                                                  '—',
                                            ),
                                          ),

                                          DataCell(
                                            Text(
                                              college?['college_name']
                                                      ?.toString() ??
                                                  '—',
                                            ),
                                          ),

                                          DataCell(
                                            Text(
                                              plant['growth_stage']
                                                      ?.toString() ??
                                                  '—',
                                            ),
                                          ),

                                          DataCell(
                                            healthText(plant['health_status']),
                                          ),

                                          DataCell(
                                            Text(
                                              formatDate(plant['date_planted']),
                                            ),
                                          ),

                                          DataCell(
                                            Text(
                                              formatDate(
                                                plant['last_inspected'],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
