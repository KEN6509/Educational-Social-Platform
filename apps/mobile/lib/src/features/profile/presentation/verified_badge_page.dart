import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_creator_badge.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/theme/app_design_tokens.dart';

part 'verified_badge_widgets.dart';

enum CreatorRequestStatus { pending, approved, rejected }

const creatorFollowerRequirement = 2;

class CreatorVerificationState {
  const CreatorVerificationState({
    this.isVerified = false,
    this.followerCount = 0,
    this.requestStatus,
  });

  final bool isVerified;
  final int followerCount;
  final CreatorRequestStatus? requestStatus;

  bool get meetsFollowerRequirement =>
      followerCount >= creatorFollowerRequirement;
}

typedef CreatorVerificationStateLoader = Future<CreatorVerificationState>
    Function();
typedef CreatorApplicationSubmitter = Future<void> Function(String statement);

class VerifiedBadgePage extends StatefulWidget {
  const VerifiedBadgePage({
    super.key,
    this.loadState,
    this.submitApplication,
  });

  final CreatorVerificationStateLoader? loadState;
  final CreatorApplicationSubmitter? submitApplication;

  @override
  State<VerifiedBadgePage> createState() => _VerifiedBadgePageState();
}

class _VerifiedBadgePageState extends State<VerifiedBadgePage> {
  final _statementController = TextEditingController();
  late Future<CreatorVerificationState> _stateFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _stateFuture = _loadState();
  }

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  Future<CreatorVerificationState> _loadState() async {
    final injectedLoader = widget.loadState;
    if (injectedLoader != null) return injectedLoader();

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to view verification status.');
    }

    final profile = await client.from('profiles').select('''
          is_content_creator,
          follower_count:follows!follows_following_id_fkey(count)
        ''').eq('id', userId).maybeSingle();
    final request = await client
        .from('content_creator_requests')
        .select('status')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final followerCountRows = profile?['follower_count'] as List?;
    final followerCount = followerCountRows?.isNotEmpty == true
        ? followerCountRows!.first['count'] as int? ?? 0
        : 0;

    return CreatorVerificationState(
      isVerified: profile?['is_content_creator'] as bool? ?? false,
      followerCount: followerCount,
      requestStatus: _requestStatusFrom(request?['status'] as String?),
    );
  }

  CreatorRequestStatus? _requestStatusFrom(String? value) {
    return switch (value) {
      'pending' => CreatorRequestStatus.pending,
      'approved' => CreatorRequestStatus.approved,
      'rejected' => CreatorRequestStatus.rejected,
      _ => null,
    };
  }

  Future<void> _submit(CreatorVerificationState currentState) async {
    if (_isSubmitting) return;

    if (!currentState.meetsFollowerRequirement) {
      AppFeedback.showWarning(
        context,
        'You need at least $creatorFollowerRequirement followers to apply.',
      );
      return;
    }

    final statement = _statementController.text.trim();
    if (statement.isEmpty) {
      AppFeedback.showError(
        context,
        'Tell us why you would like to be verified.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final injectedSubmitter = widget.submitApplication;
      if (injectedSubmitter != null) {
        await injectedSubmitter(statement);
      } else {
        final client = Supabase.instance.client;
        if (client.auth.currentUser == null) {
          throw StateError('Sign in to apply for verification.');
        }
        await client.rpc<void>(
          'submit_creator_verification_request',
          params: {'p_reason': statement},
        );
      }

      if (!mounted) return;
      setState(() {
        _stateFuture = Future.value(
          CreatorVerificationState(
            isVerified: currentState.isVerified,
            followerCount: currentState.followerCount,
            requestStatus: CreatorRequestStatus.pending,
          ),
        );
      });
      AppFeedback.showSuccess(context, 'Verification request submitted.');
    } catch (_) {
      if (!mounted) return;
      AppFeedback.showError(
        context,
        'Could not submit your request. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _retry() {
    setState(() => _stateFuture = _loadState());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        title: const Text(
          'Verified Badge',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<CreatorVerificationState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _LoadError(onRetry: _retry);
          }

          return _BadgePageBody(
            state: snapshot.data!,
            statementController: _statementController,
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<CreatorVerificationState>(
        future: _stateFuture,
        builder: (context, snapshot) {
          final state = snapshot.data;
          if (state == null) return const SizedBox.shrink();

          return _VerificationBottomAction(
            state: state,
            isSubmitting: _isSubmitting,
            onSubmit: () => _submit(state),
          );
        },
      ),
    );
  }
}
