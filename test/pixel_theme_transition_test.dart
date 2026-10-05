import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:armoury_flutter/widgets/pixel_theme_transition.dart';

void main() {
  test('PixelWavePainter fallback mode paints without error across progress states', () {
    final painterStart = PixelWavePainter(
      progress: 0.0,
      origin: const Offset(100, 100),
      toLight: true,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(400, 800);

    // At progress 0.0, it should early return safely
    painterStart.paint(canvas, size);

    // At progress 0.5 (midpoint)
    final painterMid = PixelWavePainter(
      progress: 0.5,
      origin: const Offset(200, 300),
      toLight: false,
    );
    painterMid.paint(canvas, size);

    // At progress 1.0 (fully covered)
    final painterEnd = PixelWavePainter(
      progress: 1.0,
      origin: const Offset(50, 50),
      toLight: true,
    );
    painterEnd.paint(canvas, size);

    expect(painterEnd.shouldRepaint(painterMid), isTrue);
    expect(painterEnd.shouldRepaint(painterEnd), isFalse);

    final picture = recorder.endRecording();
    expect(picture, isNotNull);
  });

  test('PixelWavePainter snapshot-coordinated mode paints and clips correctly', () async {
    // Generate a mock snapshot ui.Image
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 400, 800), Paint()..color = Colors.black);
    final pic = rec.endRecording();
    final testImage = await pic.toImage(400, 800);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(400, 800);

    final painterWithSnapshot = PixelWavePainter(
      snapshot: testImage,
      progress: 0.45,
      origin: const Offset(200, 400),
      toLight: true,
    );

    painterWithSnapshot.paint(canvas, size);
    final picture = recorder.endRecording();
    expect(picture, isNotNull);

    testImage.dispose();
  });
}
