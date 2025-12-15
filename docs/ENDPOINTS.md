## Endpoints API (Nuxt/Nitro)

Note: Les fichiers sous `server/api` définissent automatiquement les routes sous `/api`. Le suffixe du fichier indique souvent la méthode HTTP (ex: `.get.ts`, `.post.ts`, `.put.ts`). Quand la méthode n'est pas explicite, elle peut être gérée dans le handler; ci-dessous elle est marquée «ANY» si non déduite.

### Tableau des endpoints

| Méthode | Chemin | Fichier |
|---|---|---|
| POST | /api/add-article-basket | server/api/add-article-basket.js |
| ANY | /api/add-country-wishlist | server/api/add-country-wishlist.js |
| POST | /api/add-current-article | server/api/add-current-article.js |
| POST | /api/add-pays-listpays | server/api/add-pays-listpays.post.ts |
| ANY | /api/add-product-wishlist | server/api/add-product-wishlist.js |
| POST | /api/add-product-to-wishlist | server/api/add-product-to-wishlist.post.ts |
| ANY | /api/add-to-wishlist | server/api/add-to-wishlist.js |
| POST | /api/auth/auto-login-after-payment | server/api/auth/auto-login-after-payment.post.ts |
| GET | /api/auth/facebook | server/api/auth/facebook.get.ts |
| GET | /api/auth/google | server/api/auth/google.get.ts |
| POST | /api/auth/init | server/api/auth/init.post.ts |
| POST | /api/auth/login | server/api/auth/login.post.ts |
| POST | /api/auth/login-email | server/api/auth/login-email.post.ts |
| POST | /api/auth/quick-signup | server/api/auth/quick-signup.post.ts |
| POST | /api/auth/signup | server/api/auth/signup.post.ts |
| POST | /api/basket-delete-pdf | server/api/basket-delete-pdf.post.ts |
| ANY | /api/cancelled-product | server/api/cancelled-product.js |
| ANY | /api/change-seleceted-country | server/api/change-seleceted-country.js |
| ANY | /api/comparaison | server/api/comparaison.js |
| ANY | /api/comparaison-by-code | server/api/comparaison-by-code.js |
| ANY | /api/comparaison-by-code-30041025 | server/api/comparaison-by-code-30041025.ts |
| POST | /api/contact | server/api/contact.post.ts |
| POST | /api/create-checkout-session | server/api/create-checkout-session.post.ts |
| POST | /api/create-checkout-session-backup | server/api/create-checkout-session-backup.post.ts |
| POST | /api/create-checkout-session-clear | server/api/create-checkout-session-clear.post.ts |
| POST | /api/create-checkout-session-crypted | server/api/create-checkout-session-crypted.post.ts |
| POST | /api/create-checkout-session-encrypt | server/api/create-checkout-session-encrypt.post.ts |
| ANY | /api/db | server/api/db.js |
| ANY | /api/delete-article-wishlist | server/api/delete-article-wishlist.js |
| POST | /api/delete-article-wishlistBasket | server/api/delete-article-wishlistBasket.post.ts |
| POST | /api/delete-article-basket-dtl | server/api/delete-article-basket-dtl.post.ts |
| ANY | /api/delete-country-wishlist | server/api/delete-country-wishlist.js |
| GET | /api/flags | server/api/flags.ts |
| POST | /api/get-all-infos-4country | server/api/get-all-infos-4country.post.ts |
| ANY | /api/get-all-country | server/api/get-all-country.js |
| ANY | /api/get-all-pdf | server/api/get-all-pdf.js |
| ANY | /api/get-article | server/api/getArticle.js |
| GET | /api/get-basket-list-article | server/api/get-basket-list-article.get.ts |
| GET | /api/get-basket-user | server/api/get-basket-user.get.ts |
| ANY | /api/get-basket-info | server/api/get-basket-info.js |
| ANY | /api/get-basket-by-country | server/api/get-basket-by-country.js |
| ANY | /api/get-basket-by-procedur | server/api/get-basket-by-procedur.ts |
| GET | /api/get-faq-list-question | server/api/get-faq-list-question.get.ts |
| GET | /api/get-ikea-store-list | server/api/get-ikea-store-list.get.ts |
| GET | /api/get-info-profil | server/api/get-info-profil.get.ts |
| GET | /api/get-infos-status | server/api/get-infos-status.get.ts |
| ANY | /api/get-last-wishlist-by-profil | server/api/get-last-wishlist-by-profil.js |
| GET | /api/get-list-pays-basket | server/api/get-list-pays-basket.get.ts |
| GET | /api/get-pdf-models-list | server/api/get-pdf-models-list.get.ts |
| ANY | /api/get-profile | server/api/get-profile.js |
| ANY | /api/get-profil | server/api/get-profil/index.js |
| ANY | /api/get-sPdfDocument-Dtl | server/api/get-sPdfDocument-Dtl.js |
| GET | /api/get-sh-magasins | server/api/get-sh-magasins.get.ts |
| GET | /api/get-wishlist-by-profil | server/api/get-wishlist-by-profil.get.ts |
| GET | /api/newsletter/confirm | server/api/newsletter/confirm.post.ts |
| GET | /api/payment-success | server/api/payment-success.get.ts |
| GET | /api/projet | server/api/projet.get.ts |
| POST | /api/projet | server/api/projet.post.ts |
| GET | /api/projet-download | server/api/projet-download.get.ts |
| GET | /api/projet-s3 | server/api/projet-s3.get.ts |
| POST | /api/projet-s3 | server/api/projet-s3.post.ts |
| POST | /api/projet-previewpdf | server/api/projet-previewpdf.post.ts |
| ANY | /api/profile/update-list/:iprofile | server/api/profile/update-list/[iprofile].js |
| POST | /api/profile/update | server/api/profile/update.post.ts |
| POST | /api/profile/apdatePhoto | server/api/profile/apdatePhoto.post.ts |
| GET | /api/search-article | server/api/search-article.get.ts |
| ANY | /api/selected-pays | server/api/selected-pays.js |
| POST | /api/stripe/get-session-details | server/api/stripe/get-session-details.post.ts |
| POST | /api/stripe-webhook | server/api/stripe-webhook.post.ts |
| POST | /api/subscribe-newsletter | server/api/subscribe-newsletter.post.ts |
| GET | /api/subscription/get-subscription-plans | server/api/subscription/get-subscription-plans.get.ts |
| GET | /api/subscription/get-user-subscription | server/api/subscription/get-user-subscription.get.ts |
| POST | /api/subscription/manage-subscription | server/api/subscription/manage-subscription.post.ts |
| ANY | /api/test-db | server/api/test-db.js |
| ANY | /api/translations/:lang | server/api/translations/[lang].ts |
| PUT | /api/update-info-profil/:iprofile | server/api/update-info-profil/[iprofile].put.ts |
| PUT | /api/update-info-profil/:iprofileOld | server/api/update-info-profil/[iprofileOld].put.ts |
| POST | /api/update-country-selected | server/api/update-country-selected.post.ts |
| POST | /api/update-country-wishlistBasket | server/api/update-country-wishlistBasket.post.ts |
| POST | /api/update-listpays | server/api/update-listpays.post.ts |
| POST | /api/update-payList-to-basket | server/api/update-payList-to-basket.post.ts |
| ANY | /api/update-profile/:iprofile | server/api/update-profile/[iprofile].js |
| ANY | /api/update-quantity-product | server/api/update-quantity-product.js |
| POST | /api/update-quantity-articleBasket | server/api/update-quantity-articleBasket.post.ts |
| PUT | /api/update-validated-product | server/api/update-validated-product.js |
| POST | /api/user-signup | server/api/user-signup.post.ts |
| GET | /api/user/stats | server/api/user/stats.get.ts |
| POST | /api/user/update | server/api/user/update.post.ts |
| POST | /api/validate-product | server/api/validate-product.js |

