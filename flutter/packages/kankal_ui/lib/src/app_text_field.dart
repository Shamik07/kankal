import 'package:flutter/material.dart';

/// A labeled Material form field with native validation and keyboard behavior.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.autofillHints,
    this.maxLines = 1,
    super.key,
  }) : assert(!obscureText || maxLines == 1);

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    obscureText: obscureText,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onFieldSubmitted: onSubmitted,
    enabled: enabled,
    autofillHints: autofillHints,
    maxLines: obscureText ? 1 : maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    ),
  );
}
