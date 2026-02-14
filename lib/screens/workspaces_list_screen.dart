import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/workspace.dart';
import '../services/auth_service.dart';
import '../services/workspace_service.dart';
import 'qr_scan_screen.dart';
import 'workspace_notes_screen.dart';

class WorkspacesListScreen extends StatefulWidget {
  const WorkspacesListScreen({super.key});

  @override
  State<WorkspacesListScreen> createState() => _WorkspacesListScreenState();
}

class _WorkspacesListScreenState extends State<WorkspacesListScreen> {
  final WorkspaceService _workspaceService = WorkspaceService();
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


  /// Returns null on success, or an error message string on failure.
  Future<String?> _handleAcceptInvite(String code) async {
    if (code.isEmpty) {
      return 'Enter an invite code';
    }
    try {
      await _workspaceService.acceptInviteByCode(code);
      if (mounted) _showSuccessSnackBar('Joined workspace');
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _userFriendlyInviteError(e);
    } catch (e) {
      return _userFriendlyInviteError(e);
    }
  }

  String _userFriendlyInviteError(dynamic e) {
    if (e is FirebaseFunctionsException) {
      final code = e.code.toString().toLowerCase();
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      if (code.contains('already') || code.contains('exists') || code == 'failed-precondition') {
        return 'You\'re already a member of this workspace.';
      }
      if (code.contains('not-found') || code.contains('invalid') || code.contains('permission')) {
        return 'Invalid or expired invite code.';
      }
      return e.code;
    }
    final s = e.toString();
    if (s.startsWith('Exception: ')) return s.replaceFirst('Exception: ', '');
    return s.isNotEmpty ? s : 'Failed to join workspace.';
  }

  Future<void> _showJoinWorkspaceModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _JoinWorkspaceSheet(
        onAccept: _handleAcceptInvite,
        onSuccessClose: () => Navigator.of(context).pop(),
        showErrorSnackBar: _showErrorSnackBar,
      ),
    );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'My Workspaces',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_authService.isDemoMode)
              Text(
                'Demo Mode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'join_workspace',
                child: Row(
                  children: [
                    Icon(
                      Icons.login_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Join workspace'),
                  ],
                ),
              ),
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
              if (value == 'join_workspace') {
                _showJoinWorkspaceModal();
              } else if (value == 'logout') {
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

          return CustomScrollView(
            slivers: [
              if (workspaces.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.workspaces_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No workspaces yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create one or join a workspace from the menu.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _handleCreateWorkspace,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create Workspace'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final workspace = workspaces[index];
                        return _buildWorkspaceCard(context, workspace);
                      },
                      childCount: workspaces.length,
                    ),
                  ),
                ),
            ],
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

  Widget _buildWorkspaceCard(BuildContext context, Workspace workspace) {
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
                    _badge(context, 'Owner', Theme.of(context).colorScheme.primaryContainer)
                  else
                    _badge(context, 'Invited', Theme.of(context).colorScheme.secondaryContainer),
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
                  if (!isOwner) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${role.value}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color bgColor) {
    final isPrimary = bgColor == Theme.of(context).colorScheme.primaryContainer;
    final textColor = isPrimary
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _JoinWorkspaceSheet extends StatefulWidget {
  final Future<String?> Function(String code) onAccept;
  final VoidCallback onSuccessClose;
  final void Function(String message) showErrorSnackBar;

  const _JoinWorkspaceSheet({
    required this.onAccept,
    required this.onSuccessClose,
    required this.showErrorSnackBar,
  });

  @override
  State<_JoinWorkspaceSheet> createState() => _JoinWorkspaceSheetState();
}

class _JoinWorkspaceSheetState extends State<_JoinWorkspaceSheet> {
  final _inviteCodeController = TextEditingController();
  bool _accepting = false;
  String? _bannerMessage;
  Timer? _bannerDismissTimer;

  @override
  void dispose() {
    _bannerDismissTimer?.cancel();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _showBanner(String message) {
    _bannerDismissTimer?.cancel();
    if (mounted) setState(() => _bannerMessage = message);
    _bannerDismissTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _bannerMessage = null);
    });
  }

  Future<void> _submit() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      _showBanner('Enter an invite code');
      return;
    }
    _bannerDismissTimer?.cancel();
    setState(() => _accepting = true);
    setState(() => _bannerMessage = null);
    try {
      final errorMessage = await widget.onAccept(code);
      if (!mounted) return;
      if (errorMessage != null) {
        _showBanner(errorMessage);
      } else {
        widget.onSuccessClose();
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _scanQrCode() async {
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted && mounted) {
          _showCameraPermissionDenied(context, permanentlyDenied: result.isPermanentlyDenied);
          return;
        }
      }
    } on Exception {
      // permission_handler can throw (e.g. MissingPluginException) if native plugin
      // isn't registered (hot reload, or platform not fully set up). Proceed to scanner;
      // opening the camera will trigger the system permission prompt if needed.
    }
    if (!mounted) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QrScanScreen(),
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      _inviteCodeController.text = code;
      _inviteCodeController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: code.length,
      );
    }
  }

  void _showCameraPermissionDenied(BuildContext context, {bool permanentlyDenied = false}) {
    final messenger = ScaffoldMessenger.of(context);
    if (permanentlyDenied) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Camera access needed'),
          content: const Text(
            'Camera permission was denied. To scan QR codes, please allow camera access in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Camera permission is needed to scan QR codes.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_bannerMessage != null) ...[
            Material(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _bannerMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: colorScheme.onErrorContainer),
                      onPressed: () {
                        _bannerDismissTimer?.cancel();
                        setState(() => _bannerMessage = null);
                      },
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Join a workspace',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the invite code shared by the workspace owner.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _inviteCodeController,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'Paste the code here or scan QR',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            onChanged: (_) {
              if (_bannerMessage != null) {
                _bannerDismissTimer?.cancel();
                setState(() => _bannerMessage = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scanQrCode,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan QR code'),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _accepting ? null : _submit,
              icon: _accepting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded, size: 20),
              label: Text(_accepting ? 'Accepting...' : 'Accept'),
            ),
          ),
        ],
      ),
    );
  }
}
