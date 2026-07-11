import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/posts_repository.dart';

class ReportPostPage extends StatefulWidget {
  const ReportPostPage({
    required String postId,
    super.key,
  })  : targetType = 'post',
        targetId = postId,
        subject = 'post';

  const ReportPostPage.comment({
    required String commentId,
    super.key,
  })  : targetType = 'comment',
        targetId = commentId,
        subject = 'comment';

  final String targetType;
  final String targetId;
  final String subject;

  @override
  State<ReportPostPage> createState() => _ReportPostPageState();
}

class _ReportPostPageState extends State<ReportPostPage> {
  String? _selectedReason;
  bool _isSubmitting = false;
  bool _submitted = false;

  Future<void> _submit(String reason) async {
    if (_isSubmitting) return;

    setState(() {
      _selectedReason = reason;
      _isSubmitting = true;
    });

    try {
      final repo = PostsRepository(Supabase.instance.client);
      await repo.createReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
      );
      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          'Report',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _submitted ? _buildThanksState(context) : _buildReasonList(),
      ),
    );
  }

  Widget _buildReasonList() {
    return ListView(
      key: const ValueKey('reasons'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          'Why are you reporting this ${widget.subject}?',
          style: const TextStyle(
            color: Color(0xFF0B1F3E),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your report is private and helps keep CyanZone safe for learning.',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        ...PostsRepository.reportReasons.map((reason) {
          final selected = _selectedReason == reason && _isSubmitting;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              title: Text(
                reason,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: selected
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _isSubmitting ? null : () => _submit(reason),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildThanksState(BuildContext context) {
    return Center(
      key: const ValueKey('thanks'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F8F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF2C7189),
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thanks for your feedback',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF0B1F3E),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We will review this ${widget.subject} and use your report to improve safety.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1F3E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
