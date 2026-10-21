import 'package:flutter/material.dart';

import '../../services/plant_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/word_capitalization.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_shell.dart';

class PlantClassificationCatalogScreen extends StatefulWidget {
  const PlantClassificationCatalogScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.catalog,
  });

  final int userId;
  final String username;
  final String role;
  final PlantClassificationCatalog? catalog;

  @override
  State<PlantClassificationCatalogScreen> createState() =>
      _PlantClassificationCatalogScreenState();
}

class _PlantClassificationCatalogScreenState
    extends State<PlantClassificationCatalogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commonName = TextEditingController();
  final _scientificName = TextEditingController();
  final _search = TextEditingController();
  late final PlantClassificationCatalog _catalog =
      widget.catalog ?? PlantService();

  String? _plantType;
  String? _typeFilter;
  List<String> _plantTypes = [];
  List<Map<String, dynamic>> _classifications = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _commonName.dispose();
    _scientificName.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _catalog.getClassifications(),
        _catalog.getPlantTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _classifications = List<Map<String, dynamic>>.from(results[0]);
        _plantTypes = List<String>.from(results[1]);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(
          error,
          fallback: 'Plant catalog could not be loaded. Try again.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _createClassification() async {
    if (_saving || !_formKey.currentState!.validate() || _plantType == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _catalog.createPlantClassification(
        plantType: _plantType!,
        commonName: capitalizeWords(_commonName.text.trim()),
        scientificName: _scientificName.text.trim(),
      );
      _formKey.currentState!.reset();
      _commonName.clear();
      _scientificName.clear();
      setState(() => _plantType = null);
      await _loadCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plant catalog entry saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'Plant catalog entry could not be saved. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPlantType() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddPlantTypeDialog(),
    );
    if (name == null || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final added = await _catalog.addPlantType(capitalizeWords(name));
      if (!mounted) return;
      setState(() {
        if (!_plantTypes.any(
          (existing) => existing.toLowerCase() == added.toLowerCase(),
        )) {
          _plantTypes = [..._plantTypes, added]..sort();
        }
        _plantType = added;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plant type "$added" is available in the catalog.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'Plant type could not be added. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editClassification(Map<String, dynamic> classification) async {
    final updated = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditClassificationDialog(
        classification: classification,
        plantTypes: _plantTypes,
      ),
    );
    if (updated == null || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _catalog.updatePlantClassification(
        classificationId: classification['classification_id'] as int,
        plantType: updated['plant_type']!,
        commonName: capitalizeWords(updated['common_name']!),
        scientificName: updated['scientific_name']!,
      );
      await _loadCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plant classification updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'Plant classification could not be updated. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> get _filteredClassifications {
    final query = _search.text.trim().toLowerCase();
    return _classifications.where((classification) {
      final type = classification['plant_type']?.toString() ?? '';
      if (_typeFilter != null &&
          type.toLowerCase() != _typeFilter!.toLowerCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      final searchable = [
        classification['common_name'],
        classification['scientific_name'],
        type,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  Widget _buildEntryCard(Map<String, dynamic> classification) => AppCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    borderRadius: AppRadii.medium,
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: AppColors.green,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                classification['common_name']?.toString() ?? 'Unnamed plant',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                classification['scientific_name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _catalogBadge(
          Icons.category_outlined,
          classification['plant_type']?.toString() ?? 'Plant',
          background: AppColors.secondaryContainer,
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: 'Edit ${classification['common_name'] ?? 'classification'}',
          onPressed: _saving ? null : () => _editClassification(classification),
          icon: const Icon(Icons.edit_outlined),
          color: AppColors.green,
        ),
      ],
    ),
  );

  Widget _catalogBadge(
    IconData icon,
    String label, {
    Color background = AppColors.surfaceVariant,
  }) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: AppRadii.fullyRounded,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.green),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AppShell(
    activeRoute: '/plant-classifications',
    mobileTitle: 'Plant Catalog',
    mobileSubtitle: 'University Admin',
    userId: widget.userId,
    username: widget.username,
    role: widget.role,
    userName: widget.username,
    userRole: 'University Admin',
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'University Plant Catalog',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.darkGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Add plant classifications for College Admins to select across campuses. Growth stage, health status, and variety are recorded for each plant.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Catalog Entry',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('plant-type-$_plantType'),
                          initialValue: _plantTypes.contains(_plantType)
                              ? _plantType
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Plant Type',
                          ),
                          items: _plantTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _plantType = value),
                          validator: (value) =>
                              value == null ? 'Select a plant type.' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _addPlantType,
                          icon: const Icon(Icons.add),
                          label: const Text('Add type'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _commonName,
                    enabled: !_saving,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Common Name'),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Enter a common name.';
                      if (name.runes.length > 100) {
                        return 'Use at most 100 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _scientificName,
                    enabled: !_saving,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Scientific Name',
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Enter a scientific name.';
                      if (name.runes.length > 200) {
                        return 'Use at most 200 characters.';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _createClassification,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_saving ? 'Saving...' : 'Add To Catalog'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plant Classifications',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _catalogBadge(
                Icons.eco_outlined,
                '${_classifications.length} ${_classifications.length == 1 ? 'entry' : 'entries'}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && _classifications.isEmpty)
            AppCard(
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: _loadCatalog,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else if (_classifications.isEmpty)
            const AppCard(
              child: Text('No plant classifications have been added yet.'),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  key: const ValueKey('catalog-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText:
                        'Search common name, scientific name, or plant type',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                );
                final typeFilter = DropdownButtonFormField<String>(
                  key: ValueKey('catalog-type-filter-$_typeFilter'),
                  initialValue: _typeFilter ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Plant Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All types')),
                    ..._plantTypes.map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _typeFilter = value?.isEmpty ?? true ? null : value,
                  ),
                );
                if (constraints.maxWidth >= 640) {
                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(width: 210, child: typeFilter),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: AppSpacing.sm),
                    typeFilter,
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Builder(
              builder: (context) {
                final entries = _filteredClassifications;
                if (entries.isEmpty) {
                  return const AppCard(
                    child: Center(
                      child: Text('No catalog entries match your search.'),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _buildEntryCard(entries[index]),
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    ),
  );
}

class _EditClassificationDialog extends StatefulWidget {
  const _EditClassificationDialog({
    required this.classification,
    required this.plantTypes,
  });

  final Map<String, dynamic> classification;
  final List<String> plantTypes;

  @override
  State<_EditClassificationDialog> createState() =>
      _EditClassificationDialogState();
}

class _EditClassificationDialogState extends State<_EditClassificationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _commonName = TextEditingController(
    text: widget.classification['common_name']?.toString() ?? '',
  );
  late final _scientificName = TextEditingController(
    text: widget.classification['scientific_name']?.toString() ?? '',
  );
  late String? _plantType = widget.classification['plant_type']?.toString();

  @override
  void dispose() {
    _commonName.dispose();
    _scientificName.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _plantType == null) return;
    Navigator.pop(context, {
      'plant_type': _plantType!,
      'common_name': _commonName.text.trim(),
      'scientific_name': _scientificName.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Plant Classification'),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: widget.plantTypes.contains(_plantType)
                    ? _plantType
                    : null,
                decoration: const InputDecoration(labelText: 'Plant Type'),
                items: widget.plantTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _plantType = value),
                validator: (value) =>
                    value == null ? 'Select a plant type.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _commonName,
                autofocus: true,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Common Name'),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Enter a common name.';
                  if (name.runes.length > 100) {
                    return 'Use at most 100 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _scientificName,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Scientific Name'),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Enter a scientific name.';
                  if (name.runes.length > 200) {
                    return 'Use at most 200 characters.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save Changes')),
    ],
  );
}

class _AddPlantTypeDialog extends StatefulWidget {
  const _AddPlantTypeDialog();

  @override
  State<_AddPlantTypeDialog> createState() => _AddPlantTypeDialogState();
}

class _AddPlantTypeDialogState extends State<_AddPlantTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Plant Type'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Plant Type'),
        validator: (value) {
          final type = value?.trim() ?? '';
          if (type.isEmpty) return 'Enter a plant type.';
          if (type.runes.length > 80) return 'Use at most 80 characters.';
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Add Type')),
    ],
  );
}
