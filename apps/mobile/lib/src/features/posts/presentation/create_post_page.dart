import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/posts_repository.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    required this.onPostCreated,
    super.key,
  });

  final VoidCallback onPostCreated;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _picker = ImagePicker();

  late final PostsRepository _repository;

  final List<_DraftImage> _images = [];
  bool _isSubmitting = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _repository = PostsRepository(Supabase.instance.client);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 9 - _images.length;
    if (remaining <= 0) {
      return;
    }

    final picked = await _picker.pickMultiImage(
      imageQuality: 86,
      limit: remaining,
    );

    if (picked.isEmpty || !mounted) {
      return;
    }

    final drafts = <_DraftImage>[];
    for (final image in picked.take(remaining)) {
      drafts.add(
        _DraftImage(
          file: image,
          bytes: await image.readAsBytes(),
        ),
      );
    }

    setState(() {
      _images.addAll(drafts);
      _message = null;
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
      _isSuccess = false;
    });

    try {
      await _repository.createPost(
        CreatePostInput(
          title: _titleController.text,
          content: _contentController.text,
          tags: _parseTags(_tagsController.text),
          images: _images
              .map(
                (image) => PickedPostImage(
                  name: image.file.name,
                  bytes: image.bytes,
                  contentType: image.file.mimeType ?? _contentTypeFor(image),
                ),
              )
              .toList(),
        ),
      );

      _titleController.clear();
      _contentController.clear();
      _tagsController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _images.clear();
        _message = 'Posted. It will stay visible to you while pending review.';
        _isSuccess = true;
      });
      widget.onPostCreated();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.toString();
        _isSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[,\s]+'))
        .map((tag) => tag.trim().replaceFirst('#', '').toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(8)
        .toList();
  }

  String _contentTypeFor(_DraftImage image) {
    final lowerName = image.file.name.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Text(
            'Create learning post',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Images, notes, questions, and study tips work best here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF536A74),
                ),
          ),
          const SizedBox(height: 18),
          _ImagePickerPanel(
            images: _images,
            onPickImages: _isSubmitting ? null : _pickImages,
            onRemove: _isSubmitting
                ? null
                : (index) => setState(() => _images.removeAt(index)),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    final title = value?.trim() ?? '';
                    if (title.length < 3) {
                      return 'Use at least 3 characters.';
                    }
                    if (title.length > 120) {
                      return 'Keep the title under 120 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contentController,
                  minLines: 5,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 92),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                  validator: (value) {
                    final content = value?.trim() ?? '';
                    if (content.isEmpty) {
                      return 'Write something educational.';
                    }
                    if (content.length > 5000) {
                      return 'Keep the post under 5000 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _tagsController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    helperText: 'Separate with commas or spaces.',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_rounded),
            label: Text(_isSubmitting ? 'Posting...' : 'Post to CyanZone'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            _CreateMessage(message: _message!, isSuccess: _isSuccess),
          ],
        ],
      ),
    );
  }
}

class _DraftImage {
  const _DraftImage({
    required this.file,
    required this.bytes,
  });

  final XFile file;
  final Uint8List bytes;
}

class _ImagePickerPanel extends StatelessWidget {
  const _ImagePickerPanel({
    required this.images,
    required this.onPickImages,
    required this.onRemove,
  });

  final List<_DraftImage> images;
  final VoidCallback? onPickImages;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDEBED)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Images (${images.length}/9)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Add images',
                  onPressed: onPickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (images.isEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onPickImages,
                child: Container(
                  height: 132,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD8E8EA)),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 38,
                    color: Color(0xFF4490AD),
                  ),
                ),
              )
            else
              GridView.builder(
                itemCount: images.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          images[index].bytes,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filled(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Remove image',
                            onPressed: onRemove == null
                                ? null
                                : () => onRemove!(index),
                            icon: const Icon(Icons.close_rounded, size: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateMessage extends StatelessWidget {
  const _CreateMessage({
    required this.message,
    required this.isSuccess,
  });

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF087F5B) : const Color(0xFFB42318);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFEAF8F1) : const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
