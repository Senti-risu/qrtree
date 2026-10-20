import '../../widgets/app_search_field.dart';
import 'dart:async';
import '../../widgets/media_preview.dart';
import '../../widgets/plant_details_presentation.dart';
import '../plants/plant_detail_screen.dart';

import 'package:flutter/material.dart';
import 'widgets/qr_numbering_info.dart';
import '../../widgets/app_workspace_page.dart';
import '../../widgets/compact_filter_panel.dart';
import '../../theme/app_typography.dart';
import '../../models/app_role.dart';
import '../../services/qr_print_service.dart';
import '../../services/qr_batch_selection.dart';
import '../../widgets/qr_batch_print_dialog.dart';
import '../../services/qr_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_filter_sheet.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/qr_mobile_tag_list.dart';

import '../../widgets/qr_tag_actions.dart';
import 'qr_problem_reports_screen.dart';

class QrManagementScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;
  final QrService? qrService;
  final QrPrintService? printService;

  const QrManagementScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
    this.qrService,
    this.printService,
  });

  @override
  State<QrManagementScreen> createState() => _QrManagementScreenState();
}

class _QrManagementScreenState extends State<QrManagementScreen> {
  static const int _pageSize = 100;
  late final QrService _qrService = widget.qrService ?? QrService();
  late final QrPrintService _printService =
      widget.printService ?? QrPrintService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _tags = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _generating = false;
  bool _printingBatch = false;
  final Set<int> _updatingTags = <int>{};
  String _filter = 'all';
  int _loadRequestId = 0;
  Timer? _searchDebounce;

  Map<String, dynamic> get _userArguments => {
    'user_id': widget.userId,
    'username': widget.username,
    'role': widget.role,
    'campus_id': widget.campusId,
    'college_id': widget.collegeId,
  };

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleTags => _tags;

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty || _filter != 'all';

  int get _activeFilterCount => _filter == 'all' ? 0 : 1;

  static const Map<String, String> _statusFilters = {
    'available': 'Available',
    'assigned': 'Assigned',
    'damaged': 'Damaged',
    'replaced': 'Replaced',
    'retired': 'Retired',
    'all': 'All Statuses',
  };

