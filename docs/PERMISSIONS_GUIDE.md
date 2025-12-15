# 🔐 Guide des Permissions - Jirig

## 📱 Permissions Ajoutées

### Android (AndroidManifest.xml)

```xml
<!-- Géolocalisation (carte) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Caméra (scanner QR) -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Fonctionnalités matérielles -->
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
<uses-feature android:name="android.hardware.location.gps" android:required="false" />
```

### iOS (Info.plist)

```xml
<!-- Géolocalisation (carte) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Nous avons besoin de votre localisation pour afficher les magasins IKEA à proximité sur la carte.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Nous avons besoin de votre localisation pour afficher les magasins IKEA à proximité sur la carte.</string>

<!-- Caméra (scanner QR) -->
<key>NSCameraUsageDescription</key>
<string>Nous avons besoin d'accéder à la caméra pour scanner les codes QR des produits IKEA.</string>

<!-- Photothèque (optionnel) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Nous avons besoin d'accéder à vos photos pour sélectionner des images de produits.</string>
```

## 🎯 Permissions par Fonctionnalité

### 1. 🗺️ Carte / Géolocalisation

#### Android
- `ACCESS_FINE_LOCATION` : GPS précis
- `ACCESS_COARSE_LOCATION` : Localisation approximative (WiFi/réseau)
- `INTERNET` : Télécharger tuiles OpenStreetMap
- `ACCESS_NETWORK_STATE` : Vérifier connexion réseau

#### iOS
- `NSLocationWhenInUseUsageDescription` : Localisation pendant utilisation
- `NSLocationAlwaysAndWhenInUseUsageDescription` : Localisation toujours/utilisation

**Usage**: 
- Afficher la position de l'utilisateur sur la carte
- Trouver les magasins IKEA à proximité
- Calculer les distances

### 2. 📷 Scanner QR Code

#### Android
- `CAMERA` : Accès caméra
- `android.hardware.camera` : Fonctionnalité caméra (non obligatoire)
- `android.hardware.camera.autofocus` : Autofocus (non obligatoire)

#### iOS
- `NSCameraUsageDescription` : Accès caméra

**Usage**:
- Scanner les codes QR des produits IKEA
- Détecter et lire les barcodes

### 3. 🌐 Réseau

#### Android
- `INTERNET` : Connexion Internet
- `ACCESS_NETWORK_STATE` : État du réseau

**Usage**:
- Appels API vers backend
- Téléchargement images produits
- Téléchargement tuiles carte OpenStreetMap

### 4. 📸 Photos (Optionnel)

#### iOS
- `NSPhotoLibraryUsageDescription` : Accès photothèque

**Usage**:
- Sélectionner images pour produits (fonctionnalité future)

## ⚙️ Configuration Runtime

### Gestion des Permissions dans le Code

```dart
// Géolocalisation
Future<void> checkLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  
  if (permission == LocationPermission.deniedForever) {
    // Ouvrir les paramètres
    await Geolocator.openLocationSettings();
  }
}

// Caméra (géré automatiquement par MobileScanner)
MobileScannerController controller = MobileScannerController();
```

## 📋 Checklist de Déploiement

### Android
- [x] Permissions dans `AndroidManifest.xml`
- [x] `uses-feature` avec `required="false"` (app fonctionne sans matériel)
- [ ] Test sur appareil physique (géolocalisation)
- [ ] Test sur émulateur (caméra/localisation simulées)

### iOS
- [x] Descriptions dans `Info.plist`
- [x] Messages explicites pour l'utilisateur
- [ ] Test sur appareil physique (permissions iOS)
- [ ] Test sur simulateur

### Web
- [ ] Géolocalisation : Demandée via `navigator.geolocation` (géré par Geolocator)
- [ ] Caméra : Demandée via `getUserMedia` (géré par MobileScanner)
- [ ] HTTPS requis pour permissions (production)

## 🔍 Débogage Permissions

### Android - Vérifier via ADB

