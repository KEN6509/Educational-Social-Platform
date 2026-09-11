import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ParentChildPage owns one coordinated dashboard refresh path', () {
    final source = File(
      'lib/src/features/parent_child/presentation/parent_child_page.dart',
    ).readAsStringSync();

    expect(source, contains('late final AsyncRefreshCoordinator'));
    expect(source, contains('.trackInitialRefresh('));
    expect(source, contains('onChange: _refreshCoordinator.schedule'));
    expect(source, contains('Future<void> _performRefresh()'));
    expect(source, contains('_refreshCoordinator.dispose();'));
    expect(source, isNot(contains('Timer? _refreshDebounce')));
    expect(
      source.indexOf('_refreshCoordinator = AsyncRefreshCoordinator('),
      lessThan(source.indexOf('_dashboardFuture =')),
    );
  });
}
