# Connexion Google & Facebook – Implémentation côté SNAL-Project

Ce guide documente **pas à pas** la configuration d’OAuth Google et Facebook dans **SNAL-Project** afin que, après authentification, l’utilisateur soit renvoyé vers l’application Flutter :

- web en développement (`localhost` ou proxy),
- web en production (SPA Flutter hébergée),
- mobile (deep links `thico://` après publication sur les stores).

Chaque section précise **où intervenir**, **quoi modifier** et **pour quelle raison**.

---

## 1. Fichiers SNAL à modifier

| Fichier | Description | Action |
| ------- | ----------- | ------ |
| `server/api/auth/google.get.ts` | Construction de l’URL Google et redirection initiale | Lire `platformId`, stocker un cookie temporaire, générer `state`, rediriger vers Google |
| `server/api/auth/google-callback.get.ts` | Callback Google | Vérifier `state`, créer la session, rediriger vers Flutter selon `platformId` |
| `server/api/auth/facebook.get.ts` | Construction de l’URL Facebook | Même logique que Google |
| `server/api/auth/facebook-callback.get.ts` | Callback Facebook | Même logique que Google |

---

## 2. Variables d’environnement à créer

Définir les URL Flutter utilisées par SNAL selon l’environnement :

```
# Flutter web en développement direct (serveur Dart)
FLUTTER_CALLBACK_WEB_DEV=http://localhost:3000/#/home
# Flutter web via proxy Express (optionnel)
FLUTTER_CALLBACK_WEB_PROXY=http://localhost:3001/#/home
# Flutter mobile debug (deep link)
FLUTTER_CALLBACK_MOBILE_DEV=thico://auth/success

# Flutter web production (SPA hébergée)
FLUTTER_CALLBACK_WEB_PROD=https://app.jirig.be/#/home
# Flutter mobile production (app stores)
FLUTTER_CALLBACK_MOBILE_PROD=thico://auth/success
```

> Ajuster la fin de l’URL (`#/home`, `#/wishlist`, …) selon l’écran de destination souhaité.

Ces variables doivent être disponibles à l’exécution (fichier `.env`, variables Render, GitLab CI/CD, etc.).

---

## 3. Autoriser les callbacks SNAL chez Google & Facebook

### 3.1 Google Cloud Console

1. Ouvrir **APIs & Services → Credentials** → votre client OAuth.
2. Dans **Authorized redirect URIs**, ajouter **chaque URL SNAL** :
   ```
   https://jirig.be/api/auth/google-callback
   https://staging.jirig.be/api/auth/google-callback
   https://<domaine-prod>/api/auth/google-callback
   ```
3. Pour un test local, utiliser un tunnel HTTPS (`https://<ngrok>.ngrok.io/api/auth/google-callback`) : Google refuse généralement `http://localhost` en redirect.
4. Vérifier que `google.get.ts` utilise **exactement** la même URL (`redirect_uri`) pour construire l’URL d’autorisation.

### 3.2 Meta (Facebook) Developer Console

1. Dans **Settings → Basic → Valid OAuth Redirect URIs**, enregistrer :
   ```
   https://jirig.be/api/auth/facebook-callback
   https://staging.jirig.be/api/auth/facebook-callback
   https://<domaine-prod>/api/auth/facebook-callback
   ```
2. Vérifier que `facebook.get.ts` passe bien cette URL dans `redirect_uri`.

> Seule l’URL du callback SNAL doit être déclarée chez Google/Facebook. La redirection finale vers Flutter se fera ensuite côté SNAL.

---

## 4. Stocker `platformId` avant de lancer l’OAuth

Dans `google.get.ts` (même logique pour `facebook.get.ts`) :

```ts
export default defineEventHandler(async (event) => {
  const query = getQuery(event);
  const platformId = query.platformId as string | undefined;

  if (platformId) {
    setCookie(event, 'flutter_platform', platformId, {
      path: '/',
      httpOnly: false,
      maxAge: 600,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
    });
  }

  const authUrl = buildGoogleAuthUrl({
    redirectUri: getRuntimeConfig().googleRedirectUri,
    state: createEncryptedState({ platformId }),
  });

  return sendRedirect(event, authUrl);
});
```

