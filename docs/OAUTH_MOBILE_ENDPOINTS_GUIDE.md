# 🔐 Guide d'implémentation OAuth Mobile pour SNAL

## 📋 Vue d'ensemble

Ce guide explique **étape par étape** comment créer des endpoints OAuth spécifiques pour mobile dans SNAL qui redirigent vers l'application Flutter au lieu du site web en production.

## 🎯 Objectif

**Problème actuel :** Quand vous cliquez sur Google/Facebook dans Flutter, vous êtes redirigé vers le site web SNAL en production au lieu de revenir à votre application Flutter.

**Solution :** Créer des endpoints OAuth spécifiques pour mobile qui redirigent directement vers votre application Flutter.

## 🏗️ Architecture

```
Flutter App → SNAL OAuth Mobile → Google/Facebook → SNAL Callback → Flutter App
```

**Explication :**
1. Flutter ouvre l'endpoint OAuth mobile de SNAL
2. SNAL redirige vers Google/Facebook pour l'authentification
3. Google/Facebook redirige vers le callback de SNAL
4. SNAL traite la connexion et redirige vers Flutter

## 📁 Structure des fichiers à créer dans SNAL

### 1. Google OAuth Mobile Endpoint

**Fichier :** `SNAL-Project/server/api/auth/google-mobile.get.ts`

**Explication :** Ce fichier crée un endpoint spécifique pour la connexion Google sur mobile. Quand Flutter appelle cet endpoint, il redirige vers Google OAuth avec les paramètres appropriés pour mobile.

**Comment créer ce fichier :**
1. Ouvrez votre projet SNAL dans votre éditeur
2. Naviguez vers le dossier `server/api/auth/`
3. Créez un nouveau fichier nommé `google-mobile.get.ts`
4. Copiez le code ci-dessous dans ce fichier

```typescript
export default defineEventHandler(async (event) => {
  console.log('🔐 Google OAuth Mobile - Démarrage');
  
  try {
    // Récupérer les paramètres de requête envoyés par Flutter
    const query = getQuery(event);
    const { redirect_uri } = query;
    
    console.log('📱 Paramètres reçus:', { redirect_uri });
    
    // URL de redirection par défaut vers Flutter (deep link)
    const defaultRedirectUri = 'jirig://oauth/callback';
    const finalRedirectUri = redirect_uri || defaultRedirectUri;
    
    console.log('🎯 Redirect URI final:', finalRedirectUri);
    
    // Configuration OAuth Google pour mobile
    const googleAuthUrl = new URL('https://accounts.google.com/oauth/authorize');
    googleAuthUrl.searchParams.set('client_id', process.env.GOOGLE_CLIENT_ID);
    googleAuthUrl.searchParams.set('redirect_uri', process.env.GOOGLE_REDIRECT_URI_MOBILE);
    googleAuthUrl.searchParams.set('response_type', 'code');
    googleAuthUrl.searchParams.set('scope', 'openid email profile');
    googleAuthUrl.searchParams.set('state', JSON.stringify({ 
      redirect_uri: finalRedirectUri,
      platform: 'mobile'
    }));
    
    console.log('🌐 Redirection vers Google OAuth:', googleAuthUrl.toString());
    
    // Rediriger vers Google OAuth
    await sendRedirect(event, googleAuthUrl.toString(), 302);
    
  } catch (error) {
    console.error('❌ Erreur Google OAuth Mobile:', error);
    
    // Rediriger vers Flutter avec erreur
    const errorRedirectUri = 'jirig://oauth/callback?error=oauth_error&provider=google';
    await sendRedirect(event, errorRedirectUri, 302);
  }
});
```

**Explication du code :**
- `getQuery(event)` : Récupère les paramètres envoyés par Flutter
- `redirect_uri` : URL où rediriger après la connexion (vers Flutter)
- `googleAuthUrl` : Construit l'URL Google OAuth avec les bons paramètres
- `state` : Passe des informations entre les étapes OAuth
- `sendRedirect` : Redirige vers Google OAuth

### 2. Facebook OAuth Mobile Endpoint

**Fichier :** `SNAL-Project/server/api/auth/facebook-mobile.get.ts`

**Explication :** Ce fichier crée un endpoint spécifique pour la connexion Facebook sur mobile. Il fonctionne de la même manière que l'endpoint Google mais pour Facebook.

