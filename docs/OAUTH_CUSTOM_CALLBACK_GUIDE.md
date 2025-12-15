# 📘 Guide : Créer un Endpoint Callback OAuth Personnalisé dans SNAL

## 📅 Date : 16 octobre 2025

Ce guide explique comment créer un endpoint personnalisé dans SNAL pour rediriger vers votre app Flutter après authentification OAuth (Google/Facebook) **sans pointer vers l'URL de production**.

---

## 🎯 OBJECTIF

Créer un endpoint dans SNAL qui :
1. ✅ Reçoit la redirection depuis Google/Facebook OAuth
2. ✅ Définit les cookies de session SNAL
3. ✅ Redirige vers l'app Flutter locale (`http://localhost:PORT`)
4. ✅ Fonctionne en développement sans affecter la production

---

## 🛠️ SOLUTION : Endpoint `/api/auth/dev-callback`

### **Concept**

Créer un endpoint spécial dans SNAL qui :
- Est utilisé **uniquement en développement**
- Accepte un paramètre `redirectUrl` pour l'app Flutter
- Configure le profil utilisateur et les cookies
- Redirige vers l'app Flutter locale

---

## 📝 IMPLÉMENTATION DANS SNAL

### **Étape 1 : Créer le fichier `dev-callback.get.ts`**

📁 Chemin : `SNAL-Project/server/api/auth/dev-callback.get.ts`

```typescript
import { defineEventHandler, getQuery, sendRedirect } from "h3";

/**
 * Endpoint de callback OAuth pour développement Flutter
 * 
 * Utilisation :
 * Configurer Google/Facebook OAuth pour rediriger vers :
 * https://jirig.be/api/auth/dev-callback?token=XXX&redirectUrl=http://localhost:3000/oauth/callback
 * 
 * ⚠️ NE PAS UTILISER EN PRODUCTION
 */
export default defineEventHandler(async (event) => {
  console.log('\n' + '='.repeat(70));
  console.log('🔐 DEV CALLBACK - Redirection OAuth vers Flutter');
  console.log('='.repeat(70));

  try {
    const query = getQuery(event);
    
    // Récupérer l'URL de redirection Flutter
    const redirectUrl = query.redirectUrl as string | undefined;
    const defaultRedirect = 'http://localhost:3000/oauth/callback';
    const flutterUrl = redirectUrl || defaultRedirect;

    console.log(`📱 URL de redirection Flutter: ${flutterUrl}`);

    // Vérifier que l'URL est bien localhost (sécurité)
    if (!flutterUrl.startsWith('http://localhost') && 
        !flutterUrl.startsWith('http://127.0.0.1')) {
      console.error(`❌ URL de redirection non autorisée: ${flutterUrl}`);
      return sendRedirect(event, '/?error=invalid_redirect_url');
    }

    // La session utilisateur est déjà configurée par l'endpoint OAuth standard
    // On peut récupérer les infos depuis la session
    const userSession = await getUserSession(event);
    
    if (!userSession || !userSession.user) {
      console.error('❌ Aucune session utilisateur trouvée');
      return sendRedirect(event, '/login?error=no_session');
    }

    console.log(`✅ Utilisateur connecté: ${userSession.user.sEmail}`);
    console.log(`✅ iProfile: ${userSession.user.iProfile}`);

    // Rediriger vers Flutter avec les paramètres nécessaires
    const callbackParams = new URLSearchParams({
      success: 'true',
      provider: query.provider as string || 'google',
    });

    const finalUrl = `${flutterUrl}?${callbackParams.toString()}`;
    
    console.log(`🌐 Redirection finale: ${finalUrl}`);
    console.log('='.repeat(70) + '\n');

    return sendRedirect(event, finalUrl);

  } catch (error: any) {
    console.error('❌ Erreur lors du callback dev:', error);
    return sendRedirect(event, '/login?error=callback_failed');
  }
});
```

---

### **Étape 2 : Modifier les endpoints OAuth Google et Facebook**

#### **Option A : Créer des endpoints de dev séparés**

📁 `SNAL-Project/server/api/auth/google-dev.get.ts`

