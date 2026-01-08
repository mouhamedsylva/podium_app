# Guide d'implémentation - Système de mise à jour de l'application

## 📋 Vue d'ensemble

Ce document décrit l'implémentation complète d'un système de mise à jour pour l'application Podium, permettant de :
- Vérifier automatiquement les nouvelles versions disponibles
- Notifier l'utilisateur des mises à jour
- Télécharger et installer les mises à jour (selon la plateforme)

---

## 🔧 Partie Backend (SNAL-Project)

### 1. Endpoint API pour vérifier la version

#### Fichier : `SNAL-Project/server/api/app-version.get.ts`

SNAL-Project utilise **Nuxt 3** avec **H3** (et non Express). L'endpoint doit suivre la convention de nommage Nuxt : `[nom].get.ts` pour les requêtes GET.

```typescript
import {
  defineEventHandler,
  getQuery,
  createError,
} from "h3";
import { connectToDatabase } from "../db/index";
import sql from "mssql";

/**
 * Endpoint GET pour vérifier la version de l'application
 * 
 * Query parameters:
 * - version: Version actuelle de l'application (ex: "1.0.0")
 * - platform: Plateforme de l'application ("android" | "ios" | "web")
 * 
 * Response:
 * {
 *   success: boolean,
 *   updateAvailable: boolean,
 *   updateRequired: boolean,
 *   forceUpdate: boolean,
 *   latestVersion: string,
 *   minimumVersion: string,
 *   currentVersion: string,
 *   updateUrl?: string,
 *   releaseNotes?: string,
 *   platform: string
 * }
 */
export default defineEventHandler(async (event) => {
  try {
    const query = getQuery(event);
    const clientVersion = (query.version as string) || "1.0.0";
    const platform = (query.platform as string) || "web";

    console.log("🔍 Vérification de version:", { clientVersion, platform });

    // Option 1: Récupérer depuis la base de données (recommandé)
    // Option 2: Configuration statique (pour développement)
    
    // Pour l'instant, on utilise une configuration statique
    // TODO: Remplacer par une requête à la base de données
    const versions = {
      android: {
        latest: "1.1.0",
        minimum: "1.0.0",
        forceUpdate: false,
        updateUrl: "https://play.google.com/store/apps/details?id=com.jirig.podium",
        releaseNotes: "Nouvelle version avec corrections de bugs et améliorations",
      },
      ios: {
        latest: "1.1.0",
        minimum: "1.0.0",
        forceUpdate: false,
        updateUrl: "https://apps.apple.com/app/podium/id123456789",
        releaseNotes: "Nouvelle version avec corrections de bugs et améliorations",
      },
      web: {
        latest: "1.1.0",
        minimum: "1.0.0",
        forceUpdate: false,
        updateUrl: null, // Pour web, on recharge simplement la page
        releaseNotes: "Nouvelle version disponible. Rechargez la page pour mettre à jour.",
      },
    };

    const platformVersion =
      versions[platform as keyof typeof versions] || versions.web;

    // Comparer les versions
    const isUpdateRequired =
      compareVersions(clientVersion, platformVersion.minimum) < 0;
    const isUpdateAvailable =
      compareVersions(clientVersion, platformVersion.latest) < 0;

    const response = {
      success: true,
      updateAvailable: isUpdateAvailable,
      updateRequired: isUpdateRequired,
      forceUpdate: platformVersion.forceUpdate && isUpdateRequired,
      latestVersion: platformVersion.latest,
      minimumVersion: platformVersion.minimum,
      currentVersion: clientVersion,
      updateUrl: platformVersion.updateUrl,
      releaseNotes: platformVersion.releaseNotes,
      platform: platform,
    };

    console.log("✅ Réponse vérification version:", response);
    return response;
  } catch (error: any) {
    console.error("❌ Erreur lors de la vérification de version:", error);
    throw createError({
      statusCode: 500,
      message: "Erreur lors de la vérification de version",
      data: { error: error.message },
    });
  }
});

/**
 * Fonction utilitaire pour comparer les versions (format: X.Y.Z)
 * Retourne:
 * - -1 si version1 < version2
 * - 0 si version1 === version2
 * - 1 si version1 > version2
 */
function compareVersions(version1: string, version2: string): number {
  const v1Parts = version1.split(".").map(Number);
  const v2Parts = version2.split(".").map(Number);

  const maxLength = Math.max(v1Parts.length, v2Parts.length);

  for (let i = 0; i < maxLength; i++) {
    const v1Part = v1Parts[i] || 0;
    const v2Part = v2Parts[i] || 0;

    if (v1Part < v2Part) return -1;
    if (v1Part > v2Part) return 1;
  }

  return 0;
}
```

