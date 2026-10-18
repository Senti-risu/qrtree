import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_session.dart';
import '../utils/user_facing_error.dart';

class PlantTimeline extends StatefulWidget {
  const PlantTimeline({super.key, required this.plantId});
  final int plantId;
  @override
  State<PlantTimeline> createState() => _PlantTimelineState();
}

class _PlantTimelineState extends State<PlantTimeline> {
  late Future<List<dynamic>> _events;
  int _visible = 10;
  Future<List<dynamic>> _load() async =>
      (await Supabase.instance.client
              .rpc(
                'plant_monitoring_timeline',
                params: {
                  'p_session_token': AppSession.requiredToken,
                  'p_plant_id': widget.plantId,
                },
              )
              .timeout(const Duration(seconds: 20)))
          as List;
  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Plant timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          FutureBuilder<List<dynamic>>(
            future: _events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(
                      userFacingError(
                        snapshot.error!,
                        fallback: 'Timeline unavailable.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _events = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final events = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final event in events.take(_visible))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timeline),
                      title: Text('${event['title']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateTime.tryParse('${event['occurred_at']}')?.toLocal() ?? event['occurred_at']}',
                          ),
                          Text('${event['description'] ?? ''}'),
                          if (event['photo_url'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Image.network(
                                '${event['photo_url']}',
                                height: 160,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Text('Photo unavailable'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_visible < events.length)
                    TextButton(
                      onPressed: () => setState(() => _visible += 10),
                      child: const Text('Show earlier events'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
