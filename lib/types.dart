/// Top-level schema representation parsed from the user's JSON file.
///
/// This mirrors the user-provided schema shape closely to keep parsing simple,
/// while enabling nested response trees and presentation configuration.
class Schema {
  final Api? api;
  final Map<String, dynamic>? response;
  final Config? config;

  Schema({this.api, this.response, this.config});

  factory Schema.fromJson(Map<String, dynamic> json) {
    return Schema(
      api: json['api'] == null ? null : Api.fromJson(json['api'] as Map<String, dynamic>),
      response: json['response'] as Map<String, dynamic>?,
      config: json['config'] == null
          ? null
          : Config.fromJson(json['config'] as Map<String, dynamic>),
    );
  }
}

/// Controls which presentation layer is generated.
///
/// Exactly one of [bloc] or [riverpod] must be true when provided.
class Config {
  final bool? bloc;
  final bool? riverpod;

  Config({this.bloc, this.riverpod}) {
    if (bloc == null && riverpod == null) {
      return;
    }
    if (!(bloc! ^ riverpod!)) {
      throw ArgumentError(
        'Exactly one of "bloc" or "riverpod" must be true in the config section.',
      );
    }
  }

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(bloc: json['bloc'] as bool?, riverpod: json['riverpod'] as bool?);
  }

  Map<String, dynamic> toMap() {
    return {'bloc': bloc, 'riverpod': riverpod};
  }
}

/// Represents the `api` section of the schema.
///
/// The API section currently focuses on method contracts (params/body/query)
/// that drive request model generation.
class Api {
  final Methods? methods;

  Api({this.methods});

  factory Api.fromJson(Map<String, dynamic> json) {
    return Api(
      methods: json['methods'] == null
          ? null
          : Methods.fromJson(json['methods'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() {
    return {'methods': methods?.toMap()};
  }
}

/// Container for named [ApiMethod] entries.
///
/// The map key is the method name used for generated files and symbols.
class Methods {
  final Map<String, ApiMethod>? method;

  Methods({this.method});

  factory Methods.fromJson(Map<String, dynamic> json) {
    return Methods(method: json.map((key, value) => MapEntry(key, ApiMethod.fromJson(value))));
  }

  Map<String, dynamic> toMap() {
    return {'method': method};
  }
}

/// A single API method's input contract (params, body, query).
///
/// All fields are optional to allow lightweight endpoints and read-only calls.
class ApiMethod {
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? query;

  ApiMethod({this.params, this.body, this.query});

  factory ApiMethod.fromJson(Map<String, dynamic> json) {
    return ApiMethod(
      params: json['params'] as Map<String, dynamic>?,
      body: json['body'] as Map<String, dynamic>?,
      query: json['query'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'params': params, 'body': body, 'query': query};
  }
}

/// Template-ready representation of an API method.
///
/// Params/body/query are represented as nested field trees so templates can
/// generate request models.
class ContextMethod {
  final String methodName;
  final String methodNamePascalCase;
  final List<NestedContextField>? params;
  final List<NestedContextField>? body;
  final List<NestedContextField>? query;
  final bool hasUseCase;
  final bool hasParams;
  final bool hasBody;
  final bool hasQuery;

  ContextMethod({
    required this.methodName,
    required this.methodNamePascalCase,
    this.params,
    this.body,
    this.query,
    required this.hasParams,
    required this.hasBody,
    required this.hasQuery,
    required this.hasUseCase,
  });

  Map<String, dynamic> toMap() {
    return {
      'methodName': methodName,
      'methodNamePascalCase': methodNamePascalCase,
      'params': params?.map((e) => e.toMap()).toList(),
      'body': body?.map((e) => e.toMap()).toList(),
      'query': query?.map((e) => e.toMap()).toList(),
      'hasParams': hasParams,
      'hasBody': hasBody,
      'hasQuery': hasQuery,
      'hasUseCase': hasUseCase,
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

/// Template-ready representation of a nested field.
///
/// A root node represents a request/response model, while children represent
/// nested object properties.
class NestedContextField {
  final String name;
  final List<ContextField> properties;
  final bool isRoot;

  NestedContextField({required this.name, required this.properties, this.isRoot = false});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'properties': properties.map((e) => e.toMap()).toList(),
      'isRoot': isRoot,
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

/// A name/type pair representing a field or parameter.
///
/// Used for response fields, request models, and nested object properties.
class ContextField {
  final String name;
  final String type;
  final bool isList;
  final bool isMap;
  final bool isCustom;

  ContextField({
    required this.name,
    required this.type,
    this.isList = false,
    this.isMap = false,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'type': type, 'isList': isList, 'isMap': isMap, 'isCustom': isCustom};
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

/// Root context passed to the Mustache template engine for code generation.
///
/// This is the single source of truth for all template rendering, including
/// nested models, API method contracts, and presentation-layer selection.
class Context {
  final String name;
  final String nameLowerCase;
  final String nameCamelCase;
  final List<NestedContextField> fields;
  final List<ContextMethod> methods;
  final bool generateUseCase;
  final String projectRoot;
  final String projectName;
  final Config config;

  Context({
    required this.name,
    required this.nameLowerCase,
    required this.nameCamelCase,
    required this.fields,
    required this.methods,
    required this.generateUseCase,
    required this.projectRoot,
    required this.projectName,
    required this.config,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameLowerCase': nameLowerCase,
      'nameCamelCase': nameCamelCase,
      'fields': fields.map((field) => field.toMap()).toList(),
      'methods': methods.map((method) => method.toMap()).toList(),
      'generateUseCase': generateUseCase,
      'projectRoot': projectRoot,
      'projectName': projectName,
      'config': config.toMap(),
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }
}
