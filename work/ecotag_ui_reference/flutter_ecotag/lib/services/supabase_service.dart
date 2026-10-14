import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_models.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  static Future<AppUser?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    final res = await _client
        .from('users')
        .select('*, roles(name), campus(name), college(name)')
        .eq('id', authUser.id)
        .maybeSingle();

    if (res == null) return null;
    return AppUser.fromMap({...res, 'email': authUser.email});
  }

  static Future<void> signOut() => _client.auth.signOut();

  // ---------------------------------------------------------------------------
  // Dashboard stats
  // ---------------------------------------------------------------------------

  static Future<DashboardStats> getDashboardStats() async {
    final results = await Future.wait([
      _client.from('plant').select('id', const FetchOptions(count: CountOption.exact, head: true)),
      _client.from('plant').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('health_status.name', 'alive'),
      _client.from('plant').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('health_status.name', 'dying'),
      _client.from('plant').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('health_status.name', 'dead'),
    ]);

    return DashboardStats(
      totalPlants: results[0].count ?? 0,
      healthyPlants: results[1].count ?? 0,
      atRiskPlants: results[2].count ?? 0,
      deadPlants: results[3].count ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Recent plants
  // ---------------------------------------------------------------------------

  static Future<List<RecentPlant>> getRecentPlants({int limit = 5}) async {
    final res = await _client
        .from('plant')
        .select('''
          id, date_planted,
          plant_classification(common_name, type, variety),
          campus(name),
          health_status(name),
          growth_status(name)
        ''')
        .order('created_at', ascending: false)
        .limit(limit);

    return (res as List).map((m) => RecentPlant.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Recent inspections
  // ---------------------------------------------------------------------------

  static Future<List<RecentInspection>> getRecentInspections({int limit = 4}) async {
    final res = await _client
        .from('inspection')
        .select('''
          id, inspection_date, inspector_name, status,
          plant(plant_classification(common_name)),
          health_status(name),
          growth_status(name)
        ''')
        .order('inspection_date', ascending: false)
        .limit(limit);

    return (res as List).map((m) => RecentInspection.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Campus distribution
  // ---------------------------------------------------------------------------

  static Future<List<CampusData>> getCampusDistribution() async {
    final res = await _client
        .from('plant')
        .select('campus(name)')
        .not('campus_id', 'is', null);

    final counts = <String, int>{};
    for (final row in res as List) {
      final name = row['campus']?['name'] as String? ?? 'Unknown';
      counts[name] = (counts[name] ?? 0) + 1;
    }

    return counts.entries
        .map((e) => CampusData(campus: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  // ---------------------------------------------------------------------------
  // Full dashboard fetch
  // ---------------------------------------------------------------------------

  static Future<DashboardData> getDashboardData() async {
    final results = await Future.wait([
      getDashboardStats(),
      getRecentPlants(),
      getRecentInspections(),
      getCampusDistribution(),
    ]);

    return DashboardData(
      stats: results[0] as DashboardStats,
      recentPlants: results[1] as List<RecentPlant>,
      recentInspections: results[2] as List<RecentInspection>,
      campusDistribution: results[3] as List<CampusData>,
    );
  }
}