**Comment créer ce fichier :**
1. Dans le même dossier `server/api/auth/`
2. Créez un nouveau fichier nommé `facebook-mobile.get.ts`
3. Copiez le code ci-dessous dans ce fichier

```typescript
export default defineEventHandler(async (event) => {
  console.log('🔐 Facebook OAuth Mobile - Démarrage');
  
  try {
    // Récupérer les paramètres de requête envoyés par Flutter
    const query = getQuery(event);
    const { redirect_uri } = query;
    
    console.log('📱 Paramètres reçus:', { redirect_uri });
    
    // URL de redirection par défaut vers Flutter (deep link)
    const defaultRedirectUri = 'jirig://oauth/callback';
    const finalRedirectUri = redirect_uri || defaultRedirectUri;
    
    console.log('🎯 Redirect URI final:', finalRedirectUri);
    
    // Configuration OAuth Facebook pour mobile
    const facebookAuthUrl = new URL('https://www.facebook.com/v18.0/dialog/oauth');
    facebookAuthUrl.searchParams.set('client_id', process.env.FACEBOOK_APP_ID);
    facebookAuthUrl.searchParams.set('redirect_uri', process.env.FACEBOOK_REDIRECT_URI_MOBILE);
    facebookAuthUrl.searchParams.set('response_type', 'code');
    facebookAuthUrl.searchParams.set('scope', 'email');
    facebookAuthUrl.searchParams.set('state', JSON.stringify({ 
      redirect_uri: finalRedirectUri,
      platform: 'mobile'
    }));
    
    console.log('🌐 Redirection vers Facebook OAuth:', facebookAuthUrl.toString());
    
    // Rediriger vers Facebook OAuth
    await sendRedirect(event, facebookAuthUrl.toString(), 302);
    
  } catch (error) {
    console.error('❌ Erreur Facebook OAuth Mobile:', error);
    
    // Rediriger vers Flutter avec erreur
    const errorRedirectUri = 'jirig://oauth/callback?error=oauth_error&provider=facebook';
    await sendRedirect(event, errorRedirectUri, 302);
  }
});
```

**Explication du code :**
- Même structure que Google mais avec les paramètres Facebook
- `FACEBOOK_APP_ID` : ID de votre application Facebook
- `FACEBOOK_REDIRECT_URI_MOBILE` : URL de callback pour mobile
- `scope: 'email'` : Demande l'accès à l'email de l'utilisateur

### 3. Callback OAuth Mobile Endpoint

**Fichier :** `SNAL-Project/server/api/auth/oauth-mobile-callback.get.ts`

**Explication :** Ce fichier gère le retour de Google/Facebook après l'authentification. Il reçoit le code d'authentification, traite la connexion et redirige vers Flutter.

**Comment créer ce fichier :**
1. Dans le même dossier `server/api/auth/`
2. Créez un nouveau fichier nommé `oauth-mobile-callback.get.ts`
3. Copiez le code ci-dessous dans ce fichier

