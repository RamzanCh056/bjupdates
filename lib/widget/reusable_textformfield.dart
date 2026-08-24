import 'package:flutter/material.dart';
import 'package:gradient_borders/input_borders/gradient_outline_input_border.dart';

import '../utils/color.dart';

class ReusableTextForm extends StatelessWidget {
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Color filledColor;
  final String? hintText;
  final bool? obscureText;
  final bool? enabled;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextCapitalization? capitalize;
  final int? maxLine;
  final Color? textColor;
  final double? borderRadius;
  final Function(String)? onChanged;
  final Function()? onTap;
  final bool? readOnly;


  const ReusableTextForm({
    Key? key,
    this.validator,
    this.controller,
    this.keyboardType,
    this.textColor=whiteColor,
    this.capitalize=TextCapitalization.none,
    this.hintText,
    this.suffixIcon,
    this.maxLine=1,
    this.obscureText = false,
    this.enabled = true,
    this.prefixIcon,  this.filledColor = lightBlackColor,
    this.borderRadius=8,
    this.onChanged,
    this.onTap,
    this.readOnly=false

  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onTap: onTap,
        obscureText: obscureText!,
        textCapitalization: capitalize!,
        maxLines: maxLine!,
        onChanged: onChanged,
        readOnly: readOnly!,
        style: TextStyle(color: textColor!),
        decoration: InputDecoration(
          filled: true,
          fillColor: filledColor,
          suffixIcon: suffixIcon,
          prefixIcon: prefixIcon,
          enabled: enabled!,
          hintText: hintText,

          hintStyle: TextStyle(color: greyColor),

          contentPadding: const EdgeInsets.all(10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius!),
              borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius!),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius!),
            borderSide: BorderSide.none,
          ),
          focusedBorder: GradientOutlineInputBorder(
            gradient: buttonGradient,
            borderRadius: BorderRadius.circular(borderRadius!),
          )
        ),
        // validations
        validator: validator);
  }
}
