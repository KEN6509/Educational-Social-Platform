import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/src';
const _feedbackFacade = 'lib/src/core/widgets/app_feedback.dart';

Iterable<File> _productionDartFiles() => Directory(_sourceRoot)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

String _portablePath(File file) => file.path.replaceAll('\\', '/');

void main() {
  test('only AppFeedback constructs temporary message surfaces', () {
    final violations = <String>[];
    final directMessenger = RegExp(r'\bScaffoldMessenger\.of\s*\(');
    final directSnackBar = RegExp(r'\bSnackBar\s*\(');

    for (final file in _productionDartFiles()) {
      final path = _portablePath(file);
      if (path == _feedbackFacade) continue;
      final source = file.readAsStringSync();
      if (directMessenger.hasMatch(source) || directSnackBar.hasMatch(source)) {
        violations.add(path);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('visible failure messages do not interpolate caught exceptions', () {
    final violations = <String>[];
    final rawVisibleError = RegExp(
      r'''(?:Error:|Unable to [^'"\r\n]+:)\s*\$\{?(?:e|error|exception)\b''',
    );

    for (final file in _productionDartFiles()) {
      final source = file.readAsStringSync();
      if (rawVisibleError.hasMatch(source)) {
        violations.add(_portablePath(file));
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
