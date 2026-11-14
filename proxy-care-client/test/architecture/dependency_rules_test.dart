import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../fixtures/import_rule_sources.dart';
import '../helpers/import_rules.dart';

/// Imports that tie code to Flutter, Riverpod or HTTP. Pure-Dart code must
/// not use them.
const _frameworkImports = [
  'package:flutter/',
  'package:material_ui/',
  'dart:ui',
  'package:flutter_riverpod/',
  'package:riverpod',
  'package:dio/',
  'package:flutter_secure_storage/',
];

/// The dependency rules from ARCHITECTURE.md, enforced on every file in lib/.
final _rules = [
  ImportRule(
    name: 'domain is pure Dart and knows nothing about data or presentation',
    appliesTo: RegExp(r'^lib/features/[^/]+/domain/'),
    forbidden: [
      ..._frameworkImports,
      'package:json_annotation/',
      '/data/',
      '/presentation/',
    ],
  ),
  ImportRule(
    name: 'types used by the domain layer are pure Dart',
    appliesTo: RegExp(
      r'^lib/(shared/models/|core/config/|'
      r'core/error/(failure|error_reporter)\.dart)',
    ),
    forbidden: _frameworkImports,
  ),
  ImportRule(
    name: 'data does not depend on presentation',
    appliesTo: RegExp(r'^lib/features/[^/]+/data/'),
    forbidden: const ['/presentation/'],
  ),
  ImportRule(
    name: 'presentation depends on domain, not on data',
    appliesTo: RegExp(r'^lib/features/[^/]+/presentation/'),
    forbidden: const ['/data/', 'package:dio/'],
  ),
  ImportRule(
    name: 'core and shared do not depend on features',
    appliesTo: RegExp(r'^lib/(core|shared)/'),
    forbidden: const ['features/'],
  ),
];

void main() {
  group('import rule checker', () {
    test('finds every forbidden import and export', () {
      final violations = violationsOf(
        'lib/features/auth/domain/entities/user.dart',
        ImportRuleSources.badDomainFile,
        _rules,
      );

      expect(violations, hasLength(3));
      expect(violations, contains(contains('package:dio/dio.dart')));
      expect(violations, contains(contains('package:flutter/foundation')));
      expect(violations, contains(contains('../../data/dto/user_dto.dart')));
    });

    test('accepts allowed imports and ignores comments', () {
      final violations = violationsOf(
        'lib/features/auth/domain/entities/user.dart',
        ImportRuleSources.cleanDomainFile,
        _rules,
      );

      expect(violations, isEmpty);
    });

    test('only applies a rule to matching paths', () {
      final violations = violationsOf(
        'lib/features/auth/data/datasources/auth_remote_source.dart',
        ImportRuleSources.badDomainFile,
        _rules,
      );

      expect(violations, isEmpty);
    });
  });

  test('lib/ follows the dependency rules', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = [
      for (final file in files)
        ...violationsOf(
          file.path.replaceAll(r'\', '/'),
          file.readAsStringSync(),
          _rules,
        ),
    ];

    expect(files, isNotEmpty);
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
