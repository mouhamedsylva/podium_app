# Implémentation Flutter - Vérification de Version de l'Application

## 📋 Analyse du Backend Actuel (SNAL-Project)

### Endpoint Backend
**Fichier :** `SNAL-Project/server/api/get-app-mobile-infos-versions.get.ts`

**Méthode :** `GET`  
**URL :** `/api/get-app-mobile-infos-versions`  
**Paramètres :** Aucun (actuellement)  
**Stored Procedure :** `proc_App_Version_GetInfos` (sans paramètres)

### Réponse Backend Actuelle

```typescript
{
  success: boolean,
  data: parsedData,  // JSON parsé depuis la stored procedure
  message?: string,  // En cas d'erreur
  error?: string     // En cas d'erreur
}
```

### Structure des données attendue depuis `proc_App_Version_GetInfos`

La stored procedure retourne un JSON qui est parsé. La structure exacte dépend de la procédure stockée, mais elle devrait contenir des informations de version telles que :

**Exemple de structure possible :**
```json
{
  "sLatestVersion": "1.1.0",
  "sMinimumVersion": "1.0.0",
  "bForceUpdate": false,
  "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
  "sReleaseNotes": "Nouvelle version avec corrections de bugs",
  "sPlatform": "android"  // ou "ios", "web"
}
```

**OU un tableau par plateforme :**
```json
[
  {
    "sPlatform": "android",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
    "sReleaseNotes": "Nouvelle version Android"
  },
  {
    "sPlatform": "ios",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://apps.apple.com/app/podium/id123456789",
    "sReleaseNotes": "Nouvelle version iOS"
  }
]
```

## 🔍 État Actuel de l'Implémentation Flutter

### ❌ Non Implémenté

Actuellement, **aucune implémentation Flutter** n'existe pour :
- Vérifier la version de l'application
- Comparer avec la version du serveur
- Afficher un dialogue de mise à jour obligatoire
- Rediriger vers les stores (Google Play / App Store)

### ✅ Éléments Disponibles

1. **Version de l'application** : Définie dans `pubspec.yaml` (ligne 19)
   ```yaml
   version: 1.0.0+1
   ```

2. **Service API** : `ApiService` existe dans `lib/services/api_service.dart`
   - Gère les appels HTTP avec Dio
   - Gestion des cookies automatique
   - Configuration baseUrl selon la plateforme

3. **Packages disponibles** : 
   - `package_info_plus` : **À AJOUTER** pour récupérer la version de l'app
   - `url_launcher` : Déjà disponible pour ouvrir les stores
   - `in_app_update` : **À AJOUTER** pour les mises à jour OTA sur Android

## 📱 Implémentation Flutter Recommandée

### 1. Ajouter les Dépendances Nécessaires

Dans `pubspec.yaml`, ajouter :

```yaml
dependencies:
  # ... dépendances existantes ...
  
  # Version checking
  package_info_plus: ^8.0.0  # Pour récupérer la version de l'app
  
  # In-app updates (Android uniquement)
  in_app_update: ^5.0.0  # Pour les mises à jour OTA sur Android
  
  # Version comparison
  version: ^3.0.0  # Pour comparer les versions (X.Y.Z)
```

Puis exécuter :
```bash
flutter pub get
```

### 2. Créer un Modèle de Données

**Fichier :** `lib/models/app_version_info.dart`

