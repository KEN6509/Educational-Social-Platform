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

  void trackInitialRefresh(Future<void> refresh) {
    if (_disposed) return;
    if (_cycleCompleter != null) {
      throw StateError('A refresh cycle is already active.');
    }

    final cycle = Completer<void>();
    _cycleCompleter = cycle;
    unawaited(_drain(cycle, initialRefresh: refresh));
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

  Future<void> _drain(
    Completer<void> cycle, {
    Future<void>? initialRefresh,
  }) async {
    try {
      if (initialRefresh != null) {
        await _runRefresh(() => initialRefresh);
      }
      while (_pending && !_disposed) {
        _pending = false;
        await _runRefresh(_refresh);
      }
    } finally {
      if (identical(_cycleCompleter, cycle)) {
        _cycleCompleter = null;
      }
      if (!cycle.isCompleted) cycle.complete();
    }
  }

  Future<void> _runRefresh(ChatRefreshTask refresh) async {
    try {
      await refresh();
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
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
