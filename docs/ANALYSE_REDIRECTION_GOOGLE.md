# 🔍 Analyse Complète - Redirection vers jirig.be après Connexion Google

## 📋 Vue d'ensemble

Ce document analyse **TOUS** les chemins possibles qui peuvent causer une redirection vers `jirig.be` quand vous cliquez sur "Se connecter avec Google".

---

## 🎯 Scénarios de Redirection Identifiés

### ✅ **SCÉNARIO 1 : Mode Web (Navigateur)** 
**Ligne : `login_screen.dart:437-454`**

```dart
if (kIsWeb) {
  // Web : Flux OAuth classique SNAL (redirection vers le site)
  final authUrl = 'https://jirig.be/api/auth/google';
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}
```

**Comportement :** ⚠️ **NORMAL** - Si vous testez dans un navigateur (mobile ou desktop), `kIsWeb = true`, donc redirection attendue.

**Solution :** Vérifiez si vous testez dans un navigateur ou une vraie app Android.

---

### ✅ **SCÉNARIO 2 : webClientId Non Configuré**
**Ligne : `login_screen.dart:475-480`**

```dart
const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

if (webClientId == 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com') {
  throw Exception('Web Client ID non configuré...');
}
```

**Comportement :** 🚨 **PROBLÈME** - Si le `webClientId` n'est pas configuré :
- Une exception est lancée
- Le code tombe dans le `catch` (ligne 546-551)
- Affiche une erreur mais **NE DEVRAIT PAS rediriger**

**Solution :** Configurez votre vrai Web Client ID dans `login_screen.dart` ligne 475.

---

### ✅ **SCÉNARIO 3 : Plateforme Non Supportée (iOS ou autre)**
**Ligne : `login_screen.dart:557-564`**

```dart
else {
  // iOS ou autre plateforme
  print('⚠️ Plateforme non supportée pour Google Sign-In Mobile');
  // Affiche erreur mais NE redirige PAS
}
```

**Comportement :** ℹ️ Affiche une erreur mais **NE redirige PAS**.

---

### ✅ **SCÉNARIO 4 : Dio Suit les Redirections HTTP**
**Ligne : `api_service.dart:1891-1903`**

```dart
final response = await _dio!.get(
  '/auth/google-mobile',
  options: Options(
    followRedirects: false, // ✅ DÉSACTIVÉ
  ),
);
```

**Comportement :** ✅ **CORRECT** - `followRedirects: false` empêche Dio de suivre les redirections HTTP 301/302.

**Vérification :** Si le backend SNAL retourne un HTTP 302 avec `Location: https://jirig.be`, Dio ne devrait pas le suivre grâce à `followRedirects: false`.

---

### ✅ **SCÉNARIO 5 : Proxy Redirige au lieu de Proxy**
**Ligne : `proxy-server.js:2017-2132`**

**Avant correction :** ❌ Le proxy utilisait `res.redirect(snallUrl)` qui redirigeait le navigateur.

**Après correction :** ✅ Le proxy utilise maintenant `res.json(data)` qui retourne la réponse JSON.

**Vérification :** Vérifiez que le proxy utilise bien `res.json()` et non `res.redirect()`.

---

### ✅ **SCÉNARIO 6 : Backend SNAL Redirige**
**Fichier : `SNAL-Project/server/api/auth/google-mobile.get.ts`**

**Ligne 129-136 :** Le backend retourne un JSON :
```typescript
return {
  status: "success",
  iProfile: profileData.iProfileEncrypted,
  iBasket: profileData.iBasketProfil,
  nom, prenom, email,
};
```

**Comportement :** ✅ **CORRECT** - Le backend retourne du JSON, pas de redirection.

**Vérification :** Si le backend Nuxt fait une redirection via `sendRedirect()` ou `setHeader('Location')`, cela pourrait causer une redirection.

---

### ✅ **SCÉNARIO 7 : Configuration API (baseUrl)**
**Ligne : `api_config.dart:24-37`**