```dart
/// Modèle pour les informations de version de l'application
class AppVersionInfo {
  final String latestVersion;
  final String minimumVersion;
  final bool forceUpdate;
  final String? updateUrl;
  final String? releaseNotes;
  final String platform;

  AppVersionInfo({
    required this.latestVersion,
    required this.minimumVersion,
    required this.forceUpdate,
    this.updateUrl,
    this.releaseNotes,
    required this.platform,
  });

  /// Créer depuis la réponse API
  factory AppVersionInfo.fromJson(Map<String, dynamic> json, String platform) {
    return AppVersionInfo(
      latestVersion: json['sLatestVersion']?.toString() ?? 
                     json['latestVersion']?.toString() ?? 
                     json['version']?.toString() ?? 
                     '1.0.0',
      minimumVersion: json['sMinimumVersion']?.toString() ?? 
                      json['minimumVersion']?.toString() ?? 
                      json['minVersion']?.toString() ?? 
                      '1.0.0',
      forceUpdate: json['bForceUpdate'] ?? 
                   json['forceUpdate'] ?? 
                   false,
      updateUrl: json['sUpdateUrl']?.toString() ?? 
                 json['updateUrl']?.toString() ?? 
                 json['url']?.toString(),
      releaseNotes: json['sReleaseNotes']?.toString() ?? 
                    json['releaseNotes']?.toString() ?? 
                    json['notes']?.toString(),
      platform: platform.toLowerCase(),
    );
  }

  /// Créer depuis un tableau (structure par plateforme)
  factory AppVersionInfo.fromArray(List<dynamic> jsonArray, String platform) {
    final platformLower = platform.toLowerCase();
    
    // Chercher l'entrée correspondant à la plateforme
    final platformEntry = jsonArray.firstWhere(
      (item) => (item['sPlatform']?.toString().toLowerCase() ?? '') == platformLower ||
                (item['platform']?.toString().toLowerCase() ?? '') == platformLower,
      orElse: () => jsonArray.isNotEmpty ? jsonArray[0] : {},
    );
    
    return AppVersionInfo.fromJson(
      platformEntry is Map ? Map<String, dynamic>.from(platformEntry) : {},
      platform,
    );
  }

  /// Vérifier si une mise à jour est disponible
  bool isUpdateAvailable(String currentVersion) {
    return _compareVersions(currentVersion, latestVersion) < 0;
  }

  /// Vérifier si une mise à jour est requise (version minimale)
  bool isUpdateRequired(String currentVersion) {
    return _compareVersions(currentVersion, minimumVersion) < 0;
  }

  /// Comparer deux versions (format: X.Y.Z)
  /// Retourne: -1 si v1 < v2, 0 si v1 == v2, 1 si v1 > v2
  int _compareVersions(String v1, String v2) {
    // Nettoyer les versions (enlever le build number si présent)
    final cleanV1 = v1.trim().split('+')[0];
    final cleanV2 = v2.trim().split('+')[0];

    // Séparer en parties numériques
    final parts1 = cleanV1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = cleanV2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    // Remplir avec des zéros pour avoir la même longueur
    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    while (parts1.length < maxLength) parts1.add(0);
    while (parts2.length < maxLength) parts2.add(0);

    // Comparer partie par partie
    for (int i = 0; i < maxLength; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0;
  }
}
```

### 3. Ajouter la Méthode dans ApiService

**Fichier :** `lib/services/api_service.dart`

Ajouter cette méthode dans la classe `ApiService` :

```dart
  /// Récupérer les informations de version de l'application mobile
  /// 
  /// Retourne les informations de version depuis le backend:
  /// - latestVersion: Dernière version disponible
  /// - minimumVersion: Version minimale requise
  /// - forceUpdate: Si une mise à jour est obligatoire
  /// - updateUrl: URL du store (Google Play / App Store)
  /// - releaseNotes: Notes de version
  Future<Map<String, dynamic>?> getAppMobileInfosVersions() async {
    try {
      print('📱 Vérification de la version de l\'application...');
      print('🌐 URL complète: ${_dio!.options.baseUrl}/get-app-mobile-infos-versions');
      
      final response = await _dio!.get('/get-app-mobile-infos-versions');
      
      print('📡 Status Code: ${response.statusCode}');
      print('📡 Données brutes: ${response.data}');
      
      if (response.statusCode == 200) {
        print('✅ Informations de version récupérées avec succès');
        print('✅ Données retournées: ${response.data}');
        return response.data;
      } else {
        print('❌ Status code non-200: ${response.statusCode}');
        print('❌ Données d\'erreur: ${response.data}');
        throw Exception('Erreur lors de la récupération des informations de version: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur getAppMobileInfosVersions: $e');
      print('❌ Type d\'erreur: ${e.runtimeType}');
      if (e is DioException) {
        print('❌ DioException - Type: ${e.type}');
        print('❌ DioException - Message: ${e.message}');
        print('❌ DioException - Response: ${e.response?.data}');
        print('❌ DioException - Status Code: ${e.response?.statusCode}');
      }
      return null;
    }
  }
```

### 4. Créer un Service de Gestion des Versions

