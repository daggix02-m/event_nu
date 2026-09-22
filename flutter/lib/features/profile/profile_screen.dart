import 'package:flutter/material.dart';

import 'widgets/profile_identity_card.dart';
import 'widgets/profile_stats_row.dart';
import 'widgets/profile_tabs.dart';

/// Profile home: identity card, summary stats and tabbed history
/// (Going / Saved / Tickets / Badges).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(title: const Text('Your profile')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  ProfileIdentityCard(),
                  ProfileStatsRow(),
                  ProfileTabBar(),
                  Expanded(child: ProfileTabViews()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}