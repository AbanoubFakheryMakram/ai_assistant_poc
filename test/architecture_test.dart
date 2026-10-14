import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the separation the project depends on: the rest of the app must
/// never depend on a specific model or on the inference package.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rel(File f) => f.path.replaceAll('\\', '/');
  List<String> importsOf(File f) => [
    for (final l in f.readAsLinesSync())
      if (l.trimLeft().startsWith('import ') ||
          l.trimLeft().startsWith('export '))
        l.trim(),
  ];

  const runtime = 'lib/assistant/providers/flutter_gemma_assistant_model.dart';

  List<String> violations(
    bool Function(String path) scope,
    bool Function(String importLine) forbidden,
  ) => [
    for (final f in files)
      if (scope(rel(f)))
        for (final i in importsOf(f))
          if (forbidden(i)) '${rel(f)}: $i',
  ];

  test('only one file imports the inference package', () {
    final v = violations(
      (p) => p != runtime,
      (i) => i.contains('package:flutter_gemma'),
    );
    expect(v, isEmpty, reason: v.join('\n'));
    expect(
      importsOf(File(runtime)).any((i) => i.contains('package:flutter_gemma/')),
      isTrue,
    );
  });

  test(
    'the core (models, actions, validation, execution) is pure Dart and knows no providers or UI',
    () {
      final v = violations(
        (p) => RegExp(
          r'lib/assistant/(models|actions|validation|execution)/',
        ).hasMatch(p),
        (i) =>
            i.contains('package:flutter/') ||
            i.contains('/providers/') ||
            i.contains('/evaluation/') ||
            i.contains('/app/') ||
            i.contains('flutter_gemma'),
      );
      expect(v, isEmpty, reason: v.join('\n'));
    },
  );

  test('providers never depend on the UI', () {
    final v = violations(
      (p) => p.startsWith('lib/assistant/providers/'),
      (i) => i.contains('/app/') || i.contains('package:flutter/'),
    );
    expect(v, isEmpty, reason: v.join('\n'));
  });

  test('evaluation depends on interfaces, not on a runtime or the UI', () {
    final v = violations(
      (p) => p.startsWith('lib/assistant/evaluation/'),
      (i) =>
          i.contains('flutter_gemma') ||
          i.contains('local_model_factory') ||
          i.contains('/app/') ||
          i.contains('package:flutter/'),
    );
    expect(v, isEmpty, reason: v.join('\n'));
  });

  test(
    'the UI depends on abstractions: no runtime, no factory, no inference package',
    () {
      final v = violations(
        (p) => p.startsWith('lib/app/'),
        (i) =>
            i.contains('flutter_gemma') ||
            i.contains('local_model_factory') ||
            i.contains('flutter_gemma_assistant_model'),
      );
      expect(v, isEmpty, reason: v.join('\n'));
    },
  );

  test('only the composition root connects the catalog to the runtime', () {
    final v = violations(
      (p) =>
          p != 'lib/main.dart' &&
          p != 'lib/assistant/providers/local_model_factory.dart',
      (i) => i.contains('local_model_factory'),
    );
    expect(v, isEmpty, reason: v.join('\n'));
  });

  test('no specific model name appears outside the data/config files', () {
    const allowed = {
      'lib/assistant/providers/model_catalog.dart',
      'lib/assistant/providers/model_prompt.dart',
      'lib/assistant/providers/local_model_config.dart',
      runtime,
      'lib/main.dart',
    };
    final name = RegExp(
      r'functiongemma|qwen|gemma ?4|\be2b\b|\be4b\b',
      caseSensitive: false,
    );
    final hits = [
      for (final f in files)
        if (!allowed.contains(rel(f)) && name.hasMatch(f.readAsStringSync()))
          rel(f),
    ];
    expect(hits, isEmpty, reason: 'model names found in: $hits');
  });

  test(
    'the runtime contains no model names, only the config-driven mapping',
    () {
      final src = File(runtime).readAsStringSync();
      // The family enum mapping is the only place a family is named.
      final stripped = src
          .replaceAll(RegExp(r'ModelFamily\.\w+'), '')
          .replaceAll(RegExp(r'ModelType\.\w+'), '');
      expect(
        RegExp(
          r'qwen|e2b|e4b|7B|270M',
          caseSensitive: false,
        ).hasMatch(stripped),
        isFalse,
      );
    },
  );
}
