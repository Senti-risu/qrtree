import 'package:flutter/material.dart';

import '../services/qr_problem_service.dart';
import '../utils/user_facing_error.dart';

Future<void> showQrProblemDialog(BuildContext context, int plantId) async {
  final messenger = ScaffoldMessenger.of(context);
  final description = TextEditingController();
  final form = GlobalKey<FormState>();
  var problem = 'damaged';
  var saving = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => PopScope(
        canPop: !saving,
        child: AlertDialog(
          scrollable: true,
          title: const Text('Report QR problem'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Describe what happened to this plant’s QR label. Your College Admin will review the report.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: problem,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'QR problem'),
                    items: QrProblemService.problems.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => update(() => problem = value!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: description,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                      hintText:
                          'Example: The label is faded and cannot be scanned.',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Please describe the problem.'
                        : null,
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await QrProblemService().report(
                          plantId,
                          problem,
                          description.text,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (messenger.mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'QR problem reported to your College Admin.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            error = userFacingError(
                              e,
                              fallback:
                                  'Could not submit the report. Please try again.',
                            );
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Sending…' : 'Submit report'),
            ),
          ],
        ),
      ),
    ),
  );
  // The dialog route finishes its closing animation before disposing its field.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  description.dispose();
}