```typescript
import { connectToDatabase } from "../../db/index";
import sql from "mssql";
import {
  defineEventHandler,
  getQuery,
  createError,
} from "h3";
import { useAppCookies } from "~/composables/useAppCookies";

export default defineOAuthGoogleEventHandler({
  async onSuccess(event, { user }) {
    try {
      console.log('🔐 Google OAuth Dev - Utilisateur:', user.email);

      // ... (même logique que google.get.ts pour créer le profil) ...
      
      const { setGuestProfile } = useAppCookies(event);
      
      // Définir le profil et les cookies
      setGuestProfile({
        iProfile: profileData.iProfileEncrypted,
        iBasket: profileData.iBasketProfil,
        sPaysLangue: profileData.sPaysLangue,
      });

      // Définir la session utilisateur
      await setUserSession(event, {
        user: {
          iProfile: profileData.iProfile,
          sNom: profileData.sNom,
          sPrenom: profileData.sPrenom,
          sEmail: profileData.sEmail,
          // ... autres champs ...
        },
        loggedInAt: Date.now(),
        loggedIn: true,
      });

      // Récupérer le redirectUrl depuis les query params
      const query = getQuery(event);
      const redirectUrl = query.redirectUrl as string || 'http://localhost:3000/oauth/callback';

      console.log(`✅ Redirection vers: ${redirectUrl}`);

      // Rediriger vers le dev-callback avec le redirectUrl
      return sendRedirect(
        event, 
        `/api/auth/dev-callback?redirectUrl=${encodeURIComponent(redirectUrl)}&provider=google`
      );

    } catch (error: any) {
      console.error("Erreur Google OAuth Dev:", error);
      throw createError({
        statusCode: 500,
        message: "Erreur lors de l'authentification",
      });
    }
  },
  
  onError(event, error: any) {
    console.error("Google OAuth Dev error:", error);
    return sendRedirect(event, "/login?error=google_oauth_failed");
  },
});
```

#### **Option B : Modifier l'endpoint existant avec condition**

📁 `SNAL-Project/server/api/auth/google.get.ts`

```typescript
export default defineOAuthGoogleEventHandler({
  async onSuccess(event, { user }) {
    try {
      // ... (logique existante de création de profil) ...

      // Vérifier si c'est un appel de dev (via query param)
      const query = getQuery(event);
      const isDev = query.dev === 'true';
      const redirectUrl = query.redirectUrl as string;

      if (isDev && redirectUrl) {
        console.log('🔧 Mode développement détecté');
        console.log(`📱 Redirection dev vers: ${redirectUrl}`);
        
        // Rediriger vers dev-callback
        return sendRedirect(
          event,
          `/api/auth/dev-callback?redirectUrl=${encodeURIComponent(redirectUrl)}&provider=google`
        );
      }

      // Comportement normal (production)
      return sendRedirect(event, "/");

    } catch (error: any) {
      // ... gestion d'erreur ...
    }
  },
});
```

---

## 🔧 CONFIGURATION FLUTTER

### **Modifier `oauth_handler.dart`**

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html show window;
import '../services/local_storage_service.dart';

class OAuthHandler {
  static Future<void> authenticate({
    required String authUrl,
    String? callBackUrl,
  }) async {
    print('🔐 OAuth - Authentification via: $authUrl');
    
    // Sauvegarder le callBackUrl
    if (callBackUrl != null && callBackUrl.isNotEmpty) {
      await LocalStorageService.saveCallBackUrl(callBackUrl);
      print('💾 CallBackUrl sauvegardé: $callBackUrl');
    }
    
    // 🆕 Construire l'URL avec les paramètres de dev
    final devAuthUrl = _buildDevAuthUrl(authUrl);
    
    if (kIsWeb) {
      print('🌐 Web - Redirection vers: $devAuthUrl');
      html.window.location.href = devAuthUrl;
    } else {
      print('📱 Mobile - Ouverture navigateur: $devAuthUrl');
      final uri = Uri.parse(devAuthUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Impossible d\'ouvrir l\'URL: $devAuthUrl');
      }
    }
  }

  /// 🆕 Construire l'URL OAuth avec paramètres de dev
  static String _buildDevAuthUrl(String baseUrl) {
    // Détecter le port Flutter actuel
    final currentPort = html.window.location.port;
    final flutterCallbackUrl = 'http://localhost:$currentPort/oauth/callback';
    
    // Ajouter les paramètres dev et redirectUrl
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    
    // Mode développement
    params['dev'] = 'true';
    params['redirectUrl'] = flutterCallbackUrl;
    
    return uri.replace(queryParameters: params).toString();
  }
}
```

### **Modifier `login_screen.dart`**

```dart
Future<void> _loginWithGoogle() async {
  print('🔐 Connexion avec Google');
  try {
    // URL SNAL avec endpoint de dev
    String authUrl = 'https://jirig.be/api/auth/google';
    
    print('🌐 Redirection vers: $authUrl');
    
    await OAuthHandler.authenticate(
      authUrl: authUrl,
      callBackUrl: widget.callBackUrl ?? '/wishlist',
    );
  } catch (e) {
    print('❌ Erreur connexion Google: $e');
    setState(() {
      _errorMessage = 'Erreur lors de la connexion avec Google';
    });
  }
}
```

---

## 🔄 FLUX COMPLET

### **Avec l'endpoint dev-callback :**

```
1. User clique "Connexion Google" dans Flutter (localhost:PORT)
   ↓
