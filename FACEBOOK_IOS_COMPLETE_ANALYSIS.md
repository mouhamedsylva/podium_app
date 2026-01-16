# Analyse complète Facebook iOS - Alignement Flutter vs Backend

## 📊 Comparaison Flutter vs Backend SNAL-Project

### Flux Flutter (login_screen.dart)

```
STEP 1: FacebookAuth.instance.login()
  ↓ (obtient accessToken)
STEP 2: apiService.initialize()
  ↓ (initialise Dio)
STEP 3: apiService.loginWithFacebookMobile(accessToken.tokenString) ⚠️ CASSE ICI
  ↓ (appel POST /auth/facebook-mobile-token)
STEP 4: Traitement de la réponse
STEP 5: Sauvegarde du profil
```

### Flux Backend SNAL (facebook-mobile-token.post.ts)

```
STEP 1: Token received
STEP 2: Facebook App Credentials Loaded
STEP 3: Validating Facebook Token (appel Graph API)
STEP 4: Fetching Facebook User Profile (appel Graph API)
STEP 5: Normalizing User Data
STEP 6: Constructing XML Payload
STEP 7: Connecting to Database and Executing Stored Procedure
  ↓ (retourne JSON avec status, token, iBasket, nom, prenom, email)
```

## ✅ Alignement Flutter ↔ Backend

### 1. Endpoint appelé

**Flutter** (ligne 2383) :
```dart
await _dio!.post('/auth/facebook-mobile-token', data: { 'access_token': accessToken });
```

**Backend** (ligne 25-29) :
```typescript
export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const token = body.access_token;
```

✅ **Aligné** : Le backend attend bien `access_token` dans le body POST.

### 2. Format de réponse

**Backend retourne** (lignes 134-141) :
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

**Flutter attend** (ligne 2401) :
```dart
final iProfile = data['token']?.toString() ?? data['iProfile']?.toString();
final iBasket = data['iBasket']?.toString();
final email = data['email']?.toString();
```

✅ **Aligné** : Le code Flutter cherche bien `token` (et fallback `iProfile`).

### 3. Validation des identifiants

**Flutter vérifie** (ligne 2434) :
```dart
if (iProfile != null && iBasket != null && iProfile.isNotEmpty && iBasket.isNotEmpty) {
```

✅ **Corrigé** : Ne vérifie plus si `email != null` (le backend retourne toujours un email).

## 🔍 Points de défaillance possibles (STEP 3 Backend)

### STEP 3: Validating Facebook Token (ligne 54-69)

Le backend valide le token en appelant Facebook Graph API :

```typescript
const debugUrl = `https://graph.facebook.com/debug_token` +
  `?input_token=${token}` +
  `&access_token=${FB_APP_TOKEN}`;

const debugResponse = await $fetch<FacebookDebugTokenResponse>(debugUrl);

if (!debugResponse.data.is_valid || debugResponse.data.app_id !== FB_APP_ID) {
  throw createError({ statusCode: 401, message: "Invalid Facebook token" });
}
```

**Causes possibles d'échec** :

1. **`FB_APP_TOKEN` invalide** :
   - `FB_APP_ID` manquant ou incorrect
   - `FB_APP_SECRET` manquant ou incorrect
   - Format : `${FB_APP_ID}|${FB_APP_SECRET}` doit être correct

2. **Token Facebook invalide** :
   - Token expiré
   - Token révoqué
   - Token d'une autre app Facebook

3. **Erreur réseau** :
   - Appel à `graph.facebook.com` échoue
   - Timeout
   - CORS (mais côté serveur, normalement pas de CORS)

4. **App ID mismatch** :
   - Le token appartient à une autre app Facebook
   - `debugResponse.data.app_id !== FB_APP_ID`

## ✅ Corrections apportées dans Flutter

### 1. Logs détaillés ajoutés

```dart
print('📱 === STEP 3: Appel API /api/auth/facebook-mobile-token ===');
print('📡 URL complète: ${ApiConfig.baseUrl}/auth/facebook-mobile-token');
print('📡 Méthode: POST');
print('📡 Body: { access_token: ... }');
print('✅ Réponse facebook-mobile reçue:');
print('   Status Code: ${response.statusCode}');
print('   Response Data: ${response.data}');
print('   Toutes les clés: ${(response.data as Map?)?.keys.toList()}');
```

### 2. Récupération depuis les cookies

Si les identifiants ne sont pas dans le JSON, le code les récupère depuis les cookies :

```dart
final setCookieHeaders = response.headers['set-cookie'];
// Extraction de iProfile et iBasket depuis les cookies
```

### 3. Validation assouplie

```dart
// Avant : if (iProfile != null && iBasket != null && email != null)
// Après : if (iProfile != null && iBasket != null && iProfile.isNotEmpty && iBasket.isNotEmpty)
```

## 🔧 Vérifications à faire

### 1. Backend - Variables d'environnement

Vérifier dans `nuxt.config.ts` ou `.env` que :
```
NUXT_OAUTH_FACEBOOK_CLIENT_ID=1412145146538940
NUXT_OAUTH_FACEBOOK_CLIENT_SECRET=<votre-secret>
```

Le backend utilise (lignes 41-42) :
```typescript
const FB_APP_ID = config.oauth?.facebook?.clientId;
const FB_APP_SECRET = config.oauth?.facebook?.clientSecret;
```

### 2. Backend - Logs STEP 3

Vérifier dans les logs backend :
```
STEP 3: Validating Facebook Token
Facebook Debug Token Response: { data: { is_valid: true, app_id: "...", user_id: "..." } }
```

Si `is_valid: false`, le token est invalide.

### 3. Backend - Logs STEP 4

Vérifier :
```
STEP 4: Fetching Facebook User Profile
Facebook Profile Response: { id: "...", name: "...", email: "..." }
```

Si erreur ici, problème avec les permissions Facebook.

### 4. Backend - Logs STEP 7

Vérifier :
```
Facebook Mobile profileData: { iProfileEncrypted: "...", iBasketProfil: "...", ... }
```

Si `iProfileEncrypted` ou `iBasketProfil` sont null, problème avec la procédure stockée.

### 5. Flutter - Logs STEP 3

Après correction, vérifier dans les logs Flutter :
```
📱 === STEP 3: Appel API /api/auth/facebook-mobile-token ===
✅ Réponse facebook-mobile reçue:
   Status Code: 200 (ou 401, 500, etc.)
   Response Data: {...}
