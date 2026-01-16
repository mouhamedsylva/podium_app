# Pourquoi Facebook fonctionne sur Android mais pas sur iOS

## 🔍 Différences clés Android vs iOS

### 1. Configuration des fichiers

**Android** (`android/app/src/main/res/values/strings.xml`) :
```xml
<string name="facebook_app_id">1412145146538940</string>
<string name="facebook_client_token">5884bf451d9d4a5d40d7181475ccaed3</string>
```

**iOS** (`ios/Runner/Info.plist`) :
```xml
<key>FacebookAppID</key>
<string>1412145146538940</string>
<key>FacebookClientToken</key>
<string>5884bf451d9d4a5d40d7181475ccaed3</string>
```

✅ **Les deux sont configurés** - Ce n'est probablement pas le problème.

### 2. Bundle ID - ⚠️ PROBLÈME PROBABLE

**Android** :
- Package name : `be.jirig.app` (dans `AndroidManifest.xml`)
- Configuré dans Facebook Developer Portal avec ce package name

**iOS** :
- Bundle ID : `be.jirig.app.ios` (dans Xcode)
- **⚠️ Doit être configuré dans Facebook Developer Portal avec EXACTEMENT ce Bundle ID**

**🔴 CAUSE PROBABLE** : Le Bundle ID iOS (`be.jirig.app.ios`) n'est probablement **PAS configuré** dans Facebook Developer Portal, ou ne correspond pas exactement.

### 3. Token Facebook - Format différent

**Android** :
- Le SDK Android génère un token standard
- Le token est validé sans problème par le backend

**iOS** :
- Le SDK iOS peut générer un token avec un format légèrement différent
- Le backend valide le token via Graph API (`debug_token`)
- Si le token iOS est associé à un App ID différent, la validation échoue

**🔴 CAUSE PROBABLE** : Le token iOS est associé à un App ID qui ne correspond pas à `FB_APP_ID` dans le backend, donc la validation STEP 3 échoue.

### 4. AppDelegate - Gestion des callbacks

**Android** :
- Les callbacks sont gérés automatiquement par le SDK

**iOS** :
- Les callbacks doivent être gérés dans `AppDelegate.swift`
- Actuellement, le code dit "le SDK gère automatiquement" mais peut nécessiter une gestion explicite

**🔴 CAUSE POSSIBLE** : Les callbacks Facebook ne sont pas correctement gérés dans AppDelegate.

## 🔍 Analyse du code actuel

### AppDelegate.swift (lignes 15-31)

```swift
override func application(_ app: UIApplication, open url: URL, options: ...) -> Bool {
  // Gérer les callbacks Google Sign-In
  if GIDSignIn.sharedInstance.handle(url) {
    return true
  }
  
  // Gérer les callbacks Facebook (le SDK flutter_facebook_auth gère automatiquement via GeneratedPluginRegistrant)
  // Mais on peut aussi le gérer explicitement si nécessaire
  
  return super.application(app, open: url, options: options)
}
```

**⚠️ Problème** : Le commentaire dit que Facebook est géré automatiquement, mais cela peut ne pas fonctionner dans tous les cas.

## ✅ Solutions

### Solution 1 : Vérifier Bundle ID dans Facebook Developer Portal

1. Aller sur [developers.facebook.com](https://developers.facebook.com/)
2. Sélectionner votre app (ID: `1412145146538940`)
3. Settings → Basic → Section **iOS**
4. Vérifier que **Bundle ID** = `be.jirig.app.ios` (exactement, même casse)
5. Si différent ou manquant :
   - Ajouter/Modifier le Bundle ID iOS
   - Sauvegarder
   - Attendre quelques minutes pour la propagation

### Solution 2 : Gérer explicitement Facebook dans AppDelegate

Modifier `AppDelegate.swift` pour gérer explicitement les callbacks Facebook :

```swift
import Flutter
import UIKit
import GoogleSignIn
import FBSDKCoreKit  // Ajouter cet import

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialiser Facebook SDK
    ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Gérer les callbacks Google Sign-In
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    
    // Gérer les callbacks Facebook explicitement
    if ApplicationDelegate.shared.application(app, open: url, options: options) {
      return true
    }
    
    return super.application(app, open: url, options: options)
  }
}
```

### Solution 3 : Vérifier les logs backend

Lors d'une connexion Facebook iOS, vérifier dans les logs backend :

```
STEP 3: Validating Facebook Token
Facebook Debug Token Response: { data: { is_valid: false, app_id: "..." } }
```

Si `is_valid: false` ou `app_id` ne correspond pas à `1412145146538940`, c'est un problème de configuration Bundle ID.

## 📋 Checklist de vérification

### Facebook Developer Portal
- [ ] App ID iOS configuré avec Bundle ID = `be.jirig.app.ios`
- [ ] Bundle ID correspond exactement (même casse, mêmes points)
- [ ] App iOS activée dans Facebook Developer Portal

### Xcode
- [ ] Bundle Identifier = `be.jirig.app.ios` (dans Runner → General → Identity)
- [ ] Info.plist contient `FacebookAppID`, `FacebookClientToken`, URL scheme

### Code
- [ ] AppDelegate gère les callbacks Facebook (actuellement géré automatiquement, peut nécessiter gestion explicite)

## 🎯 Action immédiate recommandée

**1. Vérifier Bundle ID dans Facebook Developer Portal** (PRIORITÉ)

C'est la cause la plus probable. Si le Bundle ID iOS n'est pas configuré ou ne correspond pas exactement, Facebook rejette le token.

**2. Tester avec gestion explicite dans AppDelegate**

Si le Bundle ID est correct, essayer d'ajouter la gestion explicite des callbacks Facebook dans AppDelegate.

**3. Comparer les tokens**

Ajouter des logs pour comparer le format du token entre Android et iOS :
```dart
print('Token Android: ${accessToken.tokenString.substring(0, 50)}...');
print('Token iOS: ${accessToken.tokenString.substring(0, 50)}...');
```

## 📝 Notes importantes

1. **Le code Flutter est identique** pour Android et iOS - Le problème vient de la configuration native
2. **Le backend est identique** - Il valide le token de la même manière
3. **La différence est dans la configuration iOS** - Bundle ID, AppDelegate, ou permissions
