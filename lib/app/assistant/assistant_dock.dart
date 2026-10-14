import 'package:flutter/material.dart';

import '../model_host.dart';
import '../strings.dart';
import 'assistant_controller.dart';
import 'turn_card.dart';

/// The assistant's input area: model status, suggestions, the latest result and
/// the text field.
class AssistantDock extends StatefulWidget {
  const AssistantDock({
    super.key,
    required this.controller,
    required this.host,
    required this.strings,
  });

  final AssistantController controller;
  final ModelHost host;
  final Strings strings;

  @override
  State<AssistantDock> createState() => _AssistantDockState();
}

class _AssistantDockState extends State<AssistantDock> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send([String? override]) {
    final value = override ?? _text.text;
    if (value.trim().isEmpty) return;
    _text.clear();
    FocusScope.of(context).unfocus();
    widget.controller.submit(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.strings;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.host]),
      builder: (context, _) {
        final host = widget.host;
        final ready = host.status == ModelStatus.ready;
        final turn = widget.controller.current;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!ready) _ModelBanner(host: host, strings: s),
              if (ready && turn == null)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final q in s.suggestions)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ActionChip(
                            label: Text(q, textDirection: TextDirection.ltr),
                            onPressed: () => _send(q),
                          ),
                        ),
                    ],
                  ),
                ),
              if (turn != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: SingleChildScrollView(
                    child: TurnCard(
                      turn: turn,
                      strings: s,
                      onChoose: widget.controller.choose,
                      onDismissQuestion: widget.controller.dismissQuestion,
                      onClose: widget.controller.clear,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('assistant_input'),
                      controller: _text,
                      enabled: ready && !widget.controller.busy,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(hintText: s.inputHint),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('assistant_send'),
                    tooltip: s.send,
                    onPressed: ready && !widget.controller.busy ? _send : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModelBanner extends StatelessWidget {
  const _ModelBanner({required this.host, required this.strings});
  final ModelHost host;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final scheme = Theme.of(context).colorScheme;
    final loading = host.status == ModelStatus.loading;
    final error = host.status == ModelStatus.error;
    final fg = error ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    final detail = loading
        ? (host.progress == null ? s.loading : s.downloading(host.progress!))
        : error
        ? (host.error ?? '')
        : '${host.selected.displayName} · ${s.firstTimeDownload(host.selected.approxSizeMb)}';
    return Container(
      key: const Key('model_banner'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.auto_awesome_rounded,
                color: fg,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error ? s.loadFailed : s.assistantOff,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: fg),
                    ),
                    Text(
                      detail,
                      key: const Key('model_status'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
              if (!loading) ...[
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('load_model'),
                  onPressed: () => host.load(),
                  child: Text(error ? s.retry : s.turnOn),
                ),
              ],
            ],
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: LinearProgressIndicator(
                value: host.progress == null ? null : host.progress! / 100,
              ),
            ),
        ],
      ),
    );
  }
}
