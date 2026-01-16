# Correction de l'erreur Facebook iOS "Facebook mobile authentication failed"

## 🔍 Problème identifié

L'erreur "Facebook mobile authentication failed" sur iOS est généralement causée par une configuration manquante dans `Info.plist`.

## ✅ Corrections apportées

### 1. Ajout de `FacebookClientToken` dans Info.plist

Le `FacebookClientToken` était manquant dans `Info.plist` iOS. Il a été ajouté :

```xml
<key>FacebookClientToken</key>
<string>5884bf451d9d4a5d40d7181475ccaed3</string>
```

**Source**: Récupéré depuis `android/app/src/main/res/values/strings.xml`

### 2. Configuration Info.plist complète (vérifiée)

Votre `Info.plist` contient maintenant :

✅ **FacebookAppID**: `1412145146538940`
✅ **FacebookDisplayName**: `Jirig`
✅ **FacebookClientToken**: `5884bf451d9d4a5d40d7181475ccaed3` (ajouté)
✅ **CFBundleURLSchemes**: `fb1412145146538940`
✅ **LSApplicationQueriesSchemes**: `fbapi`, `fbauth2`, `fbshareextension`

## ⚠️ Vérifications supplémentaires nécessaires

### 1. Facebook Developer Portal

Vérifiez que votre app iOS est configurée dans [Facebook Developers](https://developers.facebook.com/) :

1. Aller sur [developers.facebook.com](https://developers.facebook.com/)
2. Sélectionner votre app (ID: `1412145146538940`)
3. Aller dans **Settings** → **Basic**
4. Vérifier la section **iOS** :
   - ✅ **Bundle ID**: Doit être `be.jirig.app.ios` (exactement)
   - ✅ **iPhone Store ID**: Optionnel (si publié sur App Store)
   - ✅ **iPad Store ID**: Optionnel

### 2. Bundle ID dans Xcode

Vérifiez que le Bundle Identifier dans Xcode correspond :

1. Ouvrir Xcode
2. Sélectionner le target "Runner"
3. Onglet "General" → "Identity"
4. Vérifier que **Bundle Identifier** = `be.jirig.app.ios`

**IMPORTANT**: Le Bundle ID dans Facebook Developer Portal doit correspondre EXACTEMENT à celui dans Xcode.

### 3. Test après correction

Après avoir ajouté le `FacebookClientToken` :

```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter run
```

## 🔧 Dépannage si l'erreur persiste

### Vérifier les logs

Regardez les logs dans la console Xcode ou `flutter run` pour voir l'erreur exacte :

```bash
flutter run --verbose
```

### Erreurs courantes

1. **"Invalid App ID"** :
   - Vérifier que `FacebookAppID` dans Info.plist correspond à l'App ID dans Facebook Developer Portal

2. **"Bundle ID mismatch"** :
   - Vérifier que le Bundle ID dans Facebook Developer Portal = Bundle ID dans Xcode
   - Doit être exactement `be.jirig.app.ios`

3. **"Client Token invalid"** :
   - Vérifier que `FacebookClientToken` dans Info.plist correspond à celui dans Facebook Developer Portal
   - Settings → Basic → App Secret → Show → Client Token

4. **"URL Scheme not found"** :
   - Vérifier que `CFBundleURLSchemes` contient `fb1412145146538940`
   - Format: `fb` + `FacebookAppID`

## 📋 Checklist finale Facebook iOS

- [x] `FacebookAppID` dans Info.plist
- [x] `FacebookDisplayName` dans Info.plist
- [x] `FacebookClientToken` dans Info.plist (ajouté)
- [x] `CFBundleURLSchemes` avec `fb1412145146538940`
- [x] `LSApplicationQueriesSchemes` avec `fbapi`, `fbauth2`, `fbshareextension`
- [ ] Bundle ID dans Facebook Developer Portal = `be.jirig.app.ios`
- [ ] Bundle ID dans Xcode = `be.jirig.app.ios`
- [ ] AppDelegate.swift gère les URL callbacks (déjà fait)

## 📝 Notes

- Le `FacebookClientToken` est différent de l'App Secret
- Il se trouve dans Facebook Developer Portal : Settings → Basic → App Secret → Show → Client Token
- Le token utilisé (`5884bf451d9d4a5d40d7181475ccaed3`) provient de votre configuration Android et devrait être le même pour iOS
