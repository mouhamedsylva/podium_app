# Analyse du Backend Apple Sign-In - SNAL-Project

## ✅ Vérification du Backend

### Fichier analysé : `SNAL-Project/server/api/auth/apple-mobile.ts`

### Format de réponse du backend

Le backend retourne bien les identifiants dans le JSON de réponse (lignes 109-114) :

```typescript
return {
  status: "success",
  iProfile: profileData.iProfileEncrypted,
  iBasket: profileData.iBasketProfil,
  email,
};
```

**✅ Le backend retourne bien `iProfile` et `iBasket` dans le JSON**

### Comparaison avec Google Sign-In

Le backend Google (`google-mobile.get.ts`) retourne le même format :

```typescript
return {
  status: "success",
  iProfile: profileData.iProfileEncrypted,
  iBasket: profileData.iBasketProfil,
  email: profileData.email,
};
```

**✅ Les deux endpoints retournent le même format**

## 🔍 Analyse du problème

### 1. Le backend retourne bien les identifiants

Le code backend (lignes 109-114) retourne explicitement :
- `iProfile: profileData.iProfileEncrypted`
- `iBasket: profileData.iBasketProfil`
- `email`

### 2. Le code Flutter cherche les bons champs

Le code Flutter (ligne 2256-2257) cherche :
- `data['iProfile']`
- `data['iBasket']`

**✅ Les noms correspondent**

### 3. Causes possibles du problème

Si l'erreur "Identifiants manquants" persiste, cela peut être dû à :

1. **`profileData.iProfileEncrypted` est `null` ou `undefined`** :
   - La procédure stockée `dbo.proc_user_signup_4All_user_v2` ne retourne pas `iProfileEncrypted`
   - Vérifier les logs backend : `console.log("✅ profileData-for-apple-mobile", profileData);`

2. **`profileData.iBasketProfil` est `null` ou `undefined`** :
   - La procédure stockée ne retourne pas `iBasketProfil`
   - Vérifier les logs backend

3. **Erreur dans la procédure stockée** :
   - La procédure peut échouer silencieusement
   - Vérifier les logs SQL Server

4. **Problème de format de données** :
   - `iProfileEncrypted` peut être un format spécial (varbinary, hex, etc.)
   - Vérifier le type de données retourné

## 🔧 Vérifications à faire

### 1. Vérifier les logs backend

Dans les logs du serveur SNAL, chercher :
```
✅ profileData-for-apple-mobile { ... }
```

Vérifier que `profileData` contient bien :
- `iProfileEncrypted` (non null, non undefined)
- `iBasketProfil` (non null, non undefined)

### 2. Vérifier la procédure stockée

Vérifier que `dbo.proc_user_signup_4All_user_v2` retourne bien :
- `iProfileEncrypted`
- `iBasketProfil`

### 3. Comparer avec Google Sign-In

Si Google Sign-In fonctionne mais pas Apple, comparer :
- Les logs backend pour Google vs Apple
- Les valeurs retournées par la procédure stockée
- Les formats de données

## 📋 Checklist de débogage

- [ ] Vérifier les logs backend lors d'une connexion Apple
- [ ] Vérifier que `profileData.iProfileEncrypted` n'est pas null
- [ ] Vérifier que `profileData.iBasketProfil` n'est pas null
- [ ] Comparer avec les logs Google Sign-In (qui fonctionne)
- [ ] Vérifier la procédure stockée SQL
- [ ] Vérifier les logs Flutter pour voir la réponse complète

## 🔄 Code Flutter amélioré

Le code Flutter a été amélioré pour :
- ✅ Afficher tous les logs détaillés
- ✅ Récupérer depuis les cookies si pas dans le JSON
- ✅ Afficher la réponse complète pour le débogage

## 📝 Conclusion

**Le backend retourne bien les identifiants dans le JSON**. Si l'erreur persiste, le problème vient probablement de :
1. La procédure stockée qui ne retourne pas les valeurs
2. Les valeurs sont `null` ou `undefined`
3. Un problème de format de données

**Action recommandée** : Vérifier les logs backend lors d'une tentative de connexion Apple pour voir ce que `profileData` contient réellement.
