import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';

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

  final SupabaseClient supabase = Supabase.instance.client;

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

      AppSession.start(sessionToken);

      _showMessage('Login successful.', isError: false);

      Navigator.pushReplacementNamed(
        context,
        role == 'super_admin' ? '/super-admin' : '/dashboard',
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.phone;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: AppCard(
                padding: EdgeInsets.all(
                  compact ? AppSpacing.xl : AppSpacing.xl * 1.5,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: const Text('Choose another access type'),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: AppRadii.extraLarge,
                      ),
                      child: const Icon(
                        Icons.eco,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'EcoTag',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreen,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      'Admin & Inspection Team sign in',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Text(
                      'Use the account issued to you by EcoTag.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    TextField(
                      controller: _usernameController,
                      enabled: !_isLoading,
                      onChanged: (_) {
                        if (_usernameError != null) {
                          setState(() => _usernameError = null);
                        }
                      },
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        errorText: _usernameError,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    TextField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) {
                        if (!_isLoading) {
                          _handleLogin();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        errorText: _passwordError,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                'Sign in',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
