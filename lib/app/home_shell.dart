import 'package:flutter/material.dart';

import '../assistant/models/action_parameters.dart';
import 'app_state.dart';
import 'assistant/assistant_controller.dart';
import 'assistant/assistant_dock.dart';
import 'model_host.dart';
import 'pages/developer_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'strings.dart';

/// The app: three pages, the assistant dock above the navigation bar.
class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.state,
    required this.host,
    required this.assistant,
  });

  final AppState state;
  final ModelHost host;
  final AssistantController assistant;

  @override
  Widget build(BuildContext context) {
    final s = Strings(state.language);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded),
            const SizedBox(width: 8),
            Text(
              s.appTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: host,
            builder: (context, _) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: _StatusDot(
                status: host.status,
                label: host.selected.displayName,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(state.destination),
                child: switch (state.destination) {
                  AppDestination.home => HomePage(
                    state: state,
                    onSuggestion: assistant.submit,
                  ),
                  AppDestination.profile => ProfilePage(strings: s),
                  AppDestination.settings => SettingsPage(
                    state: state,
                    host: host,
                    onOpenDeveloper: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeveloperPage(state: state),
                      ),
                    ),
                  ),
                },
              ),
            ),
          ),
          AssistantDock(controller: assistant, host: host, strings: s),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.destination.index,
        onDestinationSelected: (i) =>
            state.navigateTo(AppDestination.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: s.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: s.tabProfile,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: s.tabSettings,
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status, required this.label});
  final ModelStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ModelStatus.ready => const Color(0xFF2DBE7E),
      ModelStatus.loading => scheme.tertiary,
      ModelStatus.error => scheme.error,
      ModelStatus.notLoaded => scheme.outline,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          key: const Key('model_chip'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
