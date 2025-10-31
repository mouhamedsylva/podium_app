import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Generates an Android adaptive icon foreground by transforming the existing
/// logo_mobile.png:
/// 1) Any fully transparent pixel becomes opaque white (center glyph)
/// 2) Any pixel close to the brand blue becomes fully transparent (background removed)
///
/// Input:  assets/img/logo_mobile.png
/// Output: assets/icons/jirig_fg_white.png
Future<void> main() async {
  final inputPath = 'assets/img/logo_mobile.png';
  final outputDirPath = 'assets/icons';
  final outputPath = '$outputDirPath/jirig_fg_white.png';

  if (!File(inputPath).existsSync()) {
    stderr.writeln('Input not found: $inputPath');
    exit(1);
  }

  Directory(outputDirPath).createSync(recursive: true);

  final bytes = await File(inputPath).readAsBytes();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('Failed to decode image: $inputPath');
    exit(2);
  }

  // Target brand blue (approx): #29B6F6 -> (41, 182, 246)
  const targetR = 41;
  const targetG = 182;
  const targetB = 246;
  const tolerance = 40; // generous tolerance for compression/anti-aliasing

  final out = img.Image.from(src);

  for (int y = 0; y < out.height; y++) {
    for (int x = 0; x < out.width; x++) {
      final c = out.getPixel(x, y);
      final a = img.getAlpha(c);
      final r = img.getRed(c);
      final g = img.getGreen(c);
      final b = img.getBlue(c);

      if (a == 0) {
        // Previously transparent -> paint white (center glyph)
        out.setPixelRgba(x, y, 255, 255, 255, 255);
        continue;
      }

      // Distance from target blue
      final dr = (r - targetR).toDouble();
      final dg = (g - targetG).toDouble();
      final db = (b - targetB).toDouble();
      final dist = sqrt(dr * dr + dg * dg + db * db);

      if (dist <= tolerance) {
        // Brand blue -> make transparent so background (adaptive) shows through
        out.setPixelRgba(x, y, r, g, b, 0);
      } else {
        // Keep as-is for edges/anti-aliased transition
        out.setPixelRgba(x, y, r, g, b, a);
      }
    }
  }

  // Optionally upscale to 1024x1024 for best results
  const targetSize = 1024;
  img.Image finalOut = out;
  if (out.width != targetSize || out.height != targetSize) {
    finalOut = img.copyResize(out, width: targetSize, height: targetSize, interpolation: img.Interpolation.cubic);
  }

  await File(outputPath).writeAsBytes(img.encodePng(finalOut));
  stdout.writeln('Generated: $outputPath (${finalOut.width}x${finalOut.height})');
}
