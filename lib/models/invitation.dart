import 'package:cloud_firestore/cloud_firestore.dart';

class Invitation {
  final String? id;
  final String workspaceId;
  final String token;
  final String role; // 'owner', 'editor', 'viewer'
  final String createdBy; // userId of the person who created the invitation
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String? usedBy; // userId who used this invitation
  final DateTime? usedAt;

  Invitation({
    this.id,
    required this.workspaceId,
    required this.token,
    required this.role,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
    this.usedBy,
    this.usedAt,
  });

  factory Invitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Invitation(
      id: doc.id,
      workspaceId: data['workspaceId'] ?? '',
      token: data['token'] ?? '',
      role: data['role'] ?? 'viewer',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isUsed: data['isUsed'] ?? false,
      usedBy: data['usedBy'],
      usedAt: data['usedAt'] != null
          ? (data['usedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workspaceId': workspaceId,
      'token': token,
      'role': role,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isUsed': isUsed,
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
    };
  }

  bool get isValid {
    if (isUsed) return false;
    if (DateTime.now().isAfter(expiresAt)) return false;
    return true;
  }

  Invitation copyWith({
    String? id,
    String? workspaceId,
    String? token,
    String? role,
    String? createdBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
    String? usedBy,
    DateTime? usedAt,
  }) {
    return Invitation(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      token: token ?? this.token,
      role: role ?? this.role,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
      usedBy: usedBy ?? this.usedBy,
      usedAt: usedAt ?? this.usedAt,
    );
  }
}
