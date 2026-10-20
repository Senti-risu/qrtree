import 'package:flutter/material.dart';
import '../services/plant_service.dart';
import '../services/plant_location_service.dart';
import '../utils/user_facing_error.dart';
import 'forms/planting_campus_dropdown.dart';

class PlantLocationEditor extends StatefulWidget {
  const PlantLocationEditor({super.key, required this.plantId});
  final int plantId;
  @override
  State<PlantLocationEditor> createState() => _PlantLocationEditorState();
}

class _PlantLocationEditorState extends State<PlantLocationEditor> {
  final _form = GlobalKey<FormState>();
  final _service = PlantLocationService();
  List<Map<String, dynamic>> _campuses = [], _towns = [], _barangays = [];
  String? _choice, _error;
  int? _town, _barangay;
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lookup = PlantService();
      final lists = await Future.wait([
        lookup.getCampuses(),
        lookup.getTowns(),
        lookup.getBarangays(),
      ]);
      final location = await _service.get(widget.plantId);
      if (!mounted) return;
      setState(() {
        _campuses = lists[0];
        _towns = List<Map<String, dynamic>>.of(lists[1])
          ..sort(
            (a, b) => a['town_name'].toString().trim().toLowerCase().compareTo(
              b['town_name'].toString().trim().toLowerCase(),
            ),
          );
        _barangays = List<Map<String, dynamic>>.of(lists[2])
          ..sort(
            (a, b) => a['barangay_name']
                .toString()
                .trim()
                .toLowerCase()
                .compareTo(b['barangay_name'].toString().trim().toLowerCase()),
          );
        _choice = location['planting_location_type'] == 'outside'
            ? 'outside'
            : location['planting_campus_id']?.toString();
        _town = location['town_id'] as int?;
        _barangay = location['barangay_id'] as int?;
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.update(widget.plantId, _choice!, _town!, _barangay!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Planting Location'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose where the plant is planted. Its managing campus and college remain assigned to your account.',
                    ),
                    const SizedBox(height: 16),
                    if (_campuses.isNotEmpty) ...[
                      PlantingCampusDropdown(
                        campuses: _campuses,
                        value: _choice,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _choice = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _town,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Planting Town',
                        ),
                        items: _towns
                            .map(
                              (t) => DropdownMenuItem(
                                value: t['town_id'] as int,
                                child: Text(
                                  '${t['town_name']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                _town = v;
                                _barangay = null;
                              }),
                        validator: (v) => v == null ? 'Select a town.' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: ValueKey('$_town-$_barangay'),
                        initialValue: _barangay,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Planting Barangay',
                        ),
                        items: _barangays
                            .where((b) => b['town_id'] == _town)
                            .map(
                              (b) => DropdownMenuItem(
                                value: b['barangay_id'] as int,
                                child: Text(
                                  '${b['barangay_name']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving || _town == null
                            ? null
                            : (v) => setState(() => _barangay = v),
                        validator: (v) =>
                            v == null ? 'Select a barangay.' : null,
                      ),
                    ],
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
                    if (_campuses.isEmpty)
                      TextButton(
                        onPressed: _load,
                        child: const Text('Try Again'),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _loading || _campuses.isEmpty ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save location'),
        ),
      ],
    ),
  );
}
