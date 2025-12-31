# 🔑 Explication : Web Client ID pour Google Sign-In

## ❓ Question

**"À quoi correspond le `webClientId` ? Pour la connexion Google côté web ou bien ?"**

---

## 🎯 Réponse Directe

**Le `webClientId` est utilisé pour Android, PAS pour le web !**

C'est une source de confusion courante. Voici pourquoi :

---

## 📱 Pour Android : Utilisation du Web Client ID

### Comment ça fonctionne

Quand vous utilisez **Google Sign-In sur Android**, vous devez fournir un **Web Client ID** (pas un Android Client ID) dans le paramètre `serverClientId` de `GoogleSignIn`.

### Code Actuel (ligne 491-494)

```dart
final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: webClientId, // ✅ Web Client ID pour Android
);
```

**Pourquoi ?**

1. **Le Web Client ID** est utilisé pour obtenir un **idToken** côté serveur
2. **L'Android Client ID** est utilisé pour authentifier l'app Android auprès de Google
3. **Le flux complet** :
   - Android Client ID → Authentifie l'app Android
   - Web Client ID → Génère un idToken pour le serveur backend

---

## 🌐 Pour le Web : Pas de Web Client ID dans le Code

### Code Actuel (ligne 437-456)

```dart
if (kIsWeb) {
  // Web : Flux OAuth classique SNAL (redirection vers le site)
  final authUrl = 'https://jirig.be/api/auth/google';
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}
```

**Sur le web** :
- ❌ **Pas de `webClientId` utilisé dans le code Flutter**
- ✅ **Redirection directe** vers `https://jirig.be/api/auth/google`
- ✅ **Le backend SNAL** gère l'OAuth avec son propre Web Client ID

---

## 🔄 Flux Complet Expliqué

### 📱 Flux Android

```
1. Utilisateur clique "Se connecter avec Google"
   ↓
2. Google Sign-In SDK (Android)
   - Utilise Android Client ID (configuré dans Google Cloud Console)
   - Authentifie l'app Android
   ↓
3. Google Sign-In SDK demande idToken
   - Utilise Web Client ID (serverClientId dans le code)
   - Génère un idToken signé avec le Web Client ID
   ↓
4. App envoie idToken au backend
   - POST /api/auth/google-mobile?id_token=...
   ↓
5. Backend SNAL vérifie l'idToken
   - Utilise le Web Client ID pour valider l'idToken
   - Crée la session utilisateur
```

### 🌐 Flux Web

```
1. Utilisateur clique "Se connecter avec Google"
   ↓
2. Redirection vers jirig.be/api/auth/google
   ↓
3. Backend SNAL gère l'OAuth
   - Utilise son propre Web Client ID
   - Redirige vers Google OAuth
   ↓
4. Google redirige vers jirig.be avec le code
   ↓
5. Backend SNAL échange le code contre un token
   - Crée la session utilisateur
```

---

## 🔑 Différence entre Web Client ID et Android Client ID

| Type | Utilisation | Où Configuré | Où Utilisé |
|------|-------------|---------------|-------------|
| **Web Client ID** | Génère idToken pour le serveur | Google Cloud Console → OAuth 2.0 Client IDs → Web application | Code Flutter Android (serverClientId) |
| **Android Client ID** | Authentifie l'app Android | Google Cloud Console → OAuth 2.0 Client IDs → Android | Google Sign-In SDK (automatique) |

---

## ✅ Configuration Requise

### Dans Google Cloud Console

**1. Client OAuth Web** (pour `serverClientId`) :
- Type : **Web application**
- Client ID : `116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com` (ou celui dans votre code)
- Redirect URI : `https://jirig.be/api/auth/google-mobile`

**2. Client OAuth Android** (pour authentification) :
- Type : **Android**
- Package name : `be.jirig.app`
- SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

---

## 🎯 Pourquoi Utiliser le Web Client ID pour Android ?

### Raison Technique

Le **Web Client ID** est utilisé pour générer un **idToken** qui peut être vérifié par votre backend. Le backend SNAL utilise ce Web Client ID pour valider l'idToken reçu.

**Sans Web Client ID** :
- ❌ Pas d'idToken valide
- ❌ Le backend ne peut pas vérifier l'authentification
- ❌ Erreur : `PlatformException(sign_in_failed, a2.d: 10:)`

**Avec Web Client ID correct** :
- ✅ idToken généré et signé
- ✅ Backend peut vérifier l'idToken
- ✅ Connexion réussie

---

## 🔍 Vérification dans le Code

### Android (ligne 466-494)

```dart
else if (Platform.isAndroid) {
  // ✅ Android : Google Sign-In Mobile
  const webClientId = '116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com';
  
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: webClientId, // ✅ Web Client ID utilisé ici
  );
  
  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  final idToken = googleAuth.idToken; // ✅ idToken généré avec Web Client ID
}
```

### Web (ligne 437-456)

```dart
if (kIsWeb) {
  // ✅ Web : Redirection directe, pas de Web Client ID dans le code
  final authUrl = 'https://jirig.be/api/auth/google';
  await launchUrl(uri, mode: LaunchMode.platformDefault);
  // Le backend SNAL utilise son propre Web Client ID
}
```

---

## 📋 Résumé

| Plateforme | Utilisation du Web Client ID | Comment |
|------------|------------------------------|---------|
| **Android** | ✅ **OUI** | Utilisé dans `serverClientId` pour générer l'idToken |
| **Web** | ❌ **NON** | Le backend SNAL utilise son propre Web Client ID |

---

## ⚠️ Erreur Courante

**Confusion** : "Le Web Client ID est pour le web, donc je ne dois pas l'utiliser sur Android"

**Réalité** : Le Web Client ID est **nécessaire sur Android** pour générer un idToken valide pour le backend.

---

## ✅ Action à Faire

1. **Vérifier dans Google Cloud Console** :
   - Client OAuth Web → Client ID
   - Comparer avec le code (ligne 480)

2. **S'assurer que les deux correspondent** :
   - Code : `116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com`
   - Google Cloud Console : Doit être identique

3. **Vérifier aussi** :
   - Android Client ID configuré (package name + SHA-1)
   - Redirect URI configuré dans Web Client

---

**Dernière mise à jour** : Explication du Web Client ID  
**Réponse** : Le `webClientId` est utilisé pour **Android** (pas pour le web)  
**Statut** : ✅ Clarification complète

