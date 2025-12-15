## Documentation des requêtes et réponses API

Cette documentation synthétise, pour chaque endpoint, la requête attendue et la réponse renvoyée. Les structures sont déduites du code des handlers sous `server/api`. Lorsque la structure exacte dépend des résultats SQL, la réponse est indiquée comme «données métier (résultats SQL)».

Format par endpoint:

- Méthode / Chemin
- Requête: Query | Body | Headers (si pertinent)
- Réponse: Structure ou exemple JSON

---

### POST /api/add-article-basket
- Requête: Body: informations d’un article à ajouter (ex: `iProfile`, `sCodeArticle`, quantités, prix, pays)
- Réponse: JSON avec confirmation d’ajout et/ou contenu mis à jour du panier

### ANY /api/add-country-wishlist
- Requête: Query ou Body: `iProfile`, `iPaysSelected`
- Réponse: JSON avec statut et wishlist mise à jour

### POST /api/add-current-article
- Requête: Body: article courant à mémoriser (champs article)
- Réponse: JSON avec statut

### POST /api/add-pays-listpays
- Requête: Body: `iProfile`, `iPaysSelected`
- Réponse: JSON avec `listPays` mis à jour

### ANY /api/add-product-wishlist
- Requête: Body: `iProfile`, `sCodeArticle` (+ métadonnées)
- Réponse: JSON: statut et wishlist mise à jour

### POST /api/add-product-to-wishlist
- Requête: Body: `iProfile`, `sCodeArticle`
- Réponse: JSON: confirmation

### ANY /api/add-to-wishlist
- Requête: Body: données article et profil
- Réponse: JSON: confirmation

### POST /api/auth/auto-login-after-payment
- Requête: Body: données de session/transaction Stripe
- Réponse: JSON: session utilisateur (cookies mis à jour côté serveur)

### GET /api/auth/facebook
- Requête: Query: paramètres d’OAuth Facebook
- Réponse: Redirection / JSON d’état de connexion

### GET /api/auth/google
- Requête: Query: paramètres d’OAuth Google
- Réponse: Redirection / JSON d’état de connexion

### POST /api/auth/init
- Requête: Body: init anonyme/guest
- Réponse: JSON: profil invité + cookies de session

### POST /api/auth/login
- Requête: Body: `email`, `password`
- Réponse: JSON: session utilisateur (profil, jeton/cookies)

### POST /api/auth/login-email
- Requête: Body: `email`
- Réponse: JSON: statut (ex: lien envoyé)

### POST /api/auth/quick-signup
- Requête: Body: informations minimales (email, etc.)
- Réponse: JSON: profil utilisateur créé + session

### POST /api/auth/signup
- Requête: Body: informations d’inscription
- Réponse: JSON: profil utilisateur créé + session

### POST /api/basket-delete-pdf
- Requête: Query: `iBasket`
- Réponse: JSON: statut de suppression

### ANY /api/cancelled-product
- Requête: Query: `iProfile`, `iBasket`, `sCodeArticle`
- Réponse: JSON: statut d’annulation et mise à jour du panier

### ANY /api/change-seleceted-country
- Requête: Query/Body: `iProfile`, `iPaysSelected`
- Réponse: JSON: mise à jour du pays sélectionné

### ANY /api/comparaison
- Requête: Query: paramètres d’article et pays
- Réponse: JSON: résultats de comparaison (prix, disponibilité...)

### ANY /api/comparaison-by-code
- Requête: Query: `sCodeArticle`, pays, options
- Réponse: JSON: comparaison par code

### ANY /api/comparaison-by-code-30041025
- Requête: Query: `sCodeArticle` (endpoint spécifique)
- Réponse: JSON: comparaison par code (variante)

### POST /api/contact
- Requête: Body: `name`, `email`, `message`
- Réponse: JSON: statut d’envoi (Mailjet/SMTP)

### POST /api/create-checkout-session
- Requête: Body: détail panier, profil
- Réponse: JSON: `sessionId` Stripe ou URL de checkout

### POST /api/create-checkout-session-backup
- Requête: Body: idem ci-dessus (variante)
- Réponse: JSON: données de session Stripe

### POST /api/create-checkout-session-clear
- Requête: Body
- Réponse: JSON

### POST /api/create-checkout-session-crypted
- Requête: Body chiffré
- Réponse: JSON: session Stripe

### POST /api/create-checkout-session-encrypt
- Requête: Body clair -> chiffrage côté serveur
- Réponse: JSON: session Stripe

### ANY /api/db
- Requête: —
- Réponse: JSON: statut de connexion DB (test)

