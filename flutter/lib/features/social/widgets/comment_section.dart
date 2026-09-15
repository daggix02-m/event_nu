import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../../social/data/comment.dart';
import '../../social/social_providers.dart';

class CommentSection extends ConsumerWidget {
  const CommentSection({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(commentsControllerProvider(eventId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Comments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 6),
            value.value == null
                ? const SizedBox.shrink()
                : Text(
                    '${value.value?.length ?? 0}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
          ],
        ),
        const SizedBox(height: 12),
        CommentComposer(eventId: eventId),
        const SizedBox(height: 12),
        value.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neon),
              ),
            ),
          ),
          error: (_, _) => Center(
            child: Text(
              'Comments could not load.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          data: (comments) => comments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No comments yet. Be the first to say something.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: [
                    ...comments.take(8).map((c) => CommentTile(comment: c)),
                    if (comments.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton(
                          onPressed: () => ref.read(commentsControllerProvider(eventId).notifier).loadMore(),
                          child: const Text('Show more'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.neon.withValues(alpha: 0.16),
            child: const Icon(Icons.person, size: 16, color: AppColors.neon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d · h:mm a').format(comment.createdAt.toLocal()),
                  style: textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                ),
                Text(comment.body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(commentsControllerProvider(widget.eventId).notifier).add(body);
      if (!mounted) return;
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post your comment. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add a comment…',
              filled: true,
              fillColor: AppColors.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          tooltip: 'Send',
        ),
      ],
    );
  }
}