### 2. Option: Récupération depuis la base de données (recommandé)

Si vous souhaitez gérer les versions dynamiquement via la base de données, vous pouvez créer une table et une stored procedure.

#### Table SQL Server : `SNAL-Project/database/migrations/create_app_versions_table.sql`

```sql
-- Table pour stocker les versions de l'application
CREATE TABLE AppVersions (
    id INT PRIMARY KEY IDENTITY(1,1),
    sPlatform VARCHAR(10) NOT NULL, -- 'android', 'ios', 'web'
    sLatestVersion VARCHAR(20) NOT NULL, -- Ex: '1.1.0'
    sMinimumVersion VARCHAR(20) NOT NULL, -- Version minimale requise
    bForceUpdate BIT DEFAULT 0, -- 1 = mise à jour obligatoire
    sUpdateUrl NVARCHAR(500), -- URL du store ou null pour web
    sReleaseNotes NVARCHAR(MAX), -- Notes de version
    bIsActive BIT DEFAULT 1, -- Version active ou non
    dtCreatedAt DATETIME DEFAULT GETDATE(),
    dtUpdatedAt DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT UQ_Platform_Version UNIQUE (sPlatform, sLatestVersion)
);

-- Index pour les requêtes rapides
CREATE INDEX IX_Platform_Active ON AppVersions(sPlatform, bIsActive);

-- Données initiales
INSERT INTO AppVersions (sPlatform, sLatestVersion, sMinimumVersion, bForceUpdate, sUpdateUrl, sReleaseNotes) VALUES
('android', '1.1.0', '1.0.0', 0, 'https://play.google.com/store/apps/details?id=com.jirig.podium', 'Nouvelle version avec corrections de bugs'),
('ios', '1.1.0', '1.0.0', 0, 'https://apps.apple.com/app/podium/id123456789', 'Nouvelle version avec corrections de bugs'),
('web', '1.1.0', '1.0.0', 0, NULL, 'Nouvelle version disponible. Rechargez la page.');
```

#### Stored Procedure : `SNAL-Project/database/stored_procedures/proc_app_get_version.sql`

```sql
CREATE PROCEDURE proc_app_get_version
    @sPlatform VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP 1
        sLatestVersion AS latestVersion,
        sMinimumVersion AS minimumVersion,
        CAST(bForceUpdate AS BIT) AS forceUpdate,
        sUpdateUrl AS updateUrl,
        sReleaseNotes AS releaseNotes
    FROM AppVersions
    WHERE sPlatform = @sPlatform
        AND bIsActive = 1
    ORDER BY dtUpdatedAt DESC;
END
```

#### Modification de l'endpoint pour utiliser la base de données

```typescript
// Dans app-version.get.ts, remplacer la configuration statique par:

try {
  const pool = await connectToDatabase();
  if (!pool) {
    throw new Error("Connexion à la base de données non disponible.");
  }

  const result = await pool
    .request()
    .input("sPlatform", sql.VarChar(10), platform)
    .execute("proc_app_get_version");

  if (result.recordset.length === 0) {
    // Aucune version trouvée, utiliser les valeurs par défaut
    throw createError({
      statusCode: 404,
      message: "Aucune version trouvée pour cette plateforme",
    });
  }

  const platformVersion = result.recordset[0];
  // ... reste du code de comparaison ...
} catch (error) {
  // ... gestion d'erreur ...
}
```

### 3. Ajout de la route dans le proxy (pour Flutter Web)

#### Fichier : `podium_app/proxy-server.js`

Ajouter la route dans la liste des `excludedPaths` et créer un middleware pour la route :

```javascript
// Dans proxy-server.js, ajouter à excludedPaths:
const excludedPaths = [
  // ... autres paths ...
  '/api/app-version',
];

// Ajouter un middleware pour /api/app-version (si nécessaire)
app.get('/api/app-version', async (req, res) => {
  try {
    const { version, platform } = req.query;
    const targetUrl = `${SNAL_API_BASE_URL}/api/app-version?version=${version}&platform=${platform}`;
    
    const response = await axios.get(targetUrl, {
      headers: {
        'Cookie': req.headers.cookie || '',
      },
    });
    
    res.json(response.data);
  } catch (error) {
    console.error('❌ Erreur proxy app-version:', error);
    res.status(500).json({ success: false, error: 'Erreur lors de la vérification de version' });
  }
});
```

