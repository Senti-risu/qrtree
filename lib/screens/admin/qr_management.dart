import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import '../../models/app_role.dart';
import '../../services/qr_print_service.dart';
import '../../services/qr_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_filter_sheet.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/qr_mobile_tag_list.dart';
import '../../widgets/full_width_data_table.dart';
import '../../widgets/qr_tag_actions.dart';
import '../qr/qr_problem_reports_screen.dart';

class QrManagementScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  const QrManagementScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  @override
  State<QrManagementScreen> createState() => _QrManagementScreenState();
}

class _QrManagementScreenState extends State<QrManagementScreen> {
  static const int _pageSize = 100;
  final QrService _qrService = QrService();
  final QrPrintService _printService = QrPrintService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _tags = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _generating = false;
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
    'all': 'All statuses',
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
          title: 'Filter QR tags',
          applyLabel: 'Apply filters',
          onReset: () => setSheetState(() => draftFilter = 'all'),
          onApply: () => Navigator.pop(sheetContext, draftFilter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tag status'),
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

  Future<void> _printAvailable() async {
    final available = _tags
        .where((tag) => QrService.statusOf(tag) == 'available')
        .toList();
    if (available.isEmpty) {
      _message('No available QR tags are currently shown.');
      return;
    }
    await _printService.printBatch(available);
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
      title: 'Mark label as damaged?',
      message:
          'The plant will keep its current record, but this label should no longer be scanned. You can replace it next.',
      actionLabel: 'Mark damaged',
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _runTagAction(
      tagId,
      action: () => _qrService.markDamaged(qrTagId: tagId, reason: reason),
      success: 'QR label marked as damaged.',
    );
  }

  Future<void> _retireTag(Map<String, dynamic> tag) async {
    final tagId = _tagId(tag);
    if (tagId == null) return;
    final reason = await _askReason(
      title: 'Retire this unused label?',
      message:
          'A retired label cannot be assigned to a plant. Its history will remain available for administrators.',
      actionLabel: 'Retire label',
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _runTagAction(
      tagId,
      action: () => _qrService.retireTag(qrTagId: tagId, reason: reason),
      success: 'QR label retired.',
    );
  }

  Future<void> _replaceTag(Map<String, dynamic> tag) async {
    final oldTagId = _tagId(tag);
    if (oldTagId == null) return;
    final reason = await _askReason(
      title: 'Replace damaged label',
      message:
          'Choose an available label for the same plant. The old label will remain in history as replaced.',
      actionLabel: 'Choose replacement',
    );
    if (reason == null || !mounted) return;

    setState(() => _updatingTags.add(oldTagId));
    try {
      var available = await _qrService.getTags(status: 'available');
      if (!mounted) return;
      if (available.isEmpty) {
        final generate = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('No available labels'),
            content: const Text(
              'Generate one new QR label now and use it as the replacement?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Generate label'),
              ),
            ],
          ),
        );
        if (generate != true || !mounted) return;
        available = [await _qrService.createQrTag()];
      }
      if (!mounted) return;
      final replacement = await _chooseReplacement(available);
      if (replacement == null || !mounted) return;
      final replacementId = _tagId(replacement);
      if (replacementId == null) return;