```typescript
export default defineEventHandler(async (event) => {
  console.log('🔐 OAuth Mobile Callback - Démarrage');
  
  try {
    // Récupérer les paramètres de retour de Google/Facebook
    const query = getQuery(event);
    const { code, state, error, error_description } = query;
    
    console.log('📱 Callback reçu:', { code: !!code, state, error });
    
    // Vérifier s'il y a une erreur OAuth
    if (error) {
      console.error('❌ Erreur OAuth:', error, error_description);
      throw new Error(`OAuth error: ${error}`);
    }
    
    // Vérifier que le code d'authentification est présent
    if (!code) {
      throw new Error('Code OAuth manquant');
    }
    
    // Décoder le state pour récupérer les paramètres
    let stateParams = {};
    try {
      stateParams = JSON.parse(decodeURIComponent(state as string));
    } catch (e) {
      console.warn('⚠️ Impossible de décoder le state:', e);
    }
    
    const { redirect_uri, platform } = stateParams;
    const finalRedirectUri = redirect_uri || 'jirig://oauth/callback';
    
    console.log('🎯 Paramètres state:', { redirect_uri: finalRedirectUri, platform });
    
    // Déterminer le provider (Google ou Facebook) basé sur l'URL de callback
    const referer = getHeader(event, 'referer') || '';
    const isGoogle = referer.includes('accounts.google.com');
    const isFacebook = referer.includes('facebook.com');
    const provider = isGoogle ? 'google' : isFacebook ? 'facebook' : 'unknown';
    
    console.log('🔍 Provider détecté:', provider);
    
    // Traitement OAuth spécifique au provider
    if (provider === 'google') {
      await handleGoogleOAuthCallback(event, code, finalRedirectUri);
    } else if (provider === 'facebook') {
      await handleFacebookOAuthCallback(event, code, finalRedirectUri);
    } else {
      throw new Error('Provider OAuth non reconnu');
    }
    
  } catch (error) {
    console.error('❌ Erreur OAuth Mobile Callback:', error);
    
    // Rediriger vers Flutter avec erreur
    const errorRedirectUri = 'jirig://oauth/callback?error=callback_error&message=' + encodeURIComponent(error.message);
    await sendRedirect(event, errorRedirectUri, 302);
  }
});

// Fonction pour gérer le callback Google
async function handleGoogleOAuthCallback(event: any, code: string, redirectUri: string) {
  console.log('🔐 Traitement callback Google');
  
  try {
    // Échanger le code contre un token d'accès
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.GOOGLE_CLIENT_SECRET,
        code: code,
        grant_type: 'authorization_code',
        redirect_uri: process.env.GOOGLE_REDIRECT_URI_MOBILE,
      }),
    });
    
    const tokenData = await tokenResponse.json();
    console.log('🎫 Token Google reçu');
    
    // Récupérer les informations utilisateur avec le token
    const userResponse = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: {
        Authorization: `Bearer ${tokenData.access_token}`,
      },
    });
    
    const userData = await userResponse.json();
    console.log('👤 Utilisateur Google:', { id: userData.id, email: userData.email });
    
    // Traitement utilisateur (créer/mettre à jour en base de données)
    await processUserData(event, userData, 'google');
    
    // Rediriger vers Flutter avec succès
    const successRedirectUri = `${redirectUri}?success=true&provider=google&user_id=${userData.id}`;
    await sendRedirect(event, successRedirectUri, 302);
    
  } catch (error) {
    console.error('❌ Erreur callback Google:', error);
    throw error;
  }
}

// Fonction pour gérer le callback Facebook
async function handleFacebookOAuthCallback(event: any, code: string, redirectUri: string) {
  console.log('🔐 Traitement callback Facebook');
  
  try {
    // Échanger le code contre un token
    const tokenResponse = await fetch('https://graph.facebook.com/v18.0/oauth/access_token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: process.env.FACEBOOK_APP_ID,
        client_secret: process.env.FACEBOOK_APP_SECRET,
        code: code,
        redirect_uri: process.env.FACEBOOK_REDIRECT_URI_MOBILE,
      }),
    });
    
    const tokenData = await tokenResponse.json();
    console.log('🎫 Token Facebook reçu');
    
    // Récupérer les informations utilisateur
    const userResponse = await fetch(`https://graph.facebook.com/v18.0/me?access_token=${tokenData.access_token}&fields=id,name,email`);
    const userData = await userResponse.json();
    console.log('👤 Utilisateur Facebook:', { id: userData.id, email: userData.email });
    
    // Traitement utilisateur (créer/mettre à jour en base)
    await processUserData(event, userData, 'facebook');
    
    // Rediriger vers Flutter avec succès
    const successRedirectUri = `${redirectUri}?success=true&provider=facebook&user_id=${userData.id}`;
    await sendRedirect(event, successRedirectUri, 302);
    
  } catch (error) {
    console.error('❌ Erreur callback Facebook:', error);
    throw error;
  }
}

// Fonction pour traiter les données utilisateur
async function processUserData(event: any, userData: any, provider: string) {
  console.log('👤 Traitement des données utilisateur:', { provider, userId: userData.id });
  
  // Ici, vous pouvez ajouter votre logique pour :
  // 1. Créer ou mettre à jour l'utilisateur en base de données
  // 2. Créer une session utilisateur
  // 3. Définir les cookies appropriés
  
  // Exemple basique :
  const userInfo = {
    id: userData.id,
    email: userData.email,
    name: userData.name || userData.given_name,
    provider: provider,
    avatar: userData.picture || userData.picture?.data?.url,
  };
  
  console.log('✅ Utilisateur traité:', userInfo);
  
  // TODO: Implémenter la logique de base de données
  // await createOrUpdateUser(userInfo);
  // await createUserSession(event, userInfo);
}
```

## ⚙️ Configuration des variables d'environnement

**Explication :** Vous devez configurer les variables d'environnement pour que SNAL puisse communiquer avec Google et Facebook OAuth.

**Comment faire :**
1. Ouvrez le fichier `.env` dans votre projet SNAL
2. Ajoutez les variables ci-dessous
3. Remplacez les valeurs par vos vraies clés OAuth

```env
# Google OAuth Mobile
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_REDIRECT_URI_MOBILE=https://jirig.be/api/auth/oauth-mobile-callback

