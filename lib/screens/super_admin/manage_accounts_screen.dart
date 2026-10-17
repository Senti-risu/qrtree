import 'package:flutter/material.dart';
import '../../widgets/app_workspace_page.dart';
import '../../theme/app_typography.dart';
import '../../models/admin_account.dart';
import '../../models/app_role.dart';
import '../../services/super_admin_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/account_access_controls.dart';
import 'create_account_screen.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
  });
  final int userId;
  final String username;
  final String role;
  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final _service = SuperAdminService();
  final _searchController = TextEditingController();
  List<AdminAccount> _accounts = const [];
  bool _loading = true;
  String? _error;
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  final Set<int> _busyAccountIds = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminAccount> get _visibleAccounts {
    final term = _searchController.text.trim().toLowerCase();
    return _accounts.where((account) {
      if (term.isNotEmpty &&
          !'${account.username} ${account.roleLabel} ${account.scopeLabel}'
              .toLowerCase()
              .contains(term)) {
        return false;
      }
      if (_roleFilter != 'all' && account.role != _roleFilter) {
        return false;
      }
      if (_statusFilter == 'active' && !account.isActive) return false;
      if (_statusFilter == 'inactive' && account.isActive) return false;
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _roleFilter != 'all' ||
      _statusFilter != 'all';

  int get _appliedFilterCount =>
      (_roleFilter == 'all' ? 0 : 1) + (_statusFilter == 'all' ? 0 : 1);

  String get _roleFilterLabel => switch (_roleFilter) {
    'university_admin' => 'University Admin',
    'campus_admin' => 'Campus Admin',
    'college_admin' => 'College Admin',
    _ => 'All roles',
  };

  String get _statusFilterLabel => switch (_statusFilter) {
    'active' => 'Active',
    'inactive' => 'Inactive',
    _ => 'All statuses',
  };

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _roleFilter = 'all';
      _statusFilter = 'all';
    });
  }

  Future<void> _showMobileFilters() async {
    var pendingRole = _roleFilter;
    var pendingStatus = _statusFilter;
    final selection = await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget option({
            required String label,
            required bool selected,
            required VoidCallback onTap,
          }) => ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onTap(),
            selectedColor: AppColors.primaryContainer,
            backgroundColor: AppColors.background,
            side: BorderSide(
              color: selected ? AppColors.green : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            labelStyle: TextStyle(
              color: selected ? AppColors.darkGreen : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                                  'Filter accounts',
                                  style: TextStyle(
                                    fontSize: AppTypography.sectionTitle,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Narrow results by role and status',
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
                        'ROLE',
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
                          option(
                            label: 'All roles',
                            selected: pendingRole == 'all',
                            onTap: () =>
                                setSheetState(() => pendingRole = 'all'),
                          ),
                          option(
                            label: 'University Admin',
                            selected: pendingRole == 'university_admin',
                            onTap: () => setSheetState(
                              () => pendingRole = 'university_admin',
                            ),
                          ),
                          option(
                            label: 'Campus Admin',
                            selected: pendingRole == 'campus_admin',
                            onTap: () => setSheetState(
                              () => pendingRole = 'campus_admin',
                            ),
                          ),
                          option(
                            label: 'College Admin',
                            selected: pendingRole == 'college_admin',
                            onTap: () => setSheetState(
                              () => pendingRole = 'college_admin',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
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
                          option(
                            label: 'All statuses',
                            selected: pendingStatus == 'all',
                            onTap: () =>
                                setSheetState(() => pendingStatus = 'all'),
                          ),
                          option(
                            label: 'Active',
                            selected: pendingStatus == 'active',
                            onTap: () =>
                                setSheetState(() => pendingStatus = 'active'),
                          ),
                          option(
                            label: 'Inactive',
                            selected: pendingStatus == 'inactive',
                            onTap: () =>
                                setSheetState(() => pendingStatus = 'inactive'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setSheetState(() {
                                pendingRole = 'all';
                                pendingStatus = 'all';
                              }),
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
                              onPressed: () => Navigator.pop(sheetContext, [
                                pendingRole,
                                pendingStatus,
                              ]),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppColors.green,
                              ),
                              child: const Text('Apply filters'),
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
    setState(() {
      _roleFilter = selection[0];
      _statusFilter = selection[1];
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _service.getAccounts(widget.userId);
      if (mounted) setState(() => _accounts = value);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateAdminAccountDialog(actorUserId: widget.userId),
    );
    if (created == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Admin account created.')));
      }
    }
  }

  Future<void> _setActive(AdminAccount account, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate account?'),
          content: Text(
            '${account.username} will no longer be able to sign in.',
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
      await _service.setAccountActive(
        actorUserId: widget.userId,
        targetUserId: account.userId,
        isActive: active,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _edit(AdminAccount account) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          EditAdminAccountDialog(actorUserId: widget.userId, account: account),
    );
    if (updated == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account updated.')));
      }
    }
  }

  Future<void> _archive(AdminAccount account) async {
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
                '${account.username} will no longer be able to sign in. The account and its history can be restored later.',
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
        targetUserId: account.userId,
        reason: reason,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account archived.')));
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
    List<AdminAccount> archived;
    try {
      archived = await _service.getArchivedAccounts();
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
                              'Archived accounts',
                              style: TextStyle(
                                fontSize: AppTypography.sectionTitle,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Restore an account, then activate it when ready.',
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
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 50,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 10),
                              Text('No archived accounts'),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: archived.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final account = archived[index];
                            final restoring = restoringIds.contains(
                              account.userId,
                            );
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
                                account.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  account.roleLabel,
                                  account.scopeLabel,
                                  if (account.archiveReason
                                          ?.trim()
                                          .isNotEmpty ==
                                      true)
                                    account.archiveReason!.trim(),
                                ].join(' • '),
                              ),
                              trailing: OutlinedButton.icon(
                                onPressed: restoring
                                    ? null
                                    : () async {
                                        setSheetState(
                                          () =>
                                              restoringIds.add(account.userId),
                                        );
                                        try {
                                          await _service.restoreAccount(
                                            account.userId,
                                          );
                                          if (!sheetContext.mounted) return;
                                          archived.removeAt(index);
                                          setSheetState(() {});
                                          await _load();
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            this.context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Account restored as inactive. Activate it when ready.',
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
                                              () => restoringIds.remove(
                                                account.userId,
                                              ),
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

  Future<void> _runAccountAction(
    AdminAccount account,
    Future<void> Function() action,
  ) async {
    if (_busyAccountIds.contains(account.userId)) return;
    setState(() => _busyAccountIds.add(account.userId));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyAccountIds.remove(account.userId));
    }
  }

  Widget _actions(AdminAccount account) => AccountRowActions(
    busy: _busyAccountIds.contains(account.userId),
    onEdit: () => _runAccountAction(account, () => _edit(account)),
    onArchive: () => _runAccountAction(account, () => _archive(account)),
  );

  Widget _statusButton(AdminAccount account) => AccountStatusButton(
    active: account.isActive,
    busy: _busyAccountIds.contains(account.userId),
    onPressed: () => _runAccountAction(
      account,
      () => _setActive(account, !account.isActive),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return AppShell(
      activeRoute: '/manage-accounts',
      mobileTitle: 'Manage Accounts',
      mobileSubtitle:
          '${_visibleAccounts.length} of ${_accounts.length} accounts',
      userId: widget.userId,
      username: widget.username,
      role: widget.role,
      userRole: AppRole.superAdmin.label,
      child: AppWorkspacePage(
        header: isDesktop
            ? AppPageHeader(
                title: 'Manage Accounts',
                subtitle:
                    'View, activate, archive, and restore administrator accounts.',
                trailing: _pageActions(),
              )
            : _pageActions(),
        tools: _filterBar(),
        body: LayoutBuilder(
          builder: (_, constraints) {
            final table = !AppBreakpoints.isPhone(constraints.maxWidth);
            if (!_loading && _error == null && _accounts.isEmpty) {
              return AppEmptyState(
                title: 'No administrator accounts yet',
                message: 'Create an account to get started.',
                icon: Icons.people_outline,
                action: FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Create Account'),
                ),
              );
            }
            if (!_loading && _error == null && _visibleAccounts.isEmpty) {
              return AppEmptyState(
                title: 'No accounts match your filters',
                message: 'Try another search or reset your filters.',
                action: TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset filters'),
                ),
              );
            }
            if (table &&
                !_loading &&
                _error == null &&
                _visibleAccounts.isNotEmpty) {
              return AppTablePanel(child: _desktopTable(_visibleAccounts));
            }
            return AppCard(
              padding: const EdgeInsets.all(16),
              child: _body(table),
            );
          },
        ),
      ),
    );
  }

  Widget _pageActions() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: _showArchivedAccounts,
        icon: const Icon(Icons.archive_outlined),
        label: const Text('Archived'),
      ),
      FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Create Account'),
      ),
    ],
  );

  Widget _filterBar() => AppToolbarCard(
    child: LayoutBuilder(
      builder: (_, constraints) {
        final isMobile =
            !AppBreakpoints.isDesktop(constraints.maxWidth) ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4;
        final search = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: isMobile
                ? 'Search accounts…'
                : 'Search username, role, or assignment…',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.green,
            ),
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
              if (_appliedFilterCount > 0) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_roleFilter != 'all')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            avatar: const Icon(Icons.badge_outlined, size: 17),
                            label: Text(_roleFilterLabel),
                            onDeleted: () =>
                                setState(() => _roleFilter = 'all'),
                            deleteIconColor: AppColors.green,
                            backgroundColor: AppColors.primaryContainer,
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      if (_statusFilter != 'all')
                        InputChip(
                          avatar: const Icon(
                            Icons.toggle_on_outlined,
                            size: 18,
                          ),
                          label: Text(_statusFilterLabel),
                          onDeleted: () =>
                              setState(() => _statusFilter = 'all'),
                          deleteIconColor: AppColors.green,
                          backgroundColor: AppColors.primaryContainer,
                          side: const BorderSide(color: AppColors.border),
                        ),
                    ],
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
                const SizedBox(width: 10),
                _roleDropdown(),
                const SizedBox(width: 10),
                _statusDropdown(),
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
                    child: Text(
                      '$_appliedFilterCount active',
                      style: const TextStyle(
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
    ),
  );

  InputDecoration _dropdownDecoration(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, size: 20),
    isDense: true,
    filled: true,
    fillColor: AppColors.surfaceSubtle,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );

  Widget _roleDropdown({double? width = 200}) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('role-$_roleFilter'),
      initialValue: _roleFilter,
      isExpanded: true,
      decoration: _dropdownDecoration(Icons.badge_outlined),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All roles')),
        DropdownMenuItem(
          value: 'university_admin',
          child: Text('University Admin'),
        ),
        DropdownMenuItem(value: 'campus_admin', child: Text('Campus Admin')),
        DropdownMenuItem(value: 'college_admin', child: Text('College Admin')),
      ],
      onChanged: (value) {
        if (value != null && value != _roleFilter) {
          setState(() => _roleFilter = value);
        }
      },
    ),
  );

  Widget _statusDropdown({double? width = 170}) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('status-$_statusFilter'),
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: _dropdownDecoration(Icons.toggle_on_outlined),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All statuses')),
        DropdownMenuItem(value: 'active', child: Text('Active')),
        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
      ],
      onChanged: (value) {
        if (value != null && value != _statusFilter) {
          setState(() => _statusFilter = value);
        }
      },
    ),
  );

  Widget _body(bool useTable) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 42),
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_accounts.isEmpty) {
      return const Center(child: Text('No administrator accounts yet.'));
    }
    final accounts = _visibleAccounts;
    if (accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.manage_search_rounded,
              size: 42,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'No accounts match these filters.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Reset filters'),
            ),
          ],
        ),
      );
    }
    if (useTable) {
      return SingleChildScrollView(child: _desktopTable(accounts));
    }
    return ListView.separated(
      itemCount: accounts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final account = accounts[index];
        return AccountAccessTile(
          username: account.username,
          subtitle: '${account.roleLabel} · ${account.scopeLabel}',
          statusButton: _statusButton(account),
          actions: _actions(account),
        );
      },
    );
  }

  Widget _desktopTable(List<AdminAccount> accounts) => LayoutBuilder(
    builder: (_, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          dataRowMinHeight: 56,
          dataRowMaxHeight: double.infinity,
          headingRowColor: const WidgetStatePropertyAll(AppColors.background),
          columns: const [
            DataColumn(label: Text('ACCOUNT')),
            DataColumn(label: Text('ROLE')),
            DataColumn(label: Text('ASSIGNMENT')),
            DataColumn(label: Text('STATUS / ACCESS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: accounts
              .map(
                (account) => DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              account.username.isEmpty
                                  ? '?'
                                  : account.username[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.darkGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            account.username,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(account.roleLabel)),
                    DataCell(Text(account.scopeLabel)),
                    DataCell(_statusButton(account)),
                    DataCell(_actions(account)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
}
