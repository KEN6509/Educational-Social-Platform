import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/src';
const _feedbackFacade = 'lib/src/core/widgets/app_feedback.dart';

Iterable<File> _productionDartFiles() => Directory(_sourceRoot)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

String _portablePath(File file) => file.path.replaceAll('\\', '/');

bool _containsRawVisibleError(String source) {
  final patterns = [
    RegExp(
      r'''(?:Error:|Unable to [^'"\r\n]+:)\s*\$\{?(?:e|error|exception)\b''',
    ),
    RegExp(
      r'\b(?:AppFeedback\.(?:show|showSuccess|showWarning|showError)|Text)\s*\([^;]*\b(?:e|error|exception)\.toString\s*\(',
    ),
    RegExp(
      r'\b(?:AppFeedback\.(?:show|showSuccess|showWarning|showError)|Text)\s*\([^;]*\$\{?(?:e|error|exception)\b',
    ),
  ];
  return patterns.any((pattern) => pattern.hasMatch(source));
}

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

    for (final file in _productionDartFiles()) {
      final source = file.readAsStringSync();
      if (_containsRawVisibleError(source)) {
        violations.add(_portablePath(file));
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('raw-error guard recognizes direct exception display sinks', () {
    expect(
      _containsRawVisibleError(
        'AppFeedback.showError(context, error.toString());',
      ),
      isTrue,
    );
    expect(_containsRawVisibleError('Text(exception.toString())'), isTrue);
    expect(
      _containsRawVisibleError(
        r"AppFeedback.show(context, message: '$error');",
      ),
      isTrue,
    );
  });
}
