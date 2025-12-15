# 📱 Guide de Test - Application Jirig (APK Android)

**Version** : 1.0.0  
**Date** : 18 octobre 2025  
**Plateforme** : Android (APK)

---

## 📥 Installation

1. **Télécharger** le fichier APK
2. **Activer** les sources inconnues sur votre téléphone Android :
   - Paramètres → Sécurité → Sources inconnues (autoriser)
3. **Installer** l'APK en cliquant dessus
4. **Lancer** l'application Jirig

---

## ✅ Checklist des fonctionnalités à tester

Pour chaque fonctionnalité, merci de noter :
- ✅ **Fonctionne** - Pas de problème
- ⚠️ **Fonctionne avec bugs** - Fonctionne mais avec des problèmes
- ❌ **Ne fonctionne pas** - Erreur ou crash
- 🔄 **Non testé** - Pas eu le temps de tester

---

## 1️⃣ DÉMARRAGE DE L'APPLICATION

### 1.1 Écran de chargement (Splash Screen)
**À tester :**
- [ ] L'écran de chargement s'affiche avec le logo Jirig
- [ ] Les anneaux bleu et jaune tournent correctement
- [ ] La barre de progression se remplit
- [ ] Transition automatique vers l'écran suivant après ~8 secondes

**Statut** : 🔄 Non testé  
**Commentaires** :
```
(Notez ici vos observations, bugs, ou problèmes rencontrés)
```

---

### 1.2 Sélection du pays
**À tester :**
- [ ] La liste des pays s'affiche avec les drapeaux
- [ ] La recherche fonctionne (taper "France", "Belgique", etc.)
- [ ] Je peux sélectionner un pays
- [ ] Le pays sélectionné s'affiche correctement
- [ ] La checkbox "J'accepte les conditions" fonctionne
- [ ] Le bouton "Terminer" est grisé tant que je n'accepte pas les conditions
- [ ] Le bouton "Terminer" redirige vers la page d'accueil

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 2️⃣ PAGE D'ACCUEIL

### 2.1 Affichage de la page
**À tester :**
- [ ] Le titre s'affiche correctement
- [ ] Le sélecteur de pays en haut à droite fonctionne
- [ ] Les 2 modules principaux sont visibles :
  - [ ] Module "Recherche" (icône loupe)
  - [ ] Module "Scanner" (icône QR code)

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 2.2 Navigation
**À tester :**
- [ ] Cliquer sur "Recherche" ouvre la page de recherche
- [ ] Cliquer sur "Scanner" ouvre le scanner QR code
- [ ] La barre de navigation en bas fonctionne :
  - [ ] Icône Maison → Page d'accueil
  - [ ] Icône Loupe → Recherche
  - [ ] Icône Cœur → Wishlist
  - [ ] Icône Profil → Profil utilisateur

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 3️⃣ RECHERCHE DE PRODUITS

### 3.1 Recherche par code article
**À tester :**
- [ ] Je peux taper un code article (ex: 123.456.78)
- [ ] Le code se formate automatiquement pendant la saisie (XXX.XXX.XX)
- [ ] Les résultats s'affichent en temps réel
- [ ] Chaque résultat montre :
  - [ ] Image du produit
  - [ ] Code article
  - [ ] Nom du produit
  - [ ] Description

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

**Codes à tester** (exemples réels IKEA) :
- `304.887.96` - Lampe
- `902.866.56` - Chaise
- `704.288.81` - Étagère

---

### 3.2 Sélection d'un produit
**À tester :**
- [ ] Cliquer sur un résultat me redirige vers la page de comparaison (Podium)

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 4️⃣ SCANNER QR CODE

### 4.1 Ouverture du scanner
**À tester :**
- [ ] Depuis la page d'accueil, cliquer sur "Scanner" ouvre la caméra
- [ ] Depuis la recherche, le bouton "Scanner" ouvre la caméra
- [ ] Permission caméra demandée si première utilisation
- [ ] La caméra s'affiche en plein écran

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 4.2 Scan d'un QR code IKEA
**À tester :**
- [ ] Le cadre de scan est visible (carré avec coins animés)
- [ ] Le QR code est détecté automatiquement
- [ ] Un message "QR Code validé !" s'affiche
- [ ] Vibration du téléphone lors de la détection
- [ ] Redirection automatique vers la page du produit

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

**⚠️ Note** : Pour tester, vous pouvez :
- Scanner un vrai QR code IKEA en magasin
- Utiliser un QR code de test (je peux vous en fournir un)

---

### 4.3 Fermeture du scanner
**À tester :**
- [ ] Le bouton "X" ferme le scanner
- [ ] Retour à la page précédente

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 5️⃣ PAGE PODIUM (Comparaison des prix)

