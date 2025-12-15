# 🧪 Guide de test OAuth - Web et Mobile

## 📋 Vue d'ensemble

Ce guide explique comment tester la connexion OAuth Google/Facebook sur différentes plateformes après les modifications.

---

## 🌐 **TEST 1 : Navigateur Web (Desktop)**

### **Comportement attendu :**
1. Clic sur "Connexion Google" → Ouvre le navigateur externe
2. Connexion Google → Redirige vers `https://jirig.be/oauth-callback.html`
3. Page intermédiaire → Propose "Continuer sur l'app web"
4. Clic → Redirige vers `/wishlist` dans l'app web

### **Test à effectuer :**
```bash
# 1. Démarrer l'app web
flutter run -d chrome

# 2. Aller sur la page de connexion
# 3. Cliquer sur "Connexion Google"
# 4. Choisir "Ouvrir dans le navigateur"
# 5. Se connecter avec Google
# 6. Vérifier la redirection vers oauth-callback.html
# 7. Vérifier la redirection vers l'app web
```

---

## 📱 **TEST 2 : Mobile (Android/iOS)**

### **Comportement attendu :**
1. Clic sur "Connexion Google" → Dialogue de choix
2. Choisir "Ouvrir dans le navigateur" → Ouvre Chrome/Safari
3. Connexion Google → Redirige vers `https://jirig.be/oauth-callback.html`
4. Page intermédiaire → Propose "Ouvrir l'application"
5. Clic → Deep link `jirig://oauth/callback` → Ouvre l'app
6. App → Redirige vers `/wishlist`

### **Test à effectuer :**
```bash
# 1. Compiler et installer l'app
flutter build apk --debug
flutter install

# 2. Ouvrir l'app
# 3. Aller sur la page de connexion
# 4. Cliquer sur "Connexion Google"
# 5. Choisir "Ouvrir dans le navigateur"
# 6. Se connecter avec Google
# 7. Vérifier la redirection vers oauth-callback.html
# 8. Vérifier l'ouverture de l'app via deep link
# 9. Vérifier la redirection vers /wishlist
```

---

## 🔗 **TEST 3 : Deep Link Direct**

### **Test du deep link :**
```bash
# Test sur Android
adb shell am start -W -a android.intent.action.VIEW -d "jirig://oauth/callback?redirect=/wishlist"

# Test sur iOS (simulateur)
xcrun simctl openurl booted "jirig://oauth/callback?redirect=/wishlist"
```

### **Comportement attendu :**
- L'app s'ouvre
- Affiche l'écran de callback OAuth
- Redirige vers `/wishlist` après traitement

---

## 🌐 **TEST 4 : Page Intermédiaire**

### **Test direct de la page :**
```bash
# Ouvrir dans le navigateur
https://jirig.be/oauth-callback.html?redirect=/wishlist
```

### **Comportements selon le contexte :**

#### **Desktop (Chrome/Firefox) :**
- Titre : "Connexion réussie !"
- Message : "Voulez-vous continuer sur l'application web Jirig ?"
- Bouton : "Continuer sur l'app web"
- Bouton secondaire : "Télécharger l'app mobile"

#### **Mobile (Chrome/Safari) :**
- Titre : "Connexion réussie !"
- Message : "Vous êtes maintenant connecté à Jirig. Voulez-vous ouvrir l'application ?"
- Bouton : "Ouvrir l'application"
- Bouton secondaire : "Continuer sur le site"

#### **App Web (PWA) :**
- Titre : "Connexion réussie !"
- Message : "Vous allez être redirigé vers l'application..."
- Redirection automatique après 2 secondes

---

## 🔧 **DÉPANNAGE**

### **Problème : La page oauth-callback.html ne s'affiche pas**
```bash
# Vérifier que le fichier est déployé
curl https://jirig.be/oauth-callback.html

# Vérifier les logs du serveur
tail -f /var/log/nginx/error.log
```

### **Problème : Le deep link ne fonctionne pas**
```bash
# Vérifier l'AndroidManifest.xml
grep -A 10 "jirig://" android/app/src/main/AndroidManifest.xml

# Tester le deep link
adb shell am start -W -a android.intent.action.VIEW -d "jirig://oauth/callback?redirect=/wishlist"
```

### **Problème : L'app ne se redirige pas**
```bash
# Vérifier les logs Flutter
flutter logs

# Vérifier que la route existe
grep -A 5 "/oauth/callback" lib/app.dart
```

---

## 📊 **RÉSULTATS ATTENDUS**

### **✅ Succès :**
- [ ] Connexion Google sans erreur 403
- [ ] Redirection vers oauth-callback.html
- [ ] Interface adaptée selon le contexte
- [ ] Deep link fonctionne sur mobile
- [ ] Redirection vers l'app web sur desktop
- [ ] Redirection vers l'app mobile sur mobile

### **❌ Échecs courants :**
- [ ] Erreur 403: disallowed_useragent (résolu)
- [ ] Page oauth-callback.html non trouvée
- [ ] Deep link ne s'ouvre pas
- [ ] Redirection incorrecte
- [ ] Interface non adaptée

---

## 🚀 **DÉPLOIEMENT**

### **1. Déployer oauth-callback.html :**
```bash
# Copier vers le serveur
scp web/oauth-callback.html user@jirig.be:/var/www/html/

# Vérifier l'accès
curl https://jirig.be/oauth-callback.html
```

### **2. Compiler et déployer l'app :**
```bash
# Android
flutter build apk --release
flutter install

# Web
flutter build web
# Déployer le dossier build/web/
```

---

## 🎯 **CHECKLIST FINALE**

- [ ] Page oauth-callback.html déployée et accessible
- [ ] App compilée et installée
- [ ] Deep links configurés dans AndroidManifest.xml
- [ ] Routes ajoutées dans app.dart
- [ ] Tests effectués sur toutes les plateformes
- [ ] Aucune erreur 403 Google
- [ ] Redirections fonctionnelles

**Résultat : Connexion OAuth fluide sur toutes les plateformes !** 🎉