  Future<void> _loadTags({bool more = false}) async {
    if (more && (_loadingMore || !_hasMore)) return;
    final requestId = ++_loadRequestId;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
      }
    });
    try {
      final tags = await _qrService.getTags(
        status: _filter == 'all' ? null : _filter,
        search: _searchController.text,
        limit: _pageSize,
        offset: more ? _tags.length : 0,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _tags = more ? [..._tags, ...tags] : tags;
        _hasMore = tags.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        if (!more) _tags = const [];
        _loading = false;
        _loadingMore = false;
      });
      _message(
        userFacingError(
          e,
          fallback: 'QR tags could not be loaded. Please try again.',
        ),
        error: true,
      );
    }
  }

  Future<void> _resetFilters() async {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _filter = 'all');
    await _loadTags();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadTags);
  }

  Future<void> _openMobileFilters() async {
    var draftFilter = _filter;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AppFilterSheet(
          title: 'Filter QR Tags',
          applyLabel: 'Apply Filters',
          onReset: () => setSheetState(() => draftFilter = 'all'),
          onApply: () => Navigator.pop(sheetContext, draftFilter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tag Status'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _statusFilters.entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: draftFilter == entry.key,
                        onSelected: (_) =>
                            setSheetState(() => draftFilter = entry.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Apply to load matching tags. Your search text is kept.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || selected == _filter || !mounted) return;
    setState(() => _filter = selected);
    await _loadTags();
  }

  Future<void> _generateBatch(int amount) async {
    setState(() => _generating = true);
    try {
      final generated = await _qrService.createQrTags(amount);
      if (!mounted) return;
      _message('${generated.length} QR tags generated.');
      setState(() => _filter = 'available');
      await _loadTags();
    } catch (e) {
      if (!mounted) return;
      _message(
        userFacingError(
          e,
          fallback: 'The QR tags could not be generated. Please try again.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  bool get _canPrintBatch =>
      !_printingBatch &&
      !_loading &&
      _updatingTags.isEmpty &&
      {'all', 'available', 'assigned', 'damaged'}.contains(_filter);

  Future<void> _printBatch() async {
    if (!_canPrintBatch) return;
    final filter = _filter;
    final search = _searchController.text.trim();
    setState(() => _printingBatch = true);
    try {
      final tags = await loadPrintableQrBatch(
        loadPage: _qrService.getTags,
        filter: filter,
        search: search,
      );
      if (!mounted) return;
      if (tags.isEmpty) {
        _message('No printable QR tags match this search and status.');
        return;
      }
      final selected = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (_) => QrBatchPrintDialog(
          tags: tags,
          status: filter == 'all' ? 'available' : filter,
        ),
      );
      if (!mounted || selected == null || selected.isEmpty) return;
      final printed = await _printService.printBatch(selected);
      if (!mounted || !printed || filter != 'damaged') return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Are all replacement QRs ready?'),
          content: Text(
            'Confirm only if all ${selected.length} selected labels printed correctly '
            'and are attached to their plants. This clears their damaged status '
            'without changing the QR codes. Otherwise, keep them damaged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Damaged'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm All Ready'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      var restored = 0;
      for (final tag in selected) {
        final id = _tagId(tag);
        if (id == null) continue;
        try {
          await _qrService.confirmReprinted(qrTagId: id);
          restored++;
        } catch (_) {
          // Keep failed tags damaged and report partial completion accurately.
        }
      }
      if (!mounted) return;
      final remaining = selected.length - restored;
      _message(
        remaining == 0
            ? '$restored QR tags restored. Damaged status cleared.'
            : '$restored QR tags restored; $remaining could not be confirmed. Refresh and try those again.',
        error: remaining > 0,
      );
      await _loadTags();
    } catch (error) {
      if (mounted) {
        _message(
          userFacingError(
            error,
            fallback: 'Could not print the QR batch. Please try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _printingBatch = false);
    }
  }

  Future<String?> _askReason({
    required String title,
    required String message,
    required String actionLabel,
    bool danger = false,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 250,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Briefly explain why this change is needed',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length < 3) return 'Enter at least 3 characters.';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? AppColors.danger : AppColors.green,
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _markDamaged(Map<String, dynamic> tag) async {
    final tagId = _tagId(tag);
    if (tagId == null) return;
    final reason = await _askReason(
      title: 'Mark QR as damaged?',
      message:
          'The plant will keep its current record and QR code. You can reprint the same QR code if you need a new printed QR.',
      actionLabel: 'Mark Damaged',
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _runTagAction(
      tagId,
      action: () => _qrService.markDamaged(qrTagId: tagId, reason: reason),
      success: 'QR marked as damaged.',
    );
  }

  Future<void> _retireTag(Map<String, dynamic> tag) async {
    final tagId = _tagId(tag);
    if (tagId == null) return;
    final reason = await _askReason(
      title: 'Retire this unused QR?',
      message:
          'A retired QR cannot be assigned to a plant. Its history will remain available for administrators.',
      actionLabel: 'Retire QR',
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _runTagAction(
      tagId,
      action: () => _qrService.retireTag(qrTagId: tagId, reason: reason),
      success: 'QR retired.',
    );
  }

  Future<void> _runTagAction(
    int tagId, {
    required Future<void> Function() action,
    required String success,
  }) async {
    setState(() => _updatingTags.add(tagId));
    try {
      await action();
      if (!mounted) return;
      _message(success);
      await _loadTags();
    } catch (error) {
      if (!mounted) return;
      _message(
        userFacingError(
          error,
          fallback: 'The QR could not be updated. Please try again.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _updatingTags.remove(tagId));
    }
  }

  int? _tagId(Map<String, dynamic> tag) {
    final value = tag['qr_tag_id'];
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return AppShell(
      activeRoute: '/qr-management',
      mobileTitle: 'QR Management',
      mobileSubtitle:
          '${_visibleTags.length} of ${_tags.length} ${_tags.length == 1 ? 'tag' : 'tags'}',
      userId: widget.userId,
      username: widget.username,
      role: widget.role,
      campusId: widget.campusId,
      collegeId: widget.collegeId,
      userName: widget.username,
      userRole: _roleLabel(widget.role),
      child: !isDesktop
          ? QrMobileTagList(
              toolbar: _toolbar(),
              header: _listHeader(),
              itemCount: _visibleTags.length,
              itemBuilder: (_, index) => _tagTile(_visibleTags[index]),
              loading: _loading,
              loadingMore: _loadingMore,
              hasMore: _hasMore,
              onLoadMore: () => _loadTags(more: true),
              emptyMessage: _hasActiveFilters
                  ? 'No QR tags match your filters.'
                  : 'No QR tags found.',
            )
          : AppWorkspacePage(
              header: AppPageHeader(
                title: 'QR Management',
                subtitle: 'Generate, print, scan, and monitor EcoTag QR codes',
                trailing: _headerActions(),
              ),
              tools: AppToolbarCard(child: _listHeader()),
              body: _tagList(),
            ),
    );
  }

  Future<void> _openProblemReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const QrProblemReportsScreen(canReview: true),
      ),
    );
    if (mounted) _loadTags();
  }

  Future<void> _openGenerateDialog() async {
    final controller = TextEditingController(text: '20');
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Generate QR Tags'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const QrNumberingInfo(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number Of QR Tags',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                    border: OutlineInputBorder(),
                    helperText: 'Minimum 1, maximum 500',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed < 1 || parsed > 500) {
                      return 'Enter a number from 1 to 500.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(
                        dialogContext,
                        int.parse(controller.text.trim()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, int.parse(controller.text.trim()));
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Generate'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount != null && mounted) await _generateBatch(amount);
  }

  String _roleLabel(String role) {
    final parsed = AppRole.fromValue(role);
    return parsed == AppRole.unknown ? role : parsed.label;
  }

  Widget _toolbar() {
    return AppCard(
      mergeWithParent: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final actions = <Widget>[
            FilledButton.icon(
              onPressed: _generating ? null : _openGenerateDialog,
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_2),
              label: const Text('Generate QR'),
            ),
            OutlinedButton.icon(
              onPressed: _canPrintBatch ? _printBatch : null,
              icon: const Icon(Icons.print_outlined),
              label: Text(_printingBatch ? 'Preparing...' : 'Print Batch'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/qr-scanner',
                arguments: _userArguments,
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
            ),
          ];
          if (AppBreakpoints.isPhone(constraints.maxWidth)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                actions.first,
                const SizedBox(height: AppSpacing.sm),
                if (constraints.maxWidth >= 340 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.1)
                  Row(
                    children: [
                      Expanded(child: actions[1]),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: actions[2]),
                    ],
                  )
                else ...[
                  actions[1],
                  const SizedBox(height: AppSpacing.sm),
                  actions[2],
                ],
              ],
            );
          }
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: actions,
          );
        },
      ),
    );
  }

  Widget _headerActions() => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.end,
    children: [
      FilledButton.icon(
        onPressed: _generating ? null : _openGenerateDialog,
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        icon: _generating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.qr_code_2_rounded),
        label: const Text('Generate'),
      ),
      OutlinedButton.icon(
        onPressed: _canPrintBatch ? _printBatch : null,
        icon: const Icon(Icons.print_outlined),
        label: Text(_printingBatch ? 'Preparing...' : 'Print'),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(
          context,
          '/qr-scanner',
          arguments: _userArguments,
        ),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan'),
      ),
    ],
  );

  Widget _statusDropdown({double? width = 170}) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey(_filter),
      initialValue: _filter,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(
        labelText: 'Status',
        prefixIcon: const Icon(
          Icons.inventory_2_outlined,
          color: AppColors.green,
          size: 20,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
      ),
      items: _statusFilters.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null || value == _filter) return;
        setState(() => _filter = value);
        _loadTags();
      },
    ),
  );

  Widget _tagList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }
    if (_visibleTags.isEmpty) {
      return AppEmptyState(
        title: 'No QR Tags Found',
        message: _hasActiveFilters
            ? 'Try another search or reset your filters.'
            : 'Generate QR tags to get started.',
        icon: Icons.qr_code_2_rounded,
        action: _hasActiveFilters
            ? TextButton(
                onPressed: _resetFilters,
                child: const Text('Reset Filters'),
              )
            : null,
      );
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._visibleTags.map(_desktopTagCard),
          if (_hasMore) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _loadTags(more: true),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_loadingMore ? 'Loading…' : 'Load More QR Tags'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField() => AppSearchField(
    controller: _searchController,
    suggestions: _tags
        .expand(
          (tag) => [
            tag['qr_code_string'],
            tag['common_name'],
            tag['qr_tag_id'],
          ],
        )
        .whereType<Object>()
        .map((value) => value.toString()),
    onChanged: _onSearchChanged,
    decoration: InputDecoration(
      hintText: 'Search QR code or ID',
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear Search',
              onPressed: () {
                _searchDebounce?.cancel();
                _searchController.clear();
                setState(() {});
                _loadTags();
              },
              icon: const Icon(Icons.close_rounded),
            ),
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: AppBorders.subtleSide,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadii.medium,
        borderSide: AppBorders.focusedSide,
      ),
    ),
  );

  Widget _mobileFilterButton() => OutlinedButton(
    onPressed: _openMobileFilters,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      foregroundColor: AppColors.darkGreen,
      backgroundColor: _activeFilterCount > 0
          ? AppColors.primaryContainer
          : AppColors.surface,
      side: BorderSide(
        color: _activeFilterCount > 0 ? AppColors.green : AppColors.border,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.tune_rounded, size: 20),
        const SizedBox(width: 7),
        const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700)),
        if (_activeFilterCount > 0) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: AppRadii.fullyRounded,
            ),
            child: Text(
              '$_activeFilterCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _activeFilterPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primaryContainer,
      borderRadius: AppRadii.fullyRounded,
      border: Border.all(color: AppColors.green.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.tune_rounded, size: 15, color: AppColors.green),
        const SizedBox(width: 5),
        Text(
          _statusFilters[_filter] ?? 'All Tags',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );

  Widget _listHeader() => LayoutBuilder(
    builder: (context, constraints) {
      final visibleCount = _visibleTags.length;
      final title = LayoutBuilder(
        builder: (context, titleConstraints) => Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadii.medium,
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: AppColors.green,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'QR Tags',
                    style: TextStyle(
                      fontSize: AppTypography.sectionTitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$visibleCount of ${_tags.length} results',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (titleConstraints.maxWidth >= 600 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.6)
              TextButton.icon(
                onPressed: _openProblemReports,
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('QR Problem Reports'),
              )
            else
              IconButton(
                onPressed: _openProblemReports,
                tooltip: 'QR Problem Reports',
                color: AppColors.green,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.report_problem_outlined),
              ),
          ],
        ),
      );
      if (!AppBreakpoints.isDesktop(constraints.maxWidth)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: AppSpacing.lg),
            _searchField(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _mobileFilterButton()),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _hasActiveFilters ? _resetFilters : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(82, 48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.medium,
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: _activeFilterPill(),
              ),
            ],
          ],
        );
      }
      return CompactFilterPanel(
        search: _searchField(),
        controls: [
          _statusDropdown(width: 190),
          TextButton.icon(
            onPressed: _openProblemReports,
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('QR Problem Reports'),
          ),
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Reset'),
            ),
        ],
        choices: [if (_activeFilterCount > 0) _activeFilterPill()],
        resultSummary: '$visibleCount of ${_tags.length} QR tags',
      );
    },
  );

  Widget _desktopTagCard(Map<String, dynamic> tag) {
    final code = tag['qr_code_string']?.toString() ?? '';
    final plantName = tag['common_name']?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        boxShadow: const [],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.qr_code_2_rounded, color: AppColors.green),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _showTagDetails(tag),
                        child: Text(code, softWrap: true),
                      ),
                      Text(
                        'ID: ${tag['qr_tag_id']}${plantName != null && plantName.isNotEmpty ? ' · $plantName' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final controls = Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusChip(QrService.statusOf(tag)),
                _tagActions(tag, code),
              ],
            );
            if (constraints.maxWidth < 850 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.md),
                  controls,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: AppSpacing.lg),
                Flexible(child: controls),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tagTile(Map<String, dynamic> tag) {
    final code = tag['qr_code_string']?.toString() ?? '';
    final status = QrService.statusOf(tag);
    final plantName = tag['common_name']?.toString().trim();
    return InkWell(
      onTap: () => _showTagDetails(tag),
      borderRadius: AppRadii.large,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.qr_code_2_rounded, color: AppColors.green),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _statusChip(status),
                          Text('ID: ${tag['qr_tag_id']}'),
                          if (plantName != null && plantName.isNotEmpty)
                            Text(plantName),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _tagActions(tag, code),
          ],
        ),
      ),
    );
  }

  Future<void> _reprintTag(Map<String, dynamic> tag, String code) async {
    final tagId = _tagId(tag);
    if (tagId == null || _updatingTags.contains(tagId)) return;
    setState(() => _updatingTags.add(tagId));
    try {
      final printed = await _printService.printSingleTag(qrCode: code);
      if (!mounted || !printed || QrService.statusOf(tag) != 'damaged') return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Is the new QR ready?'),
          content: const Text(
            'Confirm that the QR printed correctly and is attached to the plant. '
            'This will clear the damaged status and keep the same QR code.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Damaged'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm QR Ready'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _qrService.confirmReprinted(qrTagId: tagId);
      if (!mounted) return;
      _message('QR restored. Damaged status cleared.');
      await _loadTags();
    } catch (error) {
      if (mounted) {
        _message(
          userFacingError(
            error,
            fallback: 'Could not complete the QR reprint. Try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingTags.remove(tagId));
    }
  }

  void _showTagDetails(Map<String, dynamic> tag) {
    final code = tag['qr_code_string']?.toString() ?? '';
    showQrDetails(
      context,
      code: code,
      details: {
        'QR ID': '${tag['qr_tag_id']}',
        'Status':
            _statusFilters[QrService.statusOf(tag)] ?? QrService.statusOf(tag),
        if (tag['common_name'] != null) 'Plant': '${tag['common_name']}',
        if (tag['created_at'] != null) 'Created': '${tag['created_at']}',
      },
      onOpenPlant: tag['plant_id'] == null
          ? null
          : () => Navigator.push(
              context,
              plantDetailsRoute(
                builder: (_) => PlantDetailScreen(
                  plantId: (tag['plant_id'] as num).toInt(),
                  userId: widget.userId,
                  username: widget.username,
                  role: widget.role,
                ),
              ),
            ),
    );
  }

  Widget _tagActions(Map<String, dynamic> tag, String code) {
    final tagId = _tagId(tag);
    return QrTagActions(
      status: QrService.statusOf(tag),
      busy: tagId != null && _updatingTags.contains(tagId),
      onPrint: code.isEmpty ? null : () => _reprintTag(tag, code),
      onMarkDamaged: () => _markDamaged(tag),
      onRetire: () => _retireTag(tag),
    );
  }

  Widget _statusChip(String status) {
    final value = status.toLowerCase();
    final assigned = value == 'assigned';
    final warning = value == 'damaged';
    final replaced = value == 'replaced';
    final foreground = value == 'available'
        ? AppColors.green
        : assigned
        ? AppColors.info
        : warning
        ? AppColors.warning
        : replaced
        ? AppColors.accentPurple
        : AppColors.textSecondary;
    final background = value == 'available'
        ? AppColors.primaryContainer
        : assigned
        ? AppColors.infoContainer
        : warning
        ? AppColors.warningContainer
        : replaced
        ? AppColors.accentPurpleContainer
        : AppColors.surfaceDisabled;
    final label = status.isEmpty
        ? 'Unknown'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.fullyRounded,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppColors.danger : AppColors.green,
        ),
      );
  }
}
