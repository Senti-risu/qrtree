import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source and test files use paths without spaces', () {
    for (final root in ['lib', 'test']) {
      for (final entry in Directory(root).listSync(recursive: true)) {
        final relative = entry.path.replaceAll('\\', '/');
        expect(relative.contains(' '), isFalse, reason: relative);
      }
    }
  });

  test('local Dart imports still resolve after file organization', () {
    final imports = RegExp(r'''(?:import|export|part)\s+['"]([^'"]+)['"]''');
    for (final root in ['lib', 'test']) {
      for (final file
          in Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        for (final match in imports.allMatches(file.readAsStringSync())) {
          final uri = match[1]!;
          File? target;
          if (uri.startsWith('package:flutter_application_1/')) {
            target = File(
              'lib/${uri.substring('package:flutter_application_1/'.length)}',
            );
          } else if (!Uri.parse(uri).hasScheme) {
            target = File.fromUri(file.absolute.parent.uri.resolve(uri));
          }
          if (target != null) {
            expect(target.existsSync(), isTrue, reason: '${file.path}: $uri');
          }
        }
      }
    }
  });
}