2. Flutter sauvegarde callBackUrl dans localStorage
   ↓
3. Flutter redirige vers:
   https://jirig.be/api/auth/google?dev=true&redirectUrl=http://localhost:PORT/oauth/callback
   ↓
4. SNAL détecte dev=true
   ↓
5. Google OAuth standard
   ↓
6. SNAL crée session et cookies
   ↓
7. SNAL redirige vers:
   https://jirig.be/api/auth/dev-callback?redirectUrl=http://localhost:PORT/oauth/callback
   ↓
8. dev-callback vérifie la session
   ↓
9. dev-callback redirige vers:
   http://localhost:PORT/oauth/callback?success=true&provider=google
   ↓
10. Flutter OAuthCallbackScreen affiche popup succès
   ↓
11. Redirection vers /wishlist (ou callBackUrl)
```

---

## ⚠️ SÉCURITÉ

### **1. Validation de l'URL de redirection**

```typescript
// Dans dev-callback.get.ts
const ALLOWED_REDIRECT_PATTERNS = [
  /^http:\/\/localhost:\d+/,
  /^http:\/\/127\.0\.0\.1:\d+/,
  /^http:\/\/192\.168\.\d+\.\d+:\d+/, // LAN
];

function isValidRedirectUrl(url: string): boolean {
  return ALLOWED_REDIRECT_PATTERNS.some(pattern => pattern.test(url));
}

if (!isValidRedirectUrl(redirectUrl)) {
  console.error(`❌ URL non autorisée: ${redirectUrl}`);
  return sendRedirect(event, '/?error=invalid_redirect_url');
}
```

### **2. Désactiver en production**

```typescript
// Ajouter au début de dev-callback.get.ts
const isDevelopment = process.env.NODE_ENV === 'development';

if (!isDevelopment) {
  console.error('❌ dev-callback appelé en production');
  return sendRedirect(event, '/');
}
```

### **3. Variable d'environnement**

```typescript
// .env
ENABLE_DEV_OAUTH_CALLBACK=true

// Dans dev-callback.get.ts
if (process.env.ENABLE_DEV_OAUTH_CALLBACK !== 'true') {
  return sendRedirect(event, '/');
}
```

---

## 🧪 TESTS

### **1. Test local**

```bash
# Terminal 1 - SNAL
cd SNAL-Project
npm run dev

# Terminal 2 - Flutter
cd jirig
flutter run -d chrome
```

### **2. Vérifier les cookies**

Dans DevTools → Application → Cookies :
- ✅ `GuestProfile` doit être défini
- ✅ `auth.session-token` doit être présent
- ✅ Domaine : `localhost`

### **3. Vérifier les logs**

```
# SNAL
🔐 Google OAuth Dev - Utilisateur: user@email.com
✅ Redirection vers: http://localhost:52432/oauth/callback

# Flutter
🎯 OAuth Callback reçu
✅ Utilisateur connecté
🔄 Redirection vers: /wishlist
```

---

## 📌 AVANTAGES

1. ✅ **Développement local** : Fonctionne avec `localhost`
2. ✅ **Cookies corrects** : SNAL gère les cookies de session
3. ✅ **Sécurisé** : Validation des URLs de redirection
4. ✅ **Flexible** : Paramètres dynamiques (port, callBackUrl)
5. ✅ **Isolé** : N'affecte pas la production

---

## 📌 INCONVÉNIENTS

1. ⚠️ **Modification SNAL** : Nécessite d'ajouter du code dans SNAL
2. ⚠️ **Maintenance** : Garder sync entre Flutter et SNAL
3. ⚠️ **Configuration OAuth** : Peut nécessiter d'ajouter `localhost` dans les redirects autorisés Google/Facebook

---


**Pour la production mobile :**
- ✅ Créer l'endpoint `dev-callback` dans SNAL
- Permet de rediriger vers l'app mobile installée via deep links

**Configuration Google OAuth :**
```
Authorized redirect URIs:
- https://jirig.be/api/auth/google (production)
- http://localhost:3000/api/auth/dev-callback (dev web)
- jirig://oauth/callback (mobile app avec deep link)
```

---

## 🔗 RESSOURCES

- [Nuxt Auth Utils](https://github.com/Atinux/nuxt-auth-utils)
- [Google OAuth Guide](https://developers.google.com/identity/protocols/oauth2)
- [Flutter Deep Links](https://docs.flutter.dev/development/ui/navigation/deep-linking)

