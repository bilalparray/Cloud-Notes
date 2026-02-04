import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkspaceRole {
  owner,
  editor,
  viewer;

  String get value => name;
  static WorkspaceRole fromString(String value) {
    return WorkspaceRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => WorkspaceRole.viewer,
    );
  }
}

class Workspace {
  final String? id;
  final String name;
  final String description;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> members; // userId -> role
  final Map<String, String> memberNames; // userId -> displayName

  Workspace({
    this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    Map<String, String>? memberNames,
  }) : memberNames = memberNames ?? {};

  factory Workspace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Workspace(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      ownerId: data['ownerId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      members: Map<String, String>.from(data['members'] ?? {}),
      memberNames: Map<String, String>.from(data['memberNames'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'members': members,
      'memberNames': memberNames,
    };
  }

  WorkspaceRole getRoleForUser(String userId) {
    if (ownerId == userId) return WorkspaceRole.owner;
    final roleString = members[userId];
    if (roleString == null) return WorkspaceRole.viewer;
    return WorkspaceRole.fromString(roleString);
  }

  bool canEdit(String userId) {
    final role = getRoleForUser(userId);
    return role == WorkspaceRole.owner || role == WorkspaceRole.editor;
  }

  bool canView(String userId) {
    return ownerId == userId || members.containsKey(userId);
  }

  Workspace copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? members,
    Map<String, String>? memberNames,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      memberNames: memberNames ?? this.memberNames,
    );
  }
  
  String? getMemberName(String userId) {
    return memberNames[userId];
  }
}
