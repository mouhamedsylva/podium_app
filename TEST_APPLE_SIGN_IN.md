# Guide de Test - Connexion Apple Sign-In sur Appareil Physique iOS

## ⚠️ Important

**Apple Sign-In ne fonctionne PAS sur le simulateur iOS.** Vous devez absolument tester sur un **appareil iOS physique** (iPhone ou iPad).

---

## 📋 Prérequis

### Matériel
- ✅ iPhone ou iPad physique (iOS 13.0 ou supérieur)
- ✅ Câble USB pour connecter l'appareil à votre Mac
- ✅ Compte Apple Developer (gratuit suffit pour tester)

### Logiciel
- ✅ Xcode installé (dernière version recommandée)
- ✅ Flutter SDK installé
- ✅ CocoaPods installé (`sudo gem install cocoapods`)

### Backend
- ✅ Backend SNAL-Project accessible à `https://jirig.be/api`
- ✅ Variable d'environnement `NUXT_APPLE_CLIENT_ID` configurée dans le backend

---

## 🔧 Étape 1 : Configuration Xcode

### 1.1 Ouvrir le projet iOS

```bash
cd podium_app
open ios/Runner.xcworkspace
```

⚠️ **Important** : Utiliser `.xcworkspace` et non `.xcodeproj`

### 1.2 Configurer le Signing

1. Dans Xcode, sélectionner le projet **Runner** dans le navigateur de gauche
2. Sélectionner le target **Runner**
3. Aller dans l'onglet **Signing & Capabilities**
4. Cocher **Automatically manage signing**
5. Sélectionner votre **Team** (votre compte Apple Developer)
6. Vérifier que le **Bundle Identifier** est correct (ex: `com.example.jirig`)

### 1.3 Ajouter la Capability "Sign In with Apple"

1. Toujours dans **Signing & Capabilities**
2. Cliquer sur le bouton **+ Capability** (en haut à gauche)
3. Rechercher et ajouter **Sign In with Apple**
4. La capability devrait apparaître dans la liste

### 1.4 Vérifier la configuration

Vérifier que vous voyez :
- ✅ **Signing Certificate** : Votre certificat de développement
- ✅ **Provisioning Profile** : Profil généré automatiquement
- ✅ **Sign In with Apple** : Capability présente

---

## 🍎 Étape 2 : Configuration Apple Developer Portal

### 2.1 Accéder au Developer Portal

1. Aller sur https://developer.apple.com/account/
2. Se connecter avec votre compte Apple Developer

### 2.2 Configurer l'App ID

1. Aller dans **Certificates, Identifiers & Profiles**
2. Cliquer sur **Identifiers** dans le menu de gauche
3. Sélectionner votre **App ID** (ou en créer un nouveau)
4. Vérifier que le **Bundle ID** correspond à celui dans Xcode
5. Cocher **Sign In with Apple** dans la liste des capabilities
6. Cliquer sur **Save**

### 2.3 Vérifier la configuration

- ✅ App ID configuré avec Sign In with Apple
- ✅ Bundle ID correspond à celui dans Xcode
- ✅ Status : Active

---

## 🔌 Étape 3 : Vérifier le Backend

### 3.1 Vérifier l'endpoint

L'endpoint backend doit être accessible :
```
GET https://jirig.be/api/auth/apple-mobile?identity_token=TOKEN
```

### 3.2 Vérifier la variable d'environnement

Dans le backend SNAL-Project, vérifier que `NUXT_APPLE_CLIENT_ID` est configuré :
- Doit correspondre au **Service ID** ou **App ID** configuré dans Apple Developer Portal
- Format : `com.example.jirig` (votre Bundle ID)

---

## 📱 Étape 4 : Installer l'application sur l'appareil

### 4.1 Connecter l'appareil

1. Connecter votre iPhone/iPad à votre Mac via USB
2. Déverrouiller l'appareil
3. Faire confiance à l'ordinateur si demandé

### 4.2 Configurer l'appareil dans Xcode

1. Dans Xcode, en haut de la fenêtre, cliquer sur le menu déroulant des destinations
2. Sélectionner votre appareil iOS (il devrait apparaître dans la liste)
3. Si l'appareil n'apparaît pas :
   - Vérifier que le câble USB est bien connecté
   - Vérifier que l'appareil est déverrouillé
   - Aller dans **Window > Devices and Simulators** pour voir l'appareil

