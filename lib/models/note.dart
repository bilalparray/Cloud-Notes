import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String workspaceId;
  final bool isPinned;
  final List<String> imageUrls;
  /// Thumbnail URLs for preview (same order as imageUrls). Use for display; download uses imageUrls.
  final List<String> imageThumbUrls;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    DateTime? updatedAt,
    required this.userId,
    required this.workspaceId,
    this.isPinned = false,
    List<String>? imageUrls,
    List<String>? imageThumbUrls,
  })  : updatedAt = updatedAt ?? createdAt,
        imageUrls = imageUrls ?? const [],
        imageThumbUrls = imageThumbUrls ?? const [];

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? createdAt;
    final imageUrlsRaw = data['imageUrls'];
    final imageUrls = imageUrlsRaw is List
        ? imageUrlsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final imageThumbUrlsRaw = data['imageThumbUrls'];
    final imageThumbUrls = imageThumbUrlsRaw is List
        ? imageThumbUrlsRaw.map((e) => e.toString()).toList()
        : <String>[];
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      userId: data['userId'] ?? '',
      workspaceId: data['workspaceId'] ?? '',
      isPinned: data['isPinned'] == true,
      imageUrls: imageUrls,
      imageThumbUrls: imageThumbUrls,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'userId': userId,
      'workspaceId': workspaceId,
      'isPinned': isPinned,
      'imageUrls': imageUrls,
      'imageThumbUrls': imageThumbUrls,
    };
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? workspaceId,
    bool? isPinned,
    List<String>? imageUrls,
    List<String>? imageThumbUrls,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      isPinned: isPinned ?? this.isPinned,
      imageUrls: imageUrls ?? this.imageUrls,
      imageThumbUrls: imageThumbUrls ?? this.imageThumbUrls,
    );
  }
}
