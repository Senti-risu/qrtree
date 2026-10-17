import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_role.dart';
import '../../services/qr_print_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_navigation_guard.dart';
import '../../widgets/registration_progress.dart';
import '../../widgets/forms/app_searchable_dropdown.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/forms/planting_campus_dropdown.dart';
import '../../models/plant_record_lock.dart';
import '../../widgets/dead_plant_lock.dart';
import '../../widgets/forms/locked_plant_assignment.dart';
import 'plant_service.dart';
import 'registration widgets/plant_image_picker_field.dart';

class RegisterPlantScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String role;
  final int? campusId;
  final int? collegeId;
  final Map<String, dynamic>? existingQrTag;

  const RegisterPlantScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    this.campusId,
    this.collegeId,
    this.existingQrTag,
  });

  @override
  State<RegisterPlantScreen> createState() => _RegisterPlantScreenState();
}

class _RegisterPlantScreenState extends State<RegisterPlantScreen> {
  final PlantService _plantService = PlantService();
  final QrPrintService _qrPrintService = QrPrintService();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _formScroll = ScrollController();

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
        _classifications = results[0];
        _campuses = results[1];
        _colleges = results[2];
        _towns = results[3];
        _barangays = results[4];
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
    if (value == null || _plantType == null) {
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
    if (value == null || _selectedCampusId == null) {
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
    if (value == null || _selectedTownId == null) {
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

  bool _validatePlantStep({bool announce = true}) {
    final missing = <String>[
      if (_selectedCampusId == null || _selectedCollegeId == null)
        'managing campus and college',
      if (_selectedClassificationId == null) 'plant type and common name',
      if (_selectedGrowthStatusId == null) 'growth stage',
      if (_selectedHealthStatusId == null) 'health status',
    ];
    final varietyLength = _varietyController.text.trim().runes.length;
    final planterLength = _planterController.text.trim().runes.length;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    String? validationError;
    if (missing.isNotEmpty) {
      validationError = 'Complete the highlighted plant information.';
    } else if (varietyLength > _maxVarietyLength) {
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
      _showPlantErrors = validationError != null;
    });
    if (validationError != null && announce) {
      _message(validationError, error: true);
    }
    return validationError == null;
  }

  bool _validateLocationStep({bool announce = true}) {
    final missing = <String>[
      if (_plantingCampusChoice == null) 'planting campus or Outside campus',
      if (_selectedTownId == null) 'town',
      if (_selectedBarangayId == null) 'barangay',
    ];
    setState(() => _showLocationErrors = missing.isNotEmpty);
    if (missing.isNotEmpty && announce) {
      _message('Complete the highlighted location information.', error: true);
    }
    return missing.isEmpty;
  }

  void _nextMobileStep() {
    if (_mobileStep == 0 && !_validatePlantStep()) return;
    if (_mobileStep == 1 && !_validateLocationStep()) return;
    _goToStep((_mobileStep + 1).clamp(0, 3).toInt());
  }

  void _previousMobileStep() {
    _goToStep((_mobileStep - 1).clamp(0, 3).toInt());
  }

  void _goToStep(int step) {
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
    if (_saving) {
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
      setState(() => _mobileStep = plantValid ? 1 : 0);
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
            variety: _emptyToNull(_varietyController.text),
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

        variety: _emptyToNull(_varietyController.text),

        datePlanted: _datePlanted == null ? null : _formatDate(_datePlanted!),

        treePlanter: _emptyToNull(_planterController.text),

        photoUrl: photoUrl,
      );
      registrationCompleted = true;

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
    if (_saving) return false;
    if (!_hasUnsavedChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard this registration?'),
            content: const Text(
              'The plant information you entered has not been saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final phone = width < AppBreakpoints.desktop;
    final desktop = width >= AppBreakpoints.desktop;

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
      body = _form(useMobileStepper: phone, showHeader: desktop);
    }

    return PopScope(
      canPop: !_saving && (_allowPop || !_hasUnsavedChanges),
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
          onRefresh: _saving
              ? null
              : () async {
                  if (await _confirmDiscard() && mounted) _loadData();
                },
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

  Widget _form({required bool useMobileStepper, required bool showHeader}) {
    if (useMobileStepper) return _mobileForm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          const AppPageHeader(
            title: 'Registration',
            subtitle: 'Register and profile a new campus plant',
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        _qrCard(),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= AppBreakpoints.desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _plantSection()),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: _locationSection()),
                  ],
                )
              : Column(
                  children: [
                    _plantSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _locationSection(),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 200, height: 52, child: _registerButton()),
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
          currentStep: _mobileStep,
          onStepSelected: _saving ? null : _goToStep,
        ),
        SizedBox(height: sectionGap),
        if (_mobileStep == 0) ...[
          _qrCard(),
          SizedBox(height: sectionGap),
          _plantSection(includePhoto: false),
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
        Text('Plant photo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Optional. Add a clear photo to help your team identify this plant.',
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
    return _card(
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
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PLANT SECTION
  // ============================================================

  Widget _plantSection({bool includePhoto = true}) {
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

          if (_showPlantErrors) ...[
            const SizedBox(height: AppSpacing.lg),
            _validationBanner(
              _plantValidationError ??
                  'Select the plant type and common name, growth stage, and health status.',
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          _twoFields(
            AppSearchableDropdown(
              label: 'Plant Type',

              value: _plantType,

              items: _plantTypes,

              onChanged: _selectPlantType,
            ),

            AppSearchableDropdown(
              label: 'Common Name',

              value: _commonName,

              items: _filteredCommonNames,

              enabled: _plantType != null,

              onChanged: _selectCommonName,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _twoFields(
            AppTextField(
              label: 'Variety',
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

              value: _growthStage,

              items: _growthStageNames,

              onChanged: _selectGrowthStage,
            ),

            AppSearchableDropdown(
              label: 'Health Status',

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
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Where this plant is physically planted.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),

          if (_showLocationErrors) ...[
            const SizedBox(height: AppSpacing.lg),
            _validationBanner(
              'Select a planting campus or Outside campus, then town and barangay.',
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          PlantingCampusDropdown(
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

            value: _town,

            items: _townNames,

            onChanged: _selectTown,
          ),

          const SizedBox(height: AppSpacing.lg),

          // BARANGAY FILTERED BY TOWN
          AppSearchableDropdown(
            label: 'Barangay',

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
          'Date Planted',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(),
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

  Widget _card({required Widget child}) {
    final width = MediaQuery.sizeOf(context).width;
    return AppCard(
      width: double.infinity,
      padding: EdgeInsets.all(
        AppBreakpoints.isPhone(width) ? AppSpacing.lg : AppSpacing.xl,
      ),
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
