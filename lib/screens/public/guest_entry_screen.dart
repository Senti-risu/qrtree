import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/guest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';

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
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _isSubmitting ? null : _goBack,
          tooltip: 'Back to access options',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: const _EcoTagTitle(),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = AppBreakpoints.isPhone(constraints.maxWidth);
            final pagePadding = compact ? 16.0 : 32.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(pagePadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - pagePadding * 2).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: AppCard(
                      padding: EdgeInsets.all(compact ? 20 : 32),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Continue as a guest',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Explore public EcoTag information without an administrator account.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.45,
                                    ),
                              ),
                              SizedBox(height: compact ? 24 : 28),
                              TextFormField(
                                controller: _nameController,
                                enabled: !_isSubmitting,
                                maxLength: 60,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Name (optional)',
                                  hintText: 'How should EcoTag welcome you?',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                  helperText: 'Your name is not saved.',
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _ageController,
                                enabled: !_isSubmitting,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                onFieldSubmitted: (_) => _continueAsGuest(),
                                decoration: const InputDecoration(
                                  labelText: 'Age',
                                  hintText: 'Enter your age',
                                  prefixIcon: Icon(Icons.cake_outlined),
                                  helperText:
                                      'Required for anonymous visitor statistics.',
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
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.privacy_tip_outlined,
                                        color: AppColors.green,
                                        size: 21,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Privacy: only your age is recorded for statistics. Your optional name stays in this visit and is never sent to the database.',
                                          style: TextStyle(
                                            color: AppColors.darkGreen,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 22 : 26),
                              SizedBox(
                                height: textScale >= 1.5 ? 60 : 52,
                                child: FilledButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : _continueAsGuest,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_rounded),
                                  label: Text(
                                    _isSubmitting
                                        ? 'Opening guest view…'
                                        : 'Continue as guest',
                                    textAlign: TextAlign.center,
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EcoTagTitle extends StatelessWidget {
  const _EcoTagTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.eco_rounded, color: AppColors.green),
        SizedBox(width: 8),
        Text(
          'EcoTag Guest Access',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