### Appels côté client ($fetch)

Références vues dans le code côté client (non exhaustif si legacy/commenté) :

- GET `/api/projet` (voir `app/composables/callEndpoints/usePdfDocuments.ts`)
- GET `/api/get-sPdfDocument-Dtl?iProfile=...&iBasket=...&sPdfDocument=...` (voir `app/composables/callEndpoints/usePdfDocuments.ts`)
- POST `/api/basket-delete-pdf?iBasket=...` (voir `app/composables/callEndpoints/usePdfDocuments.ts`)
- GET `/api/get-ikea-store-list?lat=...&lng=...` (voir `app/composables/callEndpoints/useGetIkeaStore.ts`)
- POST `/api/validate-product?iProfile=...&sCodeArticle=...&iPrixAchete=...&iQteAchetee=...&iPaysSelected=...` (voir `app/composables/callEndpoints/useValidate*.ts`)
- PUT `/api/update-validated-product?iProfile=...&sCodeArticle=...&iBasket=...&iQte=...` (voir `app/composables/callEndpoints/useValidate*.ts`)
- GET `/api/cancelled-validated-product?iProfile=...&sCodeArticle=...&iBasket=...` (NB: côté serveur l’endpoint est `/api/cancelled-product`) (voir `app/composables/callEndpoints/useValidateProduct.ts`)
- GET `/api/get-info-profil` (voir `app/composables/callEndpoints/useInfoUser.ts`)
- POST `/api/logout` (appelé côté client mais non trouvé dans `server/api`) (voir `app/composables/callEndpoints/useInfoUser.ts`)

Si vous souhaitez, je peux enrichir ce document avec descriptions, paramètres et exemples de réponses en parcourant chaque handler.


