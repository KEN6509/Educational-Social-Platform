part of 'verified_badge_page.dart';

class _VerificationBottomAction extends StatelessWidget {
  const _VerificationBottomAction({
    required this.state,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final CreatorVerificationState state;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isVerified = state.isVerified ||
        state.requestStatus == CreatorRequestStatus.approved;
    final isPending = state.requestStatus == CreatorRequestStatus.pending;
    final label = isVerified
        ? 'Verified creator'
        : isPending
            ? 'Application pending'
            : state.requestStatus == CreatorRequestStatus.rejected
                ? 'Apply again'
                : 'Apply for verification';

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: isVerified || isPending || isSubmitting ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            disabledBackgroundColor: const Color(0xFFCBD5E1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isSubmitting ? 'Submitting...' : label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _BadgePageBody extends StatelessWidget {
  const _BadgePageBody({
    required this.state,
    required this.statementController,
  });

  final CreatorVerificationState state;
  final TextEditingController statementController;

  @override
  Widget build(BuildContext context) {
    final isVerified = state.isVerified ||
        state.requestStatus == CreatorRequestStatus.approved;
    final isPending = state.requestStatus == CreatorRequestStatus.pending;
    final isRejected = state.requestStatus == CreatorRequestStatus.rejected;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContentCreatorBadge(isVisible: true, size: 44),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stand out as a trusted creator',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'The verified badge helps users identify trusted content creators.',
                        style: TextStyle(
                          color: Color(0xFF526779),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isVerified || isPending || isRejected) ...[
            const SizedBox(height: 16),
            _StatusNotice(
              icon: isVerified
                  ? Icons.verified_rounded
                  : isPending
                      ? Icons.schedule_rounded
                      : Icons.info_outline_rounded,
              color: isVerified
                  ? const Color(0xFF16805D)
                  : isPending
                      ? const Color(0xFF9A6700)
                      : const Color(0xFFB45309),
              message: isVerified
                  ? 'Your account is verified as a CyanZone content creator.'
                  : isPending
                      ? 'Your application is being reviewed by an administrator.'
                      : 'Your last request was not approved. Check System notifications for the administrator\'s reason.',
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'To be eligible to submit a request for account verification:',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          const _Requirement(
            icon: Icons.groups_rounded,
            title: 'Have at least 10,000 followers',
            detail: 'Your CyanZone account must reach this follower milestone.',
          ),
          const _Requirement(
            icon: Icons.account_circle_outlined,
            title: 'Complete your profile',
            detail: 'Use a clear profile name, photo, and useful biography.',
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF367D98),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sometimes, CyanZone may also proactively verify accounts with fewer than 10,000 followers that are well-known outside of CyanZone.',
                    style: TextStyle(
                      color: Color(0xFF526779),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Strengthen your application',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'These steps may improve your chances of receiving the verified badge.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const _Requirement(
            icon: Icons.health_and_safety_outlined,
            title: 'Keep your account in good standing',
            detail: 'Keep your account active and avoid serious violations.',
          ),
          const _Requirement(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Share valuable content',
            detail:
                'Publish useful, original posts that benefit your audience.',
          ),
          const _Requirement(
            icon: Icons.rule_rounded,
            title: 'Follow the CyanZone Community Guidelines',
            detail: 'Keep your content respectful, safe, and appropriate.',
          ),
          if (!isVerified && !isPending) ...[
            const SizedBox(height: 24),
            const Text(
              'Account Verification Application',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tell the review team what you create and why your account should be verified.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('creator-application-statement'),
              controller: statementController,
              maxLength: 500,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
              maxLines: 5,
              minLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Describe your content and audience',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDCE5EA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDCE5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.cyan,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: statementController,
              builder: (_, value, __) => Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${value.text.length} / 500',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5ECEF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF367D98), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF263B4A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load verification status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
