import 'dart:io';
import 'dart:isolate';

import 'package:feature_gen_cli/string_extension.dart';
import 'package:feature_gen_cli/types.dart';
import 'package:mustache_template/mustache.dart';

/// Creates the feature directory structure and renders Mustache templates
/// into Dart source files.
///
/// The generator is file-system focused and deliberately avoids business logic.
/// It expects a fully prepared [Context] and respects the configured
/// presentation layer (bloc or riverpod). Existing generated files are
/// overwritten when the same paths are produced.
class Generator {
  /// Creates directories and generates all boilerplate files for the feature.
  Future<void> generateFeature(Context context, {bool overwrite = false}) async {
    final featureName = context.nameLowerCase;
    final basePath = '${context.projectRoot}/lib/features/$featureName';
    final generateUseCase = context.generateUseCase;

    // Resolve templates from within the feature_gen_cli package itself.
    final packageUri = Uri.parse('package:feature_gen_cli/');
    final libUri = await Isolate.resolvePackageUri(packageUri);
    if (libUri == null) {
      throw StateError('Could not resolve package:feature_gen_cli – is the package activated?');
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
      if (context.config.bloc == true || context.config.riverpod == true)
        '$basePath/presentation/screen',
    ];

    if (generateUseCase) {
      folders.add('${context.projectRoot}/lib/features/shared/usecase');
    }

    // Create core folders
    folders.add('${context.projectRoot}/lib/core/di');

    for (var folder in folders) {
      Directory(folder).createSync(recursive: true);
    }

    generateBoilerplate(
      featureName: featureName,
      basePath: basePath,
      templateBasePath: templateBasePath,
      context: context,
      overwrite: overwrite,
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
    required bool overwrite,
  }) {
    // Injector
    renderTemplate(
      '$templateBasePath/injector.mustache',
      '${context.projectRoot}/lib/core/di/injector.dart',
      {"projectName": context.projectName},
      overwrite: overwrite,
    );

    // Model
    renderTemplate(
      '$templateBasePath/data/model.mustache',
      '$basePath/data/models/${featureName}_model.dart',
      context.toMap(),
      overwrite: overwrite,
    );

    // Entity
    renderTemplate(
      '$templateBasePath/domain/entity.mustache',
      '$basePath/domain/entities/${featureName}_entity.dart',
      context.toMap(),
      overwrite: overwrite,
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
      overwrite: overwrite,
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
      overwrite: overwrite,
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
      overwrite: overwrite,
    );

    // Use Cases
    if (context.generateUseCase) {
      renderTemplate(
        '$templateBasePath/usecase.mustache',
        '${context.projectRoot}/lib/features/shared/usecase/usecase.dart',
        context.toMap(),
        overwrite: overwrite,
      );

      for (var method in context.methods) {
        renderTemplate(
          '$templateBasePath/domain/usecase.mustache',
          '$basePath/domain/usecases/${method.methodName.camelCaseToSnakeCase()}_usecase.dart',
          {
            'name': context.name,
            'isList': context.isList,
            'nameLowerCase': context.nameLowerCase,
            'nameCamelCase': context.nameCamelCase,
            'projectName': context.projectName,
            ...method.toMap(),
          },
          overwrite: overwrite,
        );
      }
    }

    if (context.config.bloc == true) {
      // Bloc
      renderTemplate(
        '$templateBasePath/presentation/bloc/bloc.mustache',
        '$basePath/presentation/bloc/${featureName}_bloc.dart',
        {
          ...context.toMap(),
          "methods": context.methods
              .map(
                (e) => {...e.toMap(), "methodNameLowerCase": e.methodName.camelCaseToSnakeCase()},
              )
              .toList(),
        },
        overwrite: overwrite,
      );

      // Event
      renderTemplate(
        '$templateBasePath/presentation/bloc/event.mustache',
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
        overwrite: overwrite,
      );

      // State
      renderTemplate(
        '$templateBasePath/presentation/bloc/state.mustache',
        '$basePath/presentation/bloc/${featureName}_state.dart',
        {
          'name': context.name,
          'isList': context.isList,
          'nameLowerCase': context.nameLowerCase,
          'nameCamelCase': context.nameCamelCase,
          ...context.toMap(),
        },
        overwrite: overwrite,
      );

      // Screen
      renderTemplate(
        '$templateBasePath/presentation/screen/screen_bloc.mustache',
        '$basePath/presentation/screen/${featureName}_screen.dart',
        context.toMap(),
        overwrite: overwrite,
      );
    }

    if (context.config.riverpod == true) {
      // Notifier
      renderTemplate(
        '$templateBasePath/presentation/riverpod/notifier.mustache',
        '$basePath/presentation/riverpod/${featureName}_notifier.dart',
        {
          ...context.toMap(),
          "methods": context.methods
              .map(
                (e) => {...e.toMap(), "methodNameLowerCase": e.methodName.camelCaseToSnakeCase()},
              )
              .toList(),
        },
        overwrite: overwrite,
      );

      // Screen
      renderTemplate(
        '$templateBasePath/presentation/screen/screen_riverpod.mustache',
        '$basePath/presentation/screen/${featureName}_screen.dart',
        context.toMap(),
        overwrite: overwrite,
      );
    }
  }

  /// Reads a `.mustache` template, injects [context] values, and writes to [outPath]
  /// only if it does not already exist.
  ///
  /// This is intentionally synchronous to keep file creation predictable.
  void renderTemplate(
    String templatePath,
    String outPath,
    Map<String, dynamic> context, {
    required bool overwrite,
  }) {
    final outFile = File(outPath);
    if (!overwrite && outFile.existsSync()) {
      return;
    }
    final templateString = File(templatePath).readAsStringSync();
    final template = Template(templateString);
    final result = template.renderString(context);
    outFile.writeAsStringSync(result);
  }
}
