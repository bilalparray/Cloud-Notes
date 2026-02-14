import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../config/firebase_config.dart';

/// Max dimension for thumbnail (enough for 120px tile at 2x density).
const int _thumbMaxSize = 240;

class NoteImageService {
  /// Use explicit bucket so web and mobile use the same Storage bucket.
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: FirebaseConfig.storageBucket);

  /// Creates thumbnail bytes (max [_thumbMaxSize] px). Returns null if decode fails.
  List<int>? createThumbnailBytes(List<int> bytes) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return null;
    final w = decoded.width;
    final h = decoded.height;
    if (w <= _thumbMaxSize && h <= _thumbMaxSize) {
      return img.encodeJpg(decoded, quality: 80);
    }
    img.Image resized;
    if (w > h) {
      resized = img.copyResize(decoded, width: _thumbMaxSize);
    } else {
      resized = img.copyResize(decoded, height: _thumbMaxSize);
    }
    return img.encodeJpg(resized, quality: 80);
  }

  /// Upload full image and thumbnail; returns (fullUrl, thumbUrl). Preview should use thumbUrl.
  Future<({String fullUrl, String thumbUrl})> uploadImageBytesWithThumb({
    required String workspaceId,
    required String noteId,
    required List<int> bytes,
  }) async {
    final base = DateTime.now().millisecondsSinceEpoch.toString();
    final fullRef = _storage
        .ref()
        .child('workspaces')
        .child(workspaceId)
        .child('notes')
        .child(noteId)
        .child('$base.jpg');
    await fullRef.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/jpeg'));
    final fullUrl = await fullRef.getDownloadURL();

    final thumbBytes = createThumbnailBytes(bytes);
    final thumbRef = _storage
        .ref()
        .child('workspaces')
        .child(workspaceId)
        .child('notes')
        .child(noteId)
        .child('${base}_thumb.jpg');
    if (thumbBytes != null && thumbBytes.isNotEmpty) {
      await thumbRef.putData(Uint8List.fromList(thumbBytes), SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await thumbRef.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/jpeg'));
    }
    final thumbUrl = await thumbRef.getDownloadURL();
    return (fullUrl: fullUrl, thumbUrl: thumbUrl);
  }

  /// Upload image bytes (works on all platforms). Returns the download URL.
  Future<String> uploadImageBytes({
    required String workspaceId,
    required String noteId,
    required List<int> bytes,
  }) async {
    final ref = _storage
        .ref()
        .child('workspaces')
        .child(workspaceId)
        .child('notes')
        .child(noteId)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  /// Upload an image file (mobile). Returns the download URL.
  Future<String> uploadImage({
    required String workspaceId,
    required String noteId,
    required File imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    return uploadImageBytes(workspaceId: workspaceId, noteId: noteId, bytes: bytes);
  }

  /// Download image bytes from a URL (for saving to device).
  Future<List<int>> getImageBytes(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image: ${response.statusCode}');
    }
    return response.bodyBytes;
  }
}
