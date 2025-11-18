# 🔐 Explication : Qu'est-ce que `id_token` ?

## 📋 Vue d'ensemble

L'`id_token` (ID Token) est un **jeton JWT (JSON Web Token)** fourni par Google Sign-In qui contient des informations sur l'utilisateur authentifié.

---

## 🎯 Qu'est-ce qu'un `id_token` ?

### **Définition**
L'`id_token` est un **token d'identité** signé par Google qui :
- ✅ **Prouve l'identité** de l'utilisateur
- ✅ **Contient des informations** sur l'utilisateur (email, nom, prénom, etc.)
- ✅ **Est signé cryptographiquement** par Google (vérifiable)
- ✅ **A une durée de vie limitée** (généralement 1 heure)

### **Format**
L'`id_token` est un **JWT (JSON Web Token)** qui ressemble à ceci :
```
eyJhbGciOiJSUzI1NiIsImtpZCI6IjEyMzQ1NiJ9.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiJZb3VyQ2xpZW50SWQuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiJZb3VyQ2xpZW50SWQuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTIyMzM0NDU1NjY3Nzg4OTkiLCJlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6IkpvaG4gRG9lIiwiZ2l2ZW5fbmFtZSI6IkpvaG4iLCJmYW1pbHlfbmFtZSI6IkRvZSIsImlhdCI6MTYzODU2Nzg5MCwiZXhwIjoxNjM4NTcxNDkwfQ.signature
```

**Structure d'un JWT :**
```
[HEADER].[PAYLOAD].[SIGNATURE]
```

---

## 📦 Contenu de l'`id_token` (Payload)

Quand vous décodez l'`id_token`, vous obtenez un JSON comme celui-ci :

```json
{
  "iss": "https://accounts.google.com",
  "azp": "YourClientId.apps.googleusercontent.com",
  "aud": "YourClientId.apps.googleusercontent.com",
  "sub": "112233445566778899",  // ✅ ID unique de l'utilisateur Google
  "email": "user@example.com",  // ✅ Email de l'utilisateur
  "email_verified": true,
  "name": "John Doe",           // ✅ Nom complet
  "given_name": "John",         // ✅ Prénom
  "family_name": "Doe",         // ✅ Nom de famille
  "picture": "https://...",     // ✅ Photo de profil
  "iat": 1638567890,            // Date d'émission
  "exp": 1638571490             // Date d'expiration
}
```

---

## 🔄 Comment l'`id_token` est généré ?

### **Flux Google Sign-In Mobile (Android)**

```
1. Utilisateur clique "Se connecter avec Google"
   ↓
2. Flutter ouvre Google Sign-In (popup natif Android)
   ↓
3. Utilisateur sélectionne son compte Google
   ↓
4. Google génère un id_token (JWT signé)
   ↓
5. Google retourne l'id_token à Flutter
   ↓
6. Flutter envoie l'id_token au backend SNAL
   ↓
7. Backend SNAL vérifie l'id_token avec Google
   ↓
8. Backend SNAL extrait les infos utilisateur (email, nom, etc.)
   ↓
9. Backend SNAL crée/mise à jour le profil utilisateur
   ↓
10. Backend SNAL retourne les identifiants (iProfile, iBasket, etc.)
```

---

## 🔍 Comment le backend SNAL utilise l'`id_token` ?

### **Dans `google-mobile.get.ts` (lignes 22-36)**

```typescript
// 1. Créer un client OAuth2 pour vérifier le token
const client = new OAuth2Client(process.env.NUXT_OAUTH_ANDROID_CLIENT_ID);

// 2. Vérifier l'id_token avec Google
const ticket = await client.verifyIdToken({
  idToken,  // ✅ L'id_token reçu depuis Flutter
  audience: process.env.NUXT_OAUTH_ANDROID_CLIENT_ID,
});

// 3. Extraire les informations utilisateur depuis le payload
const payload = ticket.getPayload();

// 4. Utiliser les informations pour créer le profil
const email = payload.email;           // ✅ Email
const nom = payload.family_name || "";  // ✅ Nom de famille
const prenom = payload.given_name || ""; // ✅ Prénom
const sProviderId = payload.sub;        // ✅ ID unique Google
```

