import 'dart:convert';
import 'dart:io';

import 'package:feature_gen_cli/command_helper.dart';
import 'package:feature_gen_cli/string_extension.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:feature_gen_cli/yaml_helper.dart';

/// Parses JSON schema files and builds the template [Context] for code generation.
///
/// The parser is intentionally strict about required sections so generated code
/// is predictable and templates can rely on stable fields. It also builds
/// nested field graphs so templates can emit models for complex payloads and
/// enforces presentation configuration. The current working directory is used
/// as the target project root for `pubspec.yaml` lookup.
class Parser {
  /// Creates a parser with an injectable [CommandHelper] for test reporting.
  Parser({CommandHelper? commandHelper}) : _commandHelper = commandHelper ?? CommandHelper();

  final CommandHelper _commandHelper;

  /// Reads and deserialises the JSON schema file at [path] into a [Schema].
  Schema parse(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      _commandHelper.error('Schema file not found: $path');
    }
    final json = jsonDecode(file.readAsStringSync());
    return Schema.fromJson(json);
  }

  /// Builds a [Context] from a [featureName] and parsed [schema].
  ///
  /// Returns an empty context if validation fails. The caller is expected to
  /// halt or surface the error to the user.
  ///
  /// **Single-response mode**: response fields are collected into a nested tree
  /// with a root node matching the feature name (original behaviour).
  ///
  /// **Multi-response mode**: one [EntityContext] is built per entry in
  /// `schema.responses`. Each [ContextMethod] is linked to its named entity
  /// via the `response` key on [ApiMethod].
  Future<Context> buildContext(String featureName, Schema schema) async {
    final projectRoot = Directory.current.path;
    final projectName = await YamlHelper().getProjectName(workingDirectory: projectRoot);

    if (!validateSchema(schema)) {
      return Context(
        name: '',
        nameLowerCase: '',
        nameCamelCase: '',
        isList: false,
        fields: [],
        methods: [],
        generateUseCase: false,
        projectRoot: projectRoot,
        projectName: projectName,
        config: Config(),
      );
    }

    // Use consistent naming across the generated layers.
    final feature = featureName.toPascalCase();
    bool generateUseCase = false;

    final apiMethods = schema.api?.methods?.method ?? {};

    if (schema.isMultiResponse) {
      return _buildMultiResponseContext(
        featureName: featureName,
        feature: feature,
        schema: schema,
        apiMethods: apiMethods,
        projectRoot: projectRoot,
        projectName: projectName,
        generateUseCase: generateUseCase,
      );
    }

    // ── Single-response mode (original behaviour) ──────────────────────────

    final methods = <ContextMethod>[];
    for (var method in apiMethods.entries) {
      final contextMethod = buildContextMethod(method);
      methods.add(contextMethod);
      if (contextMethod.hasUseCase) generateUseCase = true;
    }

    // Response fields become entity/model properties.
    final response = schema.response ?? {};
    final contextFields = <NestedContextField>[];
    final fields = buildContextFields(response, contextFields);
    contextFields.add(NestedContextField(name: feature, properties: fields, isRoot: true));

    return Context(
      name: feature,
      nameLowerCase: featureName.toLowerCase(),
      nameCamelCase: featureName.toCamelCase(),
      isList: schema.isList,
      fields: contextFields,
      methods: methods,
      generateUseCase: generateUseCase,
      projectRoot: projectRoot,
      projectName: projectName,
      config: schema.config ?? Config(),
      isMultiResponse: false,
      entities: [],
    );
  }

  // ── Multi-response private helper ─────────────────────────────────────────

  Future<Context> _buildMultiResponseContext({
    required String featureName,
    required String feature,
    required Schema schema,
    required Map<String, ApiMethod> apiMethods,
    required String projectRoot,
    required String projectName,
    required bool generateUseCase,
  }) async {
    final responses = schema.responses!;
    final validKeys = responses.keys.toSet();

    // Build one EntityContext per named response.
    final entities = <EntityContext>[];
    for (final entry in responses.entries) {
      final (fieldMap, entIsList) = entry.value;
      final entityPascal = entry.key.toPascalCase();
      final contextFields = <NestedContextField>[];
      final props = buildContextFields(fieldMap, contextFields);
      contextFields.add(NestedContextField(name: entityPascal, properties: props, isRoot: true));

      entities.add(
        EntityContext(
          name: entityPascal,
          nameLower: entry.key.toLowerCase(),
          nameCamelCase: entry.key.toCamelCase(),
          isList: entIsList,
          fields: contextFields,
        ),
      );
    }

    // Build per-method context, resolving response entity refs.
    final methods = <ContextMethod>[];
    for (final method in apiMethods.entries) {
      final contextMethod = buildContextMethod(method, validResponseKeys: validKeys);
      methods.add(contextMethod);
      if (contextMethod.hasUseCase) generateUseCase = true;
    }

    // Use the first entity as the "primary" for legacy template vars that
    // expect a single entity name/fields (they won't be used in multi-response
    // templates, but Context requires non-null values).
    final primary = entities.firstOrNull;

    return Context(
      name: feature,
      nameLowerCase: featureName.toLowerCase(),
      nameCamelCase: featureName.toCamelCase(),
      isList: primary?.isList ?? false,
      fields: primary?.fields ?? [],
      methods: methods,
      generateUseCase: generateUseCase,
      projectRoot: projectRoot,
      projectName: projectName,
      config: schema.config ?? Config(),
      isMultiResponse: true,
      entities: entities,
    );
  }

  // ── Method builder ────────────────────────────────────────────────────────

  /// Converts an [ApiMethod] schema entry into a [ContextMethod].
  ///
  /// Params/body/query sections are expanded into nested field trees that can
  /// generate request models. The `hasUseCase` flag is derived from the
  /// presence of any params/body/query.
  ///
  /// [validResponseKeys] is supplied in multi-response mode so the method's
  /// `response` key can be validated and resolved to entity name strings.
  ContextMethod buildContextMethod(
    MapEntry<String, ApiMethod> method, {
    Set<String>? validResponseKeys,
  }) {
    final paramsFields = <NestedContextField>[],
        bodyFields = <NestedContextField>[],
        queryFields = <NestedContextField>[];

    final params = buildContextFields(method.value.params ?? {}, paramsFields);
    final body = buildContextFields(method.value.body ?? {}, bodyFields);
    final query = buildContextFields(method.value.query ?? {}, queryFields);

    if (params.isNotEmpty) {
      paramsFields.add(
        NestedContextField(
          name: method.key.camelCaseToPascalCase(),
          properties: params,
          isRoot: true,
        ),
      );
    }
    if (body.isNotEmpty) {
      bodyFields.add(
        NestedContextField(
          name: method.key.camelCaseToPascalCase(),
          properties: body,
          isRoot: true,
        ),
      );
    }
    if (query.isNotEmpty) {
      queryFields.add(
        NestedContextField(
          name: method.key.camelCaseToPascalCase(),
          properties: query,
          isRoot: true,
        ),
      );
    }

    // Resolve response entity reference (multi-response mode only).
    String? responseEntityName;
    String? responseEntityNameLower;
    String? responseEntityCamelCase;
    bool responseIsList = method.value.responseIsList;
    bool hasResponse = false;

    final rawResponse = method.value.response;
    if (rawResponse != null && validResponseKeys != null) {
      if (validResponseKeys.contains(rawResponse)) {
        responseEntityName = rawResponse.toPascalCase();
        responseEntityNameLower = rawResponse.toLowerCase();
        responseEntityCamelCase = rawResponse.toCamelCase();
        hasResponse = true;
      } else {
        _commandHelper.warning(
          'Method "${method.key}" declares response "$rawResponse" which is not defined in the '
          '"response" section. It will be treated as void.',
        );
      }
    }

    return ContextMethod(
      methodName: method.key,
      methodNamePascalCase: method.key.camelCaseToPascalCase(),
      params: paramsFields,
      body: bodyFields,
      query: queryFields,
      hasParams: paramsFields.isNotEmpty,
      hasBody: bodyFields.isNotEmpty,
      hasQuery: queryFields.isNotEmpty,
      hasUseCase: paramsFields.isNotEmpty || bodyFields.isNotEmpty || queryFields.isNotEmpty,
      responseEntityName: responseEntityName,
      responseEntityNameLower: responseEntityNameLower,
      responseEntityCamelCase: responseEntityCamelCase,
      responseIsList: responseIsList,
      hasResponse: hasResponse,
    );
  }

  // ── Field builder ─────────────────────────────────────────────────────────

  /// Converts a `{ fieldName: schemaType }` map to a list of [ContextField]s.
  ///
  /// Nested objects and lists of objects are lifted into [NestedContextField]
  /// entries so templates can generate custom model classes.
  List<ContextField> buildContextFields(
    Map<String, dynamic> fields,
    List<NestedContextField> nestedFields,
  ) {
    return fields.entries.map((entry) {
      final value = entry.value;
      final originalKey = entry.key;
      final camelCaseKey = originalKey.contains('_') ? originalKey.toCamelCase() : originalKey;
      final hasJsonKey = camelCaseKey != originalKey;

      // If nested JSON object → treat as custom model type
      if (value is Map<String, dynamic>) {
        final someData = buildContextFields(value, nestedFields);
        nestedFields.add(
          NestedContextField(name: camelCaseKey.camelCaseToPascalCase(), properties: someData),
        );
        return ContextField(
          name: camelCaseKey,
          type: camelCaseKey.camelCaseToPascalCase(),
          isCustom: true,
          jsonKey: originalKey,
          hasJsonKey: hasJsonKey,
        );
      }

      // If list of objects → List<CustomModel>
      if (value is List && value.isNotEmpty) {
        var type = "";
        var isCustom = false;
        if (value.first is Map<String, dynamic>) {
          nestedFields.add(
            NestedContextField(
              name: camelCaseKey.camelCaseToPascalCase(),
              properties: buildContextFields(value.first, nestedFields),
            ),
          );
          type = camelCaseKey.camelCaseToPascalCase();
          isCustom = true;
        } else {
          type = getDartType(value.first);
        }
        return ContextField(
          name: camelCaseKey, 
          type: "List<$type>", 
          isList: true, 
          isCustom: isCustom,
          jsonKey: originalKey,
          hasJsonKey: hasJsonKey,
        );
      }

      final type = getDartType(value);
      return ContextField(
        name: camelCaseKey, 
        type: type, 
        isList: type.contains('List'),
        jsonKey: originalKey,
        hasJsonKey: hasJsonKey,
      );
    }).toList();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Validates that [schema] has the required sections and config.
  ///
  /// Requires `api`, `api.methods`, `response`, and `config`, with exactly one
  /// of `config.bloc` or `config.riverpod` set to true.
  ///
  /// In multi-response mode, additionally checks that any method `response` key
  /// that is set corresponds to a declared response entity.
  bool validateSchema(Schema schema) {
    if (schema.api == null) {
      _commandHelper.error('Schema is not valid. "api" is required.');
      return false;
    }
    if (schema.api?.methods == null) {
      _commandHelper.error('Schema is not valid. "api.methods" is required.');
      return false;
    }
    if (schema.response == null && schema.responses == null) {
      _commandHelper.error('Schema is not valid. "response" is required.');
      return false;
    }
    if (schema.config == null) {
      _commandHelper.error('Schema is not valid. "config" is required.');
      return false;
    }
    if (schema.config!.bloc == null && schema.config!.riverpod == null) {
      _commandHelper.error('Schema is not valid. "config.bloc" or "config.riverpod" is required.');
      return false;
    }

    // In multi-response mode: warn if a method's response key is unknown.
    if (schema.isMultiResponse) {
      final validKeys = schema.responses!.keys.toSet();
      for (final method in schema.api!.methods!.method!.entries) {
        final resp = method.value.response;
        if (resp != null && !validKeys.contains(resp)) {
          _commandHelper.warning(
            'Method "${method.key}" declares response "$resp" which is not a key in the '
            '"response" section. Valid keys: ${validKeys.join(', ')}.',
          );
        }
      }
    }

    return true;
  }

  // ── Type resolution ───────────────────────────────────────────────────────

  /// Maps a schema type (e.g. `"string"`, `"int"`) to its Dart type string.
  ///
  /// This is a simple mapping meant for scaffolding; complex types should be
  /// updated by the developer after generation.
  String getDartType(dynamic type) {
    if (type == 'int' || type is int) {
      return 'int';
    }
    if (type == 'double' || type is double) {
      return 'double';
    }
    if (type == 'bool' || type is bool) {
      return 'bool';
    }
    if (type == 'list' || type is List) {
      return 'List<dynamic>';
    }
    if (type == 'map' || type is Map) {
      return 'Map<String, dynamic>';
    }
    if (type == 'string' || type is String) {
      return 'String';
    }
    return 'dynamic';
  }
}
