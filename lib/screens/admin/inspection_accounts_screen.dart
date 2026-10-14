import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import '../../services/inspection_account_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';

class InspectionAccountsScreen extends StatefulWidget {
  const InspectionAccountsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    required this.campusId,
    required this.collegeId,
  });

  final int userId;
  final String username;
  final String role;
  final int campusId;
  final int collegeId;

  @override
  State<InspectionAccountsScreen> createState() =>
      _InspectionAccountsScreenState();
}

class _InspectionAccountsScreenState extends State<InspectionAccountsScreen> {
  final _service = InspectionAccountService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _accounts = const [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleAccounts {
    final term = _searchController.text.trim().toLowerCase();
    return _accounts.where((account) {
      final username = account['username']?.toString().toLowerCase() ?? '';
      final active = account['is_active'] as bool? ?? true;
      if (term.isNotEmpty && !username.contains(term)) return false;
      if (_statusFilter == 'active' && !active) return false;
      if (_statusFilter == 'inactive' && active) return false;
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty || _statusFilter != 'all';

  int get _appliedFilterCount => _statusFilter == 'all' ? 0 : 1;

  String get _statusFilterLabel => switch (_statusFilter) {
    'active' => 'Active',
    'inactive' => 'Inactive',
    _ => 'All statuses',
  };

  void _resetFilters() {
    _searchController.clear();
    setState(() => _statusFilter = 'all');
  }

  int _statusCount(String status) {
    final term = _searchController.text.trim().toLowerCase();
    final searchMatches = _accounts.where((account) {
      final username = account['username']?.toString().toLowerCase() ?? '';
      return term.isEmpty || username.contains(term);
    });
    if (status == 'all') return searchMatches.length;
    return searchMatches.where((account) {
      final active = account['is_active'] as bool? ?? true;
      return status == 'active' ? active : !active;
    }).length;
  }

  Future<void> _showMobileFilters() async {
    var pendingStatus = _statusFilter;
    final selection = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget option(String value, String label) => ChoiceChip(
            label: Text('$label (${_statusCount(value)})'),
            selected: pendingStatus == value,
            showCheckmark: false,
            onSelected: (_) => setSheetState(() => pendingStatus = value),
            selectedColor: AppColors.primaryContainer,
            backgroundColor: AppColors.background,
            side: BorderSide(
              color: pendingStatus == value
                  ? AppColors.green
                  : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            labelStyle: TextStyle(
              color: pendingStatus == value
                  ? AppColors.darkGreen
                  : AppColors.textPrimary,
              fontWeight: pendingStatus == value
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          );

          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
              ),
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: AppColors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter inspection accounts',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Choose an account status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close filters',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'ACCOUNT STATUS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          option('all', 'All'),
                          option('active', 'Active'),
                          option('inactive', 'Inactive'),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setSheetState(() => pendingStatus = 'all'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                side: const BorderSide(color: AppColors.green),
                              ),
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, pendingStatus),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppColors.green,
                              ),
                              child: const Text('Apply filter'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _statusFilter = selection);
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await _service.listAccounts(widget.userId);
      if (mounted) setState(() => _accounts = accounts);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateInspectionAccountDialog(
        actorUserId: widget.userId,
        service: _service,
      ),
    );
    if (created == true) {
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection Team account created.')),
        );
      }
    }
  }

