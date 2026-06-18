import 'package:flutter_gemma/flutter_gemma.dart';

/// Maps download URLs / filenames to flutter_gemma install options.
class GemmaModelSpec {
  const GemmaModelSpec({
    required this.modelType,
    required this.fileType,
  });

  final ModelType modelType;
  final ModelFileType fileType;

  static GemmaModelSpec forUrl(String url) {
    final lower = url.trim().toLowerCase();
    final fileType = lower.endsWith('.litertlm')
        ? ModelFileType.litertlm
        : ModelFileType.task;
    return GemmaModelSpec(
      modelType: _modelTypeForName(lower),
      fileType: fileType,
    );
  }

  static GemmaModelSpec forFilename(String filename) => forUrl(filename);

  static ModelType _modelTypeForName(String lower) {
    if (lower.contains('gemma-4') ||
        lower.contains('gemma4') ||
        lower.contains('4-e4b') ||
        lower.contains('4-e2b')) {
      return ModelType.gemma4;
    }
    return ModelType.gemmaIt;
  }

  /// Gemma 4 `.task` is web MediaPipe only — not loadable on Android.
  static String? androidIncompatibility(String filename) {
    final lower = filename.toLowerCase();
    if ((lower.contains('gemma-4') ||
            lower.contains('4-e4b') ||
            lower.contains('4-e2b')) &&
        lower.endsWith('.task')) {
      return 'Gemma 4 on Android needs a .litertlm file, not .task. '
          'Remove the model and download again from Settings → EDGE.';
    }
    return null;
  }
}
