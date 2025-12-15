# Comparaison complète : Login SNAL vs Flutter

## 📋 Vue d'ensemble

Cette document compare l'implémentation complète du système de connexion entre SNAL (Nuxt.js) et Flutter pour identifier les différences et problèmes.

---

## 1️⃣ INTERFACE UTILISATEUR (UI)

### ✅ SNAL (`connexion.vue`)

#### Structure de la page
```vue
<section class="min-h-screen flex">
  <!-- Partie gauche: Image/Visuel (masquée sur mobile) -->
  <div class="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-blue-600 to-blue-700">
    <!-- Motif décoratif avec cercles -->
    <!-- Contenu: "Bienvenue sur Jirig" + animation de points -->
    <!-- Dégradé décoratif en bas -->
  </div>
  
  <!-- Partie droite: Formulaire -->
  <div class="w-full lg:w-1/2 flex flex-col">
    <!-- En-tête mobile (visible uniquement sur mobile) -->
    <div class="lg:hidden bg-gradient-to-r from-blue-600 to-blue-700">
      <h1>Bienvenue sur Jirig</h1>
      <p>Connectez-vous pour commencer</p>
    </div>
    
    <!-- Container du formulaire -->
    <div class="max-w-lg border rounded-2xl shadow-xl p-8">
      <!-- Logo + Titre "Connexion" + Sous-titre "Accédez à votre compte" -->
      
      <!-- Formulaire -->
      <form @submit.prevent="loginWithEmail">
        <!-- Champ Email OU Token (conditionnel selon awaitingToken) -->
        <input v-if="!awaitingToken" type="email" v-model="email" placeholder="votre@email.com" />
        <input v-else type="text" v-model="password" placeholder="Entrez le token reçu par e-mail" />
        
        <!-- Bouton Submit -->
        <UButton type="submit">
          {{ loading ? (awaitingToken ? 'Connexion...' : 'Envoi du lien...') : (awaitingToken ? 'Valider le token' : 'Se connecter avec email') }}
        </UButton>
      </form>
      
      <!-- Séparateur "Ou continuer avec" -->
      
      <!-- Boutons sociaux -->
      <a href="/api/auth/google"><UButton>Continuer avec Google</UButton></a>
      <a href="/api/auth/facebook"><UButton>Continuer avec Facebook</UButton></a>
      
      <!-- Footer avec CGU -->
      <p>En vous connectant, vous acceptez nos Conditions d'utilisation...</p>
    </div>
  </div>
</section>

<!-- Modal "Vérifiez votre email" -->
<UModal v-model="showMailModal">
  <h2>Vérifiez votre email</h2>
  <p>Nous avons envoyé un lien de connexion à <strong>{{ email }}</strong>.</p>
  <p>Cliquez ci-dessous pour ouvrir votre boîte mail :</p>
  <UButton href="https://mail.google.com/mail/u/0/#inbox">Ouvrir Gmail</UButton>
  <UButton href="https://outlook.office.com/mail/">Ouvrir Outlook</UButton>
  <UButton href="https://mail.yahoo.com/">Ouvrir Yahoo Mail</UButton>
  <button @click="showMailModal = false">J'ai reçu le mail, fermer</button>
</UModal>
```

#### Comportement UI
- **Étape 1** : Afficher champ email + bouton "Se connecter avec email"
- **Après envoi** : Champ email devient champ token + bouton devient "Valider le token"
- **Modal** : **NE S'AFFICHE PAS** dans la version active (seulement dans `loginWithEmailOld2`)
- **Loading states** : "Envoi du lien..." ou "Connexion..." selon l'étape

### ✅ Flutter (`login_screen.dart`)