**Fichier :** `lib/services/app_version_service.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart' if (dart.library.html) 'package:in_app_update/in_app_update_web.dart';
import '../models/app_version_info.dart';
import 'api_service.dart';

/// Service pour gérer la vérification et la mise à jour de version
class AppVersionService {
  static final AppVersionService _instance = AppVersionService._internal();
  factory AppVersionService() => _instance;
  AppVersionService._internal();

  final ApiService _apiService = ApiService();

  /// Récupérer la version actuelle de l'application
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // Retourne la version sans le build number (ex: "1.0.0" au lieu de "1.0.0+1")
      return packageInfo.version;
    } catch (e) {
      print('❌ Erreur lors de la récupération de la version: $e');
      return '1.0.0'; // Version par défaut en cas d'erreur
    }
  }

  /// Récupérer le build number actuel
  Future<String> getCurrentBuildNumber() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e) {
      print('❌ Erreur lors de la récupération du build number: $e');
      return '1';
    }
  }

  /// Détecter la plateforme actuelle
  String getPlatform() {
    if (kIsWeb) {
      return 'web';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    } else {
      return 'unknown';
    }
  }

  /// Vérifier les informations de version depuis le serveur
  Future<AppVersionInfo?> checkVersion() async {
    try {
      print('🔍 Vérification de la version depuis le serveur...');
      
      // Récupérer la version actuelle
      final currentVersion = await getCurrentVersion();
      final platform = getPlatform();
      
      print('📱 Version actuelle: $currentVersion');
      print('📱 Plateforme: $platform');
      
      // Appeler l'API backend
      final response = await _apiService.getAppMobileInfosVersions();
      
      if (response == null || response['success'] != true) {
        print('❌ Réponse API invalide: $response');
        return null;
      }

      final data = response['data'];
      if (data == null) {
        print('❌ Aucune donnée dans la réponse API');
        return null;
      }

      // Parser les données selon la structure retournée
      AppVersionInfo? versionInfo;

      if (data is List) {
        // Cas 1: Tableau d'objets par plateforme
        versionInfo = AppVersionInfo.fromArray(data, platform);
      } else if (data is Map) {
        // Cas 2: Objet unique ou objet avec clés par plateforme
        if (data.containsKey(platform.toLowerCase())) {
          // Objet avec clés par plateforme
          final platformData = data[platform.toLowerCase()] as Map<String, dynamic>;
          versionInfo = AppVersionInfo.fromJson(platformData, platform);
        } else {
          // Objet unique (une seule version pour toutes les plateformes)
          versionInfo = AppVersionInfo.fromJson(data, platform);
        }
      }

      if (versionInfo == null) {
        print('❌ Impossible de parser les données de version');
        return null;
      }

      print('✅ Informations de version parsées:');
      print('   - Latest Version: ${versionInfo.latestVersion}');
      print('   - Minimum Version: ${versionInfo.minimumVersion}');
      print('   - Force Update: ${versionInfo.forceUpdate}');
      print('   - Update URL: ${versionInfo.updateUrl}');
      print('   - Update Available: ${versionInfo.isUpdateAvailable(currentVersion)}');
      print('   - Update Required: ${versionInfo.isUpdateRequired(currentVersion)}');

      return versionInfo;
    } catch (e) {
      print('❌ Erreur lors de la vérification de version: $e');
      return null;
    }
  }

  /// Ouvrir le store (Google Play / App Store)
  Future<void> openStore(String? updateUrl) async {
    try {
      if (updateUrl == null || updateUrl.isEmpty) {
        // URL par défaut selon la plateforme
        final platform = getPlatform();
        if (platform == 'android') {
          updateUrl = 'https://play.google.com/store/apps/details?id=com.jirig.podium';
        } else if (platform == 'ios') {
          updateUrl = 'https://apps.apple.com/app/podium/id123456789'; // ⚠️ À remplacer par l'ID réel
        } else {
          print('⚠️ Plateforme non supportée pour l\'ouverture du store: $platform');
          return;
        }
      }

      final uri = Uri.parse(updateUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Store ouvert: $updateUrl');
      } else {
        print('❌ Impossible d\'ouvrir le store: $updateUrl');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ouverture du store: $e');
    }
  }

  /// Vérifier et gérer les mises à jour OTA (Android uniquement)
  /// Nécessite le package `in_app_update`
  Future<void> checkInAppUpdate() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        print('⚠️ In-app update disponible uniquement sur Android');
        return;
      }

      // Implémentation avec in_app_update
      // Note: Ceci nécessite le package in_app_update
      // final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      // 
      // if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      //   if (updateInfo.immediateUpdateAllowed) {
      //     await InAppUpdate.performImmediateUpdate();
      //   } else if (updateInfo.flexibleUpdateAllowed) {
      //     await InAppUpdate.startFlexibleUpdate();
      //   }
      // }
      
      print('⚠️ In-app update non implémenté (nécessite le package in_app_update)');
    } catch (e) {
      print('❌ Erreur lors de la vérification In-app update: $e');
    }
  }
}
```

