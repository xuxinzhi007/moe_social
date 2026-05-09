import 'package:flutter/material.dart';

class MoeInputField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Color primaryColor;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final AutovalidateMode? autovalidateMode;

  const MoeInputField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.validator,
    this.keyboardType,
    this.primaryColor = const Color(0xFF7F7FD5),
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.autovalidateMode,
  });

  @override
  State<MoeInputField> createState() => _MoeInputFieldState();
}

class _MoeInputFieldState extends State<MoeInputField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autovalidateMode:
            widget.autovalidateMode ?? AutovalidateMode.disabled,
        obscureText: widget.isPassword ? _obscurePassword : false,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction ??
            (widget.isPassword ? TextInputAction.done : TextInputAction.next),
        onEditingComplete: widget.onEditingComplete,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: Icon(widget.icon, color: widget.primaryColor.withValues(alpha: 0.6), size: 22),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey[300],
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}
