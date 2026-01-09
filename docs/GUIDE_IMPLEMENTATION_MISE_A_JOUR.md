# Guide d'implémentation - Mise à jour de l'application Podium

## 📋 Vue d'ensemble

Ce guide vous explique comment implémenter le système de mise à jour de l'application Podium côté frontend. Le système permet de :
- Vérifier automatiquement les nouvelles versions disponibles
- Notifier l'utilisateur des mises à jour (recommandées ou obligatoires)
- Rediriger vers les stores pour télécharger la mise à jour
- Recharger automatiquement la page pour les mises à jour web

---

## ✅ Prérequis

### 1. Vérifier les dépendances

Assurez-vous que les dépendances suivantes sont présentes dans `pubspec.yaml` :

```yaml
dependencies:
  # ... autres dépendances ...
  package_info_plus: ^8.0.0
  device_info_plus: ^11.1.0
  url_launcher: ^6.3.1
  shared_preferences: ^2.3.3
```

Si elles ne sont pas présentes, ajoutez-les et exécutez :
```bash
flutter pub get
```

### 2. Vérifier l'endpoint backend

L'endpoint backend `get-app-mobile-infos-versions.get.ts` doit être configuré et fonctionnel. Il doit :
- Accepter les paramètres `version` et `platform` en query
- Retourner une réponse au format :
```json
{
  "success": true,
  "updateAvailable": boolean,
  "updateRequired": boolean,
  "forceUpdate": boolean,
  "latestVersion": string,
  "minimumVersion": string,
  "currentVersion": string,
  "updateUrl": string,
  "releaseNotes": string,
  "platform": string
}
```

---

## 🚀 Étapes d'implémentation

### Étape 1 : Créer le service de version

**Fichier : `lib/services/version_service.dart`**

Créez ce fichier avec le code suivant :

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'api_service.dart';

/// Service pour gérer la vérification de version de l'application
class VersionService {
  final ApiService _apiService;
  
  VersionService(this._apiService);
  
  /// Récupérer la version actuelle de l'application
  /// Retourne uniquement la partie version (sans le build number)
  /// Exemple: "1.0.0+1" => "1.0.0"
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // Extraire uniquement la version (sans le build number)
      final versionParts = packageInfo.version.split('+');
      return versionParts[0];
    } catch (e) {
      print('❌ Erreur récupération version: $e');
      return '1.0.0'; // Version par défaut
    }
  }
  
  /// Détecter la plateforme (android, ios, web)
  Future<String> getPlatform() async {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    }
    return 'web';
  }
  
  /// Vérifier si une mise à jour est disponible
  Future<VersionCheckResult> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      final platform = await getPlatform();
      
      print('🔍 Vérification de mise à jour...');
      print('   Version actuelle: $currentVersion');
      print('   Plateforme: $platform');
      
      // Appel API pour vérifier la version
      final response = await _apiService.checkAppVersion(
        version: currentVersion,
        platform: platform,
      );
      
      if (response != null && response['success'] == true) {
        return VersionCheckResult.fromJson(response);
      }
      
      // En cas d'erreur, retourner un résultat sans mise à jour
      return VersionCheckResult(
        updateAvailable: false,
        updateRequired: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
      );
    } catch (e) {
      print('❌ Erreur vérification mise à jour: $e');
      final currentVersion = await getCurrentVersion();
      return VersionCheckResult(
        updateAvailable: false,
        updateRequired: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
      );
    }
  }
  
  /// Comparer deux versions (format: X.Y.Z)
  /// Retourne: -1 si v1 < v2, 0 si v1 == v2, 1 si v1 > v2
  int compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    final maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
    
    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;
      
      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }
    
    return 0;
  }
}

/// Modèle pour le résultat de la vérification de version
class VersionCheckResult {
  final bool updateAvailable;
  final bool updateRequired;
  final bool forceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? updateUrl;
  final String? releaseNotes;
  final String? platform;
  
  VersionCheckResult({
    required this.updateAvailable,
    required this.updateRequired,
    this.forceUpdate = false,
    required this.currentVersion,
    required this.latestVersion,
    this.updateUrl,
    this.releaseNotes,
    this.platform,
  });
  
