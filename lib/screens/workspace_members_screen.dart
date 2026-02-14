import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/workspace.dart';
import '../services/auth_service.dart';
import '../services/workspace_service.dart';

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

  Future<void> _handleUpdateInviteSettings(Workspace workspace, bool inviteEnabled, String? inviteRole) async {
    if (workspace.id == null) return;
    try {
      await _workspaceService.updateWorkspaceInvite(
        workspaceId: workspace.id!,
        inviteEnabled: inviteEnabled,
        inviteRole: inviteRole,
      );
      if (mounted) _showSuccessSnackBar(inviteEnabled ? 'Invite enabled' : 'Invite disabled');
    } catch (e) {
      if (mounted) _showErrorSnackBar(e.toString());
    }
  }

  void _showQrCodeDialog(String inviteCode) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Invite code – QR'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scan to get the invite code',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 232,
                  height: 232,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: QrImageView(
                      data: inviteCode,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  inviteCode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              HapticFeedback.lightImpact();
              _showSuccessSnackBar('Invite code copied');
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy code'),
          ),
        ],
      ),
    );
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

        return Scaffold(
          appBar: AppBar(title: const Text('Workspace Members')),
          body: _buildMembersTab(workspace),
        );
      },
    );
  }

  Widget _buildMembersTab(Workspace workspace) {
    final members = workspace.members.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isOwner && workspace.id != null) _buildShareWorkspaceCard(workspace),
        if (_isOwner && workspace.id != null) const SizedBox(height: 16),
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

  Widget _buildShareWorkspaceCard(Workspace workspace) {
    final inviteRole = workspace.inviteRole ?? 'viewer';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Share workspace',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Allow others to join with the invite code. Set the role they will get.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: inviteRole == 'editor' ? 'editor' : 'viewer',
                    decoration: const InputDecoration(
                      labelText: 'Role for new members',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'editor', child: Text('Editor')),
                      DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await _handleUpdateInviteSettings(workspace, workspace.inviteEnabled, value);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Text('Allow join', style: Theme.of(context).textTheme.bodyMedium),
                Switch(
                  value: workspace.inviteEnabled,
                  onChanged: (v) async {
                    await _handleUpdateInviteSettings(workspace, v, workspace.inviteRole ?? inviteRole);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            if (workspace.inviteEnabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        workspace.id!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _showQrCodeDialog(workspace.id!),
                    icon: const Icon(Icons.qr_code_rounded),
                    tooltip: 'Show QR code',
                  ),
                  IconButton.filled(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: workspace.id!));
                      HapticFeedback.lightImpact();
                      _showSuccessSnackBar('Invite code copied');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copy code',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Share this code or QR code. Others enter it in "Join a workspace" and tap Accept.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
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

}