#### Structure de la page
```dart
Scaffold(
  body: Row(
    children: [
      // Partie gauche: Image/Visuel (masquée sur mobile si !isMobile)
      if (!isMobile)
        Expanded(
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(...)),
            child: Stack(
              children: [
                // 4 cercles décoratifs (positions identiques)
                // Texte "Bienvenue sur Jirig" + sous-titre
                // Animation de 3 points qui rebondissent
                // Dégradé décoratif en bas
              ],
            ),
          ),
        ),
      
      // Partie droite: Formulaire
      Expanded(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(borderRadius, border, boxShadow),
            child: Column(
              children: [
                // Logo + Titre "Connexion" + Sous-titre "Accédez à votre compte"
                
                // Champ Email OU Token (conditionnel selon _awaitingToken)
                if (!_awaitingToken)
                  TextField(controller: _emailController, hintText: 'votre@email.com')
                else
                  TextField(controller: _tokenController, hintText: 'Entrez le token reçu par e-mail'),
                
                // Message d'erreur (si _errorMessage.isNotEmpty)
                
                // Bouton Submit
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithEmail,
                  child: _isLoading ? CircularProgressIndicator()
                    : Text(_awaitingToken ? 'Valider le token' : 'Envoi du lien'),
                ),
                
                // Séparateur "Ou continuer avec"
                
                // Boutons sociaux
                OutlinedButton(onPressed: _loginWithGoogle, child: Text('Continuer avec Google')),
                OutlinedButton(onPressed: _loginWithFacebook, child: Text('Continuer avec Facebook')),
                
                // Footer avec CGU
                Text('En vous connectant, vous acceptez nos Conditions d'utilisation...'),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
)

// Fonction _openMailModal() qui affiche le Dialog
void _openMailModal() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      child: Column(
        children: [
          Text('Vérifiez votre email'),
          RichText(text: TextSpan(children: [
            TextSpan(text: 'Nous avons envoyé un lien de connexion à\n'),
            TextSpan(text: _emailController.text.trim(), style: TextStyle(fontWeight: FontWeight.bold)),
          ])),
          Text('Cliquez ci-dessous pour ouvrir votre boîte mail :'),
          ElevatedButton(onPressed: () => launchUrl(...), child: Text('Ouvrir Gmail')),
          ElevatedButton(onPressed: () => launchUrl(...), child: Text('Ouvrir Outlook')),
          ElevatedButton(onPressed: () => launchUrl(...), child: Text('Ouvrir Yahoo Mail')),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("J'ai reçu le mail, fermer")),
        ],
      ),
    ),
  );
}
```

#### Comportement UI
- **Étape 1** : Afficher champ email + bouton "Envoi du lien"
- **Après envoi** : Champ email devient champ token + bouton devient "Valider le token" + **Modal s'affiche**
- **Modal** : S'affiche après un délai de 100ms via `_openMailModal()`
- **Loading states** : CircularProgressIndicator ou texte du bouton

---

## 2️⃣ LOGIQUE DE CONNEXION

### ✅ SNAL (`connexion.vue` - Fonction `loginWithEmail`)

```typescript
const loginWithEmail = async () => {
  try {
    loading.value = true;

    if (!awaitingToken.value) {
      // ✅ ÉTAPE 1 : Demande du lien magique
      await $fetch("/api/auth/login", {
        method: "POST",
        body: { email: email.value },
      });

      awaitingToken.value = true;
      console.log("Lien magique envoyé à", email.value);
      
      // ❌ PAS DE MODAL AFFICHÉ ICI (version active)
      // showMailModal.value = true; // Seulement dans loginWithEmailOld2

    } else {
      // ✅ ÉTAPE 2 : Validation du token
      if (!password.value) {
        throw new Error("Veuillez entrer le token reçu par email");
      }

      await $fetch("/api/auth/login", {
        method: "POST",
        body: {
          email: email.value,
          password: password.value, // token collé par user
        },
      });

      // ✅ Mise à jour de la session utilisateur
      await fetchUserSession();

      // ✅ Redirection avec callBackUrl
      let callBackUrl = (route.query.callBackUrl as string) || getCallBackUrl() || "/";
      callBackUrl = decodeURIComponent(callBackUrl);

      console.log("Redirecting to:", callBackUrl);
      await navigateTo(callBackUrl);
    }
  } catch (e) {
    console.error("Login failed", e);
  } finally {
    loading.value = false;
  }
};
```

**Points clés SNAL :**
1. **Pas de modal** dans la version active (ligne 286-345)
2. **`fetchUserSession()`** après validation du token
3. **Redirection** avec `callBackUrl` récupéré de l'URL ou localStorage
4. **Pas de récupération manuelle du profil** (session côté serveur)

### ✅ Flutter (`login_screen.dart` - Fonction `_loginWithEmail`)

