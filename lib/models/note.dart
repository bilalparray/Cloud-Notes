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

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    DateTime? updatedAt,
    required this.userId,
    required this.workspaceId,
    this.isPinned = false,
  }) : updatedAt = updatedAt ?? createdAt;

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? createdAt;
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      userId: data['userId'] ?? '',
      workspaceId: data['workspaceId'] ?? '',
      isPinned: data['isPinned'] == true,
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
    );
  }
}