      await _qrService.replaceTag(
        oldQrTagId: oldTagId,
        replacementQrTagId: replacementId,
        reason: reason,
      );
      if (!mounted) return;
      await _loadTags();
      if (!mounted) return;
      final printNow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Label replaced'),
          content: Text(
            'The plant now uses ${replacement['qr_code_string']}. Print the new label now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print label'),
            ),
          ],
        ),
      );
      if (printNow == true && mounted) {
        await _printService.printSingleTag(
          qrCode: replacement['qr_code_string']?.toString() ?? '',
        );
      }
    } catch (error) {
      if (mounted) {
        _message(
          userFacingError(
            error,
            fallback: 'The damaged label could not be replaced. Try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingTags.remove(oldTagId));
    }
  }

  Future<Map<String, dynamic>?> _chooseReplacement(
    List<Map<String, dynamic>> available,
  ) async {
    var selectedId = _tagId(available.first);
    final chosenId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Choose available label'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: DropdownButtonFormField<int>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Replacement QR label',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
                border: OutlineInputBorder(),
              ),
              items: available.map((candidate) {
                final id = _tagId(candidate)!;
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    candidate['qr_code_string']?.toString() ?? 'QR #$id',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) => setDialogState(() => selectedId = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedId),
              child: const Text('Use this label'),
            ),
          ],
        ),
      ),
    );
    if (chosenId == null) return null;
    return available.firstWhere((candidate) => _tagId(candidate) == chosenId);
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
          fallback: 'The QR label could not be updated. Please try again.',
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
    final useHeaderActions = isDesktop;
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop) ...[
                  AppPageHeader(
                    title: 'QR Management',
                    subtitle:
                        'Generate, print, scan, and monitor EcoTag QR codes',
                    trailing: useHeaderActions ? _headerActions() : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (!useHeaderActions) ...[
                  _toolbar(),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Expanded(child: _tagList()),
              ],
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
                const Text(
                  'Enter how many new QR tags you want to generate.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.green,
                          size: 20,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Format: ECOTAG-YYYYMM-000001. YYYYMM is the creation month and year; the last number starts at 1 and continues globally without resetting.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkGreen,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of QR Tags',
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
              onPressed: _tags.isEmpty ? null : _printAvailable,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print available'),
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
        onPressed: _tags.isEmpty ? null : _printAvailable,
        icon: const Icon(Icons.print_outlined),
        label: const Text('Print'),
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
      return AppCard(
        child: Column(
          children: [
            _listHeader(),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.green),
              ),
            ),
          ],
        ),
      );
    }
    if (_tags.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            _listHeader(),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 46,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text('No QR tags found.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _listHeader(),
          const SizedBox(height: AppSpacing.md),
          if (_visibleTags.isEmpty)
            const Expanded(
              child: Center(child: Text('No QR tags match your search.')),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  if (AppBreakpoints.isPhone(constraints.maxWidth)) {
                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _visibleTags.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) => _tagTile(_visibleTags[index]),
                    );
                  }
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _tagTable(),
                  );
                },
              ),
            ),
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
                label: Text(_loadingMore ? 'Loading…' : 'Load more QR tags'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField() => TextField(
    controller: _searchController,
    onChanged: _onSearchChanged,
    decoration: InputDecoration(
      hintText: 'Search QR code or ID',
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
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
          _statusFilters[_filter] ?? 'All tags',
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
                    'QR tags',
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
                label: const Text('QR problem reports'),
              )
            else
              IconButton(
                onPressed: _openProblemReports,
                tooltip: 'QR problem reports',
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
      return Row(
        children: [
          Expanded(child: title),
          SizedBox(width: 300, child: _searchField()),
          const SizedBox(width: 10),
          _statusDropdown(width: 190),
          if (_activeFilterCount > 0) ...[
            const SizedBox(width: 8),
            _activeFilterPill(),
          ],
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _hasActiveFilters ? _resetFilters : null,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Reset'),
          ),
        ],
      );
    },
  );

  Widget _tagTable() => FullWidthDataTable(
    columns: const [
      DataColumn(label: Text('QR CODE'), columnWidth: FlexColumnWidth(4)),
      DataColumn(label: Text('ID'), columnWidth: FlexColumnWidth(1.2)),
      DataColumn(label: Text('STATUS'), columnWidth: FlexColumnWidth(1.6)),
      DataColumn(label: Text('ACTIONS'), columnWidth: FlexColumnWidth(3.2)),
    ],
    rows: _visibleTags.map((tag) {
      final code = tag['qr_code_string']?.toString() ?? '';
      final status = QrService.statusOf(tag);
      return DataRow(
        cells: [
          DataCell(
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.qr_code_2_rounded, color: AppColors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          DataCell(Text('${tag['qr_tag_id']}')),
          DataCell(_statusChip(status)),
          DataCell(_tagActions(tag, code)),
        ],
      );
    }).toList(),
  );

  Widget _tagTile(Map<String, dynamic> tag) {
    final code = tag['qr_code_string']?.toString() ?? '';
    final status = QrService.statusOf(tag);
    final plantName = tag['common_name']?.toString().trim();
    return Padding(
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
    );
  }

  Widget _tagActions(Map<String, dynamic> tag, String code) {
    final tagId = _tagId(tag);
    return QrTagActions(
      status: QrService.statusOf(tag),
      busy: tagId != null && _updatingTags.contains(tagId),
      onPrint: code.isEmpty
          ? null
          : () => _printService.printSingleTag(qrCode: code),
      onMarkDamaged: () => _markDamaged(tag),
      onReplace: () => _replaceTag(tag),
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
