# 🔍 ANALYSE COMPLÈTE DU PROBLÈME WISHLIST

## ❌ SYMPTÔME
`get-basket-list-article` retourne systématiquement :
```json
{
  "success": false,
  "error": "Field 'Pivot' not found in the JSON response."
}
```

## 📊 FLUX OBSERVÉ

### 1. Ajout d'article (`add-product-to-wishlist`)
```
✅ SUCCESS
iBasket envoyé: 0x0200000077CFFC92...
iBasket retourné: 0x02000000F2058222... (DIFFÉRENT!)
sBasketName: "Wishlist (2 Art.)"
```

### 2. Récupération articles (`get-basket-list-article`)
```
❌ ÉCHEC
iBasket envoyé: 0x02000000F2058222...
Réponse: "Field 'Pivot' not found"
```

## 🔍 ANALYSE DU CODE SNAL

### `get-basket-list-article.get.ts` (lignes 22-28)
```typescript
const xml = `
 <root>
   <iProfile>${iProfile}</iProfile>
   <iBasket>${iBasket}</iBasket>
    <sAction>${sAction}</sAction>
 </root>
 `.trim();
```

### Procédure SQL appelée (ligne 39)
```typescript
.execute("dbo.Proc_PickingList_Actions");
```

### Vérification du champ Pivot (lignes 67-72)
```typescript
if (!parsedFirst?.Pivot) {
  return {
    success: false,
    error: "Field 'Pivot' not found in the JSON response.",
  };
}
```

## 🎯 HYPOTHÈSES

### Hypothèse 1: Timing de la base de données
- La procédure SQL `sp_Wishlist_AddArticleNews` crée/met à jour le panier
- Mais `Proc_PickingList_Actions` ne voit pas encore les données
- **Testé:** Délai de 5 secondes → ❌ Toujours échec

### Hypothèse 2: iBasket invalide
- Chaque ajout retourne un `iBasket` différent
- Le nouveau `iBasket` n'est pas encore "prêt" dans la DB
- **Observation:** `get-basket-user` retourne un `iBasket` ENCORE DIFFÉRENT

### Hypothèse 3: Cookie GuestProfile incorrect
- Le cookie doit contenir `iProfile`, `iBasket`, `sPaysLangue`
- **Vérifié:** Cookie correctement formé dans le proxy

### Hypothèse 4: Procédure SQL défectueuse
- `Proc_PickingList_Actions` ne retourne pas `Pivot` pour certains états de panier
- Peut-être que le panier est vide selon la procédure SQL
- **À tester:** Vérifier sur le site SNAL si ça fonctionne

## 📝 CE QUE NOUS ENVOYONS

### Proxy → SNAL
```
URL: https://jirig.be/api/get-basket-list-article?iBasket=0x...
Cookie: GuestProfile={"iProfile":"0x...","iBasket":"0x...","sPaysLangue":"FR/FR"}
```

### XML généré par SNAL
```xml
<root>
  <iProfile>0x...</iProfile>
  <iBasket>0x...</iBasket>
  <sAction>INIT</sAction>
</root>
```

## 🚨 PROBLÈME IDENTIFIÉ

**Le `iBasket` retourné par `add-product-to-wishlist` change à chaque ajout !**

```
Ajout 1: iBasket retourné = 0x0200000077CFFC92...
Ajout 2: iBasket retourné = 0x02000000F2058222... (DIFFÉRENT!)
```

Cela signifie que la procédure SQL `sp_Wishlist_AddArticleNews` **crée un NOUVEAU panier** au lieu de mettre à jour l'ancien.

## 💡 SOLUTIONS POSSIBLES

### Solution 1: Utiliser get-basket-user
```typescript
// 1. Appeler get-basket-user pour obtenir la liste des paniers
const baskets = await getAllBasket4User(iProfile);

// 2. Utiliser le premier panier de la liste
const validIBasket = baskets.data[0].iBasket;

// 3. Appeler get-basket-list-article avec ce iBasket
const articles = await getBasketListArticle(iProfile, validIBasket);
```

### Solution 2: Attendre BEAUCOUP plus longtemps
- Peut-être que la DB SQL a besoin de 10-15 secondes ?
- **Problème:** UX horrible

### Solution 3: Contacter l'équipe SNAL
- Le problème pourrait être côté serveur
- La procédure SQL ne fonctionne peut-être pas correctement

### Solution 4: Utiliser un autre endpoint
- `get-basket-by-procedur` ?
- `get-basket-info` ?

## 🧪 PROCHAINES ÉTAPES

1. ✅ Tester `get-basket-user` après chaque ajout
2. ✅ Vérifier si UN des paniers retournés contient les articles
3. ❌ Si aucun panier ne fonctionne → Problème SQL côté SNAL
4. ✅ Implémenter une solution de contournement

## 📊 LOGS COMPLETS

### Ajout réussi
```
📡 POST /api/add-product-to-wishlist
✅ Article ajouté ! Nouveau iBasket: 0x02000000F2058222...
```

### Récupération échouée
```
📡 GET /api/get-basket-list-article?iBasket=0x02000000F2058222...
❌ Response: {"success":false,"error":"Field 'Pivot' not found"}
```

### Cookie envoyé
```
GuestProfile=%7B%22iProfile%22%3A%220x020000004526EE5F...%22%2C%22iBasket%22%3A%220x02000000F2058...%22%2C%22sPaysLangue%22%3A%22FR%2FFR%22%7D
```

## 🔧 CODE DEBUG ACTUEL

`podium_screen.dart` (lignes 1562-1601):
- Appelle `getAllBasket4User` après ajout
- Teste `getBasketListArticle` avec CHAQUE panier
- Affiche les résultats dans les logs

**ATTENDONS LES RÉSULTATS DU DEBUG !**
