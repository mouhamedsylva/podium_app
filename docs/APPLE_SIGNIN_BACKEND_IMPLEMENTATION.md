# Implémentation Backend - Sign in with Apple (SNAL-Project)

## 📋 Vue d'ensemble

Sign in with Apple est différent de Google et Facebook car :
- ✅ Apple utilise des **JWT (JSON Web Tokens)** pour l'authentification
- ✅ Apple peut **masquer l'email** de l'utilisateur (relay email)
- ✅ Il faut **générer un client_secret JWT** avec une clé privée `.p8`
- ✅ Il n'y a **pas de handler natif** dans `nuxt-auth-utils` pour Apple
- ✅ Il faut **valider les tokens** avec les clés publiques d'Apple

---

## 🔧 1. Configuration Apple Developer

### Étape 1 : Créer un Service ID

1. Connectez-vous à [Apple Developer](https://developer.apple.com/)
2. Allez dans **Certificates, Identifiers & Profiles**
3. Sélectionnez **Identifiers** → Cliquez sur **"+"**
4. Choisissez **Services IDs** → **Continue**
5. Remplissez :
   - **Description** : `Jirig Sign in with Apple`
   - **Identifier** : `com.jirig.app` (ou votre identifiant)
6. Cochez **Sign in with Apple** → **Configure**
7. Configurez :
   - **Primary App ID** : Sélectionnez votre App ID
   - **Website URLs** :
     - **Domains** : `jirig.be`, `jirig.com`
     - **Return URLs** :
       - `https://jirig.be/api/auth/apple`
       - `https://jirig.com/api/auth/apple`
       - `https://localhost:3000/api/auth/apple` (pour dev)
8. **Save** → **Continue** → **Register**

### Étape 2 : Créer une Clé Privée

1. Dans **Keys** → Cliquez sur **"+"**
2. Donnez un nom : `Jirig Apple Sign In Key`
3. Cochez **Sign in with Apple**
4. **Configure** → Sélectionnez votre **Primary App ID**
5. **Save** → **Continue** → **Register**
6. **⚠️ IMPORTANT** : Téléchargez la clé `.p8` (vous ne pourrez plus la télécharger après)
7. Notez :
   - **Key ID** (ex: `ABC123DEF4`)
   - **Team ID** (ex: `XYZ987ABC6`)

### Étape 3 : Variables d'environnement

Ajoutez dans votre `.env` :

```env
# Apple Sign In Configuration
NUXT_OAUTH_APPLE_CLIENT_ID=com.jirig.app
NUXT_OAUTH_APPLE_TEAM_ID=XYZ987ABC6
NUXT_OAUTH_APPLE_KEY_ID=ABC123DEF4
NUXT_OAUTH_APPLE_PRIVATE_KEY_PATH=./keys/AuthKey_ABC123DEF4.p8
# OU directement la clé en base64 (recommandé pour production)
NUXT_OAUTH_APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...\n-----END PRIVATE KEY-----"
```

---

## 📦 2. Installation des dépendances

### Package nécessaire

Apple Sign In nécessite un package pour générer le `client_secret` JWT :

```bash
cd SNAL-Project
pnpm add jsonwebtoken
# jsonwebtoken est déjà installé dans votre projet ✅
```

Si vous voulez utiliser un package dédié (optionnel) :

```bash
pnpm add apple-signin-auth
# OU
pnpm add @apple/app-store-server-library
```

---

## 🛠️ 3. Création de l'endpoint API

### Fichier : `SNAL-Project/server/api/auth/apple.post.ts`

Créer un endpoint POST pour recevoir le code d'autorisation depuis l'application mobile/web :

```typescript
import { defineEventHandler, readBody, createError, sendRedirect, getCookie, setCookie } from "h3";
import { connectToDatabase } from "../../db/index";
import sql from "mssql";
import { useAppCookies } from "~/composables/useAppCookies";
import jwt from "jsonwebtoken";
import crypto from "crypto";

/**
 * Génère le client_secret JWT pour Apple
 */
function generateAppleClientSecret(): string {
  const config = useRuntimeConfig();
  
  const clientId = config.oauth.apple.clientId;
  const teamId = config.oauth.apple.teamId;
  const keyId = config.oauth.apple.keyId;
  
  // Récupérer la clé privée
  let privateKey: string;
  if (config.oauth.apple.privateKey) {
    privateKey = config.oauth.apple.privateKey;
  } else if (config.oauth.apple.privateKeyPath) {
    const fs = require("fs");
    privateKey = fs.readFileSync(config.oauth.apple.privateKeyPath, "utf8");
  } else {
    throw new Error("Apple private key not configured");
  }

  // Créer le JWT pour client_secret
  const now = Math.floor(Date.now() / 1000);
  const token = jwt.sign(
    {
      iss: teamId,
      iat: now,
      exp: now + 3600 * 24 * 180, // 6 mois
      aud: "https://appleid.apple.com",
      sub: clientId,
    },
    privateKey,
    {
      algorithm: "ES256",
      keyid: keyId,
    }
  );

  return token;
}

/**
 * Échange le code d'autorisation contre un ID token
 */
async function exchangeCodeForToken(
  code: string,
  clientSecret: string
): Promise<any> {
  const config = useRuntimeConfig();
  const clientId = config.oauth.apple.clientId;
  
  const host = process.env.NODE_ENV === "development" 
    ? "localhost:3000" 
    : "jirig.be";
  
  const redirectUri = `https://${host}/api/auth/apple`;

  const response = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: code,
      grant_type: "authorization_code",
      redirect_uri: redirectUri,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Apple token exchange failed: ${errorText}`);
  }

  return await response.json();
}

/**
 * Valide et décode l'ID token d'Apple
 */
async function validateAppleIdToken(idToken: string): Promise<any> {
  // Récupérer les clés publiques d'Apple
  const keysResponse = await fetch("https://appleid.apple.com/auth/keys");
  const keys = await keysResponse.json();

  // Décoder le header du JWT pour obtenir le kid
  const [headerB64] = idToken.split(".");
  const header = JSON.parse(
    Buffer.from(headerB64, "base64").toString("utf8")
  );

  // Trouver la clé correspondante
  const key = keys.keys.find((k: any) => k.kid === header.kid);
  if (!key) {
    throw new Error("Apple public key not found");
  }

  // Convertir la clé JWK en format PEM
  const publicKey = crypto.createPublicKey({
    key: {
      kty: key.kty,
      kid: key.kid,
      use: key.use,
      alg: key.alg,
      n: key.n,
      e: key.e,
    },
    format: "jwk",
  });

  // Vérifier et décoder le token
  const decoded = jwt.verify(idToken, publicKey, {
    algorithms: ["RS256"],
    audience: config.oauth.apple.clientId,
    issuer: "https://appleid.apple.com",
  });

  return decoded as any;
}

export default defineEventHandler(async (event) => {
  console.log("🍎 [Apple Auth] === AUTHENTICATION START ===");

  try {
    const body = await readBody(event);
    const { code, id_token, user } = body;

    // Si on reçoit directement un id_token (depuis mobile)
    let appleUser: any;
    
    if (id_token) {
      // Valider le token directement
      appleUser = await validateAppleIdToken(id_token);
    } else if (code) {
      // Échanger le code contre un token
      const clientSecret = generateAppleClientSecret();
      const tokenResponse = await exchangeCodeForToken(code, clientSecret);
      appleUser = await validateAppleIdToken(tokenResponse.id_token);
    } else {
      throw createError({
        statusCode: 400,
        message: "Missing code or id_token",
      });
    }

    console.log("🍎 Apple user decoded:", appleUser);

    // Gestion des domaines
    const host = event.node.req.headers.host || "";
    let currentDomain = "";
    let currentHost = "";
    let redirectUri = "";

    if (host.includes("localhost")) {
      currentDomain = "localhost";
      currentHost = "localhost:3000";
      redirectUri = "https://localhost:3000/";
    } else if (host.includes("jirig.be")) {
      currentDomain = ".jirig.be";
      currentHost = "jirig.be";
      redirectUri = "https://jirig.be/";
    } else {
      currentDomain = ".jirig.com";
      currentHost = "jirig.com";
      redirectUri = "https://jirig.com/";
    }

    console.log(`🌐 Domain: ${currentDomain}, Host: ${currentHost}`);

    // Récupérer le profil invité
    const { getGuestProfile, setGuestProfile, setiBasketFromInitialization } =
      useAppCookies(event);
    const guestProfile = getGuestProfile();

    let sPaysListe = guestProfile.sPaysFav || "";
    let sPaysLangue = guestProfile.sPaysLangue || "";
    let sTypeAccount = "EMAIL";

    // Extraire les données d'Apple
    // ⚠️ Apple peut masquer l'email, utiliser le relay email si nécessaire
    const email = appleUser.email || appleUser.sub + "@privaterelay.appleid.com";
    const sProviderId = appleUser.sub || "";
    const sProvider = "apple";

    // Gérer les noms (peuvent être absents)
    // Si user est fourni dans le body (première connexion uniquement)
    let nom = "";
    let prenom = "";

    if (user && typeof user === "object") {
      // user est fourni uniquement lors de la première connexion
      nom = user.name?.familyName || "";
      prenom = user.name?.givenName || "";
    }

    // Si pas de nom, utiliser des valeurs par défaut
    if (!nom && !prenom) {
      prenom = "Utilisateur";
      nom = "Apple";
    }

    // Construire le XML pour la stored procedure
    const xXml = `
      <root>
        <email>${email}</email>
        <sProviderId>${sProviderId}</sProviderId>
        <sProvider>${sProvider}</sProvider>
        <nom>${nom}</nom>
        <prenom>${prenom}</prenom>
        <sTypeAccount>${sTypeAccount}</sTypeAccount>
        <iPaysOrigine>${sPaysLangue}</iPaysOrigine>
        <sLangue>${sPaysLangue}</sLangue>
        <sPaysListe>${sPaysListe}</sPaysListe>
        <sPaysLangue>${sPaysLangue}</sPaysLangue>
      </root>
    `.trim();

    console.log("🍎 XML payload:", xXml);

    // Appeler la stored procedure (même que Google/Facebook)
    const pool = await connectToDatabase();
    const newProfile = await pool
      .request()
      .input("xXml", sql.Xml, xXml)
      .execute("dbo.proc_user_signup_4All_user_v2");

    const profileData = newProfile.recordset[0];
    console.log("🍎 Profile data:", profileData);

    if (profileData) {
      setGuestProfile({
        iProfile: profileData.iProfileEncrypted,
        iBasket: profileData.iBasketProfil,
        sPaysLangue: profileData.sPaysLangue,
        sPaysFav: profileData.sPaysFav,
      });

      setiBasketFromInitialization(profileData.iBasketProfil);
    }

    // Créer la session utilisateur
    await setUserSession(event, {
      user: {
        iProfile: profileData.iProfile,
        sNom: profileData.sNom,
        sPrenom: profileData.sPrenom,
        sEmail: profileData.sEmail,
        sPhoto: profileData.sPhoto,
        sRue: profileData.sRue,
        sZip: profileData.sZip,
        sCity: profileData.sCity,
        iPays: profileData.iPays,
        sTel: profileData.sTel,
        sLangue: profileData.sLangue,
        sPaysFav: profileData.sPaysFav,
        sTypeAccount: profileData.sTypeAccount,
        sPaysLangue: profileData.sPaysLangue,
      },
      loggedInAt: Date.now(),
      loggedIn: true,
    });

    const checkSession = await getUserSession(event);
    console.log("✅ Session set:", !!checkSession.user);

    // Nettoyer le cookie origin_domain
    setCookie(event, "origin_domain", "", {
      maxAge: 0,
      path: "/",
      domain: currentDomain !== "localhost" ? currentDomain : undefined,
      httpOnly: false,
      secure: currentDomain !== "localhost",
      sameSite: "lax",
    });

    console.log("🔄 Redirecting to:", redirectUri);
    console.log("✅ [Apple Auth] === AUTHENTICATION COMPLETE ===\n");

    const redirectWishlist = redirectUri + `wishlist/${profileData.iBasketProfil}`;
    console.log("🔄 Redirecting to wishlist:", redirectWishlist);

    return sendRedirect(event, redirectWishlist);
  } catch (error: any) {
    console.error("❌ [Apple Auth] Error:", error);
    
    const host = event.node.req.headers.host || "";
    const currentHost = host.includes("jirig.be") ? "jirig.be" : "jirig.com";
    const originDomain = getCookie(event, "origin_domain") || currentHost;

    setCookie(event, "origin_domain", "", {
      maxAge: 0,
      path: "/",
      domain: host.includes("localhost") ? undefined : `.${currentHost}`,
      httpOnly: false,
      secure: !host.includes("localhost"),
      sameSite: "lax",
    });

    return sendRedirect(
      event,
      `https://${originDomain}/connexion?error=apple_oauth_failed`
    );
  }
});
```

---

## ⚙️ 4. Configuration Nuxt

### Mise à jour de `nuxt.config.ts`

Ajoutez la configuration Apple dans la section `oauth` :

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  // ... autres configs
  
  runtimeConfig: {
    // ... autres configs
    
    oauth: {
      google: {
        // ... config existante
      },
      facebook: {
        // ... config existante
      },
      apple: {
        clientId: process.env.NUXT_OAUTH_APPLE_CLIENT_ID,
        teamId: process.env.NUXT_OAUTH_APPLE_TEAM_ID,
        keyId: process.env.NUXT_OAUTH_APPLE_KEY_ID,
        privateKey: process.env.NUXT_OAUTH_APPLE_PRIVATE_KEY,
        privateKeyPath: process.env.NUXT_OAUTH_APPLE_PRIVATE_KEY_PATH,
      },
    },
  },
});
```

