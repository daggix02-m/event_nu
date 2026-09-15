import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../data/engagement_models.dart';
import '../engagement_providers.dart';

/// Reviews for an event plus a write-a-review form.
class ReviewSection extends ConsumerWidget {
  const ReviewSection({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(reviewsControllerProvider(eventId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _WriteReviewForm(eventId: eventId),
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
          error: (_, _) => Text(
            'Reviews could not load.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          data: (reviews) => reviews.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No reviews yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: reviews.take(10).map((r) => ReviewTile(review: r)).toList(),
                ),
        ),
      ],
    );
  }
}

class _WriteReviewForm extends ConsumerStatefulWidget {
  const _WriteReviewForm({required this.eventId});

  final String eventId;

  @override
  ConsumerState<_WriteReviewForm> createState() => _WriteReviewFormState();
}

class _WriteReviewFormState extends ConsumerState<_WriteReviewForm> {
  final _controller = TextEditingController();
  int _rating = 0;
  bool _open = false;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a star rating first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(reviewsControllerProvider(widget.eventId).notifier)
          .submit(rating: _rating, body: _controller.text.trim());
      if (!mounted) return;
      setState(() {
        _open = false;
        _rating = 0;
      });
      _controller.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post your review. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _open = true),
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Write a review'),
      );
    }
    return Card(
      color: AppColors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    onPressed: _submitting ? null : () => setState(() => _rating = star),
                    icon: Icon(
                      star <= _rating ? Icons.star : Icons.star_border,
                      color: star <= _rating ? AppColors.secondary : AppColors.onSurfaceVariant,
                    ),
                    iconSize: 26,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 8),
                Text('$_rating/5', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 5,
              maxLength: 5000,
              decoration: const InputDecoration(
                hintText: 'What did you think?',
                filled: true,
                fillColor: AppColors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting ? null : () => setState(() => _open = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Post review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final ReviewItem review;

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
                Row(
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          size: 14,
                          color: i < review.rating ? AppColors.secondary : AppColors.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d').format(review.createdAt.toLocal()),
                      style: textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                if (review.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review.body, style: textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}