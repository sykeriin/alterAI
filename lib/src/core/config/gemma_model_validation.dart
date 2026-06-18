import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Validates Gemma `.litertlm` / `.task` files before native load.
class GemmaModelValidation {
  GemmaModelValidation._();

  static const _litertLmMagic = [0x4C, 0x49, 0x54, 0x45, 0x52, 0x54, 0x4C, 0x4D];

  static int? minimumBytesForFilename(String filename) {
    final lower = filename.toLowerCase();
    // HF sizes (Jun 2026): E4B ~3660 MB, E2B ~2468 MB — use ~95% as floor.
    if (lower.contains('e4b') && lower.endsWith('.litertlm')) return 3400000000;
    if (lower.contains('e2b') && lower.endsWith('.litertlm')) return 2400000000;
    if (lower.contains('e4b') && lower.endsWith('.task')) return 2800000000;
    if (lower.endsWith('.litertlm')) return 50 * 1024 * 1024;
    if (lower.endsWith('.task')) return 50 * 1024 * 1024;
    return null;
  }

  static Future<String> pathForInstalledId(String modelId) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, modelId);
  }

  static Future<String?> validateFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return 'Model file missing. Remove and download again.';
    }

    final name = p.basename(filePath);
    final size = await file.length();
    final minBytes = minimumBytesForFilename(name);
    if (minBytes != null && size < minBytes) {
      final sizeMb = (size / (1024 * 1024)).round();
      final minMb = (minBytes / (1024 * 1024)).round();
      return 'Download incomplete ($sizeMb MB of ~$minMb MB). '
          'Remove and re-download on stable Wi‑Fi — keep the app open.';
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      final head = await raf.read(64);
      if (head.isEmpty) return 'Model file is empty. Remove and download again.';

      final asText = String.fromCharCodes(head.where((b) => b >= 32 && b <= 126));
      if (asText.startsWith('version https://git-lfs.github.com')) {
        return 'Downloaded a Git LFS stub, not the model. Remove and try again.';
      }
      if (asText.trimLeft().startsWith('<!DOCTYPE') ||
          asText.trimLeft().startsWith('<html')) {
        return 'Download failed (HTML error page). Check URL and connection.';
      }
      if (_startsWithLitertLm(head)) return null;
      // Older bundles may be zip-based (.task or legacy .litertlm).
      if (head.length >= 2 && head[0] == 0x50 && head[1] == 0x4B) return null;
      return 'File is not a valid model archive. Remove and download again.';
    } finally {
      await raf.close();
    }
  }

  static Future<String?> validateInstalledModel(String modelId) async {
    return validateFile(await pathForInstalledId(modelId));
  }

  static bool _startsWithLitertLm(List<int> head) {
    if (head.length < _litertLmMagic.length) return false;
    for (var i = 0; i < _litertLmMagic.length; i++) {
      if (head[i] != _litertLmMagic[i]) return false;
    }
    return true;
  }
}