**Pourquoi ?**

- `platformId` est fourni par Flutter (via le proxy) pour indiquer quelle URL cible utiliser (ex. `web-dev`, `web-prod`, `android`, `ios`).
- Le cookie `flutter_platform` est temporaire et lisible côté serveur.
- Le paramètre `state` transporte `platformId` afin d’éviter toute falsification (voir §7 pour la sécurité).

---

## 5. Rediriger le callback vers Flutter sur base du `platformId`

Dans `google-callback.get.ts` (adapter les fonctions pour Facebook) :

```ts
export default defineEventHandler(async (event) => {
  const query = getQuery(event);
  const flutterPlatformCookie = getCookie(event, 'flutter_platform');

  // 1. Contrôler l'intégrité de la requête
  verifyState(query.state as string, {
    platformId: flutterPlatformCookie,
  });

  // 2. Échanger le code OAuth contre un access token + profil
  const tokens = await exchangeGoogleCode(query.code as string);
  const profile = await fetchGoogleProfile(tokens);

  // 3. Créer la session SNAL (JWT ou cookie)
  const session = await createSnalSession({
    provider: 'google',
    profile,
    tokens,
  });

  // 4. Déterminer l'URL Flutter finale
  const platformId = flutterPlatformCookie || (query.platformId as string | undefined) || '';

  const predefinedTargets: Record<string, string | undefined> = {
    'web-dev': process.env.FLUTTER_CALLBACK_WEB_DEV,
    'web-proxy': process.env.FLUTTER_CALLBACK_WEB_PROXY,
    'web-prod': process.env.FLUTTER_CALLBACK_WEB_PROD,
    'android-dev': process.env.FLUTTER_CALLBACK_MOBILE_DEV,
    'ios-dev': process.env.FLUTTER_CALLBACK_MOBILE_DEV,
    'android-prod': process.env.FLUTTER_CALLBACK_MOBILE_PROD,
    'ios-prod': process.env.FLUTTER_CALLBACK_MOBILE_PROD,
  };

  const fallback =
    predefinedTargets[platformId] ??
    (process.env.NODE_ENV === 'production'
      ? process.env.FLUTTER_CALLBACK_WEB_PROD
      : process.env.FLUTTER_CALLBACK_WEB_DEV);

  const target = fallback || 'https://app.jirig.be/#/home';

  const redirectUrl = new URL(target);
  redirectUrl.searchParams.set('oauth', 'success');
  redirectUrl.searchParams.set('provider', 'google');
  redirectUrl.searchParams.set('token', session.jwt);

  // 5. Nettoyer puis rediriger
  deleteCookie(event, 'flutter_platform', { path: '/' });
  return sendRedirect(event, redirectUrl.toString(), 302);
});
```

**Ce qu’il faut retenir :**

1. **PlatformId** sélectionne automatiquement la bonne URL (web dev, proxy, prod, Android/iOS).  
2. **Fallback** garanti : si `platformId` manquant ou inconnu, SNAL retombe sur `FLUTTER_CALLBACK_WEB_DEV/PROD`, puis sur `https://app.jirig.be/#/home`.  
3. **Paramètres ajoutés** (`oauth`, `provider`, `token`) adaptés à ce que Flutter doit lire.  
4. **Nettoyage** du cookie `flutter_platform` pour éviter les fuites.  
5. **Facebook** suit exactement le même schéma en remplaçant les fonctions d’échange et `provider='facebook'`.

---

## 6. Choisir la bonne URL de redirection selon l’environnement

