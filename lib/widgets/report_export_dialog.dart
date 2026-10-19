import 'package:flutter/material.dart';
import '../services/report_export_data.dart';

enum ReportExportFormat { pdf, csv }

class ReportExportChoice {
  const ReportExportChoice(this.kind, this.format, this.period);
  final ReportKind kind;
  final ReportExportFormat format;
  final DateTimeRange? period;
}

class ReportExportDialog extends StatefulWidget {
  const ReportExportDialog({super.key});
  @override
  State<ReportExportDialog> createState() => _ReportExportDialogState();
}

class _ReportExportDialogState extends State<ReportExportDialog> {
  ReportKind _kind = ReportKind.inventory;
  ReportExportFormat _format = ReportExportFormat.pdf;
  DateTimeRange? _period;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Export Report'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ReportKind>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Report'),
              items: [
                for (final kind in ReportKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (kind) => setState(() => _kind = kind!),
            ),
            const SizedBox(height: 16),
            Text(
              _kind == ReportKind.outcomes
                  ? 'Full assigned scope. Page filters do not apply. Includes survival, 30-day inspection coverage, and health observations.'
                  : 'Uses the matching active plants and filters on this page. The page date range filters registration dates, not planting or inspection dates.',
            ),
            if (_kind == ReportKind.history) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  _period == null
                      ? 'All Inspection Dates'
                      : '${ReportExportData.date(_period!.start)} to ${ReportExportData.date(_period!.end)}',
                ),
                onPressed: () async {
                  final now = ReportExportData.manilaNow();
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(now.year, now.month, now.day),
                    initialDateRange: _period,
                  );
                  if (range != null && mounted) setState(() => _period = range);
                },
              ),
              if (_period != null)
                TextButton(
                  onPressed: () => setState(() => _period = null),
                  child: const Text('Clear Inspection Dates'),
                ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<ReportExportFormat>(
              initialValue: _format,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Format'),
              items: const [
                DropdownMenuItem(
                  value: ReportExportFormat.pdf,
                  child: Text('Print / Save PDF'),
                ),
                DropdownMenuItem(
                  value: ReportExportFormat.csv,
                  child: Text('Spreadsheet (CSV for Excel)'),
                ),
              ],
              onChanged: (format) => setState(() => _format = format!),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(
          context,
          ReportExportChoice(
            _kind,
            _format,
            _kind == ReportKind.history ? _period : null,
          ),
        ),
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('Continue'),
      ),
    ],
  );
}
