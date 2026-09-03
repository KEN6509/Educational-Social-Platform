import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';

enum SosParentAction { acknowledge, resolve, none }

sealed class SosLifecycleState {
  const SosLifecycleState();

  bool get trackingAllowed;

  SosParentAction actionFor({
    required bool hasCurrentParentAcknowledged,
  });
}

base class OpenSosState extends SosLifecycleState {
  const OpenSosState();

  @override
  bool get trackingAllowed => true;

  @override
  SosParentAction actionFor({
    required bool hasCurrentParentAcknowledged,
  }) =>
      hasCurrentParentAcknowledged
          ? SosParentAction.resolve
          : SosParentAction.acknowledge;
}

final class AcknowledgedSosState extends OpenSosState {
  const AcknowledgedSosState();
}

final class ResolvedSosState extends SosLifecycleState {
  const ResolvedSosState();

  @override
  bool get trackingAllowed => false;

  @override
  SosParentAction actionFor({
    required bool hasCurrentParentAcknowledged,
  }) =>
      SosParentAction.none;
}

SosLifecycleState sosLifecycleStateFor(SosStatus status) => switch (status) {
      SosStatus.open => const OpenSosState(),
      SosStatus.acknowledged => const AcknowledgedSosState(),
      SosStatus.resolved => const ResolvedSosState(),
    };
