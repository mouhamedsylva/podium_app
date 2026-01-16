# Configuration Facebook Bundle ID - Android vs iOS

## ✅ Bundle IDs confirmés

- **Android** : `be.jirig.app`
- **iOS** : `be.jirig.app.ios`

## 🔍 Vérification dans Facebook Developer Portal

### Étapes à suivre

1. **Aller sur Facebook Developer Portal**
   - URL : [developers.facebook.com](https://developers.facebook.com/)
   - App ID : `1412145146538940`

2. **Settings → Basic**

3. **Section Android**
   - Vérifier **Package Name** = `be.jirig.app`
   - Vérifier **Class Name** = `MainActivity` (ou selon votre configuration)

4. **Section iOS** ⚠️ IMPORTANT
   - Vérifier **Bundle ID** = `be.jirig.app.ios` (exactement, même casse)
   - Si différent ou manquant : **Cliquer sur "Add Platform" → iOS**
   - Entrer Bundle ID = `be.jirig.app.ios`
   - Sauvegarder

## 🔧 Vérification dans Xcode

### Pour confirmer le Bundle ID iOS actuel

1. Ouvrir Xcode
2. Projet → Target "Runner"
3. Onglet **General** → **Identity**
4. Vérifier **Bundle Identifier** = `be.jirig.app.ios`

**⚠️ Si vous voyez `be.jirig.app` dans Xcode**, c'est l'ancien Bundle ID. Il faut le changer.

### Pour changer le Bundle ID dans Xcode (si nécessaire)

1. Xcode → Target "Runner" → **General**
2. **Bundle Identifier** → Cliquer sur le champ
3. Entrer : `be.jirig.app.ios`
4. Sauvegarder (Cmd+S)

## 🔍 Vérification dans Android

### Pour confirmer le Package Name Android

Fichier : `android/app/build.gradle.kts`

Chercher :
```kotlin
android {
    namespace = "be.jirig.app"
    // ou
    defaultConfig {
        applicationId = "be.jirig.app"
    }
}
```

**✅ Doit être** : `be.jirig.app`

## 🎯 Action immédiate

### 1. Vérifier Bundle ID iOS dans Xcode

**Si le Bundle ID dans Xcode est `be.jirig.app`** (au lieu de `be.jirig.app.ios`) :
- Le token Facebook iOS est généré avec `be.jirig.app`
- Mais Facebook Developer Portal attend peut-être `be.jirig.app.ios`
- **Résultat** : Token rejeté

### 2. Configurer Bundle ID iOS dans Facebook Developer Portal

1. Aller sur [developers.facebook.com](https://developers.facebook.com/)
2. App ID: `1412145146538940`
3. **Settings** → **Basic**
4. Section **iOS** :
   - Si absente : **Cliquer sur "Add Platform" → iOS**
   - **Bundle ID** : `be.jirig.app.ios` (exactement)
   - **iPhone Store ID** : (optionnel, pour App Store)
   - **iPad Store ID** : (optionnel, pour App Store)
5. **Enregistrer les modifications**

### 3. Vérifier les deux plateformes dans Facebook

Dans **Settings → Basic**, vous devriez voir :

**Android** :
- Package Name: `be.jirig.app`
- Class Name: `MainActivity`

**iOS** :
- Bundle ID: `be.jirig.app.ios`

## 📋 Checklist complète

### Facebook Developer Portal
- [ ] App ID : `1412145146538940`
- [ ] Android Package Name : `be.jirig.app`
- [ ] iOS Bundle ID : `be.jirig.app.ios` ⚠️ VÉRIFIER CE POINT
- [ ] Les deux plateformes sont activées

### Xcode
- [ ] Bundle Identifier = `be.jirig.app.ios` (dans Runner → General → Identity)
- [ ] Info.plist contient :
  - `FacebookAppID` = `1412145146538940`
  - `FacebookClientToken` = `5884bf451d9d4a5d40d7181475ccaed3`
  - `CFBundleURLSchemes` avec `fb1412145146538940`

### Android
- [ ] Package Name = `be.jirig.app` (dans build.gradle.kts)
- [ ] strings.xml contient :
  - `facebook_app_id` = `1412145146538940`
  - `facebook_client_token` = `5884bf451d9d4a5d40d7181475ccaed3`

### GoogleService-Info.plist
- [ ] `BUNDLE_ID` = `be.jirig.app.ios` ✅ (déjà fait)

## 🔍 Débogage

### Si le Bundle ID iOS n'est pas configuré dans Facebook

**Symptômes** :
- Android fonctionne ✅
- iOS ne fonctionne pas ❌
- Logs backend montrent : `STEP 3: Validating Facebook Token` → `is_valid: false`

**Solution** :
1. Configurer Bundle ID iOS dans Facebook Developer Portal
2. Attendre quelques minutes pour la propagation
3. Tester à nouveau

### Si le Bundle ID dans Xcode est différent

**Symptômes** :
- Token généré avec un Bundle ID
- Facebook attend un autre Bundle ID
- Validation échoue

**Solution** :
1. Vérifier Bundle ID dans Xcode
2. Si différent de `be.jirig.app.ios`, le changer
3. Rebuilder l'app iOS
4. Tester à nouveau

## 📝 Notes importantes

1. **Facebook valide le token en fonction du Bundle ID**
   - Si le token est généré avec `be.jirig.app` mais Facebook attend `be.jirig.app.ios`, la validation échoue

2. **Les deux plateformes sont indépendantes dans Facebook**
   - Android et iOS ont des configurations séparées
   - Il faut configurer les deux dans Facebook Developer Portal

3. **Le Bundle ID doit correspondre exactement**
   - Même casse
   - Même points
   - Aucun espace

## ✅ Résumé

**Problème probable** :
- Bundle ID iOS `be.jirig.app.ios` n'est pas configuré dans Facebook Developer Portal
- Ou le Bundle ID dans Xcode est `be.jirig.app` au lieu de `be.jirig.app.ios`

**Solution** :
1. Vérifier Bundle ID dans Xcode
2. Configurer Bundle ID iOS dans Facebook Developer Portal
3. Tester à nouveau
