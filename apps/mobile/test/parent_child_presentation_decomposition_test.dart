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

  test('Family Links page keeps coordination and delegates private widgets',
      () {
    final page = File(
      'lib/src/features/parent_child/presentation/family_links_page.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/src/features/parent_child/presentation/family_links_widgets.dart',
    );

    expect(page, contains("part 'family_links_widgets.dart';"));
    expect(widgets.existsSync(), isTrue);
    final widgetSource = widgets.readAsStringSync();
    expect(widgetSource, contains("part of 'family_links_page.dart';"));
    expect(page, contains('class _FamilyLinksPageState'));
    expect(page, isNot(contains('class _PendingLinkRow')));
    expect(widgetSource, contains('class _PendingLinkRow'));
    expect(widgetSource, contains('class _ActiveLinkRow'));
    expect(widgetSource, contains('class _ChildScreenTimeRow'));
  });
}
