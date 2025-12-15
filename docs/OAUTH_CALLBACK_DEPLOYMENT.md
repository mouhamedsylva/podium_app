# 🚀 Déploiement de la page OAuth Callback

## 📋 Vue d'ensemble

Pour que la connexion OAuth via navigateur externe fonctionne correctement, nous devons déployer la page `oauth-callback.html` sur le serveur de production `https://jirig.be`.

---

## 📁 Fichier à déployer

**Fichier source :** `jirig/web/oauth-callback.html`  
**Destination :** `https://jirig.be/oauth-callback.html`

---

## 🔄 Flux de connexion OAuth

### Avant (problématique) :
```
1. App → Navigateur externe → https://jirig.be/api/auth/google
2. Google OAuth → https://jirig.be/ (production)
3. ❌ Utilisateur reste sur le site web
```

### Après (solution) :
```
1. App → Navigateur externe → https://jirig.be/api/auth/google?callBackUrl=...
2. Google OAuth → https://jirig.be/oauth-callback.html?redirect=...
3. Page intermédiaire → Deep link jirig://oauth/callback?redirect=...
4. ✅ App s'ouvre et redirige vers la page souhaitée
```

---

## 🛠️ Instructions de déploiement

### 1. **Copier le fichier**
```bash
# Copier oauth-callback.html vers le serveur web
scp jirig/web/oauth-callback.html user@jirig.be:/var/www/html/
```

### 2. **Vérifier l'accès**
```bash
# Tester l'accès à la page
curl https://jirig.be/oauth-callback.html
```

### 3. **Tester le deep link**
```bash
# Test du deep link (sur Android)
adb shell am start -W -a android.intent.action.VIEW -d "jirig://oauth/callback?redirect=/wishlist"
```

---

## 🧪 Tests à effectuer

### **Test 1 : Page intermédiaire**
1. Ouvrir `https://jirig.be/oauth-callback.html?redirect=/wishlist`
2. Vérifier que la page s'affiche correctement
3. Cliquer sur "Ouvrir l'application"
4. Vérifier que l'app s'ouvre

### **Test 2 : Connexion Google complète**
1. Dans l'app, appuyer sur "Connexion Google"
2. Choisir "Ouvrir dans le navigateur"
3. Se connecter avec Google
4. Vérifier la redirection vers la page intermédiaire
5. Vérifier l'ouverture de l'app

### **Test 3 : Deep link direct**
```bash
adb shell am start -W -a android.intent.action.VIEW -d "jirig://oauth/callback?redirect=/wishlist"
```

---

## 🔧 Configuration serveur

### **Nginx (si utilisé)**
```nginx
# Ajouter dans la configuration nginx
location /oauth-callback.html {
    try_files $uri =404;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
}
```

### **Apache (si utilisé)**
```apache
# Ajouter dans .htaccess
<Files "oauth-callback.html">
    Header set Cache-Control "no-cache, no-store, must-revalidate"
    Header set Pragma "no-cache"
    Header set Expires "0"
</Files>
```

---

## ✅ Vérification du déploiement

### **Checklist :**
- [ ] Fichier `oauth-callback.html` accessible sur `https://jirig.be/oauth-callback.html`
- [ ] Page s'affiche correctement avec le design Jirig
- [ ] Bouton "Ouvrir l'application" fonctionne
- [ ] Deep link `jirig://` est capturé par l'app
- [ ] Redirection vers la page souhaitée fonctionne
- [ ] Tests sur Android et iOS (si disponible)

---

## 🚨 Dépannage

### **La page ne s'affiche pas**
- Vérifier que le fichier est bien copié sur le serveur
- Vérifier les permissions du fichier (644)
- Vérifier la configuration du serveur web

### **Le deep link ne fonctionne pas**
- Vérifier l'AndroidManifest.xml (intent-filter `jirig://`)
- Vérifier que l'app est installée
- Tester avec `adb shell am start...`

### **L'app ne se redirige pas**
- Vérifier les logs de l'app Flutter
- Vérifier que le DeepLinkService est initialisé
- Vérifier la route de redirection

---

## 🎯 Résultat attendu

Après déploiement, la connexion OAuth via navigateur externe devrait :

1. ✅ Ouvrir le navigateur externe
2. ✅ Permettre la connexion Google/Facebook
3. ✅ Rediriger vers la page intermédiaire
4. ✅ Proposer d'ouvrir l'app
5. ✅ Ouvrir l'app et rediriger vers la page souhaitée

**Plus d'erreur "Erreur 403: disallowed_useragent" !** 🎉