### 4.3 Installer les dépendances Flutter

```bash
cd podium_app
flutter pub get
cd ios
pod install
cd ..
```

### 4.4 Build et Run

1. Dans Xcode, cliquer sur le bouton **Run** (▶️) ou appuyer sur `Cmd + R`
2. Xcode va compiler et installer l'application sur votre appareil
3. La première fois, vous devrez peut-être autoriser l'installation sur l'appareil :
   - Aller dans **Réglages > Général > Gestion des appareils**
   - Faire confiance à votre certificat de développement

---

## 🧪 Étape 5 : Test du flux de connexion

### 5.1 Ouvrir l'application

1. Sur votre appareil, ouvrir l'application **Jirig**
2. Naviguer vers l'écran de connexion

### 5.2 Vérifier la présence du bouton Apple

✅ **Le bouton "Continuer avec Apple" doit être visible** (uniquement sur iOS)

Si le bouton n'apparaît pas :
- Vérifier que vous êtes bien sur iOS (`Platform.isIOS`)
- Vérifier que le package `sign_in_with_apple` est installé
- Vérifier les logs dans Xcode Console

### 5.3 Tester la connexion

1. **Cliquer sur le bouton "Continuer avec Apple"**
2. Le dialogue Apple Sign-In devrait s'afficher
3. **Choisir une option** :
   - Utiliser un compte Apple existant
   - Créer un nouveau compte Apple
   - Utiliser un compte masqué (Hide My Email)
4. **S'authentifier** avec :
   - Face ID
   - Touch ID
   - Code Apple
5. **Autoriser** l'application à utiliser votre email (si demandé)

### 5.4 Vérifier le résultat

Après l'authentification, vous devriez :
- ✅ Voir un popup de succès (check vert)
- ✅ Être redirigé vers la page souhaitée (par défaut `/wishlist`)
- ✅ Être connecté (vérifier dans le profil)

---

## 📊 Étape 6 : Vérifier les logs

### 6.1 Ouvrir la Console Xcode

Dans Xcode, aller dans **View > Debug Area > Activate Console** (ou `Cmd + Shift + Y`)

### 6.2 Logs attendus

Vous devriez voir dans la console :

```
🍎 === DÉBUT CONNEXION APPLE ===
📱 === ÉTAPE 1: Demande de connexion Apple Sign-In ===
✅ Credential Apple obtenu
   User ID: 001234.abc123def456.7890
   Email: user@example.com
   Identity Token: eyJraWQiOiJlWGF1...
📱 === ÉTAPE 2: Appel API /api/auth/apple-mobile ===
📡 URL complète: https://jirig.be/api/auth/apple-mobile?identity_token=...
🔐 Connexion avec Apple Mobile - identityToken: eyJraWQiOiJlWGF1...
✅ Réponse apple-mobile: {status: success, iProfile: ..., iBasket: ..., email: ...}
✅ Connexion Apple réussie
📱 === ÉTAPE 3: Traitement de la réponse ===
📢 Notification de la connexion à AuthNotifier...
✅ AuthNotifier notifié
📱 === ÉTAPE 4: Redirection interne dans l'app ===
🔄 Redirection interne vers: /wishlist
✅ Redirection interne effectuée vers: /wishlist
```

### 6.3 Logs d'erreur possibles

Si vous voyez des erreurs :

**Erreur "Identity token non disponible"**
- L'authentification Apple a échoué
- Réessayer la connexion

**Erreur "Missing Apple identity_token" (400)**
- Le token n'a pas été envoyé correctement
- Vérifier les logs pour voir si le token est présent

**Erreur "Invalid Apple token" (401)**
- Le token est invalide ou expiré
- Vérifier que `NUXT_APPLE_CLIENT_ID` est correct dans le backend

**Erreur réseau**
- Vérifier la connexion internet de l'appareil
- Vérifier que `https://jirig.be/api` est accessible

---

## ✅ Checklist de vérification