### 5. Créer un Widget de Dialogue de Mise à Jour

**Fichier :** `lib/widgets/app_update_dialog.dart`

```dart
import 'package:flutter/material.dart';
import '../models/app_version_info.dart';
import '../services/app_version_service.dart';

/// Dialogue pour afficher les informations de mise à jour
class AppUpdateDialog extends StatelessWidget {
  final AppVersionInfo versionInfo;
  final bool isRequired;
  final String currentVersion;

  const AppUpdateDialog({
    Key? key,
    required this.versionInfo,
    required this.isRequired,
    required this.currentVersion,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appVersionService = AppVersionService();

    return WillPopScope(
      onWillPop: () async => !isRequired, // Empêcher la fermeture si mise à jour requise
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              isRequired ? Icons.warning : Icons.info_outline,
              color: isRequired ? Colors.red : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isRequired ? 'Mise à jour obligatoire' : 'Mise à jour disponible',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.b600,
                  color: isRequired ? Colors.red : Colors.blue,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version actuelle: $currentVersion',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Dernière version: ${versionInfo.latestVersion}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (versionInfo.releaseNotes != null && versionInfo.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes de version:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    versionInfo.releaseNotes!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!isRequired)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              appVersionService.openStore(versionInfo.updateUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isRequired ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }

  /// Afficher le dialogue de mise à jour
  static Future<void> show(
    BuildContext context,
    AppVersionInfo versionInfo,
    String currentVersion,
  ) async {
    final isRequired = versionInfo.isUpdateRequired(currentVersion) || 
                       versionInfo.forceUpdate;

    return showDialog<void>(
      context: context,
      barrierDismissible: !isRequired, // Empêcher la fermeture si mise à jour requise
      builder: (BuildContext context) {
        return AppUpdateDialog(
          versionInfo: versionInfo,
          isRequired: isRequired,
          currentVersion: currentVersion,
        );
      },
    );
  }
}
```

### 6. Intégrer dans l'Application (ex: Splash Screen)

**Fichier :** `lib/screens/splash_screen.dart` (ou équivalent)

Ajouter cette logique dans `initState` ou dans une méthode d'initialisation :

```dart
import '../services/app_version_service.dart';
import '../widgets/app_update_dialog.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  // ... votre code existant ...
}

class _SplashScreenState extends State<SplashScreen> {
  final AppVersionService _appVersionService = AppVersionService();

  @override
  void initState() {
    super.initState();
    _checkVersionAndNavigate();
  }

  Future<void> _checkVersionAndNavigate() async {
    try {
      // Attendre un délai minimal pour l'animation du splash
      await Future.delayed(const Duration(seconds: 2));

      // Vérifier la version (en arrière-plan, ne bloque pas l'application)
      _checkVersionInBackground();

      // Naviguer vers la page principale
      if (mounted) {
        context.go('/home'); // ou votre route principale
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
      if (mounted) {
        context.go('/home');
      }
    }
  }

  /// Vérifier la version en arrière-plan et afficher le dialogue si nécessaire
  Future<void> _checkVersionInBackground() async {
    try {
      final versionInfo = await _appVersionService.checkVersion();
      
      if (versionInfo == null || !mounted) {
        return;
      }

      final currentVersion = await _appVersionService.getCurrentVersion();
      
      // Vérifier si une mise à jour est disponible ou requise
      final isUpdateAvailable = versionInfo.isUpdateAvailable(currentVersion);
      final isUpdateRequired = versionInfo.isUpdateRequired(currentVersion) || 
                               versionInfo.forceUpdate;

      if (isUpdateAvailable || isUpdateRequired) {
        // Attendre que le splash soit terminé avant d'afficher le dialogue
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          await AppUpdateDialog.show(
            context,
            versionInfo,
            currentVersion,
          );
        }
      } else {
        print('✅ Application à jour (version: $currentVersion)');
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification de version: $e');
      // Ne pas bloquer l'application en cas d'erreur
    }
  }

  // ... reste de votre code ...
}
```

