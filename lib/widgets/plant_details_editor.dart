import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/plant_record_lock.dart';
import '../services/plant_service.dart';
import '../services/plant_details_editor_service.dart';
import '../utils/user_facing_error.dart';
import '../theme/app_typography.dart';
import 'forms/planting_campus_dropdown.dart';

class PlantDetailsEditor extends StatefulWidget {
  const PlantDetailsEditor({
    super.key,
    required this.plantId,
    required this.userId,
    this.repository,
  });
  final int plantId, userId;
  final PlantDetailsEditorRepository? repository;
  @override
  State<PlantDetailsEditor> createState() => _PlantDetailsEditorState();
}

class _PlantDetailsEditorState extends State<PlantDetailsEditor> {
  final _form = GlobalKey<FormState>();
  final _variety = TextEditingController(), _planter = TextEditingController();
  late final _service = widget.repository ?? PlantDetailsEditorService();
  List<Map<String, dynamic>> _classes = [],
      _campuses = [],
      _towns = [],
      _barangays = [];
  Map<String, dynamic> _plant = {};
  int? _classification, _town, _barangay;
  String? _type, _choice, _error;
  String _photoUrl = '', _photoExtension = 'jpg';
  DateTime? _date;
  Uint8List? _photo;
  bool _loading = true, _saving = false, _dirty = false, _picking = false;
  bool get _locked => _plant.isNotEmpty && !PlantRecordLock.canEdit(_plant);
  bool get _disabled => _loading || _saving || _picking || _locked;
  Map<String, dynamic> get _selected => _classes.firstWhere(
    (c) => c['classification_id'] == _classification,
    orElse: () => {},
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _variety.dispose();
    _planter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.load(widget.plantId);
      if (!mounted) return;
      final plant = Map<String, dynamic>.from(data['plant'] as Map);
      final location = Map<String, dynamic>.from(data['location'] as Map);
      setState(() {
        _plant = plant;
        _classes = List<Map<String, dynamic>>.from(data['classifications']);
        _campuses = List<Map<String, dynamic>>.from(data['campuses']);
        _towns = List<Map<String, dynamic>>.from(data['towns']);
        _barangays = List<Map<String, dynamic>>.from(data['barangays']);
        _classification = plant['classification_id'] as int?;
        _type = _selected['plant_type']?.toString();
        _variety.text = plant['variety']?.toString() ?? '';
        _planter.text = plant['tree_planter']?.toString() ?? '';
        _date = DateTime.tryParse(plant['date_planted']?.toString() ?? '');
        _photoUrl = plant['photo_url']?.toString() ?? '';
        _choice = location['planting_location_type'] == 'outside'
            ? 'outside'
            : location['planting_campus_id']?.toString();
        _town = location['town_id'] as int?;
        _barangay = location['barangay_id'] as int?;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            e,
            fallback: 'Plant details could not be loaded. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_disabled || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_photo != null) {
        final url = await _service.uploadPhoto(
          widget.userId,
          _photo!,
          _photoExtension,
        );
        if (!mounted) return;
        // Keep the uploaded URL for retries. Never delete an image when a
        // network failure leaves the database commit outcome uncertain.
        setState(() {
          _photoUrl = url;
          _photo = null;
        });
      }
      await _service.save(
        widget.plantId,
        PlantDetailsDraft(
          classificationId: _classification!,
          variety: _variety.text,
          treePlanter: _planter.text,
          datePlanted: _date,
          photoUrl: _photoUrl,
          locationChoice: _choice!,
          townId: _town!,
          barangayId: _barangay!,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(
            e,
            fallback:
                'Changes could not be saved. Your entries are still here; try again.',
          );
        });
      }
    }
  }

  Future<void> _close() async {
    if (_saving || _picking) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved plant details will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = PlantPhotoRules.validate(
        bytes: bytes,
        extension: image.name.contains('.')
            ? image.name.split('.').last
            : 'jpg',
      );
      if (mounted) {
        setState(() {
          _photo = bytes;
          _photoExtension = extension;
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Photo could not be added. Check permissions and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date == null || _date!.isAfter(today)
          ? today
          : _date!.isBefore(DateTime(1800))
          ? DateTime(1800)
          : _date!,
      firstDate: DateTime(1800),
      lastDate: today,
    );
    if (selected != null && mounted) {
      setState(() {
        _date = selected;
        _dirty = true;
      });
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: AppTypography.sectionTitle,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  Widget _dropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required String id,
    required String name,
    required ValueChanged<int?> changed,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<int>(
      key: ValueKey('$label-$value'),
      initialValue: items.any((item) => item[id] == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem<int>(
              value: item[id] as int,
              child: Text('${item[name]}', overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _disabled
          ? null
          : (v) => setState(() {
              changed(v);
              _dirty = true;
            }),
      validator: (v) => v == null ? 'Select ${label.toLowerCase()}.' : null,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_picking && !_dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(16),
      title: const Text('Update plant details'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _plant.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Plant not available.'),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              )
            : Form(
                key: _form,
                onChanged: () => _dirty = true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_locked)
                      const Text(
                        'This plant is locked or archived and cannot be edited.',
                      ),
                    const Text(
                      'Managing campus, college and EcoTag code stay the same. Record health and growth changes through Inspect Plant.',
                    ),
                    _heading('Plant Classification'),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Plant type',
                      ),
                      items: _classes
                          .map((c) => c['plant_type'].toString())
                          .toSet()
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: _disabled
                          ? null
                          : (v) => setState(() {
                              _type = v;
                              _classification = null;
                              _dirty = true;
                            }),
                      validator: (v) =>
                          v == null ? 'Select a plant type.' : null,
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      label: 'Common name',
                      value: _classification,
                      items: _classes
                          .where((c) => c['plant_type'].toString() == _type)
                          .toList(),
                      id: 'classification_id',
                      name: 'common_name',
                      changed: (v) => _classification = v,
                    ),
                    TextFormField(
                      key: ValueKey('scientific-$_classification'),
                      initialValue:
                          _selected['scientific_name']?.toString() ?? '',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Scientific name',
                        helperText: 'Based on the selected common name.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _variety,
                      enabled: !_disabled,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Variety (optional)',
                      ),
                    ),
                    TextFormField(
                      controller: _planter,
                      enabled: !_disabled,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Tree planter (optional)',
                      ),
                    ),
                    TextFormField(
                      key: ValueKey('date-$_date'),
                      readOnly: true,
                      enabled: !_disabled,
                      initialValue: _date == null
                          ? ''
                          : MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(_date!),
                      onTap: _disabled ? null : _pickDate,
                      decoration: InputDecoration(
                        labelText: 'Date planted (optional)',
                        prefixIcon: const Icon(Icons.event_outlined),
                        suffixIcon: _date == null
                            ? null
                            : IconButton(
                                tooltip: 'Clear date planted',
                                onPressed: _disabled
                                    ? null
                                    : () => setState(() {
                                        _date = null;
                                        _dirty = true;
                                      }),
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                    _heading('Planting location'),
                    PlantingCampusDropdown(
                      campuses: _campuses,
                      value: _choice,
                      onChanged: _disabled
                          ? null
                          : (v) => setState(() {
                              _choice = v;
                              _dirty = true;
                            }),
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      label: 'Planting town',
                      value: _town,
                      items: _towns,
                      id: 'town_id',
                      name: 'town_name',
                      changed: (v) {
                        _town = v;
                        _barangay = null;
                      },
                    ),
                    _dropdown(
                      label: 'Planting barangay',
                      value: _barangay,
                      items: _barangays
                          .where((b) => b['town_id'] == _town)
                          .toList(),
                      id: 'barangay_id',
                      name: 'barangay_name',
                      changed: (v) => _barangay = v,
                    ),
                    _heading('Plant photo'),
                    if (_photo != null)
                      Image.memory(_photo!, height: 140, fit: BoxFit.contain)
                    else if (_photoUrl.isNotEmpty)
                      Image.network(
                        _photoUrl,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Text(
                          'Existing photo will be kept unless you change or remove it.',
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _disabled ? null : _pickPhoto,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _picking ? 'Opening photo…' : 'Choose or replace photo',
                      ),
                    ),
                    if (_photo != null || _photoUrl.isNotEmpty)
                      TextButton(
                        onPressed: _disabled
                            ? null
                            : () => setState(() {
                                _photo = null;
                                _photoUrl = '';
                                _dirty = true;
                              }),
                        child: const Text('Remove photo'),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving || _picking ? null : _close,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _disabled || _plant.isEmpty ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save changes'),
        ),
      ],
    ),
  );
}
