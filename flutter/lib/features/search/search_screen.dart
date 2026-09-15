import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../design/app_colors.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/widgets/event_feed.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(feedControllerProvider.notifier).setQuery(value);
    });
  }

  Future<void> _pickFrom() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (day != null && mounted) {
      setState(() => _from = day);
      ref.read(feedControllerProvider.notifier).setDateWindow(day, _to);
    }
  }

  Future<void> _pickTo() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _from ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (day != null && mounted) {
      setState(() => _to = day);
      ref.read(feedControllerProvider.notifier).setDateWindow(_from, day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromLabel = _from == null ? 'From' : DateFormat('MMM d').format(_from!);
    final toLabel = _to == null ? 'To' : DateFormat('MMM d').format(_to!);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search events, organizers…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  InputChip(
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    label: Text(fromLabel),
                    onPressed: _pickFrom,
                    onDeleted: _from == null ? null : () {
                      setState(() => _from = null);
                      ref.read(feedControllerProvider.notifier).setDateWindow(null, _to);
                    },
                  ),
                  const SizedBox(width: 8),
                  InputChip(
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    label: Text(toLabel),
                    onPressed: _pickTo,
                    onDeleted: _to == null ? null : () {
                      setState(() => _to = null);
                      ref.read(feedControllerProvider.notifier).setDateWindow(_from, null);
                    },
                  ),
                ],
              ),
            ),
            const Expanded(child: EventFeed()),
          ],
        ),
      ),
    );
  }
}