import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/guest_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/user_facing_error.dart';
import '../auth/widgets/auth_entry_layout.dart';

class GuestEntryScreen extends StatefulWidget {
  const GuestEntryScreen({super.key, this.service});

  final GuestService? service;

  @override
  State<GuestEntryScreen> createState() => _GuestEntryScreenState();
}

class _GuestEntryScreenState extends State<GuestEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  late final GuestService _service;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GuestService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final age = int.parse(_ageController.text.trim());
    final guestName = _nameController.text.trim();
    setState(() => _isSubmitting = true);

    try {
      final visitId = await _service.startGuestVisit(age: age);
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/guest-dashboard',
        arguments: {
          'visit_id': visitId,
          if (guestName.isNotEmpty) 'guest_name': guestName,
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                error,
                fallback:
                    'Guest access is unavailable right now. Please try again.',
              ),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/access');
    }
  }

  @override
  Widget build(BuildContext context) => AuthEntryLayout(
    title: 'Guest access',
    readOnly: true,
    onBack: _isSubmitting ? null : _goBack,
    child: Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_isSubmitting,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'Enter your name',
                fillColor: AppColors.surfaceSubtle,
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _ageController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              onFieldSubmitted: (_) => _continueAsGuest(),
              decoration: const InputDecoration(
                labelText: 'Age (required)',
                hintText: 'Enter your age',
                fillColor: AppColors.surfaceSubtle,
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Enter your age.';
                final age = int.tryParse(raw);
                if (age == null || age < 1 || age > 120) {
                  return 'Enter an age from 1 to 120.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: AppColors.green,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Privacy: only your age is recorded for statistics. Your optional name stays in this visit and is never sent to the database.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: FilledButton(
                onPressed: _isSubmitting ? null : _continueAsGuest,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text(
                        'Continue as guest',
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
