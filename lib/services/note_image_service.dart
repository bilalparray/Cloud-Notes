import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../config/firebase_config.dart';

class NoteImageService {
  /// Use explicit bucket so web and mobile use the same Storage bucket.
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: FirebaseConfig.storageBucket);

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
