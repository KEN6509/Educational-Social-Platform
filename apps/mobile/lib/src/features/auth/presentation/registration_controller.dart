import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/auth_gateway.dart';
import '../domain/pending_registration_store.dart';
import '../domain/registration_request.dart';

enum RegistrationPhase {
  editing,
  submitting,
  awaitingOtp,
  verifyingOtp,
  resendingOtp,
}

final class RegistrationState {
  const RegistrationState({
    this.phase = RegistrationPhase.editing,
    this.pendingEmail,
    this.resendSecondsRemaining = 0,
    this.message,
    this.isSuccessMessage = false,
  });

  final RegistrationPhase phase;
  final String? pendingEmail;
  final int resendSecondsRemaining;
  final String? message;
  final bool isSuccessMessage;

  bool get showsOtp => switch (phase) {
        RegistrationPhase.awaitingOtp ||
        RegistrationPhase.verifyingOtp ||
        RegistrationPhase.resendingOtp =>
          true,
        _ => false,
      };

  bool get isBusy => switch (phase) {
        RegistrationPhase.submitting ||
        RegistrationPhase.verifyingOtp ||
        RegistrationPhase.resendingOtp =>
          true,
        _ => false,
      };

  RegistrationState copyWith({
    RegistrationPhase? phase,
    Object? pendingEmail = _unset,
    int? resendSecondsRemaining,
    Object? message = _unset,
    bool? isSuccessMessage,
  }) {
    return RegistrationState(
      phase: phase ?? this.phase,
      pendingEmail: identical(pendingEmail, _unset)
          ? this.pendingEmail
          : pendingEmail as String?,
      resendSecondsRemaining:
          resendSecondsRemaining ?? this.resendSecondsRemaining,
      message: identical(message, _unset) ? this.message : message as String?,
      isSuccessMessage: isSuccessMessage ?? this.isSuccessMessage,
    );
  }
}

const _unset = Object();

final class RegistrationController extends ChangeNotifier {
  RegistrationController({
    required AuthGateway authGateway,
    required PendingRegistrationStore pendingRegistrationStore,
    this.countdownDuration = const Duration(seconds: 60),
  })  : _authGateway = authGateway,
        _pendingRegistrationStore = pendingRegistrationStore;

  final AuthGateway _authGateway;
  final PendingRegistrationStore _pendingRegistrationStore;
  final Duration countdownDuration;

  RegistrationState _state = const RegistrationState();
  Timer? _countdownTimer;
  bool _disposed = false;

  RegistrationState get state => _state;

  Future<void> restore() async {
    final email = await _pendingRegistrationStore.readEmail();
    if (_disposed || email == null) return;

    _setState(_state.copyWith(
      phase: RegistrationPhase.awaitingOtp,
      pendingEmail: email,
      message: null,
      isSuccessMessage: false,
    ));
    _startCountdown();
  }

  Future<RegistrationOutcome?> register(RegistrationRequest request) async {
    if (_state.isBusy) return null;

    final normalizedRequest = RegistrationRequest(
      name: request.name.trim(),
      email: _normalizeEmail(request.email),
      password: request.password,
      termsVersion: request.termsVersion,
      privacyVersion: request.privacyVersion,
      consentAcceptedAt: request.consentAcceptedAt.toUtc(),
    );
    _setState(_state.copyWith(
      phase: RegistrationPhase.submitting,
      message: null,
      isSuccessMessage: false,
    ));

    try {
      final outcome = await _authGateway.register(normalizedRequest);
      if (outcome == RegistrationOutcome.confirmationRequired) {
        await _pendingRegistrationStore.saveEmail(normalizedRequest.email);
        if (_disposed) return outcome;
        _setState(_state.copyWith(
          phase: RegistrationPhase.awaitingOtp,
          pendingEmail: normalizedRequest.email,
          message: 'Check your email for a verification code.',
          isSuccessMessage: true,
        ));
        _startCountdown();
      } else {
        await _pendingRegistrationStore.clear();
        _cancelCountdown();
        _setState(_state.copyWith(
          phase: RegistrationPhase.editing,
          pendingEmail: null,
        ));
      }
      return outcome;
    } on AuthFailure catch (error) {
      _setState(_state.copyWith(
        phase: RegistrationPhase.editing,
        message: error.message,
        isSuccessMessage: false,
      ));
      return null;
    } catch (_) {
      _setState(_state.copyWith(
        phase: RegistrationPhase.editing,
        message: 'Something went wrong. Please try again.',
        isSuccessMessage: false,
      ));
      return null;
    }
  }

