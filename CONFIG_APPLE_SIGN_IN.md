# Configuration Apple Sign-In avec Xcode

## ⚠️ Prérequis
- Mac avec Xcode installé
- iPhone/iPad physique (Apple Sign-In ne fonctionne pas sur simulateur)
- Compte Apple Developer (gratuit suffit)

---

## 🔧 Configuration Xcode

### 1. Ouvrir le projet
```bash
cd podium_app
open ios/Runner.xcworkspace
```

### 2. Configurer Signing & Capabilities
1. Sélectionner le target **Runner**
2. Onglet **Signing & Capabilities**
3. Cocher **Automatically manage signing**
4. Sélectionner votre **Team**
5. Noter le **Bundle Identifier** (ex: `com.example.jirig`)

### 3. Ajouter Sign In with Apple
1. Cliquer **+ Capability**
2. Ajouter **Sign In with Apple**

---

## 🍎 Configuration Apple Developer Portal

### 1. Accéder au portal
https://developer.apple.com/account/

### 2. Configurer l'App ID
1. **Certificates, Identifiers & Profiles** → **Identifiers**
2. Sélectionner votre **App ID** (ou créer un nouveau)
3. Vérifier que le **Bundle ID** correspond à Xcode
4. Cocher **Sign In with Apple**
5. **Save**

---

## 🔌 Vérifier le Backend

Dans SNAL-Project, vérifier que `NUXT_APPLE_CLIENT_ID` est configuré :
- Doit correspondre au **Bundle ID** de votre app
- Format : `com.example.jirig`

---

## 📱 Tester sur appareil

### 1. Connecter l'iPhone
- Connecter via USB
- Déverrouiller l'appareil

### 2. Installer l'app
1. Dans Xcode, sélectionner votre appareil comme destination
2. Cliquer **Run** (▶️) ou `Cmd + R`
3. Autoriser l'installation sur l'appareil si demandé

### 3. Tester la connexion
1. Ouvrir l'app sur l'iPhone
2. Aller sur l'écran de connexion
3. Cliquer **Continuer avec Apple**
4. S'authentifier (Face ID/Touch ID/Code)
5. Vérifier la redirection

---

## ✅ Checklist

- [ ] Sign In with Apple capability ajoutée dans Xcode
- [ ] Bundle ID correspond entre Xcode et Developer Portal
- [ ] App ID configuré avec Sign In with Apple dans Developer Portal
- [ ] `NUXT_APPLE_CLIENT_ID` configuré dans le backend
- [ ] App installée sur appareil physique
- [ ] Bouton Apple visible sur l'écran de connexion
- [ ] Authentification Apple fonctionne
- [ ] Connexion réussie et redirection OK

---

## 🐛 Erreur 1000 ?

**Cause** : Configuration manquante

**Solution** :
1. Vérifier que Sign In with Apple est activé dans Xcode
2. Vérifier que l'App ID est configuré dans Developer Portal
3. Nettoyer et rebuilder :
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```

---

**Note** : Apple Sign-In nécessite un appareil physique iOS. Le simulateur ne fonctionne pas.

