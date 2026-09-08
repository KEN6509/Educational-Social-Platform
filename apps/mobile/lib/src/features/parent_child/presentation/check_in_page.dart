import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import '../services/location_service.dart';

class CheckInPage extends StatefulWidget {
  CheckInPage({
    super.key,
    required this.repository,
    LocationService? locationService,
  }) : locationService = locationService ?? GeolocatorLocationService();

  final ParentChildRepositoryContract repository;
  final LocationService locationService;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _shareLocation = false;
  bool _busy = false;
  LocationCapture? _failedCapture;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String? _validateMessage(String? value) {
    final message = value?.trim() ?? '';
    if (message.isEmpty) return 'Enter a short safety message.';
    if (message.length > 280) return 'Keep your message within 280 characters.';
    return null;
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_shareLocation) {
      await _captureLocation();
    } else {
      await _submit(const LocationCapture.notRequested());
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _busy = true;
      _failedCapture = null;
    });
    final location = await widget.locationService.capture();
    if (!mounted) return;
    if (location.status == LocationStatus.available) {
      await _submit(location, alreadyBusy: true);
      return;
    }
    setState(() {
      _busy = false;
      _failedCapture = location;
    });
  }

  Future<void> _submit(
    LocationCapture location, {
    bool alreadyBusy = false,
  }) async {
    if (!alreadyBusy) setState(() => _busy = true);
    try {
      await widget.repository.submitCheckIn(
        CheckInDraft(
          message: _messageController.text.trim(),
          location: location,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safety Check-In sent.')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send Check-In: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Safety Check-In',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Send a short update to every linked parent so they know you are safe.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _messageController,
                enabled: !_busy,
                validator: _validateMessage,
                maxLength: 280,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  labelText: 'Safety message',
                  hintText: 'Example: I arrived safely.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Share my location',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Optional. Location permission is requested only when selected.',
                ),
                value: _shareLocation,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _shareLocation = value;
                          _failedCapture = null;
                        }),
              ),
              if (_failedCapture != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location unavailable',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You can retry location or send your message without it.',
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('check-in-retry-location'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _busy ? null : _captureLocation,
                                child: const Text(
                                  'Retry location',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                key: const Key(
                                  'check-in-send-without-location',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => _submit(
                                          const LocationCapture.notRequested(),
                                        ),
                                child: const Text(
                                  'Send without location',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Sending…' : 'Send Check-In'),
                ),
              ),
            ],
          ),
        ),
      );
}
