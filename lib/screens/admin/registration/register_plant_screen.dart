import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/app_role.dart';
import '../../../services/qr_print_service.dart';
import '../../../services/registration_draft_store.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../utils/user_facing_error.dart';
import '../../../utils/word_capitalization.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_error_state.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/app_navigation_guard.dart';
import '../../../widgets/registration_exit_dialog.dart';
import '../../../widgets/registration_progress.dart';
import '../../../widgets/forms/app_searchable_dropdown.dart';
import '../../../widgets/forms/app_text_field.dart';
import '../../../widgets/forms/planting_campus_dropdown.dart';
import '../../../models/plant_record_lock.dart';
import '../../../widgets/dead_plant_lock.dart';
import '../../../widgets/forms/locked_plant_assignment.dart';
import '../../../services/plant_service.dart';
import 'widgets/plant_image_picker_field.dart';

class RegisterPlantScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;
  final Map<String, dynamic>? existingQrTag;
  final PlantService? plantService;
  final RegistrationDraftStore? draftStore;

  const RegisterPlantScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
    this.existingQrTag,
    this.plantService,
    this.draftStore,
  });

  @override
  State<RegisterPlantScreen> createState() => _RegisterPlantScreenState();
}

class _RegisterPlantScreenState extends State<RegisterPlantScreen> {
  late final PlantService _plantService = widget.plantService ?? PlantService();
  final QrPrintService _qrPrintService = QrPrintService();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _formScroll = ScrollController();
  late final RegistrationDraftStore _drafts =
      widget.draftStore ?? RegistrationDraftStore();
  bool _draftBusy = false;
  bool _draftChecked = false;

  String get _draftKey => RegistrationDraftStore.keyFor(
    userId: widget.userId,
    role: widget.role,
    campusId: widget.campusId,
    collegeId: widget.collegeId,
    qrTagId: _existingQrTagId,
  );

  static const int _maxVarietyLength = 100;
  static const int _maxPlanterLength = 120;

  final TextEditingController _varietyController = TextEditingController();

  final TextEditingController _scientificNameController =
      TextEditingController();

  final TextEditingController _planterController = TextEditingController();

  final TextEditingController _zipCodeController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isPickingImage = false;

  // PostgreSQL enum values.
  final List<String> _plantTypes = const ['Tree', 'Shrub', 'Herb', 'Vine'];

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  int _mobileStep = 0;
  bool _showPlantErrors = false;
  bool _showLocationErrors = false;
  String? _plantValidationError;
  bool _hasUnsavedChanges = false;
  bool _allowPop = false;

  String? _plantType;
  String? _commonName;
  String? _growthStage;
  String? _healthStatus;

  // IMPORTANT:
  // Campus is selected before College.
  String? _campus;
  String? _college;
  String? _plantingCampusChoice;

  // Town is selected before Barangay.
  String? _town;
  String? _barangay;

  DateTime? _datePlanted;

  int? _selectedClassificationId;
  int? _selectedCampusId;
  int? _selectedCollegeId;
  int? _selectedTownId;
  int? _selectedBarangayId;
  int? _selectedGrowthStatusId;
  int? _selectedHealthStatusId;

  List<Map<String, dynamic>> _classifications = [];
  List<Map<String, dynamic>> _campuses = [];
  List<Map<String, dynamic>> _colleges = [];
  List<Map<String, dynamic>> _towns = [];
  List<Map<String, dynamic>> _barangays = [];
  List<Map<String, dynamic>> _growthStatuses = [];
  List<Map<String, dynamic>> _healthStatuses = [];

  bool get _usingExistingQr => widget.existingQrTag != null;

  RoleCapabilities get _capabilities => RoleCapabilities.fromValue(widget.role);

  bool get _registrationScopeLocked => _capabilities.locksRegistrationScope;

