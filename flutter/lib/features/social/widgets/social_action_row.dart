import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../design/app_colors.dart';
import '../../discovery/discovery_providers.dart';
import '../social_providers.dart';

/// Optimistic like / save toggle row for the event detail screen.
class SocialActionRow extends ConsumerStatefulWidget {
  const SocialActionRow({super.key, required this.eventId, required this.initialLiked, required this.initialLikeCount, required this.initialSaved});

  final String eventId;
  final bool initialLiked;
  final int initialLikeCount;
  final bool initialSaved;

  @override
  ConsumerState<SocialActionRow> createState() => _SocialActionRowState();
}

class _SocialActionRowState extends ConsumerState<SocialActionRow> {
  late bool _liked = widget.initialLiked;
  late int _likeCount = widget.initialLikeCount;
  late bool _saved = widget.initialSaved;
  bool _busy = false;

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      final state = await ref.read(socialRepositoryProvider).setLike(widget.eventId, _liked);
      if (!mounted) return;
      setState(() {
        _likeCount = state.likeCount;
        _liked = state.liked;
      });
      ref.invalidate(eventDetailProvider(widget.eventId));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
      });
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _saved = !_saved;
    });
    try {
      final state = await ref.read(socialRepositoryProvider).setSave(widget.eventId, _saved);
      if (!mounted) return;
      setState(() => _saved = state.saved);
      ref.invalidate(eventDetailProvider(widget.eventId));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saved = !_saved);
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          color: _liked ? AppColors.neon : null,
          label: _likeCount > 0 ? '$_likeCount' : 'Like',
          onPressed: _toggleLike,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: _saved ? Icons.bookmark : Icons.bookmark_border,
          color: _saved ? AppColors.tertiary : null,
          label: _saved ? 'Saved' : 'Save',
          onPressed: _toggleSave,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? AppColors.onSurfaceVariant;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: effective,
        side: BorderSide(color: effective.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}