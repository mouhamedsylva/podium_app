# 🔗 Configuration des Deep Links (Magic Links)

## 📋 Vue d'ensemble

Ce document explique comment les **Magic Links** (liens magiques depuis email) fonctionnent dans l'application Flutter Jirig pour Android.

---

## ✅ Configuration complète

### 1. **Package installé**
```yaml
# pubspec.yaml
dependencies:
  app_links: ^6.4.1  # Gestion des deep links (remplace uni_links obsolète)
```

### 2. **AndroidManifest.xml configuré**
```xml
<!-- Intent filter pour capturer les liens https://jirig.be/connexion -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    
    <data
        android:scheme="https"
        android:host="jirig.be"
        android:pathPrefix="/connexion"/>
</intent-filter>

<!-- Intent filter pour capturer les liens https://jirig.be/ (racine) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    
    <data
        android:scheme="https"
        android:host="jirig.be"/>
</intent-filter>
```

### 3. **Service de Deep Links créé**
- Fichier : `lib/services/deep_link_service.dart`
- Écoute les liens entrants
- Affiche un dialogue de confirmation
- Redirige vers `/magic-login`

### 4. **Page MagicLoginScreen créée**
- Fichier : `lib/screens/magic_login_screen.dart`
- Valide le token via API
- Sauvegarde le profil dans LocalStorage
- Redirige vers le `callBackUrl`

### 5. **Route ajoutée dans app.dart**
```dart
GoRoute(
  path: '/magic-login',
  pageBuilder: (context, state) {
    final email = state.uri.queryParameters['email'] ?? '';
    final token = state.uri.queryParameters['token'] ?? '';
    final callBackUrl = state.uri.queryParameters['callBackUrl'];
    
    return _buildPageWithTransition(
      context,
      state,
      MagicLoginScreen(
        email: email,
        token: token,
        callBackUrl: callBackUrl,
      ),
    );
  },
),
```

---

## 🧪 Comment tester

### **Méthode 1 : Via Email (Production)**
1. Demandez un lien magique depuis l'écran de connexion
2. Ouvrez votre email sur votre téléphone Android
3. Cliquez sur le lien magique
4. Android devrait afficher : "Ouvrir avec Jirig / Navigateur"
5. Choisissez "Jirig"
6. L'app s'ouvre et affiche le dialogue de confirmation
7. Cliquez sur "Oui"
8. Vous êtes connecté et redirigé vers votre wishlist

### **Méthode 2 : Via ADB (Test Local)**
```bash
# Assurez-vous que votre téléphone est connecté en USB avec le débogage activé

# Tester avec un lien complet
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://jirig.be/connexion?email=test@example.com&token=TEST-TOKEN-123&callBackUrl=%2Fwishlist%2F0x12345"

# Ou avec un lien simple
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://jirig.be/connexion?email=test@example.com&token=TEST-TOKEN-123"
```

### **Méthode 3 : Via un fichier HTML local**
Créez un fichier `test_deep_link.html` :
```html
<!DOCTYPE html>
<html>
<head>
    <title>Test Deep Link Jirig</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial; padding: 20px;">
    <h1>Test Deep Link Jirig</h1>
    <p>Cliquez sur le lien ci-dessous depuis votre téléphone Android :</p>
    
    <a href="https://jirig.be/connexion?email=test@example.com&token=ECE7E50F-0EF5-40F9-8DF8-4441264E3A23&callBackUrl=%2Fwishlist%2F0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5">
        🔗 Magic Link Test
    </a>
    
    <br><br>
    <p style="color: gray; font-size: 12px;">
        Ce lien devrait ouvrir l'application Jirig si elle est installée.
    </p>
</body>
</html>
```

Envoyez ce fichier par email à vous-même, ouvrez-le sur votre téléphone et cliquez sur le lien.

---

## 🔄 Flux de fonctionnement

```
1. Utilisateur clique sur le lien dans son email
   ↓
2. Android détecte le lien https://jirig.be/connexion
   ↓
3. Android affiche : "Ouvrir avec Jirig / Navigateur"
   ↓
4. Utilisateur choisit "Jirig"
   ↓
5. L'app Flutter s'ouvre (ou passe au premier plan si déjà ouverte)
   ↓
6. DeepLinkService détecte le lien via app_links
   ↓
7. Un dialogue s'affiche : "Souhaitez-vous ouvrir ce lien dans l'application ?"
   ↓
8. Si "Oui" → Navigation vers /magic-login avec les paramètres
   ↓
9. MagicLoginScreen valide le token via API
   ↓
10. Si succès → Sauvegarde du profil + Redirection vers callBackUrl
```

