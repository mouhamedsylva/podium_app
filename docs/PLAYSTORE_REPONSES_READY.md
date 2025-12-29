# 📋 Réponses Prêtes pour Google Play Console

## 🎯 Instructions

Ce document contient les textes exacts à copier-coller dans la Google Play Console lors de la déclaration des permissions sensibles.

**Accès :** Play Console → Votre App → Politique et programmes → Autorisations sensibles

---

## 1️⃣ ACCESS_FINE_LOCATION

### ✅ Cochez : Oui, l'application utilise cette permission

### 📝 Justification (copier-coller) :

```
L'application utilise la localisation uniquement "while in use" (pendant l'utilisation) pour afficher la position de l'utilisateur sur une carte interactive et trouver les magasins IKEA à proximité. La localisation est demandée uniquement lorsque l'utilisateur ouvre explicitement la fonctionnalité de carte. Aucun suivi en arrière-plan n'est effectué.
```

### 🎯 Fonctionnalité de base :

- Affichage de la carte interactive des magasins IKEA
- Recherche de magasins à proximité de l'utilisateur

---

## 2️⃣ ACCESS_COARSE_LOCATION

### ✅ Cochez : Oui, l'application utilise cette permission

### 📝 Justification (copier-coller) :

```
L'application utilise la localisation uniquement "while in use" (pendant l'utilisation) pour afficher la position de l'utilisateur sur une carte interactive et trouver les magasins IKEA à proximité. La localisation est demandée uniquement lorsque l'utilisateur ouvre explicitement la fonctionnalité de carte. Aucun suivi en arrière-plan n'est effectué.
```

### 🎯 Fonctionnalité de base :

- Affichage de la carte interactive des magasins IKEA
- Recherche de magasins à proximité de l'utilisateur

---

## 3️⃣ CAMERA

### ✅ Cochez : Oui, l'application utilise cette permission

### 📝 Justification (copier-coller) :

```
L'application utilise la caméra pour scanner les codes QR des produits IKEA en magasin. Cette fonctionnalité permet aux utilisateurs de rechercher rapidement un produit en scannant son code-barres ou QR code. La caméra est utilisée uniquement lorsque l'utilisateur ouvre explicitement le scanner QR dans l'application.
```

### 🎯 Fonctionnalité de base :

- Scanner de codes QR/barres des produits IKEA
- Recherche rapide de produits en magasin

---

## 4️⃣ READ_EXTERNAL_STORAGE

### ✅ Cochez : Oui, l'application utilise cette permission (Android 12 et inférieur uniquement)

### 📝 Justification (copier-coller) :

```
L'application utilise cette permission uniquement pour créer des fichiers PDF temporaires dans le cache privé de l'application lors du partage de la wishlist. Ces fichiers sont créés dans le répertoire de cache temporaire privé (getTemporaryDirectory()) et ne nécessitent pas d'accès aux médias de l'utilisateur (photos, vidéos, audio). L'application n'accède pas aux fichiers stockés sur le stockage externe de l'utilisateur. Sur Android 13+, aucune permission de stockage n'est requise.
```

### 🎯 Fonctionnalité de base :

- Partage de la wishlist sous forme de PDF
- Création de fichiers temporaires dans le cache privé de l'application

**⚠️ Important :** Même si Google Play détecte cette permission comme liée aux photos/vidéos, précisez clairement que l'application **n'accède PAS** aux médias de l'utilisateur.

---

## 5️⃣ WRITE_EXTERNAL_STORAGE

### ✅ Cochez : Oui, l'application utilise cette permission (Android 12 et inférieur uniquement)

### 📝 Justification (copier-coller) :

```
L'application utilise cette permission uniquement pour créer des fichiers PDF temporaires dans le cache privé de l'application lors du partage de la wishlist. Ces fichiers sont créés dans le répertoire de cache temporaire privé (getTemporaryDirectory()) et ne nécessitent pas d'accès aux médias de l'utilisateur (photos, vidéos, audio). L'application n'accède pas aux fichiers stockés sur le stockage externe de l'utilisateur. Sur Android 13+, aucune permission de stockage n'est requise.
```

### 🎯 Fonctionnalité de base :

- Partage de la wishlist sous forme de PDF
- Création de fichiers temporaires dans le cache privé de l'application