---

## 📱 Partie Frontend (podium_app)

### 1. Service de vérification de version

#### Fichier : `podium_app/lib/services/version_service.dart`

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VersionService {
  final ApiService _apiService;
  
  VersionService(this._apiService);
  
  /// Récupérer la version actuelle de l'application
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
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
      
      return VersionCheckResult(
        updateAvailable: false,
        updateRequired: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
      );
    } catch (e) {
      print('❌ Erreur vérification mise à jour: $e');
      return VersionCheckResult(
        updateAvailable: false,
        updateRequired: false,
        currentVersion: await getCurrentVersion(),
        latestVersion: await getCurrentVersion(),
      );
    }
  }
  
  /// Comparer deux versions (format: X.Y.Z)
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

### 2. Méthode API dans ApiService

#### Fichier : `podium_app/lib/services/api_service.dart`

Ajouter cette méthode dans la classe `ApiService` :

```dart
/// Vérifier la version de l'application
Future<Map<String, dynamic>?> checkAppVersion({
  required String version,
  required String platform,
}) async {
  try {
    print('🔍 Vérification version: $version (plateforme: $platform)');
    
    final response = await _dio!.get(
      '/app-version',
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

### 3. Widget de dialogue de mise à jour

#### Fichier : `podium_app/lib/widgets/update_dialog.dart`

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class UpdateDialog extends StatelessWidget {
  final bool forceUpdate;
  final String latestVersion;
  final String? releaseNotes;
  final String? updateUrl;
  final VoidCallback? onDismiss;
  
  const UpdateDialog({
    Key? key,
    required this.forceUpdate,
    required this.latestVersion,
    this.releaseNotes,
    this.updateUrl,
    this.onDismiss,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !forceUpdate, // Empêcher la fermeture si mise à jour forcée
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: forceUpdate ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                forceUpdate ? 'Mise à jour requise' : 'Mise à jour disponible',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: forceUpdate ? Colors.red : Colors.blue,
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
                'Une nouvelle version ($latestVersion) est disponible.',
                style: const TextStyle(fontSize: 16),
              ),
              if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes de version:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  releaseNotes!,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              if (forceUpdate) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cette mise à jour est obligatoire pour continuer à utiliser l\'application.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
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
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: const Text('Plus tard'),
            ),
          FilledButton(
            onPressed: () => _handleUpdate(context),
            style: FilledButton.styleFrom(
              backgroundColor: forceUpdate ? Colors.red : Colors.blue,
            ),
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleUpdate(BuildContext context) async {
    if (kIsWeb) {
      // Pour web, recharger la page
      // Note: En production, vous pourriez vouloir utiliser window.location.reload()
      Navigator.of(context).pop();
      // Recharger la page après un court délai
      Future.delayed(const Duration(milliseconds: 500), () {
        // window.location.reload(); // Décommenter en production
      });
    } else if (updateUrl != null && updateUrl!.isNotEmpty) {
      // Ouvrir le store (Play Store / App Store)
      final uri = Uri.parse(updateUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le store. Veuillez mettre à jour manuellement.'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL de mise à jour non disponible.'),
        ),
      );
    }
  }
}
```

### 4. Service de gestion des mises à jour

#### Fichier : `podium_app/lib/services/update_service.dart`

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'version_service.dart';
import '../widgets/update_dialog.dart';

class UpdateService {
  final VersionService _versionService;
  static const String _lastCheckKey = 'last_version_check';
  static const String _lastVersionKey = 'last_version_shown';
  static const Duration _checkInterval = Duration(hours: 24); // Vérifier une fois par jour
  
  UpdateService(this._versionService);
  
  /// Vérifier et afficher la mise à jour si nécessaire
  Future<void> checkAndShowUpdate(BuildContext context, {bool forceCheck = false}) async {
    try {
      // Vérifier si on doit faire une vérification
      if (!forceCheck && !await _shouldCheckForUpdate()) {
        print('⏭️ Vérification de version ignorée (trop récente)');
        return;
      }
      
      final result = await _versionService.checkForUpdate();
      
      if (result.updateAvailable || result.updateRequired) {
        // Vérifier si on a déjà montré cette version
        final prefs = await SharedPreferences.getInstance();
        final lastVersionShown = prefs.getString(_lastVersionKey);
        
        if (lastVersionShown != result.latestVersion) {
          // Afficher le dialogue de mise à jour
          await _showUpdateDialog(context, result);
          
          // Sauvegarder la version affichée
          await prefs.setString(_lastVersionKey, result.latestVersion);
        }
      }
      
      // Sauvegarder la date de dernière vérification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      
    } catch (e) {
      print('❌ Erreur checkAndShowUpdate: $e');
    }
  }
  
