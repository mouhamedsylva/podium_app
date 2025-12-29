# 📱 Déclaration de Localisation - Google Play Store

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

