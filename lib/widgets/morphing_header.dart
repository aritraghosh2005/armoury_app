import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/ascii_art.dart';
import '../core/theme.dart';

const List<String> _glitchRunes = [
  '/', '\\', '|', '-', '=', '+', '*', '%', '#', '@', 'X', '0', '~', '!', ':', '^', 'v', '1', '0'
];

/// Smooth, high-performance typewriter & character-morphism ASCII header.
///
/// When [title] changes, characters typewriter and morph across a directional
/// wavefront, scrambling with terminal glyphs before locking into the target banner.
class MorphingAsciiHeader extends StatefulWidget {
  final String title;

  const MorphingAsciiHeader({
    super.key,
    required this.title,
  });

  @override
  State<MorphingAsciiHeader> createState() => _MorphingAsciiHeaderState();
}

class _MorphingAsciiHeaderState extends State<MorphingAsciiHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late String _currentTitle;
  late String _previousTitle;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
    _previousTitle = widget.title;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant MorphingAsciiHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title.toLowerCase() != widget.title.toLowerCase()) {
      _previousTitle = oldWidget.title;
      _currentTitle = widget.title;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _morphLine(String from, String to, double p, int lineIndex) {
    final maxLen = math.max(from.length, to.length);
    final chars = List<String>.filled(maxLen, ' ');

    for (int i = 0; i < maxLen; i++) {
      final fromChar = i < from.length ? from[i] : ' ';
      final toChar = i < to.length ? to[i] : ' ';

      final charPos = i / (maxLen > 0 ? maxLen : 1);
      final startScramble = charPos * 0.55;
      final endScramble = startScramble + 0.35;

      if (p < startScramble) {
        chars[i] = fromChar;
      } else if (p < endScramble && p < 1.0) {
        if (fromChar == ' ' && toChar == ' ') {
          chars[i] = ' ';
        } else {
          final runeIdx = ((p * 120).floor() + i * 7 + lineIndex * 13).abs() % _glitchRunes.length;
          chars[i] = _glitchRunes[runeIdx];
        }
      } else {
        chars[i] = toChar;
      }
    }
    return chars.join('').trimRight();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final p = _ctrl.value;
            final fromArt = AsciiArt.get(_previousTitle);
            final toArt = AsciiArt.get(_currentTitle);

            String displayArt;
            if (p >= 1.0 || _previousTitle.toLowerCase() == _currentTitle.toLowerCase()) {
              displayArt = toArt;
            } else {
              final fromLines = fromArt.split('\n');
              final toLines = toArt.split('\n');
              final maxRows = math.max(fromLines.length, toLines.length);
              final morphedLines = <String>[];

              for (int r = 0; r < maxRows; r++) {
                final f = r < fromLines.length ? fromLines[r] : '';
                final t = r < toLines.length ? toLines[r] : '';
                morphedLines.add(_morphLine(f, t, p, r));
              }
              displayArt = morphedLines.join('\n');
            }

            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                displayArt,
                style: AppTypography.ascii(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Typewriter & character-morphism single-line text label.
class MorphingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MorphingText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<MorphingText> createState() => _MorphingTextState();
}

class _MorphingTextState extends State<MorphingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late String _currentText;
  late String _previousText;

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
    _previousText = widget.text;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void didUpdateWidget(covariant MorphingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _previousText = oldWidget.text;
      _currentText = widget.text;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final p = _ctrl.value;
        if (p >= 1.0 || _previousText == _currentText) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final maxLen = math.max(_previousText.length, _currentText.length);
        final chars = List<String>.filled(maxLen, ' ');

        for (int i = 0; i < maxLen; i++) {
          final fromChar = i < _previousText.length ? _previousText[i] : ' ';
          final toChar = i < _currentText.length ? _currentText[i] : ' ';

          final charPos = i / (maxLen > 0 ? maxLen : 1);
          final startScramble = charPos * 0.55;
          final endScramble = startScramble + 0.38;

          if (p < startScramble) {
            chars[i] = fromChar;
          } else if (p < endScramble && p < 1.0) {
            if (toChar == ' ' && fromChar == ' ') {
              chars[i] = ' ';
            } else {
              final runeIdx = ((p * 100).floor() + i * 5).abs() % _glitchRunes.length;
              chars[i] = _glitchRunes[runeIdx];
            }
          } else {
            chars[i] = toChar;
          }
        }

        return Text(
          chars.join('').trimRight(),
          style: widget.style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
