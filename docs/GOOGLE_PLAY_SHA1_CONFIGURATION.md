# 📱 SHA-1 pour Google Play Store - Configuration

## ❓ Question

**"Si je déploie mon app sous Google Play Store, dois-je changer le SHA-1 ?"**

---

## 🎯 Réponse Directe

**Cela dépend de votre configuration Google Play App Signing.**

Il y a **deux scénarios** possibles :

---

## 📊 Scénario 1 : Google Play App Signing DÉSACTIVÉ

### Configuration Actuelle

- **Keystore utilisé** : `monapp-release.jks`
- **SHA-1** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- **Vous signez l'APK/AAB** avec ce keystore avant l'upload

### Réponse

✅ **NON, vous ne devez PAS changer le SHA-1**

Le SHA-1 que vous avez (`65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`) est le bon et restera le même.

**Configuration Google Cloud Console :**
- Package name : `be.jirig.app`
- SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` ✅

---

## 📊 Scénario 2 : Google Play App Signing ACTIVÉ (Recommandé)

### Configuration

- **Google Play App Signing** : Activé (recommandé par Google)
- **Upload Key** : Votre keystore (`monapp-release.jks`) - utilisé pour signer l'APK/AAB avant upload
- **App Signing Key** : Généré par Google Play - utilisé pour signer l'APK final distribué aux utilisateurs

### Réponse

⚠️ **OUI, vous devez configurer DEUX SHA-1**

1. **SHA-1 Upload Key** (celui que vous avez) :
   - `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
   - Utilisé pour signer l'APK/AAB que vous uploadez

2. **SHA-1 App Signing Key** (généré par Google Play) :
   - Récupéré depuis Google Play Console
   - Utilisé pour signer l'APK final distribué aux utilisateurs

**Configuration Google Cloud Console :**
- Package name : `be.jirig.app`
- SHA-1 : 
  - `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` (Upload Key) ✅
  - `XX:XX:XX:...` (App Signing Key - à récupérer depuis Play Console) ✅

---

## 🔍 Comment Vérifier Votre Configuration

### Vérifier si Google Play App Signing est Activé

1. **Allez sur [Google Play Console](https://play.google.com/console)**
2. **Sélectionnez votre app**
3. **Allez dans** : **Release** → **Setup** → **App signing**
4. **Vérifiez le statut** :
   - **"App signing by Google Play"** → Activé ⚠️
   - **"App signing by you"** → Désactivé ✅

---

## 📝 Récupérer le SHA-1 App Signing Key (si activé)

### Méthode 1 : Depuis Google Play Console

1. **Google Play Console** → **Release** → **Setup** → **App signing**
2. **Section "App signing key certificate"**
3. **Copiez le SHA-1 certificate fingerprint**

### Méthode 2 : Depuis l'API Google Play

```bash
# Utiliser l'API Google Play pour récupérer le certificat
```

---

## ✅ Configuration Recommandée

### Pour Google Sign-In avec Google Play App Signing

**Configurez les DEUX SHA-1 dans Google Cloud Console :**

1. **SHA-1 Upload Key** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
   - Pour les tests avant publication
   - Pour les builds internes/alpha/beta

2. **SHA-1 App Signing Key** : (à récupérer depuis Play Console)
   - Pour les builds de production
   - Pour les utilisateurs finaux

**Comment ajouter plusieurs SHA-1 :**
- Dans Google Cloud Console, vous pouvez ajouter plusieurs SHA-1 au même client OAuth Android
- Cliquez sur "Edit" → Ajoutez chaque SHA-1 séparément

---

## 🎯 Action Immédiate

### Étape 1 : Vérifier Google Play App Signing

1. Allez sur Google Play Console
2. Vérifiez si "App signing by Google Play" est activé

### Étape 2 : Configurer Google Cloud Console

**Si Google Play App Signing est DÉSACTIVÉ :**
- ✅ Utilisez uniquement : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

**Si Google Play App Signing est ACTIVÉ :**
- ✅ Ajoutez les deux SHA-1 :
  - Upload Key : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
  - App Signing Key : (récupéré depuis Play Console)

---

## 📚 Informations Complémentaires

### Google Play App Signing - Avantages

- ✅ **Sécurité renforcée** : Google gère la clé de signature principale
- ✅ **Récupération en cas de perte** : Si vous perdez votre upload key, Google peut vous aider
- ✅ **Recommandé par Google** : Meilleure pratique

### Upload Key vs App Signing Key

| Type | Utilisation | SHA-1 |
|------|-------------|-------|
| **Upload Key** | Signer l'APK/AAB avant upload | `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` |
| **App Signing Key** | Signer l'APK final distribué | Récupéré depuis Play Console |

---

## ✅ Checklist Avant Publication

- [ ] ✅ SHA-1 Upload Key configuré dans Google Cloud Console
- [ ] ✅ SHA-1 App Signing Key configuré (si Google Play App Signing activé)
- [ ] ✅ Package name `be.jirig.app` configuré dans Google Cloud Console
- [ ] ✅ Web Client ID vérifié
- [ ] ✅ Android Client ID configuré dans SNAL `.env`
- [ ] ✅ Test de connexion Google réussi

---

## 🎯 Résumé

| Scénario | SHA-1 à Utiliser | Action |
|----------|------------------|--------|
| **App Signing DÉSACTIVÉ** | `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` | ✅ Utiliser tel quel |
| **App Signing ACTIVÉ** | Upload Key + App Signing Key | ⚠️ Ajouter les deux |

---

**Date de création** : $(date)  
**SHA-1 Upload Key** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`  
**Package Name** : `be.jirig.app`  
**Statut** : ⚠️ Vérifier Google Play App Signing

