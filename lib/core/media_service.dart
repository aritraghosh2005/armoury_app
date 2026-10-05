import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaService {
  static const MethodChannel _channel = MethodChannel('com.orcus.armoury/media');
  static final ImagePicker _picker = ImagePicker();

  /// Captures a photo with the device camera,
  /// saves a copy to the device's DCIM -> Gallery (under DCIM/Armoury),
  /// and saves a persistent copy into app storage for the local database.
  static Future<String?> capturePhotoAndSaveToGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );

      if (photo == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'armoury_$timestamp.jpg';

      // 1. Save to device DCIM -> Gallery
      try {
        if (!kIsWeb && Platform.isAndroid) {
          await _channel.invokeMethod('saveImageToGallery', {
            'filePath': photo.path,
            'fileName': fileName,
          });
        }
      } catch (e) {
        debugPrint('[MediaService] Note: Gallery save via MediaStore: $e');
      }

      // 2. Save persistently to app documents directory
      final persistentPath = await _persistImage(photo.path, fileName);
      return persistentPath;
    } catch (e) {
      debugPrint('[MediaService] Camera capture error: $e');
      rethrow;
    }
  }

  /// Picks an image from the gallery and copies it to local persistent app storage.
  static Future<String?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );

      if (image == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'gallery_$timestamp.jpg';

      final persistentPath = await _persistImage(image.path, fileName);
      return persistentPath;
    } catch (e) {
      debugPrint('[MediaService] Gallery pick error: $e');
      rethrow;
    }
  }

  /// Persists any local file into the app's internal documents directory
  static Future<String> _persistImage(String srcPath, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'component_images'));
    if (!imagesDir.existsSync()) {
      await imagesDir.create(recursive: true);
    }

    final destPath = p.join(imagesDir.path, fileName);
    final srcFile = File(srcPath);
    await srcFile.copy(destPath);
    return destPath;
  }
}
