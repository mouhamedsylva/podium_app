import 'dart:io';
import 'package:image/image.dart' as img;

Future<void> main() async {
  stdout.writeln('🎨 Réduction et centrage du logo...\n');

  // Charger l'image originale
  const inputPath = 'assets/images/jirig.png';
  const outputPath = 'assets/images/jirig.png';

  if (!File(inputPath).existsSync()) {
    stderr.writeln('❌ Erreur : Fichier non trouvé : $inputPath');
    stderr.writeln('   Assurez-vous que le fichier existe à cet emplacement.');
    exit(1);
  }

  final imageBytes = await File(inputPath).readAsBytes();
  final originalImage = img.decodeImage(imageBytes);

  if (originalImage == null) {
    stderr.writeln('❌ Erreur : Impossible de décoder l\'image');
    exit(2);
  }

  stdout.writeln('📏 Dimensions originales : ${originalImage.width}x${originalImage.height}');

  // Calculer le facteur de réduction
  const scaleFactor = 0.40;
  final targetWidth = (originalImage.width * scaleFactor).round();
  final targetHeight = (originalImage.height * scaleFactor).round();

  // Déterminer la zone à conserver (supprimer la bordure unie)
  final cropped = _trimUniformBorder(originalImage);

  // Conserver le ratio du logo lors du redimensionnement
  final scale = [
    targetWidth / cropped.width,
    targetHeight / cropped.height,
  ].reduce((a, b) => a < b ? a : b);

  final resizedWidth = (cropped.width * scale).round().clamp(1, originalImage.width);
  final resizedHeight = (cropped.height * scale).round().clamp(1, originalImage.height);

  final resizedImage = img.copyResize(
    cropped,
    width: resizedWidth,
    height: resizedHeight,
    interpolation: img.Interpolation.cubic,
  );

  // Créer une image finale transparente
  final newImage = img.Image(
    width: originalImage.width,
    height: originalImage.height,
    numChannels: 4,
  );
  img.fill(newImage, color: img.ColorUint8.rgba(0, 0, 0, 0));

  // Centrer l'image recadrée
  final offsetX = (originalImage.width - resizedImage.width) ~/ 2;
  final offsetY = (originalImage.height - resizedImage.height) ~/ 2;

  // Copier l'image redimensionnée sur le fond transparent
  img.compositeImage(
    newImage,
    resizedImage,
    dstX: offsetX,
    dstY: offsetY,
    blend: img.BlendMode.alpha,
  );

  // Sauvegarder la nouvelle image
  await File(outputPath).writeAsBytes(img.encodePng(newImage));

  stdout.writeln('✅ Image optimisée créée : $outputPath');
  stdout.writeln('📊 Logo réduit à ${(scaleFactor * 100).round()}% de sa taille originale');
  stdout.writeln('🧼 Bordures blanches supprimées');
  stdout.writeln('\n🔧 Configuration recommandée dans flutter_launcher_icons.yaml :');
  stdout.writeln('   adaptive_icon_foreground: "$outputPath"');
  stdout.writeln('   adaptive_icon_background: "#FFFFFF" # Couleur personnalisée au besoin');
}

img.Image _trimUniformBorder(img.Image image, {int tolerance = 10}) {
  final bg = image.getPixel(0, 0);
  var left = image.width, right = -1, top = image.height, bottom = -1;

  bool similar(img.Pixel pixel) =>
      (pixel.r - bg.r).abs() <= tolerance &&
      (pixel.g - bg.g).abs() <= tolerance &&
      (pixel.b - bg.b).abs() <= tolerance;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (similar(pixel)) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }

  if (right == -1 || bottom == -1) {
    return image;
  }

  final width = right - left + 1;
  final height = bottom - top + 1;
  return img.copyCrop(image, x: left, y: top, width: width, height: height);
}