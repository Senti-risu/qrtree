import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the installed package, not a hard-coded pubspec version.
class AppVersionInfo extends StatefulWidget {
  const AppVersionInfo({super.key});

  @override
  State<AppVersionInfo> createState() => _AppVersionInfoState();
}

class _AppVersionInfoState extends State<AppVersionInfo> {
  late final Future<String> _label = _load();

  Future<String> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'EcoTag ${info.version} (build ${info.buildNumber})';
    } catch (_) {
      return 'EcoTag · Version unavailable';
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _label,
    builder: (context, snapshot) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        snapshot.data ?? 'EcoTag · Loading version…',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}
