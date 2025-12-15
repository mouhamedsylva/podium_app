# ✅ Redirection Flutter : éléments manquants côté SNAL-Project

Ce mémo résume précisément ce qu’il reste à implémenter dans **SNAL-Project** pour que l’OAuth Google/Facebook renvoie l’utilisateur vers **Flutter Web** et **Flutter Mobile**.

---

## 1. Rappels

- **Flutter Web** utilise l’endpoint SNAL `GET /api/auth/google`.
- **Flutter Mobile** utilise l’endpoint SNAL `GET /api/auth/google-mobile`.
- À ce jour :
  - `google.get.ts` redirige toujours vers `https://jirig.be/` (interface Nuxt).
  - `google-mobile.get.ts` redirige vers `process.env.FLUTTER_CALLBACK_URL ?? "jirig://auth/callback"`.

Pour que Flutter reçoive la main, SNAL doit connaître l’URL exacte à viser et l’appliquer dans le callback OAuth.

---

## 2. Ce qui manque pour Flutter Web

1. **Transmettre la plateforme depuis Flutter :**  
   - Ajouter un paramètre `platformId` (ex. `web-dev`, `web-prod`) dans la requête vers SNAL :  
     ```dart
     // Sur Flutter Web
     final authUrl = 'https://jirig.be/api/auth/google?platformId=web-dev';
     ```
2. **Stocker `platformId` côté SNAL (google.get.ts) avant la redirection vers Google :**
   ```ts
   const { platformId } = getQuery(event);
   if (platformId) {
     setCookie(event, 'flutter_platform', platformId, {
       path: '/',
       httpOnly: false,
       sameSite: 'lax',
       maxAge: 600, // 10 minutes
     });
   }
   ```
3. **Dans `google-callback.get.ts`, choisir l’URL Flutter en fonction de `platformId` et rediriger vers cette URL :**
   ```ts
   const platformId = getCookie(event, 'flutter_platform') ||
                     (getQuery(event).platformId as string | undefined) ||
                     '';

   const targets: Record<string, string | undefined> = {
     'web-dev': 'http://localhost:56774/#/home', // URL Flutter web en dev
     'web-prod': 'https://app.jirig.be/#/home',  // URL Flutter web en production
   };

   const fallback =
     targets[platformId] ??
     (process.env.NODE_ENV === 'production'
       ? 'https://app.jirig.be/#/home'
       : 'http://localhost:56774/#/home');

   const flutterRedirect = new URL(fallback);
   flutterRedirect.searchParams.set('oauth', 'success');
   flutterRedirect.searchParams.set('provider', 'google');
   flutterRedirect.searchParams.set('token', session.jwt);

   deleteCookie(event, 'flutter_platform', { path: '/' });
   return sendRedirect(event, flutterRedirect.toString());
   ```

4. **Déclarer les valeurs cibles dans les variables d’environnement (optionnel mais recommandé) :**
   ```
   FLUTTER_CALLBACK_WEB_DEV=http://localhost:56774/#/home
   FLUTTER_CALLBACK_WEB_PROD=https://app.jirig.be/#/home
   ```
   Puis remplacer les chaînes codées en dur par `process.env.FLUTTER_CALLBACK_WEB_DEV` / `WEB_PROD`.

---

## 3. Ce qui manque pour Flutter Mobile

1. **Variable d’environnement :**  
   Vérifier / ajouter dans SNAL :
   ```
   FLUTTER_CALLBACK_URL=thico://auth/callback
   ```
   (si besoin, une valeur différente par environnement : `FLUTTER_CALLBACK_MOBILE_DEV`, `FLUTTER_CALLBACK_MOBILE_PROD`, etc.).

2. **Optionnel : gestion fine par plateforme via `platformId`**  
   - Faire transiter `platformId=android-dev`, `ios-prod`, etc. dans `google-mobile.get.ts`.
   - Adapter le même mapping que pour web dans `google-mobile.get.ts` pour sélectionner l’URL :
     ```ts
     const platformId = getCookie(event, 'flutter_platform') ||
                       (getQuery(event).platformId as string | undefined) ||
                       '';

     const targets: Record<string, string | undefined> = {
       'android-dev': 'thico://auth/callback',
       'ios-dev': 'thico://auth/callback',
       'android-prod': 'thico://auth/callback',
       'ios-prod': 'thico://auth/callback',
     };

     const fallback =
       targets[platformId] ??
       (process.env.FLUTTER_CALLBACK_URL ?? 'thico://auth/callback');

     const flutterRedirect = new URL(fallback);
     flutterRedirect.searchParams.set('iProfile', profileData.iProfileEncrypted);
     flutterRedirect.searchParams.set('iBasket', profileData.iBasketProfil);

     deleteCookie(event, 'flutter_platform', { path: '/' });
     return sendRedirect(event, flutterRedirect.toString());
     ```

3. **Deep link Flutter :**  
   L’app mobile doit continuer d’écouter `jirig://auth/callback` (ou le schéma défini). `OAuthMobileHandler` s’en charge déjà ; aucun changement Flutter supplémentaire n’est requis si les identifiants arrivent bien.

---

## 4. Checklist rapide

- [ ] Flutter envoie un `platformId` (ou autre identifiant de plateforme) lors de l’appel OAuth.  
- [ ] `google.get.ts` (et `facebook.get.ts`) stockent ce `platformId`.  
- [ ] `google-callback.get.ts` reconstruit l’URL Flutter (dev/prod) en fonction du `platformId`.  
- [ ] Variables d’environnement définies : `FLUTTER_CALLBACK_WEB_DEV`, `FLUTTER_CALLBACK_WEB_PROD`, `FLUTTER_CALLBACK_URL` (mobile).  
- [ ] Même logique appliquée pour Facebook si besoin.

Une fois ces éléments en place, SNAL saura rediriger vers l’URL Flutter correcte pour chaque plateforme, et Flutter (web ou mobile) reprendra la main immédiatement après l’authentification.***