---

## 📱 5. Intégration côté Mobile (podium_app)

### Option 1 : Envoyer directement l'ID Token

Dans votre application Flutter, après l'authentification Apple :

```dart
// Après Sign in with Apple
final idToken = appleAuthResult.credential?.idToken;

if (idToken != null) {
  final response = await apiService.dio.post(
    '/auth/apple',
    data: {
      'id_token': idToken,
      'user': {
        'name': {
          'givenName': appleAuthResult.user?.givenName,
          'familyName': appleAuthResult.user?.familyName,
        }
      }
    },
  );
  
  // Gérer la redirection ou la session
}
```

### Option 2 : Envoyer le code d'autorisation

```dart
// Après Sign in with Apple
final authorizationCode = appleAuthResult.credential?.authorizationCode;

if (authorizationCode != null) {
  final response = await apiService.dio.post(
    '/auth/apple',
    data: {
      'code': authorizationCode,
    },
  );
  
  // Gérer la redirection ou la session
}
```

---

## 🔐 6. Gestion des emails masqués (Relay Email)

Apple peut masquer l'email de l'utilisateur et utiliser un relay email comme :
`xxxxx@privaterelay.appleid.com`

### Solution 1 : Accepter les relay emails

La stored procedure `proc_user_signup_4All_user_v2` doit gérer les emails en format relay.