  factory VersionCheckResult.fromJson(Map<String, dynamic> json) {
    return VersionCheckResult(
      updateAvailable: json['updateAvailable'] ?? false,
      updateRequired: json['updateRequired'] ?? false,
      forceUpdate: json['forceUpdate'] ?? false,
      currentVersion: json['currentVersion'] ?? '1.0.0',
      latestVersion: json['latestVersion'] ?? '1.0.0',
      updateUrl: json['updateUrl'],
      releaseNotes: json['releaseNotes'],
      platform: json['platform'],
    );
  }
}
```

---

### Étape 2 : Ajouter la méthode API dans ApiService

**Fichier : `lib/services/api_service.dart`**

Ajoutez cette méthode dans la classe `ApiService` :

```dart
/// Vérifier la version de l'application
/// 
/// Paramètres:
/// - version: Version actuelle de l'application (ex: "1.0.0")
/// - platform: Plateforme ("android", "ios", ou "web")
/// 
/// Retourne la réponse de l'API ou null en cas d'erreur
Future<Map<String, dynamic>?> checkAppVersion({
  required String version,
  required String platform,
}) async {
  try {
    print('🔍 Vérification version: $version (plateforme: $platform)');
    
    // S'assurer que l'API est initialisée
    if (_dio == null) {
      await initialize();
    }
    
    final response = await _dio!.get(
      '/get-app-mobile-infos-versions',
      queryParameters: {
        'version': version,
        'platform': platform,
      },
    );
    
    if (response.statusCode == 200) {
      print('✅ Réponse vérification version: ${response.data}');
      return response.data;
    } else {
      throw Exception('Erreur lors de la vérification de version: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Erreur checkAppVersion: $e');
    return null;
  }
}
```

---

### Étape 3 : Créer le widget de dialogue de mise à jour

**Fichier : `lib/widgets/update_dialog.dart`**

Créez ce fichier avec le code suivant :

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/version_service.dart';

/// Dialogue pour afficher les informations de mise à jour
class UpdateDialog extends StatelessWidget {
  final bool forceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? releaseNotes;
  final String? updateUrl;
  final String? platform;
  
  const UpdateDialog({
    Key? key,
    required this.forceUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.updateUrl,
    this.platform,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !forceUpdate, // Empêcher la fermeture si mise à jour obligatoire
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              forceUpdate ? Icons.warning : Icons.system_update,
              color: forceUpdate ? Colors.orange : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                forceUpdate ? 'Mise à jour obligatoire' : 'Mise à jour disponible',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: forceUpdate ? Colors.orange : Colors.blue,
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
                'Une nouvelle version de l\'application est disponible.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildVersionInfo(),
              if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Notes de version:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    releaseNotes!,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
              if (forceUpdate) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cette mise à jour est obligatoire pour continuer à utiliser l\'application.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Plus tard'),
            ),
          ElevatedButton.icon(
            onPressed: () => _handleUpdate(context),
            icon: const Icon(Icons.download),
            label: const Text('Mettre à jour'),
            style: ElevatedButton.styleFrom(
              backgroundColor: forceUpdate ? Colors.orange : Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVersionInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version actuelle: $currentVersion',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Nouvelle version: $latestVersion',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleUpdate(BuildContext context) async {
    // Pour web, recharger la page
    if (kIsWeb) {
      // Recharger la page pour appliquer la mise à jour
      // Note: En production, vous devriez utiliser un service worker ou un mécanisme de cache busting
      print('🔄 Rechargement de la page pour la mise à jour web...');
      // window.location.reload(); // Décommentez si vous utilisez dart:html
      Navigator.of(context).pop(true);
      return;
    }
    
    // Pour mobile, ouvrir le store
    if (updateUrl != null && updateUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse(updateUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          Navigator.of(context).pop(true);
        } else {
          _showError(context, 'Impossible d\'ouvrir le lien de mise à jour.');
        }
      } catch (e) {
        print('❌ Erreur lors de l\'ouverture du lien: $e');
        _showError(context, 'Erreur lors de l\'ouverture du store.');
      }
    } else {
      _showError(context, 'Lien de mise à jour non disponible.');
    }
  }
  
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

### Étape 4 : Créer le service de gestion des mises à jour

**Fichier : `lib/services/update_service.dart`**

Créez ce fichier avec le code suivant :

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'version_service.dart';
import '../widgets/update_dialog.dart';

/// Service pour gérer les vérifications de mise à jour
class UpdateService {
  final VersionService _versionService;
  static const String _lastCheckKey = 'last_update_check';
  static const int _checkIntervalHours = 24; // Vérifier une fois par jour
  
  UpdateService(this._versionService);
  
  /// Vérifier la mise à jour et afficher le dialogue si nécessaire
  /// 
  /// Paramètres:
  /// - context: Le contexte BuildContext pour afficher le dialogue
  /// - forceCheck: Si true, force la vérification même si elle a été faite récemment
  /// - showOnlyIfRequired: Si true, n'affiche le dialogue que si la mise à jour est obligatoire
  Future<void> checkAndShowUpdate({
    required BuildContext context,
    bool forceCheck = false,
    bool showOnlyIfRequired = false,
  }) async {
    try {
      // Vérifier si on doit faire la vérification
      if (!forceCheck && !await _shouldCheck()) {
        print('⏭️ Vérification de mise à jour ignorée (trop récente)');
        return;
      }
      
      print('🔍 Début de la vérification de mise à jour...');
      
      // Vérifier la version
      final result = await _versionService.checkForUpdate();
      
      // Enregistrer la date de la vérification
      await _saveLastCheck();
      
      // Afficher le dialogue si nécessaire
      if (result.updateAvailable) {
        // Si showOnlyIfRequired est true, n'afficher que si obligatoire
        if (showOnlyIfRequired && !result.updateRequired && !result.forceUpdate) {
          print('ℹ️ Mise à jour disponible mais non obligatoire, dialogue non affiché');
          return;
        }
        
        print('✅ Mise à jour disponible: ${result.latestVersion}');
        _showUpdateDialog(context, result);
      } else {
        print('✅ Application à jour (version: ${result.currentVersion})');
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification de mise à jour: $e');
      // Ne pas afficher d'erreur à l'utilisateur pour ne pas perturber l'expérience
    }
  }
  
  /// Vérifier la mise à jour au démarrage de l'application
  /// Affiche uniquement les mises à jour obligatoires
  Future<void> checkOnAppStart(BuildContext context) async {
    await checkAndShowUpdate(
      context: context,
      forceCheck: false,
      showOnlyIfRequired: true, // Afficher uniquement les mises à jour obligatoires au démarrage
    );
  }
  
  /// Vérifier la mise à jour périodiquement (en arrière-plan)
  Future<void> checkPeriodically(BuildContext context) async {
    await checkAndShowUpdate(
      context: context,
      forceCheck: false,
      showOnlyIfRequired: false, // Afficher toutes les mises à jour disponibles
    );
  }
  
  /// Afficher le dialogue de mise à jour
  void _showUpdateDialog(BuildContext context, VersionCheckResult result) {
    showDialog(
      context: context,
      barrierDismissible: !result.forceUpdate, // Empêcher la fermeture si obligatoire
      builder: (context) => UpdateDialog(
        forceUpdate: result.forceUpdate,
        currentVersion: result.currentVersion,
        latestVersion: result.latestVersion,
        releaseNotes: result.releaseNotes,
        updateUrl: result.updateUrl,
        platform: result.platform,
      ),
    );
  }
  
  /// Vérifier si on doit faire la vérification
  Future<bool> _shouldCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckMillis = prefs.getInt(_lastCheckKey);
      
      if (lastCheckMillis == null) {
        return true; // Première vérification
      }
      
      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
      final now = DateTime.now();
      final difference = now.difference(lastCheck);
      
      // Vérifier si l'intervalle de temps est écoulé
      return difference.inHours >= _checkIntervalHours;
    } catch (e) {
      print('❌ Erreur lors de la vérification de la dernière vérification: $e');
      return true; // En cas d'erreur, faire la vérification
    }
  }
  
  /// Enregistrer la date de la dernière vérification
  Future<void> _saveLastCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement de la dernière vérification: $e');
    }
  }
  
  /// Forcer une vérification immédiate (pour les tests ou depuis les paramètres)
  Future<void> forceCheck(BuildContext context) async {
    await checkAndShowUpdate(
      context: context,
      forceCheck: true,
      showOnlyIfRequired: false,
    );
  }
}
```

---

### Étape 5 : Intégrer dans main.dart

**Fichier : `lib/main.dart`**

Ajoutez l'initialisation du service de mise à jour dans votre `main.dart`. Voici un exemple d'intégration :

```dart
import 'package:flutter/material.dart';
// ... autres imports ...
import 'services/api_service.dart';
import 'services/version_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser l'API Service
  final apiService = ApiService();
  await apiService.initialize();
  
  // Initialiser les services de mise à jour
  final versionService = VersionService(apiService);
  final updateService = UpdateService(versionService);
  
  runApp(MyApp(updateService: updateService));
}

class MyApp extends StatelessWidget {
  final UpdateService updateService;
  
  const MyApp({Key? key, required this.updateService}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... votre configuration ...
      home: MyHomePage(updateService: updateService),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final UpdateService updateService;
  
  const MyHomePage({Key? key, required this.updateService}) : super(key: key);
  
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    // Vérifier la mise à jour au démarrage (uniquement les mises à jour obligatoires)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.updateService.checkOnAppStart(context);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... votre UI ...
    );
  }
}
```

**Alternative : Utiliser un GlobalKey pour accéder au contexte**

Si vous préférez vérifier la mise à jour depuis n'importe où dans l'application, vous pouvez utiliser un `GlobalKey<NavigatorState>` :

```dart
// Dans main.dart
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  await apiService.initialize();
  
  final versionService = VersionService(apiService);
  final updateService = UpdateService(versionService);
  
  runApp(MyApp(
    navigatorKey: navigatorKey,
    updateService: updateService,
  ));
  
  // Vérifier la mise à jour après un court délai
  Future.delayed(Duration(seconds: 2), () {
    final context = navigatorKey.currentContext;
    if (context != null) {
      updateService.checkOnAppStart(context);
    }
  });
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final UpdateService updateService;
  
  const MyApp({
    Key? key,
    required this.navigatorKey,
    required this.updateService,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      // ... reste de la configuration ...
    );
  }
}
```

---

### Étape 6 : Ajouter un bouton de vérification manuelle (optionnel)

Si vous souhaitez permettre à l'utilisateur de vérifier manuellement les mises à jour (par exemple dans les paramètres), ajoutez un bouton :

```dart
// Dans votre écran de paramètres
ElevatedButton.icon(
  onPressed: () async {
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    // Forcer la vérification
    await updateService.forceCheck(context);
    
    // Fermer l'indicateur de chargement
    Navigator.of(context).pop();
  },
  icon: Icon(Icons.system_update),
  label: Text('Vérifier les mises à jour'),
)
```

---

## 🧪 Tests et vérifications

### 1. Tester la détection de version

Ajoutez un bouton de test temporaire pour vérifier que la détection fonctionne :

```dart
// Dans un écran de test
ElevatedButton(
  onPressed: () async {
    final versionService = VersionService(ApiService());
    final currentVersion = await versionService.getCurrentVersion();
    final platform = await versionService.getPlatform();
    
    print('Version actuelle: $currentVersion');
    print('Plateforme: $platform');
    
    final result = await versionService.checkForUpdate();
    print('Résultat: ${result.updateAvailable}');
    print('Version la plus récente: ${result.latestVersion}');
  },
  child: Text('Tester la détection de version'),
)
```

### 2. Vérifier la réponse de l'API

Vérifiez que l'endpoint backend répond correctement :

```dart
// Test de l'API directement
final apiService = ApiService();
await apiService.initialize();

final response = await apiService.checkAppVersion(
  version: '1.0.0',
  platform: 'android',
);

print('Réponse API: $response');
```

### 3. Tester le dialogue

Testez l'affichage du dialogue avec des données fictives :

```dart
showDialog(
  context: context,
  builder: (context) => UpdateDialog(
    forceUpdate: false,
    currentVersion: '1.0.0',
    latestVersion: '1.1.0',
    releaseNotes: 'Nouvelle version avec corrections de bugs',
    updateUrl: 'https://play.google.com/store/apps/details?id=com.jirig.podium',
    platform: 'android',
  ),
);
```

---

## 📝 Notes importantes

### 1. Version de l'application

La version est extraite depuis `pubspec.yaml` :
```yaml
version: 1.0.0+1
```

Le service extrait uniquement `1.0.0` (sans le build number `+1`) pour la comparaison.

### 2. Intervalle de vérification

Par défaut, la vérification est effectuée une fois par 24 heures. Vous pouvez modifier cette valeur dans `UpdateService` :

```dart
static const int _checkIntervalHours = 24; // Modifier cette valeur
```

### 3. Mises à jour obligatoires

Les mises à jour obligatoires (`forceUpdate: true`) :
- Empêchent la fermeture du dialogue
- Sont affichées même si l'utilisateur a choisi "Plus tard" précédemment
- Doivent être installées pour continuer à utiliser l'application

### 4. Gestion des erreurs

Le système est conçu pour ne pas perturber l'utilisateur en cas d'erreur :
- Les erreurs sont loggées mais n'affichent pas de message d'erreur à l'utilisateur
- Si l'API ne répond pas, l'application continue de fonctionner normalement

### 5. Plateforme Web

Pour la plateforme web :
- Le dialogue affiche un message pour recharger la page
- Vous pouvez implémenter un mécanisme de cache busting ou de service worker pour une mise à jour automatique

---

## 🔧 Dépannage

### Problème : Le dialogue ne s'affiche pas

**Solutions :**
1. Vérifiez que l'API est initialisée : `await apiService.initialize()`
2. Vérifiez les logs pour voir si la vérification est effectuée
3. Vérifiez que l'endpoint backend répond correctement
4. Vérifiez que `showOnlyIfRequired` n'est pas à `true` si la mise à jour n'est pas obligatoire

### Problème : L'erreur "ApiService not initialized"

**Solution :**
Assurez-vous d'appeler `await apiService.initialize()` avant d'utiliser le service de version.

### Problème : Le lien de mise à jour ne s'ouvre pas

**Solutions :**
1. Vérifiez que `url_launcher` est bien installé
2. Vérifiez que l'URL est valide
3. Sur Android, vérifiez les permissions dans `AndroidManifest.xml`

### Problème : La version n'est pas détectée correctement

**Solutions :**
1. Vérifiez que `package_info_plus` est installé
2. Vérifiez le format de version dans `pubspec.yaml` (doit être `X.Y.Z+B`)
3. Vérifiez les logs pour voir la version détectée

---

## 📚 Ressources

- [package_info_plus](https://pub.dev/packages/package_info_plus)
- [device_info_plus](https://pub.dev/packages/device_info_plus)
- [url_launcher](https://pub.dev/packages/url_launcher)
- [shared_preferences](https://pub.dev/packages/shared_preferences)

---

## ✅ Checklist d'implémentation

- [ ] Ajouter les dépendances dans `pubspec.yaml`
- [ ] Créer `lib/services/version_service.dart`
- [ ] Ajouter `checkAppVersion` dans `ApiService`
- [ ] Créer `lib/widgets/update_dialog.dart`
- [ ] Créer `lib/services/update_service.dart`
- [ ] Intégrer dans `main.dart`
- [ ] Tester la détection de version
- [ ] Tester l'affichage du dialogue
- [ ] Tester l'ouverture du store
- [ ] Vérifier les logs en production

---

**Félicitations !** 🎉 Vous avez maintenant un système complet de mise à jour pour votre application Podium.
