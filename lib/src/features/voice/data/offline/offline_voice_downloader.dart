import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Downloads archives and extracts them into [destRoot].
class OfflineVoiceDownloader {
  OfflineVoiceDownloader(this._client);

  final http.Client _client;

  Future<void> downloadArchive({
    required String url,
    required String destRoot,
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('Download failed (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    final chunks = <int>[];
    var received = 0;
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }

    final bytes = Uint8List.fromList(chunks);
    if (url.endsWith('.tar.bz2')) {
      await _extractTarBz2(bytes, destRoot);
    } else if (url.endsWith('.onnx')) {
      final dir = Directory(destRoot);
      await dir.create(recursive: true);
      final file = File(p.join(destRoot, p.basename(url)));
      await file.writeAsBytes(bytes, flush: true);
    } else {
      throw UnsupportedError('Unsupported archive: $url');
    }
  }

  Future<void> _extractTarBz2(List<int> bytes, String destRoot) async {
    final decompressed = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(decompressed);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = file.name.replaceAll('\\', '/');
      final outPath = p.join(destRoot, normalized);
      final outFile = File(outPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>, flush: true);
    }
  }

  /// Finds first file ending with [suffix] under [root].
  static Future<String?> findFile(String root, String suffix) async {
    final dir = Directory(root);
    if (!await dir.exists()) return null;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith(suffix)) {
        return entity.path;
      }
    }
    return null;
  }

  static Future<String?> findDirectoryNamed(String root, String name) async {
    final dir = Directory(root);
    if (!await dir.exists()) return null;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is Directory && p.basename(entity.path) == name) {
        return entity.path;
      }
    }
    return null;
  }
}
