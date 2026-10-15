import 'package:flutter/material.dart';

import '../../services/qr_problem_service.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_error_state.dart';

class QrProblemReportsScreen extends StatefulWidget {
  const QrProblemReportsScreen({super.key, required this.canReview});
  final bool canReview;

  @override
  State<QrProblemReportsScreen> createState() => _QrProblemReportsScreenState();
}

class _QrProblemReportsScreenState extends State<QrProblemReportsScreen> {
  final _service = QrProblemService();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;

  String _reportedAt(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    final labels = MaterialLocalizations.of(context);
    return '${labels.formatMediumDate(local)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

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
      final rows = await _service.list();
      if (mounted) setState(() => _reports = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> report, bool confirm) async {
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(confirm ? 'Confirm QR problem?' : 'Dismiss report?'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                confirm
                    ? 'The label will be marked damaged and scanning will be blocked. Replace the label from QR Management.'
                    : 'Explain why this report does not need a label change.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: note,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Review note'),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Enter a review note.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, note.text.trim());
              }
            },
            child: Text(confirm ? 'Confirm and mark damaged' : 'Dismiss'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    note.dispose();
    if (result == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await _service.review(
        (report['report_id'] as num).toInt(),
        confirm,
        result,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not review this report. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.canReview ? 'QR problem reports' : 'My QR reports'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? AppErrorState(
            title: 'Unable to load QR reports',
            message: userFacingError(_error!),
            technicalDetails: _error,
            onRetry: _load,
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No QR problem reports yet. Open a plant from Plants to report a damaged, faded, missing, or incorrect label.',
                    ),
                  ),
                for (final report in _reports)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${report['common_name'] ?? 'Plant'} · ${report['status']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              SelectableText('${report['qr_code_string']}'),
                              Text(
                                QrProblemService.problems[report['problem']] ??
                                    'QR problem',
                              ),
                              const SizedBox(height: 8),
                              Text('${report['description']}'),
                              const SizedBox(height: 8),
                              Text(
                                'Reported by ${report['reported_by']} · ${_reportedAt(report['created_at'])}',
                              ),
                              if (report['review_note'] != null)
                                Text('Review: ${report['review_note']}'),
                              if (widget.canReview &&
                                  report['status'] == 'pending')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton(
                                        onPressed: () => _review(report, true),
                                        child: const Text('Confirm problem'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _review(report, false),
                                        child: const Text('Dismiss'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}