### Configuration
- [ ] Xcode configuré avec Sign In with Apple capability
- [ ] Bundle ID correspond entre Xcode et Apple Developer Portal
- [ ] App ID configuré avec Sign In with Apple dans Developer Portal
- [ ] Backend accessible à `https://jirig.be/api`
- [ ] `NUXT_APPLE_CLIENT_ID` configuré dans le backend

### Installation
- [ ] Appareil iOS physique connecté
- [ ] Application installée sur l'appareil
- [ ] Application fonctionne correctement

### Test
- [ ] Bouton "Continuer avec Apple" visible sur l'écran de connexion
- [ ] Dialogue Apple Sign-In s'affiche correctement
- [ ] Authentification réussie (Face ID/Touch ID/Code)
- [ ] Popup de succès affiché
- [ ] Redirection vers la page souhaitée
- [ ] Utilisateur connecté (vérifier dans le profil)
- [ ] Logs dans Xcode Console montrent le flux complet

### Données
- [ ] `iProfile` sauvegardé dans le localStorage
- [ ] `iBasket` sauvegardé dans le localStorage
- [ ] Email sauvegardé (si fourni par Apple)
- [ ] Cookies synchronisés avec le backend

---

## 🐛 Dépannage

### Le bouton Apple n'apparaît pas

**Cause** : Le bouton n'apparaît que sur iOS

**Solution** :
- Vérifier que vous testez sur un appareil iOS physique
- Vérifier que `Platform.isIOS` retourne `true`
- Vérifier que le package est installé : `flutter pub get`

### Erreur "Sign In with Apple capability not enabled"

**Cause** : La capability n'est pas activée dans Xcode

**Solution** :
1. Ouvrir Xcode
2. Aller dans Signing & Capabilities
3. Ajouter la capability "Sign In with Apple"

### Erreur "Invalid client" ou "Invalid Apple token"

**Cause** : Configuration incorrecte dans Apple Developer Portal ou backend

**Solution** :
1. Vérifier que le Bundle ID correspond entre Xcode et Developer Portal
2. Vérifier que `NUXT_APPLE_CLIENT_ID` dans le backend correspond au Bundle ID
3. Vérifier que Sign In with Apple est activé pour l'App ID dans Developer Portal

### Erreur réseau lors de l'appel API

**Cause** : Problème de connexion ou configuration API

**Solution** :
1. Vérifier la connexion internet de l'appareil
2. Vérifier que `ApiConfig.baseUrl` pointe vers `https://jirig.be/api`
3. Vérifier que le backend est accessible depuis l'appareil

### L'authentification Apple fonctionne mais la redirection échoue

**Cause** : Problème avec le callback URL ou la navigation

**Solution** :
1. Vérifier les logs pour voir si `iProfile` et `iBasket` sont bien reçus
2. Vérifier que `AuthNotifier.onLogin()` est appelé
3. Vérifier que le `callBackUrl` est correct

---

## 📝 Notes importantes

### Première connexion vs Connexions suivantes

- **Première connexion** : Apple peut fournir l'email et le nom complet
- **Connexions suivantes** : Apple ne fournit généralement que l'email (si autorisé)

### Compte masqué (Hide My Email)

Apple permet aux utilisateurs d'utiliser un email masqué. Dans ce cas :
- L'email retourné sera un email Apple masqué (ex: `xxxxx@privaterelay.appleid.com`)
- Le backend doit gérer ce cas normalement

### Expiration du token

L'`identityToken` Apple expire rapidement. Le flux doit être rapide :
1. Récupération du token
2. Appel API immédiat
3. Sauvegarde des identifiants

---

## 🎯 Test de régression

Après avoir testé la connexion Apple, vérifier que :

1. ✅ Les autres méthodes de connexion fonctionnent toujours (Email, Google, Facebook)
2. ✅ La déconnexion fonctionne correctement
3. ✅ Le profil utilisateur s'affiche correctement
4. ✅ Les fonctionnalités de l'app fonctionnent avec un compte Apple connecté

---

## 📞 Support

Si vous rencontrez des problèmes :

1. **Vérifier les logs** dans Xcode Console
2. **Vérifier la configuration** dans Apple Developer Portal
3. **Vérifier le backend** : logs serveur et configuration
4. **Vérifier la documentation** : [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)

---

**Bon test ! 🍎**

