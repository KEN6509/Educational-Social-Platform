import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_input_decoration.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../data/feed_post.dart';
import '../data/posts_repository.dart';
import '../domain/content_moderation.dart';
import '../domain/post_submission_repository.dart';
import '../data/tag_catalog.dart';
import '../data/tags_repository.dart';
import '../../media/presentation/device_photo_picker_page.dart';
import 'filter_page.dart';
import 'create_post_validation.dart';
import 'post_submission_error.dart';
import 'content_moderation_scope.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    required this.onPostCreated,
    this.editPost,
    this.repository,
    super.key,
  });

  final VoidCallback onPostCreated;
  final FeedPost? editPost;
  final PostSubmissionRepository? repository;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  late final PostSubmissionRepository _repository;
  late final TagsRepository _tagsRepository;
  late Future<List<TagCategory>> _tagsFuture;

  final Set<String> _selectedTags = {};
  final List<_DraftImage> _images = [];
  bool _isSubmitting = false;
  bool get _isEditing => widget.editPost != null;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? PostsRepository(Supabase.instance.client);
    _tagsRepository = TagsRepository(Supabase.instance.client);
    _tagsFuture = _tagsRepository.fetchCatalog();
    final post = widget.editPost;
    if (post != null) {
      _titleController.text = post.title;
      _contentController.text = post.content;
      _selectedTags.addAll(post.tags.take(5));
      for (var index = 0; index < post.imageUrls.length; index += 1) {
        final storagePath = index < post.imageStoragePaths.length
            ? post.imageStoragePaths[index]
            : null;
        if (storagePath == null) continue;
        _images.add(
          _DraftImage.existing(
            url: post.imageUrls[index],
            storagePath: storagePath,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 9 - _images.length;
    if (remaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 9 images allowed')),
        );
      }
      return;
    }

    final picked = await Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        builder: (_) => DevicePhotoPickerPage(
          maxSelection: remaining,
          allowCamera: true,
        ),
      ),
    );

    if (picked == null || picked.isEmpty || !mounted) {
      return;
    }

    if (picked.length > remaining) {
      if (mounted) {
        final message = _images.isEmpty
            ? 'Only 9 images can be selected'
            : 'Only $remaining more images can be added';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }

    final drafts = <_DraftImage>[];
    for (final image in picked.take(remaining)) {
      drafts.add(
        _DraftImage.picked(
          file: image,
          bytes: await image.readAsBytes(),
        ),
      );
    }

    setState(() {
      _images.addAll(drafts);
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _openTagSelection() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (context) => FilterPage(
          initialSelectedTags: _selectedTags,
          tagsFuture: _tagsFuture,
          isSelectionMode: true,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedTags.clear();
        // Limit to 5 tags
        _selectedTags.addAll(result.take(5));
      });
    }
  }

  String? _findTagNameFromCatalog(String slug) {
    if (slug == 'others') return 'Others';
    // This is a bit inefficient but fine for small lists
    for (final category in TagCatalog.fallback) {
      for (final tag in category.tags) {
        if (tag.slug == slug) return tag.name;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!canSubmitPostBody(
      content: _contentController.text,
      imageCount: _images.length,
    )) {
      _showSubmissionError(
        'Add an image or write some content before posting.',
      );
      return;
    }

    if (!await hasInternetConnection()) {
      if (!mounted) return;
      _showSubmissionError(
        'No internet connection. Connect to the internet before posting.',
      );
      return;
    }

    if (_isEditing) {
      final confirmed = await _showEditConfirmation();
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final pickedImages = _images
          .where((image) => image.isPicked)
          .map(
            (image) => PickedPostImage(
              name: image.file!.name,
              bytes: image.bytes!,
              contentType: image.file!.mimeType ?? _contentTypeFor(image),
            ),
          )
          .toList();

      if (_isEditing) {
        final postId = await _repository.updatePost(
          widget.editPost!.id,
          UpdatePostInput(
            title: _titleController.text,
            content: _contentController.text,
            tags: _selectedTags.toList(),
            keptImages: _images
                .where((image) => image.isExisting)
                .map(
                  (image) => ExistingPostImage(
                    storagePath: image.storagePath!,
                    publicUrl: image.url!,
                  ),
                )
                .toList(),
            newImages: pickedImages,
          ),
        );
        await _moderatePost(postId);
      } else {
        final postId = await _repository.createPost(
          CreatePostInput(
            title: _titleController.text,
            content: _contentController.text,
            tags: _selectedTags.toList(),
            images: pickedImages,
          ),
        );
        await _moderatePost(postId);
      }

      _titleController.clear();
      _contentController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _images.clear();
        _selectedTags.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSubmissionError(postSubmissionErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _moderatePost(String postId) async {
    if (!mounted) return;
    try {
      final result =
          await ContentModerationScope.of(context).moderatePost(postId);
      if (!mounted) return;
      switch (result.state) {
        case ContentModerationState.approved:
          _showModerationMessage('Post published');
          widget.onPostCreated();
          if (_isEditing && mounted) Navigator.of(context).pop(true);
        case ContentModerationState.adminReview:
          _showModerationMessage('Sent for administrator review');
          widget.onPostCreated();
          if (_isEditing && mounted) Navigator.of(context).pop(true);
        case ContentModerationState.processing:
          _showModerationMessage('Moderation is still processing.');
          widget.onPostCreated();
          if (_isEditing && mounted) Navigator.of(context).pop(true);
        case ContentModerationState.rejected:
          _showModerationMessage(
            result.reason?.trim().isNotEmpty == true
                ? 'Post was not published: ${result.reason}'
                : 'Post was not published.',
          );
        case ContentModerationState.superseded:
          _showModerationMessage(
              'This post changed. Submit the latest version again.');
        case ContentModerationState.failed:
          _showModerationRetry(postId);
      }
    } on ContentModerationFailure catch (error) {
      if (!mounted) return;
      if (error.retryAllowed) {
        _showModerationRetry(postId);
      } else {
        _showSubmissionError(error.message);
      }
    }
  }

  void _showModerationMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showModerationRetry(String postId) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Moderation could not complete.'),
          action: SnackBarAction(
            label: 'Retry moderation',
            onPressed: () => _moderatePost(postId),
          ),
        ),
      );
  }

  void _showSubmissionError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  String _contentTypeFor(_DraftImage image) {
    final lowerName = image.file!.name.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<bool?> _showEditConfirmation() {
    return showAppConfirmationDialog(
      context: context,
      icon: Icons.edit_note_rounded,
      iconColor: const Color(0xFF2C7189),
      iconBackgroundColor: const Color(0xFFE7F8F5),
      title: 'Update this post?',
      message:
          'Updating will send this post back to pending review before it appears publicly again.',
      primaryLabel: 'Update post',
      primaryColor: const Color(0xFF0B1F3E),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            _isEditing ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
            color: const Color(0xFF0B1F3E),
            size: _isEditing ? 20 : 24,
          ),
          onPressed: () {
            if (_isEditing) {
              Navigator.of(context).pop();
            } else {
              // Redirect to home (which is index 0 in MainShell)
              widget.onPostCreated();
            }
          },
        ),
        title: Text(
          _isEditing ? 'Edit post' : 'New post',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0B1F3E),
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: const [SizedBox(width: 8)],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? 'Update your post and send it back for review.'
                    : 'Share your notes, questions, or just a happy moment today!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Image Section
              Row(
                children: [
                  const Icon(Icons.image_outlined,
                      size: 20, color: Color(0xFF4490AD)),
                  const SizedBox(width: 8),
                  Text(
                    'Images',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1F3E),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_images.length}/9 selected',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ModernImageGrid(
                images: _images,
                onPick: _pickImages,
                onRemove: _removeImage,
              ),

              const SizedBox(height: 32),

              // Form Section
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.title_rounded,
                            size: 20, color: Color(0xFF4490AD)),
                        const SizedBox(width: 8),
                        Text(
                          'Title',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B1F3E),
                          ),
                        ),
                        const Spacer(),
                        ListenableBuilder(
                          listenable: _titleController,
                          builder: (context, _) => Text(
                            '${_titleController.text.length}/40',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      maxLength: 40,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: appInputDecoration(
                        hintText: 'Add a title',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        final title = value?.trim() ?? '';
                        if (title.length > 40) {
                          return 'Keep the title under 40 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.notes_rounded,
                            size: 20, color: Color(0xFF4490AD)),
                        const SizedBox(width: 8),
                        Text(
                          'Content',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B1F3E),
                          ),
                        ),
                        const Spacer(),
                        ListenableBuilder(
                          listenable: _contentController,
                          builder: (context, _) => Text(
                            '${_contentController.text.length}/1000',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contentController,
                      minLines: 4,
                      maxLines: 12,
                      maxLength: 1000,
                      style: const TextStyle(fontSize: 15),
                      decoration: appInputDecoration(
                        hintText: 'Add text',
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        final content = value?.trim() ?? '';
                        if (content.length > 1000) {
                          return 'Keep the content under 1000 characters.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Tags Section
              Row(
                children: [
                  const Icon(Icons.tag_rounded,
                      size: 20, color: Color(0xFF4490AD)),
                  const SizedBox(width: 8),
                  Text(
                    'Tags',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B1F3E),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedTags.length}/5 selected',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ModernTagField(
                selectedTags: _selectedTags,
                onAdd: _openTagSelection,
                onRemove: (tag) => setState(() => _selectedTags.remove(tag)),
                tagLabelProvider: _findTagNameFromCatalog,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1F3E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update post' : 'Post',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftImage {
  const _DraftImage.picked({
    required XFile this.file,
    required Uint8List this.bytes,
  })  : url = null,
        storagePath = null;

  const _DraftImage.existing({
    required String this.url,
    required String this.storagePath,
  })  : file = null,
        bytes = null;

  final XFile? file;
  final Uint8List? bytes;
  final String? url;
  final String? storagePath;

  bool get isPicked => file != null && bytes != null;
  bool get isExisting => url != null && storagePath != null;
}

class _ModernImageGrid extends StatelessWidget {
  const _ModernImageGrid({
    required this.images,
    required this.onPick,
    required this.onRemove,
  });

  final List<_DraftImage> images;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final count = images.length;
    // Calculate how many items to show in the grid
    // If < 9, show images + 1 plus icon
    // If = 9, only show images
    final gridCount = count < 9 ? count + 1 : 9;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: gridCount,
      itemBuilder: (context, index) {
        if (index == count) {
          // Plus button
          return InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4490AD).withValues(alpha: 0.2),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF4490AD),
                size: 32,
              ),
            ),
          );
        }

        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: const Color(0xFFF1F5F9),
                child: Image(
                  image: images[index].isPicked
                      ? MemoryImage(images[index].bytes!)
                      : NetworkImage(images[index].url!) as ImageProvider,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModernTagField extends StatelessWidget {
  const _ModernTagField({
    required this.selectedTags,
    required this.onAdd,
    required this.onRemove,
    required this.tagLabelProvider,
  });

  final Set<String> selectedTags;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final String? Function(String) tagLabelProvider;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...selectedTags.map((slug) {
          final label = tagLabelProvider(slug) ?? slug;
          return Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F8F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF087F5B),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onRemove(slug),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFF087F5B),
                  ),
                ),
              ],
            ),
          );
        }),
        if (selectedTags.length < 5)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4490AD).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: Color(0xFF4490AD)),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: Color(0xFF4490AD),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
