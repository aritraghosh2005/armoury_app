import '../media_service.dart';
import 'i_media_repository.dart';

class MediaRepository implements IMediaRepository {
  const MediaRepository();

  @override
  Future<String?> capture() => MediaService.capturePhotoAndSaveToGallery();

  @override
  Future<String?> pick() => MediaService.pickFromGallery();
}