### ANY /api/delete-article-wishlist
- Requête: Query/Body: `iProfile`, `sCodeArticle`
- Réponse: JSON: wishlist mise à jour

### POST /api/delete-article-wishlistBasket
- Requête: Body: `iProfile`, `sCodeArticle`
- Réponse: JSON: suppression confirmée

### POST /api/delete-article-basket-dtl
- Requête: Body: `iBasket`, `sCodeArticle`
- Réponse: JSON: suppression confirmée

### ANY /api/delete-country-wishlist
- Requête: Query/Body: `iProfile`, `iPaysSelected`
- Réponse: JSON: wishlist mise à jour

### GET /api/flags
- Requête: Query: `lang` (optionnel)
- Réponse: JSON: liste de drapeaux/ressources

### POST /api/get-all-infos-4country
- Requête: Body: `iProfile`, liste de pays
- Réponse: JSON: agrégat d’infos par pays

### ANY /api/get-all-country
- Requête: —
- Réponse: JSON: liste des pays

### ANY /api/get-all-pdf
- Requête: Query: `iProfile` (optionnel)
- Réponse: JSON: liste des PDF (nom, pays, panier...)

### ANY /api/get-article
- Requête: Query: filtres article (code, texte, pays)
- Réponse: JSON: liste d’articles

### GET /api/get-basket-list-article
- Requête: Query: `iBasket`
- Réponse: JSON: lignes d’articles du panier

### GET /api/get-basket-user
- Requête: — (profil via session/cookies)
- Réponse: JSON: paniers utilisateur

### ANY /api/get-basket-info
- Requête: Query: `iBasket`
- Réponse: JSON: infos panier (totaux, pays, statut)

### ANY /api/get-basket-by-country
- Requête: Query: `iProfile`, `iPaysSelected`
- Réponse: JSON: panier filtré par pays

### ANY /api/get-basket-by-procedur
- Requête: Query: paramètres procédure
- Réponse: JSON: résultats procédure

### GET /api/get-faq-list-question
- Requête: —
- Réponse: JSON: liste des questions FAQ

### GET /api/get-ikea-store-list
- Requête: Query: `lat`, `lng` (optionnels)
- Réponse: JSON: liste des magasins (proximité si coords)

### GET /api/get-info-profil
- Requête: — (profil invité/utilisateur via cookies)
- Réponse: JSON: informations de profil

### GET /api/get-infos-status
- Requête: —
- Réponse: JSON: informations de statut global (service, quotas...)

### ANY /api/get-last-wishlist-by-profil
- Requête: Query: `iProfile`
- Réponse: JSON: dernière wishlist

### GET /api/get-list-pays-basket
- Requête: — (profil invité via cookies)
- Réponse: JSON: liste des pays liés au panier courant

### GET /api/get-pdf-models-list
- Requête: —
- Réponse: JSON: modèles PDF disponibles

### ANY /api/get-profile
- Requête: —
- Réponse: JSON: profils disponibles

### ANY /api/get-profil
- Requête: — (nécessite session)
- Réponse: JSON: profil courant

### ANY /api/get-sPdfDocument-Dtl
- Requête: Query: `iProfile`, `iBasket`, `sPdfDocument`
- Réponse: JSON: détails d’un document PDF

### GET /api/get-sh-magasins
- Requête: —
- Réponse: JSON: liste des magasins `sh_magasins`

### GET /api/get-wishlist-by-profil
- Requête: — (profil via session)
- Réponse: JSON: wishlist par profil

### POST /api/newsletter/confirm
- Requête: Query: `sToken`
- Réponse: JSON: confirmation d’inscription

### GET /api/payment-success
- Requête: Query: identifiants de session/payment
- Réponse: JSON: succès paiement + infos commande

### GET /api/projet
- Requête: — (profil invité/utilisateur via cookies)
- Réponse: JSON: liste de projets/PDF

### POST /api/projet
- Requête: Body: création de projet/PDF (panier, options)
- Réponse: JSON: projet créé (id, meta)

### GET /api/projet-download
- Requête: Query: identifiant de document/projet
- Réponse: Binaire/stream ou JSON contenant URL signée

### GET /api/projet-s3
- Requête: Query: `key` (clé objet S3)
- Réponse: JSON: URL signée ou métadonnées

### POST /api/projet-s3
- Requête: Body: fichier ou référence d’upload
- Réponse: JSON: résultat upload (key, url)

### POST /api/projet-previewpdf
- Requête: Body: `iBasket`, options de rendu
- Réponse: JSON: aperçu (lien/clé)

