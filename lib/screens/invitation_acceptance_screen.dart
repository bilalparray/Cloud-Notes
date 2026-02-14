import 'package:flutter/material.dart';
import '../models/invitation.dart';
import '../models/workspace.dart';
import '../services/auth_service.dart';
import '../services/invitation_service.dart';
import '../services/workspace_service.dart';
import 'workspaces_list_screen.dart';
import 'workspace_notes_screen.dart';

class InvitationAcceptanceScreen extends StatefulWidget {
  final String token;

  const InvitationAcceptanceScreen({
    super.key,
    required this.token,
  });

  @override
  State<InvitationAcceptanceScreen> createState() =>
      _InvitationAcceptanceScreenState();
}

class _InvitationAcceptanceScreenState
    extends State<InvitationAcceptanceScreen> {
  final InvitationService _invitationService = InvitationService();
  final WorkspaceService _workspaceService = WorkspaceService();
  final AuthService _authService = AuthService();

  Invitation? _invitation;
  Workspace? _workspace;
  bool _isLoading = true;
  String? _error;
  bool _isProcessing = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
    // Listen for auth state changes to reload invitation after sign-in
    _authService.authStateChanges.listen((user) {
      if (user != null && _invitation != null && _workspace == null) {
        // User just signed in, reload invitation to get workspace details
        _loadInvitation();
      }
    });
  }

  Future<void> _loadInvitation() async {
    try {
      final invitation =
          await _invitationService.getInvitationByToken(widget.token);

      if (invitation == null) {
        setState(() {
          _error = 'Invitation not found';
          _isLoading = false;
        });
        return;
      }

      if (!invitation.isValid) {
        setState(() {
          _error = invitation.isUsed
              ? 'This invitation has already been used'
              : 'This invitation has expired';
          _isLoading = false;
        });
        return;
      }

      // Try to load workspace - if it fails due to permissions, we'll show invitation without workspace details
      Workspace? workspace;
      try {
        workspace =
            await _workspaceService.getWorkspaceById(invitation.workspaceId);
      } catch (e) {
        // If workspace can't be loaded (permission denied), we'll show invitation without workspace details
        // User will see workspace details after signing in
        debugPrint('Could not load workspace: $e');
      }

      setState(() {
        _invitation = invitation;
        _workspace = workspace; // May be null if permission denied
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load invitation: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAcceptInvitation() async {
    if (_invitation == null || _workspace == null) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      // User needs to sign in first
      // This should be handled by the auth wrapper, but just in case
      _showErrorSnackBar('Please sign in first');
      return;
    }

    // Check if user is already a member
    final isAlreadyMember = _workspace!.ownerId == currentUser.uid ||
        _workspace!.members.containsKey(currentUser.uid);

    // If user is owner, they can't change their role
    if (_workspace!.ownerId == currentUser.uid) {
      // User is owner, just navigate
      if (mounted) {
        _showSuccessSnackBar('You are the owner of this workspace');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => WorkspaceNotesScreen(workspace: _workspace!),
          ),
          (route) => route.isFirst,
        );
      }
      return;
    }

    // If user is already a member, check if role needs to be updated
    final currentRole = isAlreadyMember
        ? WorkspaceRole.fromString(
            _workspace!.members[currentUser.uid] ?? 'viewer')
        : null;
    final newRole = WorkspaceRole.fromString(_invitation!.role);

    // If already a member with the same role, just navigate
    if (isAlreadyMember && currentRole == newRole) {
      if (mounted) {
        _showSuccessSnackBar('You already have ${newRole.value} access');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => WorkspaceNotesScreen(workspace: _workspace!),
          ),
          (route) => route.isFirst,
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Add or update user role in workspace
      // This will add new members or update existing member roles
      await _workspaceService.addMemberToWorkspace(
        workspaceId: _workspace!.id!,
        userId: currentUser.uid,
        role: newRole,
        displayName: currentUser.displayName,
        email: currentUser.email,
      );

      // Mark invitation as used
      await _invitationService.markInvitationAsUsed(
        invitationId: _invitation!.id!,
        usedBy: currentUser.uid,
      );

      // Small delay to ensure Firestore has propagated the update
      await Future.delayed(const Duration(milliseconds: 500));

      // Get updated workspace - retry a few times to ensure we get the latest data
      Workspace? updatedWorkspace;
      for (int i = 0; i < 3; i++) {
        updatedWorkspace =
            await _workspaceService.getWorkspaceById(_workspace!.id!);
        if (updatedWorkspace != null) {
          // Verify the role was actually updated
          final actualRole = updatedWorkspace.getRoleForUser(currentUser.uid);
          if (actualRole == newRole || i == 2) {
            // Role matches or we've tried enough times
            break;
          }
          // Wait a bit more and try again
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (mounted && updatedWorkspace != null) {
        // Show appropriate message based on whether role was updated or user joined
        final actualRole = updatedWorkspace.getRoleForUser(currentUser.uid);
        if (isAlreadyMember) {
          if (actualRole == newRole) {
            _showSuccessSnackBar(
                'Role updated to ${newRole.value.toUpperCase()}!');
          } else {
            _showSuccessSnackBar(
                'Role update in progress... (Current: ${actualRole.value.toUpperCase()})');
          }
        } else {
          _showSuccessSnackBar(
              'Successfully joined workspace as ${newRole.value.toUpperCase()}!');
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                WorkspaceNotesScreen(workspace: updatedWorkspace!),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showErrorSnackBar('Failed to accept invitation: $e');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Loading invitation...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Invalid Invitation',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const WorkspacesListScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Go to Workspaces'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_invitation == null || _workspace == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final currentUser = _authService.currentUser;
    final isAlreadyMember = currentUser != null &&
        (_workspace!.ownerId == currentUser.uid ||
            _workspace!.members.containsKey(currentUser.uid));
    
    // Check if user needs role update
    WorkspaceRole? currentRole;
    WorkspaceRole? invitationRole;
    bool needsRoleUpdate = false;
    
    if (currentUser != null && isAlreadyMember) {
      if (_workspace!.ownerId == currentUser.uid) {
        currentRole = WorkspaceRole.owner;
      } else {
        currentRole = WorkspaceRole.fromString(
            _workspace!.members[currentUser.uid] ?? 'viewer');
      }
      invitationRole = WorkspaceRole.fromString(_invitation!.role);
      needsRoleUpdate = currentRole != invitationRole && 
                        currentRole != WorkspaceRole.owner;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.workspaces_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'You\'re Invited!',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _workspace!.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (_workspace!.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _workspace!.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Role: ${_invitation!.role.toUpperCase()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (currentUser == null)
                  Column(
                    children: [
                      Text(
                        'Please sign in to accept this invitation',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSigningIn
                            ? null
                            : () async {
                                setState(() {
                                  _isSigningIn = true;
                                });
                                try {
                                  await _authService.signInWithGoogle();
                                  // After sign in, reload the invitation to get workspace details
                                  // and show accept button
                                  if (mounted) {
                                    await _loadInvitation();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _isSigningIn = false;
                                    });
                                    _showErrorSnackBar('Sign in failed: $e');
                                  }
                                }
                              },
                        icon: _isSigningIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_isSigningIn ? 'Signing in...' : 'Sign In'),
                      ),
                    ],
                  )
                else if (isAlreadyMember && !needsRoleUpdate)
                  Column(
                    children: [
                      Text(
                        'You are already a member of this workspace',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (currentRole != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Current role: ${currentRole.value.toUpperCase()}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  WorkspaceNotesScreen(workspace: _workspace!),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Open Workspace'),
                      ),
                    ],
                  )
                else if (isAlreadyMember && needsRoleUpdate)
                  Column(
                    children: [
                      Text(
                        'Update Your Role',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You are currently ${currentRole?.value.toUpperCase() ?? 'UNKNOWN'}. Accept this invitation to become ${invitationRole?.value.toUpperCase() ?? 'UNKNOWN'}.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isProcessing ? null : _handleAcceptInvitation,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.upgrade_rounded),
                        label: Text(
                            _isProcessing
                                ? 'Updating Role...'
                                : 'Update to ${invitationRole?.value.toUpperCase() ?? 'UNKNOWN'}'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: _isProcessing ? null : _handleAcceptInvitation,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                        _isProcessing ? 'Joining...' : 'Accept Invitation'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
