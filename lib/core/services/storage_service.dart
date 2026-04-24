import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Wraps Supabase Storage (backed by GCS under the hood via Supabase's
/// storage integration).  Files are stored in the `evidence` bucket.
class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;

  static const _bucket = 'evidence';

  /// Upload [file] under [path] and return the storage path.
  Future<String> uploadFile(File file, String path) async {
    await _client.storage.from(_bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
    return path;
  }

  /// Upload raw bytes under [path] and return the storage path.
  Future<String> uploadBytes(
    Uint8List bytes,
    String path,
    String contentType,
  ) async {
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    return path;
  }

  /// Generate a time-limited signed URL so the client can view the file.
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) {
    return _client.storage
        .from(_bucket)
        .createSignedUrl(path, expiresInSeconds);
  }

  /// Delete a file from storage.
  Future<void> deleteFile(String path) async {
    await _client.storage.from(_bucket).remove([path]);
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StorageService(client);
});