  Future<void> verifyOtp(String token) async {
    final email = _state.pendingEmail;
    if (email == null || _state.isBusy) return;
    final normalizedToken = token.trim();
    if (normalizedToken.length != 6) return;

    _setState(_state.copyWith(
      phase: RegistrationPhase.verifyingOtp,
      message: null,
      isSuccessMessage: false,
    ));
    try {
      await _authGateway.verifyRegistrationOtp(
        email: email,
        token: normalizedToken,
      );
      await _pendingRegistrationStore.clear();
      _cancelCountdown();
      _setState(_state.copyWith(
        phase: RegistrationPhase.editing,
        pendingEmail: null,
        message: 'Email verified successfully.',
        isSuccessMessage: true,
      ));
    } on AuthFailure catch (error) {
      _setState(_state.copyWith(
        phase: RegistrationPhase.awaitingOtp,
        message: error.message,
        isSuccessMessage: false,
      ));
    } catch (_) {
      _setState(_state.copyWith(
        phase: RegistrationPhase.awaitingOtp,
        message: 'Something went wrong. Please try again.',
        isSuccessMessage: false,
      ));
    }
  }

  Future<void> resendOtp() async {
    final email = _state.pendingEmail;
    if (email == null || _state.isBusy || _state.resendSecondsRemaining > 0) {
      return;
    }

    _setState(_state.copyWith(
      phase: RegistrationPhase.resendingOtp,
      message: null,
      isSuccessMessage: false,
    ));
    try {
      await _authGateway.resendRegistrationOtp(email: email);
      _setState(_state.copyWith(
        phase: RegistrationPhase.awaitingOtp,
        message: 'A new verification code was sent.',
        isSuccessMessage: true,
      ));
      _startCountdown();
    } on AuthFailure catch (error) {
      _setState(_state.copyWith(
        phase: RegistrationPhase.awaitingOtp,
        message: error.message,
        isSuccessMessage: false,
      ));
    } catch (_) {
      _setState(_state.copyWith(
        phase: RegistrationPhase.awaitingOtp,
        message: 'Something went wrong. Please try again.',
        isSuccessMessage: false,
      ));
    }
  }

  Future<void> resumeUnconfirmedLogin(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    await _pendingRegistrationStore.saveEmail(normalizedEmail);
    if (_disposed) return;
    _setState(_state.copyWith(
      phase: RegistrationPhase.awaitingOtp,
      pendingEmail: normalizedEmail,
      message: 'Verify your email before logging in.',
      isSuccessMessage: false,
    ));
    _startCountdown();
  }

  Future<void> backToForm() async {
    await _pendingRegistrationStore.clear();
    _cancelCountdown();
    _setState(_state.copyWith(
      phase: RegistrationPhase.editing,
      pendingEmail: null,
      resendSecondsRemaining: 0,
      message: null,
      isSuccessMessage: false,
    ));
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCountdown();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _setState(
        _state.copyWith(resendSecondsRemaining: countdownDuration.inSeconds));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      final remaining = _state.resendSecondsRemaining;
      if (remaining <= 1) {
        _countdownTimer?.cancel();
        _setState(_state.copyWith(resendSecondsRemaining: 0));
      } else {
        _setState(_state.copyWith(resendSecondsRemaining: remaining - 1));
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _setState(RegistrationState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();
}
