# Analyse Facebook iOS - Problème STEP 3

## 🔍 Flux Facebook Sign-In iOS

### Étapes dans login_screen.dart

1. **STEP 1** (ligne 1039-1045) : Lancer la connexion avec le SDK natif Facebook
   ```dart
   final LoginResult result = await FacebookAuth.instance.login(
     permissions: ['public_profile', 'email'],
   );
   ```

2. **STEP 2** (ligne 1055-1056) : Initialiser ApiService
   ```dart
   final apiService = Provider.of<ApiService>(context, listen: false);
   await apiService.initialize();
   ```

3. **STEP 3** (ligne 1058) : Appel API au backend ⚠️ **CASSE ICI**
   ```dart
   final responseBody = await apiService.loginWithFacebookMobile(accessToken.tokenString);
   ```

## 🔍 Analyse du backend SNAL-Project

### Fichier : `SNAL-Project/server/api/auth/facebook-mobile-token.post.ts`

Le backend a plusieurs étapes :

- **STEP 1** (ligne 34) : Token reçu ✅
- **STEP 2** (ligne 48) : Facebook App Credentials Loaded ✅
- **STEP 3** (ligne 54) : Validating Facebook Token ⚠️ **POSSIBLE ERREUR ICI**
- **STEP 4** (ligne 74) : Fetching Facebook User Profile
- **STEP 5** (ligne 83) : Normalizing User Data
- **STEP 6** (ligne 99) : Constructing XML Payload
- **STEP 7** (ligne 120) : Connecting to Database and Executing Stored Procedure

### Format de réponse du backend (lignes 134-141)

```typescript
return {
  status: "success",
  token: profileData.iProfileEncrypted,  // ⚠️ Note: "token" et non "iProfile"
  iBasket: profileData.iBasketProfil,
  nom,
  prenom,
  email,
};
```

**✅ Le backend retourne bien les identifiants**

## 🔍 Problème identifié

### 1. Vérification trop stricte dans Flutter

Le code Flutter (ligne 2400) vérifie :
```dart
if (iProfile != null && iBasket != null && email != null) {
```

**Problème** : Si `email` est `null` (ce qui peut arriver si Facebook ne le fournit pas), la condition échoue.

**Note** : Le backend retourne un email par défaut (`${profile.id}@facebook.com`), donc normalement `email` ne devrait pas être null.

### 2. Possibles causes de l'erreur STEP 3

1. **Erreur dans la validation du token Facebook** (STEP 3 backend) :
   - `FB_APP_ID` ou `FB_APP_SECRET` manquant ou incorrect
   - Token Facebook invalide
   - Erreur de réseau lors de la validation

2. **Erreur dans la récupération du profil** (STEP 4 backend) :
   - Graph API Facebook ne répond pas
   - Permissions manquantes

3. **Erreur dans la procédure stockée** (STEP 7 backend) :
   - `profileData.iProfileEncrypted` ou `profileData.iBasketProfil` sont null
   - Erreur SQL

4. **Format de réponse incorrect** :
   - La réponse n'est pas au format JSON attendu
   - Status code d'erreur (400, 401, 500)

## ✅ Corrections apportées

### 1. Amélioration des logs

Ajout de logs détaillés à chaque étape :
- URL complète de l'endpoint
- Méthode HTTP
- Status code de la réponse
- Toutes les clés de la réponse
- Valeurs des identifiants avec leurs types

### 2. Récupération depuis les cookies

Si les identifiants ne sont pas dans le JSON, le code les récupère depuis les cookies (comme pour Apple Sign-In).

### 3. Validation assouplie

La validation ne vérifie plus si `email` est null (le backend retourne toujours un email par défaut).

## 🔧 Vérifications à faire

### 1. Vérifier les logs backend

Dans les logs du serveur SNAL, vérifier :

```
[Facebook Mobile] === AUTH SUCCESS START ===
STEP 1: Token received
STEP 2: Facebook App Credentials Loaded
STEP 3: Validating Facebook Token  ⚠️ Vérifier si erreur ici
```

### 2. Vérifier les variables d'environnement

Le backend utilise (lignes 41-42) :
```typescript
const FB_APP_ID = config.oauth?.facebook?.clientId;
const FB_APP_SECRET = config.oauth?.facebook?.clientSecret;
```

Vérifier que ces variables sont bien définies :
- `NUXT_OAUTH_FACEBOOK_CLIENT_ID` = `1412145146538940`
- `NUXT_OAUTH_FACEBOOK_CLIENT_SECRET` = votre secret Facebook

### 3. Vérifier les permissions Facebook

Le SDK Flutter demande `['public_profile', 'email']`, mais :
- Certains utilisateurs peuvent avoir refusé l'accès à l'email
- Le backend gère ce cas avec un email par défaut

### 4. Vérifier les logs Flutter

Après la correction, les logs afficheront :
```
📱 === STEP 3: Appel API /api/auth/facebook-mobile-token ===
✅ Réponse facebook-mobile reçue:
   Status Code: 200
   Response Data: {...}
   Toutes les clés: [status, token, iBasket, nom, prenom, email]
🔍 Identifiants récupérés depuis la réponse:
   token/iProfile: ... (type: String)
   iBasket: ... (type: String)
   email: ... (type: String)
```

## 📋 Checklist de débogage

- [ ] Vérifier les logs backend lors d'une connexion Facebook iOS
- [ ] Vérifier que STEP 3 (validation token) réussit
- [ ] Vérifier que `FB_APP_ID` et `FB_APP_SECRET` sont corrects
- [ ] Vérifier que `profileData.iProfileEncrypted` n'est pas null
- [ ] Vérifier que `profileData.iBasketProfil` n'est pas null
- [ ] Vérifier les logs Flutter pour voir la réponse complète
- [ ] Comparer avec Google Sign-In (qui fonctionne) pour voir les différences

## 🔄 Test après correction

1. **Nettoyer et rebuilder** :
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Tester la connexion Facebook iOS** :
   - Cliquer sur "Inloggen met Facebook"
   - Vérifier les logs dans la console
   - Vérifier les logs backend

3. **Vérifier les logs** :
   - Chercher `📱 === STEP 3: Appel API /api/auth/facebook-mobile-token ===`
   - Chercher `✅ Réponse facebook-mobile reçue:`
   - Chercher `🔍 Identifiants récupérés depuis la réponse:`

## 📝 Notes importantes

1. **Le backend retourne `token` (pas `iProfile`)** : Le code Flutter gère déjà ce cas (ligne 2394)
2. **Email peut être null** : Le code ne vérifie plus si email est null (le backend retourne toujours un email)
3. **Récupération depuis cookies** : Si les identifiants ne sont pas dans le JSON, le code les récupère depuis les cookies
