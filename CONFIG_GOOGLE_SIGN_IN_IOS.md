# Configuration Google Sign-In pour iOS

## ⚠️ Problème : L'app se ferme automatiquement sur iPhone

Si l'app se ferme automatiquement quand vous appuyez sur le bouton Google sur iPhone, c'est probablement dû à une configuration manquante.

## 🔧 Configuration requise

### 1. Fichier GoogleService-Info.plist (CRITIQUE)

**Ce fichier est OBLIGATOIRE pour que Google Sign-In fonctionne sur iOS.**

#### Comment l'obtenir :

1. Aller sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionner votre projet
3. Aller dans **APIs & Services** → **Credentials**
4. Trouver votre **iOS Client ID** (ou en créer un nouveau)
5. Télécharger le fichier **GoogleService-Info.plist**
6. Placer le fichier dans `ios/Runner/GoogleService-Info.plist`

#### Structure du fichier :

Le fichier doit contenir au minimum :
- `CLIENT_ID` : Votre iOS Client ID
- `REVERSED_CLIENT_ID` : L'ID inversé (utilisé pour l'URL scheme)
- `BUNDLE_ID` : Votre Bundle Identifier

#### Vérification :

Le fichier doit être présent dans :
```
podium_app/ios/Runner/GoogleService-Info.plist
```

### 2. Configuration Info.plist

Le fichier `ios/Runner/Info.plist` doit contenir l'URL scheme dans `CFBundleURLTypes` :

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.116497000948-rqah223nds6mkli2p74i7s713ccd8crd</string>
    </array>
  </dict>
</array>
```

**Note** : Le REVERSED_CLIENT_ID doit correspondre à celui dans GoogleService-Info.plist.

### 3. Configuration AppDelegate.swift

Le fichier `ios/Runner/AppDelegate.swift` doit gérer les URL callbacks :

```swift
import GoogleSignIn

override func application(
  _ app: UIApplication,
  open url: URL,
  options: [UIApplication.OpenURLOptionsKey : Any] = [:]
) -> Bool {
  if GIDSignIn.sharedInstance.handle(url) {
    return true
  }
  return super.application(app, open: url, options: options)
}
```

### 4. Configuration dans le code Dart

Le code utilise maintenant le **Web Client ID** (comme Android) :

```dart
const webClientId = '116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com';

final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: webClientId, // ✅ Web Client ID
);
```

## 🐛 Dépannage

### L'app se ferme immédiatement

**Cause probable** : Fichier `GoogleService-Info.plist` manquant ou mal configuré

**Solution** :
1. Vérifier que le fichier existe dans `ios/Runner/`
2. Vérifier que le REVERSED_CLIENT_ID dans Info.plist correspond
3. Nettoyer et rebuilder :
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   flutter pub get
   flutter run
   ```

### Erreur "configuration" ou "GoogleService-Info.plist"

**Cause** : Fichier manquant ou REVERSED_CLIENT_ID incorrect

**Solution** :
1. Télécharger le fichier depuis Google Cloud Console
2. Vérifier que le REVERSED_CLIENT_ID dans Info.plist correspond exactement

### Erreur "Invalid client"

**Cause** : Web Client ID incorrect ou Bundle ID ne correspond pas

**Solution** :
1. Vérifier que le Web Client ID est correct dans le code
2. Vérifier que le Bundle ID dans Xcode correspond à celui configuré dans Google Cloud Console

## ✅ Checklist

- [ ] Fichier `GoogleService-Info.plist` présent dans `ios/Runner/`
- [ ] REVERSED_CLIENT_ID dans Info.plist correspond à celui dans GoogleService-Info.plist
- [ ] AppDelegate.swift gère les URL callbacks Google Sign-In
- [ ] Web Client ID correct dans le code Dart
- [ ] Bundle ID correspond entre Xcode et Google Cloud Console
- [ ] iOS Client ID créé dans Google Cloud Console
- [ ] Pods installés : `cd ios && pod install`

## 📝 Notes importantes

1. **Web Client ID vs iOS Client ID** :
   - `serverClientId` dans le code Dart = **Web Client ID**
   - URL scheme dans Info.plist = **REVERSED_CLIENT_ID** (depuis GoogleService-Info.plist)

2. **Fichier GoogleService-Info.plist** :
   - Doit être ajouté au projet Xcode
   - Doit être dans le target "Runner"
   - Ne doit PAS être dans .gitignore (ou alors utiliser un template)

3. **Test** :
   - Tester sur un appareil physique iOS
   - Le simulateur peut avoir des limitations
