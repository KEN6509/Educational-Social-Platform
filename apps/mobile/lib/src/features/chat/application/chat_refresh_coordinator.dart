import 'dart:async';

typedef ChatRefreshTask = Future<void> Function();
typedef ChatRefreshErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

final class ChatRefreshCoordinator {
  ChatRefreshCoordinator({
    required ChatRefreshTask refresh,
    this.debounce = const Duration(milliseconds: 120),
    ChatRefreshErrorHandler? onError,
  })  : _refresh = refresh,
        _onError = onError;

  final ChatRefreshTask _refresh;
  final ChatRefreshErrorHandler? _onError;
  final Duration debounce;

  Timer? _timer;
  Completer<void>? _cycleCompleter;
  bool _pending = false;
  bool _disposed = false;

  void schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(refreshNow());
    });
  }

  Future<void> refreshNow() {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    _pending = true;

    final activeCycle = _cycleCompleter;
    if (activeCycle != null) return activeCycle.future;

    final cycle = Completer<void>();
    _cycleCompleter = cycle;
    unawaited(_drain(cycle));
    return cycle.future;
  }

  Future<void> _drain(Completer<void> cycle) async {
    try {
      while (_pending && !_disposed) {
        _pending = false;
        try {
          await _refresh();
        } catch (error, stackTrace) {
          _onError?.call(error, stackTrace);
        }
      }
    } finally {
      if (identical(_cycleCompleter, cycle)) {
        _cycleCompleter = null;
      }
      if (!cycle.isCompleted) cycle.complete();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending = false;
    _timer?.cancel();
    _timer = null;
  }
}
