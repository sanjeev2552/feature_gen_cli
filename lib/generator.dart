import 'dart:io';
import 'dart:isolate';

import 'package:feature_gen/string_extension.dart';
import 'package:feature_gen/types.dart';
import 'package:mustache_template/mustache.dart';

/// Creates the feature directory structure and renders Mustache templates
/// into Dart source files.
///
/// The generator is file-system focused and deliberately avoids business logic.
/// It expects a fully prepared [Context] and respects the configured
/// presentation layer (bloc or riverpod).
class Generator {
  /// Creates directories and generates all boilerplate files for the feature.
  Future<void> generateFeature(Context context) async {
    final featureName = context.nameLowerCase;
    final basePath = '${context.projectRoot}/lib/features/$featureName';
    final generateUseCase = context.generateUseCase;

    // Resolve templates from within the feature_gen package itself.
    final packageUri = Uri.parse('package:feature_gen/');
    final libUri = await Isolate.resolvePackageUri(packageUri);
    if (libUri == null) {
      throw StateError('Could not resolve package:feature_gen – is the package activated?');
    }
    final templateBasePath = libUri.resolve('template').toFilePath();

    // Create feature folders in a conventional clean-architecture layout.
    final folders = [
      '$basePath/data/models',
      '$basePath/data/repositories',
      '$basePath/data/datasources',
      '$basePath/domain/entities',
      '$basePath/domain/repositories',
      if (generateUseCase) '$basePath/domain/usecases',
      if (context.config.bloc == true) '$basePath/presentation/bloc',
      if (context.config.riverpod == true) '$basePath/presentation/riverpod',
    ];

    if (generateUseCase) {
      folders.add('${context.projectRoot}/lib/features/shared/usecase');
    }

    for (var folder in folders) {
      Directory(folder).createSync(recursive: true);
    }

    generateBoilerplate(
      featureName: featureName,
      basePath: basePath,
      templateBasePath: templateBasePath,
      context: context,
    );
  }

  /// Renders all Mustache templates (model, entity, repository, datasource,
  /// usecase, bloc/event/state, or riverpod notifier) into the feature directory.
  ///
  /// Each template receives a simple map to keep the generator decoupled
  /// from the Mustache engine.
  void generateBoilerplate({
    required String featureName,
    required String basePath,
    required String templateBasePath,
    required Context context,
  }) {
    // Model
    renderTemplate(
      '$templateBasePath/data/model.mustache',
      '$basePath/data/models/${featureName}_model.dart',
      context.toMap(),
    );

    // Entity
    renderTemplate(
      '$templateBasePath/domain/entity.mustache',
      '$basePath/domain/entities/${featureName}_entity.dart',
      context.toMap(),
    );

    // Repository
    renderTemplate(
      '$templateBasePath/domain/repository.mustache',
      '$basePath/domain/repositories/${featureName}_repository.dart',
      {
        ...context.toMap(),
        "methods": context.methods
            .map((e) => {...e.toMap(), "methodNameLowerCase": e.methodName.camelCaseToSnakeCase()})
            .toList(),
      },
    );

    // Repository Impl
    renderTemplate(
      '$templateBasePath/data/repository_impl.mustache',
      '$basePath/data/repositories/${featureName}_repository_impl.dart',
      {
        ...context.toMap(),
        "methods": context.methods
            .map((e) => {...e.toMap(), "methodNameLowerCase": e.methodName.camelCaseToSnakeCase()})
            .toList(),
      },
    );

    // Remote Datasource
    renderTemplate(
      '$templateBasePath/data/remote_datasource.mustache',
      '$basePath/data/datasources/${featureName}_remote_datasource.dart',
      {
        ...context.toMap(),
        "methods": context.methods
            .map((e) => {...e.toMap(), "methodNameLowerCase": e.methodName.camelCaseToSnakeCase()})
            .toList(),
      },
    );

    // Use Cases
    if (context.generateUseCase) {
      renderTemplate(
        '$templateBasePath/base_usecase.mustache',
        '${context.projectRoot}/lib/features/shared/usecase/base_usecase.dart',
        context.toMap(),
      );

      for (var method in context.methods) {
        renderTemplate(
          '$templateBasePath/domain/usecase.mustache',
          '$basePath/domain/usecases/${method.methodName.camelCaseToSnakeCase()}_usecase.dart',
          {
            'name': context.name,
            'nameLowerCase': context.nameLowerCase,
            'nameCamelCase': context.nameCamelCase,
            'projectName': context.projectName,
            ...method.toMap(),
          },
        );
      }
    }

    if (context.config.bloc == true) {
      // Bloc
      renderTemplate(
        '$templateBasePath/bloc/bloc.mustache',
        '$basePath/presentation/bloc/${featureName}_bloc.dart',
        {
          ...context.toMap(),
          "methods": context.methods
              .map(
                (e) => {...e.toMap(), "methodNameLowerCase": e.methodName.camelCaseToSnakeCase()},
              )
              .toList(),
        },
      );

      // Event
      renderTemplate(
        '$templateBasePath/bloc/event.mustache',
        '$basePath/presentation/bloc/${featureName}_event.dart',
        {
          'name': context.name,
          'projectName': context.projectName,
          "methods": context.methods
              .map(
                (e) => {
                  ...e.toMap(),
                  "methodNameLowerCase": e.methodName.camelCaseToSnakeCase(),
                  'nameLowerCase': context.nameLowerCase,
                },
              )
              .toList(),
        },
      );

      // State
      renderTemplate(
        '$templateBasePath/bloc/state.mustache',
        '$basePath/presentation/bloc/${featureName}_state.dart',
        {
          'name': context.name,
          'nameLowerCase': context.nameLowerCase,
          'nameCamelCase': context.nameCamelCase,
          ...context.toMap(),
        },
      );
    }

    if (context.config.riverpod == true) {
      // Notifier
      renderTemplate(
        '$templateBasePath/riverpod/notifier.mustache',
        '$basePath/presentation/riverpod/${featureName}_notifier.dart',
        {
          ...context.toMap(),
          "methods": context.methods
              .map(
                (e) => {...e.toMap(), "methodNameLowerCase": e.methodName.camelCaseToSnakeCase()},
              )
              .toList(),
        },
      );
    }
  }

  /// Reads a `.mustache` template, injects [context] values, and writes to [outPath].
  ///
  /// This is intentionally synchronous to keep file creation predictable.
  void renderTemplate(String templatePath, String outPath, Map<String, dynamic> context) {
    final templateString = File(templatePath).readAsStringSync();
    final template = Template(templateString);
    final result = template.renderString(context);
    File(outPath).writeAsStringSync(result);
  }
}
