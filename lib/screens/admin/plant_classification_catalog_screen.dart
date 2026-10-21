import 'package:flutter/material.dart';

import '../../services/plant_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/word_capitalization.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page_header.dart';
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

  Future<void> _editPlantType() async {
    final currentName = _plantType;
    if (currentName == null || _saving) return;
    final updatedName = await showDialog<String>(
      context: context,
      builder: (_) => _EditPlantTypeDialog(currentName: currentName),
    );
    if (updatedName == null || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final savedName = await _catalog.updatePlantType(
        currentName: currentName,
        updatedName: capitalizeWords(updatedName),
      );
      await _loadCatalog();
      if (!mounted) return;
      setState(() {
        _plantTypes =
            _plantTypes
                .map((type) => type == currentName ? savedName : type)
                .toList()
              ..sort();
        _plantType = savedName;
        if (_typeFilter == currentName) _typeFilter = savedName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plant type updated to "$savedName" across existing classifications.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'Plant type could not be updated. Try again.',
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

  Future<void> _deleteClassification(
    Map<String, dynamic> classification,
  ) async {
    final commonName =
        classification['common_name']?.toString() ?? 'this classification';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove plant classification?'),
        content: Text(
          '"$commonName" will be removed from the catalog and no longer be '
          'available for new plant records. Existing plants and their saved '
          'data will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove from Catalog'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _catalog.deletePlantClassification(
        classificationId: classification['classification_id'] as int,
      );
      await _loadCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Classification removed from the catalog. Existing plant data was kept.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'Plant classification could not be removed. Try again.',
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

  Widget _buildEntryRow(
    Map<String, dynamic> classification, {
    required bool showDivider,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      final identity = Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: AppColors.green,
              size: 20,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final typeBadge = _catalogBadge(
        Icons.category_outlined,
        classification['plant_type']?.toString() ?? 'Plant',
        background: AppColors.secondaryContainer,
      );
      final actions = _entryActions(classification);

      final content = compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: typeBadge),
                    actions,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: AppSpacing.md),
                typeBadge,
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );

      return Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.md : AppSpacing.lg,
              vertical: compact ? AppSpacing.md : AppSpacing.sm,
            ),
            child: content,
          ),
          if (showDivider)
            const Divider(
              height: 1,
              thickness: 1,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
              color: AppColors.border,
            ),
        ],
      );
    },
  );

  Widget _entryActions(Map<String, dynamic> classification) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Edit ${classification['common_name'] ?? 'classification'}',
        onPressed: _saving ? null : () => _editClassification(classification),
        icon: const Icon(Icons.edit_outlined),
        color: AppColors.green,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
      IconButton(
        tooltip: 'Delete ${classification['common_name'] ?? 'classification'}',
        onPressed: _saving ? null : () => _deleteClassification(classification),
        icon: const Icon(Icons.delete_outline_rounded),
        color: AppColors.danger,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
    ],
  );

  Widget _buildEntryTable(List<Map<String, dynamic>> entries) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 640) {
        return Column(
          children: [
            for (var index = 0; index < entries.length; index++)
              _buildEntryRow(
                entries[index],
                showDivider: index < entries.length - 1,
              ),
          ],
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: const WidgetStatePropertyAll(AppColors.background),
          columnSpacing: 32,
          columns: const [
            DataColumn(label: Text('PLANT CLASSIFICATION')),
            DataColumn(label: Text('PLANT TYPE')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: entries.map((classification) {
            final commonName =
                classification['common_name']?.toString() ?? 'Unnamed plant';
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commonName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                ),
                DataCell(
                  _catalogBadge(
                    Icons.category_outlined,
                    classification['plant_type']?.toString() ?? 'Plant',
                    background: AppColors.secondaryContainer,
                  ),
                ),
                DataCell(_entryActions(classification)),
              ],
            );
          }).toList(),
        ),
      );
    },
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
          const AppPageHeader(
            title: 'University Plant Catalog',
            subtitle:
                'Add plant classifications for College Admins to select across campuses.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: AppRadii.medium,
                        ),
                        child: const Icon(
                          Icons.add_business_rounded,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Catalog Entry',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.darkGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Add a plant for campus admins to use when registering plants.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final typeDropdown = DropdownButtonFormField<String>(
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
                      );
                      final typeActions = Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _addPlantType,
                            icon: const Icon(Icons.add),
                            label: const Text('Add type'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving || _plantType == null
                                ? null
                                : _editPlantType,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit type'),
                          ),
                        ],
                      );
                      if (constraints.maxWidth >= 520) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: typeDropdown),
                            const SizedBox(width: AppSpacing.md),
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: typeActions,
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          typeDropdown,
                          Align(
                            alignment: Alignment.centerLeft,
                            child: typeActions,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final commonName = TextFormField(
                        controller: _commonName,
                        enabled: !_saving,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Common Name',
                          hintText: 'e.g. Narra',
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) return 'Enter a common name.';
                          if (name.runes.length > 100) {
                            return 'Use at most 100 characters.';
                          }
                          return null;
                        },
                      );
                      final scientificName = TextFormField(
                        controller: _scientificName,
                        enabled: !_saving,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Scientific Name',
                          hintText: 'e.g. Pterocarpus indicus',
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) {
                            return 'Enter a scientific name.';
                          }
                          if (name.runes.length > 200) {
                            return 'Use at most 200 characters.';
                          }
                          return null;
                        },
                      );
                      if (constraints.maxWidth >= 760) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: commonName),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: scientificName),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          commonName,
                          const SizedBox(height: AppSpacing.md),
                          scientificName,
                        ],
                      );
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.dangerContainer,
                        borderRadius: AppRadii.medium,
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
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
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(180, 48),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.medium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            boxShadow: const [],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Plant Classifications',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
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
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.md,
                              ),
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
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.md,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('All types'),
                              ),
                              ..._plantTypes.map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _typeFilter = value?.isEmpty ?? true
                                  ? null
                                  : value,
                            ),
                          );
                          if (constraints.maxWidth >= 640) {
                            return Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: AppSpacing.md),
                                SizedBox(width: 220, child: typeFilter),
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
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null && _classifications.isEmpty)
                        Column(
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.danger),
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: _loadCatalog,
                              child: const Text('Try Again'),
                            ),
                          ],
                        )
                      else if (_classifications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.eco_outlined,
                                size: 40,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: AppSpacing.sm),
                              Text(
                                'Your catalog is ready to grow',
                                style: TextStyle(
                                  color: AppColors.darkGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                'Create the first plant classification using the form above.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Builder(
                          builder: (context) {
                            final entries = _filteredClassifications;
                            if (entries.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl,
                                ),
                                child: Center(
                                  child: Text(
                                    'No catalog entries match your search.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return _buildEntryTable(entries);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

class _EditPlantTypeDialog extends StatefulWidget {
  const _EditPlantTypeDialog({required this.currentName});

  final String currentName;

  @override
  State<_EditPlantTypeDialog> createState() => _EditPlantTypeDialogState();
}

class _EditPlantTypeDialogState extends State<_EditPlantTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.currentName);

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
    title: const Text('Edit Plant Type'),
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
      FilledButton(onPressed: _submit, child: const Text('Save Plant Type')),
    ],
  );
}