# Facebook OAuth Mobile
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_REDIRECT_URI_MOBILE=https://jirig.be/api/auth/oauth-mobile-callback
```

**Comment obtenir ces clés :**

**Pour Google :**
1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Créez un projet ou sélectionnez un projet existant
3. Activez l'API Google+ et OAuth2
4. Créez des identifiants OAuth 2.0
5. Ajoutez `https://jirig.be/api/auth/oauth-mobile-callback` comme URI de redirection

**Pour Facebook :**
1. Allez sur [Facebook Developers](https://developers.facebook.com/)
2. Créez une nouvelle application
3. Ajoutez le produit "Facebook Login"
4. Configurez les URI de redirection OAuth valides
5. Ajoutez `https://jirig.be/api/auth/oauth-mobile-callback` comme URI de redirection

## 📱 Configuration Flutter

**Explication :** Maintenant que vous avez créé les endpoints OAuth mobiles dans SNAL, vous devez modifier Flutter pour les utiliser.

### 1. Modification du login_screen.dart

**Explication :** Remplacez les méthodes OAuth existantes par ces nouvelles méthodes qui utilisent les endpoints mobiles de SNAL.

**Comment faire :**
1. Ouvrez le fichier `lib/screens/login_screen.dart`
2. Remplacez les méthodes `_loginWithGoogle()` et `_loginWithFacebook()` par les nouvelles méthodes ci-dessous

```dart
/// Connexion avec Google Mobile - Nouveau endpoint SNAL
Future<void> _loginWithGoogleMobile() async {
  print('🔐 Connexion avec Google Mobile');
  try {
    // Sauvegarder le callBackUrl pour le récupérer après OAuth
    final callBackUrl = widget.callBackUrl ?? '/wishlist';
    await LocalStorageService.saveCallBackUrl(callBackUrl);
    
    // URL de connexion Google Mobile basée sur SNAL
    String authUrl = 'https://jirig.be/api/auth/google-mobile?redirect_uri=jirig://oauth/callback';

    print('🌐 Redirection vers Google OAuth Mobile: $authUrl');

    // Ouvrir l'URL SNAL Mobile OAuth
    await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
    
  } catch (e) {
    print('❌ Erreur connexion Google Mobile: $e');
    setState(() {
      _errorMessage = 'Erreur lors de la connexion avec Google';
    });
  }
}

/// Connexion avec Facebook Mobile - Nouveau endpoint SNAL
Future<void> _loginWithFacebookMobile() async {
  print('🔐 Connexion avec Facebook Mobile');
  try {
    // Sauvegarder le callBackUrl pour le récupérer après OAuth
    final callBackUrl = widget.callBackUrl ?? '/wishlist';
    await LocalStorageService.saveCallBackUrl(callBackUrl);
    
    // URL de connexion Facebook Mobile basée sur SNAL
    String authUrl = 'https://jirig.be/api/auth/facebook-mobile?redirect_uri=jirig://oauth/callback';

    print('🌐 Redirection vers Facebook OAuth Mobile: $authUrl');

    // Ouvrir l'URL SNAL Mobile OAuth
    await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
    
  } catch (e) {
    print('❌ Erreur connexion Facebook Mobile: $e');
    setState(() {
      _errorMessage = 'Erreur lors de la connexion avec Facebook';
    });
  }
}
```

**Explication du code :**
- `google-mobile` : Utilise le nouvel endpoint Google mobile de SNAL
- `facebook-mobile` : Utilise le nouvel endpoint Facebook mobile de SNAL
- `redirect_uri=jirig://oauth/callback` : Spécifie que le retour doit se faire vers Flutter
- `LaunchMode.externalApplication` : Ouvre l'URL dans le navigateur externe

### 2. Configuration des deep links dans AndroidManifest.xml

**Explication :** Les deep links permettent à votre application Flutter de recevoir les redirections OAuth. Quand SNAL redirige vers `jirig://oauth/callback`, Android ouvrira votre application Flutter.

**Comment faire :**
1. Ouvrez le fichier `android/app/src/main/AndroidManifest.xml`
2. Assurez-vous que votre activité principale contient les intent filters ci-dessous

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    
    <!-- Deep link pour OAuth callback -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="jirig" />
    </intent-filter>
    
    <!-- Intent filter pour le callback OAuth -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="jirig"
              android:host="oauth"
              android:pathPrefix="/callback" />
    </intent-filter>
</activity>
```

**Explication des intent filters :**
- `android:scheme="jirig"` : Permet d'intercepter les URLs qui commencent par `jirig://`
- `android:host="oauth"` : Spécifie que l'URL doit contenir `oauth`
- `android:pathPrefix="/callback"` : Spécifie que l'URL doit se terminer par `/callback`
- Résultat : `jirig://oauth/callback` ouvrira votre application Flutter

## 🔄 Flux complet détaillé

**Explication :** Voici le flux complet de bout en bout avec des explications détaillées.

1. **Flutter** → Clic sur bouton Google/Facebook Mobile
   - L'utilisateur clique sur le bouton de connexion dans Flutter
   
2. **Flutter** → Ouvre `https://jirig.be/api/auth/google-mobile`
   - Flutter ouvre l'URL dans le navigateur externe
   - L'URL contient le paramètre `redirect_uri=jirig://oauth/callback`
   
3. **SNAL** → Redirige vers Google/Facebook OAuth avec callback vers SNAL
   - SNAL reçoit la requête et construit l'URL OAuth
   - Il redirige vers Google/Facebook avec les bons paramètres
   
4. **Google/Facebook** → Authentification responsable
   - L'utilisateur se connecte avec son compte Google/Facebook
   - Google/Facebook vérifie les identifiants
   
5. **Google/Facebook** → Redirige vers `https://jirig.be/api/auth/oauth-mobile-callback`
   - Google/Facebook redirige vers le callback de SNAL avec un code d'authentification
   
6. **SNAL** → Traite le callback et redirige vers `jirig://oauth/callback`
   - SNAL échange le code contre un token d'accès
   - Il récupère les informations utilisateur
   - Il redirige vers Flutter avec le deep link
   
7. **Flutter** → Reçoit le deep link et traite la connexion
   - Android intercepte le deep link `jirig://oauth/callback`
   - Flutter s'ouvre et traite la connexion réussie

## 🧪 Test étape par étape

**Comment tester cette implémentation :**

1. **Déployez les nouveaux endpoints sur SNAL**
   - Assurez-vous que les 3 fichiers sont créés et déployés
   - Vérifiez que les variables d'environnement sont configurées

2. **Testez avec Flutter en utilisant les nouvelles URLs**
   - Remplacez les anciennes méthodes OAuth par les nouvelles
   - Testez sur un appareil Android réel (les deep links ne fonctionnent pas sur émulateur)

3. **Vérifiez que les deep links fonctionnent correctement**
   - Testez que `jirig://oauth/callback` ouvre votre application
   - Vérifiez que les paramètres sont bien transmis

4. **Testez le flux complet de connexion**
   - Connectez-vous avec Google
   - Connectez-vous avec Facebook
   - Vérifiez que vous revenez bien dans Flutter

## 📝 Notes importantes

- **Séparation mobile/web** : Les endpoints mobiles sont séparés des endpoints web pour éviter les conflits
- **Deep links** : Le deep link `jirig://oauth/callback` permet de revenir à l'application Flutter
- **Paramètres state** : Les paramètres `state` permettent de passer des informations entre les étapes
- **Gestion d'erreur** : La gestion d'erreur est intégrée à chaque étape du processus
- **Variables d'environnement** : Assurez-vous que toutes les variables d'environnement sont correctement configurées

## 🚀 Avantages de cette approche

- ✅ **Redirection directe** vers l'application Flutter
- ✅ **Pas de redirection** vers le site web en production
- ✅ **Gestion d'erreur complète** à chaque étape
- ✅ **Séparation claire** entre mobile et web
- ✅ **Utilisation des deep links natifs** Android
- ✅ **Contrôle total** sur le flux OAuth

## 🎯 Résultat final

Cette implémentation vous donnera un contrôle complet sur le flux OAuth mobile et évitera les redirections indésirables vers le site web en production. Votre application Flutter recevra directement les redirections OAuth et pourra traiter la connexion de manière native.
