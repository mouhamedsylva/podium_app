# Correction de l'erreur Apple Sign-In "Identifiants manquants dans la réponse Apple mobile"

## 🔍 Problème identifié

L'erreur "Identifiants manquants dans la réponse Apple mobile" se produit lorsque le backend ne retourne pas `iProfile` et `iBasket` dans le JSON de réponse.

## ✅ Corrections apportées

### 1. Amélioration de la gestion d'erreur

Le code vérifie maintenant :
- ✅ Les identifiants dans le JSON de réponse
- ✅ Les identifiants dans les cookies (Set-Cookie headers)
- ✅ Logs détaillés pour le débogage

### 2. Récupération depuis les cookies

Si `iProfile` et `iBasket` ne sont pas dans le JSON mais sont présents dans les cookies, le code les récupère automatiquement.

## 🔧 Vérifications nécessaires

### 1. Backend - Endpoint `/api/auth/apple-mobile`

Vérifiez que votre endpoint backend retourne bien les identifiants dans la réponse JSON :

**Format attendu** :
```json
{
  "status": "success",
  "iProfile": "0x02000000...",
  "iBasket": "12345",
  "email": "user@example.com"
}
```

**OU** dans les cookies Set-Cookie :
```
Set-Cookie: iProfile=0x02000000...; Path=/; HttpOnly
Set-Cookie: iBasket=12345; Path=/; HttpOnly
Set-Cookie: GuestProfile={...}; Path=/; HttpOnly
```

### 2. Vérifier les logs

Après la correction, les logs afficheront :
- Toutes les clés de la réponse
- Les valeurs de `iProfile` et `iBasket`
- Les cookies reçus
- La réponse complète

Exemple de logs :
```
✅ Réponse apple-mobile: {...}
📋 Toutes les clés de la réponse: [status, email, ...]
🔍 Identifiants récupérés depuis la réponse:
   iProfile: null (type: Null)
   iBasket: null (type: Null)
   email: user@example.com
🍪 Cookies reçus: [iProfile=0x02000000...; Path=/; HttpOnly, ...]
   ✅ iProfile trouvé dans cookie: 0x02000000...
   ✅ iBasket trouvé dans cookie: 12345
```

### 3. Backend SNAL - Vérification

Vérifiez dans votre backend SNAL (`server/api/auth/apple-mobile.ts`) que :

1. **Les identifiants sont retournés dans le JSON** :
   ```typescript
   return {
     status: 'success',
     iProfile: result.iProfile,
     iBasket: result.iBasket,
     email: result.email,
   };
   ```

2. **OU les identifiants sont dans les cookies** :
   ```typescript
   setCookie(event, 'iProfile', result.iProfile, { ... });
   setCookie(event, 'iBasket', result.iBasket, { ... });
   ```

## 🐛 Dépannage

### Si l'erreur persiste

1. **Vérifier les logs Flutter** :
   ```bash
   flutter run --verbose
   ```
   Cherchez les lignes avec :
   - `✅ Réponse apple-mobile:`
   - `🔍 Identifiants récupérés depuis la réponse:`
   - `🍪 Cookies reçus:`

2. **Vérifier la réponse du backend** :
   - Ouvrir les DevTools du navigateur (si test web)
   - Vérifier l'onglet Network
   - Regarder la réponse de `/api/auth/apple-mobile`

3. **Vérifier le backend SNAL** :
   - Vérifier que l'endpoint `/api/auth/apple-mobile` retourne bien les identifiants
   - Vérifier les logs du serveur

### Erreurs courantes

1. **Backend retourne seulement les cookies** :
   - ✅ **Corrigé** : Le code récupère maintenant depuis les cookies

2. **Backend ne retourne pas les identifiants du tout** :
   - Vérifier la procédure stockée SQL
   - Vérifier que `result.iProfile` et `result.iBasket` sont bien récupérés

3. **Format de réponse incorrect** :
   - Vérifier que `status === 'success'`
   - Vérifier que les identifiants ne sont pas `null` ou `undefined`

## 📋 Checklist

- [x] Code Flutter amélioré pour récupérer depuis les cookies
- [x] Logs détaillés ajoutés
- [ ] Backend retourne `iProfile` et `iBasket` dans le JSON OU dans les cookies
- [ ] Tester la connexion Apple Sign-In
- [ ] Vérifier les logs pour confirmer la récupération des identifiants

## 🔄 Test après correction

1. **Nettoyer et rebuilder** :
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Tester la connexion Apple** :
   - Cliquer sur "Continuer avec Apple"
   - Vérifier les logs dans la console
   - Vérifier que les identifiants sont récupérés

3. **Vérifier les logs** :
   - Chercher `✅ iProfile trouvé dans cookie:` ou `✅ Connexion Apple réussie - identifiants mis à jour`

## 📝 Notes

- Le code récupère maintenant les identifiants depuis les cookies si ils ne sont pas dans le JSON
- Les logs sont plus détaillés pour faciliter le débogage
- Si les identifiants ne sont ni dans le JSON ni dans les cookies, l'erreur sera plus descriptive
