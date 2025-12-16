# Guide de Correction pour l'Authentification Facebook Mobile

Ce document décrit la solution technique pour implémenter correctement l'authentification Facebook dans un contexte d'application mobile Flutter, en utilisant un flux basé sur un token, et non un flux web basé sur des cookies.

## Problème Actuel

L'implémentation existante utilise un endpoint (`/api/auth/facebook-mobile`) qui initie un flux d'authentification OAuth2 web standard. Ce flux stocke la session utilisateur dans un cookie de navigateur (`connect.session`). Une application mobile ne peut pas accéder à ce cookie, ce qui rend la connexion impossible.

## Solution Proposée : Flux Basé sur le Token

Nous allons adopter la même stratégie que celle utilisée pour la connexion Google, qui est la méthode standard pour les applications mobiles.

**Le flux correct est le suivant :**
1.  **Flutter App** : Utilise un package natif (ici `flutter_facebook_auth`) pour communiquer avec le SDK de Facebook et obtenir un `access_token`.
2.  **Flutter App** : Envoie cet `access_token` au backend via une requête `POST` sur un nouvel endpoint dédié.
3.  **Backend** : Reçoit le token, le valide côté serveur en interrogeant l'API Graph de Facebook.
4.  **Backend** : Si le token est valide, récupère les informations de l'utilisateur, le crée ou le met à jour en base de données via la procédure stockée `dbo.proc_user_signup_4All_user_v2`.
5.  **Backend** : Retourne les informations de session (`iProfile`, `iBasket`, etc.) à l'application Flutter dans une réponse JSON.
6.  **Flutter App** : Reçoit les données de session et finalise la connexion de l'utilisateur.

---

## Étape 1 : Modification du Backend (`SNAL-Project`)

### Créer un Nouvel Endpoint pour la Validation du Token

Il faut créer un nouveau fichier pour gérer la validation du token reçu de l'application mobile.

**Fichier à créer :** `SNAL-Project/server/api/auth/facebook-mobile-token.post.ts`

```typescript
// SNAL-Project/server/api/auth/facebook-mobile-token.post.ts

import { defineEventHandler, readBody } from 'h3';
import { dbo } from '../../../db/dbo'; // Assurez-vous que le chemin est correct

interface FacebookDebugTokenResponse {
  data: {
    app_id: string;
    type: string;
    application: string;
    data_access_expires_at: number;
    expires_at: number;
    is_valid: boolean;
    scopes: string[];
    user_id: string;
  };
}

interface FacebookUserResponse {
  id: string;
  name: string;
  email?: string;
  picture?: {
    data: {
      height: number;
      is_silhouette: boolean;
      url: string;
      width: number;
    };
  };
}

export default defineEventHandler(async (event) => {
  try {
    const { token } = await readBody(event);

    if (!token) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Token manquant' }),
      };
    }

    // Secrets à stocker dans votre .env
    const FB_APP_ID = process.env.NUXT_OAUTH_FACEBOOK_CLIENT_ID;
    const FB_APP_SECRET = process.env.NUXT_OAUTH_FACEBOOK_CLIENT_SECRET;
    const FB_APP_TOKEN = `${FB_APP_ID}|${FB_APP_SECRET}`; // Ou un token d'application généré

    // 1. Valider le token d'accès auprès de Facebook
    const debugUrl = `https://graph.facebook.com/debug_token?input_token=${token}&access_token=${FB_APP_TOKEN}`;
    const debugResponse: FacebookDebugTokenResponse = await $fetch(debugUrl);

    if (!debugResponse.data.is_valid || debugResponse.data.app_id !== FB_APP_ID) {
      throw new Error('Token Facebook invalide ou ne correspond pas à l\'application.');
    }

    const userId = debugResponse.data.user_id;

    // 2. Récupérer les informations de l'utilisateur
    const userUrl = `https://graph.facebook.com/${userId}?fields=id,name,email,picture.type(large)&access_token=${token}`;
    const userData: FacebookUserResponse = await $fetch(userUrl);

    // 3. Appeler la procédure stockée pour créer/connecter l'utilisateur
    //    Le format est basé sur l'implémentation de google-mobile.get.ts
    const result = await dbo.proc_user_signup_4All_user_v2(
      userData.email || '',       // sEmail
      userData.name || '',        // sName
      '',                         // sFirstName
      '',                         // sPassword
      '',                         // sLogin
      'FACEBOOK',                 // sType -> Indique la méthode de connexion
      userData.id,                // sSocialNetworkID
      userData.picture?.data.url || '', // sPicture
      '',                         // sGender
      null,                       // dBirthDate
      '',                         // sAddress
      '',                         // sZipCode
      '',                         // sCity
      0,                          // iCountry
      0,                          // iMobileOS
      'FR',                       // sLanguage
      0                           // iCustomer
    );
    
    // Le résultat de la procédure stockée contient iProfile, iBasket, etc.
    const userProfile = result[0][0];

    if (!userProfile || !userProfile.iProfile) {
        throw new Error("La création ou la connexion de l'utilisateur a échoué.");
    }
    
    // 4. Retourner les informations de session en JSON
    return {
      statusCode: 200,
      user: userProfile,
    };

  } catch (error) {
    console.error("Erreur lors de l'authentification Facebook mobile:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message || 'Erreur interne du serveur' }),
    };
  }
});
```

---

## Étape 2 : Modification du Frontend (`podium_app`)

### Mettre à jour la Logique de Connexion

Modifiez la fonction `_loginWithFacebook` pour utiliser le package `flutter_facebook_auth` et appeler le nouvel endpoint.

**Fichier à modifier :** `podium_app/lib/screens/login_screen.dart`

```dart
// podium_app/lib/screens/login_screen.dart

import 'package.flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ... autres imports

class _LoginScreenState extends State<LoginScreen> {

  // ...

  Future<void> _loginWithFacebook() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Lancer la connexion avec le SDK natif de Facebook
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      // 2. Vérifier si la connexion a réussi
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        print("Token Facebook obtenu: ${accessToken.token}");

        // 3. Envoyer le token au backend
        final response = await http.post(
          Uri.parse('https://jirig.be/api/auth/facebook-mobile-token'), // URL du nouvel endpoint
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': accessToken.token}),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Succès ! Gérer la réponse de connexion
          // Le format exact dépend de ce que votre backend retourne.
          // Ici, on suppose une structure comme { "user": { "iProfile": ..., "iBasket": ... } }
          print("Réponse du backend : $data");
          final userProfile = data['user'];

          // VÉRIFIEZ ET ADAPTEZ la logique ci-dessous selon la structure de votre réponse
          if (userProfile != null && userProfile['iProfile'] != null) {
            // Logique pour sauvegarder la session et naviguer vers la page d'accueil
            // Par exemple:
            // await _sessionService.save(userProfile);
            // Navigator.of(context).pushReplacementNamed('/home');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connexion Facebook réussie!'))
            );
          } else {
             throw Exception('Les données utilisateur sont invalides.');
          }
        } else {
          // Gérer les erreurs du backend
          throw Exception('Erreur du serveur: ${response.body}');
        }

      } else {
        // Gérer les cas où l'utilisateur annule ou échoue la connexion
        print('Statut de la connexion Facebook: ${result.status}');
        print('Message: ${result.message}');
        throw Exception('La connexion Facebook a été annulée ou a échoué.');
      }
    } catch (e) {
      print("Erreur lors de la connexion Facebook: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ... reste de la classe
}
```

Ce guide fournit tous les éléments nécessaires pour refactoriser l'authentification Facebook et la rendre fonctionnelle sur mobile.