| Situation | URL à utiliser | Commentaire |
| --------- | -------------- | ----------- |
| Flutter web – dev direct | `http://localhost:3000/#/...` (`platformId=web-dev`) | Flutter lancé avec `flutter run -d chrome` |
| Flutter web – via proxy | `http://localhost:3001/#/...` (`platformId=web-proxy`) | Flutter derrière le proxy Express |
| Flutter web production | `https://app.jirig.be/#/...` (`platformId=web-prod`) | SPA Flutter hébergée |
| Flutter mobile debug | `thico://auth/success?...` (`platformId=android-dev` / `ios-dev`) | Deep link intercepté par l’app |
| Flutter mobile production | `thico://auth/success?...` (`platformId=android-prod` / `ios-prod`) | App publiée sur les stores |

### Configuration des deep links mobiles

1. **Android** – `android/app/src/main/AndroidManifest.xml`
   ```xml
   <intent-filter>
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="thico" android:host="auth" />
   </intent-filter>
   ```
2. **iOS** – `ios/Runner/Info.plist`
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>thico</string>
       </array>
     </dict>
   </array>
   ```
3. Flutter doit écouter ces liens (`uni_links`, `go_router`, …).
4. En production mobile, définir `FLUTTER_CALLBACK_MOBILE_PROD=thico://auth/success`.

Résultat attendu : `thico://auth/success?oauth=success&provider=google&token=<jwt>`.

---

## 7. Sécurité : gérer `state`, tokens et nettoyage

1. **Paramètre `state` obligatoire**
   - Exemple de charge : `{ provider, issuedAt, platformId }`.
   - Signer ou chiffrer (`HMAC`, AES, …) pour empêcher toute modification.
   - Dans le callback, rejeter si `state` est absent ou ne correspond pas au cookie.

2. **Session SNAL**
   - Générer un JWT court (ex. 15 minutes) ou un cookie serveur.
   - Ne jamais exposer d’informations sensibles (email, nom) dans l’URL.
   - Autoriser Flutter à rafraîchir/échanger ce token via vos endpoints existants.

3. **Nettoyage et logs**
   - Logguer la redirection finale :  
     ```ts
     console.log('[OAuth] Redirecting user to Flutter:', redirectUrl.toString());
     ```

---

## 8. Chronologie complète (Google, miroir pour Facebook)

1. L’utilisateur choisit « Continuer avec Google » dans Flutter.
2. Flutter récupère `platformId`, puis ouvre `https://jirig.be/api/auth/google-mobile?platformId=...`.
3. Le proxy Express transfère la requête vers SNAL (`google.get.ts`).
4. SNAL stocke `platformId`, prépare l’URL Google (`state` inclus) et redirige l’utilisateur.
5. Google authentifie l’utilisateur et renvoie vers `https://jirig.be/api/auth/google-callback?code=...&state=...`.
6. SNAL échange le code, crée la session, construit l’URL finale Flutter à partir de `platformId` (fallback si absent), ajoute `oauth`, `provider`, `token`.
7. SNAL renvoie un `302` vers cette URL.  
   - Web : `http://localhost:3000/#/...` ou `https://app.jirig.be/#/...`.  
   - Mobile : `thico://auth/success?...`.
8. Flutter intercepte la redirection (hash route ou deep link), lit le token, finalise la connexion et redirige l’utilisateur selon sa logique interne.

---

## 9. Checklist de validation

- [ ] Variables `FLUTTER_CALLBACK_*` présentes dans chaque environnement (dev, proxy, prod, mobile).
- [ ] Redirect URIs configurées dans Google Cloud Console et Meta Developer.
- [ ] Endpoints `google.get.ts` et `facebook.get.ts` : cookie `flutter_platform` + `state` généré.
- [ ] Endpoints `google-callback.get.ts` et `facebook-callback.get.ts` : redirection 302 vers Flutter + suppression du cookie platform.
- [ ] Flutter mobile : schéma `thico://` déclaré et testé (simulateur + appareil réel).
- [ ] Tests end-to-end : web dev, web via proxy, web prod, mobile debug, mobile prod.
- [ ] Logs SNAL confirment la redirection : `[OAuth] Redirecting user to Flutter: ...`.

Lorsque chaque élément est validé, la connexion sociale renverra **systématiquement** l’utilisateur vers l’application Flutter, que ce soit en développement local ou après publication sur les stores.***

