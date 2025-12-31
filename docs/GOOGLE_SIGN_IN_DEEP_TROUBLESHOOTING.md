# 🔧 Dépannage Approfondi - Erreur Google Sign-In Persistante

## ❌ Erreur Actuelle

```
PlatformException(sign_in_failed, a2.d: 10:, null, null)
```

**Vous avez déjà configuré** :
- ✅ SHA-1 dans Google Cloud Console
- ✅ Package name `be.jirig.app` dans Google Cloud Console
- ❌ Mais l'erreur persiste

---

## 🔍 Causes Possibles (Vérifications Approfondies)

### 1. ⚠️ Google Play App Signing ACTIVÉ

**PROBLÈME CRITIQUE** : Si Google Play App Signing est activé, Google Play utilise une **clé différente** pour signer l'APK final distribué.

**Vérification** :
1. Allez sur [Google Play Console](https://play.google.com/console)
2. Sélectionnez votre app
3. **Release** → **Setup** → **App signing**
4. Vérifiez le statut :
   - **"App signing by Google Play"** → ⚠️ **PROBLÈME** : Vous devez utiliser le SHA-1 de l'**App Signing Key**, pas de l'Upload Key
   - **"App signing by you"** → ✅ OK : Utilisez le SHA-1 de votre keystore

**Si Google Play App Signing est ACTIVÉ** :

1. **Récupérer le SHA-1 App Signing Key** :
   - Dans Google Play Console → **Release** → **Setup** → **App signing**
   - Section **"App signing key certificate"**
   - Copiez le **SHA-1 certificate fingerprint**

2. **Ajouter ce SHA-1 dans Google Cloud Console** :
   - APIs & Services → Credentials
   - Ouvrez votre client OAuth Android
   - Ajoutez le SHA-1 App Signing Key (en plus de l'Upload Key)

**Important** : Vous devez avoir **DEUX SHA-1** configurés :
- SHA-1 Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- SHA-1 App Signing Key : (récupéré depuis Play Console)

---

### 2. ❌ Web Client ID Incorrect ou Non Configuré

**Vérification** :

1. **Dans Google Cloud Console** :
   - APIs & Services → Credentials
   - Trouvez le client OAuth **"Web application"**
   - Vérifiez le Client ID

2. **Dans votre code** (`lib/screens/login_screen.dart` ligne 481) :
   ```dart
   const webClientId = '116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com';
   ```

3. **Comparer** :
   - ✅ Doivent être **identiques**
   - ❌ Si différents → Mettre à jour le code OU Google Cloud Console

---

### 3. ❌ Plusieurs Clients OAuth Android avec Package Names Différents

**Problème** : Vous pouvez avoir plusieurs clients OAuth Android avec des package names différents, ce qui peut causer des conflits.

**Vérification** :
1. Dans Google Cloud Console → Credentials
2. **Listez TOUS les clients OAuth Android**
3. Vérifiez les package names :
   - `com.example.jirig` ❌ (ancien)
   - `com.jirig.app` ❌ (ancien)
   - `be.jirig.app` ✅ (actuel)

**Solution** :
- ✅ Garder uniquement le client avec `be.jirig.app`
- ❌ Supprimer ou ignorer les anciens clients (ne pas les supprimer si utilisés ailleurs)

---

### 4. ❌ SHA-1 Mal Formaté dans Google Cloud Console

**Problème** : Le SHA-1 doit être copié **exactement** avec les `:`.

**Format correct** :
```
65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73
```

**Formats incorrects** :
- `65D366028966191C182BF8DA23C74D0D319E9A73` ❌ (sans `:`)
- `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73 ` ❌ (espace à la fin)
- ` 65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` ❌ (espace au début)

**Vérification** :
1. Dans Google Cloud Console → Credentials
2. Ouvrez votre client OAuth Android
3. Vérifiez le SHA-1 :
   - Doit avoir exactement **19 `:`** (20 paires hexadécimales)
   - Pas d'espaces avant/après
   - Format : `XX:XX:XX:...`

---

### 5. ⏱️ Délai de Propagation Non Respecté

**Problème** : Google met du temps à propager les changements (5-30 minutes).

**Vérification** :
- Quand avez-vous modifié la configuration dans Google Cloud Console ?
- Si moins de 30 minutes → **Attendre encore**

**Solution** :
1. Attendre **30 minutes** après la dernière modification
2. Rebuilder l'APK : `flutter clean && flutter build apk --release`
3. Réinstaller et tester

---

### 6. ❌ APK Non Rebuilder Après Configuration

**Problème** : L'APK actuel a été buildé **avant** la configuration dans Google Cloud Console.

**Solution** :
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

**Important** : Rebuilder l'APK **après** avoir configuré Google Cloud Console.

---

### 7. ❌ Ancien APK Encore Installé

**Problème** : L'ancien APK (avec l'ancienne configuration) est encore installé sur l'appareil.

**Solution** :
```powershell
# Désinstaller complètement l'ancienne version
adb uninstall be.jirig.app

# Installer la nouvelle version
flutter install
```

**OU** :
- Désinstaller manuellement depuis l'appareil
- Installer le nouvel APK depuis `build/app/outputs/flutter-apk/app-release.apk`

---

### 8. ❌ OAuth Consent Screen Non Configuré

**Problème** : L'écran de consentement OAuth n'est pas configuré correctement.

**Vérification** :
1. Google Cloud Console → **APIs & Services** → **OAuth consent screen**
2. Vérifiez que :
   - ✅ Type d'application : **Externe** ou **Interne**
   - ✅ Informations de l'application remplies
   - ✅ Scopes configurés : `email`, `profile`, `openid`

**Si non configuré** :
1. Configurez l'écran de consentement
2. Ajoutez les scopes nécessaires
3. Sauvegardez

---

### 9. ❌ Google Sign-In API Non Activée

**Vérification** :
1. Google Cloud Console → **APIs & Services** → **Library**
2. Cherchez **"Google Sign-In API"**
3. Vérifiez le statut :
   - ✅ **Enabled** → OK
   - ❌ **Disabled** → Cliquez sur **Enable**

---

### 10. ❌ Package Name avec Espaces ou Caractères Invisibles

**Vérification** :
1. Dans `android/app/build.gradle.kts`, ligne 30 :
   ```kotlin
   applicationId = "be.jirig.app"
   ```
2. **Copier-coller exactement** dans Google Cloud Console
3. Vérifier qu'il n'y a pas d'espaces invisibles

---

## ✅ Checklist Complète de Vérification

### Configuration Google Cloud Console

- [ ] **Client OAuth Android existe** avec package name `be.jirig.app`
- [ ] **SHA-1 Upload Key configuré** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- [ ] **SHA-1 App Signing Key configuré** (si Google Play App Signing activé)
- [ ] **SHA-1 format correct** (avec `:`, pas d'espaces)
- [ ] **Web Client ID** correspond à celui dans le code
- [ ] **Redirect URI configuré** : `https://jirig.be/api/auth/google-mobile`
- [ ] **OAuth Consent Screen configuré**
- [ ] **Google Sign-In API activée**

### Configuration Code Flutter

- [ ] **Package name** : `be.jirig.app` (dans `build.gradle.kts`)
- [ ] **Web Client ID** : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com` (dans `login_screen.dart`)

### Build et Installation

- [ ] **APK rebuilder** après configuration Google Cloud Console
- [ ] **Ancien APK désinstallé** de l'appareil
- [ ] **Nouvel APK installé**
- [ ] **Attendu 30 minutes** après dernière modification Google Cloud Console

---

## 🔧 Solution Étape par Étape (Si Toujours Erreur)

### Étape 1 : Vérifier Google Play App Signing

```powershell
# Allez sur Google Play Console
# Release → Setup → App signing
# Vérifiez si "App signing by Google Play" est activé
```

**Si activé** :
1. Récupérez le SHA-1 App Signing Key depuis Play Console
2. Ajoutez-le dans Google Cloud Console (en plus de l'Upload Key)

### Étape 2 : Vérifier Tous les Clients OAuth

1. Google Cloud Console → Credentials
2. **Listez TOUS les clients OAuth Android**
3. Pour chaque client :
   - Vérifiez le package name
   - Vérifiez les SHA-1 configurés
   - Notez le Client ID

### Étape 3 : Vérifier le Web Client ID

1. Comparez le Web Client ID dans :
   - Google Cloud Console (client OAuth Web)
   - Code Flutter (`login_screen.dart` ligne 481)
2. Doivent être **identiques**

### Étape 4 : Nettoyer et Rebuilder

```powershell
# Nettoyer complètement
flutter clean
flutter pub get

# Rebuilder
flutter build apk --release

# Désinstaller l'ancien APK
adb uninstall be.jirig.app

# Installer le nouveau
flutter install
```

### Étape 5 : Attendre et Tester

1. **Attendre 30 minutes** après la dernière modification
2. **Tester la connexion Google**
3. **Vérifier les logs** : `flutter logs`

---

## 🐛 Logs à Vérifier

### Logs Flutter

Cherchez dans `flutter logs` :
```
🔑 Configuration Google Sign-In avec serverClientId: ...
📱 === ÉTAPE 1: Configuration Google Sign-In ===
```

### Erreurs Possibles dans les Logs

- `DEVELOPER_ERROR` → Package name ou SHA-1 incorrect
- `10:` → Erreur de configuration OAuth
- `NETWORK_ERROR` → Problème de connexion
- `SIGN_IN_CANCELLED` → Utilisateur a annulé (normal)

---

## 🎯 Solution Rapide (Si Rien Ne Fonctionne)

### Option 1 : Créer un Nouveau Client OAuth Android

1. **Supprimer l'ancien client** (si possible, sinon le laisser)
2. **Créer un nouveau client OAuth Android** :
   - Name : `Jirig Android Release V2`
   - Package name : `be.jirig.app`
   - SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
3. **Attendre 30 minutes**
4. **Rebuilder et tester**

### Option 2 : Vérifier avec un APK Debug

1. **Ajouter le SHA-1 Debug** dans Google Cloud Console
2. **Builder un APK Debug** : `flutter build apk --debug`
3. **Tester** : Si ça fonctionne en debug mais pas en release → Problème de SHA-1 release

---

## 📞 Informations à Fournir pour Aide Supplémentaire

Si le problème persiste, fournissez :

1. **Screenshot de Google Cloud Console** :
   - Client OAuth Android (package name + SHA-1)
   - Client OAuth Web (Client ID)

2. **Screenshot de Google Play Console** :
   - App signing status (activé ou non)
   - SHA-1 App Signing Key (si activé)

3. **Logs complets** :
   ```powershell
   flutter logs > logs.txt
   ```

4. **Date de dernière modification** dans Google Cloud Console

---

**Dernière mise à jour** : Guide de dépannage approfondi  
**SHA-1 Upload Key** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`  
**Package Name** : `be.jirig.app`  
**Statut** : ⚠️ Vérifications approfondies nécessaires

