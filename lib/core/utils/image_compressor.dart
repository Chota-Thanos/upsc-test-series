import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressor {
  /// Compresses the image bytes in a background isolate to keep UI smooth.
  /// Decodes, resizes so max dimension is 1200px, and encodes to JPEG at 80% quality.
  static Future<Uint8List> compressImage(Uint8List bytes) async {
    return await compute(_resizeAndCompress, bytes);
  }

  static Uint8List _resizeAndCompress(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint("ImageCompressor: Failed to decode image.");
        return bytes;
      }

      img.Image resized = decoded;
      const maxDim = 1200;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        if (decoded.width > decoded.height) {
          resized = img.copyResize(decoded, width: maxDim);
        } else {
          resized = img.copyResize(decoded, height: maxDim);
        }
        debugPrint("ImageCompressor: Resized image from ${decoded.width}x${decoded.height} to ${resized.width}x${resized.height}");
      }

      // Encode as JPEG with 80% quality to dramatically reduce size while preserving readability
      final compressed = img.encodeJpg(resized, quality: 80);
      debugPrint("ImageCompressor: Compressed size: ${compressed.length} bytes (original: ${bytes.length} bytes)");
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint("ImageCompressor error: $e");
      return bytes;
    }
  }
}