```dart
static String get baseUrl {
  if (kIsWeb) {
    return 'http://localhost:3001/api'; // Proxy local
  } else {
    if (useProductionApiOnMobile) {
      return 'https://jirig.be/api'; // ⚠️ Production directe
    } else {
      return localProxyUrl; // Proxy local (10.0.2.2:3001/api)
    }
  }
}
```

**Comportement :** 
- Si `useProductionApiOnMobile = true` → Appelle directement `https://jirig.be/api`
- Si `useProductionApiOnMobile = false` → Utilise le proxy local

**Vérification :** Vérifiez la valeur de `useProductionApiOnMobile` dans `api_config.dart`.

---

### ✅ **SCÉNARIO 8 : Erreur dans Google Sign-In**
**Ligne : `login_screen.dart:492-500`**

```dart
final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

if (googleUser == null) {
  // L'utilisateur a annulé
  return; // ⚠️ Ne redirige PAS mais retourne
}
```

**Comportement :** Si l'utilisateur annule, le code retourne sans redirection.

**Vérification :** Si Google Sign-In échoue avec une exception, le code tombe dans le `catch` (ligne 546) qui affiche une erreur mais ne devrait pas rediriger.

---

### ✅ **SCÉNARIO 9 : Exception Non Gérée**
**Ligne : `login_screen.dart:565-571`**

```dart
catch (e) {
  print('❌ Erreur connexion Google: $e');
  setState(() {
    _errorMessage = translationService.translate('LOGIN_ERROR_GOOGLE');
  });
}
```

**Comportement :** Affiche une erreur mais **NE redirige PAS**.

---

## 🔍 Diagnostic Complet

### **Étape 1 : Vérifier la Plateforme Détectée**

Quand vous cliquez sur "Se connecter avec Google", regardez les logs :

```
🔍 DEBUG Plateforme:
   kIsWeb: true ou false ?
   Platform.isAndroid: true ou false ?
   Platform.operatingSystem: ?
```

**Si `kIsWeb: true`** → Vous êtes dans un navigateur, redirection normale vers jirig.be ✅
**Si `kIsWeb: false` et `Platform.isAndroid: true`** → Vous êtes sur Android, le flux Google Sign-In devrait s'exécuter

---

### **Étape 2 : Vérifier le Web Client ID**

Vérifiez dans `login_screen.dart` ligne 475 :

```dart
const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
```

**Si c'est encore `YOUR_WEB_CLIENT_ID`** → ❌ **PROBLÈME** - Remplacez par votre vrai Web Client ID.

---

### **Étape 3 : Vérifier la Configuration API**

Vérifiez dans `api_config.dart` :

```dart
static const bool useProductionApiOnMobile = false; // ou true ?
```

**Si `true`** → L'app appelle directement `https://jirig.be/api`
**Si `false`** → L'app utilise le proxy local (`http://10.0.2.2:3001/api`)

---

### **Étape 4 : Vérifier les Logs du Proxy**

Vérifiez les logs du proxy quand vous cliquez sur "Se connecter avec Google" :

```bash
# Dans le terminal où tourne le proxy
🔐 AUTH/GOOGLE-MOBILE: Connexion OAuth Google Mobile (Flutter Android)
📥 id_token reçu: ...
📡 Appel SNAL API: https://jirig.be/api/auth/google-mobile?id_token=...
✅ Réponse SNAL reçue: {...}
```

**Si vous voyez `res.redirect()` dans les logs** → ❌ **PROBLÈME** - Le proxy redirige au lieu de retourner JSON.

---

### **Étape 5 : Vérifier les Logs Flutter**

Dans les logs Flutter, vérifiez :

```
📱 Mode Android détecté - Utilisation de Google Sign-In Mobile
🔑 Configuration Google Sign-In avec serverClientId: ...
🔑 Demande de connexion Google Sign-In...
✅ Compte Google récupéré: ...
✅ idToken récupéré: ...
📡 Appel à /api/auth/google-mobile...
```

**Si vous voyez une erreur** → Notez l'erreur exacte.

---

## 🚨 Causes Probables de la Redirection

### **Cause #1 : Vous testez dans un navigateur mobile (90% probable)**
- **Symptôme :** `kIsWeb = true` dans les logs
- **Solution :** Testez dans une vraie app Android compilée, pas dans un navigateur

