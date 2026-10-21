import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/inspection_schedule_settings_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_typography.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';

class InspectionScheduleSettingsScreen extends StatefulWidget {
  const InspectionScheduleSettingsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.settings,
  });

  final int userId;
  final String username;
  final String role;
  final InspectionScheduleSettings? settings;

  @override
  State<InspectionScheduleSettingsScreen> createState() =>
      _InspectionScheduleSettingsScreenState();
}

class _InspectionScheduleSettingsScreenState
    extends State<InspectionScheduleSettingsScreen> {
  late final InspectionScheduleSettings _settings =
      widget.settings ?? InspectionScheduleSettingsService();
  final _daysController = TextEditingController();
  int? _savedDays;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await _settings.getIntervalDays();
      if (!mounted) return;
      setState(() {
        _savedDays = days;
        _daysController.text = '$days';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(
          error,
          fallback: 'Inspection schedule could not be loaded. Try again.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final days = int.tryParse(_daysController.text.trim());
    if (days == null || days < 1 || days > 3650) {
      setState(() => _error = 'Enter a whole number from 1 to 3650 days.');
      return;
    }
    if (days == _savedDays) {
      setState(() => _error = 'The inspection interval has not changed.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update university inspection schedule?'),
        content: Text(
          'This changes the interval to $days days for all campuses and resets every active plant’s next inspection date to the date this change is made plus $days days. Archived and dead plants are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update Schedule'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _settings.setIntervalDays(days);
      if (!mounted) return;
      setState(() {
        _savedDays = saved;
        _daysController.text = '$saved';
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inspection schedule updated for all campuses and admins.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userFacingError(
          error,
          fallback: 'Inspection schedule could not be updated. Try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
    activeRoute: '/inspection-schedule',
    mobileTitle: 'Inspection Schedule',
    mobileSubtitle: 'University-wide schedule settings',
    userId: widget.userId,
    username: widget.username,
    role: widget.role,
    userName: widget.username,
    userRole: 'University Admin',
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Inspection Schedule',
            subtitle:
                'Set the inspection frequency used by College Admins and Inspection Teams across all campuses.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _savedDays == null
                ? _loadError()
                : _settingsForm(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    ),
  );

  Widget _loadError() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_error!, style: const TextStyle(color: AppColors.danger)),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
      ),
    ],
  );

  Widget _settingsForm() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 680;
      final days = int.tryParse(_daysController.text);
      final intervalInput = TextField(
        controller: _daysController,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Custom interval',
          hintText: 'Enter days',
          suffixText: 'days',
          helperText: 'Choose 1 to 3650 days.',
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: AppRadii.medium,
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
        onChanged: (_) => setState(() => _error = null),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: AppRadii.medium,
                ),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspection frequency',
                      style: TextStyle(
                        fontSize: AppTypography.sectionTitle,
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'One schedule for every campus and college.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadii.medium,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.green),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Current interval',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$_savedDays',
                  key: const ValueKey('current-inspection-interval'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Text(
                  'days',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Choose an interval',
            style: TextStyle(
              color: AppColors.darkGreen,
              fontWeight: FontWeight.w700,
              fontSize: AppTypography.label,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Select a common schedule or enter a custom number of days.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final preset in [7, 14, 30]) ...[
                  Expanded(
                    child: _presetCard(preset, selected: days == preset),
                  ),
                  if (preset != 30) const SizedBox(width: AppSpacing.md),
                ],
                const SizedBox(width: AppSpacing.md),
                Expanded(child: intervalInput),
              ],
            )
          else ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final preset in [7, 14, 30])
                  _presetCard(preset, selected: days == preset),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            intervalInput,
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerContainer,
                borderRadius: AppRadii.medium,
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadii.medium,
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.green),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Saving updates the interval for existing plants and recalculates upcoming inspection dates for active plants. New registrations and inspections will use the same university-wide schedule.',
                    style: TextStyle(color: AppColors.darkGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save Schedule'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(170, 48),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.medium,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _presetCard(int days, {required bool selected}) => OutlinedButton(
    onPressed: _saving
        ? null
        : () => setState(() {
            _daysController.text = '$days';
            _error = null;
          }),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      backgroundColor: selected ? AppColors.primaryContainer : Colors.white,
      foregroundColor: AppColors.darkGreen,
      side: BorderSide(
        color: selected ? AppColors.green : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$days days',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, size: 18),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          switch (days) {
            7 => 'Weekly',
            14 => 'Every two weeks',
            _ => 'About monthly',
          },
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTypography.caption,
          ),
        ),
      ],
    ),
  );
}