---

## ✅ Pourquoi utiliser `id_token` au lieu de `access_token` ?

### **Différence entre `id_token` et `access_token`**

| Type | Usage | Contenu | Durée de vie |
|------|-------|---------|--------------|
| **`id_token`** | ✅ **Authentification** (qui est l'utilisateur ?) | Informations utilisateur (email, nom, etc.) | ~1 heure |
| **`access_token`** | ✅ **Autorisation** (quelles permissions ?) | Permissions pour accéder aux APIs Google | Variable |

### **Pour notre cas d'usage :**
- ✅ Nous avons besoin de **savoir qui est l'utilisateur** (email, nom, prénom)
- ✅ Nous n'avons **PAS besoin** d'accéder aux APIs Google (Gmail, Drive, etc.)
- ✅ Donc nous utilisons **`id_token`** uniquement

---

## 🔐 Sécurité de l'`id_token`

### **Vérification côté backend**

Le backend SNAL **vérifie** l'`id_token` avant de l'utiliser :

1. **Vérifie la signature** → Le token est bien signé par Google
2. **Vérifie l'audience** → Le token est destiné à notre application
3. **Vérifie l'expiration** → Le token n'est pas expiré
4. **Vérifie l'émetteur** → Le token vient bien de Google

**Code de vérification (google-mobile.get.ts ligne 24-27) :**
```typescript
const ticket = await client.verifyIdToken({
  idToken,
  audience: process.env.NUXT_OAUTH_ANDROID_CLIENT_ID, // ✅ Vérifie que le token est pour notre app
});
```

Si la vérification échoue → Le backend rejette la requête avec une erreur 401.

---

## 📱 Dans notre implémentation Flutter

### **Récupération de l'`id_token` (login_screen.dart)**

```dart
// 1. Créer une instance GoogleSignIn
final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: webClientId, // Web Client ID
);

// 2. Demander la connexion
final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

// 3. Récupérer l'authentification (contient id_token)
final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

// 4. Extraire l'id_token
final idToken = googleAuth.idToken; // ✅ C'est l'id_token !
```

### **Envoi au backend (api_service.dart)**

```dart
// Envoyer l'id_token au backend via GET
final response = await _dio!.get(
  '/auth/google-mobile',
  queryParameters: {
    'id_token': idToken, // ✅ L'id_token est envoyé en paramètre GET
  },
);
```

---

## 🎯 Résumé

### **Qu'est-ce que `id_token` ?**
- ✅ Un **JWT signé par Google** qui prouve l'identité de l'utilisateur
- ✅ Contient des **informations utilisateur** (email, nom, prénom, photo, etc.)
- ✅ **Vérifiable** par le backend pour s'assurer qu'il vient bien de Google
- ✅ **Durée de vie limitée** (~1 heure)

### **Pourquoi l'utiliser ?**
- ✅ **Sécurisé** : Signé par Google, vérifiable côté backend
- ✅ **Complet** : Contient toutes les infos nécessaires (email, nom, prénom)
- ✅ **Simple** : Pas besoin d'appeler d'autres APIs Google pour récupérer les infos

### **Dans notre flux :**
1. Flutter récupère l'`id_token` depuis Google Sign-In
2. Flutter envoie l'`id_token` au backend SNAL
3. Backend SNAL vérifie l'`id_token` avec Google
4. Backend SNAL extrait les infos utilisateur (email, nom, prénom)
5. Backend SNAL crée/mise à jour le profil et retourne les identifiants

---

## 📚 Références

- [Google Sign-In Documentation](https://developers.google.com/identity/sign-in/android/start)
- [OAuth 2.0 ID Token](https://oauth.net/2/id-tokens/)
- [JWT (JSON Web Token)](https://jwt.io/)

