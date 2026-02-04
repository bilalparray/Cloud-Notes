import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';

class NotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'notes';

  Stream<List<Note>> getNotesStream(String workspaceId) {
    return _firestore
        .collection(_collectionName)
        .where('workspaceId', isEqualTo: workspaceId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList());
  }

  Future<void> createNote(Note note) async {
    try {
      await _firestore.collection(_collectionName).add(note.toFirestore());
    } catch (e) {
      throw Exception('Failed to create note: $e');
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      if (note.id == null) {
        throw Exception('Note ID is required for update');
      }
      await _firestore
          .collection(_collectionName)
          .doc(note.id)
          .update(note.toFirestore());
    } catch (e) {
      throw Exception('Failed to update note: $e');
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _firestore.collection(_collectionName).doc(noteId).delete();
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }
}