```

Si Status Code != 200, regarder le message d'erreur.

## 📋 Checklist de débogage

### Backend
- [ ] `NUXT_OAUTH_FACEBOOK_CLIENT_ID` = `1412145146538940`
- [ ] `NUXT_OAUTH_FACEBOOK_CLIENT_SECRET` est défini et correct
- [ ] STEP 3 (validation token) réussit dans les logs
- [ ] STEP 4 (récupération profil) réussit dans les logs
- [ ] STEP 7 (procédure stockée) retourne `iProfileEncrypted` et `iBasketProfil`

### Flutter iOS
- [ ] Configuration `Info.plist` complète (FacebookAppID, FacebookClientToken, URL scheme)
- [ ] SDK Facebook natif fonctionne (STEP 1 réussit)
- [ ] ApiService initialisé (STEP 2 réussit)
- [ ] Appel API réussit (STEP 3 - vérifier Status Code)
- [ ] Réponse contient `status: "success"`
- [ ] Réponse contient `token` ou `iProfile`
- [ ] Réponse contient `iBasket`
- [ ] Réponse contient `email`

## 🐛 Scénarios d'erreur courants

### Erreur 401 - Invalid Facebook token

**Cause** : STEP 3 backend échoue (token invalide ou App ID mismatch)

**Solution** :
1. Vérifier que le token Facebook est valide
2. Vérifier que `FB_APP_ID` correspond à l'app qui a généré le token
3. Vérifier que `FB_APP_SECRET` est correct

### Erreur 500 - Facebook mobile authentication failed

**Cause** : Erreur dans une des étapes backend (STEP 4, 5, 6, ou 7)

**Solution** :
1. Vérifier les logs backend pour voir à quelle étape ça casse
2. Vérifier que la procédure stockée retourne bien les identifiants
3. Vérifier les logs SQL Server

### Identifiants manquants dans la réponse

**Cause** : `profileData.iProfileEncrypted` ou `profileData.iBasketProfil` sont null

**Solution** :
1. Vérifier les logs backend : `Facebook Mobile profileData: {...}`
2. Vérifier que la procédure stockée retourne bien ces champs
3. Vérifier que le code récupère depuis les cookies si disponibles

## ✅ Résumé de l'alignement

| Élément | Flutter | Backend | Statut |
|---------|---------|---------|--------|
| Endpoint | `/auth/facebook-mobile-token` | `/auth/facebook-mobile-token` | ✅ Aligné |
| Méthode | POST | POST | ✅ Aligné |
| Body | `{ access_token: "..." }` | Attend `body.access_token` | ✅ Aligné |
| Réponse status | `"success"` | `status: "success"` | ✅ Aligné |
| Réponse iProfile | `data['token']` | `token: profileData.iProfileEncrypted` | ✅ Aligné |
| Réponse iBasket | `data['iBasket']` | `iBasket: profileData.iBasketProfil` | ✅ Aligné |
| Réponse email | `data['email']` | `email` | ✅ Aligné |

**✅ Le code Flutter et le backend sont bien alignés**

## 🎯 Action immédiate

**Tester avec les nouveaux logs** pour identifier exactement où ça casse :

1. Lancer une connexion Facebook iOS
2. Vérifier les logs Flutter (chercher `📱 === STEP 3`)
3. Vérifier les logs backend (chercher `STEP 3: Validating Facebook Token`)
4. Comparer avec les logs Google Sign-In (qui fonctionne) pour voir les différences
