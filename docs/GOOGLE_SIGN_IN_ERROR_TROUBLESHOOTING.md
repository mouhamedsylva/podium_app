# 🔧 Dépannage Google Sign-In - Erreur "sign_in_failed"

## ❌ Erreur Observée

```
PlatformException(sign_in_failed, a2.d: 10:, null, null)
```

Cette erreur apparaît lors de la connexion Google sur un APK buildé et testé sur un appareil Android physique.

---

## 🔍 Causes Possibles

### 1. ❌ Package Name Mismatch (PROBABLE)

**Problème :** Le package name dans Google Cloud Console ne correspond pas à `be.jirig.app`.

**Vérification :**
- Package name dans le code : `be.jirig.app` ✅
- Package name dans Google Cloud Console : `com.example.jirig` ou `com.jirig.app` ❌

**Solution :** Créer un nouveau client OAuth Android avec le package name `be.jirig.app`.

---

### 2. ❌ SHA-1 Non Configuré ou Incorrect

**Problème :** Le SHA-1 du keystore utilisé pour signer l'APK n'est pas configuré dans Google Cloud Console.

**Vérification :**
- Keystore utilisé : `android/app/monapp-release.jks` (selon `key.properties`)
- SHA-1 de ce keystore : À vérifier et ajouter dans Google Cloud Console

**Solution :** Récupérer le SHA-1 du keystore release et l'ajouter dans Google Cloud Console.

---

### 3. ❌ Web Client ID Incorrect

**Problème :** Le Web Client ID utilisé dans le code ne correspond pas à celui configuré dans Google Cloud Console.

**Vérification :**
- Web Client ID dans le code : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`
- Web Client ID dans Google Cloud Console : À vérifier

**Solution :** Vérifier que le Web Client ID est correct dans Google Cloud Console.

---

## ✅ Solution Complète - Étapes Détaillées

### Étape 1 : Récupérer le SHA-1 du Keystore Release

**Commande pour récupérer le SHA-1 :**

```bash
# Windows PowerShell
keytool -list -v -keystore android/app/monapp-release.jks -alias monapp -storepass 123456 -keypass 123456

# Ou si le keystore est dans un autre emplacement
keytool -list -v -keystore "chemin/vers/monapp-release.jks" -alias monapp -storepass 123456 -keypass 123456
```

**Ce que vous devez récupérer :**
```
Certificate fingerprints:
     SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
     SHA256: XX:XX:XX:XX:...
```

**Copiez le SHA-1** (format : `XX:XX:XX:...`)

---

### Étape 2 : Vérifier/Créer le Client OAuth Android dans Google Cloud Console

1. **Allez sur [Google Cloud Console](https://console.cloud.google.com/)**
2. **Sélectionnez votre projet**
3. **Naviguez vers** : **APIs & Services** → **Credentials**
4. **Vérifiez s'il existe un client OAuth Android** avec :
   - Package name : `be.jirig.app`
   - SHA-1 : Le SHA-1 de votre keystore release

**Si le client n'existe pas ou a le mauvais package name :**

5. **Cliquez sur "Create Credentials"** → **OAuth client ID**
6. **Sélectionnez "Android"**
7. **Remplissez :**
   - **Name** : `Jirig Android Release` (ou votre nom)
   - **Package name** : `be.jirig.app` ⚠️ **IMPORTANT : Utiliser le nouveau package name**
   - **SHA-1 certificate fingerprint** : Collez le SHA-1 récupéré à l'étape 1
8. **Cliquez sur "Create"**
9. **Notez le Client ID** (format : `XXXXX.apps.googleusercontent.com`) - C'est votre **Android Client ID**

---

### Étape 3 : Vérifier le Web Client ID

1. **Dans Google Cloud Console**, allez dans **Credentials**
2. **Trouvez le client OAuth "Web application"**
3. **Vérifiez que le Client ID correspond** à celui dans votre code :
   - Code : `116497000948-57hjcn4dfknnnipna69qgbhtt0gp2v9k.apps.googleusercontent.com`
   - Google Cloud Console : Doit être identique

**Si différent :** Mettez à jour le code avec le bon Web Client ID.

---

### Étape 4 : Vérifier les Redirect URIs (Web Client)

1. **Dans Google Cloud Console**, ouvrez le client OAuth "Web application"
2. **Vérifiez les "Authorized redirect URIs"**
3. **Doit contenir :**
   - `https://jirig.be/api/auth/google-mobile`

