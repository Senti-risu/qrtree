import 'package:flutter/material.dart';

class QrBatchPrintDialog extends StatefulWidget {
  const QrBatchPrintDialog({
    super.key,
    required this.tags,
    required this.status,
  });

  final List<Map<String, dynamic>> tags;
  final String status;

  @override
  State<QrBatchPrintDialog> createState() => _QrBatchPrintDialogState();
}

class _QrBatchPrintDialogState extends State<QrBatchPrintDialog> {
  late final Set<int> _selected = {
    for (var index = 0; index < widget.tags.length; index++) index,
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.status == 'damaged' ? 'Batch Reprint' : 'Batch Print'),
    content: SizedBox(
      width: 480,
      height: MediaQuery.sizeOf(context).height * .45,
      child: ListView(
        children: [
          Text(
            '${widget.tags.length} ${widget.status} QR tags match your search.',
          ),
          if (widget.status == 'damaged') ...[
            const SizedBox(height: 8),
            const Text(
              'Print the same QR codes. Confirm labels are ready afterward to clear damage.',
            ),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${_selected.length} selected'),
            value: _selected.length == widget.tags.length,
            onChanged: (all) => setState(() {
              _selected.clear();
              if (all == true) {
                _selected.addAll(List.generate(widget.tags.length, (i) => i));
              }
            }),
          ),
          for (var index = 0; index < widget.tags.length; index++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${widget.tags[index]['qr_code_string']}'),
              value: _selected.contains(index),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _selected.add(index);
                } else {
                  _selected.remove(index);
                }
              }),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, [
                for (var i = 0; i < widget.tags.length; i++)
                  if (_selected.contains(i)) widget.tags[i],
              ]),
        icon: const Icon(Icons.print_outlined),
        label: Text('Print ${_selected.length}'),
      ),
    ],
  );
}
