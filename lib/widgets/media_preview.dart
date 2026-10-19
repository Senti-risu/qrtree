import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showQrDetails(
  BuildContext context, {
  required String code,
  Map<String, String> details = const {},
  VoidCallback? onOpenPlant,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    scrollable: true,
    title: const Text('QR Details'),
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (code.isNotEmpty)
            SizedBox.square(
              dimension: (MediaQuery.sizeOf(context).width - 128).clamp(
                100.0,
                320.0,
              ),
              child: QrImageView(
                data: code,
                backgroundColor: Colors.white,
                semanticsLabel: 'QR preview',
              ),
            ),
          SelectableText(code.isEmpty ? 'QR unavailable' : code),
          for (final entry in details.entries)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${entry.key}: ${entry.value}'),
            ),
        ],
      ),
    ),
    actions: [
      if (onOpenPlant != null)
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onOpenPlant();
          },
          child: const Text('View Plant Details'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

class ViewablePhoto extends StatelessWidget {
  const ViewablePhoto({super.key, required this.url, required this.child});
  final String url;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'View Photo Full Screen',
    child: Tooltip(
      message: 'View photo',
      child: InkWell(
        onTap: url.trim().isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(title: const Text('Photo')),
                    body: SafeArea(
                      child: Center(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5,
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (_, _, _) => const Text(
                              'Photo Unavailable',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        child: child,
      ),
    ),
  );
}
