import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../screens/admin/plant_service.dart';
import '../../services/inspection_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_error_state.dart';

class InspectionFormScreen extends StatefulWidget {
  final Map<String, dynamic> plant;
  final int userId;

  const InspectionFormScreen({
    super.key,
    required this.plant,
    required this.userId,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _inspectionService = InspectionService();
  final _plantService = PlantService();
  final _imagePicker = ImagePicker();
  final _observation = TextEditingController();

  List<Map<String, dynamic>> _health = [];
  List<Map<String, dynamic>> _growth = [];
  int? _healthId;
  int? _growthId;
  int? _initialHealthId;
  int? _initialGrowthId;
  XFile? _photo;
  bool _healthConfirmed = false;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  String? _loadError;
  String? _selectionError;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  bool get _hasUnsavedWork =>
      _photo != null ||
      _observation.text.trim().isNotEmpty ||
      _healthConfirmed ||
      _healthId != _initialHealthId ||
      _growthId != _initialGrowthId;

  @override
  void initState() {
    super.initState();
    _observation.addListener(_refreshDirtyState);
    _loadOptions();
  }

  void _refreshDirtyState() {
    if (mounted) setState(() {});
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _plantService.getHealthStatuses(),
        _plantService.getGrowthStatuses(),
      ]);
      if (!mounted) return;
      final currentHealth = widget.plant['health_status_id'] as int?;
      final currentGrowth = widget.plant['growth_status_id'] as int?;
      setState(() {
        _health = results[0];
        _growth = results[1];
        _healthId = currentHealth;
        _growthId = currentGrowth;
        _initialHealthId = currentHealth;
        _initialGrowthId = currentGrowth;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = technicalErrorDetails(error);
      });
    }
  }

  Future<void> _choosePhotoSource() async {
    if (_saving) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'Add a current plant photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                subtitle: const Text('Use the device camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (error) {
      if (!mounted) return;
      _message(
        userFacingError(
          error,
          fallback:
              'The photo could not be added. Check camera permission and try again.',
        ),
        error: true,
      );
    }
  }

  Future<void> _save() async {
    setState(() {
      _selectionError = !_healthConfirmed
          ? 'Confirm the plant health before saving this inspection.'
          : null;
    });
    if (_healthId == null || _growthId == null) {
      _message('Select a health condition and growth stage.', error: true);
      return;
    }
    if (!_healthConfirmed) return;

    setState(() => _saving = true);
    try {
      String? photoUrl;
      if (_photo != null) {
        final extension = _photo!.name.contains('.')
            ? _photo!.name.split('.').last.toLowerCase()
            : 'jpg';
        photoUrl = await _inspectionService.uploadInspectionPhoto(
          plantId: widget.plant['plant_id'] as int,
          bytes: await _photo!.readAsBytes(),
          extension: extension,
        );
      }
      await _inspectionService.saveInspection(
        plantId: widget.plant['plant_id'] as int,
        inspectedBy: widget.userId,
        healthStatusId: _healthId!,
        growthStatusId: _growthId!,
        observation: _observation.text.trim(),
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      _allowPop = true;
      _message('Inspection saved successfully.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        userFacingError(
          error,
          fallback: 'The inspection could not be saved. Please try again.',
        ),
        error: true,
      );
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppColors.danger : AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedWork) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard this inspection?'),
            content: const Text(
              'Your selected condition, photo, and notes have not been saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _observation
      ..removeListener(_refreshDirtyState)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classification = _map(widget.plant['plant_classification']);
    final commonName = classification['common_name']?.toString() ?? 'Plant';
    return PopScope(
      canPop: _allowPop || !_hasUnsavedWork,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final discard = await _confirmDiscard();
        if (!mounted || !discard) return;
        setState(() => _allowPop = true);
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Inspect Plant'),
          backgroundColor: AppColors.background,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              )
            : _loadError != null
            ? AppErrorState(
                title: 'Unable to prepare the inspection',
                message: userFacingError(
                  _loadError!,
                  fallback:
                      'The condition choices could not be loaded. Please try again.',
                ),
                technicalDetails: _loadError,
                onRetry: _loadOptions,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
                children: [
                  _plantSummary(commonName),
                  const SizedBox(height: 18),
                  _sectionHeading(
                    number: '1',
                    title: 'Add a current photo',
                    subtitle: 'Recommended for tracking visible changes',
                  ),
                  const SizedBox(height: 10),
                  _photoField(),
                  const SizedBox(height: 22),
                  _sectionHeading(
                    number: '2',
                    title: 'Confirm the condition',
                    subtitle: 'Choose what you observe today',
                  ),
                  const SizedBox(height: 10),
                  _healthChoices(),
                  if (_selectionError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _selectionError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _growthDropdown(),
                  const SizedBox(height: 22),
                  _sectionHeading(
                    number: '3',
                    title: 'Add observations',
                    subtitle:
                        'Describe damage, symptoms, or maintenance needed',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _observation,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: 7,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Observation (optional)',
                      hintText: 'Example: Yellow leaves on the lower branches…',
                      helperText:
                          'Avoid entering private personal information.',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _loading || _loadError != null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _saving ? 'Saving inspection…' : 'Review and save',
                  ),
                ),
              ),
      ),
    );
  }

  Widget _plantSummary(String commonName) {
    final healthName = _labelFor(
      _health,
      _initialHealthId,
      'health_status_id',
      'status_name',
    );
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.local_florist, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commonName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PNT-${widget.plant['plant_id'].toString().padLeft(3, '0')}  •  Previous: ${_friendlyHealth(healthName)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading({
    required String number,
    required String title,
    required String subtitle,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
        ),
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _photoField() => InkWell(
    onTap: _choosePhotoSource,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: _photo == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 42,
                  color: AppColors.green,
                ),
                SizedBox(height: 8),
                Text(
                  'Take or choose a photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'Tap to add evidence of the current condition',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                FutureBuilder<Uint8List>(
                  future: _photo!.readAsBytes(),
                  builder: (context, snapshot) => snapshot.hasData
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 220,
                          ),
                        )
                      : const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'Remove photo',
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _healthChoices() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _health.map((row) {
      final id = row['health_status_id'] as int;
      final label = _friendlyHealth(
        row['status_name']?.toString() ?? 'Unknown',
      );
      final selected = _healthId == id;
      return ChoiceChip(
        selected: selected,
        showCheckmark: true,
        avatar: Icon(_healthIcon(label), size: 18),
        label: Text(label),
        onSelected: _saving
            ? null
            : (_) => setState(() {
                _healthId = id;
                _healthConfirmed = true;
                _selectionError = null;
              }),
        selectedColor: AppColors.primaryContainer,
        side: BorderSide(color: selected ? AppColors.green : AppColors.border),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.darkGreen : AppColors.textPrimary,
        ),
      );
    }).toList(),
  );

  Widget _growthDropdown() => DropdownButtonFormField<int>(
    initialValue: _growth.any((row) => row['growth_status_id'] == _growthId)
        ? _growthId
        : null,
    decoration: InputDecoration(
      labelText: 'Growth stage',
      helperText: 'Keep the existing stage or select a new one.',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    items: _growth
        .map(
          (row) => DropdownMenuItem<int>(
            value: row['growth_status_id'] as int,
            child: Text(row['growth_stage']?.toString() ?? 'Unknown'),
          ),
        )
        .toList(),
    onChanged: _saving ? null : (value) => setState(() => _growthId = value),
  );

  String _labelFor(
    List<Map<String, dynamic>> rows,
    int? id,
    String idKey,
    String labelKey,
  ) {
    for (final row in rows) {
      if (row[idKey] == id) return row[labelKey]?.toString() ?? 'Not recorded';
    }
    return 'Not recorded';
  }

  String _friendlyHealth(String value) {
    switch (value.trim().toLowerCase()) {
      case 'alive':
      case 'healthy':
        return 'Healthy';
      case 'dying':
      case 'at risk':
        return 'Needs attention';
      case 'dead':
        return 'Dead';
      default:
        return 'Not recorded';
    }
  }

  IconData _healthIcon(String label) => label == 'Healthy'
      ? Icons.eco_outlined
      : label == 'Needs attention'
      ? Icons.warning_amber_rounded
      : label == 'Dead'
      ? Icons.local_florist_outlined
      : Icons.help_outline_rounded;
}
