import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../models/app_version_info.dart';
import '../services/local_storage_service.dart';
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

      // ✅ Vérifier d'abord s'il y a une mise à jour forcée en attente
      final pendingUpdate = await LocalStorageService.getPendingForceUpdate();
      if (pendingUpdate != null) {
        final pendingMinVersion = pendingUpdate['minVersion']?.toString() ?? '';
        final pendingLatestVersion = pendingUpdate['latestVersion']?.toString() ?? '';
        
        print('🔍 Mise à jour forcée en attente détectée: min=$pendingMinVersion, latest=$pendingLatestVersion');
        
        // Comparer les versions (simple comparaison de strings pour l'instant)
        // Si la version actuelle est inférieure à la version minimale requise, la mise à jour est toujours nécessaire
        if (_compareVersions(currentVersion, pendingMinVersion) < 0) {
          print('⚠️ Version actuelle ($currentVersion) < version minimale requise ($pendingMinVersion)');
          // Créer un AppVersionInfo depuis les données sauvegardées
          final versionInfo = AppVersionInfo.fromJson(pendingUpdate);
          // Mettre à jour currentVersion avec la vraie version actuelle
          return AppVersionInfo(
            minVersion: versionInfo.minVersion,
            latestVersion: versionInfo.latestVersion,
            currentVersion: currentVersion, // Version actuelle réelle
            updateAvailable: true,
            updateRequired: true,
            updateUrl: versionInfo.updateUrl,
            forceUpdate: true,
            title: versionInfo.title,
            message: versionInfo.message,
            releaseNotes: versionInfo.releaseNotes,
            active: true,
          );
        } else {
          // La version actuelle est >= à la version minimale, on peut nettoyer
          print('✅ Version actuelle ($currentVersion) >= version minimale ($pendingMinVersion) - nettoyage');
          await LocalStorageService.clearPendingForceUpdate();
        }
      }

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

  /// Comparer deux versions (format: "1.2.3")
  /// Retourne -1 si version1 < version2, 0 si égales, 1 si version1 > version2
  int _compareVersions(String version1, String version2) {
    try {
      final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      // Normaliser les longueurs
      while (v1Parts.length < v2Parts.length) v1Parts.add(0);
      while (v2Parts.length < v1Parts.length) v2Parts.add(0);
      
      for (int i = 0; i < v1Parts.length; i++) {
        if (v1Parts[i] < v2Parts[i]) return -1;
        if (v1Parts[i] > v2Parts[i]) return 1;
      }
      return 0;
    } catch (e) {
      print('❌ Erreur comparaison versions: $e');
      return 0; // En cas d'erreur, considérer comme égales
    }
  }
}
