import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workspace.dart';

class WorkspaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'workspaces';

  Stream<List<Workspace>> getWorkspacesStream(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList());
  }

  // Get all workspaces where user is owner or member
  // Note: Firestore doesn't support OR queries, so we get owned workspaces
  // and filter member workspaces in the app layer
  Stream<List<Workspace>> getWorkspacesForUser(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList());
  }

  // Get workspaces where user is a member (not owner)
  Stream<List<Workspace>> getMemberWorkspaces(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('members.$userId', isGreaterThan: '')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList());
  }

  Future<Workspace> createWorkspace({
    required String name,
    required String description,
    required String ownerId,
  }) async {
    try {
      final now = DateTime.now();
      final workspace = Workspace(
        name: name,
        description: description,
        ownerId: ownerId,
        createdAt: now,
        updatedAt: now,
        members: {}, // Owner is not in members map, they're the ownerId
      );

      final docRef = await _firestore
          .collection(_collectionName)
          .add(workspace.toFirestore());

      return workspace.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create workspace: $e');
    }
  }

  Future<void> updateWorkspace(Workspace workspace) async {
    try {
      if (workspace.id == null) {
        throw Exception('Workspace ID is required for update');
      }
      await _firestore
          .collection(_collectionName)
          .doc(workspace.id)
          .update(workspace.copyWith(updatedAt: DateTime.now()).toFirestore());
    } catch (e) {
      throw Exception('Failed to update workspace: $e');
    }
  }

  Future<void> addMemberToWorkspace({
    required String workspaceId,
    required String userId,
    required WorkspaceRole role,
  }) async {
    try {
      // Use a transaction to read current workspace, update members, and write back
      // This ensures security rules can properly evaluate the update
      await _firestore.runTransaction((transaction) async {
        final workspaceRef = _firestore.collection(_collectionName).doc(workspaceId);
        final workspaceDoc = await transaction.get(workspaceRef);
        
        if (!workspaceDoc.exists) {
          throw Exception('Workspace not found');
        }
        
        final currentData = workspaceDoc.data()!;
        final currentMembers = Map<String, String>.from(currentData['members'] ?? {});
        
        // Add the new member
        currentMembers[userId] = role.value;
        
        // Update the workspace with the full members map
        transaction.update(workspaceRef, {
          'members': currentMembers,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  Future<void> removeMemberFromWorkspace({
    required String workspaceId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(workspaceId)
          .update({
        'members.$userId': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    try {
      await _firestore.collection(_collectionName).doc(workspaceId).delete();
    } catch (e) {
      throw Exception('Failed to delete workspace: $e');
    }
  }

  Future<Workspace?> getWorkspaceById(String workspaceId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(workspaceId)
          .get();
      if (!doc.exists) return null;
      return Workspace.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get workspace: $e');
    }
  }
}