### Solution 2 : Demander l'email explicitement

Si l'utilisateur utilise un relay email, vous pouvez :
1. Détecter le relay email dans le backend
2. Demander à l'utilisateur de fournir son email réel
3. Mettre à jour le profil avec l'email réel

Exemple de détection :

```typescript
const isRelayEmail = email.includes("@privaterelay.appleid.com");

if (isRelayEmail) {
  // Optionnel : Demander l'email réel à l'utilisateur
  // ou utiliser le relay email comme identifiant unique
}
```

---

## 🧪 7. Tests

### Test 1 : Vérifier la génération du client_secret

```typescript
// Test unitaire
const clientSecret = generateAppleClientSecret();
console.log("Client Secret:", clientSecret);
// Doit être un JWT valide
```

### Test 2 : Tester l'endpoint avec un ID token

```bash
curl -X POST http://localhost:3000/api/auth/apple \
  -H "Content-Type: application/json" \
  -d '{
    "id_token": "eyJraWQiOiJlWGF1bm1IM1..."
  }'
```

### Test 3 : Tester avec un code d'autorisation

```bash
curl -X POST http://localhost:3000/api/auth/apple \
  -H "Content-Type: application/json" \
  -d '{
    "code": "c1234567890abcdef..."
  }'
```

---

## 📝 8. Différences avec Google/Facebook