### 5.0 Animations de la page podium ✨ NOUVEAU - LE PLUS SPECTACULAIRE
**À tester :**
- [ ] Le produit apparaît avec une **rotation 3D** impressionnante
- [ ] L'image "surgit" de l'écran avec un effet explosion
- [ ] Le podium (top 3) **monte depuis le bas** comme s'il se construisait
- [ ] Les autres pays apparaissent en **effet ripple** (onde concentrique)
- [ ] Les animations sont FLUIDES (60 FPS)
- [ ] C'est l'écran le plus impressionnant de l'app ! 🏆
- [ ] Total durée ~2.2 secondes

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 5.1 Affichage du produit
**À tester :**
- [ ] L'image du produit s'affiche correctement
- [ ] Le nom du produit est visible
- [ ] La description est visible
- [ ] Le code article est affiché
- [ ] Je peux changer la quantité avec les boutons +/-

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 5.2 Navigation des images
**À tester :**
- [ ] Si plusieurs images, je peux naviguer avec les flèches gauche/droite
- [ ] Cliquer sur l'image l'ouvre en plein écran
- [ ] En plein écran, je peux zoomer avec les doigts
- [ ] Bouton fermer (X) fonctionne

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 5.3 Podium des prix (Top 3)
**À tester :**
- [ ] Le podium affiche 3 pays avec les meilleurs prix
- [ ] L'ordre est correct : 2ème place à gauche, 1ère au centre, 3ème à droite
- [ ] Chaque carte de pays affiche :
  - [ ] Drapeau
  - [ ] Nom du pays
  - [ ] Prix
  - [ ] Badge d'économie (ex: -10€)
  - [ ] Bouton cœur (wishlist)
- [ ] Mon pays d'origine est marqué avec une icône 🏠

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 5.4 Ajout à la wishlist
**À tester :**
- [ ] Cliquer sur le bouton cœur d'un pays
- [ ] L'application redirige vers la wishlist
- [ ] Le produit apparaît dans la wishlist avec le bon pays

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 5.5 Liste des autres pays
**À tester :**
- [ ] En dessous du podium, la liste des autres pays s'affiche
- [ ] Chaque ligne montre : drapeau, pays, prix, bouton wishlist
- [ ] Je peux ajouter ces produits à la wishlist

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 5.6 Nouvelle recherche
**À tester :**
- [ ] Le bouton "Nouvelle recherche" redirige vers la recherche

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 6️⃣ WISHLIST (Liste de souhaits)

### 6.0b Animations des modals ✨ NOUVEAU - MODALS ANIMÉS
**À tester - Sidebar de sélection de pays (icône +) :**
- [ ] Le sidebar **glisse depuis la droite** de l'écran (comme un tiroir)
- [ ] Il apparaît en fondu simultanément
- [ ] Les pays apparaissent en **vague** (60ms entre chacun)
- [ ] Chaque pays glisse depuis la droite (20px)
- [ ] Animation fluide et rapide (~400ms pour le sidebar)
- [ ] Total ~800ms pour afficher tous les pays

**À tester - Modal gestion des pays (🚩 bouton flag) :**
- [ ] Le modal **pop au centre** avec un effet zoom
- [ ] Il grandit de 80% à 100% avec un **petit bounce**
- [ ] Les chips de pays apparaissent en **vague rapide** (50ms entre chacun)
- [ ] Chaque chip fait un petit bounce en apparaissant
- [ ] Quand je **clique sur un chip**, transition fluide aqua ↔ gris
- [ ] Total ~500ms pour afficher tous les pays
- [ ] Les animations sont **dynamiques** et **engageantes** 🎭

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 6.1 Affichage de la wishlist
**À tester :**
- [ ] Tous mes produits ajoutés apparaissent
- [ ] Les produits sont groupés par pays
- [ ] Chaque produit affiche :
  - [ ] Image
  - [ ] Nom
  - [ ] Code article
  - [ ] Prix
  - [ ] Quantité
  - [ ] Total (prix × quantité)

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 6.2 Modification des quantités
**À tester :**
- [ ] Je peux augmenter la quantité avec le bouton +
- [ ] Je peux diminuer la quantité avec le bouton -
- [ ] Le total se met à jour automatiquement
- [ ] Le total général se met à jour

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 6.3 Suppression de produits
**À tester :**
- [ ] Je peux supprimer un produit (bouton poubelle ou X)
- [ ] Une confirmation est demandée
- [ ] Le produit disparaît de la liste
- [ ] Le total général se met à jour

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 6.4 Actions sur les produits
**À tester :**
- [ ] Bouton "Voir détails" redirige vers la page podium du produit
- [ ] Bouton "Partager" ouvre les options de partage Android

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 6.5 Total général
**À tester :**
- [ ] Le total général s'affiche en bas
- [ ] Le total est correct (somme de tous les produits)

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 7️⃣ CONNEXION / AUTHENTIFICATION