### 7. Alternative: Vérification au Démarrage de l'App

**Fichier :** `lib/app.dart`

Modifier la méthode `_initializeApp()` pour vérifier la version au démarrage :

```dart
import '../services/app_version_service.dart';
import '../widgets/app_update_dialog.dart';

Future<void> _initializeApp() async {
  try {
    print('🚀 Initialisation de l\'application...');
    
    // ... votre code existant ...
    
    // Vérifier la version en arrière-plan (ne bloque pas le démarrage)
    _checkAppVersion();
    
    // ... reste de votre code ...
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
  }
}

Future<void> _checkAppVersion() async {
  try {
    final appVersionService = AppVersionService();
    final versionInfo = await appVersionService.checkVersion();
    
    if (versionInfo == null) {
      return;
    }

    final currentVersion = await appVersionService.getCurrentVersion();
    final isUpdateRequired = versionInfo.isUpdateRequired(currentVersion) || 
                             versionInfo.forceUpdate;

    // Si mise à jour requise, afficher le dialogue immédiatement
    if (isUpdateRequired && mounted) {
      // Attendre que le contexte soit disponible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          AppUpdateDialog.show(
            context,
            versionInfo,
            currentVersion,
          );
        }
      });
    }
  } catch (e) {
    print('❌ Erreur lors de la vérification de version: $e');
    // Ne pas bloquer l'application
  }
}
```

## 🔧 Configuration Backend Recommandée

### Amélioration de l'Endpoint Backend (Optionnel)

Pour rendre l'endpoint plus robuste, vous pourriez modifier le backend pour accepter des paramètres optionnels :

```typescript
// SNAL-Project/server/api/get-app-mobile-infos-versions.get.ts

export default defineEventHandler(async (event) => {
  const query = getQuery(event);
  const clientVersion = query.version as string; // Optionnel
  const platform = query.platform as string; // Optionnel

  // ... reste du code existant ...
  
  // Si la stored procedure accepte un paramètre platform, l'utiliser
  // const result = await pool
  //   .request()
  //   .input("sPlatform", sql.VarChar(10), platform?.toLowerCase() || 'all')
  //   .execute("proc_App_Version_GetInfos");
  
  // Sinon, utiliser la version sans paramètre (comme actuellement)
  const result = await pool.request().execute("proc_App_Version_GetInfos");
  
  // ... reste du code ...
});
```

### Exemple d'Appel avec Paramètres (Optionnel)

Si vous modifiez le backend pour accepter des paramètres, l'appel Flutter serait :

```dart
Future<Map<String, dynamic>?> getAppMobileInfosVersions({
  String? currentVersion,
  String? platform,
}) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVer = currentVersion ?? packageInfo.version;
    final platformName = platform ?? _getPlatform();
    
    final queryParams = <String, dynamic>{};
    if (currentVer.isNotEmpty) {
      queryParams['version'] = currentVer;
    }
    if (platformName.isNotEmpty) {
      queryParams['platform'] = platformName;
    }
    
    final response = await _dio!.get(
      '/get-app-mobile-infos-versions',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    // ... reste du code ...
  } catch (e) {
    // ... gestion d'erreur ...
  }
}
```

## 📝 Structure de Données de la Stored Procedure

Pour que l'implémentation fonctionne correctement, la stored procedure `proc_App_Version_GetInfos` devrait retourner un JSON avec cette structure :

### Structure Recommandée (Format Array)

```sql
-- Exemple de ce que la stored procedure devrait retourner
-- Format JSON avec un tableau d'objets par plateforme

[
  {
    "sPlatform": "android",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
    "sReleaseNotes": "Corrections de bugs et améliorations de performance"
  },
  {
    "sPlatform": "ios",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://apps.apple.com/app/podium/id123456789",
    "sReleaseNotes": "Corrections de bugs et améliorations de performance"
  },
  {
    "sPlatform": "web",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": null,
    "sReleaseNotes": "Corrections de bugs et améliorations de performance"
  }
]
```

