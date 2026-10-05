abstract interface class IMediaRepository {
  Future<String?> capture();
  Future<String?> pick();
}
