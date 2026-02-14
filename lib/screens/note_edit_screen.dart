import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note.dart';
import '../services/note_image_service.dart';
import '../services/notes_service.dart';
import '../widgets/note_image_preview_stub.dart' if (dart.library.html) '../widgets/note_image_preview_web.dart' as image_preview;

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final String userId;
  final String workspaceId;
  /// If false, note is shown read-only (viewer); copy still works, editing and save are disabled.
  final bool canEdit;

  const NoteEditScreen({
    super.key,
    this.note,
    required this.userId,
    required this.workspaceId,
    this.canEdit = true,
  });

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final NotesService _notesService = NotesService();
  final NoteImageService _imageService = NoteImageService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isAutoSaving = false;
  bool _isUploadingImage = false;
  DateTime? _lastSaveTime;
  Timer? _autoSaveTimer;
  List<String> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _imageUrls = List.from(widget.note!.imageUrls);
    }
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // Auto-focus content if creating new note
    if (widget.note == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contentFocusNode.requestFocus();
      });
    }
  }

  void _onTextChanged() {
    if (!widget.canEdit) return;
    // Update UI immediately for word/char count
    setState(() {
      _hasChanges = true;
      _isSaving = false;
    });

    // Reset auto-save timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_hasChanges && mounted) {
        _autoSave();
      }
    });
  }

  Future<void> _autoSave() async {
    if (!widget.canEdit) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Don't auto-save empty notes
    if (title.isEmpty && content.isEmpty) {
      return;
    }

    // Don't auto-save if it's a new note (need to create it first manually)
    if (widget.note == null) {
      return;
    }

    setState(() {
      _isAutoSaving = true;
    });

    try {
      final note = Note(
        id: widget.note!.id,
        title: title,
        content: content,
        createdAt: widget.note!.createdAt,
        updatedAt: DateTime.now(),
        userId: widget.userId,
        workspaceId: widget.workspaceId,
        isPinned: widget.note!.isPinned,
        imageUrls: _imageUrls,
      );

      await _notesService.updateNote(note);

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isAutoSaving = false;
          _lastSaveTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
        });
        // Silently fail for auto-save, user can manually save
      }
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!widget.canEdit) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      HapticFeedback.lightImpact();
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Note cannot be empty',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
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
      return;
    }

    setState(() {
      _isLoading = true;
      _isSaving = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final now = DateTime.now();
      final note = Note(
        id: widget.note?.id,
        title: title,
        content: content,
        createdAt: widget.note?.createdAt ?? now,
        updatedAt: now,
        userId: widget.userId,
        workspaceId: widget.workspaceId,
        isPinned: widget.note?.isPinned ?? false,
        imageUrls: _imageUrls,
      );

      if (widget.note == null) {
        await _notesService.createNote(note);
      } else {
        await _notesService.updateNote(note);
      }

      setState(() {
        _hasChanges = false;
        _lastSaveTime = DateTime.now();
      });

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(note);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade300,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to save: ${e.toString()}',
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
            action: SnackBarAction(
              label: 'Retry',
              textColor: Theme.of(context).colorScheme.onErrorContainer,
              onPressed: _handleSave,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
      }
    }
  }

  void _copyTitle() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Nothing to copy');
      return;
    }
    Clipboard.setData(ClipboardData(text: title));
    HapticFeedback.lightImpact();
    _showSnackBar('Title copied');
  }

  void _copyContent() {
    final content = _contentController.text;
    if (content.isEmpty) {
      _showSnackBar('Nothing to copy');
      return;
    }
    Clipboard.setData(ClipboardData(text: content));
    HapticFeedback.lightImpact();
    _showSnackBar('Content copied');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (widget.note?.id == null || !widget.canEdit) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await _imageService.uploadImageBytes(
        workspaceId: widget.workspaceId,
        noteId: widget.note!.id!,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _imageUrls = [..._imageUrls, url];
        _isUploadingImage = false;
      });
      await _notesService.updateNote(widget.note!.copyWith(
        imageUrls: _imageUrls,
        updatedAt: DateTime.now(),
      ));
      if (mounted) _showSnackBar('Image added');
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showSnackBar('Failed to add image: $e');
      }
    }
  }

  Future<void> _removeImage(String url) async {
    if (!widget.canEdit || widget.note?.id == null) return;
    setState(() => _imageUrls = _imageUrls.where((u) => u != url).toList());
    try {
      await _notesService.updateNote(widget.note!.copyWith(
        imageUrls: _imageUrls,
        updatedAt: DateTime.now(),
      ));
      if (mounted) _showSnackBar('Image removed');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to remove image');
    }
  }

  Future<void> _downloadImage(String imageUrl) async {
    try {
      if (kIsWeb) {
        await launchUrl(Uri.parse(imageUrl), mode: LaunchMode.platformDefault);
        return;
      }
      final bytes = await _imageService.getImageBytes(imageUrl);
      await Gal.putImageBytes(Uint8List.fromList(bytes));
      if (mounted) _showSnackBar('Image saved to gallery');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to save image: $e');
    }
  }

  Widget _buildImageTile(String url, ColorScheme colorScheme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: image_preview.buildNoteImagePreview(
            url: url,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child ?? const SizedBox.shrink();
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          (loadingProgress.expectedTotalBytes ?? 1)
                      : null,
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: colorScheme.error),
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.download_rounded, size: 18),
                onPressed: () => _downloadImage(url),
                tooltip: 'Save image',
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurface,
                ),
              ),
              if (widget.canEdit)
                IconButton.filled(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _removeImage(url),
                  tooltip: 'Remove image',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _handleBack() async {
    // Cancel any pending auto-save
    _autoSaveTimer?.cancel();

    // If there's an auto-save in progress, wait a bit
    if (_isAutoSaving) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!_hasChanges) {
      return true;
    }

    HapticFeedback.lightImpact();
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Discard changes?'),
          ],
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
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
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  int get _wordCount {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  int get _charCount => _contentController.text.length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _handleBack();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.note == null
                    ? 'New Note'
                    : (widget.canEdit ? 'Edit Note' : 'View Note'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (!widget.canEdit)
                Text(
                  'View only',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                )
              else if (_isSaving || _isAutoSaving || _lastSaveTime != null)
                Row(
                  children: [
                    if (_isSaving || _isAutoSaving)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: Colors.green.shade400,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isSaving
                          ? 'Saving...'
                          : _isAutoSaving
                              ? 'Auto-saving...'
                              : 'Saved ${_formatSaveTime(_lastSaveTime!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.title_rounded),
                onPressed: _copyTitle,
                tooltip: 'Copy title',
              ),
              IconButton(
                icon: const Icon(Icons.content_copy_rounded),
                onPressed: _copyContent,
                tooltip: 'Copy content',
              ),
              if (widget.canEdit)
                IconButton(
                  icon: const Icon(Icons.check_rounded),
                  onPressed: _handleSave,
                  tooltip: 'Save',
                ),
            ],
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      readOnly: !widget.canEdit,
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          fontSize: 24,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      readOnly: !widget.canEdit,
                      decoration: InputDecoration(
                        hintText: 'Start writing...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                    ),
                    if (_imageUrls.isNotEmpty || (widget.canEdit && widget.note != null)) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'Images',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (widget.canEdit && widget.note != null) ...[
                            const SizedBox(width: 12),
                            if (_isUploadingImage)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.add_photo_alternate_rounded),
                                onPressed: _pickAndUploadImage,
                                tooltip: 'Add image',
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.primaryContainer,
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _imageUrls.map((url) => _buildImageTile(url, colorScheme)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_wordCount words',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.abc_rounded,
                        size: 16,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_charCount chars',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                  if (widget.canEdit && _hasChanges && !_isSaving && !_isAutoSaving)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Unsaved',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSaveTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}
