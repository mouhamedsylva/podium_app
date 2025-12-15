# 🔍 Debug - Erreur 500 Login Production

## ❌ Problème actuel

L'appel à `https://jirig.be/api/auth/login` retourne une erreur 500 :

```
{
  "error": true,
  "url": "http://jirig.be/api/auth/login",
  "statusCode": 500,
  "statusMessage": "Server Error",
  "message": "An error occurred during signup"
}
```

## 🔎 Analyse

### Le message d'erreur indique :
- **"An error occurred during signup"** 
- Cela vient du backend SNAL (`SNAL-Project/server/api/auth/login.post.ts`)
- L'erreur est levée à la ligne 236-240 du fichier `login.post.ts`

### Raisons possibles :

1. **❌ Service email non configuré en production**
   - SNAL essaie d'envoyer un email avec le token magique
   - Le service d'envoi d'email (SMTP) n'est pas configuré en prod

2. **❌ Base de données non accessible**
   - Le serveur de production ne peut pas se connecter à la base SQL
   - La stored procedure `proc_user_signup_4All_user_v2` échoue

3. **❌ Problème avec le GuestProfile**
   - Le cookie `GuestProfile` envoyé est invalide
   - `iProfile`, `sPaysLangue`, ou `sPaysFav` manquants/incorrects

4. **❌ Configuration serveur manquante**
   - Variables d'environnement manquantes en production
   - Clés API ou secrets non configurés

## 🛠️ Solutions à tester

### Solution 1 : Vérifier les logs du serveur SNAL en production

```bash
# Sur le serveur de production, vérifier les logs
pm2 logs snal
# ou
journalctl -u snal -f
```

Les logs devraient indiquer l'erreur exacte (connexion DB, envoi email, etc.)

### Solution 2 : Tester l'endpoint directement

Tester l'endpoint de production avec curl pour voir l'erreur détaillée :

```bash
curl -X POST https://jirig.be/api/auth/login \
  -H "Content-Type: application/json" \
  -H "Cookie: GuestProfile=%7B%22iProfile%22%3A%22%22%2C%22iBasket%22%3A%22%22%2C%22sPaysLangue%22%3A%22FR-fr%22%2C%22sPaysFav%22%3A%22%22%7D" \
  -d '{"email":"test@example.com"}' \
  -v
```

### Solution 3 : Utiliser le serveur local temporairement

Si le serveur de production a des problèmes, utilise le serveur local pour le développement :

1. **Démarrer SNAL en local** :
```bash
cd SNAL-Project
npm run dev
```

2. **Modifier le proxy pour pointer vers localhost** :

Dans `jirig/proxy-server.js`, remplacer :
```javascript
// Ligne 1128
const response = await fetch(`http://localhost:3000/api/auth/login`, {
  
// Ligne 1266
const response = await fetch(`http://localhost:3000/api/get-info-profil`, {
```

3. **Redémarrer le proxy** :
```bash
cd jirig
node proxy-server.js
```

### Solution 4 : Ajouter plus de logs dans le proxy

Pour mieux comprendre ce qui est envoyé :

```javascript
// Dans proxy-server.js, ligne ~1095
app.post('/api/auth/login', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/LOGIN: Connexion avec Magic Link`);
  console.log(`${'*'.repeat(70)}`);
  
  const { email, password } = req.body;
  
  console.log(`📧 Email reçu: ${email}`);
  console.log(`🔑 Password/Token: ${password ? '***' : '(vide)'}`);
  
  // Récupérer le GuestProfile existant
  const cookies = req.headers.cookie || '';
  console.log(`🍪 Cookies reçus de Flutter:`, cookies);
  
  // ... reste du code
});
```

### Solution 5 : Vérifier la configuration du GuestProfile

Le problème peut venir du `GuestProfile` initial. Vérifions ce qui est envoyé :

```javascript
// Dans le proxy, afficher plus d'infos
console.log(`\n${'='.repeat(60)}`);
console.log(`🍪 COOKIE GUESTPROFILE DÉTAILLÉ:`);
console.log(`${'='.repeat(60)}`);
console.log(`iProfile: "${guestProfile.iProfile}" (type: ${typeof guestProfile.iProfile})`);
console.log(`iBasket: "${guestProfile.iBasket}" (type: ${typeof guestProfile.iBasket})`);
console.log(`sPaysLangue: "${guestProfile.sPaysLangue}" (type: ${typeof guestProfile.sPaysLangue})`);
console.log(`sPaysFav: "${guestProfile.sPaysFav}" (type: ${typeof guestProfile.sPaysFav})`);
console.log(`${'='.repeat(60)}\n`);
```

## 🎯 Action recommandée

**Option A - Debug production** :
1. Accéder aux logs du serveur SNAL en production
2. Identifier l'erreur exacte (DB, email, etc.)
3. Corriger la configuration en production

**Option B - Utiliser local temporairement** :
1. Démarrer SNAL en local (`npm run dev`)
2. Modifier le proxy pour pointer vers `http://localhost:3000`
3. Développer et tester en local
4. Une fois fonctionnel, basculer vers la production

## 📝 Informations utiles

### Structure du GuestProfile attendu par SNAL

```javascript
{
  "iProfile": "",           // ID du profil (vide pour guest)
  "iBasket": "",            // ID du panier (vide pour nouveau)
  "sPaysLangue": "FR-fr",   // Langue et pays (ex: FR-fr, BE-fr, etc.)
  "sPaysFav": ""            // Pays favoris (vide ou JSON array)
}
```

### Endpoint SNAL local vs production

| Environnement | URL | Utilisation |
|--------------|-----|-------------|
| **Local** | `http://localhost:3000` | Développement, debug |
| **Production** | `https://jirig.be` | Utilisateurs réels |

## ⚠️ Note importante

L'erreur **"An error occurred during signup"** est une erreur générique du serveur SNAL. 
Pour obtenir plus de détails, il faut :
1. Accéder aux logs serveur (`pm2 logs` ou `journalctl`)
2. Vérifier la base de données
3. Tester la configuration email

Sans accès aux logs du serveur de production, il est difficile de diagnostiquer précisément le problème.

