import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/persistent_session.dart';

/// Navigation arguments are display context, never proof of account access.
class ProtectedStaffRoute extends StatefulWidget {
  const ProtectedStaffRoute({
    super.key,
    required this.arguments,
    required this.builder,
    this.validateSession,
    this.requiresScope = true,
  });

  final Map<String, dynamic> arguments;
  final WidgetBuilder builder;
  final Future<SessionIdentity?> Function()? validateSession;
  final bool requiresScope;

  @override
  State<ProtectedStaffRoute> createState() => _ProtectedStaffRouteState();
}

class _ProtectedStaffRouteState extends State<ProtectedStaffRoute>
    with WidgetsBindingObserver {
  bool _allowed = false;
  bool _hasVerified = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _allowed = false;
      _error = null;
    });
    try {
      final identity = await (widget.validateSession ?? AppSession.validate)();
      if (!mounted) return;
      if (identity == null) {
        _login();
        return;
      }
      // Check every identity field, including scope, against server values.
      final matches = identity.arguments.entries.every(
        (entry) =>
            (!widget.requiresScope &&
                !widget.arguments.containsKey(entry.key) &&
                (entry.key == 'campus_id' || entry.key == 'college_id')) ||
            widget.arguments[entry.key] == entry.value,
      );
      setState(() {
        _allowed = matches;
        if (matches) _hasVerified = true;
        _checking = false;
        if (!matches) {
          _error =
              'This page does not match your account access. Sign in again.';
        }
      });
    } on SessionRejected {
      if (mounted) _login();
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error =
              'Unable to verify your access. Check your connection and retry.';
        });
      }
    }
  }

  void _login() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/staff-login', (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Preserve form controllers and pending image-picker callbacks on resume.
      // The page stays invisible and unfocusable until access is verified again.
      Offstage(
        offstage: !_allowed,
        child: TickerMode(
          enabled: _allowed,
          child: ExcludeFocus(
            excluding: !_allowed,
            child: _hasVerified
                ? Builder(builder: widget.builder)
                : const SizedBox.shrink(),
          ),
        ),
      ),
      if (!_allowed) _accessGate(),
    ],
  );

  Widget _accessGate() => Scaffold(
    body: Center(
      child: _error == null
          ? const CircularProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _check, child: const Text('Retry')),
                  TextButton(onPressed: _login, child: const Text('Sign In')),
                ],
              ),
            ),
    ),
  );
}
