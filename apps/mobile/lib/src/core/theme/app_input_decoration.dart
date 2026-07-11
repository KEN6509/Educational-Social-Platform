import 'package:flutter/material.dart';

InputDecoration appInputDecoration({
  required String hintText,
  EdgeInsetsGeometry contentPadding =
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
}) {
  final radius = BorderRadius.circular(14);
  const borderColor = Color(0xFFDCE8EC);
  const focusColor = Color(0xFF4490AD);
  const errorColor = Color(0xFFE11D48);

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF94A3B8),
      fontWeight: FontWeight.w400,
    ),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    counterText: '',
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: focusColor, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: errorColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: errorColor, width: 1.4),
    ),
    contentPadding: contentPadding,
  );
}

InputDecoration appSearchInputDecoration({
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    isCollapsed: true,
    filled: false,
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF64748B),
      fontSize: 15,
      fontWeight: FontWeight.w400,
    ),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}
