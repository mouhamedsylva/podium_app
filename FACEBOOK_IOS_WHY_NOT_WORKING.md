# Pourquoi Facebook fonctionne sur Android mais pas sur iOS

## 🔴 Causes probables (par ordre de probabilité)

### 1. Bundle ID non configuré dans Facebook Developer Portal ⚠️ PRIORITÉ

**Problème** :
- Xcode utilise Bundle ID = `be.jirig.app`
- Facebook Developer Portal doit avoir EXACTEMENT le même Bundle ID configuré pour iOS
- Si différent ou manquant, Facebook rejette le token iOS

**Solution** :
1. Aller sur [developers.facebook.com](https://developers.facebook.com/)
2. App ID: `1412145146538940`
3. Settings → Basic → Section **iOS**
4. Vérifier/Configurer **Bundle ID** = `be.jirig.app` (exactement comme dans Xcode)
5. Sauvegarder et attendre quelques minutes

**Comment vérifier** :
- Dans les logs backend, chercher : `STEP 3: Validating Facebook Token`
- Si `is_valid: false` ou `app_id` différent, c'est un problème de Bundle ID

### 2. Token iOS associé à un App ID différent

**Problème** :
- Le token généré par iOS peut être associé à un App ID différent
- Le backend valide le token et vérifie que `app_id === FB_APP_ID`
- Si différent, validation échoue (STEP 3 backend)

**Solution** :
- Vérifier que le Bundle ID iOS dans Facebook Developer Portal correspond à l'App ID `1412145146538940`

### 3. AppDelegate ne gère pas explicitement Facebook

**Problème** :
- Le code précédent disait "Facebook gère automatiquement"
- Mais parfois, une gestion explicite est nécessaire

**Solution** :
- ✅ **DÉJÀ CORRIGÉ** : `AppDelegate.swift` gère maintenant explicitement Facebook avec `ApplicationDelegate.shared`

### 4. Permissions iOS manquantes

**Problème** :
- iOS peut nécessiter des permissions supplémentaires dans `Info.plist`
- `LSApplicationQueriesSchemes` peut manquer

**Solution** :
- Vérifier que `Info.plist` contient `LSApplicationQueriesSchemes` avec `fbapi`, `fbauth2`, etc.

## ✅ Corrections apportées

### 1. AppDelegate.swift - Gestion explicite Facebook

```swift
import FBSDKCoreKit  // Ajouté

// Initialisation Facebook SDK
ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

// Gestion des callbacks
if ApplicationDelegate.shared.application(app, open: url, options: options) {
  return true
}
```

### 2. Logs améliorés dans ApiService

- Logs détaillés pour identifier où ça casse
- Récupération depuis les cookies si JSON incomplet

## 📋 Checklist de vérification

### Facebook Developer Portal
- [ ] App ID iOS configuré
- [ ] Bundle ID iOS = `be.jirig.app` (exactement comme Xcode)
- [ ] App iOS activée

### Xcode
- [ ] Bundle Identifier = `be.jirig.app` (Runner → General → Identity)
- [ ] Info.plist contient :
  - `FacebookAppID` = `1412145146538940`
  - `FacebookClientToken` = `5884bf451d9d4a5d40d7181475ccaed3`
  - `CFBundleURLSchemes` avec `fb1412145146538940`

### Code
- [ ] AppDelegate gère explicitement Facebook (✅ fait)
- [ ] Logs backend montrent STEP 3 réussit

## 🔍 Comment déboguer

### 1. Vérifier les logs backend

Lors d'une connexion Facebook iOS, chercher dans les logs :

```
STEP 3: Validating Facebook Token
Facebook Debug Token Response: { data: { is_valid: true/false, app_id: "..." } }
```

**Si `is_valid: false`** :
- Bundle ID non configuré ou incorrect dans Facebook Developer Portal

**Si `app_id` différent de `1412145146538940`** :
- Le token iOS est associé à une autre app Facebook
- Vérifier Bundle ID dans Facebook Developer Portal

### 2. Vérifier les logs Flutter

Chercher :
```
📱 === STEP 3: Appel API /api/auth/facebook-mobile-token ===
✅ Réponse facebook-mobile reçue:
   Status Code: 200 (ou 401, 500)
```

**Si Status Code = 401** :
- Token invalide (problème Bundle ID)

**Si Status Code = 500** :
- Erreur backend (vérifier logs backend)

### 3. Comparer avec Android

**Android fonctionne** car :
- Package name = `be.jirig.app` est configuré dans Facebook Developer Portal
- Token Android est validé sans problème

**iOS ne fonctionne pas** car :
- Bundle ID iOS n'est probablement pas configuré dans Facebook Developer Portal
- Ou Bundle ID ne correspond pas exactement

## 🎯 Action immédiate

**1. Vérifier Bundle ID dans Facebook Developer Portal** (PRIORITÉ ABSOLUE)

C'est la cause la plus probable (90% des cas).

**2. Tester avec AppDelegate corrigé**

Le code AppDelegate a été modifié pour gérer explicitement Facebook.

**3. Vérifier les logs**

Après correction, tester et vérifier les logs backend et Flutter.

## 📝 Notes importantes

1. **Le code Flutter est identique** pour Android et iOS
2. **Le backend est identique** - Il valide le token de la même manière
3. **La différence est dans la configuration native iOS** :
   - Bundle ID dans Facebook Developer Portal
   - AppDelegate (maintenant corrigé)
   - Permissions Info.plist

4. **Android fonctionne** car la configuration est correcte
5. **iOS ne fonctionne pas** car la configuration iOS manque ou est incorrecte
