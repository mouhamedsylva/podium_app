# 🔧 Résolution Définitive - Erreur Google Sign-In Persistante

## ❌ Erreur

```
PlatformException(sign_in_failed, a2.d: 10:, null, null)
```

**Configuration déjà faite** :
- ✅ SHA-1 configuré : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- ✅ Package name configuré : `be.jirig.app`
- ❌ **Mais l'erreur persiste**

---

## 🎯 Cause Probable #1 : Google Play App Signing ACTIVÉ

**C'EST PROBABLEMENT ÇA !** Si vous avez déjà publié l'app sur Google Play, Google Play App Signing est probablement activé.

### Vérification

1. Allez sur [Google Play Console](https://play.google.com/console)
2. Sélectionnez votre app **Jirig**
3. **Release** → **Setup** → **App signing**
4. Vérifiez le statut :
   - **"App signing by Google Play"** → ⚠️ **PROBLÈME TROUVÉ !**
   - **"App signing by you"** → ✅ OK

### Solution si App Signing Activé

1. **Dans Google Play Console** → **Release** → **Setup** → **App signing**
2. **Section "App signing key certificate"**
3. **Copiez le SHA-1 certificate fingerprint** (c'est différent de votre SHA-1 upload key !)
4. **Dans Google Cloud Console** :
   - APIs & Services → Credentials
   - Ouvrez votre client OAuth Android avec package name `be.jirig.app`
   - **Ajoutez le SHA-1 App Signing Key** (en plus de l'Upload Key)
   - Vous devez avoir **DEUX SHA-1** :
     - Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
     - App Signing Key : (celui récupéré depuis Play Console)

---

## 🎯 Cause Probable #2 : Web Client ID Incorrect

### Vérification

**Web Client ID dans le code** (ligne 481 de `login_screen.dart`) :
```
116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com
```

**À vérifier dans Google Cloud Console** :
1. APIs & Services → Credentials
2. Trouvez le client OAuth **"Web application"**
3. **Le Client ID doit être EXACTEMENT** : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`

**Si différent** :
- ❌ **Problème** : Le Web Client ID ne correspond pas
- ✅ **Solution** : Mettre à jour le code OU Google Cloud Console pour qu'ils correspondent

---

## 🎯 Cause Probable #3 : Délai de Propagation

**Google met 5-30 minutes** à propager les changements.

**Vérification** :
- Quand avez-vous modifié la configuration dans Google Cloud Console ?
- Si moins de 30 minutes → **Attendre encore**

**Solution** :
1. Attendre **30 minutes** après la dernière modification
2. Rebuilder l'APK
3. Réinstaller et tester

---

## 🎯 Cause Probable #4 : APK Non Rebuilder

**L'APK actuel a été buildé AVANT la configuration dans Google Cloud Console.**

**Solution** :
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

**Important** : Rebuilder l'APK **après** avoir configuré Google Cloud Console.

---

## ✅ Solution Complète - Ordre d'Exécution

### Étape 1 : Vérifier Google Play App Signing (CRITIQUE)

1. [Google Play Console](https://play.google.com/console) → Votre app → **Release** → **Setup** → **App signing**

2. **Si "App signing by Google Play" est activé** :
   - Copiez le **SHA-1 App Signing Key**
   - Allez dans Google Cloud Console
   - Ajoutez ce SHA-1 à votre client OAuth Android (en plus de l'Upload Key)

3. **Si "App signing by you"** :
   - Utilisez uniquement le SHA-1 Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

---

### Étape 2 : Vérifier le Web Client ID

1. **Google Cloud Console** → Credentials → Client OAuth Web
2. **Vérifiez le Client ID** : Doit être `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`
3. **Si différent** :
   - Mettez à jour le code avec le bon Client ID
   - OU créez un nouveau client OAuth Web avec le bon ID

---

### Étape 3 : Vérifier le Client OAuth Android

1. **Google Cloud Console** → Credentials
2. **Trouvez le client OAuth Android** avec :
   - Package name : `be.jirig.app` (exactement)
   - SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
   - **ET** le SHA-1 App Signing Key (si Google Play App Signing activé)

3. **Si le client n'existe pas** :
   - Créez un nouveau client OAuth Android
   - Package name : `be.jirig.app`
   - SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
   - **ET** le SHA-1 App Signing Key (si nécessaire)

---

### Étape 4 : Attendre la Propagation

**Attendre 30 minutes** après la dernière modification dans Google Cloud Console.

---

### Étape 5 : Rebuilder l'APK

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

---

### Étape 6 : Désinstaller l'Ancien APK

```powershell
adb uninstall be.jirig.app
```

**OU** désinstallez manuellement depuis l'appareil.

---

### Étape 7 : Installer le Nouveau APK

```powershell
flutter install
```

**OU** installez manuellement depuis `build/app/outputs/flutter-apk/app-release.apk`

---

### Étape 8 : Tester

1. Ouvrez l'app
2. Allez sur l'écran de login
3. Cliquez sur "Se connecter avec Google"
4. Vérifiez les logs : `flutter logs`

---

## 🔍 Vérifications Détaillées

### Vérifier les Logs Flutter

```powershell
flutter logs
```

**Cherchez** :
```
🔑 Configuration Google Sign-In avec serverClientId: 116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k...
📱 === ÉTAPE 1: Configuration Google Sign-In ===
```

**Si vous voyez l'erreur** :
```
❌ ERREUR connexion Google Mobile:
   Exception: PlatformException(sign_in_failed, a2.d: 10:, null, null)
```

→ C'est bien un problème de configuration OAuth.

---

### Vérifier dans Google Cloud Console

**Client OAuth Android** :
- [ ] Package name : `be.jirig.app` (exactement, pas d'espaces)
- [ ] SHA-1 Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- [ ] SHA-1 App Signing Key : (si Google Play App Signing activé)

**Client OAuth Web** :
- [ ] Client ID : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`
- [ ] Redirect URI : `https://jirig.be/api/auth/google-mobile`

---

## 🎯 Solution Rapide (Si Rien Ne Fonctionne)

### Option 1 : Tester avec un APK Debug

1. **Ajouter le SHA-1 Debug** dans Google Cloud Console :
   ```powershell
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```

2. **Builder un APK Debug** :
   ```powershell
   flutter build apk --debug
   ```

3. **Tester** :
   - Si ça fonctionne en debug → Problème de SHA-1 release
   - Si ça ne fonctionne pas → Problème de configuration générale

---

### Option 2 : Vérifier avec Google Play App Signing

**Si vous avez déjà publié l'app sur Google Play** :

1. **Google Play Console** → **Release** → **Setup** → **App signing**
2. **Récupérez le SHA-1 App Signing Key**
3. **Ajoutez-le dans Google Cloud Console** (c'est probablement ça le problème !)

---

## 📋 Checklist Finale

### Configuration Google Cloud Console
- [ ] Client OAuth Android avec package name `be.jirig.app`
- [ ] SHA-1 Upload Key configuré
- [ ] SHA-1 App Signing Key configuré (si Google Play App Signing activé)
- [ ] Web Client ID correspond au code
- [ ] Redirect URI configuré

### Build et Installation
- [ ] Attendu 30 minutes après dernière modification
- [ ] APK rebuilder après configuration
- [ ] Ancien APK désinstallé
- [ ] Nouvel APK installé

### Tests
- [ ] Testé la connexion Google
- [ ] Vérifié les logs pour erreurs

---

## 🎯 Action Immédiate Recommandée

**1. Vérifier Google Play App Signing** (PRIORITÉ #1) :
```
https://play.google.com/console → Votre app → Release → Setup → App signing
```

**2. Si activé, récupérer le SHA-1 App Signing Key et l'ajouter dans Google Cloud Console**

**3. Attendre 30 minutes**

**4. Rebuilder et tester**

---

**Dernière mise à jour** : Guide de résolution définitive  
**SHA-1 Upload Key** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`  
**Package Name** : `be.jirig.app`  
**Web Client ID** : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`  
**Statut** : ⚠️ Vérifier Google Play App Signing en PRIORITÉ

