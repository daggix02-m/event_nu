import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../design/app_colors.dart';
import '../../../design/app_space.dart';
import '../engagement_providers.dart';

const _reasons = <(String, String)>[
  ('spam', 'Spam or scam'),
  ('harassment', 'Harassment'),
  ('misinformation', 'Misinformation'),
  ('inappropriate', 'Inappropriate content'),
  ('other', 'Something else'),
];

/// Presents the report bottom sheet for a target entity.
Future<void> showReportSheet(
  BuildContext context, {
  required String entityType,
  required String entityId,
  String? subject,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerHigh,
    builder: (ctx) => ReportSheet(
      entityType: entityType,
      entityId: entityId,
      subject: subject,
    ),
  );
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.entityType,
    required this.entityId,
    this.subject,
  });

  final String entityType;
  final String entityId;
  final String? subject;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _description = TextEditingController();
  String? _reason;
  bool _submitting = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(engagementRepositoryProvider).report(
            widget.entityType,
            widget.entityId,
            reasonCode: reason,
            description: _description.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — our team will review this.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send your report. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final pad = MediaQuery.of(context).padding;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg + bottomInset + pad.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Report', style: textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (widget.subject != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text(
                widget.subject!,
                style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, label) in _reasons)
                ChoiceChip(
                  label: Text(label),
                  selected: _reason == code,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _reason = code),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _description,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Anything else we should know? (optional)',
              filled: true,
              fillColor: AppColors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting || _reason == null ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}