**⚠️ Important :** Même si Google Play détecte cette permission comme liée aux photos/vidéos, précisez clairement que l'application **n'accède PAS** aux médias de l'utilisateur.

---

## 🎯 Déclaration de la Fonctionnalité de Base

### Question : "Indiquez la fonctionnalité de base de votre appli"

### 📝 Réponse (copier-coller) :

```
Jirig est une application de comparaison de prix IKEA qui permet aux utilisateurs de :

1. Comparer les prix des produits IKEA entre différents pays européens
2. Scanner des codes QR de produits en magasin pour rechercher rapidement un produit
3. Gérer une liste de souhaits personnalisée
4. Trouver des magasins IKEA à proximité grâce à une carte interactive

Les permissions de stockage (READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE) sont utilisées uniquement pour créer des fichiers PDF temporaires dans le cache privé de l'application lors du partage de la wishlist. L'application n'accède pas aux photos, vidéos ou fichiers audio stockés sur l'appareil de l'utilisateur.
```

---

## ✅ Checklist Rapide

Avant de soumettre, vérifiez :

- [ ] ✅ ACCESS_FINE_LOCATION déclarée avec justification
- [ ] ✅ ACCESS_COARSE_LOCATION déclarée avec justification
- [ ] ✅ CAMERA déclarée avec justification
- [ ] ✅ READ_EXTERNAL_STORAGE déclarée avec justification
- [ ] ✅ WRITE_EXTERNAL_STORAGE déclarée avec justification
- [ ] ✅ Fonctionnalité de base remplie
- [ ] ✅ Toutes les justifications copiées correctement

---

## 📌 Notes Importantes

1. **Cohérence** : Assurez-vous que vos déclarations correspondent aux permissions dans le `AndroidManifest.xml`

2. **Clarté** : Les justifications doivent être claires et précises

3. **Stockage** : Pour READ_EXTERNAL_STORAGE et WRITE_EXTERNAL_STORAGE, insister sur le fait que l'app **n'accède PAS** aux médias de l'utilisateur

4. **Localisation** : Insister sur le fait que la localisation est uniquement "while in use", pas en arrière-plan

---

## 6️⃣ Identifiant Publicitaire (AD_ID)

### Question : "Votre appli utilise-t-elle un identifiant publicitaire ?"

### ✅ Cochez : Oui, l'application utilise un identifiant publicitaire

### 📝 Justification (copier-coller) :

```
L'application Jirig utilise le Facebook SDK (flutter_facebook_auth) pour permettre aux utilisateurs de se connecter via leur compte Facebook (authentification OAuth). 

Le Facebook SDK collecte automatiquement l'identifiant publicitaire (Advertising ID / AD_ID) pour des fins d'analytics et de mesure de performance des événements d'authentification, conformément aux pratiques standard du SDK Facebook.

Cette collecte est activée via la configuration du Facebook SDK dans le manifest Android (com.facebook.sdk.AdvertiserIDCollectionEnabled) et est nécessaire pour :
- Mesurer l'efficacité des événements d'authentification Facebook
- Analyser les conversions et l'engagement utilisateur
- Respecter les exigences du SDK Facebook pour l'authentification OAuth

L'application n'affiche PAS de publicités et n'utilise pas l'identifiant publicitaire pour cibler des publicités. L'identifiant est collecté uniquement par le SDK Facebook dans le cadre de l'authentification sociale et de l'analyse des événements d'authentification.

L'utilisateur peut désactiver la collecte de l'identifiant publicitaire via les paramètres de son appareil Android (Paramètres → Google → Publicités → Réinitialiser l'ID publicitaire ou Désactiver les publicités personnalisées).
```

### 🎯 Points clés :

- ✅ L'AD_ID est collecté uniquement par le Facebook SDK pour l'authentification OAuth
- ✅ L'application n'affiche PAS de publicités
- ✅ L'identifiant n'est PAS utilisé pour cibler des publicités
- ✅ Utilisation uniquement pour l'analytics des événements d'authentification
- ✅ L'utilisateur peut désactiver la collecte via les paramètres Android

---

**Date de création** : $(date)  
**Version de l'app** : 1.0.0+1  
**Usage** : Copier-coller directement dans la Play Console