**Si manquant :** Ajoutez-le.

---

### Étape 5 : Vérifier la Configuration Backend SNAL

**Dans le fichier `.env` de SNAL**, vérifiez :

```env
NUXT_OAUTH_ANDROID_CLIENT_ID=VOTRE_ANDROID_CLIENT_ID.apps.googleusercontent.com
```

**Important :** 
- `NUXT_OAUTH_ANDROID_CLIENT_ID` doit être le **Android Client ID** (pas le Web Client ID)
- C'est l'ID du client Android créé à l'étape 2

---

## 🔍 Vérification Rapide

### Checklist

- [ ] ✅ Package name dans le code : `be.jirig.app`
- [ ] ✅ Package name dans Google Cloud Console (client Android) : `be.jirig.app`
- [ ] ✅ SHA-1 du keystore release configuré dans Google Cloud Console
- [ ] ✅ Web Client ID dans le code correspond à celui dans Google Cloud Console
- [ ] ✅ Android Client ID configuré dans SNAL `.env`
- [ ] ✅ Redirect URI `https://jirig.be/api/auth/google-mobile` configuré

---

## 🐛 Erreurs Communes

### Erreur : "10:" (code d'erreur 10)

**Signification :** Erreur de configuration OAuth (package name ou SHA-1 incorrect)

**Solution :**
1. Vérifier que le package name dans Google Cloud Console est exactement `be.jirig.app`
2. Vérifier que le SHA-1 est correct (copier-coller exact, avec les `:`)
3. Attendre quelques minutes après modification (Google met du temps à propager)

---

### Erreur : "a2.d: 10:"

**Signification :** Erreur interne Google Sign-In SDK

**Causes possibles :**
- Package name mismatch
- SHA-1 incorrect
- Client OAuth Android non créé ou mal configuré

**Solution :** Suivre toutes les étapes ci-dessus.

---

## 📝 Commandes Utiles

### Récupérer SHA-1 (Debug Keystore)

```bash
# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Linux/Mac
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Récupérer SHA-1 (Release Keystore)

```bash
# Windows PowerShell
keytool -list -v -keystore android/app/monapp-release.jks -alias monapp -storepass 123456 -keypass 123456
```

---

## ✅ Test Après Configuration

1. **Rebuilder l'APK :**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **Installer sur l'appareil :**
   ```bash
   flutter install
   ```

3. **Tester la connexion Google**

4. **Vérifier les logs :**
   ```bash
   flutter logs
   ```

---

## 🎯 Résumé de la Solution

**Le problème principal est probablement :**

1. ❌ **Package name mismatch** : Google Cloud Console a encore l'ancien package name
2. ❌ **SHA-1 non configuré** : Le SHA-1 du keystore release n'est pas dans Google Cloud Console

**Actions immédiates :**

1. ✅ Récupérer le SHA-1 du keystore release
2. ✅ Créer un nouveau client OAuth Android avec :
   - Package name : `be.jirig.app`
   - SHA-1 : Le SHA-1 récupéré
3. ✅ Vérifier que le Web Client ID est correct
4. ✅ Rebuilder et tester

---

**Date de création** : $(date)  
**Erreur** : `PlatformException(sign_in_failed, a2.d: 10:, null, null)`  
**Package name actuel** : `be.jirig.app`  
**Statut** : ⚠️ Configuration Google Cloud Console à mettre à jour

