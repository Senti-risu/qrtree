import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_session.dart';
import '../../utils/user_facing_error.dart';

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
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
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

                  const SizedBox(height: 12),

                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F4E8),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.eco,
                      size: 48,
                      color: Color(0xFF287A35),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'EcoTag',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF236B2D),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Admin & Inspection Team sign in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2E1A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Use the account issued to you by EcoTag.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),

                  const SizedBox(height: 40),

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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2E7D32),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2E7D32),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
    );
  }
}
