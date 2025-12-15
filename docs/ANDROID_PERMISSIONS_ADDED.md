# Permissions Android Ajoutées

## 📋 Résumé des modifications

Toutes les permissions nécessaires ont été ajoutées au fichier `android/app/src/main/AndroidManifest.xml` pour assurer le bon fonctionnement de l'application Android.

---

## ✅ Permissions Ajoutées

### 1. **Permissions Réseau** (http, dio, url_launcher)
- `INTERNET` - Accès Internet pour les requêtes API
- `ACCESS_NETWORK_STATE` - Vérifier l'état de la connexion réseau
- `ACCESS_WIFI_STATE` - Vérifier l'état de la connexion WiFi

### 2. **Permissions Géolocalisation** (geolocator, flutter_map)
- `ACCESS_FINE_LOCATION` - Localisation précise (GPS)
- `ACCESS_COARSE_LOCATION` - Localisation approximative (réseau)
- `ACCESS_BACKGROUND_LOCATION` - Localisation en arrière-plan

### 3. **Permissions Caméra** (mobile_scanner - QR Code)
- `CAMERA` - Accès à la caméra pour scanner les codes QR

### 4. **Permissions Stockage** (path_provider, share_plus, cached_network_image)

#### Android 12 et inférieur (API ≤ 32)
- `READ_EXTERNAL_STORAGE` - Lire les fichiers sur le stockage externe
- `WRITE_EXTERNAL_STORAGE` - Écrire des fichiers sur le stockage externe

#### Android 13+ (API 33+)
- `READ_MEDIA_IMAGES` - Lire les images
- `READ_MEDIA_VIDEO` - Lire les vidéos
- `READ_MEDIA_AUDIO` - Lire les fichiers audio

### 5. **Déclarations de Fonctionnalités Matérielles**
- `android.hardware.camera` (optionnel) - Caméra
- `android.hardware.camera.autofocus` (optionnel) - Autofocus de la caméra
- `android.hardware.location.gps` (optionnel) - GPS
- `android.hardware.wifi` (optionnel) - WiFi

---

## 🔍 Queries pour Android 11+ (Package Visibility)

Les queries permettent à l'app de détecter et interagir avec d'autres applications sur Android 11+.

### Queries Ajoutées:
1. **URL Launcher** - Ouvrir des URLs HTTP/HTTPS dans le navigateur
2. **Share Plus** - Partager du contenu via d'autres applications
3. **Email** - Ouvrir des clients email (mailto:)
4. **Téléphone** - Composer des numéros (tel:)
5. **SMS** - Envoyer des SMS (sms:)
6. **Process Text** - Traitement de texte (Flutter engine)

---

## ⚙️ Configurations Application

### Ajouts dans la balise `<application>`:
- `android:requestLegacyExternalStorage="true"` 
  - Permet l'accès au stockage legacy sur Android 10
  - Facilite la migration vers le nouveau système de stockage scopé

- `android:usesCleartextTraffic="true"`
  - Permet les connexions HTTP non chiffrées
  - Nécessaire pour le développement local et certains serveurs

---

## 📦 Packages Nécessitant des Permissions

| Package | Permissions Requises |
|---------|---------------------|
| `dio`, `http` | INTERNET, ACCESS_NETWORK_STATE |
| `geolocator` | ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION |
| `flutter_map` | INTERNET, ACCESS_NETWORK_STATE |
| `mobile_scanner` | CAMERA |
| `share_plus` | WRITE_EXTERNAL_STORAGE (Android ≤ 12), SEND intent |
| `path_provider` | READ/WRITE_EXTERNAL_STORAGE (Android ≤ 12) |
| `cached_network_image` | INTERNET, READ/WRITE_EXTERNAL_STORAGE |
| `url_launcher` | VIEW intent (http/https) |
| `webview_flutter` | INTERNET |

---

## 🛡️ Gestion des Permissions Runtime

Pour les permissions dangereuses (comme CAMERA, LOCATION), l'application doit demander l'autorisation à l'utilisateur au moment de l'exécution.

### Permissions Runtime (à demander via `permission_handler`):
- ✅ CAMERA
- ✅ ACCESS_FINE_LOCATION
- ✅ ACCESS_COARSE_LOCATION
- ✅ READ_EXTERNAL_STORAGE (Android ≤ 12)
- ✅ WRITE_EXTERNAL_STORAGE (Android ≤ 12)
- ✅ READ_MEDIA_IMAGES (Android 13+)

### Permissions Installation (accordées automatiquement):
- ✅ INTERNET
- ✅ ACCESS_NETWORK_STATE
- ✅ ACCESS_WIFI_STATE

---

## 🔧 Fichier Modifié

📁 **`jirig/android/app/src/main/AndroidManifest.xml`**

---

## 📌 Notes Importantes

1. **Android 13+**: Les permissions de stockage ont changé. L'app utilise maintenant `READ_MEDIA_*` au lieu de `READ_EXTERNAL_STORAGE`.

2. **Localisation en arrière-plan**: Si vous utilisez `ACCESS_BACKGROUND_LOCATION`, Google Play exige une justification détaillée dans la fiche de l'application.

3. **Cleartext Traffic**: `usesCleartextTraffic` est activé pour le développement. Pour la production, il est recommandé de le désactiver et d'utiliser uniquement HTTPS.

4. **Permissions Optionnelles**: Les fonctionnalités matérielles sont marquées comme `required="false"` pour permettre l'installation sur des appareils sans ces fonctionnalités.

---

## ✅ État du Build

Le build APK devrait maintenant compiler avec succès après:
1. ✅ Résolution du problème de licence NDK
2. ✅ Correction des imports `dart:html` pour compatibilité Android
3. ✅ Ajout de toutes les permissions nécessaires
4. ✅ Configuration des queries pour Android 11+

---

**Date**: 16 octobre 2025  
**Version**: 1.0.0+1

