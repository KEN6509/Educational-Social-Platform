import 'package:flutter/material.dart';

import '../../parent_child/presentation/sos_tracking_scope.dart';
import '../../shell/presentation/main_shell.dart';
import '../domain/auth_gateway.dart';
import '../domain/pending_registration_store.dart';
import 'auth_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authGateway,
    required this.pendingRegistrationStore,
    this.authenticatedChild = const SosTrackingHost(child: MainShell()),
    super.key,
  });

  final AuthGateway authGateway;
  final PendingRegistrationStore pendingRegistrationStore;
  final Widget authenticatedChild;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: authGateway.signedInChanges,
      initialData: authGateway.isSignedIn,
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data ?? authGateway.isSignedIn;
        return isSignedIn
            ? authenticatedChild
            : AuthPage(
                authGateway: authGateway,
                pendingRegistrationStore: pendingRegistrationStore,
              );
      },
    );
  }
}
