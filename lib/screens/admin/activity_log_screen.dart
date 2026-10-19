import 'package:flutter/material.dart';
import '../../widgets/app_workspace_page.dart';
import '../../theme/app_typography.dart';

import '../../models/app_role.dart';
import '../../services/activity_log_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';

class ActivityLogScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;

  const ActivityLogScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
  });

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _pageSize = 50;
  final _service = ActivityLogService();

  List<Map<String, dynamic>> _events = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  String _action = 'all';
  String _entity = 'all';
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || !_hasMore)) return;
    final requestVersion = ++_requestVersion;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        _error = null;
      }
    });

    try {
      final rows = await _service.list(
        action: _action == 'all' ? null : _action,
        entityType: _entity == 'all' ? null : _entity,
        limit: _pageSize,
        offset: more ? _events.length : 0,
      );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _events = more ? [..._events, ...rows] : rows;
        _hasMore = rows.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = technicalErrorDetails(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AppBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);
    return AppShell(
      activeRoute: '/activity-log',
      mobileTitle: 'Activity Log',
      mobileSubtitle: 'Recent account and plant changes',
      userId: widget.userId,
      username: widget.username,
      role: widget.role,
      campusId: widget.campusId,
      collegeId: widget.collegeId,
      userName: widget.username,
      userRole: _roleLabel(widget.role),
      child: AppWorkspacePage(
        header: desktop
            ? const AppPageHeader(
                title: 'Activity Log',
                subtitle: 'Review important changes made in EcoTag',
              )
            : null,
        tools: _filters(),
        body: _content(),
      ),
    );
  }

  Widget _filters() => AppToolbarCard(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final action = _dropdown(
          label: 'Action',
          value: _action,
          options: const {
            'all': 'All Actions',
            'plant.dead_record_reopened': 'Reopened dead records',
            'create': 'Created',
            'update': 'Updated',
            'archive': 'Archived',
            'restore': 'Restored',
            'inspect': 'Inspections',
            'replace': 'QR Replacements',
            'login': 'Sign-ins',
            'logout': 'Sign-outs',
          },
          onChanged: (value) {
            setState(() => _action = value);
            _load();
          },
        );
        final entity = _dropdown(
          label: 'Record Type',
          value: _entity,
          options: const {
            'all': 'All Records',
            'user': 'Accounts',
            'plant': 'Plants',
            'qr_tag': 'QR Tags',
          },
          onChanged: (value) {
            setState(() => _entity = value);
            _load();
          },
        );

        if (constraints.maxWidth < 720 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filter Activity',
                style: TextStyle(
                  fontSize: AppTypography.sectionTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              action,
              const SizedBox(height: 10),
              entity,
            ],
          );
        }
        return Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Activity',
                    style: TextStyle(
                      fontSize: AppTypography.sectionTitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Events are limited to the records your role can manage.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 190, child: action),
            const SizedBox(width: 10),
            SizedBox(width: 190, child: entity),
          ],
        );
      },
    ),
  );

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    items: options.entries
        .map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (selected) {
      if (selected != null && selected != value) onChanged(selected);
    },
  );

  Widget _content() {
    if (_loading) {
      return const AppCard(child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return AppCard(
        child: AppErrorState(
          title: 'Unable To Load Activity',
          message: userFacingError(
            _error!,
            fallback:
                'The activity history could not be loaded. Please try again.',
          ),
          technicalDetails: _error,
          onRetry: _load,
        ),
      );
    }
    if (_events.isEmpty) {
      return const AppEmptyState(
        title: 'No Activity Found',
        message: 'New account and plant changes will appear here.',
        icon: Icons.history_toggle_off_rounded,
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _events.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index < _events.length) return _eventCard(_events[index]);
        return Center(
          child: OutlinedButton.icon(
            onPressed: _loadingMore ? null : () => _load(more: true),
            icon: _loadingMore
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(_loadingMore ? 'Loading…' : 'Load More'),
          ),
        );
      },
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final action = event['action']?.toString() ?? 'update';
    final entity = event['entity_type']?.toString() ?? 'record';
    final actor = event['actor_username']?.toString().trim();
    final role = event['actor_role']?.toString();
    final entityId = event['entity_id']?.toString();
    final title = action == 'plant.dead_record_reopened'
        ? 'Reopened dead plant record'
        : '${_actionLabel(action)} ${_entityLabel(entity)}';
    final newValues = event['new_values'];
    final reopenReason =
        action == 'plant.dead_record_reopened' && newValues is Map
        ? newValues['reason']?.toString()
        : null;
    final subtitle = [
      if (actor != null && actor.isNotEmpty) 'By $actor',
      if (role != null && role.isNotEmpty) _roleLabel(role),
      _formatDate(event['created_at']),
    ].join(' • ');

    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _actionColor(_actionKind(action)).withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _actionIcon(_actionKind(action)),
              color: _actionColor(_actionKind(action)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
                if (entityId != null && entityId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_entityLabel(entity)} #$entityId',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 5),
                if (reopenReason != null) ...[
                  Text('Reason: $reopenReason'),
                  const SizedBox(height: 5),
                ],
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _actionIcon(String action) => switch (action) {
    'create' => Icons.add_circle_outline_rounded,
    'archive' => Icons.archive_outlined,
    'restore' => Icons.unarchive_outlined,
    'inspect' => Icons.fact_check_outlined,
    'replace' => Icons.swap_horiz_rounded,
    'login' => Icons.login_rounded,
    'logout' => Icons.logout_rounded,
    _ => Icons.edit_outlined,
  };

  Color _actionColor(String action) => switch (action) {
    'archive' => AppColors.danger,
    'restore' || 'create' => AppColors.green,
    'replace' => AppColors.accentPurple,
    'inspect' => AppColors.info,
    _ => AppColors.textSecondary,
  };

  String _entityLabel(String value) => switch (value) {
    'qr_tag' => 'QR Tag',
    'qr_tag_batch' => 'QR Tags',
    'user' || 'account' => 'account',
    'inspection' => 'inspection',
    'session' => 'session',
    _ => 'plant',
  };

  String _actionKind(String action) {
    final value = action.toLowerCase();
    if (value.contains('logout')) return 'logout';
    if (value.contains('login')) return 'login';
    if (value.contains('archive')) return 'archive';
    if (value.contains('restore')) return 'restore';
    if (value.contains('replac')) return 'replace';
    if (value.contains('inspection')) return 'inspect';
    if (value.contains('create') || value.contains('registered')) {
      return 'create';
    }
    return 'update';
  }

  String _actionLabel(String action) => switch (_actionKind(action)) {
    'create' => 'Created',
    'archive' => 'Archived',
    'restore' => 'Restored',
    'inspect' => 'Inspected',
    'replace' => 'Replaced',
    'login' => 'Signed in to',
    'logout' => 'Signed out of',
    _ => 'Updated',
  };

  String _roleLabel(String role) {
    final parsed = AppRole.fromValue(role);
    return parsed == AppRole.unknown ? role : parsed.label;
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Unknown time';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $hour:$minute $period';
  }
}
