import 'package:flutter/material.dart';
import '../../services/inspection_draft_store.dart';
import '../../services/inspection_sync_service.dart';
import '../../services/inspection_service.dart';
import '../../services/plant_service.dart';
import '../../utils/user_facing_error.dart';
import '../qr/qr_scanner.dart';
import 'inspection_form_screen.dart';

class InspectionOutboxScreen extends StatefulWidget {
  const InspectionOutboxScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
  });
  final int userId;
  final String username;
  final String role;
  @override
  State<InspectionOutboxScreen> createState() => _InspectionOutboxScreenState();
}

class _InspectionOutboxScreenState extends State<InspectionOutboxScreen> {
  final _store = InspectionDraftStore();
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _plants = [];
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final drafts = await _store.list(widget.userId);
      final plants = await _store.plants(widget.userId);
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _plants = plants;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    }
  }

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = InspectionService();
      final options = await Future.wait([
        PlantService().getHealthStatuses(),
        PlantService().getGrowthStatuses(),
      ]);
      final queue = await service.listInspectionQueue(filter: 'all');
      final plantIds = queue
          .map((plant) => plant['plant_id'])
          .whereType<int>()
          .toList();
      final fetchedPlants = await service.getPlants(plantIds);
      final plantsById = {
        for (final plant in fetchedPlants) plant['plant_id'] as int: plant,
      };
      final plants = <Map<String, dynamic>>[];
      for (final plantId in plantIds) {
        final plant = plantsById[plantId];
        if (plant == null) {
          throw StateError(
            'An assigned plant could not be downloaded. Please try again.',
          );
        }
        plants.add(plant);
      }
      await _store.cacheOptions(widget.userId, options);
      await _store.cachePlants(widget.userId, plants);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    for (final draft in _drafts.where((d) => d['ready'] == true)) {
      try {
        await InspectionSyncService(store: _store).submit(widget.userId, draft);
      } catch (e) {
        if (mounted) {
          setState(
            () => _error = userFacingError(
              e,
              fallback:
                  'Upload failed. Your inspection is still saved on this device.',
            ),
          );
        }
        break;
      }
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _showPending(Map<String, dynamic> draft) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Pending inspection • Plant #${draft['plantId']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Observed: ${draft['observedAt']}'),
            Text('${draft['observation'] ?? ''}'),
            const SizedBox(height: 12),
            const Text(
              'This confirmed inspection is kept unchanged for safe retries. Use Upload pending inspections to retry. Delete an obsolete submission before starting a new observation.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Offline Inspections'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Drafts and photos stay on this device. Download assigned plants while online, then scan a plant QR to start an offline inspection. Submit pending inspections when you have a connection.',
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        if (_busy) const LinearProgressIndicator(),
        FilledButton.icon(
          onPressed: _busy ? null : _sync,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Upload Pending Inspections'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _prepare,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download Assigned Plants For Offline Work'),
        ),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QrScannerScreen(
                        userId: widget.userId,
                        username: widget.username,
                        role: widget.role,
                        offlineInspectionMode: true,
                      ),
                    ),
                  );
                  await _load();
                },
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan QR To Start An Offline Inspection'),
        ),
        if (_drafts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No inspections saved on this device.'),
          ),
        for (final draft in _drafts)
          Card(
            child: ListTile(
              title: Text('Plant #${draft['plantId']}'),
              subtitle: Text(
                '${draft['ready'] == true ? 'Pending Upload' : 'Draft • needs review'}\n${draft['observedAt']}',
              ),
              isThreeLine: true,
              onTap: _busy
                  ? null
                  : () async {
                      if (draft['ready'] == true) {
                        await _showPending(draft);
                        return;
                      }
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InspectionFormScreen(
                            plant: Map<String, dynamic>.from(
                              draft['plant'] as Map,
                            ),
                            userId: widget.userId,
                            draft: draft,
                          ),
                        ),
                      );
                      _load();
                    },
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Draft',
                onPressed: _busy
                    ? null
                    : () async {
                        final delete = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete local inspection?'),
                            content: const Text(
                              'The saved notes and photo will be removed from this device.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (delete == true) {
                          await _store.remove(
                            widget.userId,
                            draft['id'] as String,
                          );
                          await _load();
                        }
                      },
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Downloaded plants (${_plants.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final plant in _plants)
          ListTile(
            title: Text(
              'Plant #${plant['plant_id']} • ${(plant['plant_classification'] as Map?)?['common_name'] ?? 'Plant'}',
            ),
            subtitle: const Text('Scan this plant’s QR to start an inspection'),
          ),
      ],
    ),
  );
}