### 7.0 Animations de la page de connexion ✨ NOUVEAU - ELEGANT ENTRY
**À tester :**
- [ ] L'**AppBar bleue** descend depuis le haut avec fade (600ms)
- [ ] Le **logo** apparaît avec un **bounce élastique très fort** (effet "explosion")
- [ ] Le logo fait une **petite rotation** (~6°) en apparaissant (twist élégant)
- [ ] Les **titres** ("Connexion", "Accédez...") montent depuis le bas (30%)
- [ ] Le **champ email/token** monte aussi depuis le bas avec fade
- [ ] Le **bouton Google** apparaît en premier (slide depuis le bas)
- [ ] Le **bouton Facebook** apparaît 150ms après (cascade)
- [ ] Le **footer** (conditions) fade in doucement
- [ ] Les animations sont **élégantes** et **accueillantes**
- [ ] L'œil suit naturellement : AppBar → logo → formulaire → boutons
- [ ] Total durée ~1.5 secondes
- [ ] Parfait pour une **première impression premium** ! 🎯✨

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 7.1 Accès à la page de connexion
**À tester :**
- [ ] Je peux accéder à la page de connexion depuis le profil

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 7.2 Connexion par Magic Link (Email)
**À tester :**
- [ ] Je peux entrer mon email
- [ ] Le bouton "Envoyer le lien magique" fonctionne
- [ ] Je reçois un email avec un lien
- [ ] Cliquer sur le lien dans l'email ouvre l'application
- [ ] Une popup demande confirmation d'ouverture
- [ ] Après validation, je suis connecté
- [ ] Redirection vers la page appropriée

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 7.3 Connexion OAuth (Google/Facebook)
**À tester :**
- [ ] Le bouton Google fonctionne
- [ ] Une page web s'ouvre pour se connecter
- [ ] Après connexion, retour à l'app
- [ ] Je suis bien connecté

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 8️⃣ PROFIL UTILISATEUR

### 8.1 Affichage du profil
**À tester :**
- [ ] Mon avatar avec initiales s'affiche
- [ ] Mon nom et prénom sont affichés
- [ ] Mon email est affiché
- [ ] Mes informations de contact sont visibles :
  - [ ] Téléphone
  - [ ] Adresse
  - [ ] Code postal
  - [ ] Ville

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 8.2 Modification du profil
**À tester :**
- [ ] Je peux cliquer sur "Modifier"
- [ ] Les champs deviennent éditables
- [ ] Je peux modifier mes informations
- [ ] Le bouton "Sauvegarder" enregistre les changements
- [ ] Un message de succès s'affiche

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 8.3 Sélection du pays principal
**À tester :**
- [ ] Je peux changer mon pays principal
- [ ] La liste des pays s'affiche avec drapeaux
- [ ] Le pays sélectionné se met à jour

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 8.4 Sélection des pays favoris
**À tester :**
- [ ] Je peux ajouter des pays favoris (plusieurs)
- [ ] Je peux retirer des pays favoris
- [ ] Les drapeaux s'affichent correctement
- [ ] Les modifications sont sauvegardées

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 9️⃣ CHANGEMENT DE LANGUE

### 9.1 Sélecteur de langue
**À tester :**
- [ ] En haut à droite, je peux cliquer sur le sélecteur de pays
- [ ] Je peux changer de langue
- [ ] L'interface se traduit dans la langue choisie
- [ ] Les traductions sont cohérentes

**Langues à tester** :
- [ ] Français (FR)
- [ ] Anglais (EN)
- [ ] Allemand (DE)
- [ ] Espagnol (ES)
- [ ] Italien (IT)
- [ ] Portugais (PT)
- [ ] Néerlandais (NL)

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 🔟 PERSISTANCE DES DONNÉES

