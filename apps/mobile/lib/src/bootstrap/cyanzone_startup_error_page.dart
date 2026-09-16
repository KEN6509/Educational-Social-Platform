import 'package:flutter/material.dart';

import '../core/widgets/cyanzone_wordmark.dart';

class CyanZoneStartupErrorPage extends StatefulWidget {
  const CyanZoneStartupErrorPage({
    required this.onRetry,
    super.key,
  });

  final Future<void> Function() onRetry;

  @override
  State<CyanZoneStartupErrorPage> createState() =>
      _CyanZoneStartupErrorPageState();
}

class _CyanZoneStartupErrorPageState extends State<CyanZoneStartupErrorPage> {
  var _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying) return;

    setState(() => _isRetrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/cyanzone_logo_black_transparent.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.contain,
                  semanticLabel: 'CyanZone logo',
                ),
                const SizedBox(height: 16),
                const CyanZoneWordmark(
                  fontSize: 30,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Text(
                  'CyanZone could not start.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0B1F3E),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection, then try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF536A74),
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isRetrying ? null : _retry,
                  icon: _isRetrying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
