# 🔍 Guide de Vérification dans Google Cloud Console

## 📍 Où Chercher dans Google Cloud Console

### 🎯 Étape 1 : Accéder à Google Cloud Console

1. **Allez sur** : [https://console.cloud.google.com/](https://console.cloud.google.com/)
2. **Connectez-vous** avec votre compte Google
3. **Sélectionnez votre projet** (celui utilisé pour Jirig)

---

## 🔑 Vérification #1 : Web Client ID (Client OAuth Web)

### 📍 Chemin dans Google Cloud Console

```
Google Cloud Console
  → APIs & Services (menu de gauche)
    → Credentials (sous-menu)
      → Cherchez "OAuth 2.0 Client IDs"
        → Trouvez le client de type "Web application"
```

### 📝 Étapes Détaillées

1. **Dans le menu de gauche**, cliquez sur **"APIs & Services"**
2. **Cliquez sur "Credentials"** (sous-menu)
3. **Dans la section "OAuth 2.0 Client IDs"**, cherchez :
   - Un client avec le **Type** : **"Web application"**
   - Le **Name** peut être : "Web client", "Jirig Web", ou similaire

4. **Cliquez sur ce client** pour l'ouvrir

5. **Vérifiez le "Client ID"** :
   - Format : `XXXXX-XXXXX.apps.googleusercontent.com`
   - **Copiez ce Client ID**

### ✅ À Comparer

**Client ID dans Google Cloud Console** : `___________________________`  
**Client ID dans le code** (ligne 480) : `116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com`

**Ils doivent être IDENTIQUES !**

---

## 📱 Vérification #2 : Android Client ID (Client OAuth Android)

### 📍 Chemin dans Google Cloud Console

```
Google Cloud Console
  → APIs & Services (menu de gauche)
    → Credentials (sous-menu)
      → Cherchez "OAuth 2.0 Client IDs"
        → Trouvez le client de type "Android"
```

### 📝 Étapes Détaillées

1. **Dans le menu de gauche**, cliquez sur **"APIs & Services"**
2. **Cliquez sur "Credentials"** (sous-menu)
3. **Dans la section "OAuth 2.0 Client IDs"**, cherchez :
   - Un client avec le **Type** : **"Android"**
   - Le **Name** peut être : "Android client", "Jirig Android", ou similaire

4. **Cliquez sur ce client** pour l'ouvrir

5. **Vérifiez les informations suivantes** :

   **a) Package name** :
   - Doit être : `be.jirig.app`
   - **Exactement**, sans espaces, sans majuscules

   **b) SHA-1 certificate fingerprints** :
   - Doit contenir : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
   - Format : `XX:XX:XX:XX:...` (avec `:`)
   - **Si Google Play App Signing est activé**, il doit y avoir **DEUX SHA-1** :
     - SHA-1 Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
     - SHA-1 App Signing Key : (récupéré depuis Google Play Console)

### ✅ Checklist Android Client

- [ ] Package name : `be.jirig.app` (exactement)
- [ ] SHA-1 Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- [ ] SHA-1 App Signing Key : (si Google Play App Signing activé)

---

## 🌐 Vérification #3 : Redirect URI (Web Client)

### 📍 Où Trouver

**Même endroit que la Vérification #1** (Client OAuth Web)

### 📝 Étapes

