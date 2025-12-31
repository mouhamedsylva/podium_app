# 🔐 Guide Vérification SHA-1 - Google Sign-In

## ✅ SHA-1 Récupéré

D'après votre commande `keytool`, voici le SHA-1 de votre **keystore release** :

```
SHA-1: 65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73
```

**Keystore** : `android/app/monapp-release.jks`  
**Alias** : `monapp`  
**Type** : Release (pour production/Play Store)

---

## 🔍 Différence SHA-1 Debug vs Release

### SHA-1 Debug
- **Keystore** : `~/.android/debug.keystore` (généré automatiquement)
- **Utilisé pour** : Tests en développement, builds debug
- **SHA-1** : Généralement `2A:F2:7F:26:C8:C7:44:B3:E7:A4:5F:30:CD:2B:C7:BB:1D:27:AA:4D` (standard Android)

### SHA-1 Release
- **Keystore** : `android/app/monapp-release.jks` (votre keystore personnalisé)
- **Utilisé pour** : Builds release, APK/AAB pour Play Store
- **SHA-1** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` ✅

---

## ⚠️ Important : Quel SHA-1 Utiliser ?

### Pour un APK Release (votre cas)

**Vous devez utiliser le SHA-1 Release** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

**Pourquoi ?**
- Vous avez buildé un APK release (`flutter build apk --release`)
- L'APK est signé avec `monapp-release.jks`
- Google Sign-In vérifie le SHA-1 de l'APK signé
- Le SHA-1 doit correspondre à celui configuré dans Google Cloud Console

---

## ✅ Configuration Google Cloud Console

### Étape 1 : Créer/Modifier le Client OAuth Android

1. **Allez sur [Google Cloud Console](https://console.cloud.google.com/)**
2. **APIs & Services** → **Credentials**
3. **Trouvez ou créez un client OAuth Android**

### Étape 2 : Configurer avec les Bonnes Informations

**Si vous créez un nouveau client :**
- **Type** : Android
- **Name** : `Jirig Android Release`
- **Package name** : `be.jirig.app` ⚠️ **IMPORTANT : Le nouveau package name**
- **SHA-1 certificate fingerprint** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

**Si vous modifiez un client existant :**
- Vérifiez que le **Package name** est `be.jirig.app`
- Vérifiez que le **SHA-1** est `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- **Si le SHA-1 est différent**, ajoutez ce nouveau SHA-1 (vous pouvez avoir plusieurs SHA-1)

---

## 🔍 Vérification dans Google Cloud Console

### Vérifier les SHA-1 Configurés

Dans Google Cloud Console, pour chaque client OAuth Android, vous devriez voir :

**Client 1 : Debug (si vous testez aussi en debug)**
- Package name : `be.jirig.app`
- SHA-1 : `2A:F2:7F:26:C8:C7:44:B3:E7:A4:5F:30:CD:2B:C7:BB:1D:27:AA:4D` (debug)

**Client 2 : Release (pour production)**
- Package name : `be.jirig.app`
- SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` ✅ (release)

**OU un seul client avec les deux SHA-1 :**
- Package name : `be.jirig.app`
- SHA-1 : 
  - `2A:F2:7F:26:C8:C7:44:B3:E7:A4:5F:30:CD:2B:C7:BB:1D:27:AA:4D` (debug)
  - `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` (release) ✅

---

## 🎯 Action Immédiate

### 1. Vérifier dans Google Cloud Console

1. **Ouvrez Google Cloud Console**
2. **APIs & Services** → **Credentials**
3. **Trouvez le client OAuth Android** (ou créez-en un nouveau)
4. **Vérifiez :**
   - Package name : `be.jirig.app` ✅
   - SHA-1 : Contient `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` ✅

### 2. Si le SHA-1 n'est pas présent

**Option A : Ajouter le SHA-1 au client existant**
- Cliquez sur le client OAuth Android
- Cliquez sur "Edit"
- Ajoutez le SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`
- Sauvegardez

**Option B : Créer un nouveau client**
- Créez un nouveau client OAuth Android
- Package name : `be.jirig.app`
- SHA-1 : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`

### 3. Si le Package name est incorrect

**Vous DEVEZ créer un nouveau client OAuth Android** avec le bon package name :
- Ancien package name : `com.example.jirig` ou `com.jirig.app` ❌
- Nouveau package name : `be.jirig.app` ✅

**Pourquoi ?** Google ne permet pas de modifier le package name d'un client OAuth existant.

---

## 📝 Résumé

| Élément | Valeur | Statut |
|---------|--------|--------|
| **Keystore Release** | `monapp-release.jks` | ✅ |
| **SHA-1 Release** | `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` | ✅ |
| **Package Name** | `be.jirig.app` | ✅ |
| **Google Cloud Console** | À vérifier/mettre à jour | ⚠️ |

---

## ✅ Checklist Finale

Avant de retester, vérifiez :

- [ ] ✅ SHA-1 `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73` est dans Google Cloud Console
- [ ] ✅ Package name `be.jirig.app` est dans Google Cloud Console
- [ ] ✅ Web Client ID correspond à celui dans le code
- [ ] ✅ Attendu 5-10 minutes après modification (propagation Google)
- [ ] ✅ Rebuild l'APK : `flutter clean && flutter build apk --release`
- [ ] ✅ Réinstaller et tester

---

**Date de création** : $(date)  
**SHA-1 Release** : `65:D3:66:02:89:66:19:1C:18:2B:F8:DA:23:C7:4D:0D:31:9E:9A:73`  
**Package Name** : `be.jirig.app`  
**Statut** : ✅ SHA-1 récupéré - Configuration Google Cloud Console à vérifier

