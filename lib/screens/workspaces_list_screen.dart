import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/workspace.dart';
import '../services/auth_service.dart';
import '../services/workspace_service.dart';
import '../services/invitation_service.dart';
import 'workspace_notes_screen.dart';

class WorkspacesListScreen extends StatefulWidget {
  const WorkspacesListScreen({super.key});

  @override
  State<WorkspacesListScreen> createState() => _WorkspacesListScreenState();
}

class _WorkspacesListScreenState extends State<WorkspacesListScreen> {
  final WorkspaceService _workspaceService = WorkspaceService();
  final InvitationService _invitationService = InvitationService();
  final AuthService _authService = AuthService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
  }

  Future<void> _handleCreateWorkspace() async {
    if (_currentUser == null) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Workspace Name',
                hintText: 'e.g., My Startup Team',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'What is this workspace for?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final workspace = await _workspaceService.createWorkspace(
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
          ownerId: _currentUser!.uid,
        );

        if (mounted) {
          _showSuccessSnackBar('Workspace created');
          // Navigate to workspace notes
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WorkspaceNotesScreen(workspace: workspace),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Failed to create workspace: $e');
        }
      }
    }
  }

  Future<void> _handleInviteTeammate(Workspace workspace) async {
    if (_currentUser == null) return;
    if (workspace.ownerId != _currentUser!.uid) {
      _showErrorSnackBar('Only workspace owners can invite members');
      return;
    }

    // Show role selection
    WorkspaceRole? selectedRole;
    final roleResult = await showDialog<WorkspaceRole>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Invite Teammate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select role for the new member:'),
            const SizedBox(height: 16),
            RadioListTile<WorkspaceRole>(
              title: const Text('Editor'),
              subtitle: const Text('Can create, edit, and delete notes'),
              value: WorkspaceRole.editor,
              groupValue: selectedRole,
              onChanged: (value) {
                selectedRole = value;
                Navigator.of(context).pop(value);
              },
            ),
            RadioListTile<WorkspaceRole>(
              title: const Text('Viewer'),
              subtitle: const Text('Can only view notes'),
              value: WorkspaceRole.viewer,
              groupValue: selectedRole,
              onChanged: (value) {
                selectedRole = value;
                Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (roleResult == null) return;
    selectedRole = roleResult;

    try {
      final invitation = await _invitationService.createInvitation(
        workspaceId: workspace.id!,
        createdBy: _currentUser!.uid,
        role: selectedRole!,
      );

      // Generate invitation link - handle web and mobile differently
      String? baseUrl;
      bool isDevelopment = true; // Set to false for production
      
      if (kIsWeb) {
        try {
          final uri = Uri.base;
          // Only use HTTP/HTTPS schemes, ignore file:// or other schemes
          if (uri.hasScheme && 
              uri.hasAuthority && 
              (uri.scheme == 'http' || uri.scheme == 'https')) {
            baseUrl = '${uri.scheme}://${uri.authority}';
            // If using localhost, it's development
            if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
              isDevelopment = true;
            } else {
              isDevelopment = false;
            }
          }
        } catch (e) {
          // If Uri.base fails, use default
          baseUrl = null;
        }
      }
      
      final link = _invitationService.generateInvitationLink(
        invitation.token,
        baseUrl: baseUrl,
        isDevelopment: isDevelopment,
      );
      
      // Validate the link is a proper HTTP/HTTPS URL before showing
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        if (mounted) {
          _showErrorSnackBar(
            'Invalid URL format. Please configure your app domain in invitation_service.dart'
          );
        }
        return;
      }

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.link, color: Colors.blue),
                SizedBox(width: 12),
                Text('Invitation Link'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share this link with your teammate:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    link,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  _showSuccessSnackBar('Link copied to clipboard');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Link'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to create invitation: $e');
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _authService.signOut();
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Logout failed: ${e.toString()}');
        }
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade300,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'My Workspaces',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Workspace>>(
        stream: _workspaceService.getWorkspacesStream(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
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
                    'Error loading workspaces',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final workspaces = snapshot.data ?? [];

          if (workspaces.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspaces_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'No workspaces yet',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first workspace to get started',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _handleCreateWorkspace,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Workspace'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workspaces.length,
            itemBuilder: (context, index) {
              final workspace = workspaces[index];
              final isOwner = workspace.ownerId == _currentUser!.uid;
              final role = workspace.getRoleForUser(_currentUser!.uid);

              return Card(
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => WorkspaceNotesScreen(workspace: workspace),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workspace.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (workspace.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      workspace.description,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Owner',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role.value.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.people_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${workspace.members.length + 1} member${workspace.members.length + 1 == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const Spacer(),
                            if (isOwner)
                              IconButton(
                                icon: const Icon(Icons.person_add_rounded),
                                onPressed: () => _handleInviteTeammate(workspace),
                                tooltip: 'Invite teammate',
                                iconSize: 20,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleCreateWorkspace,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Workspace'),
        elevation: 4,
      ),
    );
  }
}