  /// Vérifier si on doit faire une vérification de version
  Future<bool> _shouldCheckForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey);
      
      if (lastCheck == null) {
        return true; // Première vérification
      }
      
      final lastCheckDate = DateTime.fromMillisecondsSinceEpoch(lastCheck);
      final now = DateTime.now();
      
      return now.difference(lastCheckDate) >= _checkInterval;
    } catch (e) {
      return true; // En cas d'erreur, faire la vérification
    }
  }
  
  /// Afficher le dialogue de mise à jour
  Future<void> _showUpdateDialog(BuildContext context, VersionCheckResult result) async {
    if (!context.mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: !result.forceUpdate,
      builder: (context) => UpdateDialog(
        forceUpdate: result.forceUpdate,
        latestVersion: result.latestVersion,
        releaseNotes: result.releaseNotes,
        updateUrl: result.updateUrl,
        onDismiss: () {
          print('📱 Mise à jour reportée par l\'utilisateur');
        },
      ),
    );
  }
  
  /// Vérifier la version au démarrage de l'application
  Future<void> checkOnAppStart(BuildContext context) async {
    // Attendre un peu pour que l'UI soit prête
    await Future.delayed(const Duration(seconds: 2));
    
    // Vérifier la mise à jour
    await checkAndShowUpdate(context, forceCheck: false);
  }
}
```

### 5. Intégration dans l'application

#### Fichier : `podium_app/lib/main.dart`

Modifier le `main.dart` pour initialiser le service de mise à jour :

```dart
import 'services/version_service.dart';
import 'services/update_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... autres initialisations ...
  
  // Initialiser les services
  final apiService = ApiService();
  final versionService = VersionService(apiService);
  final updateService = UpdateService(versionService);
  
  runApp(MyApp(
    updateService: updateService,
  ));
}

class MyApp extends StatelessWidget {
  final UpdateService? updateService;
  
  const MyApp({Key? key, this.updateService}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... configuration ...
      home: AppWrapper(updateService: updateService),
    );
  }
}

class AppWrapper extends StatefulWidget {
  final UpdateService? updateService;
  
  const AppWrapper({Key? key, this.updateService}) : super(key: key);
  
  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    
    // Vérifier la mise à jour au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.updateService?.checkOnAppStart(context);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return YourMainScreen(); // Votre écran principal
  }
}
```

### 6. Dépendances nécessaires

#### Fichier : `podium_app/pubspec.yaml`

Ajouter ces dépendances :

```yaml
dependencies:
  # ... dépendances existantes ...
  
  # Pour récupérer la version de l'application
  package_info_plus: ^8.0.0
  
  # Pour détecter la plateforme
  device_info_plus: ^10.1.0
  
  # Pour ouvrir les URLs (stores)
  url_launcher: ^6.2.5
  
  # Pour le stockage local (déjà présent probablement)
  shared_preferences: ^2.2.2