```dart
Future<void> _loginWithEmail() async {
  if (_emailController.text.trim().isEmpty) {
    setState(() {
      _errorMessage = 'Veuillez entrer votre adresse email';
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    if (!_awaitingToken) {
      // ✅ ÉTAPE 1 : Demande du lien magique
      final response = await apiService.login(_emailController.text.trim());
      
      print('📧 Lien magique envoyé à ${_emailController.text}');
      
      setState(() {
        _awaitingToken = true;
        _showMailModal = true;
      });
      
      // ✅ MODAL AFFICHÉ ICI (différence avec SNAL)
      await Future.delayed(Duration(milliseconds: 100));
      if (mounted) {
        _openMailModal();
      }
    } else {
      // ✅ ÉTAPE 2 : Validation du token
      if (_tokenController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Veuillez entrer le token reçu par email';
        });
        return;
      }

      final response = await apiService.login(
        _emailController.text.trim(),
        token: _tokenController.text.trim(),
      );

      print('✅ Connexion réussie');
      
      // ✅ Redirection simple (pas de callBackUrl)
      if (mounted) {
        context.go('/');
      }
    }
  } catch (e) {
    print('❌ Erreur de connexion: $e');
    setState(() {
      _errorMessage = 'Erreur lors de la connexion. Veuillez réessayer.';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
```

**Points clés Flutter :**
1. **Modal affiché** après l'envoi du lien (différence avec SNAL active)
2. **Pas de `fetchUserSession()`** (API service gère la sauvegarde locale)
3. **Redirection simple** vers `/` sans `callBackUrl`
4. **Profil récupéré dans `ApiService.login()`** après validation

---

## 3️⃣ API SERVICE

### ✅ Flutter (`api_service.dart` - Méthode `login`)

```dart
Future<Map<String, dynamic>> login(String email, {String? token}) async {
  try {
    final isTokenValidation = token != null && token.isNotEmpty;
    
    if (isTokenValidation) {
      print('🔑 Validation du token pour: $email');
    } else {
      print('📧 Demande de lien magique pour: $email');
    }

    // ✅ Appel POST /auth/login (via proxy)
    final response = await _dio!.post(
      '/auth/login',
      data: {
        'email': email,
        if (token != null && token.isNotEmpty) 'password': token,
      },
    );

    print('✅ Réponse login: ${response.data}');
    
    // ✅ Si validation du token réussie, récupérer le profil complet
    if (isTokenValidation && response.data != null && response.data is Map) {
      final data = response.data as Map<String, dynamic>;
      
      if (data['status'] == 'OK') {
        print('✅ Connexion validée, récupération du profil...');
        
        // ✅ Appel GET /get-info-profil (via proxy)
        try {
          final profileResponse = await _dio!.get('/get-info-profil');
          
          if (profileResponse.data != null) {
            final profileData = profileResponse.data as Map<String, dynamic>;
            
            print('👤 Profil récupéré: ${profileData.keys.join(', ')}');
            
            // ✅ Sauvegarder le profil complet localement
            await LocalStorageService.saveProfile({
              'iProfile': profileData['iProfile'] ?? '',
              'iBasket': profileData['iBasket'] ?? '',
              'sPaysFav': profileData['sPaysFav'] ?? '',
              'sPaysLangue': profileData['sPaysLangue'] ?? '',
              'sEmail': profileData['sEmail'] ?? email,
              'sNom': profileData['sNom'] ?? '',
              'sPrenom': profileData['sPrenom'] ?? '',
              'sPhoto': profileData['sPhoto'] ?? '',
            });
            
            print('💾 Profil utilisateur sauvegardé localement');
            
            return {
              'status': 'OK',
              'user': profileData,
            };
          }
        } catch (e) {
          print('⚠️ Erreur lors de la récupération du profil: $e');
        }
      } else if (data['status'] == 'FAILED') {
        print('❌ Connexion échouée: Token invalide ou expiré');
      }
    }
    
    return response.data as Map<String, dynamic>;
  } catch (e) {
    print('❌ Erreur login: $e');
    rethrow;
  }
}
```

**Points clés :**
1. **Unique méthode `login()`** pour les 2 étapes (email seul ou email + token)
2. **Récupération du profil** via `/get-info-profil` après validation réussie
3. **Sauvegarde locale** du profil complet dans `LocalStorageService`
4. **Retour structuré** : `{ status: 'OK', user: profileData }`

---

## 4️⃣ BACKEND & PROXY

### ✅ SNAL Backend (`auth/login.post.ts`)

