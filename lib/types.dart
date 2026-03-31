/// Top-level schema representation parsed from the user's JSON file.
///
/// This mirrors the user-provided schema shape closely to keep parsing simple,
/// while enabling nested response trees and presentation configuration for
/// code generation.
class Schema {
  final Api? api;

  /// Single-response mode: the flat field map (or null in multi-response mode).
  final Map<String, dynamic>? response;

  /// Multi-response mode: map of entity-key → (field map, isList flag).
  ///
  /// Populated when the `response` JSON value has all-object top-level values,
  /// e.g. `{ "user": { ... }, "token": { ... } }`.
  final Map<String, (Map<String, dynamic>, bool)>? responses;

  final Config? config;

  /// Whether the response is an array at the root level (single-response mode).
  final bool isList;

  /// True when the `response` key uses the multi-response format.
  final bool isMultiResponse;

  Schema({
    this.api,
    this.response,
    this.responses,
    this.config,
    this.isList = false,
    this.isMultiResponse = false,
  });

  factory Schema.fromJson(Map<String, dynamic> json) {
    final rawResponse = json['response'];
    bool isMultiResponse = false;
    Map<String, dynamic>? singleResponse;
    bool isList = false;
    Map<String, (Map<String, dynamic>, bool)>? multiResponses;

    if (rawResponse is List) {
      // Existing array-wrapped single response.
      singleResponse = rawResponse.isEmpty
          ? {}
          : Map<String, dynamic>.from(rawResponse.first as Map);
      isList = true;
    } else if (rawResponse is Map) {
      final responseMap = Map<String, dynamic>.from(rawResponse);
      // Detect multi-response: ALL top-level values must be Maps (or Lists of Maps).
      final allObjects = responseMap.values.every(
        (v) =>
            v is Map ||
            (v is List && v.isNotEmpty && v.first is Map),
      );

      if (allObjects && responseMap.isNotEmpty) {
        isMultiResponse = true;
        multiResponses = responseMap.map((key, value) {
          if (value is List) {
            return MapEntry(key, (Map<String, dynamic>.from(value.first as Map), true));
          }
          return MapEntry(key, (Map<String, dynamic>.from(value as Map), false));
        });
      } else {
        // Mixed / primitive values → existing single-response.
        singleResponse = responseMap;
      }
    }

    return Schema(
      api: json['api'] == null
          ? null
          : Api.fromJson(Map<String, dynamic>.from(json['api'] as Map)),
      response: singleResponse,
      responses: multiResponses,
      config: json['config'] == null
          ? null
          : Config.fromJson(Map<String, dynamic>.from(json['config'] as Map)),
      isList: isList,
      isMultiResponse: isMultiResponse,
    );
  }

