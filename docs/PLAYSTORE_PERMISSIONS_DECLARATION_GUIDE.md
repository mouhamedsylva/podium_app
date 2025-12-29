# 📱 Guide de Déclaration des Permissions - Google Play Console

## 🚨 Erreurs Rencontrées

1. **"Cette release contient des autorisations qui n'ont pas été déclarées dans la Play Console"**
2. **"Tous les développeurs demandant l'accès aux autorisations liées aux photos et vidéos doivent indiquer à Google Play la fonctionnalité de base de leur appli"**

---

## 📋 Permissions à Déclarer dans la Play Console

### Permissions Sensibles Actuelles dans le Manifest

D'après le `AndroidManifest.xml`, voici les permissions sensibles qui nécessitent une déclaration :

1. ✅ **ACCESS_FINE_LOCATION** - Localisation précise (GPS)
2. ✅ **ACCESS_COARSE_LOCATION** - Localisation approximative
3. ✅ **CAMERA** - Accès à la caméra
4. ✅ **READ_EXTERNAL_STORAGE** - Lecture du stockage (Android ≤ 12 uniquement)
5. ✅ **WRITE_EXTERNAL_STORAGE** - Écriture du stockage (Android ≤ 12 uniquement)

**Note :** `READ_EXTERNAL_STORAGE` est détecté par Google Play comme une permission liée au stockage, même si elle n'est utilisée que pour le cache temporaire.

---

## 📦 Permissions Initialement Présentes (Retirées)

### Contexte des Permissions Supprimées

Les permissions suivantes étaient initialement présentes dans le manifest pour des raisons de compatibilité et de fonctionnalités potentielles, mais ont été retirées car elles ne sont pas utilisées par l'application :

#### 1. **ACCESS_BACKGROUND_LOCATION**

**Raison de présence initiale :**
Cette permission était initialement incluse pour permettre un suivi continu de la localisation en arrière-plan, ce qui aurait pu être utile pour des fonctionnalités avancées telles que :
- Notifications basées sur la proximité des magasins IKEA
- Mise à jour automatique de la position sur la carte même lorsque l'application est en arrière-plan
- Fonctionnalités de géofencing pour alerter l'utilisateur lorsqu'il se trouve à proximité d'un magasin

**État actuel :** Retirée - L'application utilise uniquement la localisation "while in use" (pendant l'utilisation active).

---

#### 2. **READ_MEDIA_IMAGES**

**Raison de présence initiale :**
Cette permission était initialement incluse pour permettre l'accès aux images stockées sur l'appareil, ce qui aurait pu être utile pour des fonctionnalités telles que :
- Permettre aux utilisateurs de sélectionner des photos depuis leur galerie pour personnaliser leur profil
- Uploader des images de produits depuis la galerie de l'utilisateur
- Partage d'images de produits depuis la galerie lors de la création de wishlist personnalisée
- Intégration avec des fonctionnalités de reconnaissance d'images pour identifier des produits IKEA

**État actuel :** Retirée - L'application charge uniquement des images depuis le serveur via des URLs.

---

#### 3. **READ_MEDIA_VIDEO**

**Raison de présence initiale :**
Cette permission était initialement incluse pour permettre l'accès aux vidéos stockées sur l'appareil, ce qui aurait pu être utile pour des fonctionnalités telles que :
- Permettre aux utilisateurs de partager des vidéos de produits depuis leur galerie
- Uploader des vidéos de démonstration de produits depuis l'appareil
- Intégration avec des fonctionnalités de reconnaissance vidéo pour identifier des produits IKEA
- Création de contenu multimédia pour la wishlist

**État actuel :** Retirée - L'application n'utilise pas de vidéos stockées sur l'appareil.

---

### Pourquoi ces permissions ont été retirées

Ces permissions ont été retirées du manifest pour :
- ✅ Respecter le principe de moindre privilège (ne demander que les permissions strictement nécessaires)
- ✅ Améliorer la confiance des utilisateurs en ne demandant que les permissions essentielles
- ✅ Simplifier le processus de validation dans la Google Play Console
- ✅ Réduire les risques de rejet lors de la soumission
- ✅ Conformer l'application aux meilleures pratiques de sécurité Android

**Note importante :** Ces permissions peuvent être réintroduites à l'avenir si de nouvelles fonctionnalités nécessitant leur utilisation sont développées, mais pour l'instant, l'application fonctionne parfaitement sans elles.

---

## 🎯 Étapes pour Déclarer les Permissions

### Étape 1 : Accéder aux Autorisations Sensibles

1. Dans la **Google Play Console**, allez dans votre application
2. Dans le menu de gauche, cliquez sur **"Politique et programmes"** → **"Autorisations sensibles"**
3. Ou cliquez directement sur le lien : **"Accéder aux autorisations sensibles pour votre application"**

### Étape 2 : Déclarer Chaque Permission

Pour chaque permission, vous devrez :
- ✅ Cocher la case si l'application utilise cette permission
- 📝 Fournir une justification claire et concise

---

## 📝 Déclarations Recommandées

### 1. **ACCESS_FINE_LOCATION** et **ACCESS_COARSE_LOCATION**

**Cochez :** ✅ Oui, l'application utilise cette permission

