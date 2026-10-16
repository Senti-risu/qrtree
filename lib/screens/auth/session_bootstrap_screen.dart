import 'package:flutter/material.dart';
import '../../services/app_session.dart';
import '../../services/persistent_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_error_state.dart';
import '../../utils/user_facing_error.dart';
import '../public/landing_screen.dart';

class SessionBootstrapScreen extends StatefulWidget {
  const SessionBootstrapScreen({
    super.key,
    this.restoreSession,
    this.forgetSession,
  });
  final Future<SessionIdentity?> Function()? restoreSession;
  final Future<void> Function()? forgetSession;
  @override
  State<SessionBootstrapScreen> createState() => _SessionBootstrapScreenState();
}

class _SessionBootstrapScreenState extends State<SessionBootstrapScreen> {
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  void _go(String route, [Map<String, dynamic>? arguments]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          route,
          (_) => false,
          arguments: arguments,
        );
      }
    });
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await (widget.restoreSession ?? AppSession.restore)();
      if (!mounted) return;
      if (user == null) {
        setState(() => _loading = false);
      } else {
        _go(user.dashboardRoute, user.arguments);
      }
    } on SessionRejected {
      if (mounted) _go('/staff-login');
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingError(
            error,
            fallback:
                'Your saved sign-in could not '
                'be checked. Try again, or forget it and sign in manually.',
          );
        });
      }
    }
  }

  Future<void> _forget() async {
    setState(() => _loading = true);
    try {
      await (widget.forgetSession ?? AppSession.clear)();
      if (mounted) _go('/staff-login');
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'This device could not remove the saved sign-in. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) return const LandingScreen();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Checking your sign-in…'),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    AppErrorState(
                      title: 'Unable to check saved sign-in',
                      message: _error!,
                      onRetry: _restore,
                    ),
                    TextButton(
                      onPressed: _forget,
                      child: const Text('Forget saved sign-in and log in'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
