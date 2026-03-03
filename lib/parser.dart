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
/// enforces presentation configuration.
class Parser {
  /// Reads and deserialises the JSON schema file at [path] into a [Schema].
  Schema parse(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      CommandHelper().error('Schema file not found: $path');
    }
    final json = jsonDecode(file.readAsStringSync());
    return Schema.fromJson(json);
  }

  /// Builds a [Context] from a [featureName] and parsed [schema].
  ///
  /// Returns an empty context if validation fails. The caller is expected to
  /// halt or surface the error to the user. Response fields are collected into
  /// a nested tree with a root node matching the feature name.
  Future<Context> buildContext(String featureName, Schema schema) async {
    final projectRoot = Directory.current.path;
    final projectName = await YamlHelper().getProjectName(workingDirectory: projectRoot);

    if (!validateSchema(schema)) {
      return Context(
        name: '',
        nameLowerCase: '',
        nameCamelCase: '',
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

    final methods = <ContextMethod>[];
    // Build method-level context for usecase/event/bloc generation.
    final apiMethods = schema.api?.methods?.method ?? {};
    for (var method in apiMethods.entries) {
      final contextMethod = buildContextMethod(method);

      methods.add(contextMethod);
      if (contextMethod.hasUseCase) {
        generateUseCase = true;
      }
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
      fields: contextFields,
      methods: methods,
      generateUseCase: generateUseCase,
      projectRoot: projectRoot,
      projectName: projectName,
      config: schema.config ?? Config(),
    );
  }

  /// Converts an [ApiMethod] schema entry into a [ContextMethod].
  ///
  /// Params/body/query sections are expanded into nested field trees that can
  /// generate request models. The `hasUseCase` flag is derived from the
  /// presence of any params/body/query.
  ContextMethod buildContextMethod(MapEntry<String, ApiMethod> method) {
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
    );
  }

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

      // If nested JSON object → treat as custom model type
      if (value is Map<String, dynamic>) {
        final someData = buildContextFields(value, nestedFields);
        nestedFields.add(
          NestedContextField(name: entry.key.camelCaseToPascalCase(), properties: someData),
        );
        return ContextField(
          name: entry.key,
          type: entry.key.camelCaseToPascalCase(),
          isCustom: true,
        );
      }

      // If list of objects → List<CustomModel>
      if (value is List && value.isNotEmpty) {
        var type = "";
        var isCustom = false;
        if (value.first is Map<String, dynamic>) {
          nestedFields.add(
            NestedContextField(
              name: entry.key.camelCaseToPascalCase(),
              properties: buildContextFields(value.first, nestedFields),
            ),
          );
          type = entry.key.camelCaseToPascalCase();
          isCustom = true;
        } else {
          type = getDartType(value.first);
        }
        return ContextField(name: entry.key, type: "List<$type>", isList: true, isCustom: isCustom);
      }

      final type = getDartType(value);
      return ContextField(name: entry.key, type: type, isList: type.contains('List'));
    }).toList();
  }

  /// Validates that [schema] has the required sections and config.
  ///
  /// Requires `api`, `api.methods`, `response`, and `config`, with exactly one
  /// of `config.bloc` or `config.riverpod` set to true.
  ///
  /// Validation errors are reported via [CommandHelper] to ensure consistent
  /// CLI output.
  bool validateSchema(Schema schema) {
    if (schema.api == null) {
      CommandHelper().error('Schema is not valid. "api" is required.');
      return false;
    }
    if (schema.api?.methods == null) {
      CommandHelper().error('Schema is not valid. "api.methods" is required.');
      return false;
    }
    if (schema.response == null) {
      CommandHelper().error('Schema is not valid. "response" is required.');
      return false;
    }
    if (schema.config == null) {
      CommandHelper().error('Schema is not valid. "config" is required.');
      return false;
    }
    if (schema.config!.bloc == null && schema.config!.riverpod == null) {
      CommandHelper().error('Schema is not valid. "config.bloc" or "config.riverpod" is required.');
      return false;
    }
    return true;
  }

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
