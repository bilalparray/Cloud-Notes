import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/workspace.dart';

class WorkspaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'workspaces';

  // Get all workspaces where user is owner OR member
  // Since Firestore doesn't support OR queries, we combine two streams
  Stream<List<Workspace>> getWorkspacesStream(String userId) {
    // Get owned workspaces
    final ownedStream = _firestore
        .collection(_collectionName)
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList());

    // Get workspaces where user is a member (not owner)
    final memberStream = _firestore
        .collection(_collectionName)
        .where('members.$userId', isGreaterThan: '')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Workspace.fromFirestore(doc)).toList());

    // Combine both streams manually
    final controller = StreamController<List<Workspace>>();
    final ownedWorkspaces = <String, Workspace>{};
    final memberWorkspaces = <String, Workspace>{};
    StreamSubscription? ownedSub;
    StreamSubscription? memberSub;

    void emitCombined() {
      // Merge both maps (member workspaces override owned if duplicate, which shouldn't happen)
      final allWorkspaces = <String, Workspace>{...ownedWorkspaces, ...memberWorkspaces};
      final result = allWorkspaces.values.toList();
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      controller.add(result);
    }

    ownedSub = ownedStream.listen((workspaces) {
      ownedWorkspaces.clear();
      for (final workspace in workspaces) {
        if (workspace.id != null) {
          ownedWorkspaces[workspace.id!] = workspace;
        }
      }
      emitCombined();
    }, onError: (error) {
      controller.addError(error);
    });

    memberSub = memberStream.listen((workspaces) {
      memberWorkspaces.clear();
      for (final workspace in workspaces) {
        if (workspace.id != null) {
          memberWorkspaces[workspace.id!] = workspace;
        }
      }
      emitCombined();
    }, onError: (error) {
      controller.addError(error);
    });

    controller.onCancel = () {
      ownedSub?.cancel();
      memberSub?.cancel();
    };

    return controller.stream;
  }

  // Get all workspaces where user is owner or member (alias for getWorkspacesStream)
  Stream<List<Workspace>> getWorkspacesForUser(String userId) {
    return getWorkspacesStream(userId);
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
        memberNames: {}, // Initialize empty memberNames map
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
    String? displayName,
    String? email,
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
        final currentMemberNames = Map<String, String>.from(currentData['memberNames'] ?? {});
        
        // Add the new member
        currentMembers[userId] = role.value;
        
        // Store member name if provided
        if (displayName != null && displayName.isNotEmpty) {
          currentMemberNames[userId] = displayName;
        } else if (email != null && email.isNotEmpty) {
          // Use email as fallback if no display name
          currentMemberNames[userId] = email.split('@').first;
        }
        
        // Update the workspace with the full members map
        transaction.update(workspaceRef, {
          'members': currentMembers,
          'memberNames': currentMemberNames,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  Future<void> updateMemberRole({
    required String workspaceId,
    required String userId,
    required WorkspaceRole newRole,
  }) async {
    try {
      // Use regular update instead of transaction to avoid conflicts with StreamBuilder
      // Owner updates don't need transaction isolation
      await _firestore
          .collection(_collectionName)
          .doc(workspaceId)
          .update({
        'members.$userId': newRole.value,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update member role: $e');
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
        'memberNames.$userId': FieldValue.delete(),
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

  Stream<Workspace?> getWorkspaceStream(String workspaceId) {
    return _firestore
        .collection(_collectionName)
        .doc(workspaceId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Workspace.fromFirestore(doc);
    });
  }

  /// Update only invite settings (owner sets role and enables/disables invite).
  Future<void> updateWorkspaceInvite({
    required String workspaceId,
    required bool inviteEnabled,
    required String? inviteRole,
  }) async {
    try {
      final updates = <String, dynamic>{
        'inviteEnabled': inviteEnabled,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (inviteRole != null) updates['inviteRole'] = inviteRole;
      await _firestore.collection(_collectionName).doc(workspaceId).update(updates);
    } catch (e) {
      throw Exception('Failed to update invite settings: $e');
    }
  }

  /// Accept workspace invite by code (workspace ID). Calls Cloud Function.
  Future<void> acceptInviteByCode(String workspaceId) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('acceptInvite')
        .call(<String, dynamic>{'workspaceId': workspaceId.trim()});
    if (result.data is Map && (result.data as Map)['success'] != true) {
      throw Exception((result.data as Map)['message']?.toString() ?? 'Failed to join');
    }
  }
}
