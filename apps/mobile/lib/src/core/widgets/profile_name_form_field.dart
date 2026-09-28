import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../validation/profile_name_policy.dart';

class ProfileNameFormField extends StatelessWidget {
  const ProfileNameFormField({
    required this.controller,
    required this.decoration,
    this.fieldKey,
    this.enabled = true,
    this.textInputAction,
    this.autofillHints,
    super.key,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: [
        LengthLimitingTextInputFormatter(ProfileNamePolicy.maxLength),
      ],
      decoration: decoration.copyWith(
        helperText: decoration.helperText ?? ProfileNamePolicy.helperText,
      ),
      validator: ProfileNamePolicy.validate,
    );
  }
}
