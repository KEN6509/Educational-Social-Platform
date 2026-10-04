import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_design_tokens.dart';
import '../validation/profile_name_policy.dart';

class ProfileNameFormField extends StatelessWidget {
  const ProfileNameFormField({
    required this.controller,
    required this.decoration,
    this.fieldKey,
    this.enabled = true,
    this.showCounter = false,
    this.showHelperText = true,
    this.textInputAction,
    this.autofillHints,
    super.key,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;
  final bool showCounter;
  final bool showHelperText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: [
        LengthLimitingTextInputFormatter(ProfileNamePolicy.maxLength),
      ],
      decoration: showHelperText
          ? decoration.copyWith(
              helperText: decoration.helperText ?? ProfileNamePolicy.helperText,
              helperMaxLines: decoration.helperMaxLines ?? 2,
            )
          : decoration,
      validator: ProfileNamePolicy.validate,
    );

    if (!showCounter) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return Text(
                  '${value.text.length}/${ProfileNamePolicy.maxLength}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