### ANY /api/profile/update-list/:iprofile
- Requête: Body: liste d’éléments de profil
- Réponse: JSON: mise à jour confirmée

Description: Met à jour une liste liée au profil; nécessite session.

Exemples de réponses:
```json
{ "error": "Utilisateur non autorisé à mettre à jour ce profil" }
```
```json
{ "message": "Profil mis à jour avec succès" }
```
```json
{ "error": "Échec de la mise à jour du profil" }
```

### POST /api/profile/update
- Requête: Body: informations profil à jour
- Réponse: JSON: profil mis à jour

### POST /api/profile/apdatePhoto
- Requête: Body: photo (fichier/URL)
- Réponse: JSON: profil avec photo mise à jour

### GET /api/search-article
- Requête: Query: `q`/texte, pays, pagination
- Réponse: JSON: résultats d’articles

### ANY /api/selected-pays
- Requête: Query/Body: `iPaysSelected`
- Réponse: JSON: pays sélectionné enregistré

### POST /api/stripe/get-session-details
- Requête: Body: `sessionId`
- Réponse: JSON: détails de session Stripe

### POST /api/stripe-webhook
- Requête: Headers: signature Stripe; Body: événement
- Réponse: JSON: statut de traitement

### POST /api/subscribe-newsletter
- Requête: Body: `sEmail`
- Réponse: JSON: statut d’inscription

### GET /api/subscription/get-subscription-plans
- Requête: —
- Réponse: JSON: liste de plans d’abonnement

### GET /api/subscription/get-user-subscription
- Requête: — (profil via session)
- Réponse: JSON: abonnement de l’utilisateur

### POST /api/subscription/manage-subscription
- Requête: Body: action (create/cancel/update)
- Réponse: JSON: statut et/ou URL portail

### ANY /api/test-db
- Requête: —
- Réponse: JSON: succès/erreur de test DB

### ANY /api/translations/:lang
- Requête: Path: `lang`
- Réponse: JSON: clés de traduction pour `lang`

### PUT /api/update-info-profil/:iprofile
- Requête: Path: `iprofile`; Body: infos profil
- Réponse: JSON: mise à jour confirmée

### PUT /api/update-info-profil/:iprofileOld
- Requête: Path: `iprofileOld`; Body: infos profil
- Réponse: JSON: mise à jour confirmée

Description: Met à jour un profil existant; renvoie un message de succès ou d’échec.

Exemples de réponses:
```json
{ "message": "Profil mis à jour avec succès" }
```
```json
{ "error": "Échec de la mise à jour du profil" }
```

### POST /api/update-country-selected
- Requête: Body: `iPaysSelected`
- Réponse: JSON: pays sélectionné mis à jour

### POST /api/update-country-wishlistBasket
- Requête: Body: `iPaysSelected`
- Réponse: JSON: wishlist panier mise à jour

### POST /api/update-listpays
- Requête: Body: `listPays`
- Réponse: JSON: liste pays mise à jour

Description: Ajoute/met à jour la liste des pays associée au profil ou au panier.

Exemples de réponses:
```json
{ "error": "Article non trouvé apres ajout/mise à jour" }
```
```json
{ "success": true, "data": [ { "iPays": 1, "sPays": "FR" } ] }
```
```json
{ "success": false, "error": "Erreur lors de l'exécution de la requête", "details": "<message>", "stack": "<stack>" }
```

### POST /api/update-payList-to-basket
- Requête: Body: `listPays`
- Réponse: JSON: panier mis à jour avec liste pays

### ANY /api/update-profile/:iprofile
- Requête: Path: `iprofile`; Body: données profil
- Réponse: JSON: mise à jour confirmée

### ANY /api/update-quantity-product
- Requête: Query: `iProfile`, `iBasket`, `sCodeArticle`, `iQte`
- Réponse: JSON: mise à jour de quantité

Description: Incrémente ou décrémente la quantité d’un article du panier et renvoie un objet de synthèse de comparaison/prix.

Exemples de réponses:
```json
{ "error": "Paramètres requis manquants", "required": ["iBasket", "sCodeArticle"] }
```
```json
{ "error": "Opération non valide", "validOperations": ["increment", "decrement"] }
```
```json
{ "success": false, "message": "Panier non trouvé" }
```
```json
{ "success": false, "message": "Article XYZ non trouvé dans le panier" }
```
```json
{
  "success": true,
  "data": [
    {
      "sCodeArticle2": "XYZ123",
      "Pays4List": "FR,DE,ES,IT",
      "iprice": 19.99,
      "sPaysName": "France",
      "sName": "Nom de l’article",
      "sComparaison": "Moins cher en FR",
      "iDiffPourcentage": -12
    }
  ]
}
```
```json
{ "error": "Erreur lors de la simulation de mise à jour de quantité", "details": "<message>", "stack": "<stack>" }
```

