# Problème Bundle ID Facebook iOS

## 🔴 Problème identifié

### Incohérence Bundle ID

**Xcode** (`project.pbxproj`) :
```
PRODUCT_BUNDLE_IDENTIFIER = be.jirig.app;
```

**Vous avez dit** :
```
Le vrai Bundle ID est be.jirig.app.ios
```

**Facebook Developer Portal** :
- Doit correspondre EXACTEMENT au Bundle ID dans Xcode

## ⚠️ Impact

Si le Bundle ID dans Xcode est `be.jirig.app` mais que Facebook Developer Portal attend `be.jirig.app.ios` (ou vice versa), Facebook rejette le token iOS car il ne correspond pas à l'app configurée.

## ✅ Solution

### Option 1 : Utiliser `be.jirig.app` partout

1. **Xcode** : Vérifier que Bundle ID = `be.jirig.app`
2. **Facebook Developer Portal** : Configurer Bundle ID iOS = `be.jirig.app`
3. **GoogleService-Info.plist** : Utiliser `be.jirig.app` (si nécessaire)

### Option 2 : Utiliser `be.jirig.app.ios` partout

1. **Xcode** : Changer Bundle ID = `be.jirig.app.ios`
2. **Facebook Developer Portal** : Configurer Bundle ID iOS = `be.jirig.app.ios`
3. **GoogleService-Info.plist** : Utiliser `be.jirig.app.ios` (déjà fait)

## 🔧 Vérification dans Xcode

1. Ouvrir Xcode
2. Sélectionner le projet "Runner"
3. Sélectionner le target "Runner"
4. Onglet "General" → "Identity"
5. Vérifier **Bundle Identifier**

## 🔧 Vérification dans Facebook Developer Portal

1. Aller sur [developers.facebook.com](https://developers.facebook.com/)
2. Sélectionner votre app (ID: `1412145146538940`)
3. Settings → Basic
4. Section **iOS**
5. Vérifier **Bundle ID** (doit correspondre EXACTEMENT à Xcode)

## 📝 Note importante

**Le Bundle ID doit être IDENTIQUE dans** :
- Xcode (Bundle Identifier)
- Facebook Developer Portal (iOS Bundle ID)
- GoogleService-Info.plist (BUNDLE_ID)
- Apple Developer Portal (App ID)

Si l'un est différent, les authentifications échouent.