| Aspect | Google/Facebook | Apple |
|--------|----------------|-------|
| **Handler** | `defineOAuthGoogleEventHandler` | Endpoint POST personnalisé |
| **Token** | Access token OAuth2 | ID Token JWT |
| **Validation** | Appel API au provider | Validation JWT avec clés publiques |
| **Client Secret** | String statique | JWT généré dynamiquement |
| **Email** | Toujours fourni | Peut être masqué (relay) |
| **Nom** | Toujours fourni | Fourni uniquement à la première connexion |
| **Photo** | URL de l'image | Non fournie par Apple |

---

## ✅ 9. Checklist d'implémentation

- [ ] Créer le Service ID sur Apple Developer
- [ ] Créer et télécharger la clé privée `.p8`
- [ ] Configurer les variables d'environnement
- [ ] Créer l'endpoint `/api/auth/apple.post.ts`
- [ ] Implémenter `generateAppleClientSecret()`
- [ ] Implémenter `validateAppleIdToken()`
- [ ] Implémenter `exchangeCodeForToken()`
- [ ] Mettre à jour `nuxt.config.ts`
- [ ] Tester avec un ID token
- [ ] Tester avec un code d'autorisation
- [ ] Gérer les emails relay
- [ ] Gérer les noms manquants
- [ ] Ajouter le bouton Apple dans l'UI
- [ ] Tester sur mobile (iOS)
- [ ] Tester sur web
- [ ] Documenter les erreurs possibles

