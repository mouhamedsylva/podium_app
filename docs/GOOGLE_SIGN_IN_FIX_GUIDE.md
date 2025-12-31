# 🔧 Guide de Résolution - Erreur Google Sign-In "sign_in_failed"

## ❌ Erreur Actuelle

```
PlatformException(sign_in_failed, a2.d: 10:, null, null)
```

Cette erreur indique un problème de configuration OAuth dans Google Cloud Console.

---

## 🎯 Causes Principales

### 1. ❌ Package Name Mismatch (90% des cas)

**Problème** : Le package name dans Google Cloud Console ne correspond pas à `be.jirig.app`.

**Vérification** :
- ✅ Package name dans le code : `be.jirig.app` (dans `android/app/build.gradle.kts`)
- ❌ Package name dans Google Cloud Console : Probablement `com.example.jirig` ou autre

**Solution** : Créer un **nouveau** client OAuth Android avec le bon package name.

---

### 2. ❌ SHA-1 Non Configuré ou Incorrect

**Problème** : Le SHA-1 du keystore release n'est pas configuré dans Google Cloud Console.

**SHA-1 attendu** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

**Solution** : Vérifier et ajouter ce SHA-1 dans Google Cloud Console.

---

### 3. ❌ Client OAuth Android Non Créé

**Problème** : Aucun client OAuth Android n'existe dans Google Cloud Console.

**Solution** : Créer un client OAuth Android avec les bonnes informations.

---

## ✅ Solution Étape par Étape

### Étape 1 : Vérifier le SHA-1 Actuel

**Commande PowerShell** :
```powershell
cd android/app
keytool -list -v -keystore monapp-release.jks -alias monapp -storepass 123456 -keypass 123456 | Select-String -Pattern "SHA1"
```

**Résultat attendu** :
```
SHA1: 65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73
```

**Si différent** : Notez le SHA-1 affiché et utilisez-le dans Google Cloud Console.

---

### Étape 2 : Accéder à Google Cloud Console

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionnez votre projet
3. Naviguez vers : **APIs & Services** → **Credentials**

---

### Étape 3 : Vérifier les Clients OAuth Existants

**Cherchez un client OAuth Android avec :**
- Package name : `be.jirig.app`
- SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

**Si vous trouvez un client avec un autre package name** (ex: `com.example.jirig`) :
- ❌ **NE PAS MODIFIER** (Google ne permet pas de changer le package name)
- ✅ **CRÉER UN NOUVEAU CLIENT** avec le bon package name

---

### Étape 4 : Créer un Nouveau Client OAuth Android

1. Dans **Credentials**, cliquez sur **+ CREATE CREDENTIALS** → **OAuth client ID**

2. **Si demandé, configurez l'écran de consentement OAuth** (première fois uniquement)

3. **Sélectionnez "Android"** comme type d'application

4. **Remplissez les informations** :
   - **Name** : `Jirig Android Release` (ou votre nom)
   - **Package name** : `be.jirig.app` ⚠️ **EXACTEMENT comme dans le code**
   - **SHA-1 certificate fingerprint** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
     - ⚠️ **Copier-coller EXACTEMENT** avec les `:`
     - ⚠️ **Pas d'espaces** avant ou après

5. Cliquez sur **CREATE**

6. **Notez le Client ID** affiché (format : `XXXXX-XXXXX.apps.googleusercontent.com`)
   - C'est votre **Android Client ID**
   - ⚠️ **À configurer dans le backend SNAL** (variable `NUXT_OAUTH_ANDROID_CLIENT_ID`)

---

### Étape 5 : Vérifier le Web Client ID

1. Dans **Credentials**, trouvez le client OAuth **"Web application"**

2. **Vérifiez le Client ID** :
   - Doit correspondre à celui dans `login_screen.dart` ligne 481
   - Actuel dans le code : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`

3. **Si différent** :
   - Mettez à jour le code avec le bon Web Client ID
   - OU mettez à jour Google Cloud Console avec celui du code

---

### Étape 6 : Vérifier les Redirect URIs (Web Client)

1. Ouvrez le client OAuth **"Web application"**

2. Vérifiez les **"Authorized redirect URIs"**

3. **Doit contenir** :
   - `https://jirig.be/api/auth/google-mobile`
   - `https://jirig.com/api/auth/google-mobile` (si utilisé)

4. **Si manquant** : Ajoutez-le

---