### Structure Alternative (Format Object Unique)

```sql
-- Format JSON avec un objet unique (même version pour toutes les plateformes)

{
  "sLatestVersion": "1.1.0",
  "sMinimumVersion": "1.0.0",
  "bForceUpdate": false,
  "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
  "sReleaseNotes": "Corrections de bugs et améliorations de performance"
}
```

## 🎯 Workflow de Vérification Recommandé

1. **Au démarrage de l'application** (Splash Screen ou App initialisation)
   - Vérifier la version en arrière-plan (ne bloque pas le démarrage)
   - Si mise à jour requise (`isUpdateRequired` ou `forceUpdate`), afficher le dialogue immédiatement
   - Si mise à jour disponible mais non requise, afficher une notification discrète

2. **Vérification périodique** (Optionnel)
   - Vérifier la version toutes les 24h ou à chaque démarrage de l'app
   - Sauvegarder la dernière vérification dans `SharedPreferences` pour éviter trop d'appels API

3. **Gestion des erreurs**
   - Si l'API échoue, ne pas bloquer l'application
   - Logger l'erreur pour le debugging
   - Continuer le fonctionnement normal de l'app

## ⚠️ Points d'Attention

1. **Platform Detection** : 
   - Sur Flutter Web, `defaultTargetPlatform` peut ne pas être fiable
   - Utiliser `kIsWeb` pour détecter le web

2. **URL des Stores** :
   - Google Play : Nécessite le package ID exact (`com.jirig.podium`)
   - App Store : Nécessite l'ID de l'application (ex: `id123456789`)
   - Vérifier que ces URLs sont correctes dans votre backend

3. **Force Update** :
   - Si `bForceUpdate: true` ET que la version est inférieure à `minimumVersion`, l'utilisateur ne peut pas continuer
   - Le dialogue doit être non-fermable (`barrierDismissible: false`)

4. **Comparaison de Versions** :
   - Format attendu : `X.Y.Z` (ex: `1.0.0`, `1.2.3`)
   - Le build number est ignoré (ex: `1.0.0+1` => `1.0.0`)

5. **In-App Update (Android)** :
   - Nécessite le package `in_app_update`
   - Fonctionne uniquement sur Android
   - Nécessite que l'app soit publiée sur Google Play (ne fonctionne pas en développement local)

## ✅ Checklist d'Implémentation

- [ ] Ajouter les dépendances dans `pubspec.yaml`
  - [ ] `package_info_plus: ^8.0.0`
  - [ ] `in_app_update: ^5.0.0` (optionnel, Android uniquement)
  - [ ] `version: ^3.0.0` (optionnel, pour comparaison avancée)

- [ ] Créer le modèle `AppVersionInfo` (`lib/models/app_version_info.dart`)

- [ ] Ajouter la méthode `getAppMobileInfosVersions()` dans `ApiService`

- [ ] Créer le service `AppVersionService` (`lib/services/app_version_service.dart`)

- [ ] Créer le widget `AppUpdateDialog` (`lib/widgets/app_update_dialog.dart`)

- [ ] Intégrer la vérification dans le Splash Screen ou `app.dart`

- [ ] Tester sur différentes plateformes (Android, iOS, Web)

- [ ] Configurer les URLs des stores dans le backend

- [ ] Vérifier la structure JSON retournée par `proc_App_Version_GetInfos`

## 🔗 Ressources Utiles

- [package_info_plus Documentation](https://pub.dev/packages/package_info_plus)
- [in_app_update Documentation](https://pub.dev/packages/in_app_update)
- [url_launcher Documentation](https://pub.dev/packages/url_launcher)
- [Flutter Platform Detection](https://docs.flutter.dev/platform-integration/platform-adaptations)

## 📌 Notes Finales

Cette implémentation est basée sur le backend actuel qui appelle simplement `proc_App_Version_GetInfos` sans paramètres. Si vous souhaitez améliorer le backend pour accepter des paramètres (version actuelle, plateforme), vous pouvez adapter le code Flutter en conséquence.

L'implémentation Flutter est conçue pour être **robuste** et **non-bloquante** : en cas d'erreur API, l'application continue de fonctionner normalement, mais une mise à jour requise bloquera l'utilisation jusqu'à ce que l'utilisateur mette à jour.