**Justification :**
```
L'application utilise la localisation uniquement "while in use" (pendant l'utilisation) pour afficher la position de l'utilisateur sur une carte interactive et trouver les magasins IKEA à proximité. La localisation est demandée uniquement lorsque l'utilisateur ouvre explicitement la fonctionnalité de carte. Aucun suivi en arrière-plan n'est effectué.
```

**Fonctionnalité de base :**
- Affichage de la carte interactive des magasins IKEA
- Recherche de magasins à proximité de l'utilisateur

---

### 2. **CAMERA**

**Cochez :** ✅ Oui, l'application utilise cette permission

**Justification :**
```
L'application utilise la caméra pour scanner les codes QR des produits IKEA en magasin. Cette fonctionnalité permet aux utilisateurs de rechercher rapidement un produit en scannant son code-barres ou QR code. La caméra est utilisée uniquement lorsque l'utilisateur ouvre explicitement le scanner QR dans l'application.
```

**Fonctionnalité de base :**
- Scanner de codes QR/barres des produits IKEA
- Recherche rapide de produits en magasin

---

### 3. **READ_EXTERNAL_STORAGE** et **WRITE_EXTERNAL_STORAGE**

**Cochez :** ✅ Oui, l'application utilise cette permission (Android 12 et inférieur uniquement)

**Justification :**
```
L'application utilise ces permissions uniquement pour créer des fichiers PDF temporaires dans le cache privé de l'application lors du partage de la wishlist. Ces fichiers sont créés dans le répertoire de cache temporaire privé (getTemporaryDirectory()) et ne nécessitent pas d'accès aux médias de l'utilisateur (photos, vidéos, audio). L'application n'accède pas aux fichiers stockés sur le stockage externe de l'utilisateur. Sur Android 13+, aucune permission de stockage n'est requise.
```

**Fonctionnalité de base :**
- Partage de la wishlist sous forme de PDF
- Création de fichiers temporaires dans le cache privé de l'application

**Important :** Même si Google Play détecte cette permission comme liée aux photos/vidéos, précisez clairement que l'application **n'accède PAS** aux médias de l'utilisateur.

---

## 🎯 Déclaration de la Fonctionnalité de Base

### Question : "Indiquez la fonctionnalité de base de votre appli"

**Réponse Recommandée :**

```
Jirig est une application de comparaison de prix IKEA qui permet aux utilisateurs de :

1. Comparer les prix des produits IKEA entre différents pays européens
2. Scanner des codes QR de produits en magasin pour rechercher rapidement un produit
3. Gérer une liste de souhaits personnalisée
4. Trouver des magasins IKEA à proximité grâce à une carte interactive

Les permissions de stockage (READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE) sont utilisées uniquement pour créer des fichiers PDF temporaires dans le cache privé de l'application lors du partage de la wishlist. L'application n'accède pas aux photos, vidéos ou fichiers audio stockés sur l'appareil de l'utilisateur.
```

---

## ✅ Checklist de Déclaration

Avant de soumettre, vérifiez que vous avez :

- [ ] Accédé à la section "Autorisations sensibles" dans la Play Console
- [ ] Déclaré **ACCESS_FINE_LOCATION** avec justification
- [ ] Déclaré **ACCESS_COARSE_LOCATION** avec justification
- [ ] Déclaré **CAMERA** avec justification
- [ ] Déclaré **READ_EXTERNAL_STORAGE** avec justification (précisant qu'il n'y a pas d'accès aux médias)
- [ ] Déclaré **WRITE_EXTERNAL_STORAGE** avec justification (précisant qu'il n'y a pas d'accès aux médias)
- [ ] Rempli la déclaration de fonctionnalité de base
- [ ] Vérifié que toutes les justifications sont claires et précises

---

## 🔍 Vérification Post-Déclaration

Après avoir déclaré les permissions :

1. **Reconstruire l'APK/AAB** :
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle
   ```

2. **Téléverser la nouvelle version** dans la Play Console

3. **Vérifier** que les erreurs ont disparu dans la section "Erreurs et avertissements"

---

## 📚 Références

- [Documentation Google Play - Autorisations sensibles](https://support.google.com/googleplay/android-developer/answer/9888170)
- [Politique Google Play - Permissions](https://support.google.com/googleplay/android-developer/answer/9888170)

---

## ⚠️ Notes Importantes

1. **READ_EXTERNAL_STORAGE** : Même si Google Play le détecte comme permission liée aux photos/vidéos, précisez clairement dans votre justification que l'application **n'accède PAS** aux médias de l'utilisateur.

2. **Cohérence** : Assurez-vous que vos déclarations dans la Play Console correspondent exactement aux permissions déclarées dans le `AndroidManifest.xml`.

3. **Justifications** : Les justifications doivent être claires, précises et expliquer pourquoi chaque permission est nécessaire pour la fonctionnalité de base de l'application.

4. **Fonctionnalité de base** : La déclaration de fonctionnalité de base doit expliquer clairement ce que fait l'application et pourquoi elle a besoin des permissions déclarées.

---

**Date de création** : $(date)  
**Version de l'app** : 1.0.0+1  
**Statut** : ✅ Guide complet pour déclaration Play Console