### **Cause #2 : webClientId non configuré (5% probable)**
- **Symptôme :** Erreur "Web Client ID non configuré" dans les logs
- **Solution :** Configurez votre vrai Web Client ID dans `login_screen.dart` ligne 475

### **Cause #3 : Google Sign-In échoue silencieusement (3% probable)**
- **Symptôme :** Aucune erreur mais redirection quand même
- **Solution :** Vérifiez les logs pour voir où le code échoue

### **Cause #4 : Proxy redirige au lieu de proxy (2% probable)**
- **Symptôme :** Le proxy utilise `res.redirect()` au lieu de `res.json()`
- **Solution :** Vérifiez `proxy-server.js` ligne 2123 - doit être `res.json(data)`

---

## 🛠️ Solutions par Scénario

### **Solution 1 : Si vous testez dans un navigateur**

**Option A : Tester dans une vraie app Android**
```bash
flutter run -d android
```

**Option B : Accepter la redirection Web (comportement normal)**
- La redirection vers jirig.be est normale pour le flux Web OAuth
- L'app devrait détecter la connexion via les cookies après retour

---

### **Solution 2 : Si webClientId n'est pas configuré**

Dans `login_screen.dart` ligne 475, remplacez :
```dart
const webClientId = 'VOTRE_WEB_CLIENT_ID.apps.googleusercontent.com';
```

**Où trouver votre Web Client ID :**
1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionnez votre projet
3. Naviguez vers **APIs & Services** > **Credentials**
4. Trouvez votre **OAuth 2.0 Client ID** de type **Web application**
5. Copiez le **Client ID** (format: `XXXXX.apps.googleusercontent.com`)

---

### **Solution 3 : Si useProductionApiOnMobile = true**

Si vous testez avec `useProductionApiOnMobile = true` :
- L'app appelle directement `https://jirig.be/api/auth/google-mobile`
- Pas de proxy, donc pas de protection contre les redirections
- Assurez-vous que le backend SNAL retourne bien du JSON, pas une redirection

**Recommandation :** Pour le développement, utilisez `useProductionApiOnMobile = false` avec le proxy local.

---

### **Solution 4 : Si le proxy redirige**

Vérifiez `proxy-server.js` ligne 2123 :
```javascript
// ❌ MAUVAIS (redirige)
res.redirect(snallUrl);

// ✅ BON (retourne JSON)
res.json(data);
```

---

## 📝 Checklist de Diagnostic

Cocher chaque point pour identifier le problème :

- [ ] Je teste dans une **vraie app Android** (pas un navigateur)
- [ ] Les logs montrent `kIsWeb: false` et `Platform.isAndroid: true`
- [ ] Le `webClientId` est configuré avec mon vrai Web Client ID
- [ ] `useProductionApiOnMobile = false` dans `api_config.dart`
- [ ] Le proxy est démarré : `node proxy-server.js`
- [ ] Les logs du proxy montrent `res.json(data)` et non `res.redirect()`
- [ ] Les logs Flutter montrent "📱 Mode Android détecté"
- [ ] Les logs Flutter montrent "✅ Compte Google récupéré"
- [ ] Les logs Flutter montrent "📡 Appel à /api/auth/google-mobile"
- [ ] Les logs Flutter montrent "✅ Réponse google-mobile: {...}"

---

## 🎯 Résumé

**La redirection vers jirig.be est causée par :**

1. **Test dans un navigateur** → `kIsWeb = true` → Redirection normale (scénario 1)
2. **webClientId non configuré** → Exception → Possible redirection selon gestion d'erreur (scénario 2)
3. **Proxy redirige** → `res.redirect()` au lieu de `res.json()` → Redirection du navigateur (scénario 5)
4. **Backend SNAL redirige** → HTTP 302 avec `Location: https://jirig.be` → Dio suit la redirection (scénario 6)

**Action immédiate :** Vérifiez d'abord si vous testez dans un navigateur ou une vraie app Android en regardant les logs `🔍 DEBUG Plateforme:`.

