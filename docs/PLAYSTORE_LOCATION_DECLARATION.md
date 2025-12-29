# 📱 Déclarations de Permissions - Google Play Store

## 📋 Table des matières
1. [Localisation en arrière-plan](#localisation-en-arrière-plan)
2. [Permissions READ_MEDIA_IMAGES et READ_MEDIA_VIDEO](#permissions-read_media_images-et-read_media_video)

---

# 1. Localisation en arrière-plan

## ❓ Question du Play Store

**"Expliquez-nous pourquoi votre application accède aux données de localisation en arrière-plan."**

---

## ✅ Réponse Recommandée

### Version Courte (pour le formulaire Play Store)

**Notre application n'accède PAS aux données de localisation en arrière-plan.**

L'application Jirig utilise uniquement la localisation **"while in use"** (pendant l'utilisation) pour les fonctionnalités suivantes :

1. **Affichage de la carte interactive** : Lorsque l'utilisateur ouvre la fonctionnalité de carte dans l'application, nous récupérons sa position GPS une seule fois pour :
   - Centrer la carte sur sa position actuelle
   - Afficher les magasins IKEA à proximité
   - Permettre la recherche de magasins par localisation

2. **Recherche de magasins** : La localisation est utilisée uniquement lorsque l'utilisateur interagit activement avec la fonctionnalité de carte pour trouver des magasins IKEA près de chez lui.

**Aucune fonctionnalité ne nécessite un suivi continu ou en arrière-plan.** La localisation est demandée uniquement lorsque l'utilisateur ouvre explicitement la carte et uniquement pendant que l'application est au premier plan.

---

## 📋 Version Détaillée (si nécessaire)

### Contexte de l'Application

Jirig est une application de comparaison de prix IKEA qui permet aux utilisateurs de :
- Comparer les prix des produits IKEA entre différents pays européens
- Scanner des codes QR de produits en magasin
- Gérer une liste de souhaits
- Trouver des magasins IKEA à proximité

### Utilisation de la Localisation

**Permission utilisée :** `ACCESS_FINE_LOCATION` et `ACCESS_COARSE_LOCATION` uniquement

**Permission NON utilisée :** `ACCESS_BACKGROUND_LOCATION` (retirée du manifest)

### Fonctionnalités Utilisant la Localisation

1. **Carte Interactive des Magasins IKEA**
   - **Quand** : Uniquement lorsque l'utilisateur ouvre la modal de carte depuis la wishlist
   - **Comment** : Appel ponctuel à `Geolocator.getCurrentPosition()` (une seule fois)
   - **But** : Centrer la carte sur la position de l'utilisateur et afficher les magasins à proximité
   - **Durée** : Requête unique, pas de suivi continu

2. **Recherche de Magasins par Localisation**
   - **Quand** : Uniquement lorsque l'utilisateur clique sur le bouton "Ma position" dans la carte
   - **Comment** : Appel ponctuel à `Geolocator.getCurrentPosition()` à la demande
   - **But** : Permettre à l'utilisateur de trouver rapidement les magasins IKEA les plus proches
   - **Durée** : Requête unique, pas de suivi continu

### Preuves Techniques

- ✅ Aucun `getPositionStream()` dans le code (pas de suivi continu)
- ✅ Aucun service en arrière-plan utilisant la localisation
- ✅ Aucune notification basée sur la localisation
- ✅ La permission `ACCESS_BACKGROUND_LOCATION` a été retirée du manifest
- ✅ Utilisation uniquement de `getCurrentPosition()` (requête ponctuelle)

### Conformité

- ✅ Conforme aux politiques Google Play concernant la localisation
- ✅ Utilisation minimale et transparente de la localisation
- ✅ Permission demandée uniquement au moment de l'utilisation
- ✅ L'utilisateur peut refuser la permission sans impact sur les autres fonctionnalités

---

## 🔧 Action Technique Effectuée

La permission `ACCESS_BACKGROUND_LOCATION` a été **retirée** du fichier `AndroidManifest.xml` car elle n'est pas nécessaire pour le fonctionnement de l'application.

**Avant :**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

**Après :**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- ACCESS_BACKGROUND_LOCATION retirée - non utilisée -->
```

---

## 📝 Notes pour le Développeur

1. **Rebuild de l'application** : Après cette modification, reconstruire l'APK/AAB
2. **Test** : Vérifier que la carte fonctionne toujours correctement
3. **Soumission** : Utiliser la version courte pour répondre au Play Store

---

**Date de mise à jour** : $(date)  
**Version de l'app** : 1.0.0+1  
**Statut** : ✅ Permission retirée, prêt pour soumission

---

# 2. Permissions READ_MEDIA_IMAGES et READ_MEDIA_VIDEO

## ❓ Questions du Play Store

**"Décrivez l'utilisation de l'autorisation READ_MEDIA_IMAGES par votre Application."**  
**"Décrivez l'utilisation de l'autorisation READ_MEDIA_VIDEO par votre appli."**

---

## ✅ Réponse Recommandée

### Version Courte (pour le formulaire Play Store)

**Notre application n'accède PAS aux images ou vidéos stockées sur l'appareil de l'utilisateur.**

Les permissions `READ_MEDIA_IMAGES` et `READ_MEDIA_VIDEO` ont été **retirées** du manifest Android car elles ne sont pas nécessaires.

L'application Jirig utilise uniquement :

1. **Cache temporaire privé de l'application** : Pour créer des fichiers PDF temporaires lors du partage de la wishlist. Ces fichiers sont créés dans le répertoire de cache privé de l'application (accessible uniquement par l'app) et ne nécessitent pas d'accès aux médias de l'utilisateur.

2. **Images depuis le réseau** : L'application charge uniquement des images depuis le serveur (URLs d'images de produits IKEA) via le réseau. Aucune image n'est lue depuis la galerie ou le stockage de l'utilisateur.

3. **Système de partage Android** : Lors du partage de fichiers PDF, l'application utilise le système de partage natif d'Android qui ne nécessite pas ces permissions.

**Aucune fonctionnalité ne nécessite l'accès aux photos, vidéos ou fichiers audio stockés sur l'appareil de l'utilisateur.**

---

## 📋 Version Détaillée (si nécessaire)

### Contexte de l'Application

Jirig est une application de comparaison de prix IKEA qui permet aux utilisateurs de :
- Comparer les prix des produits IKEA entre différents pays européens
- Scanner des codes QR de produits en magasin
- Gérer une liste de souhaits
- Partager leur wishlist sous forme de PDF

### Utilisation du Stockage

**Permissions retirées :** `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`

**Permissions conservées (Android 12 et inférieur uniquement) :**
- `READ_EXTERNAL_STORAGE` (maxSdkVersion="32") - Pour compatibilité Android 12 et inférieur
- `WRITE_EXTERNAL_STORAGE` (maxSdkVersion="32") - Pour compatibilité Android 12 et inférieur

**Note :** Sur Android 13+ (API 33+), aucune permission READ_MEDIA_* n'est nécessaire car l'application n'accède pas aux médias de l'utilisateur.

### Fonctionnalités Utilisant le Stockage

1. **Partage de Wishlist en PDF**
   - **Quand** : Lorsque l'utilisateur clique sur le bouton "Partager" dans la wishlist
   - **Comment** : 
     - Génération d'un PDF dans le cache temporaire privé de l'app (`getTemporaryDirectory()`)
     - Partage via `Share.shareXFiles()` qui utilise le système de partage Android
   - **Stockage** : Fichier temporaire dans le cache privé de l'application (pas d'accès au stockage externe)
   - **Accès médias** : Aucun - l'app ne lit pas d'images/vidéos depuis l'appareil

2. **Affichage d'Images de Produits**
   - **Source** : Images chargées depuis le serveur (URLs HTTP/HTTPS)
   - **Cache** : Images mises en cache localement dans le répertoire privé de l'app
   - **Accès médias** : Aucun - l'app ne lit pas d'images depuis la galerie de l'utilisateur

3. **Photo de Profil Utilisateur**
   - **Source** : URL d'image depuis le serveur (champ `sPhoto` de l'API)
   - **Stockage** : URL stockée dans SharedPreferences (pas de fichier local)
   - **Accès médias** : Aucun - l'app ne lit pas de photos depuis l'appareil

### Preuves Techniques

- ✅ Aucun package `image_picker` ou `file_picker` dans les dépendances
- ✅ Aucun accès à la galerie photo de l'utilisateur
- ✅ Aucun accès aux vidéos de l'utilisateur
- ✅ Utilisation uniquement de `getTemporaryDirectory()` (cache privé)
- ✅ Les permissions `READ_MEDIA_IMAGES` et `READ_MEDIA_VIDEO` ont été retirées du manifest
- ✅ Partage via système Android natif (ne nécessite pas ces permissions)

### Conformité

- ✅ Conforme aux politiques Google Play concernant l'accès aux médias
- ✅ Aucun accès non autorisé aux fichiers de l'utilisateur
- ✅ Utilisation minimale du stockage (cache privé uniquement)
- ✅ Respect de la vie privée de l'utilisateur

---

## 🔧 Action Technique Effectuée

Les permissions `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` et `READ_MEDIA_AUDIO` ont été **retirées** du fichier `AndroidManifest.xml` car elles ne sont pas nécessaires pour le fonctionnement de l'application.

**Avant :**
```xml
<!-- Android 13+ (API 33+) -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

**Après :**
```xml
<!-- Android 13+ (API 33+) : Aucune permission READ_MEDIA_* nécessaire -->
<!-- L'app n'accède pas aux photos/vidéos/audio de l'utilisateur -->
```

---

## 📝 Notes pour le Développeur

1. **Rebuild de l'application** : Après cette modification, reconstruire l'APK/AAB
2. **Test** : Vérifier que le partage de PDF fonctionne toujours correctement
3. **Soumission** : Utiliser la version courte pour répondre au Play Store

---

**Date de mise à jour** : $(date)  
**Version de l'app** : 1.0.0+1  
**Statut** : ✅ Permissions retirées, prêt pour soumission