### Étape 7 : Attendre la Propagation

**Important** : Après modification dans Google Cloud Console :
- ⏱️ Attendre **5-10 minutes** pour la propagation
- 🔄 Google met du temps à synchroniser les changements

---

### Étape 8 : Rebuilder l'APK

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

---

### Étape 9 : Réinstaller et Tester

```powershell
# Désinstaller l'ancienne version
adb uninstall be.jirig.app

# Installer la nouvelle version
flutter install
```

**OU** installez manuellement l'APK depuis `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔍 Vérifications Détaillées

### Checklist Complète

#### Dans le Code Flutter
- [ ] Package name dans `android/app/build.gradle.kts` : `be.jirig.app`
- [ ] Web Client ID dans `login_screen.dart` ligne 481 : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`

#### Dans Google Cloud Console
- [ ] Client OAuth Android existe avec package name : `be.jirig.app`
- [ ] SHA-1 configuré : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- [ ] Web Client ID correspond à celui dans le code
- [ ] Redirect URI configuré : `https://jirig.be/api/auth/google-mobile`

#### Dans le Backend SNAL
- [ ] Variable `NUXT_OAUTH_ANDROID_CLIENT_ID` configurée avec l'Android Client ID
- [ ] Variable `NUXT_OAUTH_GOOGLE_CLIENT_ID` configurée avec le Web Client ID

---

## 🐛 Erreurs Spécifiques

### Erreur "10:" (Code d'erreur 10)

**Signification** : Erreur de configuration OAuth

**Causes** :
- Package name mismatch
- SHA-1 incorrect ou manquant
- Client OAuth Android non créé

**Solution** : Suivre toutes les étapes ci-dessus.

---

### Erreur "a2.d: 10:"

**Signification** : Erreur interne Google Sign-In SDK

**Causes** :
- Configuration OAuth incorrecte
- Package name ou SHA-1 ne correspond pas

**Solution** : Vérifier que le package name et SHA-1 sont **exactement** identiques dans le code et Google Cloud Console.

---

## 📝 Commandes Utiles

### Récupérer le SHA-1 (Release Keystore)

```powershell
# Depuis le dossier android/app
keytool -list -v -keystore monapp-release.jks -alias monapp -storepass 123456 -keypass 123456
```

**Cherchez la ligne** :
```
SHA1: 65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73
```

### Récupérer le SHA-1 (Debug Keystore)

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

## 🎯 Solution Rapide (Résumé)

1. ✅ **Vérifier SHA-1** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
2. ✅ **Créer client OAuth Android** dans Google Cloud Console avec :
   - Package name : `be.jirig.app`
   - SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
3. ✅ **Vérifier Web Client ID** correspond au code
4. ✅ **Attendre 5-10 minutes** (propagation Google)
5. ✅ **Rebuilder l'APK** : `flutter clean && flutter build apk --release`
6. ✅ **Réinstaller et tester**

---

## 📞 Si le Problème Persiste

### Vérifications Supplémentaires

1. **Vérifier que l'APK est bien signé** :
   ```powershell
   # Vérifier la signature de l'APK
   jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Vérifier les logs détaillés** :
   ```powershell
   flutter logs
   ```
   Cherchez les messages commençant par `🔑 Configuration Google Sign-In`

3. **Tester avec un APK Debug** :
   - Build un APK debug : `flutter build apk --debug`
   - Ajouter le SHA-1 debug dans Google Cloud Console
   - Tester si ça fonctionne (pour isoler le problème)

---

## ✅ Configuration Finale Attendue

### Google Cloud Console

**Client OAuth Android** :
- Name : `Jirig Android Release`
- Package name : `be.jirig.app`
- SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- Client ID : `XXXXX-XXXXX.apps.googleusercontent.com` (à noter pour SNAL)

**Client OAuth Web** :
- Client ID : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`
- Redirect URIs : `https://jirig.be/api/auth/google-mobile`

### Code Flutter

**`lib/screens/login_screen.dart` ligne 481** :
```dart
const webClientId = '116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com';
```

**`android/app/build.gradle.kts` ligne 30** :
```kotlin
applicationId = "be.jirig.app"
```

---

**Dernière mise à jour** : Après résolution de l'erreur  
**SHA-1 Release** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`  
**Package Name** : `be.jirig.app`  
**Statut** : ⚠️ Configuration Google Cloud Console à vérifier/mettre à jour

