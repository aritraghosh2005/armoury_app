import 'package:flutter/material.dart';
import 'morphing_header.dart';

class AsciiHeader extends StatelessWidget {
  final String title;

  const AsciiHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return MorphingAsciiHeader(title: title);
  }
}