### 10.1 Fermeture et réouverture de l'app
**À tester :**
- [ ] Je ferme complètement l'application
- [ ] Je rouvre l'application
- [ ] Ma wishlist est toujours là
- [ ] Mes préférences sont conservées (pays, langue)
- [ ] Je suis toujours connecté (si je l'étais avant)

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 1️⃣1️⃣ NAVIGATION GÉNÉRALE

### 11.1 Barre de navigation inférieure
**À tester :**
- [ ] L'icône active est bien mise en évidence
- [ ] Tous les onglets fonctionnent :
  - [ ] Maison → Accueil
  - [ ] Loupe → Recherche
  - [ ] Cœur → Wishlist
  - [ ] Profil → Profil

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 11.2 Bouton retour Android
**À tester :**
- [ ] Le bouton retour physique d'Android fonctionne
- [ ] Il me ramène à la page précédente
- [ ] Depuis la page d'accueil, il ferme l'app

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 1️⃣2️⃣ PERFORMANCE ET STABILITÉ

### 12.1 Fluidité générale
**À tester :**
- [ ] Les animations sont fluides (pas de saccades)
- [ ] Les transitions entre pages sont rapides
- [ ] Le scroll est fluide
- [ ] Pas de freeze/blocage

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 12.2 Chargement des images
**À tester :**
- [ ] Les images de produits se chargent correctement
- [ ] Les drapeaux s'affichent
- [ ] Pas d'images cassées
- [ ] Temps de chargement raisonnable

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 12.3 Connexion réseau
**À tester avec WiFi** :
- [ ] Toutes les fonctionnalités marchent

**À tester avec 4G/5G** :
- [ ] Toutes les fonctionnalités marchent
- [ ] Temps de chargement acceptable

**À tester sans réseau** :
- [ ] L'app ne crash pas
- [ ] Un message d'erreur approprié s'affiche

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 12.4 Stabilité (Crashes)
**À tester :**
- [ ] Aucun crash pendant l'utilisation normale
- [ ] Si crash, noter à quel moment et dans quelle page

**Statut** : 🔄 Non testé  
**Liste des crashes rencontrés** :
```

```

---

## 1️⃣3️⃣ ADAPTATION À L'ÉCRAN

### 13.1 Rotation de l'écran
**À tester :**
- [ ] L'application reste en mode portrait
- [ ] Si je tourne le téléphone en paysage, l'app reste en portrait

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

### 13.2 Taille d'écran
**Merci de noter votre modèle de téléphone** :
```
Modèle : 
Taille d'écran : 
Résolution : 
```

**À tester :**
- [ ] L'interface s'affiche correctement sur mon écran
- [ ] Les textes ne sont pas coupés
- [ ] Les boutons sont cliquables
- [ ] Pas de débordement d'éléments

**Statut** : 🔄 Non testé  
**Commentaires** :
```

```

---

## 📝 BUGS ET PROBLÈMES RENCONTRÉS

### Liste des bugs trouvés

**Bug #1**
- **Page/Fonctionnalité** : 
- **Description** : 
- **Étapes pour reproduire** :
  1. 
  2. 
  3. 
- **Gravité** : ⬜ Mineur  ⬜ Moyen  ⬜ Critique  ⬜ Bloquant

---

**Bug #2**
- **Page/Fonctionnalité** : 
- **Description** : 
- **Étapes pour reproduire** :
  1. 
  2. 
  3. 
- **Gravité** : ⬜ Mineur  ⬜ Moyen  ⬜ Critique  ⬜ Bloquant

---

**Bug #3**
- **Page/Fonctionnalité** : 
- **Description** : 
- **Étapes pour reproduire** :
  1. 
  2. 
  3. 
- **Gravité** : ⬜ Mineur  ⬜ Moyen  ⬜ Critique  ⬜ Bloquant

---

*(Ajouter plus de bugs si nécessaire)*

---

## 💡 SUGGESTIONS D'AMÉLIORATION

**Suggestion #1** :
```

```

**Suggestion #2** :
```

```

**Suggestion #3** :
```

```

---

## 📊 RÉSUMÉ GLOBAL

### Statistiques de test
- **Fonctionnalités testées** : ___ / 50+
- **Fonctionnalités qui marchent** : ___
- **Fonctionnalités avec bugs** : ___
- **Fonctionnalités qui ne marchent pas** : ___

### Note globale
**L'application est-elle prête pour une utilisation réelle ?**
- ⬜ Oui, sans problème
- ⬜ Oui, avec quelques corrections mineures
- ⬜ Non, bugs importants à corriger
- ⬜ Non, l'app est inutilisable

### Impression générale
```
(Votre ressenti global sur l'application)




```

---

## 🙏 Merci pour votre aide !

**Testeur** : ____________________  
**Date du test** : ____________________  
**Temps de test** : ____________________  
**Téléphone utilisé** : ____________________  

---

**Comment me retourner ce document de test ?**
1. Remplir les checkboxes et commentaires ci-dessus
2. Me l'envoyer par email à : _________________
3. Ou via WhatsApp/Telegram : _________________

**En cas de problème urgent**, me contacter directement !

---

**Version du document** : 1.0  
**Créé le** : 18 octobre 2025

