import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double blur;
  final double? width;
  final double? height;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.blur = 0.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBg,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: borderColor ?? AppColors.borderSubtle,
          width: borderWidth,
        ),
      ),
      padding: padding,
      child: child,
    );

    if (blur > 0) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    return content;
  }
}
