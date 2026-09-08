import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/domain/content_moderation.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/content_moderation_scope.dart';

class FakeGateway implements ContentModerationGateway {
  @override
  Future<ContentModerationResult> moderateComment(String commentId) =>
      throw UnimplementedError();

  @override
  Future<ContentModerationResult> moderatePost(String postId) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('exposes the same gateway to descendants', (tester) async {
    final gateway = FakeGateway();
    late ContentModerationGateway resolved;
    await tester.pumpWidget(ContentModerationScope(
      gateway: gateway,
      child: Builder(builder: (context) {
        resolved = ContentModerationScope.of(context);
        return const SizedBox();
      }),
    ));
    expect(identical(resolved, gateway), isTrue);
  });
}
