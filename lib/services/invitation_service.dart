import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invitation.dart';
import '../models/workspace.dart';

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'invitations';

  String _generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<Invitation> createInvitation({
    required String workspaceId,
    required String createdBy,
    required WorkspaceRole role,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    try {
      String token = '';
      bool isUnique = false;

      // Generate unique token
      while (!isUnique) {
        token = _generateToken();
        final existing = await _firestore
            .collection(_collectionName)
            .where('token', isEqualTo: token)
            .limit(1)
            .get();
        isUnique = existing.docs.isEmpty;
      }

      final now = DateTime.now();
      final invitation = Invitation(
        workspaceId: workspaceId,
        token: token,
        role: role.value,
        createdBy: createdBy,
        createdAt: now,
        expiresAt: now.add(expiryDuration),
      );

      final docRef = await _firestore
          .collection(_collectionName)
          .add(invitation.toFirestore());

      return invitation.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create invitation: $e');
    }
  }

  Future<Invitation?> getInvitationByToken(String token) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('token', isEqualTo: token)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Invitation.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get invitation: $e');
    }
  }

  Future<void> markInvitationAsUsed({
    required String invitationId,
    required String usedBy,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(invitationId).update({
        'isUsed': true,
        'usedBy': usedBy,
        'usedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to mark invitation as used: $e');
    }
  }

  Future<void> deleteInvitation(String invitationId) async {
    try {
      await _firestore.collection(_collectionName).doc(invitationId).delete();
    } catch (e) {
      throw Exception('Failed to delete invitation: $e');
    }
  }

  Stream<List<Invitation>> getInvitationsForWorkspace(String workspaceId) {
    // Query without orderBy first (no index required) and sort in memory
    // This avoids the infinite loading issue when index is missing
    return _firestore
        .collection(_collectionName)
        .where('workspaceId', isEqualTo: workspaceId)
        .snapshots()
        .map((snapshot) {
          final invitations = snapshot.docs
              .map((doc) => Invitation.fromFirestore(doc))
              .toList();
          // Sort by createdAt descending
          invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invitations;
        });
  }

  String generateInvitationLink(String token,
      {String? baseUrl, bool isDevelopment = false}) {
    // For web, use the current origin if valid
    if (baseUrl != null &&
        baseUrl.isNotEmpty &&
        (baseUrl.startsWith('http://') || baseUrl.startsWith('https://'))) {
      // Ensure no trailing slash
      final cleanUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      return '$cleanUrl/join/$token';
    }

    // For development/testing: Use localhost
    if (isDevelopment) {
      return 'http://localhost:55926/join/$token';
    }

    // For mobile in development, you can use your local network IP
    // Get your local IP with: ipconfig (Windows) or ifconfig (Mac/Linux)
    // Example: 'http://192.168.1.100:5501/join/$token'

    // For production, you should set your actual domain here
    return 'https://your-app-domain.com/join/$token';
  }
}