  Future<void> _setActive(Map<String, dynamic> account, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate account?'),
          content: Text(
            '${account['username']} will no longer be able to sign in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await _service.setActive(
        actorUserId: widget.userId,
        targetUserId: account['user_id'] as int,
        isActive: active,
      );
      await _loadAccounts();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _edit(Map<String, dynamic> account) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateInspectionAccountDialog(
        actorUserId: widget.userId,
        service: _service,
        account: account,
      ),
    );
    if (updated == true) {
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection Team account updated.')),
        );
      }
    }
  }

  Future<void> _archive(Map<String, dynamic> account) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Archive account?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${account['username']} will no longer be able to sign in. Its inspection history is preserved and the account can be restored later.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Why is this account being archived?',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Enter at least 3 characters.'
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, reasonController.text.trim());
            },
            child: const Text('Archive Account'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;
    try {
      await _service.archiveAccount(
        targetUserId: account['user_id'] as int,
        reason: reason,
      );
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection Team account archived.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                error,
                fallback: 'The account could not be archived. Try again.',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showArchivedAccounts() async {
    List<Map<String, dynamic>> archived;
    try {
      archived = await _service.listArchivedAccounts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'Archived accounts could not be loaded. Try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    final restoringIds = <int>{};

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: .82,
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.archive_outlined,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Archived inspection accounts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Restored accounts remain inactive until you activate them.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: archived.isEmpty
                      ? const Center(child: Text('No archived accounts'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: archived.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final account = archived[index];
                            final username =
                                account['username']?.toString() ?? 'Account';
                            final userId = account['user_id'] is int
                                ? account['user_id'] as int
                                : int.tryParse(
                                    account['user_id']?.toString() ?? '',
                                  );
                            final restoring =
                                userId != null && restoringIds.contains(userId);
                            final reason = account['archive_reason']
                                ?.toString()
                                .trim();
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 5,
                              ),
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.surfaceDisabled,
                                child: Icon(Icons.person_off_outlined),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                reason == null || reason.isEmpty
                                    ? 'Inspection Team'
                                    : 'Inspection Team • $reason',
                              ),
                              trailing: OutlinedButton.icon(
                                onPressed: userId == null || restoring
                                    ? null
                                    : () async {
                                        setSheetState(
                                          () => restoringIds.add(userId),
                                        );
                                        try {
                                          await _service.restoreAccount(userId);
                                          if (!sheetContext.mounted) return;
                                          archived.removeAt(index);
                                          setSheetState(() {});
                                          await _loadAccounts();
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            this.context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Account restored as inactive.',
                                              ),
                                            ),
                                          );
                                        } catch (error) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            this.context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                userFacingError(
                                                  error,
                                                  fallback:
                                                      'The account could not be restored.',
                                                ),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        } finally {
                                          if (sheetContext.mounted) {
                                            setSheetState(
                                              () => restoringIds.remove(userId),
                                            );
                                          }
                                        }
                                      },
                                icon: restoring
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.unarchive_outlined),
                                label: Text(
                                  restoring ? 'Restoring…' : 'Restore',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(Map<String, dynamic> account) => PopupMenuButton<String>(
    tooltip: 'Account actions',
    onSelected: (value) {
      if (value == 'edit') _edit(account);
      if (value == 'archive') _archive(account);
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('Edit'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'archive',
        child: ListTile(
          leading: Icon(Icons.archive_outlined, color: Colors.red),
          title: Text('Archive', style: TextStyle(color: Colors.red)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return AppShell(
      activeRoute: '/inspection-accounts',
      mobileTitle: 'Inspection Accounts',
      mobileSubtitle:
          '${_visibleAccounts.length} of ${_accounts.length} accounts',
      userId: widget.userId,
      username: widget.username,
      role: widget.role,
      campusId: widget.campusId,
      collegeId: widget.collegeId,
      userName: widget.username,
      userRole: AppRole.collegeAdmin.label,
      showQrButton: false,
      onRefresh: _loadAccounts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) ...[
            AppPageHeader(
              title: 'Inspection Team Accounts',
              subtitle:
                  'Create, archive, and restore inspection accounts for your college.',
              trailing: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showArchivedAccounts,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archived'),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Create Account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (!isDesktop) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showArchivedAccounts,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archived'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openCreateDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Create'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) =>
                  _accountsCard(!AppBreakpoints.isPhone(constraints.maxWidth)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountsCard(bool isDesktop) {
    final visibleAccounts = _visibleAccounts;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inspection Team',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Accounts assigned to your college',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (!_loading && _error == null && _accounts.isNotEmpty) ...[
            _filterBar(),
            const SizedBox(height: 14),
          ],
          Expanded(child: _accountResults(visibleAccounts, isDesktop)),
        ],
      ),
    );
  }

  Widget _accountResults(
    List<Map<String, dynamic>> visibleAccounts,
    bool useTable,
  ) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _loadAccounts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_accounts.isEmpty) {
      return const Center(child: Text('No Inspection Team accounts yet.'));
    }
    if (visibleAccounts.isEmpty) return _noMatchingAccounts();
    if (useTable) {
      return SingleChildScrollView(child: _desktopTable(visibleAccounts));
    }
    return ListView.separated(
      itemCount: visibleAccounts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) => _accountTile(visibleAccounts[index]),
    );
  }

  Widget _filterBar() => LayoutBuilder(
    builder: (_, constraints) {
      final isMobile = !AppBreakpoints.isDesktop(constraints.maxWidth);
      final search = TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: isMobile ? 'Search accounts…' : 'Search by username…',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: AppColors.surfaceSubtle,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.green, width: 1.5),
          ),
        ),
      );

      final summary = Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${_visibleAccounts.length} of ${_accounts.length} accounts',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.restart_alt_rounded, size: 17),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.green,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      );

      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _showMobileFilters,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(104, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    foregroundColor: AppColors.darkGreen,
                    backgroundColor: _appliedFilterCount > 0
                        ? AppColors.primaryContainer
                        : AppColors.surface,
                    side: BorderSide(
                      color: _appliedFilterCount > 0
                          ? AppColors.green
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Filter'),
                      if (_appliedFilterCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_appliedFilterCount',
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
                ),
              ],
            ),
            if (_statusFilter != 'all') ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(Icons.toggle_on_outlined, size: 18),
                  label: Text(_statusFilterLabel),
                  onDeleted: () => setState(() => _statusFilter = 'all'),
                  deleteIconColor: AppColors.green,
                  backgroundColor: AppColors.primaryContainer,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
            const SizedBox(height: 8),
            summary,
          ],
        );
      }

      return Column(
        children: [
          Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 14),
              _statusChoice('all', 'All'),
              const SizedBox(width: 8),
              _statusChoice('active', 'Active'),
              const SizedBox(width: 8),
              _statusChoice('inactive', 'Inactive'),
              if (_appliedFilterCount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    '1 active',
                    style: TextStyle(
                      color: AppColors.darkGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          summary,
        ],
      );
    },
  );

  Widget _statusChoice(String value, String label) => ChoiceChip(
    label: Text('$label (${_statusCount(value)})'),
    selected: _statusFilter == value,
    showCheckmark: false,
    onSelected: (_) => setState(() => _statusFilter = value),
    selectedColor: AppColors.primaryContainer,
    backgroundColor: AppColors.surfaceSubtle,
    side: BorderSide(
      color: _statusFilter == value ? AppColors.green : AppColors.border,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    labelStyle: TextStyle(
      color: _statusFilter == value
          ? AppColors.darkGreen
          : AppColors.textSecondary,
      fontWeight: FontWeight.w700,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  );

  Widget _noMatchingAccounts() => SizedBox(
    height: 220,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.manage_search_rounded,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          const Text(
            'No accounts match your filters',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Try another username or account status.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Reset filters'),
          ),
        ],
      ),
    ),
  );

  Widget _desktopTable(List<Map<String, dynamic>> accounts) => LayoutBuilder(
    builder: (_, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(AppColors.background),
          columns: const [
            DataColumn(label: Text('ACCOUNT')),
            DataColumn(label: Text('ROLE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACCESS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: accounts.map((account) {
            final username = account['username']?.toString() ?? '';
            final active = account['is_active'] as bool? ?? true;
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          username.isEmpty ? '?' : username[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.darkGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const DataCell(Text('Inspection Team')),
                DataCell(_statusChip(active)),
                DataCell(
                  Switch(
                    value: active,
                    onChanged: (value) => _setActive(account, value),
                  ),
                ),
                DataCell(_actions(account)),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  );

  Widget _statusChip(bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? AppColors.primaryContainer : AppColors.dangerContainer,
      borderRadius: AppRadii.fullyRounded,
    ),
    child: Text(
      active ? 'Active' : 'Inactive',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: active ? AppColors.green : AppColors.danger,
      ),
    ),
  );

  Widget _accountTile(Map<String, dynamic> account) {
    final username = account['username']?.toString() ?? '';
    final active = account['is_active'] as bool? ?? true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryContainer,
        child: Text(
          username.isEmpty ? '?' : username[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        username,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Inspection Team • ${active ? 'Active' : 'Inactive'}'),
      trailing: _actions(account),
    );
  }
}

class _CreateInspectionAccountDialog extends StatefulWidget {
  const _CreateInspectionAccountDialog({
    required this.actorUserId,
    required this.service,
    this.account,
  });

  final int actorUserId;
  final InspectionAccountService service;
  final Map<String, dynamic>? account;

  @override
  State<_CreateInspectionAccountDialog> createState() =>
      _CreateInspectionAccountDialogState();
}

class _CreateInspectionAccountDialogState
    extends State<_CreateInspectionAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.account?['username']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.service.updateAccount(
          targetUserId: widget.account!['user_id'] as int,
          username: _usernameController.text,
          newPassword: _passwordController.text,
        );
      } else {
        await widget.service.createAccount(
          actorUserId: widget.actorUserId,
          username: _usernameController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppBreakpoints.isPhone(MediaQuery.sizeOf(context).width);
    return AlertDialog(
      scrollable: true,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 40,
        vertical: 24,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        compact ? 20 : 24,
        16,
        compact ? 20 : 24,
        8,
      ),
      title: Text(
        _editing ? 'Edit Inspection Account' : 'Create Inspection Account',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _editing
                      ? 'Update the username or enter a new password. Leave the password blank to keep it unchanged.'
                      : 'This account will be assigned automatically to your campus and college.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    RegExp(
                      r'^[A-Za-z0-9._-]{3,40}$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Use 3–40 letters, numbers, dots, dashes, or underscores.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: _editing
                      ? 'New password (optional)'
                      : 'Temporary password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  final length = value?.length ?? 0;
                  if (_editing && length == 0) return null;
                  return length >= 8 ? null : 'Use at least 8 characters.';
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _editing
                      ? Icons.save_outlined
                      : Icons.person_add_alt_1_rounded,
                ),
          label: Text(
            _saving
                ? 'Saving…'
                : _editing
                ? 'Save Changes'
                : 'Create Account',
          ),
        ),
      ],
    );
  }
}