```

### 7. Configuration pour Android (mise à jour in-app)

#### Fichier : `podium_app/android/app/build.gradle`

Pour activer les mises à jour in-app sur Android (optionnel) :

```gradle
dependencies {
    // ... autres dépendances ...
    
    // Pour les mises à jour in-app Android (optionnel)
    implementation 'com.google.android.play:core:1.10.3'
}
```

#### Fichier : `podium_app/lib/services/android_update_service.dart` (optionnel)

```dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class AndroidUpdateService {
  static const MethodChannel _channel = MethodChannel('com.jirig.podium/update');
  
  /// Vérifier les mises à jour in-app Android
  Future<void> checkInAppUpdate() async {
    try {
      final result = await _channel.invokeMethod('checkInAppUpdate');
      print('✅ Résultat mise à jour in-app: $result');
    } on PlatformException catch (e) {
      print('❌ Erreur mise à jour in-app: $e');
    }
  }
}
```

---

## 📦 Résumé des fichiers à créer/modifier

### Backend (SNAL-Project)

1. ✅ **Nouveau fichier** : `server/api/app-version.get.ts` - Endpoint GET pour vérifier la version
   - Suit la convention Nuxt 3 : nom du fichier = nom de la route
   - Utilise `defineEventHandler` de H3
   - Accessible via `/api/app-version?version=1.0.0&platform=android`

2. ✅ **Optionnel - Nouveau fichier** : `database/migrations/create_app_versions_table.sql` - Table pour gérer les versions dynamiquement

3. ✅ **Optionnel - Nouveau fichier** : `database/stored_procedures/proc_app_get_version.sql` - Stored procedure pour récupérer les versions

4. ✅ **Modifier** : `podium_app/proxy-server.js` - Ajouter la route `/api/app-version` dans `excludedPaths` si nécessaire

### Frontend (podium_app)

1. ✅ **Nouveau fichier** : `lib/services/version_service.dart` - Service de vérification de version
2. ✅ **Nouveau fichier** : `lib/services/update_service.dart` - Service de gestion des mises à jour
3. ✅ **Nouveau fichier** : `lib/widgets/update_dialog.dart` - Widget de dialogue de mise à jour
4. ✅ **Modifier** : `lib/services/api_service.dart` - Ajouter méthode `checkAppVersion()`
5. ✅ **Modifier** : `lib/main.dart` - Intégrer le service de mise à jour
6. ✅ **Modifier** : `pubspec.yaml` - Ajouter les dépendances nécessaires

---

## 🔄 Flux de fonctionnement

1. **Au démarrage de l'application** :
   - L'application récupère sa version actuelle via `package_info_plus`
   - Appel API pour vérifier les mises à jour disponibles
   - Si une mise à jour est disponible, affichage du dialogue

2. **Vérification périodique** :
   - Vérification automatique une fois par jour (configurable)
   - Stockage de la dernière vérification dans `SharedPreferences`

3. **Types de mises à jour** :
   - **Mise à jour recommandée** : L'utilisateur peut choisir de mettre à jour maintenant ou plus tard
   - **Mise à jour forcée** : L'utilisateur doit mettre à jour pour continuer (dialogue non fermable)

4. **Actions selon la plateforme** :
   - **Android** : Redirection vers Play Store
   - **iOS** : Redirection vers App Store
   - **Web** : Rechargement de la page (ou redirection vers nouvelle version)

---

## 🎯 Points d'attention

1. **Version de l'application** : S'assurer que `pubspec.yaml` contient la bonne version :
   ```yaml
   version: 1.0.0+1
   ```

2. **Gestion des erreurs** : L'application doit continuer à fonctionner même si la vérification de version échoue

3. **Performance** : La vérification de version ne doit pas bloquer le démarrage de l'application

4. **Sécurité** : Valider les réponses de l'API côté backend pour éviter les manipulations

5. **Tests** : Tester sur toutes les plateformes (Android, iOS, Web)

---

## 📝 Notes supplémentaires

- Pour les mises à jour in-app Android, vous pouvez utiliser le package `in_app_update` (nécessite configuration supplémentaire)
- Pour iOS, les mises à jour se font uniquement via l'App Store
- Pour le web, considérer l'utilisation de Service Workers pour les mises à jour automatiques

---

## 🚀 Prochaines étapes

### Backend (SNAL-Project)

1. ✅ Créer le fichier `server/api/app-version.get.ts` avec le code fourni ci-dessus
2. ✅ Tester l'endpoint : `GET /api/app-version?version=1.0.0&platform=android`
3. ✅ (Optionnel) Créer la table `AppVersions` et la stored procedure si gestion dynamique souhaitée
4. ✅ (Optionnel) Modifier `podium_app/proxy-server.js` pour ajouter la route si nécessaire

### Frontend (podium_app)

1. ✅ Créer les services (`version_service.dart`, `update_service.dart`)
2. ✅ Créer le widget `update_dialog.dart`
3. ✅ Ajouter la méthode `checkAppVersion()` dans `api_service.dart`
4. ✅ Intégrer dans `app.dart` ou `main.dart`
5. ✅ Ajouter les dépendances dans `pubspec.yaml`
6. ✅ Tester la vérification de version sur toutes les plateformes
7. ✅ Configurer les URLs des stores (Play Store / App Store)
8. ✅ Déployer et tester en production

## 📝 Notes importantes

- **Structure SNAL-Project** : Utilise Nuxt 3 avec H3, pas Express
- **Convention de nommage** : Les fichiers dans `server/api/` suivent le pattern `[nom].[method].ts`
- **Base de données** : SQL Server avec stored procedures (comme les autres endpoints)
- **Proxy Flutter Web** : Si l'endpoint nécessite des cookies ou headers spéciaux, ajouter dans `proxy-server.js`

