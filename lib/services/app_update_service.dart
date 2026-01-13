import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../models/app_version_info.dart';
import 'package:url_launcher/url_launcher.dart';

// package_info_plus est utilisé uniquement sur Android/iOS
// Sur web, on retourne null avant d'utiliser ce package
import 'package:package_info_plus/package_info_plus.dart';

/// Service pour gérer les mises à jour de l'application
/// Supporte uniquement Android et iOS (pas web)
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final ApiService _apiService = ApiService();

  /// Vérifier si une mise à jour est disponible
  /// 
  /// Retourne [AppVersionInfo] si une mise à jour est nécessaire/disponible,
  /// `null` sinon ou en cas d'erreur
  /// 
  /// ⚠️ Fonctionne uniquement sur Android et iOS (pas sur web)
  Future<AppVersionInfo?> checkForUpdate() async {
    // Vérifier la plateforme dès le début
    if (kIsWeb) {
      print('⚠️ Vérification de mise à jour non supportée sur web');
      return null;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      print('⚠️ Plateforme non supportée: ${Platform.operatingSystem}');
      return null;
    }

    try {
      print('🔍 Vérification des mises à jour...');

      // Récupérer la version actuelle de l'application
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // ex: "1.5.0"
      final buildNumber = packageInfo.buildNumber; // ex: "1"

      print('📱 Version actuelle: $currentVersion (build: $buildNumber)');

      // Déterminer la plateforme
      final platform = Platform.isAndroid ? 'android' : 'ios';

      // Appeler l'API backend
      final versionInfo = await _apiService.getAppVersionInfo(
        version: currentVersion,
        platform: platform,
      );

      if (versionInfo == null) {
        print('❌ Impossible de récupérer les informations de version');
        return null;
      }

      // Vérifier si la configuration est active
      if (!versionInfo.active) {
        print('⚠️ Configuration de version désactivée');
        return null;
      }

      // Retourner les informations seulement si une mise à jour est disponible ou requise
      if (versionInfo.updateAvailable || versionInfo.updateRequired) {
        print('✅ Mise à jour détectée:');
        print('   Update Available: ${versionInfo.updateAvailable}');
        print('   Update Required: ${versionInfo.updateRequired}');
        print('   Force Update: ${versionInfo.forceUpdate}');
        return versionInfo;
      }

      print('✅ Application à jour (${versionInfo.currentVersion})');
      return null;
    } catch (e) {
      print('❌ Erreur lors de la vérification de mise à jour: $e');
      return null;
    }
  }

  /// Ouvrir le store (Play Store / App Store) pour mettre à jour l'application
  /// 
  /// [updateUrl] : URL vers le store (fournie par le backend)
  /// 
  /// Retourne `true` si l'ouverture a réussi, `false` sinon
  Future<bool> openStore(String updateUrl) async {
    try {
      print('🔗 Ouverture du store: $updateUrl');
      
      final uri = Uri.parse(updateUrl);
      
      // Vérifier si l'URL peut être lancée
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Ouvre dans l'app store
        );
        
        if (launched) {
          print('✅ Store ouvert avec succès');
          return true;
        } else {
          print('❌ Impossible d\'ouvrir le store');
          return false;
        }
      } else {
        print('❌ URL non valide: $updateUrl');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ouverture du store: $e');
      return false;
    }
  }
}