```typescript
export default defineEventHandler(async (event) => {
  const { getGuestProfile, setGuestProfile, setCallBackkUrl } = useAppCookies(event);
  const guestProfile = getGuestProfile(); // Récupère cookie
  const body = await readBody(event);
  const { email, password } = body; // password = token si étape 2

  // ... validation ...

  const pool = await connectToDatabase();

  // ✅ Appel stored procedure avec XML
  const xXml = `
    <root>
        <iProfile>${iProfile}</iProfile>
        <sProvider>magic-link</sProvider>
        <email>${email}</email>
        <password>${password || ''}</password>
        <nom></nom>
        <prenom></prenom>
        <sTypeAccount>${sTypeAccount}</sTypeAccount>
        <iPaysOrigine>${sPaysLangue}</iPaysOrigine>
        <sLangue>${sPaysLangue}</sLangue>
        <sPaysListe>${sPaysListe}</sPaysListe>
        <sPaysLangue>${sPaysLangue}</sPaysLangue>
    </root>
  `.trim();

  const tokenDetail = await pool
    .request()
    .input("xXml", sql.Xml, xXml)
    .execute("dbo.proc_user_signup_4All_user_v2");

  const result = tokenDetail.recordset[0];

  // ... gestion callBackUrl ...
  if (result.callBackUrl) {
    setCallBackkUrl(result.callBackUrl);
  }

  if (password && result && result.iProfileEncrypted) {
    // ✅ ÉTAPE 2 : Token validé, profil trouvé
    
    // ✅ Mise à jour du cookie GuestProfile
    setGuestProfile({
      iProfile: result.iProfileEncrypted,
      iBasket: result.iBasketMagikLink,
      sPaysLangue: result.sPaysLangue,
    });

    // ✅ Création de la session utilisateur côté serveur
    await setUserSession(event, {
      user: {
        iProfile: result.iProfileEncrypted,
        sNom: result.sNom,
        sPrenom: result.sPrenom,
        sEmail: result.sEmail,
        sPhoto: result.sPhoto,
        // ... autres champs ...
      },
      loggedInAt: Date.now(),
      loggedIn: true,
    });
    
    return {
      status: "OK",
    };
  } else if (password) {
    // ❌ ÉTAPE 2 : Token invalide
    return {
      status: "FAILED",
      user: {},
    };
  } else {
    // ✅ ÉTAPE 1 : Token généré (envoyé par email)
    return {
      status: "waiting token",
    };
  }
});
```

**Points clés :**
1. **Session côté serveur** via `setUserSession()`
2. **Cookie `GuestProfile`** mis à jour avec `iProfile`, `iBasket`, `sPaysLangue`
3. **CallBackUrl** stocké dans un cookie
4. **Pas de retour des données utilisateur** (juste `status: 'OK'`)

### ✅ SNAL Backend (`get-info-profil.get.ts`)

```typescript
export default defineEventHandler(async (event) => {
  const { getGuestProfile } = useAppCookies(event);
  const guestProfile = getGuestProfile(); // cookie
  const { user } = await getUserSession(event); // session
  const userProfile = guestProfile;

  const pool = await connectToDatabase();
  const { iProfile } = userProfile;

  // ✅ Appel stored procedure pour récupérer le profil complet
  const xXml = `
    <root>
      <iProfile>${iProfile}</iProfile>
    </root>
  `.trim();

  const result = await pool
    .request()
    .input("xXml", sql.Xml, xXml)
    .execute("proc_profile_getInfo");

  if (result.recordset.length > 0) {
    return result.recordset[0]; // Retourner les données du profil
  } else {
    return { message: "Aucun profil trouvé" };
  }
});
```

**Points clés :**
1. **Récupère `iProfile`** depuis le cookie `GuestProfile`
2. **Appel stored procedure** `proc_profile_getInfo`
3. **Retourne toutes les données du profil** (`iProfile`, `iBasket`, `sEmail`, `sNom`, `sPrenom`, etc.)

### ✅ Proxy Flutter (`proxy-server.js`)

#### Endpoint `/api/auth/login`

