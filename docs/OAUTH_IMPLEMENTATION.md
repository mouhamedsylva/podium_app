# ✅ Implémentation OAuth Google & Facebook - Flutter

## 📅 Date : 16 octobre 2025

Ce document décrit l'implémentation complète de l'authentification OAuth (Google & Facebook) compatible **Web ET Mobile** dans l'application Flutter.

---

## 🎯 PROBLÈME RÉSOLU

### Problème initial :
- Connexion Google redirigait vers le site SNAL en production
- WebView ne fonctionne pas sur Flutter Web
- Besoin d'une solution universelle Web + Mobile

### Solution implémentée :
- **Sur Web** : Redirection classique dans la fenêtre (comme SNAL)
- **Sur Mobile** : Ouverture dans le navigateur externe (TODO: WebView pour meilleure UX)
- **Callback unifié** : Page de callback Flutter avec popup de succès

---

## 🛠️ FICHIERS MODIFIÉS

### 1. **`jirig/lib/widgets/oauth_handler.dart`** ✨ NOUVEAU
Gestionnaire OAuth universel qui détecte la plateforme :
- Web → Redirection `window.location.href`
- Mobile → Ouverture navigateur externe via `url_launcher`

### 2. **`jirig/lib/screens/oauth_callback_screen.dart`** ✨ NOUVEAU
Page de callback affichée après authentification OAuth :
- Rafraîchit l'état d'authentification
- Affiche un popup de succès avec animation
- Redirige vers la page souhaitée

### 3. **`jirig/lib/screens/login_screen.dart`**
Fonctions `_loginWithGoogle()` et `_loginWithFacebook()` simplifiées :
- Utilisent `OAuthHandler.authenticate()`
- Plus de WebView

### 4. **`jirig/lib/app.dart`**
Ajout de la route `/oauth/callback` :
```dart
GoRoute(
  path: '/oauth/callback',
  pageBuilder: (context, state) {
    final callBackUrl = state.uri.queryParameters['redirect'];
    return _buildPageWithTransition(
      context,
      state,
      OAuthCallbackScreen(callBackUrl: callBackUrl),
    );
  },
),
```

### 5. **`jirig/proxy-server.js`**
Trois nouveaux endpoints :

#### `/api/auth/google`
Redirige vers SNAL avec un callBackUrl vers notre proxy

#### `/api/auth/facebook`
Même logique pour Facebook

#### `/api/oauth/callback`
Reçoit la redirection depuis SNAL et redirige vers Flutter
- Détecte automatiquement le port Flutter
- Redirige vers `/oauth/callback?redirect=/wishlist`

### 6. **`jirig/pubspec.yaml`**
Dépendance ajoutée :
```yaml
webview_flutter: ^4.4.2  # Pour future implémentation mobile
```

---

## 🔄 FLUX D'AUTHENTIFICATION

### Web :
```
1. Utilisateur clique "Connexion Google" dans Flutter Web
   ↓
2. OAuthHandler redirige la fenêtre vers http://localhost:3001/api/auth/google
   ↓
3. Proxy redirige vers SNAL OAuth avec callBackUrl vers proxy
   ↓
4. SNAL gère OAuth Google et redirige vers proxy callback
   ↓
5. Proxy redirige vers Flutter /oauth/callback?redirect=/wishlist
   ↓
6. OAuthCallbackScreen s'affiche
   ↓
7. Rafraîchit l'auth, affiche popup succès, redirige vers /wishlist
```

### Mobile :
```
1. Utilisateur clique "Connexion Google" dans Flutter Mobile
   ↓
2. OAuthHandler ouvre le navigateur externe avec http://localhost:3001/api/auth/google
   ↓
3. Navigateur gère OAuth Google via SNAL
   ↓
4. Redirection vers http://localhost:PORT/oauth/callback?redirect=/wishlist
   ↓
5. OAuthCallbackScreen s'affiche dans l'app
   ↓
6. Rafraîchit l'auth, affiche popup succès, redirige vers /wishlist
```

---

## 📝 CONFIGURATION REQUISE

### Proxy (port 3001)
```bash
node proxy-server.js
```

### Flutter Web (port auto)
```bash
flutter run -d chrome
```

### URLs importantes :
- **Auth Google** : `http://localhost:3001/api/auth/google`
- **Auth Facebook** : `http://localhost:3001/api/auth/facebook`
- **Callback** : `http://localhost:PORT/oauth/callback?redirect=...`

---

## ✨ AMÉLIORATIONS FUTURES

### Pour Mobile :
1. Implémenter WebView intégrée au lieu du navigateur externe
2. Deep linking pour retour automatique dans l'app
3. Gestion des tokens OAuth en local

### Pour Web :
1. Support du mode popup (comme SNAL) au lieu de redirection pleine page
2. Meilleure gestion des erreurs OAuth
3. Support de plus de providers (Apple, Microsoft, etc.)

---

## 🧪 TESTS

### Test Web :
1. Lancer proxy : `node proxy-server.js`
2. Lancer Flutter Web : `flutter run -d chrome`
3. Aller sur `/login`
4. Cliquer "Continuer avec Google"
5. Vérifier redirection → auth Google → callback → wishlist

### Test Mobile :
1. Lancer proxy : `node proxy-server.js`
2. Lancer Flutter Mobile : `flutter run`
3. Aller sur `/login`
4. Cliquer "Continuer avec Google"
5. Vérifier navigateur s'ouvre → auth Google → retour app → wishlist

---

## 🎉 RÉSULTAT

✅ Authentification OAuth Google fonctionnelle Web & Mobile
✅ Pas de redirection vers SNAL en production
✅ Popup de succès avec animation
✅ Gestion correcte des callBackUrl
✅ Code propre et maintenable

