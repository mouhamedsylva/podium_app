# Implémentation Facebook OAuth Mobile

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Backend (SNAL-Project)](#backend-snal-project)
4. [Frontend Flutter](#frontend-flutter)
5. [Flux OAuth complet](#flux-oauth-complet)
6. [Permissions requises](#permissions-requises)
7. [Configuration](#configuration)
8. [Différences avec Google OAuth](#différences-avec-google-oauth)
9. [Troubleshooting](#troubleshooting)
10. [Tests](#tests)

---

## Vue d'ensemble

L'implémentation Facebook OAuth pour mobile permet aux utilisateurs de se connecter à l'application Flutter via leur compte Facebook. Contrairement à Google OAuth qui utilise un token directement, Facebook utilise un flux OAuth standard avec redirection vers le navigateur externe.

### Endpoint utilisé
- **Production** : `https://jirig.com/api/auth/facebook-mobile`
- **Développement** : `https://jirig.be/api/auth/facebook-mobile` (non utilisé actuellement)

---

## Architecture

### Comparaison des approches OAuth

| Caractéristique | Google Mobile | Facebook Mobile |
|----------------|---------------|-----------------|
| **Type de flux** | Token direct (`id_token`) | OAuth standard (redirection) |
| **Package Flutter** | `google_sign_in` | `url_launcher` |
| **Interaction utilisateur** | SDK natif (dialogue Google) | Navigateur externe |
| **Endpoint backend** | `/api/auth/google-mobile` | `/api/auth/facebook-mobile` |
| **Retour backend** | JSON avec identifiants | Cookies/Session (pas de JSON) |
| **Détection connexion** | Réponse API directe | Timer polling + vérification session |

---

## Backend (SNAL-Project)

### Fichier : `server/api/auth/facebook-mobile.get.ts`

L'endpoint utilise `defineOAuthFacebookEventHandler` de Nuxt OAuth pour gérer le flux OAuth complet.

#### Fonctionnalités principales

1. **Normalisation des données Facebook**
   ```typescript
   user.sub = user.sub || user.id;
   user.email = user.email || `${user.id}@facebook.com`;
   user.family_name = user.family_name || user.name?.split(" ").pop() || "";
   user.given_name = user.given_name || user.name?.split(" ").slice(0, -1).join(" ") || "";
   user.picture = user.picture || `https://graph.facebook.com/${user.id}/picture?type=large`;
   ```

2. **Récupération du profil guest existant**
   - Utilise les cookies `GuestProfile` pour conserver les préférences utilisateur (pays, langue)
   - Permet de migrer un profil guest vers un profil authentifié

3. **Création/Mise à jour du profil**
   - Appelle la procédure SQL `dbo.proc_user_signup_4All_user_v2`
   - Transmet les informations Facebook via XML
   - Récupère les nouveaux identifiants (`iProfile`, `iBasket`)

4. **Gestion de session**
   - Crée une session utilisateur via `setUserSession`
   - Les cookies sont automatiquement gérés par Nuxt

#### Structure XML envoyée à la DB

```xml
<root>
  <email>user@facebook.com</email>
  <sProviderId>facebook_user_id</sProviderId>
  <sProvider>facebook</sProvider>
  <sPhoto>https://graph.facebook.com/xxx/picture?type=large</sPhoto>
  <nom>Nom</nom>
  <prenom>Prénom</prenom>
  <sTypeAccount>EMAIL</sTypeAccount>
  <iPaysOrigine>pays_code</iPaysOrigine>
  <sLangue>langue_code</sLangue>
  <sPaysListe>pays_list</sPaysListe>
  <sPaysLangue>langue_code</sPaysLangue>
</root>
```

#### Gestion d'erreurs

```typescript
onError(event, error) {
  console.error("❌ Facebook OAuth Mobile Error:", error);
  event.res.statusCode = 500;
  event.res.end("Facebook OAuth failed");
}
```

---

## Frontend Flutter

### Fichier : `lib/screens/login_screen.dart`

#### Fonction principale : `_loginWithFacebook()`

```dart
Future<void> _loginWithFacebook() async {
  print('🔐 Connexion avec Facebook');
  final translationService = Provider.of<TranslationService>(context, listen: false);
  try {
    // ✅ Démarrer le timer OAuth pour vérifier la connexion
    _startOAuthCheckTimer();
    
    // Sauvegarder le callBackUrl pour le récupérer après OAuth
    final callBackUrl = widget.callBackUrl ?? '/wishlist';
    await LocalStorageService.saveCallBackUrl(callBackUrl);

    // URL de connexion Facebook - Endpoint mobile
    String authUrl = 'https://jirig.com/api/auth/facebook-mobile';

    print('🌐 Redirection vers Facebook OAuth: $authUrl');
    print('📝 Note: Après la connexion sur SNAL, revenez à cette application');

    // Ouvrir directement l'URL SNAL
    await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );

    // Afficher un message à l'utilisateur
    setState(() {
      _errorMessage = translationService.translate('LOGIN_MESSAGE_RETURN_APP');
    });
  } catch (e) {
    print('❌ Erreur connexion Facebook: $e');
    setState(() {
      _errorMessage = translationService.translate('LOGIN_ERROR_FACEBOOK');
    });
  }
}
```

#### Détection de connexion : `_startOAuthCheckTimer()`

Contrairement à Google qui reçoit une réponse directe, Facebook nécessite un système de polling pour détecter la connexion :

```dart
void _startOAuthCheckTimer() {
  if (!_oauthCheckActive) {
    _oauthCheckActive = true;
    print('🔄 Démarrage du timer OAuth');
  }
  
  // Vérifier toutes les 2 secondes si l'utilisateur est connecté
  Future.delayed(Duration(seconds: 2), () async {
    if (!mounted || !_oauthCheckActive) return;
    
    try {
      final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
      await authNotifier.refresh();
      
      if (authNotifier.isLoggedIn) {
        print('✅ OAuth détecté - Utilisateur connecté');
        
        // Arrêter le timer
        _oauthCheckActive = false;
        
        // Récupérer le callBackUrl
        final callBackUrl = await LocalStorageService.getCallBackUrl() ?? widget.callBackUrl ?? '/wishlist';
        await LocalStorageService.clearCallBackUrl();
        
        // Afficher popup et rediriger
        if (mounted) {
          await _showSuccessPopup();
          context.go(callBackUrl);
        }
      } else {
        // Continuer à vérifier seulement si le timer est toujours actif
        if (mounted && _oauthCheckActive) {
          _startOAuthCheckTimer();
        }
      }
    } catch (e) {
      print('⚠️ Erreur vérification OAuth: $e');
      if (mounted && _oauthCheckActive) {
        _startOAuthCheckTimer();
      }
    }
  });
}
```

#### Fonctionnement du timer

1. **Démarrage** : Le timer démarre quand l'utilisateur clique sur "Continuer avec Facebook"
2. **Polling** : Toutes les 2 secondes, vérifie si `AuthNotifier.isLoggedIn` est `true`
3. **Détection** : Quand la connexion est détectée, arrête le timer et redirige
4. **Arrêt** : Le timer s'arrête si :
   - L'utilisateur est connecté
   - Le widget est détruit (`dispose()`)
   - Le flag `_oauthCheckActive` est mis à `false`

---

## Flux OAuth complet

### 1. L'utilisateur clique sur "Continuer avec Facebook"

```
[Flutter App] → _loginWithFacebook()
```

### 2. Sauvegarde du callback URL

```
LocalStorageService.saveCallBackUrl('/wishlist')
```

### 3. Ouverture du navigateur externe

```
launchUrl('https://jirig.com/api/auth/facebook-mobile', 
          mode: LaunchMode.externalApplication)
```

### 4. Redirection OAuth Facebook

```
[Navigateur] → https://jirig.com/api/auth/facebook-mobile
[Navigateur] → https://www.facebook.com/vXX.X/dialog/oauth
[Utilisateur] → Se connecte avec ses identifiants Facebook
[Navigateur] → https://www.facebook.com/connect/login_success.html
[Facebook] → Redirige vers callback_url configuré dans Nuxt
```

### 5. Traitement backend

```
[Nuxt Backend] → defineOAuthFacebookEventHandler.onSuccess()
[Backend] → Normalise les données Facebook
[Backend] → Récupère le profil guest (cookies)
[Backend] → Crée/met à jour le profil utilisateur (DB)
[Backend] → Crée la session (cookies)
```

### 6. Détection de connexion (Flutter)

```
[Flutter Timer] → Vérifie toutes les 2 secondes
[Flutter] → AuthNotifier.refresh() → Appelle /api/profile
[Backend] → Retourne le profil utilisateur (cookies envoyés automatiquement)
[Flutter] → Détecte isLoggedIn = true
[Flutter] → Arrête le timer
[Flutter] → Redirige vers callBackUrl
```

### 7. Redirection finale

```
[Flutter] → context.go('/wishlist')
[Flutter] → Affiche la wishlist avec l'utilisateur connecté
```

---

## Permissions requises

### Android

Toutes les permissions nécessaires sont déjà configurées dans `android/app/src/main/AndroidManifest.xml` :

```xml
<!-- Permission réseau -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Queries pour url_launcher (Android 11+) -->
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
</queries>
```

✅ **Aucune permission supplémentaire nécessaire**

### iOS

Configuration ajoutée dans `ios/Runner/Info.plist` :

```xml
<!-- URLs schemes pour url_launcher (OAuth Facebook/Google) -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>https</string>
    <string>http</string>
</array>
```

✅ **Configuration complète**

---

## Configuration

### Backend (Nuxt)

L'endpoint Facebook OAuth nécessite la configuration suivante dans `nuxt.config.ts` :

```typescript
oauth: {
  facebook: {
    clientId: process.env.NUXT_OAUTH_FACEBOOK_CLIENT_ID,
    clientSecret: process.env.NUXT_OAUTH_FACEBOOK_CLIENT_SECRET,
    // ...
  }
}
```

**Variables d'environnement requises :**
- `NUXT_OAUTH_FACEBOOK_CLIENT_ID` : ID de l'application Facebook
- `NUXT_OAUTH_FACEBOOK_CLIENT_SECRET` : Secret de l'application Facebook

### Frontend Flutter

Aucune configuration spécifique requise dans Flutter. L'endpoint est codé en dur dans `login_screen.dart` :

```dart
String authUrl = 'https://jirig.com/api/auth/facebook-mobile';
```

Pour changer d'environnement, modifier cette ligne ou utiliser `ApiConfig.baseUrl` :

```dart
String authUrl = '${ApiConfig.baseUrl}/auth/facebook-mobile';
```

---

## Différences avec Google OAuth

### Google OAuth Mobile

| Aspect | Détails |
|--------|---------|
| **Package** | `google_sign_in: ^6.2.1` |
| **Flux** | SDK natif → `idToken` → API `/google-mobile` → JSON response |
| **Avantage** | Expérience utilisateur native, pas de redirection |
| **Inconvénient** | Nécessite configuration Android (SHA-1, Client ID) |

### Facebook OAuth Mobile

| Aspect | Détails |
|--------|---------|
| **Package** | `url_launcher: ^6.2.5` |
| **Flux** | Navigateur externe → OAuth → Cookies/Session → Polling |
| **Avantage** | Pas de configuration complexe, fonctionne partout |
| **Inconvénient** | Expérience moins fluide (redirection navigateur) |

### Choix de l'implémentation

Facebook utilise le navigateur externe car :
1. Le SDK Facebook Flutter (`flutter_facebook_auth`) peut avoir des problèmes de compatibilité
2. Le flux OAuth standard via navigateur est plus fiable
3. Moins de configuration requise côté Flutter
4. Compatible avec toutes les versions d'Android/iOS

---

## Troubleshooting

### Problème : Le timer ne détecte pas la connexion

**Symptômes :**
- L'utilisateur se connecte sur Facebook mais reste sur l'écran de login
- Le timer continue indéfiniment

**Solutions :**

1. **Vérifier que les cookies sont bien envoyés**
   ```dart
   // Dans ApiService, vérifier que dio_cookie_manager est configuré
   dio.interceptors.add(CookieManager(cookieJar));
   ```

2. **Vérifier le domaine des cookies**
   - Les cookies doivent être sur `.jirig.com` (pas `.jirig.be`)
   - Vérifier la configuration backend

3. **Augmenter la fréquence du polling**
   ```dart
   // Dans _startOAuthCheckTimer(), changer à 1 seconde au lieu de 2
   Future.delayed(Duration(seconds: 1), () async {
     // ...
   });
   ```

### Problème : Erreur "Facebook OAuth failed"

**Symptômes :**
- L'utilisateur voit une erreur 500 après la connexion Facebook
- Le backend retourne "Facebook OAuth failed"

**Solutions :**

1. **Vérifier les logs backend**
   ```typescript
   // Dans facebook-mobile.get.ts, vérifier les logs
   console.error("❌ [Facebook Mobile] Error:", error);
   ```

2. **Vérifier les variables d'environnement**
   - `NUXT_OAUTH_FACEBOOK_CLIENT_ID`
   - `NUXT_OAUTH_FACEBOOK_CLIENT_SECRET`

3. **Vérifier la configuration OAuth dans Facebook Developer**
   - URL de callback doit être : `https://jirig.com/api/auth/facebook-mobile`
   - Domaines autorisés : `jirig.com`, `jirig.be`

### Problème : L'URL ne s'ouvre pas dans le navigateur

**Symptômes :**
- Rien ne se passe quand l'utilisateur clique sur Facebook
- Erreur `PlatformException`

**Solutions :**

1. **Vérifier les permissions Android (déjà configurées)**
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```

2. **Vérifier les queries Android (déjà configurées)**
   ```xml
   <queries>
       <intent>
           <action android:name="android.intent.action.VIEW" />
           <data android:scheme="https" />
       </intent>
   </queries>
   ```

3. **Vérifier le mode de lancement**
   ```dart
   // Utiliser LaunchMode.externalApplication (déjà configuré)
   await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
   ```

---

## Tests

### Test manuel

1. **Lancer l'application Flutter**
   ```bash
   flutter run
   ```

2. **Aller sur l'écran de login**
   - Cliquer sur "Continuer avec Facebook"

3. **Observer le comportement**
   - ✅ Le navigateur externe s'ouvre
   - ✅ L'URL `https://jirig.com/api/auth/facebook-mobile` est chargée
   - ✅ Redirection vers Facebook OAuth
   - ✅ Après connexion, retour à l'application
   - ✅ Timer détecte la connexion (logs dans console)
   - ✅ Redirection vers `/wishlist`

### Vérifier les logs

**Flutter :**
```
🔐 Connexion avec Facebook
🔄 Démarrage du timer OAuth
🌐 Redirection vers Facebook OAuth: https://jirig.com/api/auth/facebook-mobile
📝 Note: Après la connexion sur SNAL, revenez à cette application
✅ OAuth détecté - Utilisateur connecté
```

**Backend (Nuxt) :**
```
[Facebook Mobile] SUCCESS
Facebook Mobile newProfile: {...}
Facebook Mobile profileData: {...}
👤 Facebook Mobile profile: {...}
```

### Test de régression

Vérifier que :
- ✅ Google OAuth fonctionne toujours
- ✅ Email/Code login fonctionne toujours
- ✅ Les cookies sont bien persistés
- ✅ Le profil est correctement mis à jour après connexion Facebook

---

## Évolutions futures possibles

### Option 1 : SDK Facebook natif

Utiliser `flutter_facebook_auth` pour une expérience plus native :
- ✅ Dialogue natif (pas de navigateur)
- ❌ Configuration plus complexe
- ❌ Peut avoir des problèmes de compatibilité

### Option 2 : Deep Link callback

Améliorer le retour vers l'application avec un deep link :
- ✅ Retour automatique à l'app (pas de polling)
- ❌ Nécessite configuration backend pour rediriger vers deep link
- ❌ Nécessite configuration Android/iOS pour capturer le deep link

### Option 3 : WebView interne

Utiliser une WebView au lieu du navigateur externe :
- ✅ Meilleure UX (reste dans l'app)
- ❌ Plus complexe à gérer (gestion des cookies, navigation)
- ❌ Peut avoir des problèmes avec certains navigateurs

---

## Conclusion

L'implémentation actuelle de Facebook OAuth Mobile est fonctionnelle et stable. Elle utilise un flux OAuth standard avec redirection vers le navigateur externe, ce qui garantit la compatibilité et la simplicité de maintenance.

**Points forts :**
- ✅ Simple et fiable
- ✅ Pas de configuration complexe
- ✅ Compatible avec toutes les versions Android/iOS
- ✅ Fonctionne avec le système de cookies existant

**Points à améliorer :**
- ⚠️ Expérience utilisateur moins fluide (redirection navigateur)
- ⚠️ Système de polling pour détecter la connexion
- ⚠️ Pas de retour automatique à l'application

---

**Dernière mise à jour :** Janvier 2025  
**Version :** 1.0.0  
**Auteur :** Documentation générée automatiquement