```bash
# Lister les permissions de l'app
adb shell dumpsys package com.jirig.app | grep permission

# Révoquer une permission
adb shell pm revoke com.jirig.app android.permission.CAMERA

# Accorder une permission
adb shell pm grant com.jirig.app android.permission.CAMERA
```

### iOS - Simulateur

```bash
# Réinitialiser permissions
Settings > Privacy & Security > Location Services > Jirig > Reset

# Simuler localisation
Debug > Location > Custom Location...
```

## ⚠️ Erreurs Courantes

### Erreur 1: "Permission denied" (Géolocalisation)

**Android**:
```
E/flutter: PlatformException(PERMISSION_DENIED, ...)
```

**Solution**:
1. Vérifier `AndroidManifest.xml`
2. Redemander permission via `requestPermission()`
3. Vérifier paramètres appareil (GPS activé)

### Erreur 2: "Camera not available" (Scanner)

**iOS**:
```
Error: Camera permission denied
```

**Solution**:
1. Vérifier `Info.plist`
2. Vérifier paramètres > Jirig > Caméra
3. Désinstaller/réinstaller l'app

### Erreur 3: Permissions Web (HTTPS)

**Web**:
```
getUserMedia() failed: NotAllowedError
```

**Solution**:
1. Utiliser HTTPS (pas HTTP)
2. Ou localhost pour développement
3. Accepter popup permissions navigateur

## 📊 Matrice de Permissions

| Permission | Android | iOS | Web | Obligatoire | Usage |
|---|---|---|---|---|---|
| Localisation Fine | ✅ | ✅ | ✅ | Non | Carte |
| Localisation Approx | ✅ | N/A | N/A | Non | Carte |
| Caméra | ✅ | ✅ | ✅ | Non | Scanner QR |
| Internet | ✅ | Auto | Auto | Oui | API/Carte |
| État Réseau | ✅ | Auto | Auto | Non | Vérif connexion |
| Photos | Non | ✅ | N/A | Non | Future |

## 🚀 Test des Permissions

### Script de Test

```dart
// test_permissions.dart
void testAllPermissions() async {
  print('🔐 Test des permissions...\n');
  
  // 1. Localisation
  print('📍 Test Géolocalisation:');
  LocationPermission locPerm = await Geolocator.checkPermission();
  print('  Status: $locPerm');
  
  // 2. Service localisation
  bool locEnabled = await Geolocator.isLocationServiceEnabled();
  print('  Service activé: $locEnabled\n');
  
  // 3. Caméra (via MobileScanner)
  print('📷 Test Caméra:');
  try {
    final controller = MobileScannerController();
    print('  Caméra disponible: ✅\n');
    controller.dispose();
  } catch (e) {
    print('  Erreur caméra: $e\n');
  }
  
  print('✅ Tests terminés');
}
```

### Commande Test

```bash
# Android
flutter run -d android --release

# iOS
flutter run -d ios --release

# Web (dev server = localhost = OK sans HTTPS)
flutter run -d chrome --web-port=3000
```

## 📝 Notes Importantes

### Android 6.0+ (API 23+)
- Permissions "dangereuses" demandées à runtime
- `ACCESS_FINE_LOCATION` et `CAMERA` = dangereuses
- `INTERNET` = normale (pas de demande runtime)

### iOS 14+
- Demande obligatoire avec description claire
- Refus définitif = relance impossible (paramètres manuels)
- Géolocalisation : "When In Use" vs "Always"

### Web
- HTTPS obligatoire en production
- Popup native navigateur
- Refus = pas de relance automatique

## ✅ Validation

Pour vérifier que tout fonctionne :

1. **Compiler l'app**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Tester géolocalisation**
   - Ouvrir la carte
   - Accepter permission
   - Voir position bleue sur carte

3. **Tester scanner QR**
   - Ouvrir scanner
   - Accepter permission
   - Scanner un QR code

4. **Logs de confirmation**
   ```
   📍 Permission actuelle: LocationPermission.whileInUse ✅
   📷 Caméra disponible ✅
   ```

**Toutes les permissions sont maintenant configurées !** 🎉

