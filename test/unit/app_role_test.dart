import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/app_role.dart';

void main() {
  group('AppRole', () {
    test('normalizes persisted and display-style role values', () {
      expect(AppRole.fromValue('college_admin'), AppRole.collegeAdmin);
      expect(AppRole.fromValue(' College Admin '), AppRole.collegeAdmin);
      expect(AppRole.fromValue('inspection-team'), AppRole.inspectionTeam);
      expect(AppRole.fromValue('unsupported'), AppRole.unknown);
      expect(AppRole.fromValue(null), AppRole.unknown);
    });
  });

  group('RoleCapabilities', () {
    test(
      'allows scoped registration for College Admin and Inspection Team; archive stays College Admin only',
      () {
        for (final role in AppRole.values) {
          final capabilities = RoleCapabilities(role);
          final expected = role == AppRole.collegeAdmin;

          final canRegister = expected || role == AppRole.inspectionTeam;
          expect(
            capabilities.canRegisterPlants,
            canRegister,
            reason: role.value,
          );
          expect(capabilities.canArchivePlants, expected, reason: role.value);
          expect(capabilities.canRestorePlants, expected, reason: role.value);
          expect(
            capabilities.locksRegistrationScope,
            canRegister,
            reason: role.value,
          );
        }
      },
    );

    test('allows only Inspection Team accounts to inspect plants', () {
      for (final role in AppRole.values) {
        expect(
          RoleCapabilities(role).canInspectPlants,
          role == AppRole.inspectionTeam,
          reason: role.value,
        );
      }
    });

    test('allows every recognized staff role to scan QR codes', () {
      for (final role in AppRole.values) {
        expect(
          RoleCapabilities(role).canScanQr,
          role != AppRole.unknown,
          reason: role.value,
        );
      }
    });

    test('models campus and college data scopes', () {
      expect(
        const RoleCapabilities(AppRole.universityAdmin).hasAssignedCampusScope,
        isFalse,
      );
      expect(
        const RoleCapabilities(AppRole.campusAdmin).hasAssignedCampusScope,
        isTrue,
      );
      expect(
        const RoleCapabilities(AppRole.campusAdmin).hasAssignedCollegeScope,
        isFalse,
      );
      expect(
        const RoleCapabilities(AppRole.collegeAdmin).hasAssignedCollegeScope,
        isTrue,
      );
      expect(
        const RoleCapabilities(AppRole.inspectionTeam).hasAssignedCollegeScope,
        isTrue,
      );
    });
  });
}
