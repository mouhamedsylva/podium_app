# 📧 Déploiement des Magic Links

## 📋 Vue d'ensemble

Pour que les magic links fonctionnent correctement et redirigent vers l'app au lieu du site de production, nous devons déployer la page `magic-link-callback.html` sur le serveur.

---

## 📁 Fichier à déployer

**Fichier source :** `jirig/web/magic-link-callback.html`  
**Destination :** `https://jirig.be/magic-link-callback.html`

---

## 🔄 Flux des Magic Links

### Avant (problématique) :
```
1. Email → Magic link https://jirig.be/connexion?email=...&token=...
2. Clic → Site de production (reste sur le site)
3. ❌ Utilisateur ne revient pas dans l'app
```

### Après (solution) :
```
1. Email → Magic link https://jirig.be/connexion?email=...&token=...
2. Clic → Deep link détecté par l'app
3. App → Page intermédiaire https://jirig.be/magic-link-callback.html
4. Page → Deep link jirig://magic-login?email=...&token=...
5. App → Validation du token et redirection
```

---

## 🛠️ Instructions de déploiement

### 1. **Copier le fichier**
```bash
# Copier magic-link-callback.html vers le serveur web
scp jirig/web/magic-link-callback.html user@jirig.be:/var/www/html/
```

### 2. **Vérifier l'accès**
```bash
# Tester l'accès à la page
curl https://jirig.be/magic-link-callback.html
```

### 3. **Tester le deep link**
```bash
# Test du deep link magic-login (sur Android)
adb shell am start -W -a android.intent.action.VIEW -d "jirig://magic-login?email=test@example.com&token=TEST-123&callBackUrl=/wishlist"
```

---

## 🧪 Tests à effectuer

### **Test 1 : Page intermédiaire**
1. Ouvrir `https://jirig.be/magic-link-callback.html?email=test@example.com&token=TEST-123&redirect=/wishlist`
2. Vérifier que la page s'affiche correctement
3. Vérifier que l'email est affiché
4. Cliquer sur "Ouvrir l'application"
5. Vérifier que l'app s'ouvre

### **Test 2 : Magic Link complet**
1. Demander un magic link depuis l'app
2. Ouvrir l'email sur le téléphone
3. Cliquer sur le magic link
4. Vérifier que l'app s'ouvre
5. Vérifier la redirection vers la page souhaitée

### **Test 3 : Deep link direct**
```bash
adb shell am start -W -a android.intent.action.VIEW -d "jirig://magic-login?email=test@example.com&token=TEST-123&callBackUrl=/wishlist"
```

---

## 🔧 Configuration serveur

### **Nginx (si utilisé)**
```nginx
# Ajouter dans la configuration nginx
location /magic-link-callback.html {
    try_files $uri =404;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
}
```

### **Apache (si utilisé)**
```apache
# Ajouter dans .htaccess
<Files "magic-link-callback.html">
    Header set Cache-Control "no-cache, no-store, must-revalidate"
    Header set Pragma "no-cache"
    Header set Expires "0"
</Files>
```

---

## 📊 **RÉSULTATS ATTENDUS**

### **✅ Succès :**
- [ ] Magic link détecté par l'app
- [ ] Page intermédiaire s'affiche correctement
- [ ] Email affiché dans l'interface
- [ ] Deep link `jirig://magic-login` fonctionne
- [ ] Validation du token réussie
- [ ] Redirection vers la page souhaitée

### **❌ Échecs courants :**
- [ ] Magic link ouvre le navigateur au lieu de l'app
- [ ] Page intermédiaire non trouvée
- [ ] Deep link ne s'ouvre pas
- [ ] Token invalide ou expiré
- [ ] Redirection incorrecte

---

## 🚨 Dépannage

### **Le magic link ouvre le navigateur**
- Vérifier que l'app est installée
- Vérifier l'AndroidManifest.xml (intent-filter pour `/connexion`)
- Redémarrer l'app

### **La page intermédiaire ne s'affiche pas**
- Vérifier que le fichier est déployé
- Vérifier les permissions du fichier
- Vérifier la configuration du serveur

### **Le deep link ne fonctionne pas**
- Vérifier l'AndroidManifest.xml (intent-filter pour `magic-login`)
- Tester avec `adb shell am start...`
- Vérifier les logs de l'app

---

## 🎯 **Exemple de Magic Link**

### **Magic Link original :**
```
https://jirig.be/connexion?email=thicosylva@gmail.com&token=ECE7E50F-0EF5-40F9-8DF8-4441264E3A23&callBackUrl=%2Fwishlist%2F0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5
```

### **Page intermédiaire générée :**
```
https://jirig.be/magic-link-callback.html?email=thicosylva%40gmail.com&token=ECE7E50F-0EF5-40F9-8DF8-4441264E3A23&redirect=%2Fwishlist%2F0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5
```

### **Deep link final :**
```
jirig://magic-login?email=thicosylva%40gmail.com&token=ECE7E50F-0EF5-40F9-8DF8-4441264E3A23&callBackUrl=%2Fwishlist%2F0x020000003C2AB5591859F09ACCF2C09CEF56EE540EEAC2E5
```

---

## ✅ **CHECKLIST FINALE**

- [ ] Page `magic-link-callback.html` déployée et accessible
- [ ] App compilée et installée
- [ ] Deep links configurés dans AndroidManifest.xml
- [ ] Service de deep links mis à jour
- [ ] Tests effectués avec de vrais magic links
- [ ] Redirections fonctionnelles

**Résultat : Magic links redirigent vers l'app !** 🎉