### POST /api/update-quantity-articleBasket
- Requête: Body: `iBasket`, `sCodeArticle`, `iQte`
- Réponse: JSON: mise à jour confirmée

Description: Met à jour la quantité d’un article dans le panier en se basant sur une procédure SQL et renvoie des données parsées.

Exemples de réponses:
```json
{ "success": false, "error": "No data returned from stored procedure" }
```
```json
{
  "success": true,
  "message": "Quantité  mis à jour avec succès",
  "parsedData": {
    "iBasket": 456,
    "sCodeArticle": "XYZ123",
    "quantity": 3,
    "sNewPaysSelected": "FR",
    "newPriceSelected": 19.99
  }
}
```
```json
{ "error": "Erreur lors de l'exécution de la requête", "details": "<message>", "stack": "<stack>" }
```

### PUT /api/update-validated-product
- Requête: Query: `iProfile`, `iBasket`, `sCodeArticle`, `iQte`
- Réponse: JSON: mise à jour confirmée

Description: Met à jour la quantité d’un article déjà validé dans le panier.

Exemples de réponses:
```json
{ "error": "Paramètres manquants", "required": ["iProfile", "iBasket", "sCodeArticle", "iQte"] }
```
```json
{ "error": "Ce panier n’appartient pas à ce profil." }
```
```json
{
  "success": true,
  "message": "Article mis à jour avec succès.",
  "rowsAffected": 1
}
```
```json
{ "error": "Erreur serveur.", "details": "<message d’erreur>" }
```

### POST /api/user-signup
- Requête: Body: `email`, `password`, etc.
- Réponse: JSON: utilisateur créé + session

Description: Crée un nouvel utilisateur et retourne un statut de création avec les informations de profil.

Exemple réponse:
```json
{
  "status": "created",
  "user": {
    "iProfile": 123,
    "sNom": "Doe",
    "sPrenom": "John",
    "sEmail": "john.doe@example.com",
    "sPhoto": null
  }
}
```

### GET /api/user/stats
- Requête: — (auth requise)
- Réponse: JSON: statistiques utilisateur

### POST /api/user/update
- Requête: Body: champs à mettre à jour
- Réponse: JSON: utilisateur mis à jour

Description: Met à jour les informations d’un utilisateur et renvoie l’objet utilisateur normalisé.

Exemple requête (Body):
```json
{
  "iProfile": 123,
  "sNom": "Doe",
  "sPrenom": "John",
  "sEmail": "john.doe@example.com",
  "sPhoto": "https://.../photo.jpg",
  "sRue": "1 rue Exemple",
  "sZip": "75000",
  "sCity": "Paris",
  "sTel": "+33123456789"
}
```

Exemple réponse:
```json
{
  "success": true,
  "user": {
    "id": 123,
    "nom": "Doe",
    "prenom": "John",
    "email": "john.doe@example.com",
    "photo": "https://.../photo.jpg",
    "rue": "1 rue Exemple",
    "zip": "75000",
    "city": "Paris",
    "tel": "+33123456789"
  }
}
```

### POST /api/validate-product
- Requête: Query: `iProfile`, `sCodeArticle`, `iPrixAchete`, `iQteAchetee`, `iPaysSelected`
- Réponse: JSON: produit validé + état panier

Description: Valide un produit pour un profil et insère la ligne dans le panier via procédure SQL.

Exemples de réponses:
```json
{ "error": "Paramètres manquants", "required": ["iProfile", "sCodeArticle", "iQteAchetee", "iPrixAchete"] }
```
```json
{ "error": "Aucun panier trouvé pour ce profil." }
```
```json
{ "error": "La quantité achetée doit être positive." }
```
```json
{
  "success": true,
  "message": "Validation enregistrée.",
  "createdObject": { "iBasket": 456, "sCodeArticle": "XYZ123", "iQte": 2, "iPrix": 19.99 }
}
```
```json
{ "error": "Erreur serveur.", "details": "<message>" }
```

---

Notes:
- Certains endpoints exigent une session utilisateur ou manipulent un profil invité via cookies (`useAppCookies`).
- Lorsque la structure exacte dépend de procédures SQL, la forme du JSON reflétera les colonnes retournées (listes d’objets).


