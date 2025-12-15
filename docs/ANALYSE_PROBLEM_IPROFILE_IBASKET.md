# 🔍 Analyse : Pourquoi iProfile et iBasket sont vides après connexion mobile

## ❌ Problème Identifié

Sur mobile, après une connexion email + code réussie, les identifiants `iProfile` et `iBasket` restent vides alors que sur web ils fonctionnent.

## 🔬 Analyse du Flux

### Flux Web - ✅ FONCTIONNE
```
1. Flutter Web → Proxy local (http://localhost:3001)
2. Proxy enrichit la réponse avec newIProfile et newIBasket
3. Flutter reçoit: { status: "OK", newIProfile: "...", newIBasket: "..." }
4. Flutter extrait les identifiants de la réponse
5. ✅ Identifiants sauvegardés
```

### Flux Mobile - ❌ NE FONCTIONNE PAS
```
1. Flutter Mobile → https://jirig.be/api (direct)
2. SNAL retourne: { status: "OK" } (PAS de newIProfile/newIBasket)
3. SNAL met les identifiants dans les COOKIES Set-Cookie
4. Flutter essaie de récupérer depuis les cookies
5. ❌ CookieJar ne récupère pas les nouveaux cookies immédiatement
6. ❌ Identifiants restent vides
```

## 🐛 Causes Racines

### 1️⃣ SNAL ne retourne PAS les identifiants dans la réponse JSON

**Fichier SNAL**: `SNAL-Project/server/api/auth/login-with-code.ts`

```typescript
// Ligne 158
return { status: "OK" }; // ❌ Pas d'iProfile/iBasket !
```

SNAL ne retourne PAS `iProfile` et `iBasket` dans la réponse JSON. Il les met seulement dans les cookies via `setGuestProfile()` (ligne 128-132).

### 2️⃣ Flutter essaie de récupérer les identifiants depuis les cookies trop tôt

**Fichier**: `jirig/lib/services/api_service.dart` (lignes 1222-1281)

```dart
// Ligne 1231
await Future.delayed(Duration(milliseconds: attempt * 1000));
```

Le délai est peut-être insuffisant. CookieJar n'a peut-être pas encore reçu les Set-Cookie de SNAL.

### 3️⃣ CookieJar ne gère peut-être pas correctement les Set-Cookie sur mobile

**Fichier**: `jirig/lib/services/api_service.dart` (lignes 1234-1236)

```dart
final cookies = await _cookieJar!.loadForRequest(apiUrl);
```

Le `CookieManager` de Dio devrait automatiquement sauvegarder les Set-Cookie reçus dans les réponses, mais il faut vérifier que cela fonctionne.

### 4️⃣ Les identifiants par défaut ('0') sont envoyés au lieu de valeurs vides

**Fichier**: `jirig/lib/services/api_service.dart` (lignes 107-114)

**AVANT la correction**:
```dart
String finalIProfile = iProfile; // '0' au lieu de ''
String finalIBasket = iBasket; // '0' au lieu de ''
```

SNAL s'attend à des valeurs vides pour créer de nouveaux identifiants. Si on envoie `'0'`, SNAL peut ignorer la requête ou créer un problème.

**APRÈS la correction**:
```dart
if (iProfile == '0' || iProfile.startsWith('guest_') || iBasket == '0' || iBasket.startsWith('basket_')) {
  finalIProfile = ''; // ✅ Envoyer vide
  finalIBasket = '';  // ✅ Envoyer vide
}
```

## ✅ Solutions Appliquées

### 1. ✅ Envoi de valeurs vides au lieu de '0'

Correction dans `api_service.dart` ligne 117-120 pour envoyer des valeurs vides au serveur SNAL.

### 2. ✅ Intercepteur de réponse pour vérifier les Set-Cookie

Ajout d'un intercepteur (lignes 98-119) pour logger les Set-Cookie reçus et vérifier que `GuestProfile` est bien présent.

### 3. ✅ Correction de la sauvegarde de l'email après connexion

Correction précédente pour sauvegarder `sEmail` après connexion (ligne 1290-1319).

## 🔄 Flux Corrigé Attendu

```
1. Connexion email + code
2. SNAL retourne { status: "OK" } avec Set-Cookie: GuestProfile=...
3. ✅ Intercepteur détecte Set-Cookie
4. ✅ CookieManager sauvegarde le cookie
5. ✅ Délai de 1-5 secondes pour laisser le temps
6. ✅ Récupération depuis CookieJar
7. ✅ Identifiants extraits et sauvegardés
```

## 🧪 Test à Faire

1. Lancer la connexion email + code sur mobile
2. Vérifier les logs :
   - ✅ "📥 Réponse reçue: /auth/login-with-code"
   - ✅ "🍪 Set-Cookie reçus: ..."
   - ✅ "🎯 Cookie GuestProfile trouvé dans Set-Cookie"
   - ✅ "🍪 Cookies récupérés du cookie jar"
   - ✅ "🔍 Identifiants extraits du cookie mobile"

3. Vérifier que les identifiants ne sont plus vides après connexion

## 📝 Comparaison Web vs Mobile

| Aspect | Web (Fonctionne) | Mobile (Problème) |
|--------|-------------------|-------------------|
| **URL** | http://localhost:3001/api | https://jirig.be/api |
| **Proxy** | ✅ Proxy enrichit la réponse | ❌ Pas de proxy |
| **Réponse enrichie** | ✅ { status, newIProfile, newIBasket } | ❌ { status } seulement |
| **Source identifiants** | Réponse JSON enrichie | Cookies Set-Cookie |
| **CookieJar** | Navigateur (automatique) | Dio + PersistCookieJar |
| **Timing** | Immédiat (réponse enrichie) | Délai nécessaire (Set-Cookie) |

## 🎯 Conclusion

Le problème principal est que :
1. SNAL ne retourne pas les identifiants dans la réponse JSON
2. Il les met seulement dans les cookies Set-Cookie
3. CookieJar sur mobile n'a peut-être pas le temps de les sauvegarder avant la récupération
4. Les identifiants par défaut '0' étaient envoyés au lieu de valeurs vides

**Solutions appliquées** :
- ✅ Envoi de valeurs vides au lieu de '0'
- ✅ Intercepteur pour vérifier les Set-Cookie reçus
- ✅ Sauvegarde de l'email après connexion

**Résultat attendu** : Les identifiants devraient maintenant être correctement récupérés depuis les cookies sur mobile.