```javascript
app.post('/api/auth/login', express.json(), async (req, res) => {
  const { email, password } = req.body;
  
  // ✅ Récupération du cookie GuestProfile
  const cookies = req.headers.cookie || '';
  const guestProfileMatch = cookies.match(/GuestProfile=([^;]+)/);
  let guestProfile = { iProfile: '', iBasket: '', sPaysLangue: '', sPaysFav: '' };
  
  if (guestProfileMatch) {
    guestProfile = JSON.parse(decodeURIComponent(guestProfileMatch[1]));
  }
  
  // ✅ Construction du cookie pour SNAL
  const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
  
  // ✅ Appel à l'API SNAL
  const fetch = require('node-fetch');
  const response = await fetch(`https://jirig.be/api/auth/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Cookie': cookieString,
      'User-Agent': 'Mobile-Flutter-App/1.0'
    },
    body: JSON.stringify({ email, password })
  });
  
  // ✅ Transfert des cookies Set-Cookie de SNAL vers Flutter
  const setCookieHeaders = response.headers.raw()['set-cookie'];
  if (setCookieHeaders && setCookieHeaders.length > 0) {
    res.set('Set-Cookie', setCookieHeaders);
  }
  
  const data = await response.json();
  res.json(data);
});
```

#### Endpoint `/api/get-info-profil`

```javascript
app.get('/api/get-info-profil', async (req, res) => {
  // ✅ Récupération du cookie GuestProfile
  const cookies = req.headers.cookie || '';
  const guestProfileMatch = cookies.match(/GuestProfile=([^;]+)/);
  
  if (!guestProfileMatch) {
    return res.status(401).json({ error: 'Non authentifié' });
  }
  
  const guestProfile = JSON.parse(decodeURIComponent(guestProfileMatch[1]));
  const iProfile = guestProfile.iProfile || '';
  
  // ✅ Construction du cookie pour SNAL
  const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
  
  // ✅ Appel à l'API SNAL
  const response = await fetch(`https://jirig.be/api/get-info-profil`, {
    method: 'GET',
    headers: {
      'Accept': 'application/json',
      'Cookie': cookieString,
      'User-Agent': 'Mobile-Flutter-App/1.0'
    }
  });
  
  const data = await response.json();
  res.json(data);
});
```

**Points clés du proxy :**
1. **Gestion des cookies** entre Flutter et SNAL
2. **Transfert des `Set-Cookie`** de SNAL vers Flutter
3. **Construction du cookie `GuestProfile`** pour chaque requête vers SNAL
4. **Appel à `https://jirig.be`** (production SNAL)

---

## 🔍 DIFFÉRENCES PRINCIPALES

| Aspect | SNAL | Flutter |
|--------|------|---------|
| **Modal "Vérifiez votre email"** | ❌ Non affiché (version active) | ✅ Affiché après envoi du lien |
| **Gestion de session** | ✅ Session côté serveur (`setUserSession`) | ❌ Session locale (`LocalStorageService`) |
| **Récupération du profil** | ✅ Automatique via session | ✅ Manuelle via `/get-info-profil` |
| **CallBackUrl** | ✅ Géré (URL query + localStorage + cookie) | ❌ Non géré (redirection vers `/`) |
| **Texte bouton (étape 1)** | "Se connecter avec email" | "Envoi du lien" |
| **Texte bouton (loading)** | "Envoi du lien..." | CircularProgressIndicator |
| **En-tête mobile** | ✅ Affiché sur mobile uniquement | ❌ Commenté dans le code |
| **Boutons sociaux** | Liens `<a href="/api/auth/...">` | Fonctions `_loginWithGoogle/Facebook` (TODO) |
| **Footer CGU** | ✅ Affiché | ✅ Affiché |

---

## ⚠️ PROBLÈMES IDENTIFIÉS

### 1. **Modal non conforme à SNAL**
- **SNAL** : Le modal n'est pas affiché dans la version active (`loginWithEmail`)
- **Flutter** : Le modal est affiché après l'envoi du lien
- **Impact** : Différence UX majeure

### 2. **CallBackUrl non géré**
- **SNAL** : Récupère `callBackUrl` de l'URL, localStorage ou cookie, puis redirige
- **Flutter** : Redirige toujours vers `/` après connexion
- **Impact** : Impossible de revenir à la page d'origine après connexion

### 3. **Boutons sociaux non fonctionnels**
- **SNAL** : Liens directs vers `/api/auth/google` et `/api/auth/facebook`
- **Flutter** : Fonctions vides avec TODO
- **Impact** : Connexion Google/Facebook ne fonctionne pas

### 4. **En-tête mobile commenté**
- **SNAL** : Affiche un bandeau bleu sur mobile avec "Bienvenue sur Jirig"
- **Flutter** : Code commenté (lignes 372-408)
- **Impact** : UX mobile incomplète

