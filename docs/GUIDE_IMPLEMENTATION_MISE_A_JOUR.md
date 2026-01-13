# Guide d'Implémentation - Mise à Jour de l'Application Flutter

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Structure de la réponse backend](#structure-de-la-réponse-backend)
3. [Dépendances nécessaires](#dépendances-nécessaires)
4. [Modèle de données](#modèle-de-données)
5. [Implémentation dans ApiService](#implémentation-dans-apiservice)
6. [Service de gestion des mises à jour](#service-de-gestion-des-mises-à-jour)
7. [Widget de dialogue de mise à jour](#widget-de-dialogue-de-mise-à-jour)
8. [Intégration dans l'application](#intégration-dans-lapplication)
9. [Exemple d'utilisation complète](#exemple-dutilisation-complète)
10. [Tests et vérifications](#tests-et-vérifications)

---

## Vue d'ensemble

Ce guide explique comment implémenter la vérification et la gestion des mises à jour de l'application Flutter en se basant sur l'endpoint backend `/api/get-app-mobile-infos-versions`.

### Flux de fonctionnement

1. **L'application démarre** (SplashScreen)
2. **Récupération de la version actuelle** via `package_info_plus`
3. **Appel à l'API backend** avec `version` et `platform` en paramètres
4. **Analyse de la réponse** pour déterminer si une mise à jour est nécessaire
5. **Affichage d'un dialogue** si mise à jour requise/optionnelle
6. **Redirection vers le store** (Play Store / App Store) si l'utilisateur accepte

### Points importants

- ✅ **Le backend calcule déjà les comparaisons** (`updateAvailable`, `updateRequired`)
- ✅ **Pas besoin de comparer les versions côté Flutter** (le backend s'en charge)
- ✅ **L'URL de mise à jour est directement fournie** par le backend
- ✅ **Support Android et iOS** via le paramètre `platform`

---

## Structure de la réponse backend

### Endpoint

**URL :** `/api/get-app-mobile-infos-versions`  
**Méthode :** `GET`  
**Paramètres Query :**
- `version` : Version actuelle de l'application (ex: `"1.5.0"`)
- `platform` : Plateforme (`"android"` ou `"ios"`)

### Exemple de requête

```
GET /api/get-app-mobile-infos-versions?version=1.5.0&platform=android
```

### Structure de la réponse (Succès)

```json
{
  "success": true,
  "data": {
    "minVersion": "1.0.0",
    "latestVersion": "1.0.0",
    "currentVersion": "1.5.0",
    "updateAvailable": false,
    "updateRequired": false,
    "updateUrl": "https://play.google.com/store/apps/details?id=be.jirig.app&hl=fr",
    "forceUpdate": false,
    "title": "Mise à jour requise",
    "message": "Veuillez mettre à jour l'application pour continuer.",
    "releaseNotes": "Veuillez mettre à jour l'application pour continuer.",
    "active": true,
    "CreatedAt": "2026-01-13T00:01:53.810"
  }
}
```

### Structure de la réponse (Erreur)

```json
{
  "success": false,
  "message": "No data returned from the stored procedure.",
  "error": "Erreur détaillée (optionnel)"
}
```

### Description des champs

| Champ | Type | Description |
|-------|------|-------------|
| `minVersion` | `string` | Version minimale requise pour utiliser l'application |
| `latestVersion` | `string` | Dernière version disponible |
| `currentVersion` | `string` | Version actuelle envoyée en paramètre (confirmation) |
| `updateAvailable` | `boolean` | **Calculé par le backend** : `true` si `currentVersion < latestVersion` |
| `updateRequired` | `boolean` | **Calculé par le backend** : `true` si `currentVersion < minVersion` |
| `updateUrl` | `string` | URL vers le Play Store (Android) ou App Store (iOS) |
| `forceUpdate` | `boolean` | Indique si la mise à jour est obligatoire (peut être combiné avec `updateRequired`) |
| `title` | `string` | Titre à afficher dans le dialogue de mise à jour |
| `message` | `string` | Message principal à afficher |
| `releaseNotes` | `string` | Notes de version (peut être identique au message) |
| `active` | `boolean` | Indique si la configuration de version est active |
| `CreatedAt` | `string` | Date de création de la configuration (pour debug) |

### Cas d'usage

1. **Mise à jour obligatoire** (`updateRequired: true`)
   - L'application est trop ancienne
   - L'utilisateur ne peut pas continuer sans mettre à jour
   - Dialog non dismissible

2. **Mise à jour optionnelle** (`updateAvailable: true` mais `updateRequired: false`)
   - Une nouvelle version est disponible
   - L'utilisateur peut continuer sans mettre à jour
   - Dialog dismissible

3. **Pas de mise à jour** (`updateAvailable: false` et `updateRequired: false`)
   - L'application est à jour
   - Aucune action nécessaire

---

## Dépendances nécessaires

### Packages à ajouter

Ouvrez `pubspec.yaml` et ajoutez la dépendance suivante :

```yaml
dependencies:
  # ... dépendances existantes ...
  
  # Version checking
  package_info_plus: ^8.0.0  # Pour récupérer la version de l'application
```

**Note :** `url_launcher` est déjà présent dans votre `pubspec.yaml` (ligne 74), donc pas besoin de l'ajouter.

### Installation

```bash
cd podium_app
flutter pub get
```

### Vérification

Assurez-vous que `package_info_plus` est bien installé :

```bash
flutter pub deps | grep package_info_plus
```

---

## Modèle de données

Créer un modèle pour représenter la réponse de l'API.

### Fichier : `lib/models/app_version_info.dart`

```dart
/// Modèle représentant les informations de version de l'application
class AppVersionInfo {
  final String minVersion;
  final String latestVersion;
  final String currentVersion;
  final bool updateAvailable;
  final bool updateRequired;
  final String updateUrl;
  final bool forceUpdate;
  final String title;
  final String message;
  final String releaseNotes;
  final bool active;
  final String? createdAt;

  AppVersionInfo({
    required this.minVersion,
    required this.latestVersion,
    required this.currentVersion,
    required this.updateAvailable,
    required this.updateRequired,
    required this.updateUrl,
    required this.forceUpdate,
    required this.title,
    required this.message,
    required this.releaseNotes,
    required this.active,
    this.createdAt,
  });

  /// Créer une instance depuis une Map (réponse JSON)
  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      minVersion: json['minVersion']?.toString() ?? '1.0.0',
      latestVersion: json['latestVersion']?.toString() ?? '1.0.0',
      currentVersion: json['currentVersion']?.toString() ?? '1.0.0',
      updateAvailable: json['updateAvailable'] == true,
      updateRequired: json['updateRequired'] == true,
      updateUrl: json['updateUrl']?.toString() ?? '',
      forceUpdate: json['forceUpdate'] == true,
      title: json['title']?.toString() ?? 'Mise à jour disponible',
      message: json['message']?.toString() ?? 'Une nouvelle version est disponible.',
      releaseNotes: json['releaseNotes']?.toString() ?? json['message']?.toString() ?? '',
      active: json['active'] == true,
      createdAt: json['CreatedAt']?.toString(),
    );
  }

  /// Convertir en Map (pour debug)
  Map<String, dynamic> toJson() {
    return {
      'minVersion': minVersion,
      'latestVersion': latestVersion,
      'currentVersion': currentVersion,
      'updateAvailable': updateAvailable,
      'updateRequired': updateRequired,
      'updateUrl': updateUrl,
      'forceUpdate': forceUpdate,
      'title': title,
      'message': message,
      'releaseNotes': releaseNotes,
      'active': active,
      'CreatedAt': createdAt,
    };
  }

  /// Vérifier si une mise à jour est nécessaire (mise à jour obligatoire)
  bool get needsUpdate => updateRequired || (forceUpdate && updateAvailable);

  /// Vérifier si une mise à jour est disponible (mise à jour optionnelle)
  bool get hasUpdate => updateAvailable && !updateRequired;
}
```

**Explications :**

- **`fromJson`** : Constructeur factory pour créer une instance depuis la réponse JSON du backend
- **`toJson`** : Méthode pour convertir en Map (utile pour le debug)
- **`needsUpdate`** : Getter pour vérifier si une mise à jour est **obligatoire**
- **`hasUpdate`** : Getter pour vérifier si une mise à jour est **optionnelle**
- **Gestion des valeurs par défaut** : Toutes les valeurs ont des fallbacks pour éviter les erreurs

---

## Implémentation dans ApiService

Ajouter la méthode pour appeler l'endpoint backend.

### Fichier : `lib/services/api_service.dart`

Ajouter la méthode suivante dans la classe `ApiService` :

```dart
  /// Récupérer les informations de version de l'application
  /// 
  /// [version] : Version actuelle de l'application (ex: "1.5.0")
  /// [platform] : Plateforme ("android" ou "ios")
  /// 
  /// Retourne [AppVersionInfo] si succès, `null` en cas d'erreur
  Future<AppVersionInfo?> getAppVersionInfo({
    required String version,
    required String platform,
  }) async {
    try {
      // S'assurer que l'API est initialisée
      if (_dio == null) {
        await initialize();
      }

      print('🔍 Vérification de version:');
      print('   Version actuelle: $version');
      print('   Plateforme: $platform');

      // Appel à l'API
      final response = await _dio!.get(
        '/get-app-mobile-infos-versions',
        queryParameters: {
          'version': version,
          'platform': platform.toLowerCase(),
        },
      );

      print('📡 Réponse API version: ${response.statusCode}');
      print('📡 Données: ${response.data}');

      // Vérifier le statut de la réponse
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Vérifier la structure de la réponse
        if (data is Map<String, dynamic>) {
          // Si la réponse contient 'success: false'
          if (data['success'] == false) {
            print('❌ Erreur backend: ${data['message']}');
            return null;
          }
          
          // Si la réponse contient 'success: true' avec 'data'
          if (data['success'] == true && data['data'] != null) {
            final versionData = data['data'] as Map<String, dynamic>;
            final versionInfo = AppVersionInfo.fromJson(versionData);
            print('✅ Informations de version récupérées:');
            print('   Update Available: ${versionInfo.updateAvailable}');
            print('   Update Required: ${versionInfo.updateRequired}');
            print('   Force Update: ${versionInfo.forceUpdate}');
            return versionInfo;
          }
        }
      }

      print('❌ Réponse invalide: ${response.data}');
      return null;
    } catch (e) {
      print('❌ Erreur lors de la vérification de version: $e');
      if (e is DioException) {
        print('   Type: ${e.type}');
        print('   Message: ${e.message}');
        print('   Response: ${e.response?.data}');
      }
      return null;
    }
  }
```

**N'oubliez pas d'ajouter l'import en haut du fichier :**

```dart
import '../models/app_version_info.dart';
```

**Explications :**

- **Paramètres** : `version` et `platform` sont requis et envoyés en query parameters
- **Gestion d'erreurs** : Retourne `null` en cas d'erreur (pas d'exception)
- **Logs détaillés** : Pour faciliter le debug
- **Structure de réponse** : Gère les deux formats possibles (`success: true/false`)

---

## Service de gestion des mises à jour

Créer un service pour orchestrer la vérification et l'affichage des mises à jour.

### Fichier : `lib/services/app_update_service.dart`

```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import '../services/api_service.dart';
import '../models/app_version_info.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service pour gérer les mises à jour de l'application
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final ApiService _apiService = ApiService();

  /// Vérifier si une mise à jour est disponible
  /// 
  /// Retourne [AppVersionInfo] si une mise à jour est nécessaire/disponible,
  /// `null` sinon ou en cas d'erreur
  Future<AppVersionInfo?> checkForUpdate() async {
    try {
      print('🔍 Vérification des mises à jour...');

      // Récupérer la version actuelle de l'application
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // ex: "1.5.0"
      final buildNumber = packageInfo.buildNumber; // ex: "1"

      print('📱 Version actuelle: $currentVersion (build: $buildNumber)');

      // Déterminer la plateforme
      String platform;
      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else {
        print('⚠️ Plateforme non supportée: ${Platform.operatingSystem}');
        return null; // Web ou autres plateformes non supportées
      }

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
```

**Explications :**

- **Singleton** : Utilise le pattern singleton (comme `ApiService`)
- **`checkForUpdate()`** : 
  - Récupère la version via `package_info_plus`
  - Détermine la plateforme (Android/iOS)
  - Appelle l'API backend
  - Retourne `AppVersionInfo` seulement si une mise à jour est nécessaire/disponible
- **`openStore()`** : 
  - Utilise `url_launcher` pour ouvrir le store
  - Mode `externalApplication` pour ouvrir dans l'app store native
- **Gestion d'erreurs** : Retourne `null` ou `false` en cas d'erreur (pas d'exception)

---

## Widget de dialogue de mise à jour

Créer un widget pour afficher le dialogue de mise à jour.

### Fichier : `lib/widgets/app_update_dialog.dart`

```dart
import 'package:flutter/material.dart';
import '../models/app_version_info.dart';
import '../services/app_update_service.dart';

/// Dialogue pour afficher les informations de mise à jour
class AppUpdateDialog extends StatelessWidget {
  final AppVersionInfo versionInfo;
  final bool isDismissible;

  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    this.isDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final appUpdateService = AppUpdateService();
    final isRequired = versionInfo.needsUpdate; // Mise à jour obligatoire

    return WillPopScope(
      onWillPop: () async => !isRequired, // Empêcher la fermeture si obligatoire
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.system_update,
              color: Color(0xFF0066FF),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                versionInfo.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF21252F),
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
                versionInfo.message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF21252F),
                  height: 1.5,
                ),
              ),
              if (versionInfo.releaseNotes.isNotEmpty &&
                  versionInfo.releaseNotes != versionInfo.message) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes de version:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF21252F),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    versionInfo.releaseNotes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF21252F),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Version actuelle: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                  Text(
                    versionInfo.currentVersion,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF21252F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Nouvelle version: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                  Text(
                    versionInfo.latestVersion,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0066FF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Bouton "Plus tard" (seulement si mise à jour optionnelle)
          if (!isRequired)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Plus tard',
                style: TextStyle(
                  color: Color(0xFF666666),
                ),
              ),
            ),
          // Bouton "Mettre à jour"
          ElevatedButton(
            onPressed: () async {
              // Fermer le dialogue
              Navigator.of(context).pop();
              
              // Ouvrir le store
              await appUpdateService.openStore(versionInfo.updateUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Mettre à jour',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Afficher le dialogue de mise à jour
  static Future<void> show({
    required BuildContext context,
    required AppVersionInfo versionInfo,
  }) async {
    final isRequired = versionInfo.needsUpdate;
    
    await showDialog(
      context: context,
      barrierDismissible: !isRequired, // Empêcher la fermeture si obligatoire
      builder: (context) => AppUpdateDialog(
        versionInfo: versionInfo,
        isDismissible: !isRequired,
      ),
    );
  }
}
```

**Explications :**

- **Design cohérent** : Utilise les couleurs de l'application (`Color(0xFF0066FF)`)
- **`isDismissible`** : 
  - `true` si mise à jour optionnelle (peut être fermé)
  - `false` si mise à jour obligatoire (ne peut pas être fermé)
- **`WillPopScope`** : Empêche la fermeture avec le bouton retour si obligatoire
- **Affichage des notes de version** : Seulement si différentes du message
- **Bouton "Plus tard"** : Seulement si mise à jour optionnelle
- **Méthode `show()`** : Méthode statique pour faciliter l'affichage

---

## Intégration dans l'application

Intégrer la vérification de mise à jour dans le `SplashScreen`.

### Fichier : `lib/screens/splash_screen.dart`

#### 1. Ajouter les imports

```dart
import '../services/app_update_service.dart';
import '../models/app_version_info.dart';
import '../widgets/app_update_dialog.dart';
```

#### 2. Modifier la méthode `_initializeAndNavigate`

Remplacer la méthode existante par :

```dart
  Future<void> _initializeAndNavigate() async {
    if (_hasNavigated || !mounted) {
      return;
    }

    // Attendre que les traductions soient chargées
    print('🔄 SPLASH_SCREEN: Attente du chargement des traductions...');
    final translationService = Provider.of<TranslationService>(context, listen: false);
    await translationService.initializationComplete;
    print('✅ SPLASH_SCREEN: Traductions chargées.');

    if (!mounted) return;

    // ✅ NOUVEAU: Vérifier les mises à jour
    await _checkForAppUpdate();

    if (!mounted) return;

    _hasNavigated = true;

    try {
      final savedRoute = await RoutePersistenceService.getStartupRoute();
      final targetRoute = (savedRoute.isEmpty ||
              savedRoute == '/' ||
              savedRoute == '/splash')
          ? '/country-selection'
          : savedRoute;

      if (mounted) {
        // Arrêter les animations juste avant de naviguer
        _blueRingController.stop();
        _yellowRingController.stop();
        _progressController.stop();
        context.go(targetRoute);
      }
    } catch (e) {
      if (mounted) {
        // Arrêter les animations juste avant de naviguer
        _blueRingController.stop();
        _yellowRingController.stop();
        _progressController.stop();
        context.go('/country-selection');
      }
    }
  }

  /// Vérifier si une mise à jour est disponible
  Future<void> _checkForAppUpdate() async {
    try {
      print('🔍 SPLASH_SCREEN: Vérification des mises à jour...');
      
      final appUpdateService = AppUpdateService();
      final versionInfo = await appUpdateService.checkForUpdate();

      if (!mounted) return;

      // Si une mise à jour est disponible/requise, afficher le dialogue
      if (versionInfo != null) {
        print('📱 SPLASH_SCREEN: Mise à jour détectée, affichage du dialogue...');
        
        // Attendre un court délai pour que le SplashScreen soit complètement rendu
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Afficher le dialogue de mise à jour
        await AppUpdateDialog.show(
          context: context,
          versionInfo: versionInfo,
        );

        // Si la mise à jour est obligatoire, ne pas continuer
        // (l'utilisateur ne peut pas fermer le dialogue)
        if (versionInfo.needsUpdate) {
          print('⚠️ SPLASH_SCREEN: Mise à jour obligatoire, arrêt du flux');
          return;
        }
      } else {
        print('✅ SPLASH_SCREEN: Application à jour');
      }
    } catch (e) {
      print('❌ SPLASH_SCREEN: Erreur lors de la vérification de mise à jour: $e');
      // En cas d'erreur, continuer normalement (ne pas bloquer l'application)
    }
  }
```

**Explications :**

- **Ordre d'exécution** : 
  1. Chargement des traductions
  2. Vérification des mises à jour
  3. Navigation vers l'écran suivant
- **`_checkForAppUpdate()`** : 
  - Appelle `AppUpdateService.checkForUpdate()`
  - Affiche le dialogue si nécessaire
  - Si mise à jour obligatoire, ne continue pas (bloque l'app)
- **Gestion d'erreurs** : En cas d'erreur, continue normalement (ne bloque pas l'app)
- **Délai** : Petit délai avant d'afficher le dialogue pour s'assurer que le SplashScreen est rendu

---

## Exemple d'utilisation complète

### Exemple 1 : Mise à jour obligatoire

```dart
// Backend retourne:
// {
//   "updateRequired": true,
//   "forceUpdate": true,
//   "title": "Mise à jour requise",
//   "message": "Veuillez mettre à jour l'application pour continuer."
// }

// Le dialogue s'affiche automatiquement dans SplashScreen
// L'utilisateur ne peut pas le fermer
// Seul le bouton "Mettre à jour" est disponible
```

### Exemple 2 : Mise à jour optionnelle

```dart
// Backend retourne:
// {
//   "updateAvailable": true,
//   "updateRequired": false,
//   "title": "Nouvelle version disponible",
//   "message": "Une nouvelle version de l'application est disponible."
// }

// Le dialogue s'affiche automatiquement dans SplashScreen
// L'utilisateur peut le fermer avec "Plus tard" ou le bouton retour
// Le bouton "Mettre à jour" ouvre le store
```

### Exemple 3 : Application à jour

```dart
// Backend retourne:
// {
//   "updateAvailable": false,
//   "updateRequired": false
// }

// Aucun dialogue n'est affiché
// L'application continue normalement
```

---

## Tests et vérifications

### 1. Vérifier l'installation des dépendances

```bash
cd podium_app
flutter pub get
flutter pub deps | grep package_info_plus
```

### 2. Tester la récupération de la version

```dart
// Dans un fichier de test temporaire
import 'package:package_info_plus/package_info_plus.dart';

void testVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  print('Version: ${packageInfo.version}');
  print('Build: ${packageInfo.buildNumber}');
}
```

### 3. Tester l'appel API

```dart
// Dans un fichier de test temporaire
import '../services/api_service.dart';

void testApi() async {
  final apiService = ApiService();
  await apiService.initialize();
  
  final versionInfo = await apiService.getAppVersionInfo(
    version: '1.5.0',
    platform: 'android',
  );
  
  print('Version Info: ${versionInfo?.toJson()}');
}
```

### 4. Tester le service complet

```dart
// Dans un fichier de test temporaire
import '../services/app_update_service.dart';

void testService() async {
  final appUpdateService = AppUpdateService();
  final versionInfo = await appUpdateService.checkForUpdate();
  
  if (versionInfo != null) {
    print('Mise à jour disponible!');
    print('Update Required: ${versionInfo.updateRequired}');
    print('Update Available: ${versionInfo.updateAvailable}');
  } else {
    print('Application à jour');
  }
}
```

### 5. Tester l'ouverture du store

```dart
// Dans un fichier de test temporaire
import '../services/app_update_service.dart';

void testStore() async {
  final appUpdateService = AppUpdateService();
  final opened = await appUpdateService.openStore(
    'https://play.google.com/store/apps/details?id=be.jirig.app&hl=fr',
  );
  
  print('Store ouvert: $opened');
}
```

### Checklist de vérification

- [ ] `package_info_plus` est installé
- [ ] Le modèle `AppVersionInfo` est créé
- [ ] La méthode `getAppVersionInfo` est ajoutée dans `ApiService`
- [ ] Le service `AppUpdateService` est créé
- [ ] Le widget `AppUpdateDialog` est créé
- [ ] L'intégration dans `SplashScreen` est faite
- [ ] L'application compile sans erreur
- [ ] Le dialogue s'affiche correctement
- [ ] Le store s'ouvre correctement
- [ ] La mise à jour obligatoire bloque l'app
- [ ] La mise à jour optionnelle permet de continuer

---

## Résumé

Ce guide explique comment implémenter la vérification et la gestion des mises à jour de l'application Flutter en se basant sur l'endpoint backend `/api/get-app-mobile-infos-versions`.

### Points clés

1. ✅ **Le backend calcule les comparaisons** (`updateAvailable`, `updateRequired`)
2. ✅ **Pas besoin de comparer les versions côté Flutter**
3. ✅ **L'URL de mise à jour est directement fournie**
4. ✅ **Support Android et iOS**

### Fichiers créés/modifiés

1. **Nouveau** : `lib/models/app_version_info.dart`
2. **Nouveau** : `lib/services/app_update_service.dart`
3. **Nouveau** : `lib/widgets/app_update_dialog.dart`
4. **Modifié** : `lib/services/api_service.dart` (ajout de `getAppVersionInfo`)
5. **Modifié** : `lib/screens/splash_screen.dart` (ajout de `_checkForAppUpdate`)
6. **Modifié** : `pubspec.yaml` (ajout de `package_info_plus`)

### Prochaines étapes

1. Implémenter les fichiers selon ce guide
2. Tester sur Android et iOS
3. Vérifier les différents cas d'usage
4. Personnaliser le design du dialogue si nécessaire
