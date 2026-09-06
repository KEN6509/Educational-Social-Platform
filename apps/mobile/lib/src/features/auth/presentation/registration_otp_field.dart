import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistrationOtpField extends StatefulWidget {
  const RegistrationOtpField({
    required this.controller,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  static const length = 6;

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<RegistrationOtpField> createState() => _RegistrationOtpFieldState();
}

class _RegistrationOtpFieldState extends State<RegistrationOtpField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 344),
        child: SizedBox(
          height: 56,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => ExcludeSemantics(
                  child: Row(
                    key: const ValueKey('registration-otp-cells'),
                    children: [
                      for (var index = 0;
                          index < RegistrationOtpField.length;
                          index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedContainer(
                            key: ValueKey('registration-otp-cell-$index'),
                            duration: const Duration(milliseconds: 140),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _isActive(index, value.text)
                                  ? const Color(0xFFF1FBFC)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isActive(index, value.text)
                                    ? theme.colorScheme.primary
                                    : const Color(0xFFD5E0E5),
                                width: _isActive(index, value.text) ? 1.8 : 1.2,
                              ),
                            ),
                            child: Text(
                              index < value.text.length
                                  ? value.text[index]
                                  : '',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF0B1F3E),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Semantics(
                label: 'Six-digit verification code',
                textField: true,
                child: TextField(
                  key: const ValueKey('registration-otp-field'),
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      RegistrationOtpField.length,
                    ),
                  ],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableSuggestions: false,
                  autocorrect: false,
                  showCursor: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (value) {
                    if (value.trim().length == RegistrationOtpField.length) {
                      widget.onSubmitted?.call(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isActive(int index, String value) {
    return widget.enabled &&
        _focusNode.hasFocus &&
        value.length < RegistrationOtpField.length &&
        index == value.length;
  }
}
