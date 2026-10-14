import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state, required this.onSuggestion});
  final AppState state;

  /// Called with a sample sentence when the user taps one of the chips.
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final s = Strings(state.language);
    final scheme = Theme.of(context).colorScheme;
    Widget tile(IconData icon, String label, String value, Key key) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                value,
                key: key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary),
              const SizedBox(height: 12),
              Text(
                s.homeTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.homeSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(s.appState, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            tile(
              Icons.palette_rounded,
              s.theme,
              s.themeName(state.themeMode),
              const Key('state_theme'),
            ),
            tile(
              Icons.translate_rounded,
              s.language,
              s.languageName(state.language),
              const Key('state_language'),
            ),
            tile(
              Icons.notifications_rounded,
              s.notifications,
              state.notificationsEnabled ? s.on : s.off,
              const Key('state_notifications'),
            ),
            tile(
              Icons.pages_rounded,
              s.currentPage,
              s.destination(state.destination),
              const Key('state_page'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.search_rounded, color: scheme.primary),
            title: Text(s.lastSearch),
            subtitle: Text(
              state.lastSearchQuery ?? s.none,
              key: const Key('state_search'),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(s.tryThese, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in s.suggestions)
              ActionChip(
                label: Text(q, textDirection: TextDirection.ltr),
                onPressed: () => onSuggestion(q),
              ),
          ],
        ),
      ],
    );
  }
}