1. **Ouvrez le client OAuth Web** (voir Vérification #1)
2. **Cherchez la section "Authorized redirect URIs"**
3. **Vérifiez que cette URI est présente** :
   ```
   https://jirig.be/api/auth/google-mobile
   ```

### ✅ Checklist Redirect URI

- [ ] Redirect URI : `https://jirig.be/api/auth/google-mobile` (exactement)

---

## 🔧 Vérification #4 : OAuth Consent Screen

### 📍 Chemin dans Google Cloud Console

```
Google Cloud Console
  → APIs & Services (menu de gauche)
    → OAuth consent screen (sous-menu)
```

### 📝 Étapes Détaillées

1. **Dans le menu de gauche**, cliquez sur **"APIs & Services"**
2. **Cliquez sur "OAuth consent screen"** (sous-menu)
3. **Vérifiez** :
   - **User Type** : Externe ou Interne (selon votre configuration)
   - **App name** : Rempli
   - **User support email** : Rempli
   - **Scopes** : Doit contenir au minimum :
     - `email`
     - `profile`
     - `openid`

### ✅ Checklist OAuth Consent Screen

- [ ] App name : Rempli
- [ ] User support email : Rempli
- [ ] Scopes : `email`, `profile`, `openid` présents

---

## 📚 Vérification #5 : Google Sign-In API Activée

### 📍 Chemin dans Google Cloud Console

```
Google Cloud Console
  → APIs & Services (menu de gauche)
    → Library (sous-menu)
      → Cherchez "Google Sign-In API"
```

### 📝 Étapes Détaillées

1. **Dans le menu de gauche**, cliquez sur **"APIs & Services"**
2. **Cliquez sur "Library"** (sous-menu)
3. **Dans la barre de recherche**, tapez : **"Google Sign-In API"**
4. **Cliquez sur "Google Sign-In API"**
5. **Vérifiez le statut** :
   - ✅ **"API enabled"** → OK
   - ❌ **"Enable"** → Cliquez sur "Enable"

### ✅ Checklist Google Sign-In API

- [ ] Google Sign-In API : **Enabled** (activée)

---

## 📋 Checklist Complète de Vérification

### ✅ Web Client (OAuth 2.0 Client ID - Web application)

- [ ] Client ID : `116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com` (ou celui dans votre code)
- [ ] Redirect URI : `https://jirig.be/api/auth/google-mobile`

### ✅ Android Client (OAuth 2.0 Client ID - Android)

- [ ] Package name : `be.jirig.app`
- [ ] SHA-1 Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- [ ] SHA-1 App Signing Key : (si Google Play App Signing activé)

### ✅ OAuth Consent Screen

- [ ] App name : Rempli
- [ ] User support email : Rempli
- [ ] Scopes : `email`, `profile`, `openid`

### ✅ Google Sign-In API

- [ ] API : **Enabled**

---

## 🎯 Résumé des Chemins Rapides

| Vérification | Chemin dans Google Cloud Console |
|--------------|----------------------------------|
| **Web Client ID** | APIs & Services → Credentials → OAuth 2.0 Client IDs → Web application |
| **Android Client ID** | APIs & Services → Credentials → OAuth 2.0 Client IDs → Android |
| **Redirect URI** | APIs & Services → Credentials → OAuth 2.0 Client IDs → Web application → Authorized redirect URIs |
| **OAuth Consent Screen** | APIs & Services → OAuth consent screen |
| **Google Sign-In API** | APIs & Services → Library → Chercher "Google Sign-In API" |

---

## 🔍 Screenshots à Prendre (Optionnel)

Pour faciliter le débogage, prenez des screenshots de :

1. **Client OAuth Web** (avec le Client ID visible)
2. **Client OAuth Android** (avec package name et SHA-1 visibles)
3. **OAuth Consent Screen** (avec les scopes visibles)

---

## ⚠️ Problèmes Courants

### Problème 1 : Client OAuth Web Introuvable

**Solution** :
- Créez un nouveau client OAuth Web
- Type : "Web application"
- Client ID : Utilisez celui généré par Google
- Redirect URI : `https://jirig.be/api/auth/google-mobile`

### Problème 2 : Client OAuth Android Introuvable

**Solution** :
- Créez un nouveau client OAuth Android
- Type : "Android"
- Package name : `be.jirig.app`
- SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

### Problème 3 : SHA-1 Non Trouvé dans Android Client

**Solution** :
- Cliquez sur "Edit" sur le client OAuth Android
- Ajoutez le SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- Sauvegardez

### Problème 4 : Google Sign-In API Non Activée

**Solution** :
- APIs & Services → Library
- Cherchez "Google Sign-In API"
- Cliquez sur "Enable"

---

## 📞 Informations à Noter

Après vérification, notez :

1. **Web Client ID** : `___________________________`
2. **Android Client ID** : `___________________________`
3. **Package name** : `___________________________`
4. **SHA-1 configurés** : `___________________________`
5. **Redirect URI** : `___________________________`

---

**Dernière mise à jour** : Guide de vérification dans Google Cloud Console  
**URL Google Cloud Console** : [https://console.cloud.google.com/](https://console.cloud.google.com/)  
**Statut** : ✅ Guide complet pour vérifier toutes les configurations