### 5. **Texte des boutons différents**
- **SNAL** : "Se connecter avec email" → "Envoi du lien..." → "Valider le token" → "Connexion..."
- **Flutter** : "Envoi du lien" → Spinner → "Valider le token" → Spinner
- **Impact** : Manque de feedback textuel pendant le chargement

---

## ✅ CORRECTIONS À APPORTER

### 1. **Supprimer ou désactiver le modal (pour correspondre à SNAL)**

```dart
// OPTION A : Ne pas afficher le modal (comme SNAL active)
if (!_awaitingToken) {
  final response = await apiService.login(_emailController.text.trim());
  
  print('📧 Lien magique envoyé à ${_emailController.text}');
  
  setState(() {
    _awaitingToken = true;
    // _showMailModal = true; // ❌ Ne pas afficher
  });
  
  // ❌ Ne pas appeler _openMailModal()
}

// OPTION B : Afficher le modal comme dans loginWithEmailOld2 de SNAL
// (garder le code actuel)
```

### 2. **Implémenter la gestion du callBackUrl**

```dart
// Ajouter un paramètre callBackUrl à LoginScreen
class LoginScreen extends StatefulWidget {
  final String? callBackUrl;
  const LoginScreen({Key? key, this.callBackUrl}) : super(key: key);
}

// Après connexion réussie
if (mounted) {
  final destination = widget.callBackUrl ?? '/';
  context.go(destination);
}
```

### 3. **Implémenter les boutons sociaux**

```dart
Future<void> _loginWithGoogle() async {
  // Option 1 : Ouvrir dans le navigateur
  await launchUrl(
    Uri.parse('http://localhost:3001/api/auth/google'),
    mode: LaunchMode.externalApplication,
  );
  
  // Option 2 : Utiliser WebView + deep linking (plus complexe)
}

Future<void> _loginWithFacebook() async {
  await launchUrl(
    Uri.parse('http://localhost:3001/api/auth/facebook'),
    mode: LaunchMode.externalApplication,
  );
}
```

### 4. **Activer l'en-tête mobile**

```dart
// Décommenter les lignes 372-408 dans login_screen.dart
if (isMobile)
  Container(
    padding: EdgeInsets.all(24),
    margin: EdgeInsets.only(bottom: 24),
    decoration: BoxDecoration(
      gradient: LinearGradient(...),
    ),
    child: Column(
      children: [
        Text('Bienvenue sur Jirig', ...),
        SizedBox(height: 8),
        Text('Connectez-vous pour commencer', ...),
      ],
    ),
  ),
```

### 5. **Améliorer les textes des boutons**

```dart
ElevatedButton(
  onPressed: _isLoading ? null : _loginWithEmail,
  child: _isLoading
      ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(...),
            ),
            SizedBox(width: 12),
            Text(_awaitingToken ? 'Connexion...' : 'Envoi du lien...'),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 20),
            SizedBox(width: 8),
            Text(
              _awaitingToken
                  ? 'Valider le token'
                  : 'Se connecter avec email',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
),
```

---

## 📊 CONCLUSION

L'implémentation Flutter est **très proche de SNAL** au niveau UI et logique, mais présente quelques différences :

### ✅ Points conformes
- Structure UI (2 colonnes, gauche = image, droite = formulaire)
- Formulaire avec champ email/token conditionnel
- Séparateur et boutons sociaux
- Logique de connexion en 2 étapes
- Appel aux mêmes endpoints API (`/auth/login`, `/get-info-profil`)
- Modal "Vérifiez votre email" stylisé correctement

### ⚠️ Points à corriger
1. **Modal affiché** (SNAL ne l'affiche pas dans la version active)
2. **CallBackUrl non géré** (impossible de revenir à la page d'origine)
3. **Boutons sociaux non fonctionnels** (TODO)
4. **En-tête mobile commenté** (UX incomplète)
5. **Texte des boutons** (manque de feedback pendant le chargement)

### 🎯 Recommandation

**Décider quelle version du modal suivre :**
- **Option A** : Suivre la version active de SNAL (pas de modal) → Simple, mais moins user-friendly
- **Option B** : Suivre `loginWithEmailOld2` de SNAL (avec modal) → Meilleure UX, correspond à l'image fournie par l'utilisateur

**Prioriser :**
1. **Gestion du callBackUrl** (important pour UX)
2. **Boutons sociaux** (fonctionnalité majeure)
3. **Textes des boutons** (feedback utilisateur)
4. **En-tête mobile** (UX mobile)
5. **Modal** (selon la décision stratégique)

