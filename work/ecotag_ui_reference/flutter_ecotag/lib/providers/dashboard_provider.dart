import 'package:flutter/foundation.dart';
import '../models/dashboard_models.dart';
import '../services/supabase_service.dart';

enum LoadState { idle, loading, loaded, error }

class DashboardProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  DashboardData? _data;
  String? _errorMessage;
  AppUser? _currentUser;

  LoadState get state => _state;
  DashboardData? get data => _data;
  String? get errorMessage => _errorMessage;
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _state == LoadState.loading;

  Future<void> init() async {
    _currentUser = await SupabaseService.getCurrentUser();
    await fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    _state = LoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await SupabaseService.getDashboardData();
      _state = LoadState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    _currentUser = null;
    _data = null;
    _state = LoadState.idle;
    notifyListeners();
  }
}
