import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_session.dart';
import '../../theme/app_colors.dart';
import '../../utils/user_facing_error.dart';
import 'widgets/auth_entry_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _usernameError;
  String? _passwordError;

  late final SupabaseClient supabase = Supabase.instance.client;

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _usernameError = username.isEmpty ? 'Enter your username.' : null;
        _passwordError = password.isEmpty ? 'Enter your password.' : null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _usernameError = null;
      _passwordError = null;
    });

    try {
      final result =
          await supabase.rpc(
                'login_user',
                params: {'p_username': username, 'p_password': password},
              )
              as List;

      final user = result.isEmpty ? null : result.first as Map<String, dynamic>;

      if (user == null) {
        throw Exception('Incorrect username or password.');
      }

      final userId = user['user_id'];

      final role = user['role']?.toString().toLowerCase() ?? '';

      final campusId = user['campus_id'];
      final collegeId = user['college_id'];
      final sessionToken = user['session_token']?.toString() ?? '';

      if (user['is_active'] == false) {
        throw Exception('This account is inactive. Contact the Super Admin.');
      }

      if (userId == null) {
        throw Exception('Invalid user account.');
      }

      if (role.isEmpty) {
        throw Exception('This account has no assigned role.');
      }

      if (sessionToken.isEmpty) {
        throw Exception(
          'Secure login is not enabled yet. Apply the latest Supabase migration.',
        );
      }

      // Campus Admin must belong to a campus
      if (role == 'campus_admin' && campusId == null) {
        throw Exception('This Campus Admin account has no assigned campus.');
      }

      // College Admin must belong to a college
      if (role == 'college_admin' && collegeId == null) {
        throw Exception('This College Admin account has no assigned college.');
      }

      // Inspection Team must belong to a college
      if (role == 'inspection_team' && collegeId == null) {
        throw Exception(
          'This Inspection Team account has no assigned college.',
        );
      }

      if (!mounted) return;

      await AppSession.start(sessionToken);
      if (!mounted) return;

      _showMessage('Login successful.', isError: false);

      Navigator.pushNamedAndRemoveUntil(
        context,
        role == 'super_admin' ? '/super-admin' : '/dashboard',
        (_) => false,
        arguments: {
          'user_id': userId,
          'username': user['username'],
          'role': role,
          'campus_id': campusId,
          'college_id': collegeId,
        },
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      debugPrint('SUPABASE ERROR: ${e.message}');

      _showMessage(
        userFacingError(
          e,
          fallback: 'We could not sign you in. Please try again.',
        ),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      final technicalMessage = technicalErrorDetails(e);

      debugPrint('LOGIN ERROR: $technicalMessage');

      _showMessage(
        userFacingError(
          e,
          fallback:
              'We could not sign you in. Check your details and try again.',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthEntryLayout(
    title: 'Staff Sign In',
    onBack: _isLoading
        ? null
        : () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (_) => false,
          ),
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameController,
            enabled: !_isLoading,
            autocorrect: false,
            enableSuggestions: false,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) {
              if (_usernameError != null) setState(() => _usernameError = null);
            },
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'Enter your username',
              errorText: _usernameError,
              fillColor: AppColors.surfaceSubtle,
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            autocorrect: false,
            enableSuggestions: false,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!_isLoading) _handleLogin();
            },
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              errorText: _passwordError,
              fillColor: AppColors.surfaceSubtle,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show Password' : 'Hide Password',
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _obscurePassword = !_obscurePassword;
                      }),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: FilledButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Sign In', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    ),
  );
}
