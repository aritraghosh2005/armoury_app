import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/i_media_repository.dart';
import '../../core/repositories/media_repository.dart';
import 'armoury_viewmodel.dart';

final mediaRepositoryProvider = Provider<IMediaRepository>(
  (ref) => const MediaRepository(),
);
final mediaViewModelProvider = NotifierProvider<MediaViewModel, MediaState>(
  MediaViewModel.new,
);

class MediaState {
  final bool isLoading;
  final String message;

  const MediaState({this.isLoading = false, this.message = ''});
}

class MediaViewModel extends Notifier<MediaState> {
  @override
  MediaState build() => const MediaState();

  Future<bool> capture(String componentId) =>
      _attach(componentId, camera: true);
  Future<bool> pick(String componentId) => _attach(componentId, camera: false);
  Future<String?> captureDraft() => _pickDraft(camera: true);
  Future<String?> pickDraft() => _pickDraft(camera: false);

  Future<String?> _pickDraft({required bool camera}) async {
    if (state.isLoading) return null;
    state = MediaState(
      isLoading: true,
      message: camera
          ? 'OPENING OPTICAL SENSOR...'
          : 'ACCESSING LOCAL GALLERY...',
    );
    try {
      final media = ref.read(mediaRepositoryProvider);
      return camera ? await media.capture() : await media.pick();
    } finally {
      state = const MediaState();
    }
  }

  Future<bool> _attach(String id, {required bool camera}) async {
    if (state.isLoading) return false;
    state = MediaState(
      isLoading: true,
      message: camera
          ? 'OPENING OPTICAL SENSOR...'
          : 'ACCESSING LOCAL GALLERY...',
    );
    try {
      final media = ref.read(mediaRepositoryProvider);
      final path = camera ? await media.capture() : await media.pick();
      if (path == null) return false;
      state = MediaState(
        isLoading: true,
        message: 'PERSISTING MEDIA & LINKING RECORD...',
      );
      await ref.read(armouryViewModelProvider.notifier).updateComponent(id, {
        'image': path,
      });
      return true;
    } finally {
      state = const MediaState();
    }
  }
}
