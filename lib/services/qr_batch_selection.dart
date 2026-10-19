import 'qr_service.dart';

typedef QrTagPageLoader =
    Future<List<Map<String, dynamic>>> Function({
      String? status,
      String? search,
      int limit,
      int offset,
    });

/// Loads the complete matching batch, not just the management page on screen.
Future<List<Map<String, dynamic>>> loadPrintableQrBatch({
  required QrTagPageLoader loadPage,
  required String filter,
  required String search,
}) async {
  // Preserve the original available-only default in the All Statuses view.
  final status = filter == 'all' ? 'available' : filter;
  if (!{'available', 'assigned', 'damaged'}.contains(status)) return [];
  const pageSize = 100;
  final tags = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var offset = 0; ; offset += pageSize) {
    final page = await loadPage(
      status: status,
      search: search,
      limit: pageSize,
      offset: offset,
    );
    for (final tag in page) {
      final code = tag['qr_code_string']?.toString().trim() ?? '';
      if (QrService.statusOf(tag) == status &&
          code.isNotEmpty &&
          seen.add(code)) {
        tags.add(tag);
      }
    }
    if (page.length < pageSize) break;
  }
  return tags;
}