  /// Unwraps array responses for single-response mode, returning inner element map and flag.
  static (Map<String, dynamic>, bool) responseParser(dynamic response) {
    if (response is List) {
      return (response.first, true);
    }
    return (response, false);
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
/// The API section focuses on method contracts (params/body/query)
/// that drive request model generation and use-case wiring.
class Api {
  final Methods? methods;

  Api({this.methods});

  factory Api.fromJson(Map<String, dynamic> json) {
    return Api(
      methods: json['methods'] == null
          ? null
          : Methods.fromJson(Map<String, dynamic>.from(json['methods'] as Map)),
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
    return Methods(
      method: json.map(
        (key, value) => MapEntry(key, ApiMethod.fromJson(Map<String, dynamic>.from(value as Map))),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {'method': method};
  }
}

/// A single API method's input contract (params, body, query) plus optional response ref.
///
/// All fields are optional to allow lightweight endpoints and read-only calls.
class ApiMethod {
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? query;

  /// The response entity key (e.g. `"user"`, `"token"`).
  ///
  /// In multi-response mode this links the method to a named entry in
  /// `Schema.responses`. In single-response mode this field is ignored.
  /// An array-wrapped value (e.g. `["user"]`) sets [responseIsList] to true.
  final String? response;

  /// True when the `response` key was written as a single-element array,
  /// meaning the method returns a list of the referenced entity.
  final bool responseIsList;

  ApiMethod({this.params, this.body, this.query, this.response, this.responseIsList = false});

  factory ApiMethod.fromJson(Map<String, dynamic> json) {
    String? response;
    bool responseIsList = false;

    final rawResponse = json['response'];
    if (rawResponse is List && rawResponse.isNotEmpty) {
      response = rawResponse.first as String;
      responseIsList = true;
    } else if (rawResponse is String) {
      response = rawResponse;
    }

    return ApiMethod(
      params: json['params'] as Map<String, dynamic>?,
      body: json['body'] as Map<String, dynamic>?,
      query: json['query'] as Map<String, dynamic>?,
      response: response,
      responseIsList: responseIsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'params': params,
      'body': body,
      'query': query,
      'response': response,
      'responseIsList': responseIsList,
    };
  }
}

/// Template-ready representation of an API method.
///
/// Params/body/query are represented as nested field trees so templates can
/// generate request models and parameter classes.
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

  /// PascalCase entity name this method returns, e.g. `"User"` or `"Token"`.
  /// Null in single-response mode or when the method returns void.
  final String? responseEntityName;

  /// lowercase entity name, e.g. `"user"`. Used for import paths.
  final String? responseEntityNameLower;

  /// camelCase entity name, e.g. `"user"`. Used for variable names.
  final String? responseEntityCamelCase;

  /// Whether the method returns a list of the entity.
  final bool responseIsList;

  /// False for void-return methods (no `response` key in multi-response mode).
  final bool hasResponse;

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
    this.responseEntityName,
    this.responseEntityNameLower,
    this.responseEntityCamelCase,
    this.responseIsList = false,
    this.hasResponse = false,
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
      'responseEntityName': responseEntityName,
      'responseEntityNameLower': responseEntityNameLower,
      'responseEntityCamelCase': responseEntityCamelCase,
      'responseIsList': responseIsList,
      'hasResponse': hasResponse,
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
  final String jsonKey;
  final bool hasJsonKey;

  ContextField({
    required this.name,
    required this.type,
    this.isList = false,
    this.isMap = false,
    this.isCustom = false,
    required this.jsonKey,
    required this.hasJsonKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'isList': isList,
      'isMap': isMap,
      'isCustom': isCustom,
      'jsonKey': jsonKey,
      'hasJsonKey': hasJsonKey,
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

/// Template-ready representation of a single named response entity.
///
/// Used in multi-response mode to drive per-entity file generation
/// and to build deduplicated import lists in templates.
class EntityContext {
  /// PascalCase name, e.g. `"User"`.
  final String name;

  /// lowercase name, e.g. `"user"`.
  final String nameLower;

  /// camelCase name, e.g. `"user"`.
  final String nameCamelCase;

  /// True when the response was array-wrapped (`["user"]`).
  final bool isList;

  /// Flat + nested fields for this entity (same shape as [Context.fields]).
  final List<NestedContextField> fields;

  EntityContext({
    required this.name,
    required this.nameLower,
    required this.nameCamelCase,
    required this.isList,
    required this.fields,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameLower': nameLower,
      'nameCamelCase': nameCamelCase,
      'isList': isList,
      'fields': fields.map((f) => f.toMap()).toList(),
    };
  }

  @override
  String toString() => toMap().toString();
}

/// Root context passed to the Mustache template engine for code generation.
///
/// This is the single source of truth for all template rendering, including
/// nested models, API method contracts, and presentation-layer selection.
class Context {
  final String name;
  final String nameLowerCase;
  final String nameCamelCase;
  final bool isList;
  final List<NestedContextField> fields;
  final List<ContextMethod> methods;
  final bool generateUseCase;
  final String projectRoot;
  final String projectName;
  final Config config;

  /// True when the schema uses the multi-response format.
  final bool isMultiResponse;

  /// All named entity contexts; populated in multi-response mode.
  final List<EntityContext> entities;

  Context({
    required this.name,
    required this.nameLowerCase,
    required this.nameCamelCase,
    required this.isList,
    required this.fields,
    required this.methods,
    required this.generateUseCase,
    required this.projectRoot,
    required this.projectName,
    required this.config,
    this.isMultiResponse = false,
    this.entities = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameLowerCase': nameLowerCase,
      'nameCamelCase': nameCamelCase,
      'isList': isList,
      'fields': fields.map((field) => field.toMap()).toList(),
      'methods': methods.map((method) => method.toMap()).toList(),
      'generateUseCase': generateUseCase,
      'projectRoot': projectRoot,
      'projectName': projectName,
      'config': config.toMap(),
      'isMultiResponse': isMultiResponse,
      'entities': entities.map((e) => e.toMap()).toList(),
    };
  }

  @override
  String toString() {
    return toMap().toString();
  }
}
