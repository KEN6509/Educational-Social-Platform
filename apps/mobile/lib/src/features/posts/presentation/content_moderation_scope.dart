import 'package:flutter/widgets.dart';

import '../domain/content_moderation.dart';

class ContentModerationScope extends InheritedWidget {
  const ContentModerationScope({
    required this.gateway,
    required super.child,
    super.key,
  });

  final ContentModerationGateway gateway;

  static ContentModerationGateway of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ContentModerationScope>();
    assert(
        scope != null, 'ContentModerationScope is missing above this context.');
    return scope!.gateway;
  }

  @override
  bool updateShouldNotify(ContentModerationScope oldWidget) =>
      gateway != oldWidget.gateway;
}
