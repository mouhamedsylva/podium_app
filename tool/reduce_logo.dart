import 'dart:io';
import 'package:image/image.dart' as img;

Future<void> main() async {
  stdout.writeln('🎨 Réduction et centrage du logo...\n');

  // Charger l'image originale
  const inputPath = 'assets/images/logo-tiaka-rv.png';
  const outputPath = 'assets/images/logo_picturelogo-tiaka-rv-optimized.png';

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

  // Créer une nouvelle image de la même taille avec fond TRANSPARENT
  final newImage = img.Image(
    width: originalImage.width,
    height: originalImage.height,
    numChannels: 4, // RGBA pour supporter la transparence
  );

  // Remplir avec un fond TRANSPARENT (alpha = 0)
  img.fill(newImage, color: img.ColorUint8.rgba(0, 0, 0, 0));

  // Calculer les dimensions pour réduire le logo
  const scaleFactor = 0.85;
  final newWidth = (originalImage.width * scaleFactor).round();
  final newHeight = (originalImage.height * scaleFactor).round();

  // Redimensionner l'image originale
  final resizedImage = img.copyResize(
    originalImage,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.average,
  );

  // Calculer la position pour centrer
  final offsetX = (originalImage.width - newWidth) ~/ 2;
  final offsetY = (originalImage.height - newHeight) ~/ 2;

  // Composer l'image : copier le logo réduit au centre
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
  stdout.writeln('📱 Fond transparent pour Android adaptive icons');
  stdout.writeln('\n🔧 Configuration recommandée dans flutter_launcher_icons.yaml :');
  stdout.writeln('   adaptive_icon_foreground: "$outputPath"');
  stdout.writeln('   adaptive_icon_background: "#FFFFFF" # Blanc uniforme');
}