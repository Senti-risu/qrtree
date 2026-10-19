import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/app_role.dart';
import 'widgets/plant_details_presentation.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/session_bootstrap_screen.dart';
import 'screens/auth/access_choice_screen.dart';
import 'screens/public/landing_screen.dart';
import 'screens/public/guest_entry_screen.dart';
import 'screens/public/guest_dashboard_screen.dart';
import 'screens/admin/dashboard/dashboard_screen.dart';
import 'screens/admin/registration/register_plant_screen.dart';
import 'screens/qr/qr_management_screen.dart';
import 'screens/qr/qr_scanner.dart';
import 'screens/plants/plant_list_screen.dart';
import 'screens/admin/reports/plant_report_screen.dart';
import 'screens/plants/plant_detail_screen.dart';
import 'screens/inspections/inspection_history_screen.dart';
import 'screens/super_admin/super_admin_screen.dart';
import 'screens/super_admin/manage_accounts_screen.dart';
import 'screens/admin/inspection_accounts_screen.dart';
import 'screens/admin/activity_log_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // INITIALIZE SUPABASE
  // ============================================================

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoTag',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,

      // ========================================================
      // INITIAL ROUTE
      // ========================================================
      initialRoute: '/',

      // ========================================================
      // ROUTES THAT DON'T NEED ARGUMENTS
      // ========================================================
      routes: {
        '/': (context) => const SessionBootstrapScreen(),
        '/landing': (context) => const LandingScreen(),
        '/login': (context) => const AccessChoiceScreen(),
        '/access': (context) => const AccessChoiceScreen(),
        '/staff-login': (context) => const LoginScreen(),
        '/guest-entry': (context) => const GuestEntryScreen(),
      },

      // ========================================================
      // ROUTES THAT NEED NAVIGATION ARGUMENTS
      // ========================================================
      onGenerateRoute: (settings) {
        final args = settings.arguments;

        if (settings.name == '/guest-dashboard') {
          if (args is! Map<String, dynamic> || args['visit_id'] == null) {
            return _errorRoute('Guest visit information is missing.');
          }
          final visitId = args['visit_id'];
          if (visitId is! int || visitId <= 0) {
            return _errorRoute('Guest visit information is invalid.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => GuestDashboardScreen(
              visitId: visitId,
              guestName: args['guest_name']?.toString(),
            ),
          );
        }

        if (settings.name == '/super-admin') {
          if (args is! Map<String, dynamic> ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] != 'super_admin') {
            return _errorRoute('Super Admin access is required.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => SuperAdminScreen(
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
            ),
          );
        }

        if (settings.name == '/manage-accounts') {
          if (args is! Map<String, dynamic> ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] != 'super_admin') {
            return _errorRoute('Super Admin access is required.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ManageAccountsScreen(
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
            ),
          );
        }

        if (settings.name == '/inspection-accounts') {
          if (args is! Map<String, dynamic> ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] != 'college_admin' ||
              args['campus_id'] == null ||
              args['college_id'] == null) {
            return _errorRoute('College Admin access and scope are required.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => InspectionAccountsScreen(
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
              campusId: args['campus_id'] as int,
              collegeId: args['college_id'] as int,
            ),
          );
        }

        if (settings.name == '/activity-log') {
          if (args is! Map<String, dynamic> ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] == null ||
              !const {
                'super_admin',
                'university_admin',
                'campus_admin',
                'college_admin',
              }.contains(args['role'])) {
            return _errorRoute('Administrator access is required.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ActivityLogScreen(
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
              campusId: args['campus_id'] as int?,
              collegeId: args['college_id'] as int?,
            ),
          );
        }

        // ======================================================
        // DASHBOARD
        // ======================================================

        if (settings.name == '/dashboard') {
          if (args is! Map<String, dynamic>) {
            return _errorRoute('Dashboard login information is missing.');
          }

          final userId = args['user_id'];
          final username = args['username'];
          final role = args['role'];

          if (userId == null || username == null || role == null) {
            return _errorRoute('Incomplete dashboard user information.');
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              return DashboardScreen(
                userId: userId as int,
                username: username.toString(),
                role: role.toString(),
                campusId: args['campus_id'] as int?,
                collegeId: args['college_id'] as int?,
              );
            },
          );
        }

        // ======================================================
        // PLANT LIST
        // ======================================================

        if (settings.name == '/plant-list') {
          if (args is! Map<String, dynamic> ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] == null) {
            return _errorRoute('Plant list user information is missing.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => PlantListScreen(
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
              campusId: args['campus_id'] as int?,
              collegeId: args['college_id'] as int?,
              initialHealthFilter: args['health_filter']?.toString(),
            ),
          );
        }

        if (settings.name == '/plant-details') {
          if (args is! Map<String, dynamic> ||
              args['plant_id'] == null ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] == null) {
            return _errorRoute('Plant details information is missing.');
          }
          return plantDetailsRoute(
            settings: settings,
            builder: (_) => PlantDetailScreen(
              plantId: args['plant_id'] as int,
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
            ),
          );
        }

        if (settings.name == '/reports') {
          if (args is! Map<String, dynamic> ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] == null) {
            return _errorRoute('Report user information is missing.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => CollegePlantReportScreen(
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
              campusId: args['campus_id'] as int?,
              collegeId: args['college_id'] as int?,
            ),
          );
        }

        if (settings.name == '/inspections') {
          if (args is! Map<String, dynamic> ||
              args['user_id'] == null ||
              args['username'] == null ||
              args['role'] == null) {
            return _errorRoute(
              'Inspection history user information is missing.',
            );
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => InspectionHistoryScreen(
              userId: args['user_id'] as int,
              username: args['username'].toString(),
              role: args['role'].toString(),
              campusId: args['campus_id'] as int?,
              collegeId: args['college_id'] as int?,
              initialQueueFilter: args['queue_filter']?.toString(),
            ),
          );
        }

        // ======================================================
        // REGISTER PLANT
        // ======================================================

        if (settings.name == '/register-plant') {
          if (args is! Map<String, dynamic>) {
            return _errorRoute('Registration user information is missing.');
          }

          final userId = args['user_id'];
          final username = args['username'];
          final role = args['role'];
          final campusId = args['campus_id'];
          final collegeId = args['college_id'];

          if (userId == null ||
              username == null ||
              role == null ||
              campusId == null ||
              collegeId == null) {
            return _errorRoute('Incomplete plant registration information.');
          }

          if (!RoleCapabilities.fromValue(role.toString()).canRegisterPlants) {
            return _errorRoute(
              'College Admin or Inspection Team access is required to register plants.',
            );
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              return RegisterPlantScreen(
                userId: userId as int,
                username: username.toString(),
                role: role.toString(),
                campusId: campusId as int,
                collegeId: collegeId as int,
              );
            },
          );
        }

        // ======================================================
        // QR MANAGEMENT
        // ======================================================

        if (settings.name == '/qr-management') {
          if (args is! Map<String, dynamic>) {
            return _errorRoute('QR Management user information is missing.');
          }

          final userId = args['user_id'];
          final username = args['username'];
          final role = args['role'];
          final campusId = args['campus_id'];
          final collegeId = args['college_id'];

          if (userId == null ||
              username == null ||
              role == null ||
              campusId == null ||
              collegeId == null) {
            return _errorRoute('Incomplete QR Management user information.');
          }

          if (role.toString().toLowerCase() != 'college_admin') {
            return _errorRoute(
              'Only College Admin accounts can manage QR tags.',
            );
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              return QrManagementScreen(
                userId: userId as int,
                username: username.toString(),
                role: role.toString(),
                campusId: campusId as int,
                collegeId: collegeId as int,
              );
            },
          );
        }

        // ======================================================
        // QR SCANNER
        // ======================================================

        if (settings.name == '/qr-scanner') {
          if (args is! Map<String, dynamic>) {
            return _errorRoute('QR Scanner user information is missing.');
          }

          final userId = args['user_id'];
          final username = args['username'];
          final role = args['role'];
          final campusId = args['campus_id'];
          final collegeId = args['college_id'];

          if (userId == null || username == null || role == null) {
            return _errorRoute('Incomplete QR Scanner user information.');
          }

          if (!RoleCapabilities.fromValue(role.toString()).canScanQr) {
            return _errorRoute(
              'A recognized EcoTag staff account is required to scan QR codes.',
            );
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              return QrScannerScreen(
                userId: userId as int,
                username: username.toString(),
                role: role.toString(),
                campusId: campusId as int?,
                collegeId: collegeId as int?,
              );
            },
          );
        }

        return null;
      },

      // ========================================================
      // UNKNOWN ROUTE
      // ========================================================
      onUnknownRoute: (settings) {
        return _errorRoute('Page not found: ${settings.name}');
      },
    );
  }

  // ============================================================
  // ERROR PAGE
  // ============================================================

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          backgroundColor: AppColors.background,

          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),

                  const SizedBox(height: 16),

                  const Text(
                    'EcoTag',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGreen,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Return To Login'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
