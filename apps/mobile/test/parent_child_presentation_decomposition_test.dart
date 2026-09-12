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

  test('Family Links preserves its existing approved text colours', () {
    final page = File(
      'lib/src/features/parent_child/presentation/family_links_page.dart',
    ).readAsStringSync();

    expect(page, contains('const _text = Color(0xFF0D2344);'));
    expect(page, contains('const _secondary = Color(0xFF7A879B);'));
  });

  test('Safety Records separates list widgets and Check-In detail route', () {
    final page = File(
      'lib/src/features/parent_child/presentation/safety_records_page.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/src/features/parent_child/presentation/safety_record_widgets.dart',
    );
    final detail = File(
      'lib/src/features/parent_child/presentation/check_in_detail_page.dart',
    );

    expect(page, contains("part 'safety_record_widgets.dart';"));
    expect(page, contains("import 'check_in_detail_page.dart';"));
    expect(widgets.existsSync(), isTrue);
    expect(detail.existsSync(), isTrue);
    expect(page, isNot(contains('class CheckInDetailPage')));
    final detailSource = detail.readAsStringSync();
    final widgetSource = widgets.readAsStringSync();
    expect(detailSource, contains('class CheckInDetailPage'));
    expect(page, isNot(contains('class _RecordsMessage')));
    expect(widgetSource, contains('class _RecordTile'));
    expect(widgetSource, contains('class _RecordsMessage'));
  });

  test('Check-In detail does not import its parent records page', () {
    final page = File(
      'lib/src/features/parent_child/presentation/safety_records_page.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/src/features/parent_child/presentation/check_in_detail_page.dart',
    ).readAsStringSync();
    final formatters = File(
      'lib/src/features/parent_child/presentation/supervision_formatters.dart',
    );

    expect(detail, isNot(contains("import 'safety_records_page.dart';")));
    expect(detail, contains("import 'supervision_formatters.dart';"));
    expect(page, contains("import 'supervision_formatters.dart';"));
    expect(formatters.existsSync(), isTrue);
  });

  test('SOS page keeps workflow state and delegates presentation widgets', () {
    final page = File(
      'lib/src/features/parent_child/presentation/sos_page.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/src/features/parent_child/presentation/sos_widgets.dart',
    );

    expect(page, contains("part 'sos_widgets.dart';"));
    expect(widgets.existsSync(), isTrue);
    final widgetSource = widgets.readAsStringSync();
    expect(page, contains('class _SosPageState'));
    expect(page, isNot(contains('class _BottomSosAction')));
    expect(widgetSource, contains('class _BottomSosAction'));
    expect(widgetSource, contains('class _TimelineCard'));
    expect(widgetSource, contains('class _TimelineEventRow'));
    expect(widgetSource, contains('class _DetailCard'));
  });

  test('parent-child presentation uses the shared feedback facade', () {
    final directory = Directory(
      'lib/src/features/parent_child/presentation',
    );
    final offenders = <String>[];

    for (final entity in directory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('ScaffoldMessenger.of(') ||
          source.contains('SnackBar(')) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
