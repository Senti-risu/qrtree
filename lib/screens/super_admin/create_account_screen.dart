import 'package:flutter/material.dart';

import '../../models/admin_account.dart';
import '../../services/super_admin_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/forms/app_searchable_dropdown.dart';

class CreateAdminAccountDialog extends StatefulWidget {
  const CreateAdminAccountDialog({
    super.key,
    required this.actorUserId,
    this.service,
  });
  final int actorUserId;
  final SuperAdminService? service;

  @override
  State<CreateAdminAccountDialog> createState() =>
      _CreateAdminAccountDialogState();
}

class _CreateAdminAccountDialogState extends State<CreateAdminAccountDialog> {
  static const _roles = {
    'university_admin': 'University Admin',
    'campus_admin': 'Campus Admin',
    'college_admin': 'College Admin',
  };

  late final SuperAdminService _service;
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  String _role = 'university_admin';
  List<AdminScopeOption> _campuses = const [];
  List<AdminScopeOption> _colleges = const [];
  List<AdminAccount> _accounts = const [];
  int? _campusId;
  int? _collegeId;
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  String? _loadError;
  String? _campusError;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SuperAdminService();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final values = await Future.wait([
        _service.getCampuses(),
        _service.getAccounts(widget.actorUserId),
      ]);
      if (!mounted) return;
      setState(() {
        _campuses = values[0] as List<AdminScopeOption>;
        _accounts = values[1] as List<AdminAccount>;
        if (_isRoleLocked(_role)) _role = 'campus_admin';
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _campusChanged(int? value) async {
    setState(() {
      _campusId = value;
      _collegeId = null;
      _colleges = const [];
      _campusError = null;
    });
    if (value != null && _role == 'college_admin') {
      try {
        final colleges = await _service.getColleges(value);
        if (mounted && _campusId == value) setState(() => _colleges = colleges);
      } catch (error) {
        _showError('Could not load colleges. Please select the campus again.');
      }
    }
  }

  void _selectCampusName(String? name) {
    if (name == null) {
      _campusChanged(null);
      return;
    }
    final matches = _campuses.where((item) => item.name == name);
    if (matches.isNotEmpty) _campusChanged(matches.first.id);
  }

  Future<void> _submit() async {
    if (_isRoleLocked(_role)) {
      _showError(
        'The maximum active accounts for this role or scope has been reached.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_role != 'university_admin' && _campusId == null) {
      setState(() => _campusError = 'Select an available campus.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createAccount(
        actorUserId: widget.actorUserId,
        username: _username.text,
        password: _password.text,
        role: _role,
        campusId: _campusId,
        collegeId: _collegeId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create Admin Account'),
    content: SizedBox(
      width: 560,
      child: _loading
          ? const SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.green),
              ),
            )
          : _loadError != null
          ? SizedBox(
              height: 220,
              child: Center(
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _username,
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
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Temporary password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : 'Use at least 8 characters.',
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.entries.map((entry) {
                        final locked = _isRoleLocked(entry.key);
                        return DropdownMenuItem(
                          value: entry.key,
                          enabled: !locked,
                          child: _lockedOption(entry.value, locked),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _role = value;
                          _campusId = null;
                          _collegeId = null;
                          _colleges = const [];
                          _campusError = null;
                        });
                      },
                    ),
                    if (_role != 'university_admin') ...[
                      const SizedBox(height: 14),
                      AppSearchableDropdown(
                        key: ValueKey('account-campus-$_role'),
                        label: 'Campus',
                        isRequired: true,
                        value: _campusId == null
                            ? null
                            : _campuses
                                  .firstWhere((item) => item.id == _campusId)
                                  .name,
                        items: _campuses.map((item) => item.name).toList(),
                        disabledItems: _role == 'campus_admin'
                            ? _campuses
                                  .where(
                                    (item) =>
                                        _activeCampusIds.contains(item.id),
                                  )
                                  .map((item) => item.name)
                                  .toSet()
                            : const {},
                        enabled: !_saving,
                        errorText: _campusError,
                        onChanged: _selectCampusName,
                      ),
                    ],
                    if (_role == 'college_admin') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _collegeId,
                        decoration: const InputDecoration(
                          labelText: 'College',
                          border: OutlineInputBorder(),
                        ),
                        items: _colleges.map((college) {
                          final locked = _activeCollegeIds.contains(college.id);
                          return DropdownMenuItem(
                            value: college.id,
                            enabled: !locked,
                            child: _lockedOption(college.name, locked),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _collegeId = value),
                        validator: (value) => value == null
                            ? 'Select an available college.'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _loading || _loadError != null || _saving ? null : _submit,
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
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_saving ? 'Creating…' : 'Create Account'),
      ),
    ],
  );

  Set<int> get _activeCampusIds => _accounts
      .where(
        (a) => a.isActive && a.role == 'campus_admin' && a.campusId != null,
      )
      .map((a) => a.campusId!)
      .toSet();

  Set<int> get _activeCollegeIds => _accounts
      .where(
        (a) => a.isActive && a.role == 'college_admin' && a.collegeId != null,
      )
      .map((a) => a.collegeId!)
      .toSet();

  bool _isRoleLocked(String role) {
    if (role == 'university_admin') {
      return _accounts.any((a) => a.isActive && a.role == role);
    }
    if (role == 'campus_admin' && _campusId != null) {
      return _activeCampusIds.contains(_campusId);
    }
    if (role == 'college_admin' && _collegeId != null) {
      return _activeCollegeIds.contains(_collegeId);
    }
    return false;
  }

  Widget _lockedOption(String label, bool locked) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      if (locked) ...[
        const SizedBox(width: 8),
        const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
      ],
    ],
  );

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class EditAdminAccountDialog extends StatefulWidget {
  const EditAdminAccountDialog({
    super.key,
    required this.actorUserId,
    required this.account,
  });

  final int actorUserId;
  final AdminAccount account;

  @override
  State<EditAdminAccountDialog> createState() => _EditAdminAccountDialogState();
}

class _EditAdminAccountDialogState extends State<EditAdminAccountDialog> {
  static const _roles = {
    'university_admin': 'University Admin',
    'campus_admin': 'Campus Admin',
    'college_admin': 'College Admin',
  };

  final _service = SuperAdminService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  final _password = TextEditingController();
  List<AdminScopeOption> _campuses = const [];
  List<AdminScopeOption> _colleges = const [];
  List<AdminAccount> _accounts = const [];
  late String _role;
  int? _campusId;
  int? _collegeId;
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.account.username);
    _role = widget.account.role;
    _campusId = widget.account.campusId;
    _collegeId = widget.account.collegeId;
    _load();
  }