  int? get _existingQrTagId => widget.existingQrTag?['qr_tag_id'] as int?;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _varietyController,
      _scientificNameController,
      _planterController,
      _zipCodeController,
    ]) {
      controller.addListener(_markDirty);
    }
    if (_capabilities.canRegisterPlants) {
      _loadData();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _formScroll.dispose();
    for (final controller in [
      _varietyController,
      _scientificNameController,
      _planterController,
      _zipCodeController,
    ]) {
      controller.removeListener(_markDirty);
    }
    _varietyController.dispose();
    _scientificNameController.dispose();
    _planterController.dispose();
    _zipCodeController.dispose();

    super.dispose();
  }

  void _markDirty() {
    if (_loading || _hasUnsavedChanges || !mounted) return;
    setState(() => _hasUnsavedChanges = true);
  }

  Map<String, dynamic> _draftData() => {
    'classificationId': _selectedClassificationId,
    'plantType': _plantType,
    'growthId': _selectedGrowthStatusId,
    'healthId': _selectedHealthStatusId,
    'townId': _selectedTownId,
    'barangayId': _selectedBarangayId,
    'plantingCampus': _plantingCampusChoice,
    'variety': capitalizeWords(_varietyController.text),
    'planter': capitalizeWords(_planterController.text),
    'datePlanted': _datePlanted?.toIso8601String(),
    'photoName': _selectedImage?.name,
    'photo': _selectedImageBytes == null
        ? null
        : base64Encode(_selectedImageBytes!),
  };

  Future<bool> _saveDraft() async {
    if (_saving || _draftBusy) return false;
    setState(() => _draftBusy = true);
    try {
      await _drafts.save(_draftKey, _draftData());
      if (mounted) {
        _message('Draft saved on this device, including the selected photo.');
      }
      return true;
    } catch (_) {
      if (mounted) {
        _message(
          'Could not save the draft. Stay on this page and try again.',
          error: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _draftBusy = false);
    }
  }

  Future<void> _offerDraft() async {
    if (_draftChecked) return;
    _draftChecked = true;
    try {
      final draft = await _drafts.read(_draftKey);
      if (!mounted || draft == null) return;
      final resume = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Resume saved registration?'),
          content: const Text(
            'A draft for your account is saved on this device. Review its details before registering.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard draft'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
      if (!mounted || resume == null) return;
      if (!resume) {
        await _drafts.discard(_draftKey);
        return;
      }
      _restoreDraft(draft);
    } catch (_) {
      if (mounted) {
        _message(
          'The saved draft could not be loaded. It has not been deleted. You can retry by reopening registration.',
          error: true,
        );
      }
    }
  }

  void _restoreDraft(Map<String, dynamic> data) {
    Map<String, dynamic>? row(
      List<Map<String, dynamic>> rows,
      String key,
      Object? id,
    ) {
      if (id is! int) return null;
      for (final candidate in rows) {
        if (candidate[key] == id) return candidate;
      }
      return null;
    }

    String text(String key, int limit) {
      final value = data[key];
      if (value is! String) return '';
      return value.length <= limit ? value : value.substring(0, limit);
    }

    // Decode and validate before modifying the form, so corrupt photo data
    // cannot leave a half-restored form behind.
    Uint8List? photo;
    final photoName = text('photoName', 255);
    final encoded = data['photo'];
    if (encoded != null) {
      if (encoded is! String || encoded.length > 9 * 1024 * 1024) {
        throw const FormatException('Invalid draft photo');
      }
      photo = base64Decode(encoded);
      PlantPhotoRules.validate(
        bytes: photo,
        extension: photoName.split('.').last,
      );
    }
    final classification = row(
      _classifications,
      'classification_id',
      data['classificationId'],
    );
    final growth = row(_growthStatuses, 'growth_status_id', data['growthId']);
    final health = row(_healthStatuses, 'health_status_id', data['healthId']);
    final town = row(_towns, 'town_id', data['townId']);
    final barangay = row(_barangays, 'barangay_id', data['barangayId']);
    final planting = data['plantingCampus'];
    setState(() {
      _selectedClassificationId = classification?['classification_id'] as int?;
      _plantType = classification == null
          ? (_plantTypes.contains(data['plantType'])
                ? data['plantType'] as String
                : null)
          : _titleCase(classification['plant_type']?.toString() ?? '');
      _commonName = classification?['common_name']?.toString();
      _scientificNameController.text =
          classification?['scientific_name']?.toString() ?? '';
      _selectedGrowthStatusId = growth?['growth_status_id'] as int?;
      _growthStage = growth == null
          ? null
          : _titleCase(growth['growth_stage']?.toString() ?? '');
      _selectedHealthStatusId = health?['health_status_id'] as int?;
      _healthStatus = health == null
          ? null
          : _friendlyHealth(health['status_name']?.toString());
      _selectedTownId = town?['town_id'] as int?;
      _town = town?['town_name']?.toString();
      final validBarangay =
          town != null && barangay?['town_id'] == _selectedTownId;
      _selectedBarangayId = validBarangay
          ? (barangay?['barangay_id'] as int?)
          : null;
      _barangay = validBarangay
          ? (barangay?['barangay_name']?.toString())
          : null;
      _zipCodeController.text = town?['zip_code']?.toString() ?? '';
      _plantingCampusChoice =
          planting is String &&
              (planting == PlantingCampusDropdown.outside ||
                  _campuses.any((c) => '${c['campus_id']}' == planting))
          ? planting
          : null;
      _varietyController.text = capitalizeWords(
        text('variety', _maxVarietyLength),
      );
      _planterController.text = capitalizeWords(
        text('planter', _maxPlanterLength),
      );
      final date = DateTime.tryParse(text('datePlanted', 40));
      _datePlanted =
          date != null && date.year >= 1950 && !date.isAfter(DateTime.now())
          ? date
          : null;
      _selectedImageBytes = photo;
      _selectedImage = photo == null
          ? null
          : XFile.fromData(photo, name: photoName);
      _mobileStep = 0;
      _hasUnsavedChanges = true;
    });
  }

  // ============================================================
  // LOAD SUPABASE DATA
  // ============================================================

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      if (_registrationScopeLocked &&
          (widget.campusId == null || widget.collegeId == null)) {
        throw StateError('This account has no assigned campus or college.');
      }
      final results = await Future.wait([
        _plantService.getClassifications(),
        _plantService.getCampuses(),
        _plantService.getColleges(),
        _plantService.getTowns(),
        _plantService.getBarangays(),
        _plantService.getGrowthStatuses(),
        _plantService.getHealthStatuses(),
      ]);

      if (!mounted) return;

      setState(() {
        // Format display names locally; database IDs and scientific names stay intact.
        List<Map<String, dynamic>> namedRows(
          List<Map<String, dynamic>> rows,
          String key,
        ) => rows
            .map(
              (row) => {
                ...row,
                if (row[key] is String)
                  key: capitalizeWords(row[key] as String),
              },
            )
            .toList();
        _classifications = namedRows(results[0], 'common_name');
        _campuses = namedRows(results[1], 'campus_name');
        _colleges = namedRows(results[2], 'college_name');
        _towns = namedRows(results[3], 'town_name');
        _barangays = namedRows(results[4], 'barangay_name');
        _growthStatuses = results[5];
        _healthStatuses = results[6];

        // If the logged-in College Admin already has an assigned campus,
        // we can preselect it when the row exists.
        if (widget.campusId != null) {
          final campusMatches = _campuses.where(
            (row) => row['campus_id'] == widget.campusId,
          );

          if (campusMatches.isNotEmpty) {
            _selectedCampusId = widget.campusId;
            _campus = campusMatches.first['campus_name']?.toString();
          }
        }

        // If the account has an assigned college, preselect it
        // only when it belongs to the selected campus.
        if (widget.collegeId != null && _selectedCampusId != null) {
          final collegeMatches = _colleges.where(
            (row) =>
                row['college_id'] == widget.collegeId &&
                row['campus_id'] == _selectedCampusId,
          );

          if (collegeMatches.isNotEmpty) {
            _selectedCollegeId = widget.collegeId;
            _college = collegeMatches.first['college_name']?.toString();
          }
        }

        _loading = false;
      });
      await _offerDraft();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  // ============================================================
  // FILTERED VALUES
  // ============================================================

  List<String> get _filteredCommonNames {
    if (_plantType == null) return [];

    return _classifications
        .where(
          (row) =>
              _titleCase(row['plant_type']?.toString() ?? '') == _plantType,
        )
        .map((row) => row['common_name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> get _campusNames {
    return _campuses
        .map((row) => row['campus_name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  // College is filtered by selected Campus.
  List<String> get _filteredCollegeNames {
    if (_selectedCampusId == null) {
      return [];
    }

    return _colleges
        .where((row) => row['campus_id'] == _selectedCampusId)
        .map((row) => row['college_name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<String> get _townNames {
    return _towns
        .map((row) => row['town_name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  // Barangay is filtered by selected Town.
  List<String> get _filteredBarangayNames {
    if (_selectedTownId == null) {
      return [];
    }

    return _barangays
        .where((row) => row['town_id'] == _selectedTownId)
        .map((row) => row['barangay_name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<String> get _growthStageNames {
    return _growthStatuses
        .map((row) => _titleCase(row['growth_stage']?.toString() ?? ''))
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<String> get _healthStatusNames {
    return _healthStatuses
        .map((row) => _friendlyHealth(row['status_name']?.toString()))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  // ============================================================
  // PLANT SELECTIONS
  // ============================================================

  void _selectPlantType(String? value) {
    setState(() {
      _hasUnsavedChanges = true;
      _plantType = value;

      _commonName = null;
      _selectedClassificationId = null;

      _scientificNameController.clear();
    });
  }

  void _selectCommonName(String? value) {
    if (value == null) {
      setState(() {
        _hasUnsavedChanges = true;
        _commonName = null;
        _selectedClassificationId = null;
        _scientificNameController.clear();
      });
      return;
    }
    if (_plantType == null) {
      return;
    }

    final matches = _classifications.where(
      (row) =>
          row['common_name']?.toString() == value &&
          _titleCase(row['plant_type']?.toString() ?? '') == _plantType,
    );

    if (matches.isEmpty) {
      return;
    }

    final row = matches.first;

    setState(() {
      _hasUnsavedChanges = true;
      _commonName = value;

      _selectedClassificationId = row['classification_id'] as int?;

      _scientificNameController.text = row['scientific_name']?.toString() ?? '';
    });
  }

  // ============================================================
  // CAMPUS -> COLLEGE
  // ============================================================

  void _selectCampus(String? value) {
    if (value == null) {
      setState(() {
        _hasUnsavedChanges = true;
        _campus = null;
        _selectedCampusId = null;

        _college = null;
        _selectedCollegeId = null;
      });

      return;
    }

    final matches = _campuses.where(
      (row) => row['campus_name']?.toString() == value,
    );

    if (matches.isEmpty) {
      return;
    }

    final row = matches.first;

    setState(() {
      _hasUnsavedChanges = true;
      _campus = value;

      _selectedCampusId = row['campus_id'] as int?;

      // College depends on Campus.
      _college = null;
      _selectedCollegeId = null;
    });
  }

  void _selectCollege(String? value) {
    if (value == null) {
      setState(() {
        _hasUnsavedChanges = true;
        _college = null;
        _selectedCollegeId = null;
      });
      return;
    }
    if (_selectedCampusId == null) {
      return;
    }

    final matches = _colleges.where(
      (row) =>
          row['college_name']?.toString() == value &&
          row['campus_id'] == _selectedCampusId,
    );

    if (matches.isEmpty) {
      return;
    }

    final row = matches.first;

    setState(() {
      _hasUnsavedChanges = true;
      _college = value;

      _selectedCollegeId = row['college_id'] as int?;
    });
  }

  // ============================================================
  // TOWN -> BARANGAY -> ZIP
  // ============================================================

  void _selectTown(String? value) {
    if (value == null) {
      setState(() {
        _hasUnsavedChanges = true;
        _town = null;
        _selectedTownId = null;

        _barangay = null;
        _selectedBarangayId = null;

        _zipCodeController.clear();
      });

      return;
    }

    final matches = _towns.where(
      (row) => row['town_name']?.toString() == value,
    );

    if (matches.isEmpty) {
      return;
    }

    final row = matches.first;

    setState(() {
      _hasUnsavedChanges = true;
      _town = value;

      _selectedTownId = row['town_id'] as int?;

      _zipCodeController.text = row['zip_code']?.toString() ?? '';

      // Barangay depends on Town.
      _barangay = null;
      _selectedBarangayId = null;
    });
  }

  void _selectBarangay(String? value) {
    if (value == null) {
      setState(() {
        _barangay = null;
        _selectedBarangayId = null;
        _hasUnsavedChanges = true;
      });
      return;
    }
    if (_selectedTownId == null) {
      return;
    }

    final matches = _barangays.where(
      (row) =>
          row['barangay_name']?.toString() == value &&
          row['town_id'] == _selectedTownId,
    );

    if (matches.isEmpty) {
      return;
    }

    final row = matches.first;

    setState(() {
      _hasUnsavedChanges = true;
      _barangay = value;

      _selectedBarangayId = row['barangay_id'] as int?;
    });
  }

  // ============================================================
  // GROWTH / HEALTH
  // ============================================================

  void _selectGrowthStage(String? value) {
    if (value == null) {
      setState(() {
        _hasUnsavedChanges = true;
        _growthStage = null;
        _selectedGrowthStatusId = null;
      });
      return;
    }

    final matches = _growthStatuses.where(
      (row) => _titleCase(row['growth_stage']?.toString() ?? '') == value,
    );

    if (matches.isEmpty) {
      return;
    }

    final row = matches.first;

    setState(() {
      _hasUnsavedChanges = true;
      _growthStage = value;

      _selectedGrowthStatusId = row['growth_status_id'] as int?;
    });
  }

  void _selectHealthStatus(String? value) {
    if (value == null) {
      setState(() {
        _hasUnsavedChanges = true;
        _healthStatus = null;
        _selectedHealthStatusId = null;
      });
      return;
    }

    final matches = _healthStatuses.where(
      (row) => _friendlyHealth(row['status_name']?.toString()) == value,
    );

    if (matches.isEmpty) {
      return;
    }

    final row = matches.first;

    setState(() {
      _hasUnsavedChanges = true;
      _healthStatus = value;

      _selectedHealthStatusId = row['health_status_id'] as int?;
    });
  }

  // ============================================================
  // DATE
  // ============================================================

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,

      initialDate: _datePlanted ?? DateTime.now(),

      firstDate: DateTime(1950),

      lastDate: DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;
      _datePlanted = selected;
    });
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Add a plant photo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'A clear photo makes the plant easier to identify.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _isPickingImage = true);
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = image.name.contains('.')
          ? image.name.split('.').last
          : 'jpg';
      PlantPhotoRules.validate(bytes: bytes, extension: extension);
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = true;
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        _message(
          userFacingError(
            e,
            fallback:
                'The photo could not be added. Check camera permission and try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removeImage() {
    setState(() {
      _hasUnsavedChanges = true;
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  // ============================================================
  // REGISTER PLANT
  // ============================================================

  List<String> get _missingPlantFields => [
    if (_selectedCampusId == null || _selectedCollegeId == null)
      'managing campus and college',
    if (_plantType == null) 'plant type',
    if (_selectedClassificationId == null) 'common name',
    if (_selectedGrowthStatusId == null) 'growth stage',
    if (_selectedHealthStatusId == null) 'health status',
    if (_datePlanted == null) 'date planted',
  ];

  List<String> get _missingLocationFields => [
    if (_plantingCampusChoice == null) 'planting campus or Outside campus',
    if (_selectedTownId == null) 'town',
    if (_selectedBarangayId == null) 'barangay',
  ];

  bool _validatePlantStep({bool announce = true}) {
    final missing = _missingPlantFields;
    final varietyLength = _varietyController.text.trim().runes.length;
    final planterLength = _planterController.text.trim().runes.length;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    String? validationError;
    if (varietyLength > _maxVarietyLength) {
      validationError =
          'Variety must be $_maxVarietyLength characters or fewer.';
    } else if (planterLength > _maxPlanterLength) {
      validationError =
          'Tree planter must be $_maxPlanterLength characters or fewer.';
    } else if (_datePlanted != null && _datePlanted!.isAfter(todayOnly)) {
      validationError = 'Date planted cannot be in the future.';
    }

    setState(() {
      _plantValidationError = validationError;
      _showPlantErrors = missing.isNotEmpty || validationError != null;
    });
    if (_showPlantErrors && announce) {
      _message(
        missing.isNotEmpty
            ? 'Please fill out: ${missing.join(', ')}.'
            : validationError!,
        error: true,
      );
    }
    return missing.isEmpty && validationError == null;
  }

  bool _validateLocationStep({bool announce = true}) {
    final missing = _missingLocationFields;
    setState(() => _showLocationErrors = missing.isNotEmpty);
    if (missing.isNotEmpty && announce) {
      _message('Please fill out: ${missing.join(', ')}.', error: true);
    }
    return missing.isEmpty;
  }

  void _nextMobileStep() {
    _goToStep((_mobileStep + 1).clamp(0, 3).toInt());
  }

  void _previousMobileStep() {
    _goToStep((_mobileStep - 1).clamp(0, 3).toInt());
  }

  void _goToStep(int step) {
    if (_saving || _draftBusy || step < 0 || step > 3) return;
    if (step > _mobileStep) {
      if (!_validatePlantStep()) {
        _showStep(0);
        return;
      }
      if (step > 1 && !_validateLocationStep()) {
        _showStep(1);
        return;
      }
    }
    _showStep(step);
  }

  void _showStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _mobileStep = step);
    if (_formScroll.hasClients) _formScroll.jumpTo(0);
  }

  Future<bool> _confirmPossibleDuplicates(
    List<Map<String, dynamic>> candidates,
  ) async {
    final preview = candidates.take(3).toList();
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.content_copy_rounded,
              color: AppColors.warning,
            ),
            title: const Text('Possible duplicate plant'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${candidates.length} similar ${candidates.length == 1 ? 'record was' : 'records were'} found in this location. Review them before creating another plant.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...preview.map((candidate) {
                    final id = candidate['plant_id']?.toString() ?? 'Unknown';
                    final name =
                        candidate['common_name']?.toString().trim() ?? '';
                    final variety =
                        candidate['variety']?.toString().trim() ?? '';
                    final planted =
                        candidate['date_planted']?.toString().trim() ?? '';
                    final details = [
                      if (name.isNotEmpty) name,
                      if (variety.isNotEmpty) variety,
                      if (planted.isNotEmpty) planted,
                    ].join(' · ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'Plant #$id${details.isEmpty ? '' : ' — $details'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                  if (candidates.length > preview.length)
                    Text(
                      'And ${candidates.length - preview.length} more similar records.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Review information'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _registerPlant() async {
    if (_saving || _draftBusy) {
      return;
    }

    if (!_capabilities.canRegisterPlants) {
      _message(
        'College Admin or Inspection Team access is required to register plants.',
        error: true,
      );
      return;
    }

    final plantValid = _validatePlantStep(announce: false);
    final locationValid = _validateLocationStep(announce: false);
    if (!plantValid || !locationValid) {
      _showStep(plantValid ? 1 : 0);
      _message(
        'Review the missing information before registering this plant.',
        error: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    UploadedPlantPhoto? uploadedPhoto;
    var registrationCompleted = false;
    try {
      if (PlantRecordLock.isDeadStatus(_healthStatus)) {
        if (!await confirmDeadPlant(context) || !mounted) return;
      }
      final possibleDuplicates = await _plantService
          .findPossibleDuplicatePlants(
            classificationId: _selectedClassificationId!,
            campusId: _selectedCampusId!,
            collegeId: _selectedCollegeId!,
            townId: _selectedTownId!,
            barangayId: _selectedBarangayId!,
            variety: _emptyToNull(capitalizeWords(_varietyController.text)),
            datePlanted: _datePlanted == null
                ? null
                : _formatDate(_datePlanted!),
          );
      if (!mounted) return;
      if (possibleDuplicates.isNotEmpty) {
        final continueRegistration = await _confirmPossibleDuplicates(
          possibleDuplicates,
        );
        if (!continueRegistration || !mounted) return;
      }

      String? photoUrl;
      if (_selectedImage != null && _selectedImageBytes != null) {
        final name = _selectedImage!.name;
        final extension = name.contains('.')
            ? name.split('.').last.toLowerCase()
            : 'jpg';
        uploadedPhoto = await _plantService.uploadPlantPhoto(
          registeredBy: widget.userId,
          bytes: _selectedImageBytes!,
          extension: extension,
        );
        photoUrl = uploadedPhoto.publicUrl;
      }

      final result = await _plantService.registerPlantWithQr(
        locationType: _plantingCampusChoice == PlantingCampusDropdown.outside
            ? 'outside'
            : 'inside',
        locationCampusId: PlantingCampusDropdown.campusId(
          _plantingCampusChoice,
        ),
        classificationId: _selectedClassificationId!,

        campusId: _selectedCampusId!,

        collegeId: _selectedCollegeId!,

        townId: _selectedTownId!,

        barangayId: _selectedBarangayId!,

        growthStatusId: _selectedGrowthStatusId!,

        healthStatusId: _selectedHealthStatusId!,

        registeredBy: widget.userId,

        existingQrTagId: _existingQrTagId,

        variety: _emptyToNull(capitalizeWords(_varietyController.text)),

        datePlanted: _datePlanted == null ? null : _formatDate(_datePlanted!),

        treePlanter: _emptyToNull(capitalizeWords(_planterController.text)),

        photoUrl: photoUrl,
      );
      registrationCompleted = true;
      try {
        await _drafts.complete(_draftKey);
      } catch (_) {
        if (mounted) {
          _message(
            'Plant registered, but the local draft could not be cleared. Discard it if offered again.',
            error: true,
          );
        }
      }

      if (!mounted) {
        return;
      }

      _hasUnsavedChanges = false;
      _allowPop = true;
      await _successDialog(result);
    } catch (e) {
      if (!registrationCompleted && uploadedPhoto != null) {
        try {
          await _plantService.deletePlantPhoto(uploadedPhoto.path);
        } catch (_) {
          // Cleanup is best effort because older storage policies may not yet
          // allow deletes. Never replace the original registration error.
        }
      }
      if (!mounted) {
        return;
      }

      _message(
        userFacingError(
          e,
          fallback: 'The plant could not be registered. Please try again.',
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _successDialog(Map<String, dynamic> result) async {
    final qrCode = result['qr_code_string'].toString();

    await showDialog<void>(
      context: context,

      barrierDismissible: false,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Plant Registered'),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text('Plant ID: ${result['plant_id']}'),

              const SizedBox(height: AppSpacing.sm),

              Text(
                _usingExistingQr
                    ? 'Existing QR assigned:'
                    : 'New QR generated:',
              ),

              const SizedBox(height: AppSpacing.xs),

              SelectableText(qrCode),
            ],
          ),

          actions: [
            TextButton.icon(
              onPressed: () async {
                await _qrPrintService.printSingleTag(
                  qrCode: qrCode,

                  subtitle: _commonName,
                );
              },

              icon: const Icon(Icons.print_outlined),

              label: const Text('Print QR'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushReplacementNamed(
                  context,
                  '/register-plant',
                  arguments: {
                    'user_id': widget.userId,
                    'username': widget.username,
                    'role': widget.role,
                    'campus_id': widget.campusId,
                    'college_id': widget.collegeId,
                  },
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Register another'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushReplacementNamed(
                  context,
                  '/plant-details',
                  arguments: {
                    'plant_id': result['plant_id'],
                    'user_id': widget.userId,
                    'username': widget.username,
                    'role': widget.role,
                  },
                );
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View plant'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PAGE BUILD
  // ============================================================

  Future<bool> _confirmDiscard() async {
    if (_saving || _draftBusy) return false;
    if (!_hasUnsavedChanges) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => const RegistrationExitDialog(),
    );
    if (!mounted || choice == null || choice == 'stay') return false;
    if (choice == 'save') return _saveDraft();
    try {
      setState(() => _draftBusy = true);
      await _drafts.discard(_draftKey);
      if (mounted) setState(() => _hasUnsavedChanges = false);
      return true;
    } catch (_) {
      if (mounted) {
        _message(
          'Could not discard the saved draft. Please try again.',
          error: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _draftBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final phone = width < AppBreakpoints.desktop;

    Widget body;

    if (!_capabilities.canRegisterPlants) {
      body = const AppErrorState(
        title: 'Registration unavailable',
        message:
            'College Admin and Inspection Team accounts can register plants for their assigned college.',
      );
    } else if (_loading) {
      body = const SizedBox(
        height: 400,

        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_loadError != null) {
      body = _errorCard();
    } else {
      body = AbsorbPointer(
        absorbing: _draftBusy,
        child: _form(useMobileStepper: phone),
      );
    }

    return PopScope(
      canPop: !_saving && !_draftBusy && (_allowPop || !_hasUnsavedChanges),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final discard = await _confirmDiscard();
        if (!mounted || !discard) return;
        setState(() => _allowPop = true);
        Navigator.of(this.context).pop();
      },
      child: AppNavigationGuard(
        canLeave: _confirmDiscard,
        child: AppShell(
          activeRoute: '/register-plant',
          mobileTitle: 'Register Plant',
          mobileSubtitle: 'Register and profile a new campus plant',
          userId: widget.userId,
          username: widget.username,
          role: widget.role,
          campusId: widget.campusId,
          collegeId: widget.collegeId,
          userName: widget.username,
          userRole: _roleLabel(widget.role),
          bottomAction:
              phone &&
                  !_loading &&
                  _loadError == null &&
                  _capabilities.canRegisterPlants
              ? _mobileActions(
                  stack: width < 360 || media.textScaler.scale(1) > 1.25,
                  compact: true,
                )
              : null,
          // Scanning is a separate task. Hiding the docked scanner here keeps it
          // from covering the form's primary action and avoids losing edits.
          showQrButton: false,
          child: SingleChildScrollView(
            controller: _formScroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: body,
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    final parsed = AppRole.fromValue(role);
    return parsed == AppRole.unknown ? role : parsed.label;
  }

  Widget _errorCard() {
    return _card(
      child: AppErrorState(
        title: 'Unable to prepare registration',
        message: userFacingError(
          _loadError ?? '',
          fallback:
              'The registration choices could not be loaded. Please try again.',
        ),
        technicalDetails: _loadError,
        onRetry: _loadData,
      ),
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _draftAction() => OutlinedButton.icon(
    key: const Key('save-registration-draft'),
    onPressed: _saving || _draftBusy ? null : _saveDraft,
    icon: _draftBusy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.save_outlined),
    label: Text(_draftBusy ? 'Saving draft…' : 'Save draft'),
  );

  Widget _registrationHeader() => _card(
    key: const Key('registration-page-header'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Add plant details, its planting location, and an optional photo.',
                ),
              ],
            );
            if (constraints.maxWidth < 650 ||
                MediaQuery.textScalerOf(context).scale(1) >= 1.4) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: AppSpacing.md),
                  _draftAction(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: heading),
                const SizedBox(width: AppSpacing.lg),
                _draftAction(),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _qrCard(),
      ],
    ),
  );

  Widget _form({required bool useMobileStepper}) {
    if (useMobileStepper) return _mobileForm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _registrationHeader(),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= AppBreakpoints.desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _plantSection(
                        includePhoto: false,
                        compactAssignment: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _locationSection(),
                          const SizedBox(height: AppSpacing.lg),
                          _photoSection(),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _plantSection(includePhoto: false, compactAssignment: true),
                    const SizedBox(height: AppSpacing.lg),
                    _locationSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _photoSection(),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4) {
                return SizedBox(
                  width: double.infinity,
                  child: _registerButton(),
                );
              }
              return Align(
                alignment: Alignment.centerRight,
                child: _registerButton(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mobileForm() {
    final media = MediaQuery.of(context);
    final compactHeight = media.size.height < 720;
    final sectionGap = compactHeight ? AppSpacing.md : AppSpacing.lg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RegistrationProgress(
          key: const Key('registration-step-header'),
          currentStep: _mobileStep,
          onStepSelected: _saving ? null : _goToStep,
          trailing: _draftAction(),
        ),
        SizedBox(height: sectionGap),
        if (_mobileStep == 0) ...[
          _qrCard(),
          SizedBox(height: sectionGap),
          _plantSection(includePhoto: false, compactAssignment: true),
        ] else if (_mobileStep == 1)
          _locationSection()
        else if (_mobileStep == 2)
          _photoSection()
        else
          _reviewSection(compact: compactHeight),
        SizedBox(height: sectionGap),
      ],
    );
  }

  Widget _mobileActions({required bool stack, required bool compact}) {
    final backButton = OutlinedButton.icon(
      onPressed: _saving ? null : _previousMobileStep,
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('Back'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppLayout.minimumTapTarget),
      ),
    );
    final primaryButton = _mobileStep < 3
        ? FilledButton.icon(
            onPressed: _saving ? null : _nextMobileStep,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              const [
                'Continue to location',
                'Continue to photo',
                'Review plant',
              ][_mobileStep],
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppLayout.minimumTapTarget),
            ),
          )
        : _registerButton();

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      child: stack
          ? Column(
              children: [
                SizedBox(width: double.infinity, child: primaryButton),
                if (_mobileStep > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(width: double.infinity, child: backButton),
                ],
              ],
            )
          : Row(
              children: [
                if (_mobileStep > 0) ...[
                  Expanded(child: backButton),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(flex: 2, child: primaryButton),
              ],
            ),
    );
  }

  Widget _registerButton() => FilledButton.icon(
    onPressed: _saving ? null : _registerPlant,
    icon: _saving
        ? const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onPrimary,
            ),
          )
        : const Icon(Icons.check_circle_outline_rounded),
    label: Text(_saving ? 'Registering…' : 'Register Plant'),
  );

  Widget _photoSection() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plant photo',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PlantImagePickerField(
          imageBytes: _selectedImageBytes,
          imageName: _selectedImage?.name,
          isPicking: _isPickingImage,
          onPick: _pickImage,
          onRemove: _removeImage,
        ),
      ],
    ),
  );

  Widget _validationBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: AppRadii.medium,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewSection({required bool compact}) {
    final theme = Theme.of(context);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Plant',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Confirm these details before creating the plant and QR record.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
          _reviewGroup('Plant', {
            'Managing campus': _campus ?? 'Not selected',
            'Managing college': _college ?? 'Not selected',
            'Common name': _commonName ?? 'Not selected',
            'Scientific name': _scientificNameController.text.trim().isEmpty
                ? 'Not available'
                : _scientificNameController.text.trim(),
            'Variety': _varietyController.text.trim().isEmpty
                ? 'Not provided'
                : _varietyController.text.trim(),
            'Growth stage': _growthStage ?? 'Not selected',
            'Health': _friendlyHealth(_healthStatus),
            'Date planted': _datePlanted == null
                ? 'Not provided'
                : _displayDate(_datePlanted!),
          }, compact: compact),
          Divider(height: compact ? AppSpacing.lg : AppSpacing.xl),
          _reviewGroup('Location', {
            'Planting location': _plantingCampusChoice == null
                ? 'Not selected'
                : _plantingCampusChoice == PlantingCampusDropdown.outside
                ? 'Outside campus'
                : _campuses
                      .firstWhere(
                        (c) => '${c['campus_id']}' == _plantingCampusChoice,
                      )['campus_name']
                      .toString(),
            'Town': _town ?? 'Not selected',
            'Barangay': _barangay ?? 'Not selected',
            'ZIP code': _zipCodeController.text.trim().isEmpty
                ? 'Not available'
                : _zipCodeController.text.trim(),
          }, compact: compact),
          Divider(height: compact ? AppSpacing.lg : AppSpacing.xl),
          Row(
            children: [
              Icon(
                _selectedImageBytes == null
                    ? Icons.image_not_supported_outlined
                    : Icons.image_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _selectedImageBytes == null
                      ? 'No plant photo added'
                      : 'Plant photo ready to upload',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewGroup(
    String title,
    Map<String, String> values, {
    required bool compact,
  }) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackRows = constraints.maxWidth < 300 || textScale > 1.3;
        final labelWidth = (constraints.maxWidth * 0.34)
            .clamp(92.0, 124.0)
            .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            ...values.entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: compact ? AppSpacing.xs : AppSpacing.sm,
                ),
                child: stackRows
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            entry.value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: labelWidth,
                            child: Text(
                              entry.key,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // QR INFORMATION
  // ============================================================

  Widget _qrCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.medium,
        border: AppBorders.subtle,
      ),
      child: Row(
        children: [
          Icon(
            _usingExistingQr ? Icons.qr_code_scanner : Icons.qr_code_2,

            color: AppColors.primary,
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Text(
              _usingExistingQr
                  ? 'Using scanned QR: ${widget.existingQrTag?['qr_code_string']}'
                  : 'A new QR will be generated automatically when registration succeeds.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PLANT SECTION
  // ============================================================

  Widget _plantSection({
    bool includePhoto = true,
    bool compactAssignment = false,
  }) {
    final theme = Theme.of(context);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Plant Classification',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_registrationScopeLocked)
            LockedPlantAssignment(
              compact: compactAssignment,
              campus: _campus ?? 'Campus not assigned',
              college: _college ?? 'College not assigned',
            )
          else
            _twoFields(
              AppSearchableDropdown(
                label: 'Managing campus',
                value: _campus,
                items: _campusNames,
                enabled: !_registrationScopeLocked,
                onChanged: _selectCampus,
              ),
              AppSearchableDropdown(
                label: 'Managing college',
                value: _college,
                items: _filteredCollegeNames,
                enabled: _selectedCampusId != null && !_registrationScopeLocked,
                onChanged: _selectCollege,
              ),
            ),

          if (_showPlantErrors &&
              (_missingPlantFields.isNotEmpty ||
                  _plantValidationError != null)) ...[
            const SizedBox(height: AppSpacing.lg),
            _validationBanner(
              _missingPlantFields.isNotEmpty
                  ? 'Please fill out: ${_missingPlantFields.join(', ')}.'
                  : _plantValidationError!,
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          _twoFields(
            AppSearchableDropdown(
              label: 'Plant Type',
              isRequired: true,
              errorText: _showPlantErrors && _plantType == null
                  ? 'Please select a plant type.'
                  : null,

              value: _plantType,

              items: _plantTypes,

              onChanged: _selectPlantType,
            ),

            AppSearchableDropdown(
              label: 'Common Name',
              isRequired: true,
              errorText: _showPlantErrors && _selectedClassificationId == null
                  ? 'Please select a common name.'
                  : null,

              value: _commonName,

              items: _filteredCommonNames,

              enabled: _plantType != null,

              onChanged: _selectCommonName,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _twoFields(
            AppTextField(
              label: 'Variety (Optional)',
              textCapitalization: TextCapitalization.words,
              inputFormatters: const [WordCapitalizationFormatter()],
              controller: _varietyController,
              maxLength: _maxVarietyLength,
            ),

            AppTextField(
              label: 'Scientific Name',

              controller: _scientificNameController,

              readOnly: true,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _twoFields(
            AppSearchableDropdown(
              label: 'Growth Stage',
              isRequired: true,
              errorText: _showPlantErrors && _selectedGrowthStatusId == null
                  ? 'Please select a growth stage.'
                  : null,

              value: _growthStage,

              items: _growthStageNames,

              onChanged: _selectGrowthStage,
            ),

            AppSearchableDropdown(
              label: 'Health Status',
              isRequired: true,
              errorText: _showPlantErrors && _selectedHealthStatusId == null
                  ? 'Please select a health status.'
                  : null,

              value: _healthStatus,

              items: _healthStatusNames,

              onChanged: _selectHealthStatus,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _twoFields(
            _dateField(),

            AppTextField(
              label: 'Tree Planter (Optional)',
              textCapitalization: TextCapitalization.words,
              inputFormatters: const [WordCapitalizationFormatter()],

              controller: _planterController,

              maxLength: _maxPlanterLength,
            ),
          ),

          if (includePhoto) ...[
            const SizedBox(height: AppSpacing.lg),
            PlantImagePickerField(
              imageBytes: _selectedImageBytes,
              imageName: _selectedImage?.name,
              isPicking: _isPickingImage,
              onPick: _pickImage,
              onRemove: _removeImage,
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION SECTION
  // Campus -> College
  // Town -> Barangay -> ZIP
  // ============================================================

  Widget _locationSection() {
    final theme = Theme.of(context);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Location',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),

          if (_showLocationErrors && _missingLocationFields.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _validationBanner(
              'Please fill out: ${_missingLocationFields.join(', ')}.',
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          PlantingCampusDropdown(
            showHelperText: false,
            isRequired: true,
            errorText: _showLocationErrors && _plantingCampusChoice == null
                ? 'Please select a planting campus or Outside campus.'
                : null,
            campuses: _campuses,
            value: _plantingCampusChoice,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _plantingCampusChoice = value;
                    _hasUnsavedChanges = true;
                  }),
          ),

          const SizedBox(height: AppSpacing.lg),

          // TOWN FIRST
          AppSearchableDropdown(
            label: 'Town',
            isRequired: true,
            errorText: _showLocationErrors && _selectedTownId == null
                ? 'Please select a town.'
                : null,

            value: _town,

            items: _townNames,

            onChanged: _selectTown,
          ),

          const SizedBox(height: AppSpacing.lg),

          // BARANGAY FILTERED BY TOWN
          AppSearchableDropdown(
            key: ValueKey('barangay-town-$_selectedTownId'),
            label: 'Barangay',
            isRequired: true,
            errorText: _showLocationErrors && _selectedBarangayId == null
                ? 'Please select a barangay.'
                : null,

            value: _barangay,

            items: _filteredBarangayNames,

            enabled: _selectedTownId != null,

            onChanged: _selectBarangay,
          ),

          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: 180,

            child: AppTextField(
              label: 'Zip Code',

              controller: _zipCodeController,

              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE FIELD
  // ============================================================

  Widget _dateField() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'Date Planted *',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: _showPlantErrors && _datePlanted == null
                  ? 'Please select the date planted.'
                  : null,
              errorMaxLines: 3,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _datePlanted == null
                          ? 'Select date'
                          : _displayDate(_datePlanted!),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LAYOUT HELPERS
  // ============================================================

  Widget _twoFields(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4) {
          return Column(
            children: [
              first,
              const SizedBox(height: AppSpacing.lg),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Expanded(child: first),

            const SizedBox(width: AppSpacing.lg),

            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _card({Key? key, required Widget child}) {
    return AppCard(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _titleCase(String text) {
    if (text.isEmpty) {
      return '';
    }

    return text
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _displayDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _friendlyHealth(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'alive':
      case 'healthy':
        return 'Healthy';
      case 'dying':
      case 'at risk':
        return 'Needs attention';
      case 'dead':
        return 'Dead';
      default:
        return value ?? 'Not selected';
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) {
      return;
    }

    final width = MediaQuery.sizeOf(context).width;
    final phone = AppBreakpoints.isPhone(width);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: phone ? null : 560,
          margin: phone
              ? const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                )
              : null,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
          showCloseIcon: true,
          closeIconColor: AppColors.onPrimary,
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: AppColors.onPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text)),
            ],
          ),
          backgroundColor: error ? AppColors.danger : AppColors.primary,
        ),
      );
  }
}
