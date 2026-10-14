import 'package:flutter/material.dart';

import '../strings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.strings});
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  s.profileName,
                  key: const Key('profile_name'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  s.profileNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
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