  Future<void> _load() async {
    try {
      final campuses = await _service.getCampuses();
      final accounts = await _service.getAccounts(widget.actorUserId);
      var colleges = <AdminScopeOption>[];
      if (_campusId != null && _role == 'college_admin') {
        colleges = await _service.getColleges(_campusId!);
      }
      if (!mounted) return;
      setState(() {
        _campuses = campuses;
        _accounts = accounts
            .where((item) => item.userId != widget.account.userId)
            .toList();
        _colleges = colleges;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _campusChanged(int? value) async {
    setState(() {
      _campusId = value;
      _collegeId = null;
      _colleges = const [];
    });
    if (value != null && _role == 'college_admin') {
      final colleges = await _service.getColleges(value);
      if (mounted) setState(() => _colleges = colleges);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.updateAccount(
        targetUserId: widget.account.userId,
        username: _username.text,
        role: _role,
        campusId: _campusId,
        collegeId: _collegeId,
        newPassword: _password.text,
      );
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
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Set<int> get _activeCampusIds => _accounts
      .where(
        (item) =>
            item.isActive &&
            item.role == 'campus_admin' &&
            item.campusId != null,
      )
      .map((item) => item.campusId!)
      .toSet();

  Set<int> get _activeCollegeIds => _accounts
      .where(
        (item) =>
            item.isActive &&
            item.role == 'college_admin' &&
            item.collegeId != null,
      )
      .map((item) => item.collegeId!)
      .toSet();

  bool get _universityLocked =>
      _accounts.any((item) => item.isActive && item.role == 'university_admin');

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Admin Account'),
    content: SizedBox(
      width: 560,
      child: _loading
          ? const SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.green),
              ),
            )
          : _loadError != null
          ? SizedBox(
              height: 220,
              child: Center(
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _username,
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
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'New password (optional)',
                        helperText: 'Leave blank to keep the current password.',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value != null && value.isNotEmpty && value.length < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.entries.map((entry) {
                        final locked =
                            entry.key == 'university_admin' &&
                            _universityLocked;
                        return DropdownMenuItem(
                          value: entry.key,
                          enabled: !locked,
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.value)),
                              if (locked)
                                const Icon(Icons.lock_outline, size: 18),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _role = value;
                          _campusId = null;
                          _collegeId = null;
                          _colleges = const [];
                        });
                      },
                    ),
                    if (_role != 'university_admin') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _campusId,
                        decoration: const InputDecoration(
                          labelText: 'Campus',
                          border: OutlineInputBorder(),
                        ),
                        items: _campuses.map((campus) {
                          final locked =
                              _role == 'campus_admin' &&
                              _activeCampusIds.contains(campus.id);
                          return DropdownMenuItem(
                            value: campus.id,
                            enabled: !locked,
                            child: Row(
                              children: [
                                Expanded(child: Text(campus.name)),
                                if (locked)
                                  const Icon(Icons.lock_outline, size: 18),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _campusChanged,
                        validator: (value) => value == null
                            ? 'Select an available campus.'
                            : null,
                      ),
                    ],
                    if (_role == 'college_admin') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _collegeId,
                        decoration: const InputDecoration(
                          labelText: 'College',
                          border: OutlineInputBorder(),
                        ),
                        items: _colleges.map((college) {
                          final locked = _activeCollegeIds.contains(college.id);
                          return DropdownMenuItem(
                            value: college.id,
                            enabled: !locked,
                            child: Row(
                              children: [
                                Expanded(child: Text(college.name)),
                                if (locked)
                                  const Icon(Icons.lock_outline, size: 18),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _collegeId = value),
                        validator: (value) => value == null
                            ? 'Select an available college.'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _loading || _loadError != null || _saving ? null : _submit,
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
            : const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Saving…' : 'Save Changes'),
      ),
    ],
  );
}
