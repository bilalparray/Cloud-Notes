import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/workspace.dart';
import '../models/invitation.dart';
import '../services/auth_service.dart';
import '../services/workspace_service.dart';
import '../services/invitation_service.dart';

class WorkspaceMembersScreen extends StatefulWidget {
  final Workspace workspace;

  const WorkspaceMembersScreen({
    super.key,
    required this.workspace,
  });

  @override
  State<WorkspaceMembersScreen> createState() => _WorkspaceMembersScreenState();
}

class _WorkspaceMembersScreenState extends State<WorkspaceMembersScreen> {
  final WorkspaceService _workspaceService = WorkspaceService();
  final InvitationService _invitationService = InvitationService();
  final AuthService _authService = AuthService();
  User? _currentUser;
  Workspace? _currentWorkspace;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _currentWorkspace = widget.workspace;
  }

  bool get _isOwner {
    return _currentUser != null &&
        _currentWorkspace != null &&
        _currentWorkspace!.ownerId == _currentUser!.uid;
  }

  Future<void> _handleUpdateMemberRole(String userId, WorkspaceRole newRole) async {
    if (!_isOwner || _currentWorkspace == null || _currentWorkspace!.id == null) {
      _showErrorSnackBar('Invalid workspace or permission denied');
      return;
    }

    // Show loading indicator
    if (mounted) {
      _showSuccessSnackBar('Updating role...');
    }

    try {
      await _workspaceService.updateMemberRole(
        workspaceId: _currentWorkspace!.id!,
        userId: userId,
        newRole: newRole,
      );

      // Small delay to ensure Firestore has propagated
      await Future.delayed(const Duration(milliseconds: 500));

      // Refresh workspace - retry a few times to get latest data
      Workspace? updated;
      for (int i = 0; i < 3; i++) {
        updated = await _workspaceService.getWorkspaceById(_currentWorkspace!.id!);
        if (updated != null) {
          // Verify the role was actually updated
          final actualRole = WorkspaceRole.fromString(updated.members[userId] ?? 'viewer');
          if (actualRole == newRole || i == 2) {
            // Role matches or we've tried enough times
            break;
          }
          // Wait a bit more and try again
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (updated != null && mounted) {
        setState(() {
          _currentWorkspace = updated;
        });
        _showSuccessSnackBar('Role updated to ${newRole.value.toUpperCase()}');
      } else if (mounted) {
        _showErrorSnackBar('Role update may still be processing...');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update role: $e');
      }
    }
  }

  Future<void> _handleRemoveMember(String userId) async {
    if (!_isOwner || _currentWorkspace == null) return;

    final memberRole = WorkspaceRole.fromString(
        _currentWorkspace!.members[userId] ?? 'viewer');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.person_remove_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            const Text('Remove Member'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove this ${memberRole.value} from the workspace?',
        ),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _workspaceService.removeMemberFromWorkspace(
        workspaceId: _currentWorkspace!.id!,
        userId: userId,
      );

      // Refresh workspace
      final updated = await _workspaceService.getWorkspaceById(_currentWorkspace!.id!);
      if (updated != null && mounted) {
        setState(() {
          _currentWorkspace = updated;
        });
      }

      if (mounted) {
        _showSuccessSnackBar('Member removed successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to remove member: $e');
      }
    }
  }

  Future<void> _handleCreateInvitation(Workspace workspace) async {
    if (!_isOwner || _currentUser == null) return;

    // Show role selection
    WorkspaceRole? selectedRole;
    final roleResult = await showDialog<WorkspaceRole>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Invitation'),
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

      // Generate invitation link
      String? baseUrl;
      bool isDevelopment = true;
      
      if (kIsWeb) {
        try {
          final uri = Uri.base;
          if (uri.hasScheme && 
              uri.hasAuthority && 
              (uri.scheme == 'http' || uri.scheme == 'https')) {
            // Include the full path (including /cloudnotes) for subdirectory deployment
            String path = uri.path;
            // Remove trailing slash if present
            if (path.endsWith('/') && path.length > 1) {
              path = path.substring(0, path.length - 1);
            }
            baseUrl = '${uri.scheme}://${uri.authority}$path';
            if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
              isDevelopment = true;
            } else {
              isDevelopment = false;
            }
          }
        } catch (e) {
          baseUrl = null;
        }
      }
      
      final link = _invitationService.generateInvitationLink(
        invitation.token,
        baseUrl: baseUrl,
        isDevelopment: isDevelopment,
      );

      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        if (mounted) {
          _showErrorSnackBar('Invalid URL format');
        }
        return;
      }

      // Show link dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Invitation Created',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
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
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

  Future<void> _handleCopyInvitationLink(Invitation invitation) async {
    if (!_isOwner) return;

    try {
      String? baseUrl;
      bool isDevelopment = true;
      
      if (kIsWeb) {
        try {
          final uri = Uri.base;
          if (uri.hasScheme && 
              uri.hasAuthority && 
              (uri.scheme == 'http' || uri.scheme == 'https')) {
            // Include the full path (including /cloudnotes) for subdirectory deployment
            String path = uri.path;
            // Remove trailing slash if present
            if (path.endsWith('/') && path.length > 1) {
              path = path.substring(0, path.length - 1);
            }
            baseUrl = '${uri.scheme}://${uri.authority}$path';
            if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
              isDevelopment = true;
            } else {
              isDevelopment = false;
            }
          }
        } catch (e) {
          baseUrl = null;
        }
      }
      
      final link = _invitationService.generateInvitationLink(
        invitation.token,
        baseUrl: baseUrl,
        isDevelopment: isDevelopment,
      );

      await Clipboard.setData(ClipboardData(text: link));
      HapticFeedback.lightImpact();
      _showSuccessSnackBar('Invitation link copied to clipboard');
    } catch (e) {
      _showErrorSnackBar('Failed to copy link: $e');
    }
  }

  Future<void> _handleDeleteInvitation(String invitationId) async {
    if (!_isOwner) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.delete_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            const Text('Delete Invitation'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this invitation? It will no longer be usable.',
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _invitationService.deleteInvitation(invitationId);
      if (mounted) {
        _showSuccessSnackBar('Invitation deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete invitation: $e');
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
        duration: const Duration(seconds: 3),
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
                  fontSize: 16,
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
    if (!_isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Members'),
        ),
        body: Center(
          child: Text(
            'Only workspace owners can manage members',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return StreamBuilder<Workspace?>(
      stream: _workspaceService.getWorkspaceStream(widget.workspace.id!),
      builder: (context, workspaceSnapshot) {
        final workspace = workspaceSnapshot.data ?? _currentWorkspace ?? widget.workspace;
        
        if (workspaceSnapshot.hasData && workspaceSnapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentWorkspace != workspaceSnapshot.data) {
              setState(() {
                _currentWorkspace = workspaceSnapshot.data;
              });
            }
          });
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Workspace Members'),
              bottom: TabBar(
                tabs: const [
                  Tab(icon: Icon(Icons.people_rounded), text: 'Members'),
                  Tab(icon: Icon(Icons.mail_rounded), text: 'Invitations'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildMembersTab(workspace),
                _buildInvitationsTab(workspace),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersTab(Workspace workspace) {
    final members = workspace.members.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Owner section
        StreamBuilder<User?>(
          stream: _authService.authStateChanges,
          builder: (context, authSnapshot) {
            // Try to get owner name - if current user is owner, use their name
            final ownerName = workspace.ownerId == _currentUser?.uid
                ? (_currentUser?.displayName ?? 
                   _currentUser?.email?.split('@').first ?? 
                   'Owner')
                : workspace.getMemberName(workspace.ownerId) ?? 'Owner';
            
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(ownerName),
                subtitle: const Text('Workspace creator'),
                trailing: Chip(
                  label: const Text('OWNER'),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        
        // Members section
        if (members.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No members yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invite members to collaborate',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          )
        else
          ...members.map((entry) {
            final userId = entry.key;
            final role = WorkspaceRole.fromString(entry.value);
            final memberName = workspace.getMemberName(userId) ?? 
                              (userId == _currentUser?.uid 
                                ? _currentUser?.displayName ?? _currentUser?.email?.split('@').first
                                : null) ??
                              'Member ${userId.substring(0, 8)}...';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: role == WorkspaceRole.editor
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.tertiaryContainer,
                  child: Icon(
                    role == WorkspaceRole.editor
                        ? Icons.edit_rounded
                        : Icons.visibility_rounded,
                    color: role == WorkspaceRole.editor
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                title: Text(
                  memberName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  '${role.value.toUpperCase()} • ${userId.substring(0, 16)}...',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'change_role',
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Text('Change Role'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Remove',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'change_role') {
                      _showRoleChangeDialog(userId, role);
                    } else if (value == 'remove') {
                      _handleRemoveMember(userId);
                    }
                  },
                ),
                isThreeLine: false,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildInvitationsTab(Workspace workspace) {
    if (workspace.id == null) {
      return const Center(child: Text('Invalid workspace'));
    }

    return StreamBuilder<List<Invitation>>(
      stream: _invitationService.getInvitationsForWorkspace(workspace.id!),
      builder: (context, snapshot) {
        // Show loading only on initial load
        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

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
                    'Error loading invitations',
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
                  if (snapshot.error.toString().contains('index') ||
                      snapshot.error.toString().contains('requires an index'))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Missing Firestore Index',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You need to create a composite index in Firebase Console.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Collection: invitations\nFields: workspaceId (Ascending), createdAt (Descending)',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
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

        final invitations = snapshot.data ?? [];

        return Column(
          children: [
            // Invite button at the top
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton.icon(
                onPressed: () => _handleCreateInvitation(workspace),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Create Invitation'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            // Invitations list
            if (invitations.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No invitations yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create an invitation link to share with teammates',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: invitations.length,
                  itemBuilder: (context, index) {
                    final invitation = invitations[index];
                    final role = WorkspaceRole.fromString(invitation.role);
                    final isExpired = invitation.expiresAt.isBefore(DateTime.now());
                    final isUsed = invitation.isUsed;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isUsed
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : isExpired
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            isUsed
                                ? Icons.check_circle_rounded
                                : isExpired
                                    ? Icons.error_rounded
                                    : Icons.mail_rounded,
                            color: isUsed
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : isExpired
                                    ? Theme.of(context).colorScheme.onErrorContainer
                                    : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text('${role.value.toUpperCase()} Invitation'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Token: ${invitation.token.substring(0, 16)}...',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isUsed
                                  ? 'Used by ${invitation.usedBy?.substring(0, 8) ?? 'unknown'}...'
                                  : isExpired
                                      ? 'Expired ${_formatDate(invitation.expiresAt)}'
                                      : 'Expires ${_formatDate(invitation.expiresAt)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: isUsed || isExpired
                            ? null
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'copy_link',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.link_rounded,
                                          size: 20,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Copy Link'),
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
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'copy_link') {
                                    _handleCopyInvitationLink(invitation);
                                  } else if (value == 'delete') {
                                    _handleDeleteInvitation(invitation.id!);
                                  }
                                },
                              ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );

      },
    );
  }

  void _showRoleChangeDialog(String userId, WorkspaceRole currentRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Member Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current role: ${currentRole.value.toUpperCase()}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const Text('Select new role:'),
            const SizedBox(height: 16),
            RadioListTile<WorkspaceRole>(
              title: const Text('Editor'),
              subtitle: const Text('Can create, edit, and delete notes'),
              value: WorkspaceRole.editor,
              groupValue: currentRole,
              onChanged: (value) {
                if (value != null && value != currentRole) {
                  Navigator.of(context).pop();
                  _handleUpdateMemberRole(userId, value);
                }
              },
            ),
            RadioListTile<WorkspaceRole>(
              title: const Text('Viewer'),
              subtitle: const Text('Can only view notes'),
              value: WorkspaceRole.viewer,
              groupValue: currentRole,
              onChanged: (value) {
                if (value != null && value != currentRole) {
                  Navigator.of(context).pop();
                  _handleUpdateMemberRole(userId, value);
                }
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
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} days';
    } else if (difference.inDays < 0) {
      return '${difference.inDays.abs()} days ago';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hours';
    } else if (difference.inHours < 0) {
      return '${difference.inHours.abs()} hours ago';
    } else {
      return 'soon';
    }
  }
}
