import 'package:flutter/material.dart';

import 'schedule_view.dart';

/// Standalone schedule page (used when the schedule is opened outside the
/// home segment). The home screen embeds [ScheduleView] directly.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SafeArea(child: const ScheduleView()),
    );
  }
}