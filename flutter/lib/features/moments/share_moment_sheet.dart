import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../design/app_colors.dart';
import '../../design/app_space.dart';
import 'moment_providers.dart';

class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;
}

class ShareMomentSheet extends ConsumerStatefulWidget {
  const ShareMomentSheet({
    super.key,
    required this.eventId,
    this.pickImage,
  });

  final String eventId;

  /// Overridable for tests; defaults to the device gallery picker.
  final Future<PickedImage?> Function()? pickImage;

  @override
  ConsumerState<ShareMomentSheet> createState() => _ShareMomentSheetState();
}

class _ShareMomentSheetState extends ConsumerState<ShareMomentSheet> {
  final _captionController = TextEditingController();
  PickedImage? _image;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<PickedImage?> _defaultPicker() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final contentType = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
    return PickedImage(bytes: bytes, contentType: contentType);
  }

  Future<void> _choosePhoto() async {
    final picker = widget.pickImage ?? _defaultPicker;
    try {
      final picked = await picker();
      if (picked != null && mounted) {
        setState(() {
          _image = picked;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the photo picker.');
    }
  }

  Future<void> _post() async {
    final image = _image;
    if (image == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(shareMomentControllerProvider.notifier).share(
            eventId: widget.eventId,
            bytes: image.bytes,
            contentType: image.contentType,
            caption: _captionController.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('Moment shared')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('share moment unexpected error: $e');
      if (mounted) setState(() => _error = 'Could not share this moment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final image = _image;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.md,
        right: AppSpace.md,
        top: AppSpace.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('Share a moment', style: textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpace.md),
          if (image == null)
            OutlinedButton.icon(
              onPressed: _busy ? null : _choosePhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Choose photo'),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                image.bytes,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 200,
                  child: ColoredBox(
                    color: AppColors.surfaceContainer,
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextField(
              controller: _captionController,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _error!,
              style: textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          FilledButton.icon(
            onPressed: image == null || _busy ? null : _post,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_busy ? 'Posting…' : 'Post moment'),
          ),
        ],
      ),
    );
  }
}