---

## 📝 Logs à surveiller

Lors du test, vous devriez voir ces logs dans la console Flutter :

```
🔗 === INITIALISATION DEEP LINK SERVICE ===
🔗 Deep link initial détecté: https://jirig.be/connexion?email=...&token=...
🔗 === TRAITEMENT DEEP LINK ===
🔗 Lien complet: https://jirig.be/connexion?email=...
🔗 URI parsée:
   - Scheme: https
   - Host: jirig.be
   - Path: /connexion
   - Query params: {email: ..., token: ..., callBackUrl: ...}
✅ Magic Link détecté !
📧 Email: test@example.com
🎫 Token: ECE7E50F-0EF5-40F9-8DF8-4441264E3A23
🔄 CallBackUrl: /wishlist/0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5
✅ Utilisateur a accepté d'ouvrir le lien
🔄 Navigation vers: /magic-login?email=test@example.com&token=...
🔐 === VALIDATION MAGIC LINK ===
📧 Email: test@example.com
🎫 Token: ECE7E50F-0EF5-40F9-8DF8-4441264E3A23
✅ Magic link validé avec succès !
💾 Profil sauvegardé dans LocalStorage
🔄 Redirection vers: /wishlist/0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5
```

---

## ⚠️ Dépannage

### **Le lien s'ouvre dans le navigateur au lieu de l'app**
1. Vérifiez que l'app est bien installée sur le téléphone
2. Redémarrez le téléphone
3. Réinstallez l'application
4. Vérifiez l'AndroidManifest.xml (l'intent-filter doit être dans la balise `<activity>` principale)

### **L'app s'ouvre mais aucun dialogue n'apparaît**
1. Vérifiez les logs de la console Flutter
2. Assurez-vous que `app_links` est bien installé (`flutter pub get`)
3. Vérifiez que le `DeepLinkService` est bien initialisé dans `app.dart`

### **Erreur "Lien invalide"**
1. Vérifiez que l'URL contient bien `email` et `token`
2. Vérifiez que le format est : `https://jirig.be/connexion?email=...&token=...`

### **Erreur de validation du token**
1. Vérifiez que le token est encore valide (pas expiré)
2. Vérifiez les logs de l'API
3. Vérifiez que l'endpoint `/api/auth/login` fonctionne

---

## 🎯 Exemple de lien complet

```
https://jirig.be/connexion?email=thicosylva@gmail.com&token=ECE7E50F-0EF5-40F9-8DF8-4441264E3A23&callBackUrl=%2Fwishlist%2F0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5
```

**Décomposition :**
- `https://jirig.be/connexion` → Capturé par l'intent-filter Android
- `email=thicosylva@gmail.com` → Email de l'utilisateur
- `token=ECE7E50F-0EF5-40F9-8DF8-4441264E3A23` → Token de validation
- `callBackUrl=%2Fwishlist%2F0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5` → URL encodée de redirection (`/wishlist/0x...`)

---

## 🚀 Prochaines étapes

Pour tester :

1. **Compilez et installez l'app sur Android** :
   ```bash
   flutter build apk --debug
   flutter install
   ```

2. **Testez avec ADB** :
   ```bash
   adb shell am start -W -a android.intent.action.VIEW \
     -d "https://jirig.be/connexion?email=test@example.com&token=TEST-123"
   ```

3. **Vérifiez les logs Flutter** :
   ```bash
   flutter logs
   ```

4. **Testez avec un vrai email** :
   - Demandez un lien magique depuis l'écran de connexion
   - Ouvrez l'email sur votre téléphone
   - Cliquez sur le lien

---

## ✨ Résultat final

Quand tout fonctionne correctement :

1. ✅ Clic sur le lien dans l'email
2. ✅ Android propose "Ouvrir avec Jirig"
3. ✅ L'app s'ouvre
4. ✅ Dialogue : "Souhaitez-vous ouvrir ce lien dans l'application ?"
5. ✅ Clic sur "Oui"
6. ✅ Validation du token automatique
7. ✅ Connexion réussie
8. ✅ Redirection vers la wishlist
9. ✅ L'utilisateur est connecté ! 🎉

---

## 📚 Fichiers modifiés

- ✅ `pubspec.yaml` - Ajout du package uni_links
- ✅ `android/app/src/main/AndroidManifest.xml` - Intent filter ajouté
- ✅ `lib/services/deep_link_service.dart` - Service créé
- ✅ `lib/screens/magic_login_screen.dart` - Page créée
- ✅ `lib/app.dart` - Route et initialisation ajoutées

---

**Tout est prêt ! 🎉** Vous pouvez maintenant compiler et tester votre application.

