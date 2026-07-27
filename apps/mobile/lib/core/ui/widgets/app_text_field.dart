import 'package:flutter/material.dart';

/// Thin wrapper over [TextFormField]. Borders/fill come from the app's
/// `InputDecorationTheme`; focus and error rendering are the framework's job
/// (`validator` + `autovalidateMode` + `errorText`) — no manual focus/error
/// state machine, no hand-drawn borders.
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.label,
    this.controller,
    this.hint,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.errorText,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.autovalidateMode,
    super.key,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    enabled: enabled,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    validator: validator,
    autovalidateMode: autovalidateMode,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    ),
  );
}
