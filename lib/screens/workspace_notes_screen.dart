import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';
import '../models/workspace.dart';
import '../services/auth_service.dart';
import '../services/notes_service.dart';
import '../services/workspace_service.dart';
import 'note_edit_screen.dart';
import 'workspace_members_screen.dart';

class WorkspaceNotesScreen extends StatefulWidget {
  final Workspace workspace;

  const WorkspaceNotesScreen({
    super.key,
    required this.workspace,
  });

  @override
  State<WorkspaceNotesScreen> createState() => _WorkspaceNotesScreenState();
}

class _WorkspaceNotesScreenState extends State<WorkspaceNotesScreen> {
  final NotesService _notesService = NotesService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  User? _currentUser;
  String _searchQuery = '';
  bool _isSearching = false;
  Workspace? _currentWorkspace;
  String? _cachedNotesWorkspaceId;
  Stream<List<Note>>? _cachedNotesStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _currentWorkspace = widget.workspace;
    // Load workspace once to ensure we have the latest data
    _workspaceService.getWorkspaceById(widget.workspace.id!).then((workspace) {
      if (workspace != null && mounted) {
        setState(() {
          _currentWorkspace = workspace;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _canEdit {
    if (_currentUser == null || _currentWorkspace == null) return false;
    return _currentWorkspace!.canEdit(_currentUser!.uid);
  }

  /// Cached notes stream so we don't recreate it on every build (which would
  /// reset the StreamBuilder and keep it in waiting state for new workspaces).
  Stream<List<Note>> _getNotesStreamFor(String workspaceId) {
    if (_cachedNotesWorkspaceId == workspaceId && _cachedNotesStream != null) {
      return _cachedNotesStream!;
    }
    _cachedNotesWorkspaceId = workspaceId;
    _cachedNotesStream = _notesService.getNotesStream(workspaceId);
    return _cachedNotesStream!;
  }

  Future<void> _handleCreateNote() async {
    if (_currentUser == null || _currentWorkspace == null) return;
    if (!_canEdit) {
      _showErrorSnackBar('You do not have permission to create notes');
      return;
    }

    final result = await Navigator.of(context).push<Note?>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NoteEditScreen(
          userId: _currentUser!.uid,
          workspaceId: _currentWorkspace!.id!,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );

    if (result != null && mounted) {
      _showSuccessSnackBar('Note created');
    }
  }

  Future<void> _handleEditNote(Note note) async {
    final result = await Navigator.of(context).push<Note?>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NoteEditScreen(
          note: note,
          userId: _currentUser!.uid,
          workspaceId: _currentWorkspace!.id!,
          canEdit: _canEdit,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );

    if (result != null && mounted) {
      _showSuccessSnackBar('Note updated');
    }
  }

  Future<void> _handleDeleteNote(Note note, {bool showUndo = true}) async {
    if (!_canEdit) {
      _showErrorSnackBar('You do not have permission to delete notes');
      return;
    }

    if (note.id == null) return;

    final noteId = note.id!;
    final noteTitle = note.title.isEmpty ? 'Untitled' : note.title;

    try {
      await _notesService.deleteNote(noteId);
      if (mounted && showUndo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Note "$noteTitle" deleted',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Theme.of(context).colorScheme.primary,
              onPressed: () async {
                try {
                  await _notesService.createNote(note);
                } catch (e) {
                  if (mounted) {
                    _showErrorSnackBar('Failed to restore note');
                  }
                }
              },
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Delete failed: ${e.toString()}');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Note> _filterNotes(List<Note> notes) {
    if (_searchQuery.isEmpty) return notes;
    final query = _searchQuery.toLowerCase();
    return notes.where((note) {
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null || _currentWorkspace == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // Use StreamBuilder to listen for workspace updates in real-time
    return StreamBuilder<Workspace?>(
      stream: _workspaceService.getWorkspaceStream(widget.workspace.id!),
      builder: (context, workspaceSnapshot) {
        // Handle loading state
        if (workspaceSnapshot.connectionState == ConnectionState.waiting &&
            workspaceSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.workspace.name),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle error state
        if (workspaceSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.workspace.name),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading workspace',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    workspaceSnapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Use the latest workspace from stream, or fallback to widget.workspace
        final workspace =
            workspaceSnapshot.data ?? _currentWorkspace ?? widget.workspace;

        // Ensure workspace has an ID
        if (workspace.id == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
            ),
            body: const Center(
              child: Text('Invalid workspace'),
            ),
          );
        }

        // Update _currentWorkspace when stream updates
        if (workspaceSnapshot.hasData && workspaceSnapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentWorkspace != workspaceSnapshot.data) {
              setState(() {
                _currentWorkspace = workspaceSnapshot.data;
              });
            }
          });
        }

        // Check edit permissions with current workspace
        final canEdit =
            _currentUser != null && workspace.canEdit(_currentUser!.uid);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  workspace.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  workspace
                      .getRoleForUser(_currentUser!.uid)
                      .value
                      .toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
            actions: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  tooltip: 'Close search',
                )
              else ...[
                // Show members management button only for owners
                if (workspace.ownerId == _currentUser!.uid)
                  IconButton(
                    icon: const Icon(Icons.people_rounded),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => WorkspaceMembersScreen(
                            workspace: workspace,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Manage Members',
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                  tooltip: 'Search',
                ),
              ],
            ],
          ),
          body: _isSearching
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                )
              : StreamBuilder<List<Note>>(
                  stream: _getNotesStreamFor(workspace.id!),
                  builder: (context, snapshot) {
                    // Show loading only when truly waiting for initial data
                    // Once stream is active or done, proceed (even if empty list)
                    // This prevents infinite loader when new space has 0 notes
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    // Once stream is active or done, proceed with data (or empty list)
                    // This ensures we don't show loader indefinitely for new spaces

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 64,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading notes',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              // Check if it's a missing index error
                              if (snapshot.error.toString().contains('index'))
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Missing Firestore Index',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'You need to create a composite index in Firebase Console.',
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Collection: notes\nFields: workspaceId (Ascending), createdAt (Descending)',
                                          style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }

                    final allNotes = snapshot.data ?? [];
                    final filteredNotes = _filterNotes(allNotes);

                    if (allNotes.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.note_add_rounded,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No notes yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                canEdit
                                    ? 'Create your first note in this workspace'
                                    : 'No notes in this workspace yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (filteredNotes.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return _buildNoteCard(note, index, canEdit);
                        },
                      ),
                    );
                  },
                ),
          floatingActionButton: canEdit
              ? FloatingActionButton.extended(
                  onPressed: _handleCreateNote,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Note'),
                  elevation: 4,
                )
              : null,
        );
      },
    );
  }

  Widget _buildNoteCard(Note note, int index, bool canEdit) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Dismissible(
        key: Key(note.id ?? 'note-$index'),
        direction:
            _canEdit ? DismissDirection.endToStart : DismissDirection.none,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.error,
                Theme.of(context).colorScheme.error.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        onDismissed: (direction) {
          _handleDeleteNote(note, showUndo: true);
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => _handleEditNote(note),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (canEdit)
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_rounded,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _handleEditNote(note);
                            } else if (value == 'delete') {
                              _handleDeleteNote(note, showUndo: false);
                            }
                          },
                        ),
                    ],
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      note.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(note.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final dateFormat = now.year == date.year;

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      if (dateFormat) {
        return '${months[date.month - 1]} ${date.day}';
      } else {
        return '${months[date.month - 1]} ${date.day}, ${date.year}';
      }
    }
  }
}