---

## 🚨 10. Erreurs courantes et solutions

### Erreur : "Invalid client_secret"

**Cause** : Le JWT client_secret est mal formé ou expiré.

**Solution** : Vérifier que :
- La clé privée est correctement formatée
- Le Team ID et Key ID sont corrects
- L'algorithme est `ES256`

### Erreur : "Invalid grant"

**Cause** : Le code d'autorisation a déjà été utilisé ou est expiré.

**Solution** : Les codes d'autorisation ne peuvent être utilisés qu'une seule fois et expirent rapidement.

### Erreur : "Email not provided"

**Cause** : L'utilisateur a choisi de masquer son email.

**Solution** : Utiliser le relay email ou demander l'email explicitement.

### Erreur : "Public key not found"

**Cause** : Le `kid` dans le header JWT ne correspond à aucune clé publique d'Apple.

**Solution** : Vérifier que vous récupérez bien les clés depuis `https://appleid.apple.com/auth/keys`.

---

## 📚 11. Ressources

- [Documentation officielle Apple](https://developer.apple.com/documentation/sign_in_with_apple)
- [Guide Apple Sign In](https://developer.apple.com/sign-in-with-apple/get-started/)
- [Validation des tokens Apple](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api/verifying_a_user)
- [Génération du client_secret](https://developer.apple.com/documentation/sign_in_with_apple/generate_and_validate_tokens)

---

## 🔗 12. Intégration avec la stored procedure existante

La stored procedure `proc_user_signup_4All_user_v2` est déjà utilisée pour Google et Facebook. Elle fonctionne aussi pour Apple car :

- ✅ Elle accepte `sProvider` = `"apple"`
- ✅ Elle accepte `sProviderId` (le `sub` d'Apple)
- ✅ Elle gère les emails (y compris les relay emails)
- ✅ Elle crée ou met à jour le profil utilisateur

**Aucune modification de la stored procedure n'est nécessaire** si elle accepte déjà les paramètres :
- `email`
- `sProvider`
- `sProviderId`
- `nom`
- `prenom`

---

## 💡 13. Améliorations futures

1. **Cache des clés publiques Apple** : Mettre en cache les clés publiques pour éviter de les récupérer à chaque requête
2. **Refresh tokens** : Implémenter le renouvellement automatique des tokens
3. **Revocation** : Gérer la révocation des tokens Apple
4. **Webhooks** : Écouter les événements de révocation d'Apple
5. **Migration email** : Permettre aux utilisateurs de migrer d'un relay email vers un email réel

---

## 📝 Notes importantes

1. **Sécurité** :
   - ⚠️ Ne jamais exposer la clé privée `.p8` dans le code source
   - ⚠️ Stocker la clé privée de manière sécurisée (variables d'environnement, secrets manager)
   - ⚠️ Valider toujours les tokens avant de créer une session

2. **Performance** :
   - Les clés publiques d'Apple peuvent être mises en cache (elles changent rarement)
   - Le client_secret JWT peut être mis en cache (valide 6 mois)

3. **Compatibilité** :
   - Sign in with Apple fonctionne sur iOS, macOS, et web
   - Sur Android, utilisez le flux web standard

---

## 🎯 Résumé

L'implémentation de Sign in with Apple nécessite :
1. ✅ Configuration Apple Developer (Service ID + Clé privée)
2. ✅ Endpoint POST personnalisé (pas de handler natif)
3. ✅ Génération d'un client_secret JWT
4. ✅ Validation des ID tokens avec les clés publiques Apple
5. ✅ Gestion des emails masqués et noms optionnels
6. ✅ Réutilisation de la stored procedure existante

Le flux est similaire à Google/Facebook mais avec des spécificités Apple (JWT, validation, relay emails).

