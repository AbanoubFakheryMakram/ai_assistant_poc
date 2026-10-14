import 'package:flutter/material.dart';

import '../../assistant/models/action_parameters.dart';
import '../app_state.dart';
import '../model_host.dart';
import '../strings.dart';

/// Manual controls for everything the assistant can change, plus the model
/// picker and the developer tools entry.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.state,
    required this.host,
    required this.onOpenDeveloper,
  });
  final AppState state;
  final ModelHost host;
  final VoidCallback onOpenDeveloper;

  @override
  Widget build(BuildContext context) {
    final s = Strings(state.language);
    final scheme = Theme.of(context).colorScheme;
    Widget section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Card(
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
        const SizedBox(height: 12),
      ],
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        section(
          s.appearance,
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeModeOption>(
              key: const Key('seg_theme'),
              segments: [
                for (final m in ThemeModeOption.values)
                  ButtonSegment(value: m, label: Text(s.themeName(m))),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (v) => state.setThemeMode(v.first),
            ),
          ),
        ),
        section(
          s.language,
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppLanguage>(
              key: const Key('seg_language'),
              segments: [
                for (final l in AppLanguage.values)
                  ButtonSegment(value: l, label: Text(s.languageName(l))),
              ],
              selected: {state.language},
              onSelectionChanged: (v) => state.setLanguage(v.first),
            ),
          ),
        ),
        section(
          s.notifications,
          SwitchListTile(
            key: const Key('switch_notifications'),
            contentPadding: EdgeInsets.zero,
            title: Text(state.notificationsEnabled ? s.on : s.off),
            value: state.notificationsEnabled,
            onChanged: state.setNotificationsEnabled,
          ),
        ),
        section(
          s.assistantModel,
          ListenableBuilder(
            listenable: host,
            builder: (context, _) => Column(
              children: [
                for (final m in host.catalog)
                  ListTile(
                    key: Key('model_${m.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      host.selected.id == m.id &&
                              host.status == ModelStatus.ready
                          ? Icons.check_circle_rounded
                          : Icons.memory_rounded,
                      color: host.selected.id == m.id
                          ? scheme.primary
                          : scheme.outline,
                    ),
                    title: Text(m.displayName),
                    subtitle: Text(s.size(m.approxSizeMb)),
                    trailing:
                        host.status == ModelStatus.loading &&
                            host.selected.id == m.id
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => host.load(m),
                            child: Text(
                              host.selected.id == m.id &&
                                      host.status == ModelStatus.ready
                                  ? s.ready
                                  : s.switchModel,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            key: const Key('open_developer'),
            leading: const Icon(Icons.code_rounded),
            title: Text(s.developerTools),
            subtitle: Text(s.developerToolsHint),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenDeveloper,
          ),
        ),
      ],
    );
  }
}
