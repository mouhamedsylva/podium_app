const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = 3001;
const FLUTTER_APP_URL = process.env.FLUTTER_APP_URL || 'http://localhost:3000';

// Servir les fichiers statiques (pour oauth-callback.html)
app.use(express.static(path.join(__dirname, 'web')));

// Middleware CORS pour permettre toutes les origines Flutter Web
app.use(cors({
  origin: true, // ✅ Permettre TOUTES les origines en développement
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['content-type', 'authorization', 'x-requested-with', 'accept', 'x-iprofile', 'x-ibasket', 'x-paysfav', 'x-spaysfav', 'x-pays-langue', 'x-pays-fav', 'x-guest-profile'],
  credentials: true
}));

// Fonction helper pour récupérer le GuestProfile depuis les headers
function getGuestProfileFromHeaders(req) {
  const guestProfileHeader = req.headers['x-guest-profile'];
  let profile = { iProfile: '', iBasket: '', sPaysLangue: '', sPaysFav: '' };
  
  if (guestProfileHeader) {
    try {
      profile = JSON.parse(guestProfileHeader);
    } catch (e) {
      console.log(`⚠️ Erreur parsing GuestProfile header:`, e.message);
    }
  }
  
  return profile;
}

// Middleware pour les logs
app.use((req, res, next) => {
  console.log(`📡 ${req.method} ${req.url}`);
  next();
});

// Middleware spécial pour /comparaison-by-code-30041025 - détails du produit
app.get('/api/comparaison-by-code-30041025', async (req, res) => {
  console.log(`🏆 COMPARAISON: Détails du produit`);
  
  try {
    const { sCodeArticle, iProfile, iBasket, iQuantite } = req.query;
    
    console.log(`🏆 Paramètres reçus:`, { sCodeArticle, iProfile, iBasket, iQuantite });

    // Le sCodeArticle reçu du Flutter est déjà sCodeArticleCrypt (voir api_service.dart)
    const sCodeArticleCrypt = sCodeArticle;
    console.log(`🔐 Code crypté à utiliser: ${sCodeArticleCrypt}`);

    // Utiliser directement iProfile et iBasket
    const iProfileValue = iProfile || '';
    const iBasketValue = iBasket || '';
    
    console.log(`📦 iProfile: ${iProfileValue}`);
    console.log(`🛒 iBasket: ${iBasketValue}`);
    
    // Créer le profil guest exactement comme SNAL-Project l'attend
    const guestProfile = {
      iProfile: iProfileValue,
      iBasket: iBasketValue
    };
    
    console.log(`👤 GuestProfile créé:`, guestProfile);

    // Créer le cookie GuestProfile comme SNAL-Project l'attend
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    console.log(`🍪 Cookie GuestProfile créé:`, cookieString);

    // Construire l'URL - SNAL attend SEULEMENT sCodeArticle en query param
    // iProfile et iBasket sont envoyés via le cookie GuestProfile
    const params = new URLSearchParams({
      sCodeArticle: sCodeArticleCrypt,
      iQuantite: iQuantite || '1'
    });

    console.log(`🏆 URL avec cookies:`, `https://jirig.be/api/comparaison-by-code-30041025?${params}`);

    // Faire la requête GET vers l'API SNAL-Project avec le cookie
    console.log(`🏆 Faire la requête vers: https://jirig.be/api/comparaison-by-code-30041025?${params}`);
    
    const response = await fetch(`https://jirig.be/api/comparaison-by-code-30041025?${params}`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });

    console.log(`🏆 Response status: ${response.status}`);
    console.log(`🏆 Response headers:`, Object.fromEntries(response.headers.entries()));

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`🏆 Error response body:`, errorText);
      
      // Retourner une erreur
      res.status(response.status).json({
        success: false,
        error: 'API SNAL-Project Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText,
        requestedUrl: `https://jirig.be/api/comparaison-by-code-30041025?${params}`
      });
      return;
    }

    const data = await response.json();
    console.log(`🏆 API Response:`, data);
    
    res.json(data);
  } catch (error) {
    console.error('❌ Comparaison Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des détails du produit',
      message: error.message
    });
  }
});

// Middleware spécial pour /search-article - recherche mobile-first
app.get('/api/search-article', async (req, res) => {
  console.log(`🔍 SEARCH-ARTICLE: Recherche d'articles`);
  
  try {
    const { search, token, limit, type } = req.query;
    
    console.log(`🔍 Paramètres URL reçus:`, { search, token, limit, type });

    // IMPORTANT: SNAL-Project utilise UNIQUEMENT les paramètres 'search' et 'limit'
    // Les autres paramètres (iProfile, iBasket, sPaysLangue) viennent des COOKIES
    
    // Récupérer le GuestProfile depuis le header
    const guestProfileHeader = req.headers['x-guest-profile'];
    let existingProfile = { iProfile: '', iBasket: '', sPaysLangue: '', sPaysFav: '' };
    
    if (guestProfileHeader) {
      try {
        existingProfile = JSON.parse(guestProfileHeader);
      } catch (e) {
        console.log(`⚠️ Erreur parsing GuestProfile header:`, e.message);
      }
    }
    
    // Créer le profil guest exactement comme SNAL-Project l'attend
    const guestProfile = {
      iProfile: token || existingProfile.iProfile || '',
      iBasket: existingProfile.iBasket || '', // SNAL-Project récupère le basket depuis la DB
      sPaysLangue: existingProfile.sPaysLangue || '' // Utiliser celui du profil
    };
    
    console.log(`👤 GuestProfile pour cookie:`, guestProfile);

    // Créer le cookie GuestProfile comme SNAL-Project l'attend
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;

    // Construire l'URL avec SEULEMENT search et limit (comme SNAL-Project)
    const params = new URLSearchParams({
      search: search,
      limit: limit || 10,
    });

    console.log(`📱 Appel SNAL API: https://jirig.be/api/search-article?${params}`);
    console.log(`🍪 Cookie envoyé: iProfile=${token ? token.substring(0, 20) + '...' : '(vide)'}`);

    // Faire la requête GET vers l'API SNAL-Project avec le cookie
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/search-article?${params}`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });

    const data = await response.json();
    console.log(`📡 API Response type:`, Array.isArray(data) ? `Array (${data.length} items)` : 'Object');
    console.log(`📡 API Response:`, data);
    
    res.json(data);
  } catch (error) {
    console.error('❌ Search-Article Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la recherche',
      message: error.message
    });
  }
});

// Middleware spécial pour /add-product-to-wishlist - ajouter un article au panier
app.post('/api/add-product-to-wishlist', express.json(), async (req, res) => {
  console.log(`\n${'='.repeat(70)}`);
  console.log(`🛒 ADD-PRODUCT-TO-WISHLIST: Ajout d'un article`);
  console.log(`${'='.repeat(70)}`);
  
  try {
    const body = req.body;
    console.log(`🛒 Body reçu complet:`, JSON.stringify(body, null, 2));
    console.log(`📦 sCodeArticle: ${body.sCodeArticle}`);
    console.log(`🌍 sPays: ${body.sPays}`);
    console.log(`💰 iPrice: ${body.iPrice}`);
    console.log(`📊 iQuantity: ${body.iQuantity}`);
    console.log(`🛒 currenentibasket: ${body.currenentibasket}`);
    console.log(`👤 iProfile: ${body.iProfile}`);
    console.log(`🌐 sPaysLangue: ${body.sPaysLangue}`);
    console.log(`🏳️  sPaysFav: ${body.sPaysFav}`);

    // Récupérer les valeurs depuis le body
    // Récupérer le GuestProfile depuis le header
    const guestProfileHeader = req.headers['x-guest-profile'];
    let existingProfile = { iProfile: '', iBasket: '', sPaysLangue: '', sPaysFav: '' };
    
    if (guestProfileHeader) {
      try {
        existingProfile = JSON.parse(guestProfileHeader);
      } catch (e) {
        console.log(`⚠️ Erreur parsing GuestProfile header:`, e.message);
      }
    }
    
    const iProfile = body.iProfile || existingProfile.iProfile || '';
    const iBasket = body.currenentibasket || existingProfile.iBasket || '';
    const sPaysLangue = body.sPaysLangue || existingProfile.sPaysLangue || '';
    const sPaysFav = body.sPaysFav || existingProfile.sPaysFav || [];
    
    // Créer le profil guest pour le cookie
    const guestProfile = {
      iProfile: iProfile,
      iBasket: iBasket,
      sPaysLangue: sPaysLangue, // ✅ Utiliser la valeur du body
      sPaysFav: sPaysFav
    };
    
    console.log(`👤 GuestProfile créé:`, guestProfile);

    // Créer le cookie GuestProfile
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;

    console.log(`📱 Appel SNAL API: https://jirig.be/api/add-product-to-wishlist`);
    console.log(`🍪 Cookie: ${cookieString.substring(0, 150)}...`);
    console.log(`📤 Body à envoyer à SNAL:`, JSON.stringify(body, null, 2));

    // Faire la requête POST vers l'API SNAL-Project avec le cookie
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/add-product-to-wishlist`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      },
      body: JSON.stringify(body),
      timeout: 60000 // ✅ Timeout de 60 secondes
    });

    const responseText = await response.text();
    console.log(`📡 Response RAW:`, responseText);
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`📡 API Response parsed:`, data);
      
      // 🔍 Log détaillé du iBasket retourné
      if (data.success && data.data && data.data.length > 0) {
        console.log(`✅ Article ajouté ! Nouveau iBasket: ${data.data[0].iBasket}`);
      }
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response from SNAL' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Add-Product-To-Wishlist Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'ajout au panier',
      message: error.message
    });
  }
});




// Middleware spécial pour /get-basket-list-article - récupérer les articles du panier
app.get('/api/get-basket-list-article', async (req, res) => {
  console.log(`📦 GET-BASKET-LIST-ARTICLE: Récupération des articles`);
  
  try {
    // ✅ PRIORITÉ AUX HEADERS pour éviter URL trop longue
    let iProfile = req.headers['x-iprofile'] || req.query.iProfile;
    let iBasket = req.headers['x-ibasket'] || req.query.iBasket;
    let sPaysFav = req.headers['x-spaysfav'] || req.query.sPaysFav;
    let { sAction } = req.query;
    
    console.log(`\n${'='.repeat(70)}`);
    console.log(`📦 GET-BASKET-LIST-ARTICLE - PARAMÈTRES REÇUS:`);
    console.log(`${'='.repeat(70)}`);
    console.log(`📥 Headers reçus:`, {
      'x-iprofile': req.headers['x-iprofile'],
      'x-ibasket': req.headers['x-ibasket'],
      'x-spaysfav': req.headers['x-spaysfav']
    });
    console.log(`📥 Query params:`, req.query);
    console.log(`📥 Valeurs finales:`, { iProfile, iBasket, sAction, sPaysFav });
    console.log(`${'='.repeat(70)}\n`);

    // 🔧 Essayer de récupérer GuestProfile depuis le cookie si les params sont manquants
    const cookies = req.headers.cookie || '';
    const guestProfileMatch = cookies.match(/GuestProfile=([^;]+)/);
    
    if (guestProfileMatch) {
      try {
        const existingProfile = JSON.parse(decodeURIComponent(guestProfileMatch[1]));
        console.log(`🍪 GuestProfile existant trouvé:`, existingProfile);
        
        // Utiliser les valeurs du cookie si les params sont manquants ou "test"
        if (!iProfile || iProfile === 'test') iProfile = existingProfile.iProfile;
        if (!iBasket || iBasket === 'test') iBasket = existingProfile.iBasket;
        if (!sPaysFav) sPaysFav = existingProfile.sPaysFav;
        
        console.log(`✅ Valeurs après récupération du cookie:`, { iProfile, iBasket, sPaysFav });
      } catch (e) {
        console.log(`⚠️ Erreur parsing GuestProfile cookie:`, e.message);
      }
    }

    // Créer le profil guest pour le cookie (OBLIGATOIRE pour SNAL)
    // Récupérer le GuestProfile depuis le header
    const guestProfileHeader = req.headers['x-guest-profile'];
    let profileFromHeader = { sPaysLangue: '' };
    if (guestProfileHeader) {
      try {
        profileFromHeader = JSON.parse(guestProfileHeader);
      } catch (e) {}
    }
    
    const guestProfile = {
      iProfile: iProfile || '',
      iBasket: iBasket || '',
      sPaysLangue: profileFromHeader.sPaysLangue || '',
      sPaysFav: sPaysFav || ''
    };
    
    console.log(`👤 GuestProfile final pour cookie:`, guestProfile);

    // Créer le cookie GuestProfile
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;

    // Envoyer iProfile, iBasket ET sAction dans l'URL
    const params = new URLSearchParams();
    if (iProfile) params.append('iProfile', iProfile);
    if (iBasket) params.append('iBasket', iBasket);
    if (sAction) params.append('sAction', sAction);

    console.log(`📱 Appel SNAL API: https://jirig.be/api/get-basket-list-article?${params}`);
    console.log(`🍪 Cookie (avec sPaysFav): ${cookieString.substring(0, 150)}...`);

    // Faire la requête GET vers l'API SNAL-Project avec le cookie
    const fetch = require('node-fetch');
    console.log(`🔄 Début de la requête vers SNAL...`);
    const response = await fetch(`https://jirig.be/api/get-basket-list-article?${params}`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });

    console.log(`📡 Response status: ${response.status}`);
    console.log(`📡 Response headers:`, Object.fromEntries(response.headers.entries()));
    
    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`📡 API Response parsed:`, data);
      
      // 🔍 DEBUG APPROFONDI: Afficher la structure exacte de la réponse
      if (!data.success && data.error === "Field 'Pivot' not found in the JSON response.") {
        console.log('🔍 === ANALYSE DÉTAILLÉE DU PROBLÈME PIVOT ===');
        console.log('❌ La procédure SQL Proc_PickingList_Actions ne retourne pas le champ Pivot');
        console.log('📝 Cela signifie que le JSON retourné par SQL ne contient pas ce champ');
        console.log('💡 Causes possibles:');
        console.log('   1. Le panier est vide selon la procédure SQL');
        console.log('   2. Le iBasket fourni n\'existe pas ou est invalide');
        console.log('   3. La procédure SQL a une condition non remplie');
        console.log('   4. Il manque un paramètre dans le XML (sPaysListe?)');
      }
      
      // ✅ Mettre à jour le cookie avec le bon iBasket retourné par SNAL
      if (data.success && data.data && data.data.meta && data.data.meta.iBasket) {
        const newIBasket = data.data.meta.iBasket;
        console.log(`🔄 Mise à jour de l'iBasket:`);
        console.log(`   Ancien: ${iBasket}`);
        console.log(`   Nouveau: ${newIBasket}`);
        
        if (newIBasket !== iBasket) {
          // Mettre à jour le GuestProfile avec le nouveau iBasket
          const updatedGuestProfile = {
            iProfile: guestProfile.iProfile,
            iBasket: newIBasket,
            sPaysLangue: guestProfile.sPaysLangue,
            sPaysFav: guestProfile.sPaysFav
          };
          
          const updatedCookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(updatedGuestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
          
          // Mettre à jour le cookie dans la réponse
          res.setHeader('Set-Cookie', updatedCookieString);
          console.log(`✅ Cookie mis à jour avec le nouveau iBasket: ${newIBasket}`);
        }
      }
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Get-Basket-List-Article Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des articles',
      message: error.message
    });
  }
});

// Endpoint pour récupérer tous les pays disponibles (get-infos-status)
app.get('/api/get-infos-status', async (req, res) => {
  console.log(`🌍 GET-INFOS-STATUS: Récupération de tous les pays disponibles`);
  
  try {
    // Récupérer iProfile depuis les headers ou query
    let iProfile = req.headers['x-iprofile'] || req.query.iProfile;
    
    console.log(`\n${'='.repeat(70)}`);
    console.log(`🌍 GET-INFOS-STATUS - PARAMÈTRES REÇUS:`);
    console.log(`${'='.repeat(70)}`);
    console.log(`📥 Headers reçus:`, {
      'x-iprofile': req.headers['x-iprofile']
    });
    console.log(`📥 Query params:`, req.query);
    console.log(`📥 iProfile final:`, iProfile);
    console.log(`${'='.repeat(70)}\n`);

    // Récupérer le GuestProfile depuis le header
    const profileFromHeader = getGuestProfileFromHeaders(req);
    
    // Créer le profil guest pour le cookie
    const guestProfile = {
      iProfile: iProfile || profileFromHeader.iProfile || '',
      iBasket: profileFromHeader.iBasket || '',
      sPaysLangue: profileFromHeader.sPaysLangue || '',
      sPaysFav: profileFromHeader.sPaysFav || ''
    };
    
    console.log(`👤 GuestProfile pour get-infos-status:`, guestProfile);

    // Créer le cookie GuestProfile
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;

    // Faire la requête GET vers l'API SNAL-Project
    const fetch = require('node-fetch');
    console.log(`🔄 Appel SNAL API: https://jirig.be/api/get-infos-status`);
    console.log(`🍪 Cookie: ${cookieString.substring(0, 100)}...`);

    const response = await fetch(`https://jirig.be/api/get-infos-status`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });

    console.log(`📡 Response status: ${response.status}`);
    console.log(`📡 Response headers:`, Object.fromEntries(response.headers.entries()));
    
    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`📡 API Response parsed:`, data);
      
      // Log des pays disponibles
      if (data.paysListe) {
        console.log(`🌍 Pays disponibles: ${data.paysListe.length} pays`);
        console.log(`📋 Détails: ${data.paysListe.map(p => p.sPays).join(', ')}`);
      }
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Get-Infos-Status Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des infos status',
      message: error.message
    });
  }
});

// Proxy pour les images IKEA (contourner le CORS)
app.get('/proxy-image', async (req, res) => {
  const imageUrl = req.query.url;
  
  if (!imageUrl) {
    return res.status(400).json({ error: 'URL manquante' });
  }

  console.log(`🖼️ Proxying image: ${imageUrl}`);

  try {
    const fetch = require('node-fetch');
    
    // Construire l'URL absolue si l'URL est relative
    let fullImageUrl = imageUrl;
    if (imageUrl.startsWith('/')) {
      fullImageUrl = `https://jirig.be${imageUrl}`;
    }
    
    console.log(`🖼️ Full URL: ${fullImageUrl}`);
    
    const response = await fetch(fullImageUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8'
      }
    });

    if (!response.ok) {
      return res.status(response.status).send('Image non trouvée');
    }

    // Copier les headers de l'image
    res.set('Content-Type', response.headers.get('content-type'));
    res.set('Cache-Control', 'public, max-age=86400'); // Cache 24h
    
    // Streamer l'image
    response.body.pipe(res);
  } catch (error) {
    console.error('❌ Erreur proxy image:', error.message);
    res.status(500).send('Erreur lors du chargement de l\'image');
  }
});

// Middleware spécial pour /delete-article-wishlistBasket - supprimer un article
app.post('/api/delete-article-wishlistBasket', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🗑️ DELETE-ARTICLE-WISHLIST: Suppression d'un article`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // Récupérer les paramètres depuis le body et les headers
    const { sCodeArticle } = req.body;
    const iProfile = req.headers['x-iprofile'];
    const iBasket = req.headers['x-ibasket'];
    
    console.log(`📦 Paramètres reçus:`, { sCodeArticle, iProfile, iBasket });
    
    if (!sCodeArticle) {
      return res.status(400).json({
        success: false,
        error: 'sCodeArticle est requis'
      });
    }
    
    if (!iProfile || !iBasket) {
      return res.status(400).json({
        success: false,
        error: 'iProfile et iBasket sont requis (headers X-IProfile et X-IBasket)'
      });
    }
    
    // Créer le GuestProfile cookie (SNAL construira le XML côté serveur)
    const guestProfile = {
      iProfile: iProfile,
      iBasket: iBasket,
      sPaysLangue: getGuestProfileFromHeaders(req).sPaysLangue || '',
      sPaysFav: ''
    };
    
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    // Faire la requête POST vers SNAL
    const fetch = require('node-fetch');
    console.log(`📱 Appel SNAL API: https://jirig.be/api/delete-article-wishlistBasket`);
    
    const response = await fetch(`https://jirig.be/api/delete-article-wishlistBasket`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString
      },
      body: JSON.stringify({
        sCodeArticle: sCodeArticle
      })
    });
    
    console.log(`📡 Response status: ${response.status}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL:`, errorText);
      return res.status(response.status).json({
        success: false,
        error: 'SNAL API Error',
        message: errorText
      });
    }
    
    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`✅ API Response parsed:`, data);
      console.log(`✅ Article supprimé avec succès !`);
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response from SNAL' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Delete-Article Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la suppression',
      message: error.message
    });
  }
});

// Middleware spécial pour /update-country-wishlistBasket - mettre à jour la liste des pays
app.post('/api/update-country-wishlistBasket', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🌍 UPDATE-COUNTRY-WISHLIST-BASKET: Mise à jour de la liste des pays`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // Récupérer les paramètres
    const { sPaysListe } = req.body;
    const iProfile = req.headers['x-iprofile'] || '';
    const iBasket = req.headers['x-ibasket'] || '';
    
    console.log(`📦 Paramètres reçus:`);
    console.log(`   - iProfile: ${iProfile}`);
    console.log(`   - iBasket: ${iBasket}`);
    console.log(`   - sPaysListe: ${sPaysListe}`);
    
    if (!iBasket || !sPaysListe) {
      return res.status(400).json({
        success: false,
        error: 'iBasket et sPaysListe sont requis'
      });
    }
    
    // Créer le GuestProfile cookie
    const guestProfile = {
      iProfile: iProfile,
      iBasket: iBasket,
      sPaysLangue: getGuestProfileFromHeaders(req).sPaysLangue || '',
      sPaysFav: sPaysListe
    };
    
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    console.log(`🍪 Cookie créé:`, cookieString);
    
    // Faire la requête POST vers SNAL
    const fetch = require('node-fetch');
    console.log(`📱 Appel SNAL API: https://jirig.be/api/update-country-wishlistBasket`);
    console.log(`📤 Body: { sPaysListe: "${sPaysListe}" }`);
    
    const response = await fetch(`https://jirig.be/api/update-country-wishlistBasket`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString
      },
      body: JSON.stringify({
        sPaysListe: sPaysListe
      })
    });
    
    console.log(`📡 Response status: ${response.status}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL:`, errorText);
      return res.status(response.status).json({
        success: false,
        error: 'SNAL API Error',
        message: errorText
      });
    }
    
    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`✅ API Response parsed:`, data);
      console.log(`✅ Liste des pays mise à jour avec succès !`);
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response from SNAL' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Update-Country-WishlistBasket Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour de la liste des pays',
      message: error.message
    });
  }
});

// Middleware spécial pour /update-quantity-articleBasket - mettre à jour la quantité
app.post('/api/update-quantity-articleBasket', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`📊 UPDATE-QUANTITY: Mise à jour de la quantité`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // Récupérer les paramètres
    const { sCodeArticle, iQte } = req.body;
    const iProfile = req.headers['x-iprofile'];
    const iBasket = req.headers['x-ibasket'];
    
    console.log(`📦 Paramètres reçus:`, { sCodeArticle, iQte, iProfile, iBasket });
    
    if (!sCodeArticle || !iQte) {
      return res.status(400).json({
        success: false,
        error: 'sCodeArticle et iQte sont requis'
      });
    }
    
    if (!iProfile || !iBasket) {
      return res.status(400).json({
        success: false,
        error: 'iProfile et iBasket sont requis (headers X-IProfile et X-IBasket)'
      });
    }
    
    // Créer le GuestProfile cookie (SNAL construira le XML côté serveur)
    const guestProfile = {
      iProfile: iProfile,
      iBasket: iBasket,
      sPaysLangue: getGuestProfileFromHeaders(req).sPaysLangue || '',
      sPaysFav: ''
    };
    
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    // Faire la requête POST vers SNAL
    const fetch = require('node-fetch');
    console.log(`📱 Appel SNAL API: https://jirig.be/api/update-quantity-articleBasket`);
    console.log(`📤 Body: { sCodeArticle: "${sCodeArticle}", iQte: ${iQte} }`);
    
    const response = await fetch(`https://jirig.be/api/update-quantity-articleBasket`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString
      },
      body: JSON.stringify({
        sCodeArticle: sCodeArticle,
        iQte: iQte
      })
    });
    
    console.log(`📡 Response status: ${response.status}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL:`, errorText);
      return res.status(response.status).json({
        success: false,
        error: 'SNAL API Error',
        message: errorText
      });
    }
    
    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`✅ API Response parsed:`, data);
      console.log(`✅ Quantité mise à jour avec succès !`);
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response from SNAL' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Update-Quantity Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour de la quantité',
      message: error.message
    });
  }
});

// ℹ️ OAUTH GOOGLE & FACEBOOK
// Ces endpoints ne sont PAS définis ici car Flutter redirige DIRECTEMENT vers SNAL
// Flutter utilise: https://jirig.be/api/auth/google-mobile (pas via proxy)
// Après OAuth, SNAL redirige vers https://jirig.be/ et HomeScreen détecte la connexion

// Middleware spécial pour /auth/init - initialisation du profil utilisateur
app.post('/api/auth/init', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/INIT: Initialisation du profil utilisateur`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    const { sPaysLangue, sPaysFav, bGeneralConditionAgree, iUserIp, iBrowser, iDevice, iPlatform, iUserAgent } = req.body;
    
    console.log(`🔐 Paramètres reçus depuis Flutter:`, { sPaysLangue, sPaysFav, bGeneralConditionAgree });

    // Créer le body pour SNAL
    const snalBody = {
      sPaysLangue: sPaysLangue || '',
      sPaysFav: sPaysFav || '',
      bGeneralConditionAgree: bGeneralConditionAgree || false,
      iUserIp: iUserIp || '',
      iBrowser: iBrowser || '',
      iDevice: iDevice || '',
      iPlatform: iPlatform || '',
      iUserAgent: iUserAgent || ''
    };

    console.log(`📱 Appel SNAL API: https://jirig.be/api/auth/init`);
    console.log(`📤 Body envoyé:`, snalBody);

    // Faire la requête POST vers l'API SNAL-Project
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/auth/init`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(snalBody)
    });

    console.log(`🔐 Response status: ${response.status}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`🔐 Error response body:`, errorText);
      
      return res.status(response.status).json({
        success: false,
        error: 'API SNAL Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText
      });
    }

    const data = await response.json();
    console.log(`🔐 API Response:`, data);

    // Extraire les cookies de la réponse SNAL
    const setCookieHeaders = response.headers.raw()['set-cookie'];
    if (setCookieHeaders) {
      console.log(`🍪 Cookies reçus de SNAL:`, setCookieHeaders);
      
      // 🔍 EXTRAIRE ET CORRIGER le cookie GuestProfile
      const guestProfileCookieIndex = setCookieHeaders.findIndex(cookie => cookie.startsWith('GuestProfile='));
      if (guestProfileCookieIndex !== -1) {
        try {
          const guestProfileCookie = setCookieHeaders[guestProfileCookieIndex];
          const cookieValue = guestProfileCookie.split(';')[0].split('=')[1];
          const decodedValue = decodeURIComponent(cookieValue);
          const guestProfile = JSON.parse(decodedValue);
          
          console.log(`\n${'='.repeat(60)}`);
          console.log(`🎯 INFORMATIONS DE PROFIL REÇUES DE SNAL (AVANT CORRECTION):`);
          console.log(`${'='.repeat(60)}`);
          console.log(`👤 iProfile: ${guestProfile.iProfile || 'N/A'}`);
          console.log(`🛒 iBasket: ${guestProfile.iBasket || 'N/A'}`);
          console.log(`🌍 sPaysLangue: ${guestProfile.sPaysLangue || 'N/A'}`);
          console.log(`🏳️  sPaysFav: ${guestProfile.sPaysFav || 'N/A'}`);
          console.log(`${'='.repeat(60)}\n`);
          
          // ✅ CORRECTION: Remplacer sPaysLangue et sPaysFav par les valeurs envoyées initialement
          guestProfile.sPaysLangue = sPaysLangue || guestProfile.sPaysLangue;
          guestProfile.sPaysFav = Array.isArray(sPaysFav) ? sPaysFav.join(',') : (sPaysFav || guestProfile.sPaysFav);
          
          console.log(`🔧 CORRECTION: Remplacement des valeurs par celles envoyées initialement`);
          console.log(`   sPaysLangue: ${sPaysLangue} → ${guestProfile.sPaysLangue}`);
          console.log(`   sPaysFav: ${sPaysFav} → ${guestProfile.sPaysFav}`);
          
          // Reconstruire le cookie avec les bonnes valeurs
          const correctedCookie = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
          setCookieHeaders[guestProfileCookieIndex] = correctedCookie;
          
          console.log(`\n${'='.repeat(60)}`);
          console.log(`✅ INFORMATIONS DE PROFIL CORRIGÉES:`);
          console.log(`${'='.repeat(60)}`);
          console.log(`👤 iProfile: ${guestProfile.iProfile || 'N/A'}`);
          console.log(`🛒 iBasket: ${guestProfile.iBasket || 'N/A'}`);
          console.log(`🌍 sPaysLangue: ${guestProfile.sPaysLangue || 'N/A'}`);
          console.log(`🏳️  sPaysFav: ${guestProfile.sPaysFav || 'N/A'}`);
          console.log(`${'='.repeat(60)}\n`);
        } catch (e) {
          console.log(`⚠️ Erreur lors du parsing/correction du cookie GuestProfile:`, e.message);
        }
      }
      
      // Transférer les cookies au client Flutter
      setCookieHeaders.forEach(cookie => {
        res.append('Set-Cookie', cookie);
      });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Auth/Init Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de l\'initialisation',
      message: error.message
    });
  }
});


// Endpoint spécifique pour /projet-download - téléchargement PDF (AVANT le proxy général)
// Endpoint spécifique pour /projet-download - téléchargement PDF (AVANT le proxy général)
app.get('/api/projet-download', async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`📄 PROJET-DOWNLOAD: Téléchargement du PDF du projet`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // LOG DÉTAILLÉ: Tous les headers reçus
    console.log(`📥 Headers reçus:`, {
      'x-ibasket': req.headers['x-ibasket'],
      'x-iprofile': req.headers['x-iprofile'],
      'X-IProfile': req.headers['X-IProfile'],
      'accept': req.headers['accept'],
      'cookie': req.headers.cookie ? req.headers.cookie.substring(0, 100) + '...' : '(aucun)'
    });
    console.log(`📥 Query params:`, req.query);
    
    // ✅ Lire d'abord depuis les HEADERS (envoyés par Flutter)
    let iProfile = req.headers['x-iprofile'] || req.headers['X-IProfile'] || '';
    let iBasket = req.headers['x-ibasket'] || req.headers['X-IBasket'] || '';
    let sPaysLangue = '';
    let sPaysFav = '';
    
    // ✅ Récupérer le GuestProfile complet depuis le header X-Guest-Profile (Flutter)
    const guestProfileHeader = req.headers['x-guest-profile'];
    if (guestProfileHeader) {
      try {
        const headerProfile = JSON.parse(guestProfileHeader);
        console.log(`📤 X-Guest-Profile header reçu:`, headerProfile);
        
        // Utiliser les valeurs du header si disponibles
        if (!iProfile) iProfile = headerProfile.iProfile || '';
        if (!iBasket) iBasket = headerProfile.iBasket || '';
        sPaysLangue = headerProfile.sPaysLangue || '';
        sPaysFav = headerProfile.sPaysFav || '';
        
        console.log(`✅ Valeurs récupérées depuis X-Guest-Profile: sPaysLangue=${sPaysLangue}`);
      } catch (e) {
        console.log(`⚠️ Erreur parsing X-Guest-Profile header:`, e.message);
      }
    }
    
    // ✅ Fallback: lire depuis les cookies (pour le Web)
    const cookies = req.headers.cookie || '';
    const guestProfileMatch = cookies.match(/GuestProfile=([^;]+)/);
    
    let guestProfile = { iProfile: '', iBasket: '', sPaysLangue: '', sPaysFav: '' };
    
    if (guestProfileMatch) {
      try {
        const cookieProfile = JSON.parse(decodeURIComponent(guestProfileMatch[1]));
        console.log(`🍪 GuestProfile depuis cookie → iProfile=${cookieProfile.iProfile || '(vide)'} iBasket=${cookieProfile.iBasket || '(vide)'} sPaysLangue=${cookieProfile.sPaysLangue || '(vide)'}`);
        
        // Utiliser les valeurs du cookie seulement si non déjà définies
        if (!iProfile) iProfile = cookieProfile.iProfile || '';
        if (!iBasket) iBasket = cookieProfile.iBasket || '';
        if (!sPaysLangue) sPaysLangue = cookieProfile.sPaysLangue || '';
        if (!sPaysFav) sPaysFav = cookieProfile.sPaysFav || '';
      } catch (e) {
        console.log(`⚠️ Erreur parsing GuestProfile cookie:`, e.message);
      }
    }
    
    // Construire le GuestProfile final avec les valeurs trouvées
    guestProfile = {
      iProfile: iProfile,
      iBasket: iBasket,
      sPaysLangue: sPaysLangue,
      sPaysFav: sPaysFav
    };
    
    console.log(`📦 GuestProfile final construit:`, {
      iProfile: iProfile || '(vide)',
      iBasket: iBasket || '(vide)',
      sPaysLangue: sPaysLangue || '(vide)',
      sPaysFav: sPaysFav || '(vide)',
      source: iProfile ? (req.headers['x-iprofile'] ? 'headers' : 'cookie') : 'aucune'
    });
    
    // ✅ Vérification : s'assurer que iProfile et iBasket sont présents
    if (!iProfile || !iBasket) {
      console.log(`❌ ERREUR: iProfile ou iBasket manquant !`);
      console.log(`   iProfile: "${iProfile}"`);
      console.log(`   iBasket: "${iBasket}"`);
      return res.status(400).json({
        success: false,
        error: 'Données manquantes',
        message: 'iProfile ou iBasket manquant pour générer le PDF'
      });
    }
    
    // ✅ CORRECTION CRITIQUE: Créer le cookie GuestProfile (SNAL lit iBasket et iProfile depuis le cookie, PAS depuis query params)
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    // ✅ CORRECTION: NE PAS passer iBasket en query parameter - SNAL le lit depuis le cookie
    const snalUrl = `https://jirig.be/api/projet-download`;
    
    console.log(`\n${'='.repeat(70)}`);
    console.log(`📄 APPEL SNAL PROJET-DOWNLOAD`);
    console.log(`${'='.repeat(70)}`);
    console.log(`📱 URL: ${snalUrl} (PAS de query params)`);
    console.log(`📦 iBasket sera lu depuis le cookie GuestProfile`);
    console.log(`👤 iProfile sera lu depuis le cookie GuestProfile`);
    console.log(`🍪 GuestProfile JSON:`, JSON.stringify(guestProfile, null, 2));
    console.log(`🍪 Cookie encodé: ${cookieString.substring(0, 200)}...`);
    console.log(`${'='.repeat(70)}\n`);
    
    // Faire la requête GET vers SNAL
    const fetch = require('node-fetch');
    const response = await fetch(snalUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/pdf',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });
    
    console.log(`📡 Response status: ${response.status}`);
    console.log(`📡 Response headers:`, Object.fromEntries(response.headers.entries()));
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL (status ${response.status}):`, errorText);
      
      // Parser l'erreur pour obtenir plus de détails
      let errorDetails = errorText;
      try {
        const errorJson = JSON.parse(errorText);
        console.log(`📋 Erreur parsée:`, errorJson);
        errorDetails = errorJson;
      } catch (e) {
        console.log(`⚠️ Erreur non-JSON:`, errorText);
      }
      
      return res.status(response.status).json({
        success: false,
        error: 'SNAL API Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorDetails,
        debug: {
          iProfile: iProfile,
          iBasket: iBasket,
          sPaysLangue: sPaysLangue,
          sPaysFav: sPaysFav
        }
      });
    }
    
    // Vérifier le Content-Type
    const contentType = response.headers.get('content-type');
    console.log(`📄 Content-Type reçu: ${contentType}`);
    
    if (contentType && contentType.includes('application/pdf')) {
      // C'est un PDF, le streamer directement
      console.log(`✅ PDF détecté, streaming vers le client...`);
      
      // Copier les headers importants
      res.set('Content-Type', 'application/pdf');
      res.set('Content-Disposition', response.headers.get('content-disposition') || `attachment; filename="projet_${iBasket}.pdf"`);
      res.set('Cache-Control', 'no-cache');
      
      // Streamer le PDF
      response.body.pipe(res);
    } else {
      // Ce n'est pas un PDF, probablement du JSON
      const responseText = await response.text();
      console.log(`⚠️ Réponse non-PDF reçue:`, responseText);
      
      // Si c'est un tableau vide [], c'est normal (panier vide)
      if (responseText.trim() === '[]') {
        return res.status(404).json({
          success: false,
          error: 'Panier vide',
          message: 'Aucun article dans le panier pour générer le PDF'
        });
      }
      
      // Autre réponse JSON
      let data;
      try {
        data = JSON.parse(responseText);
        console.log('📄 Réponse JSON de SNAL:', data);
        return res.status(400).json({
          success: false,
          error: 'SNAL API Error',
          message: 'Le serveur SNAL a retourné une erreur',
          details: data,
          snalStatus: response.status,
          snalMessage: data.message || data.statusMessage || 'Erreur inconnue'
        });
      } catch (e) {
        console.log('📄 Réponse non-JSON de SNAL:', responseText);
        return res.status(500).json({
          success: false,
          error: 'Réponse invalide',
          message: 'Le serveur a retourné une réponse non-PDF et non-JSON',
          details: responseText
        });
      }
    }
  } catch (error) {
    console.error('❌ Projet-Download Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors du téléchargement du PDF',
      message: error.message
    });
  }
});

// Endpoint spécifique pour update-country-selected (AVANT le proxy général)
app.post('/api/update-country-selected', express.json(), async (req, res) => {
  try {
    console.log('🌍 === UPDATE COUNTRY SELECTED ===');
    console.log('📤 Request body:', req.body);
    
    const { iBasket, sCodeArticle, sNewPaysSelected } = req.body;
    
    if (!iBasket || !sCodeArticle || !sNewPaysSelected) {
      return res.status(400).json({
        success: false,
        error: 'Paramètres manquants',
        message: 'iBasket, sCodeArticle et sNewPaysSelected sont requis'
      });
    }
    
    // Construire le cookie GuestProfile
    const iProfile = req.headers['x-iprofile'] || '';
    const guestProfile = {
      iProfile: iProfile,
      iBasket: iBasket,
      sPaysLangue: getGuestProfileFromHeaders(req).sPaysLangue || '',
      sPaysFav: req.headers['x-pays-fav'] || ''
    };
    
    const guestProfileCookie = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly; SameSite=None; Secure`;
    
    console.log('🍪 GuestProfile cookie:', guestProfileCookie);
    
    // Envoyer les paramètres en JSON - SNAL génère le XML côté serveur
    const snalBody = {
      iProfile: iProfile,
      iBasket: iBasket,
      sCodeArticle: sCodeArticle,
      sNewPaysSelected: sNewPaysSelected,
      sAction: 'CHANGEPAYS'
    };
    
    console.log('📤 SNAL JSON Body:', snalBody);
    
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/update-country-selected`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': guestProfileCookie
      },
      body: JSON.stringify(snalBody)
    });
    
    console.log(`🌍 Response status: ${response.status}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`🌍 Error response body:`, errorText);
      
      return res.status(response.status).json({
        success: false,
        error: 'API SNAL Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText
      });
    }
    
    const data = await response.json();
    console.log(`🌍 API Response:`, data);
    
    // Extraire les cookies de la réponse SNAL
    const setCookieHeaders = response.headers.raw()['set-cookie'];
    if (setCookieHeaders) {
      console.log(`🍪 Cookies reçus de SNAL:`, setCookieHeaders);
      
      // Transférer les cookies au client Flutter
      setCookieHeaders.forEach(cookie => {
        res.append('Set-Cookie', cookie);
      });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Update Country Selected Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour du pays',
      message: error.message
    });
  }
});

// **********************************************************************
// 🚩 FLAGS: Récupération des drapeaux des pays
// **********************************************************************
app.get('/api/flags', async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🚩 FLAGS: Récupération des drapeaux des pays`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/flags`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });
    
    console.log(`🚩 Response status: ${response.status}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`🚩 Error response body:`, errorText);
      
      return res.status(response.status).json({
        success: false,
        error: 'API SNAL Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText
      });
    }
    
    const data = await response.json();
    console.log(`🚩 API Response:`, data);
    console.log(`✅ ${data.length} drapeaux récupérés`);
    
    res.json(data);
  } catch (error) {
    console.error('❌ Flags Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération des drapeaux',
      message: error.message
    });
  }
});

// **********************************************************************
// 👤 PROFILE/UPDATE: Mise à jour du profil utilisateur
// **********************************************************************
app.post('/api/profile/update', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`👤 PROFILE/UPDATE: Mise à jour du profil`);
  console.log(`${'*'.repeat(70)}`);

  try {
    // Récupérer l'iProfile depuis les cookies/headers
    const guestProfile = getGuestProfileFromHeaders(req);
    const iProfile = guestProfile?.iProfile;
    
    if (!iProfile) {
      console.log('❌ Aucun iProfile trouvé dans les cookies');
      return res.status(400).json({
        success: false,
        error: 'iProfile manquant',
        message: 'Impossible de récupérer l\'identifiant du profil'
      });
    }

    console.log(`👤 iProfile: ${iProfile}`);

    const fetch = require('node-fetch');
    const profileData = req.body;

    console.log(`📤 Données du profil reçues:`, {
      Prenom: profileData.Prenom,
      Nom: profileData.Nom,
      email: profileData.email,
      tel: profileData.tel,
      rue: profileData.rue,
      zip: profileData.zip,
      city: profileData.city,
      token: profileData.token ? '***' : '(vide)'
    });

    // Mapper les champs Flutter vers le format SNAL
    const snalProfileData = {
      sNom: profileData.Nom || '',
      sPrenom: profileData.Prenom || '',
      sPhoto: '', // Pas de photo pour l'instant
      sRue: profileData.rue || '',
      sZip: profileData.zip || '',
      sCity: profileData.city || '',
      iPays: -1, // Valeur par défaut
      sTel: profileData.tel || '',
      sPaysFav: guestProfile.sPaysFav || '',
      sPaysLangue: guestProfile.sPaysLangue || '',
      sEmail: profileData.email || '',
      sTypeAccount: 'EMAIL', // Type de compte par défaut
      sLangue: guestProfile.sPaysLangue ? guestProfile.sPaysLangue.split('/')[1] : 'FR'
    };

    console.log(`📤 Données mappées pour SNAL:`, {
      sNom: snalProfileData.sNom,
      sPrenom: snalProfileData.sPrenom,
      sEmail: snalProfileData.sEmail,
      sTel: snalProfileData.sTel,
      sRue: snalProfileData.sRue,
      sZip: snalProfileData.sZip,
      sCity: snalProfileData.sCity,
      sPaysFav: snalProfileData.sPaysFav,
      sPaysLangue: snalProfileData.sPaysLangue,
      sLangue: snalProfileData.sLangue
    });

    // Construire le cookie GuestProfile pour SNAL
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    console.log(`🍪 Cookie envoyé à SNAL:`, cookieString.substring(0, 100) + '...');

    // Utiliser le bon endpoint SNAL avec l'iProfile
    console.log(`➡️ [Proxy][UPDATE-PROFILE] URL ciblée: https://jirig.be/api/update-info-profil/${iProfile}`);

    console.log('➡️ [Proxy][UPDATE-PROFILE] Headers envoyés vers SNAL:', {
      ...req.headers,
      host: undefined,
      connection: undefined,
      'content-length': undefined,
    });

    console.log('➡️ [Proxy][UPDATE-PROFILE] Données envoyées vers SNAL:', snalProfileData);

    const responsePayload = {
      ...snalProfileData,
      iProfile,
    };

    console.log('🟦 [Proxy][UPDATE-PROFILE] Payload JSON envoyé vers SNAL:', JSON.stringify(responsePayload, null, 2));

    const response = await fetch(`https://jirig.be/api/update-info-profil/${iProfile}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      },
      body: JSON.stringify(responsePayload)
    });

    console.log(`📥 Response status: ${response.status}`);
    const responseHeaders = Object.fromEntries(response.headers.entries());
    console.log('📥 [Proxy][UPDATE-PROFILE] Headers de réponse SNAL:', responseHeaders);

    const responseText = await response.text();
    console.log('📥 [Proxy][UPDATE-PROFILE] Corps de réponse SNAL:', responseText);

    console.log('🟦 [Proxy][UPDATE-PROFILE] JSON envoyé (replay):', responseText ? responseText : '(vide)');

    try {
      const xmlMatch = responseText.match(/<root>[\s\S]*<\/root>/);
      if (xmlMatch) {
        console.log('📄 [Proxy][UPDATE-PROFILE] XML renvoyé par SNAL:', xmlMatch[0]);
      }
    } catch (xmlParseError) {
      console.log('⚠️ [Proxy][UPDATE-PROFILE] Analyse XML échouée:', xmlParseError);
    }

    if (!response.ok) {
      console.log(`❌ [Proxy][UPDATE-PROFILE] Réponse d'erreur SNAL (status ${response.status}):`, responseText);

      return res.status(response.status).json({
        success: false,
        error: 'Erreur lors de la mise à jour du profil',
        message: responseText
      });
    }

    let data;
    try {
      data = responseText ? JSON.parse(responseText) : {};
    } catch (parseError) {
      console.log('⚠️ [Proxy][UPDATE-PROFILE] Impossible de parser la réponse JSON:', parseError);
      return res.status(502).json({
        success: false,
        error: 'Réponse SNAL invalide (JSON mal formé)',
        rawResponse: responseText
      });
    }

    if (!data.success) {
      console.log('⚠️ [Proxy][UPDATE-PROFILE] SNAL a répondu success=false:', data);
    } else {
      console.log(`✅ Profil mis à jour avec succès`);
    }
    console.log(`📥 Réponse JSON SNAL:`, data);

    res.json(data);
  } catch (error) {
    console.error('❌ Update Profile Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la mise à jour du profil',
      message: error.message
    });
  }
});

// **********************************************************************
// 🔐 AUTH/LOGIN-WITH-CODE: Connexion avec code (basé sur SNAL login-with-code.ts)
// **********************************************************************
app.post('/api/auth/login-with-code', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/LOGIN-WITH-CODE: Connexion avec code`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    const { email, sLangue, password } = req.body;
    
    // ✅ Déterminer si c'est une validation de code ou une demande de code
    const isCodeValidation = password && password.trim() !== '';
    
    console.log(`🔐 Paramètres reçus:`, { 
      email: email || '(vide)', 
      sLangue: sLangue || '(vide)',
      password: password ? '***' : '(vide)',
      isCodeValidation: isCodeValidation
    });

    // ✅ MÊME LOGIQUE QUE SNAL : Utiliser des identifiants par défaut pour la connexion
    // SNAL créera de nouveaux identifiants lors de la connexion
    let iProfile = '0'; // Utiliser '0' au lieu de '' pour éviter l'erreur de conversion
    let iBasket = '0';  // Utiliser '0' au lieu de '' pour éviter l'erreur de conversion
    let sPaysLangue = '';
    let sPaysFav = '';
    
    // ✅ Récupérer le GuestProfile depuis le header X-Guest-Profile (Flutter localStorage)
    const guestProfileHeader = req.headers['x-guest-profile'];
    if (guestProfileHeader) {
      try {
        const headerProfile = JSON.parse(guestProfileHeader);
        console.log(`📤 X-Guest-Profile header reçu:`, headerProfile);
        
        // ✅ UTILISER LES VRAIES VALEURS depuis le header X-Guest-Profile
        if (headerProfile.iProfile && headerProfile.iProfile !== '0' && !headerProfile.iProfile.startsWith('guest_')) {
          iProfile = headerProfile.iProfile;
          console.log(`✅ iProfile récupéré depuis X-Guest-Profile: ${iProfile}`);
        }
        if (headerProfile.iBasket && headerProfile.iBasket !== '0' && !headerProfile.iBasket.startsWith('basket_')) {
          iBasket = headerProfile.iBasket;
          console.log(`✅ iBasket récupéré depuis X-Guest-Profile: ${iBasket}`);
        }
        
        // Utiliser sPaysLangue et sPaysFav pour la connexion
        sPaysLangue = headerProfile.sPaysLangue || '';
        sPaysFav = headerProfile.sPaysFav || '';
        
        console.log(`✅ Valeurs récupérées depuis X-Guest-Profile: iProfile=${iProfile}, iBasket=${iBasket}, sPaysLangue=${sPaysLangue}`);
      } catch (e) {
        console.log(`⚠️ Erreur parsing X-Guest-Profile header:`, e.message);
      }
    }
    
    // ✅ Récupérer le GuestProfile depuis les cookies (comme SNAL)
    const guestProfileCookie = req.headers['cookie'];
    if (guestProfileCookie) {
      console.log(`🍪 Cookie reçu:`, guestProfileCookie);
      
      // Extraire le GuestProfile du cookie
      const guestProfileMatch = guestProfileCookie.match(/GuestProfile=([^;]+)/);
      if (guestProfileMatch) {
        try {
          const guestProfileDecoded = decodeURIComponent(guestProfileMatch[1]);
          const cookieProfile = JSON.parse(guestProfileDecoded);
          console.log(`🍪 GuestProfile depuis cookie:`, cookieProfile);
          
          // ✅ Utiliser les VRAIES valeurs du cookie pour iProfile et iBasket
          // Remplacer les identifiants par défaut par les vrais identifiants des cookies
          if (cookieProfile.iProfile && 
              cookieProfile.iProfile !== '0' && 
              !cookieProfile.iProfile.startsWith('guest_')) {
            iProfile = cookieProfile.iProfile;
            console.log(`✅ iProfile récupéré depuis cookie: ${iProfile}`);
          }
          if (cookieProfile.iBasket && 
              cookieProfile.iBasket !== '0' && 
              !cookieProfile.iBasket.startsWith('basket_')) {
            iBasket = cookieProfile.iBasket;
            console.log(`✅ iBasket récupéré depuis cookie: ${iBasket}`);
          }
          
          // Utiliser les valeurs du cookie si disponibles
          if (cookieProfile.sPaysLangue) sPaysLangue = cookieProfile.sPaysLangue;
          if (cookieProfile.sPaysFav) sPaysFav = cookieProfile.sPaysFav;
          
          console.log(`✅ Valeurs finales: iProfile=${iProfile}, iBasket=${iBasket}, sPaysLangue=${sPaysLangue}, sPaysFav=${sPaysFav}`);
        } catch (e) {
          console.log(`⚠️ Erreur parsing GuestProfile cookie:`, e.message);
        }
      }
    }
    
    // ✅ Créer le cookie GuestProfile pour SNAL avec des identifiants vides (comme SNAL)
    const guestProfile = {
      iProfile: iProfile,
      iBasket: iBasket,
      sPaysLangue: sPaysLangue,
      sPaysFav: sPaysFav
    };
    
    console.log(`\n${'='.repeat(60)}`);
    console.log(`🍪 GUESTPROFILE DÉTAILLÉ POUR SNAL:`);
    console.log(`${'='.repeat(60)}`);
    console.log(`iProfile: "${guestProfile.iProfile}" (${guestProfile.iProfile.length} chars)`);
    console.log(`iBasket: "${guestProfile.iBasket}" (${guestProfile.iBasket.length} chars)`);
    console.log(`sPaysLangue: "${guestProfile.sPaysLangue}"`);
    console.log(`sPaysFav: "${guestProfile.sPaysFav}" (${guestProfile.sPaysFav.length} chars)`);
    console.log(`${'='.repeat(60)}\n`);
    
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    console.log(`👤 GuestProfile pour cookie:`, guestProfile);
    console.log(`📱 Appel SNAL API LOCAL: https://jirig.be/api/auth/login-with-code`);
    
    // ✅ Créer la structure XML comme dans SNAL login-with-code.ts
    const passwordCleaned = password || "";
    const sLang = sLangue || "fr";
    const sPaysListe = guestProfile.sPaysFav || "";
    const sTypeAccount = "EMAIL";
    // Utiliser les variables déjà déclarées
    const xmlIProfile = guestProfile.iProfile || "";
    const xmlSPaysLangue = guestProfile.sPaysLangue || "";
    
    const xXml = `
      <root>
        <iProfile>${xmlIProfile}</iProfile>
        <sProvider>magic-link</sProvider>
        <email>${email}</email>
        <code>${passwordCleaned}</code>
        <sTypeAccount>${sTypeAccount}</sTypeAccount>
        <iPaysOrigine>${xmlSPaysLangue}</iPaysOrigine>
        <sLangue>${xmlSPaysLangue}</sLangue>
        <sPaysListe>${sPaysListe}</sPaysListe>
        <sPaysLangue>${xmlSPaysLangue}</sPaysLangue>
        <sCurrentLangue>${sLang}</sCurrentLangue>
      </root>
    `.trim();
    
    console.log(`📤 XML envoyé à SNAL:`, xXml);
    console.log(`📤 Paramètres:`, { 
      email, 
      sLangue,
      password: password ? `*** (${password.length} chars)` : '(vide)',
      iProfile: xmlIProfile || '(vide)',
      sPaysLangue: xmlSPaysLangue || '(vide)'
    });

    // Faire la requête POST vers l'API SNAL-Project LOCAL avec XML
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/auth/login-with-code`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      },
      body: JSON.stringify({
        email: email,
        sLangue: sLangue || 'fr',
        password: password || '',
        xXml: xXml  // ✅ Envoyer le XML comme dans SNAL
      })
    });

    console.log(`📡 Response status: ${response.status}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL:`, errorText);
      
      return res.status(response.status).json({
        success: false,
        error: 'API SNAL Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText
      });
    }

    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    console.log(`📡 Response headers:`, Object.fromEntries(response.headers.entries()));
    
    let data;
    let enrichedData;
    try {
      data = JSON.parse(responseText);
      console.log(`📡 API Response parsed:`, data);
      
      // ✅ CRITIQUE: Créer une copie de la réponse pour éviter les problèmes de référence
      enrichedData = { ...data };
      
      // ✅ Afficher le code envoyé si présent dans la réponse
      if (data && data.code) {
        console.log(`\n${'🔑'.repeat(30)}`);
        console.log(`✉️  CODE ENVOYÉ PAR EMAIL:`);
        console.log(`${'🔑'.repeat(30)}`);
        console.log(`🔑 Code: ${data.code}`);
        console.log(`📧 Envoyé à: ${email}`);
        console.log(`${'🔑'.repeat(30)}\n`);
      }
      
      // Extraire les cookies de la réponse SNAL (contient le profil mis à jour)
      const setCookieHeaders = response.headers.raw()['set-cookie'];
      if (setCookieHeaders) {
        console.log(`🍪 Cookies reçus de SNAL:`, setCookieHeaders);
        
        // Extraire iProfile et iBasket du cookie GuestProfile
        const guestProfileCookie = setCookieHeaders.find(cookie => cookie.startsWith('GuestProfile='));
        let updatedProfile = null;
        
        if (guestProfileCookie) {
          try {
            const cookieValue = guestProfileCookie.split(';')[0].split('=')[1];
            const decodedValue = decodeURIComponent(cookieValue);
            updatedProfile = JSON.parse(decodedValue);
            
            console.log(`\n${'='.repeat(60)}`);
            console.log(`🎯 PROFIL UTILISATEUR CONNECTÉ (AVANT CORRECTION):`);
            console.log(`${'='.repeat(60)}`);
            console.log(`👤 iProfile: ${updatedProfile.iProfile || 'N/A'}`);
            console.log(`🛒 iBasket: ${updatedProfile.iBasket || 'N/A'}`);
            console.log(`🌍 sPaysLangue: ${updatedProfile.sPaysLangue || 'N/A'}`);
            console.log(`🏳️  sPaysFav: ${updatedProfile.sPaysFav || 'N/A'}`);
            console.log(`${'='.repeat(60)}\n`);
            
            // ✅ CORRECTION: Remplacer sPaysLangue et sPaysFav par les valeurs du GuestProfile envoyé
            if (guestProfile.sPaysLangue) {
              updatedProfile.sPaysLangue = guestProfile.sPaysLangue;
            }
            if (guestProfile.sPaysFav) {
              updatedProfile.sPaysFav = guestProfile.sPaysFav;
            }
            
            console.log(`🔧 CORRECTION: Restauration des valeurs du GuestProfile envoyé`);
            console.log(`   sPaysLangue: ${guestProfile.sPaysLangue} → ${updatedProfile.sPaysLangue}`);
            console.log(`   sPaysFav: ${guestProfile.sPaysFav} → ${updatedProfile.sPaysFav}`);
            
            console.log(`\n${'='.repeat(60)}`);
            console.log(`✅ PROFIL UTILISATEUR CONNECTÉ (CORRIGÉ):`);
            console.log(`${'='.repeat(60)}`);
            console.log(`👤 iProfile: ${updatedProfile.iProfile || 'N/A'}`);
            console.log(`🛒 iBasket: ${updatedProfile.iBasket || 'N/A'}`);
            console.log(`🌍 sPaysLangue: ${updatedProfile.sPaysLangue || 'N/A'}`);
            console.log(`🏳️  sPaysFav: ${updatedProfile.sPaysFav || 'N/A'}`);
            console.log(`${'='.repeat(60)}\n`);
            
            // Remplacer le cookie dans le tableau
            const guestProfileCookieIndex = setCookieHeaders.findIndex(cookie => cookie.startsWith('GuestProfile='));
            if (guestProfileCookieIndex !== -1) {
              const correctedCookie = `GuestProfile=${encodeURIComponent(JSON.stringify(updatedProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
              setCookieHeaders[guestProfileCookieIndex] = correctedCookie;
              console.log(`✅ Cookie GuestProfile corrigé et remplacé dans les headers`);
            }
          } catch (e) {
            console.log(`⚠️ Erreur lors du parsing du cookie GuestProfile:`, e.message);
          }
        }
        
        // ✅ Si c'est une validation de code réussie, enrichir la réponse avec les nouveaux identifiants
        if (isCodeValidation && data.status === 'OK') {
          console.log('🔄 Enrichissement de la réponse avec les nouveaux identifiants...');
          
          // ✅ CRITIQUE: Ajouter les nouveaux identifiants dans la réponse pour que Flutter les utilise
          if (updatedProfile) {
            console.log('🔑 NOUVEAUX IDENTIFIANTS POUR FLUTTER:');
            console.log(`   Nouveau iProfile: ${updatedProfile.iProfile}`);
            console.log(`   Nouveau iBasket: ${updatedProfile.iBasket}`);
            
            // Ajouter les nouveaux identifiants dans la réponse JSON
            enrichedData.newIProfile = updatedProfile.iProfile;
            enrichedData.newIBasket = updatedProfile.iBasket;
            enrichedData.iProfile = updatedProfile.iProfile;
            enrichedData.iBasket = updatedProfile.iBasket;
            enrichedData.sPaysLangue = updatedProfile.sPaysLangue;
            enrichedData.sPaysFav = updatedProfile.sPaysFav;
          } else {
            console.log('⚠️ updatedProfile non défini, utilisation des identifiants par défaut');
          }
          
          // ✅ Appeler get-info-profil pour récupérer les infos complètes (sNom, sPrenom, sEmail, sPhoto)
          try {
            console.log('📞 Appel de get-info-profil pour récupérer les infos utilisateur complètes...');
            
            const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(updatedProfile))}`;
            const authSessionCookie = setCookieHeaders.find(cookie => cookie.startsWith('auth.session-token='));
            const sessionCookie = authSessionCookie ? authSessionCookie.split(';')[0] : '';
            
            const profileResponse = await fetch(`https://jirig.be/api/get-info-profil`, {
              method: 'GET',
              headers: {
                'Accept': 'application/json',
                'Cookie': `${cookieString}; ${sessionCookie}`,
                'User-Agent': 'Mobile-Flutter-App/1.0'
              }
            });
            
            if (profileResponse.ok) {
              const profileData = await profileResponse.json();
              console.log('✅ Profil complet récupéré:', profileData);
              
              // Enrichir encore plus la réponse avec les données utilisateur
              enrichedData.sEmail = profileData.sEmail || email;
              enrichedData.sNom = profileData.sNom || '';
              enrichedData.sPrenom = profileData.sPrenom || '';
              enrichedData.sPhoto = profileData.sPhoto || '';
              enrichedData.sTel = profileData.sTel || '';
              enrichedData.sRue = profileData.sRue || '';
              enrichedData.sCity = profileData.sCity || '';
              enrichedData.sZip = profileData.sZip || '';
              
              console.log('✅ Réponse enrichie avec les infos utilisateur complètes');
            } else {
              console.log('⚠️ get-info-profil a retourné:', profileResponse.status);
              // Au moins ajouter l'email
              data.sEmail = email;
            }
          } catch (e) {
            console.log('⚠️ Erreur lors de l\'appel get-info-profil:', e.message);
            // Au moins ajouter l'email
            data.sEmail = email;
          }
          
          console.log('✅ Réponse enrichie finale:');
          console.log(`   iProfile: ${enrichedData.iProfile}`);
          console.log(`   iBasket: ${enrichedData.iBasket}`);
          console.log(`   sPaysLangue: ${enrichedData.sPaysLangue}`);
          console.log(`   sPaysFav: ${enrichedData.sPaysFav}`);
          console.log(`   sEmail: ${enrichedData.sEmail}`);
          console.log(`   sNom: ${enrichedData.sNom || '(vide)'}`);
          console.log(`   sPrenom: ${enrichedData.sPrenom || '(vide)'}`);
        }
        
        // Transférer les cookies au client Flutter
        setCookieHeaders.forEach(cookie => {
          res.append('Set-Cookie', cookie);
        });
        
        // ✅ CRITIQUE: Ajouter le cookie GuestProfile mis à jour pour Flutter
        if (isCodeValidation && data.status === 'OK' && enrichedData) {
          console.log('🍪 Ajout du cookie GuestProfile mis à jour pour Flutter...');
          const updatedGuestProfile = {
            iProfile: enrichedData.newIProfile || enrichedData.iProfile,
            iBasket: enrichedData.newIBasket || enrichedData.iBasket,
            sPaysLangue: enrichedData.sPaysLangue,
            sPaysFav: enrichedData.sPaysFav
          };
          
          const updatedCookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(updatedGuestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
          res.append('Set-Cookie', updatedCookieString);
          console.log('✅ Cookie GuestProfile mis à jour ajouté aux headers de réponse');
        }
      }
      
      console.log(`✅ Connexion ${password ? 'validée' : 'code envoyé'} !`);
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response from SNAL' });
    }
    
      // ✅ CRITIQUE: Mettre à jour les cookies avec les nouveaux identifiants (comme SNAL)
      if (data.status === 'OK' && enrichedData.newIProfile && enrichedData.newIBasket) {
        console.log('🍪 Mise à jour des cookies avec les nouveaux identifiants:');
        console.log(`   Nouveau iProfile: ${enrichedData.newIProfile}`);
        console.log(`   Nouveau iBasket: ${enrichedData.newIBasket}`);
        
        // Mettre à jour le cookie GuestProfile avec les nouveaux identifiants
        const updatedGuestProfile = {
          iProfile: enrichedData.newIProfile,
          iBasket: enrichedData.newIBasket,
          sPaysLangue: enrichedData.sPaysLangue || guestProfile.sPaysLangue,
          sPaysFav: enrichedData.sPaysFav || guestProfile.sPaysFav,
        };
        
        const updatedCookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(updatedGuestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
        res.append('Set-Cookie', updatedCookieString);
        
        // Mettre à jour le cookie Guest_basket_init (comme SNAL)
        const basketInitCookieString = `Guest_basket_init=${encodeURIComponent(JSON.stringify({ iBasket: enrichedData.newIBasket }))}; Path=/; HttpOnly=false; Max-Age=31536000`;
        res.append('Set-Cookie', basketInitCookieString);
        
        console.log('✅ Cookies mis à jour avec les nouveaux identifiants');
      }
      
      // ✅ CRITIQUE: S'assurer que les nouveaux identifiants sont dans la réponse
      if (isCodeValidation && data.status === 'OK') {
        // S'assurer que les nouveaux identifiants sont présents dans la réponse
        if (enrichedData.newIProfile && enrichedData.newIBasket) {
          console.log('✅ Nouveaux identifiants ajoutés à la réponse pour Flutter:');
          console.log(`   newIProfile: ${enrichedData.newIProfile}`);
          console.log(`   newIBasket: ${enrichedData.newIBasket}`);
        } else {
          console.log('⚠️ Nouveaux identifiants manquants dans la réponse enrichie');
        }
      }
      
      // ✅ CRITIQUE: Debug de ce qui est envoyé à Flutter
      console.log('🔍 DEBUG: Contenu de enrichedData avant envoi:');
      console.log('   newIProfile: ', enrichedData?.newIProfile);
      console.log('   newIBasket: ', enrichedData?.newIBasket);
      console.log('   iProfile: ', enrichedData?.iProfile);
      console.log('   iBasket: ', enrichedData?.iBasket);
      console.log('   status: ', enrichedData?.status);
      
      // ✅ CRITIQUE: Envoyer la réponse enrichie à Flutter
      res.json(enrichedData || data);
  } catch (error) {
    console.error('❌ Auth/Login-With-Code Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la connexion avec code',
      message: error.message
    });
  }
});

// **********************************************************************
// 🔐 AUTH/GOOGLE-MOBILE: Connexion OAuth Google
// **********************************************************************
app.get('/api/auth/google-mobile', async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/GOOGLE-MOBILE: Connexion OAuth Google Mobile`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // Rediriger directement vers SNAL OAuth (sans paramètres)
    const snallUrl = 'https://jirig.be/api/auth/google-mobile';
    
    console.log(`🌐 Redirection vers SNAL Google OAuth Mobile: ${snallUrl}`);
    console.log(`📝 Note: SNAL redirigera vers / après OAuth, nous intercepterons cette redirection`);
    
    res.redirect(snallUrl);
  } catch (error) {
    console.error('❌ Auth/Google Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la connexion Google',
      message: error.message
    });
  }
});

// **********************************************************************
// 🔐 AUTH/FACEBOOK: Connexion OAuth Facebook
// **********************************************************************
app.get('/api/auth/facebook', async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/FACEBOOK: Connexion OAuth Facebook`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // Rediriger directement vers SNAL OAuth (sans paramètres)
    const snallUrl = 'https://jirig.be/api/auth/facebook';
    
    console.log(`🌐 Redirection vers SNAL Facebook OAuth: ${snallUrl}`);
    console.log(`📝 Note: SNAL redirigera vers / après OAuth, nous intercepterons cette redirection`);
    
    res.redirect(snallUrl);
  } catch (error) {
    console.error('❌ Auth/Facebook Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la connexion Facebook',
      message: error.message
    });
  }
});

// **********************************************************************
// 🔐 AUTH/OAUTH-CALLBACK: Callback OAuth pour retourner dans Flutter
// **********************************************************************
app.get('/api/auth/oauth-callback', async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/OAUTH-CALLBACK: Callback OAuth pour Flutter`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    const { provider, success, error } = req.query;
    
    console.log(`📥 Callback OAuth reçu:`, { provider, success, error });
    console.log(`📥 Query params complets:`, req.query);
    
    const providerName = provider || 'unknown';

    if (success === 'true' || !error) {
      console.log(`✅ OAuth ${provider} réussi, redirection vers Flutter`);
      
      // Rediriger vers Flutter avec succès
      const successUrl = `${FLUTTER_APP_URL}/#/home?oauth=success&provider=${encodeURIComponent(providerName)}`;
      res.redirect(successUrl);
    } else {
      console.log(`❌ OAuth ${provider} échoué: ${error}`);
      
      // Rediriger vers Flutter avec erreur
      const errorMessage = error || 'unknown';
      const errorUrl = `${FLUTTER_APP_URL}/#/login?oauth=error&provider=${encodeURIComponent(providerName)}&error=${encodeURIComponent(errorMessage)}`;
      res.redirect(errorUrl);
    }
  } catch (error) {
    console.error('❌ Auth/OAuth-Callback Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors du callback OAuth',
      message: error.message
    });
  }
});

// **********************************************************************
// 🔐 AUTH/OAUTH-SUCCESS: Intercepter la redirection SNAL vers / après OAuth
// **********************************************************************
app.get('/api/auth/oauth-success', async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/OAUTH-SUCCESS: Interception redirection SNAL après OAuth`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    const { provider } = req.query;
    const providerName = provider || 'unknown';
    
    console.log(`📥 Redirection SNAL interceptée avec provider:`, provider);
    console.log(`📥 Query params complets:`, req.query);
    
    // Rediriger vers Flutter avec succès
    console.log(`✅ OAuth ${providerName} réussi, redirection vers Flutter`);
    const successUrl = `${FLUTTER_APP_URL}/#/home?oauth=success&provider=${encodeURIComponent(providerName)}`;
    res.redirect(successUrl);
    
  } catch (error) {
    console.error('❌ Auth/OAuth-Success Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la redirection OAuth',
      message: error.message
    });
  }
});

// **********************************************************************
// 🔐 AUTH/LOGIN: Connexion avec Magic Link (email + token)
// **********************************************************************
app.post('/api/auth/login', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🔐 AUTH/LOGIN: Connexion utilisateur`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    const { email, password } = req.body;
    
    console.log(`🔐 Paramètres reçus:`, { 
      email: email || '(vide)', 
      password: password ? '***' : '(vide)' 
    });
    console.log(`🔄 CallBackUrl reçu dans query:`, req.query.callBackUrl || '(aucun)');
    console.log(`🔄 CallBackUrl reçu dans body:`, req.body.callBackUrl || '(aucun)');

    // ✅ Récupérer iProfile et iBasket depuis les headers (envoyés par Flutter)
    const iProfileFromHeader = req.headers['x-iprofile'] || '';
    const iBasketFromHeader = req.headers['x-ibasket'] || '';
    
    console.log(`📤 X-IProfile header:`, iProfileFromHeader || '(vide)');
    console.log(`📤 X-IBasket header:`, iBasketFromHeader || '(vide)');
    
    // Récupérer le GuestProfile depuis le header X-Guest-Profile (envoyé par Flutter depuis localStorage)
    const guestProfileHeader = req.headers['x-guest-profile'];
    console.log(`📤 X-Guest-Profile header:`, guestProfileHeader);
    
    let existingProfile = { iProfile: '', iBasket: '', sPaysLangue: '', sPaysFav: '' };
    
    // Priorité au header (Flutter localStorage)
    if (guestProfileHeader) {
      try {
        existingProfile = JSON.parse(guestProfileHeader);
        console.log(`✅ GuestProfile depuis Flutter localStorage (via header):`, existingProfile);
      } catch (e) {
        console.log(`⚠️ Erreur parsing GuestProfile header:`, e.message);
      }
    } else {
      console.log(`⚠️ Aucun GuestProfile dans le header, utilisation des valeurs par défaut`);
    }

    // ✅ Créer le cookie GuestProfile pour SNAL (même logique que les autres endpoints)
    // Priorité: X-IProfile/X-IBasket headers > GuestProfile header > vide
    const guestProfile = {
      iProfile: iProfileFromHeader || existingProfile.iProfile || '',
      iBasket: iBasketFromHeader || existingProfile.iBasket || '',
      sPaysLangue: existingProfile.sPaysLangue || '',
      sPaysFav: existingProfile.sPaysFav || ''
    };
    
    console.log(`\n${'='.repeat(60)}`);
    console.log(`🍪 GUESTPROFILE DÉTAILLÉ POUR SNAL:`);
    console.log(`${'='.repeat(60)}`);
    console.log(`iProfile: "${guestProfile.iProfile}" (${guestProfile.iProfile.length} chars)`);
    console.log(`iBasket: "${guestProfile.iBasket}" (${guestProfile.iBasket.length} chars)`);
    console.log(`sPaysLangue: "${guestProfile.sPaysLangue}"`);
    console.log(`sPaysFav: "${guestProfile.sPaysFav}" (${guestProfile.sPaysFav.length} chars)`);
    console.log(`${'='.repeat(60)}\n`);
    
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    console.log(`👤 GuestProfile pour cookie:`, guestProfile);
    console.log(`📱 Appel SNAL API LOCAL: https://jirig.be/api/auth/login`);
    console.log(`📤 Body envoyé:`, { 
      email, 
      password: password ? `*** (${password.length} chars)` : '(vide)' 
    });
    console.log(`📤 Body complet pour debug:`, { email, password });

    // Faire la requête POST vers l'API SNAL-Project LOCAL
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      },
      body: JSON.stringify({
        email: email,
        password: password || ''
      })
    });

    console.log(`📡 Response status: ${response.status}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL:`, errorText);
      
      return res.status(response.status).json({
        success: false,
        error: 'API SNAL Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText
      });
    }

    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    console.log(`📡 Response headers:`, Object.fromEntries(response.headers.entries()));
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`📡 API Response parsed:`, data);
      
      // ✅ Afficher le Magic Link si présent dans la réponse
      if (data && data.link) {
        console.log(`\n${'🔗'.repeat(30)}`);
        console.log(`✉️  MAGIC LINK ENVOYÉ PAR EMAIL:`);
        console.log(`${'🔗'.repeat(30)}`);
        console.log(`🔑 Lien complet: ${data.link}`);
        console.log(`📧 Envoyé à: ${email}`);
        
        // Extraire le callBackUrl du magic link si présent
        try {
          const linkUrl = new URL(data.link);
          const linkCallBackUrl = linkUrl.searchParams.get('callBackUrl');
          if (linkCallBackUrl) {
            console.log(`🔄 CallBackUrl dans le magic link: ${decodeURIComponent(linkCallBackUrl)}`);
          }
          const token = linkUrl.searchParams.get('token');
          if (token) {
            console.log(`🎫 Token: ${token}`);
          }
        } catch (e) {
          console.log(`⚠️ Impossible de parser l'URL du magic link:`, e.message);
        }
        
        console.log(`${'🔗'.repeat(30)}\n`);
      }
      
      // Extraire les cookies de la réponse SNAL (contient le profil mis à jour)
      const setCookieHeaders = response.headers.raw()['set-cookie'];
      if (setCookieHeaders) {
        console.log(`🍪 Cookies reçus de SNAL:`, setCookieHeaders);
        
        // Extraire iProfile et iBasket du cookie GuestProfile
        const guestProfileCookie = setCookieHeaders.find(cookie => cookie.startsWith('GuestProfile='));
        let updatedProfile = null;
        
        if (guestProfileCookie) {
          try {
            const cookieValue = guestProfileCookie.split(';')[0].split('=')[1];
            const decodedValue = decodeURIComponent(cookieValue);
            updatedProfile = JSON.parse(decodedValue);
            
            console.log(`\n${'='.repeat(60)}`);
            console.log(`🎯 PROFIL UTILISATEUR CONNECTÉ (AVANT CORRECTION):`);
            console.log(`${'='.repeat(60)}`);
            console.log(`👤 iProfile: ${updatedProfile.iProfile || 'N/A'}`);
            console.log(`🛒 iBasket: ${updatedProfile.iBasket || 'N/A'}`);
            console.log(`🌍 sPaysLangue: ${updatedProfile.sPaysLangue || 'N/A'}`);
            console.log(`🏳️  sPaysFav: ${updatedProfile.sPaysFav || 'N/A'}`);
            console.log(`${'='.repeat(60)}\n`);
            
            // ✅ CORRECTION: Remplacer sPaysLangue et sPaysFav par les valeurs du GuestProfile envoyé
            if (guestProfile.sPaysLangue) {
              updatedProfile.sPaysLangue = guestProfile.sPaysLangue;
            }
            if (guestProfile.sPaysFav) {
              updatedProfile.sPaysFav = guestProfile.sPaysFav;
            }
            
            console.log(`🔧 CORRECTION: Restauration des valeurs du GuestProfile envoyé`);
            console.log(`   sPaysLangue: ${guestProfile.sPaysLangue} → ${updatedProfile.sPaysLangue}`);
            console.log(`   sPaysFav: ${guestProfile.sPaysFav} → ${updatedProfile.sPaysFav}`);
            
            console.log(`\n${'='.repeat(60)}`);
            console.log(`✅ PROFIL UTILISATEUR CONNECTÉ (CORRIGÉ):`);
            console.log(`${'='.repeat(60)}`);
            console.log(`👤 iProfile: ${updatedProfile.iProfile || 'N/A'}`);
            console.log(`🛒 iBasket: ${updatedProfile.iBasket || 'N/A'}`);
            console.log(`🌍 sPaysLangue: ${updatedProfile.sPaysLangue || 'N/A'}`);
            console.log(`🏳️  sPaysFav: ${updatedProfile.sPaysFav || 'N/A'}`);
            console.log(`${'='.repeat(60)}\n`);
            
            // Remplacer le cookie dans le tableau
            const guestProfileCookieIndex = setCookieHeaders.findIndex(cookie => cookie.startsWith('GuestProfile='));
            if (guestProfileCookieIndex !== -1) {
              const correctedCookie = `GuestProfile=${encodeURIComponent(JSON.stringify(updatedProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
              setCookieHeaders[guestProfileCookieIndex] = correctedCookie;
              console.log(`✅ Cookie GuestProfile corrigé et remplacé dans les headers`);
            }
          } catch (e) {
            console.log(`⚠️ Erreur lors du parsing du cookie GuestProfile:`, e.message);
          }
        }
        
        // ✅ Si c'est une validation de token (password présent) et qu'on a un GuestProfile,
        // enrichir la réponse avec TOUTES les données du profil pour Flutter
        if (password && updatedProfile) {
          console.log('🔄 Enrichissement de la réponse avec les données du profil...');
          
          // Données du GuestProfile (cookie)
          data.iProfile = updatedProfile.iProfile;
          data.iBasket = updatedProfile.iBasket;
          data.sPaysLangue = updatedProfile.sPaysLangue;
          data.sPaysFav = updatedProfile.sPaysFav;
          
          // ✅ Appeler get-info-profil pour récupérer les infos complètes (sNom, sPrenom, sEmail, sPhoto)
          try {
            console.log('📞 Appel de get-info-profil pour récupérer les infos utilisateur complètes...');
            
            const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(updatedProfile))}`;
            const authSessionCookie = setCookieHeaders.find(cookie => cookie.startsWith('auth.session-token='));
            const sessionCookie = authSessionCookie ? authSessionCookie.split(';')[0] : '';
            
            const profileResponse = await fetch(`https://jirig.be/api/get-info-profil`, {
              method: 'GET',
              headers: {
                'Accept': 'application/json',
                'Cookie': `${cookieString}; ${sessionCookie}`,
                'User-Agent': 'Mobile-Flutter-App/1.0'
              }
            });
            
            if (profileResponse.ok) {
              const profileData = await profileResponse.json();
              console.log('✅ Profil complet récupéré:', profileData);
              
              // Enrichir encore plus la réponse avec les données utilisateur
              enrichedData.sEmail = profileData.sEmail || email;
              enrichedData.sNom = profileData.sNom || '';
              enrichedData.sPrenom = profileData.sPrenom || '';
              enrichedData.sPhoto = profileData.sPhoto || '';
              enrichedData.sTel = profileData.sTel || '';
              enrichedData.sRue = profileData.sRue || '';
              enrichedData.sCity = profileData.sCity || '';
              enrichedData.sZip = profileData.sZip || '';
              
              console.log('✅ Réponse enrichie avec les infos utilisateur complètes');
            } else {
              console.log('⚠️ get-info-profil a retourné:', profileResponse.status);
              // Au moins ajouter l'email
              data.sEmail = email;
            }
          } catch (e) {
            console.log('⚠️ Erreur lors de l\'appel get-info-profil:', e.message);
            // Au moins ajouter l'email
            data.sEmail = email;
          }
          
          console.log('✅ Réponse enrichie finale:');
          console.log(`   iProfile: ${enrichedData.iProfile}`);
          console.log(`   iBasket: ${enrichedData.iBasket}`);
          console.log(`   sPaysLangue: ${enrichedData.sPaysLangue}`);
          console.log(`   sPaysFav: ${enrichedData.sPaysFav}`);
          console.log(`   sEmail: ${enrichedData.sEmail}`);
          console.log(`   sNom: ${enrichedData.sNom || '(vide)'}`);
          console.log(`   sPrenom: ${enrichedData.sPrenom || '(vide)'}`);
        }
        
        // Gérer le callBackUrl comme SNAL
        const callBackUrl = req.query.callBackUrl || req.body.callBackUrl;
        if (callBackUrl) {
          console.log(`🔄 CallBackUrl détecté: ${callBackUrl}`);
          // Ajouter le cookie callBackUrl pour Flutter
          const callBackCookie = `callback_url=${encodeURIComponent(callBackUrl)}; Path=/; HttpOnly=false; Max-Age=864000`;
          res.setHeader('Set-Cookie', [...(res.getHeader('Set-Cookie') || []), callBackCookie]);
        }
        
        // Transférer les cookies au client Flutter
        setCookieHeaders.forEach(cookie => {
          res.append('Set-Cookie', cookie);
        });
      }
      
      console.log(`✅ Connexion ${password ? 'validée' : 'lien magique envoyé'} !`);
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response from SNAL' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Auth/Login Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la connexion',
      message: error.message
    });
  }
});

// **********************************************************************
// 🔐 AUTH/DISCONNECT: Déconnexion utilisateur (comme SNAL-Project disconnect.post.ts)
// **********************************************************************
app.post('/api/auth/disconnect', express.json(), async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`🚪 AUTH/DISCONNECT: Déconnexion utilisateur`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // ✅ Récupérer le GuestProfile depuis le header X-Guest-Profile (Flutter) ou les cookies (Web)
    const guestProfileHeader = req.headers['x-guest-profile'];
    let guestProfile;
    
    console.log(`📥 Headers reçus:`, {
      'x-guest-profile': guestProfileHeader ? guestProfileHeader.substring(0, 100) + '...' : '(aucun)',
      'x-iprofile': req.headers['x-iprofile'] || '(aucun)',
      'x-ibasket': req.headers['x-ibasket'] || '(aucun)',
      'cookie': req.headers.cookie ? req.headers.cookie.substring(0, 100) + '...' : '(aucun)'
    });
    
    if (guestProfileHeader) {
      // Flutter envoie via header
      try {
        guestProfile = JSON.parse(guestProfileHeader);
        console.log(`✅ GuestProfile depuis Flutter localStorage (via header):`, guestProfile);
      } catch (e) {
        console.log(`❌ Erreur parsing GuestProfile header:`, e.message);
        return res.status(400).json({
          success: false,
          error: 'Header invalide',
          message: 'Impossible de parser le header X-Guest-Profile'
        });
      }
    } else {
      // Web utilise les cookies
      const cookies = req.headers.cookie || '';
      const guestProfileMatch = cookies.match(/GuestProfile=([^;]+)/);
      
      if (guestProfileMatch) {
        try {
          guestProfile = JSON.parse(decodeURIComponent(guestProfileMatch[1]));
          console.log(`🍪 GuestProfile trouvé dans cookies:`, guestProfile);
        } catch (e) {
          console.log(`❌ Erreur parsing GuestProfile cookie:`, e.message);
        }
      }
    }
    
    // Si aucun profil trouvé, créer un profil vide
    if (!guestProfile) {
      guestProfile = { iProfile: '', iBasket: '', sPaysLangue: '', sPaysFav: '' };
      console.log(`⚠️ Aucun GuestProfile trouvé, utilisation d'un profil vide`);
    }
    
    const iProfile = guestProfile.iProfile || '';
    const iBasket = guestProfile.iBasket || '';
    const sPaysLangue = guestProfile.sPaysLangue || '';
    const sPaysFav = guestProfile.sPaysFav || '';
    
    console.log(`📋 Profil actuel avant déconnexion:`, {
      iProfile: iProfile || '(vide)',
      iBasket: iBasket || '(vide)',
      sPaysLangue: sPaysLangue || '(vide)',
      sPaysFav: sPaysFav || '(vide)'
    });
    
    // Créer le cookie GuestProfile pour SNAL
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
    
    console.log(`📱 Appel SNAL API: https://jirig.be/api/auth/disconnect`);
    console.log(`🍪 Cookie GuestProfile envoyé:`, cookieString.substring(0, 100) + '...');
    
    // Faire la requête POST vers l'API SNAL-Project
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/auth/disconnect`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });
    
    console.log(`📡 Response status: ${response.status}`);
    console.log(`📡 Response headers:`, Object.fromEntries(response.headers.entries()));
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL:`, errorText);
      
      return res.status(response.status).json({
        success: false,
        error: 'API SNAL Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText
      });
    }
    
    const responseData = await response.json();
    console.log(`✅ Réponse SNAL disconnect:`, responseData);
    
    // Récupérer les nouveaux identifiants depuis la réponse
    const newIProfile = responseData.iProfile?.toString() || '';
    const newIBasket = responseData.iBasket?.toString() || '';
    const success = responseData.success === true;
    
    console.log(`📋 Nouveaux identifiants après déconnexion:`, {
      iProfile: newIProfile || '(vide)',
      iBasket: newIBasket || '(vide)',
      success: success
    });
    
    if (success && newIProfile && newIBasket) {
      console.log(`✅ Déconnexion réussie - Nouveaux identifiants anonymes générés`);
      
      // Créer le nouveau GuestProfile avec les nouveaux identifiants
      const newGuestProfile = {
        iProfile: newIProfile,
        iBasket: newIBasket,
        sPaysLangue: sPaysLangue, // Conserver la langue
        sPaysFav: sPaysFav // Conserver les pays favoris
      };
      
      const newCookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(newGuestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;
      
      console.log(`🍪 Nouveau GuestProfile créé:`, newGuestProfile);
      console.log(`🍪 Nouveau cookie à renvoyer:`, newCookieString.substring(0, 100) + '...');
      
      // Renvoyer la réponse avec le nouveau cookie
      res.set('Set-Cookie', newCookieString);
      res.status(200).json({
        success: true,
        iProfile: newIProfile,
        iBasket: newIBasket,
        message: 'Déconnexion réussie'
      });
      
      console.log(`✅ Réponse disconnect envoyée avec succès`);
    } else {
      console.log(`⚠️ Réponse disconnect incomplète ou échec`);
      res.status(200).json({
        success: false,
        message: 'Déconnexion incomplète',
        data: responseData
      });
    }
  } catch (error) {
    console.error('❌ Auth/Disconnect Error:', error.message);
    console.error('❌ Stack trace:', error.stack);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la déconnexion',
      message: error.message
    });
  }
});

// **********************************************************************
// 👤 GET-INFO-PROFIL: Récupération des informations du profil utilisateur
// **********************************************************************
app.get('/api/get-info-profil', async (req, res) => {
  console.log(`\n${'*'.repeat(70)}`);
  console.log(`👤 GET-INFO-PROFIL: Récupération du profil utilisateur`);
  console.log(`${'*'.repeat(70)}`);
  
  try {
    // ✅ Récupérer le GuestProfile depuis le header X-Guest-Profile (Flutter) ou les cookies (Web)
    const guestProfileHeader = req.headers['x-guest-profile'];
    let guestProfile;
    
    if (guestProfileHeader) {
      // Flutter envoie via header
      try {
        guestProfile = JSON.parse(guestProfileHeader);
        console.log(`✅ GuestProfile depuis Flutter localStorage (via header):`, guestProfile);
      } catch (e) {
        console.log(`❌ Erreur parsing GuestProfile header:`, e.message);
        return res.status(400).json({
          success: false,
          error: 'Header invalide',
          message: 'Impossible de parser le header X-Guest-Profile'
        });
      }
    } else {
      // Web utilise les cookies
      const cookies = req.headers.cookie || '';
      const guestProfileMatch = cookies.match(/GuestProfile=([^;]+)/);
      
      if (!guestProfileMatch) {
        console.log(`❌ Aucun cookie GuestProfile trouvé et aucun header X-Guest-Profile`);
        return res.status(401).json({
          success: false,
          error: 'Non authentifié',
          message: 'Aucun profil trouvé dans les cookies ou headers'
        });
      }
      
      try {
        guestProfile = JSON.parse(decodeURIComponent(guestProfileMatch[1]));
        console.log(`🍪 GuestProfile trouvé dans cookies:`, guestProfile);
      } catch (e) {
        console.log(`❌ Erreur parsing GuestProfile:`, e.message);
        return res.status(400).json({
          success: false,
          error: 'Cookie invalide',
          message: 'Impossible de parser le cookie GuestProfile'
        });
      }
    }
    
    const iProfile = guestProfile.iProfile || '';
    
    if (!iProfile) {
      console.log(`❌ iProfile manquant dans le cookie`);
      return res.status(400).json({
        success: false,
        error: 'iProfile manquant',
        message: 'Le cookie GuestProfile ne contient pas d\'iProfile'
      });
    }
    
    console.log(`👤 iProfile: ${iProfile}`);
    console.log(`📱 Appel SNAL API LOCAL: https://jirig.be/api/get-info-profil`);
    
    const cookieString = `GuestProfile=${encodeURIComponent(JSON.stringify(guestProfile))}; Path=/; HttpOnly=false; Max-Age=864000`;

    // Faire la requête GET vers l'API SNAL-Project LOCAL
    const fetch = require('node-fetch');
    const response = await fetch(`https://jirig.be/api/get-info-profil`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Cookie': cookieString,
        'User-Agent': 'Mobile-Flutter-App/1.0'
      }
    });

    console.log(`📡 Response status: ${response.status}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Error response from SNAL:`, errorText);
      
      return res.status(response.status).json({
        success: false,
        error: 'API SNAL Error',
        message: `Erreur ${response.status}: ${response.statusText}`,
        details: errorText
      });
    }

    const responseText = await response.text();
    console.log(`📡 Response RAW text:`, responseText);
    
    let data;
    try {
      data = JSON.parse(responseText);
      console.log(`📡 API Response parsed:`, data);
      console.log(`✅ Profil récupéré avec succès !`);
      
      // Log des informations principales
      if (data.iProfile) {
        console.log(`\n${'='.repeat(60)}`);
        console.log(`🎯 INFORMATIONS DU PROFIL:`);
        console.log(`${'='.repeat(60)}`);
        console.log(`👤 iProfile: ${data.iProfile || 'N/A'}`);
        console.log(`🛒 iBasket: ${data.iBasket || 'N/A'}`);
        console.log(`📧 Email: ${data.sEmail || 'N/A'}`);
        console.log(`👨 Nom: ${data.sNom || 'N/A'}`);
        console.log(`👤 Prénom: ${data.sPrenom || 'N/A'}`);
        console.log(`🌍 sPaysLangue: ${data.sPaysLangue || 'N/A'}`);
        console.log(`🏳️  sPaysFav: ${data.sPaysFav || 'N/A'}`);
        console.log(`${'='.repeat(60)}\n`);
      }
    } catch (e) {
      console.error(`❌ Erreur parsing JSON:`, e.message);
      return res.status(500).json({ success: false, error: 'Invalid JSON response from SNAL' });
    }
    
    // ✅ CORRECTION CRITIQUE: Remplacer SEULEMENT iProfile et iBasket par les vraies données du GuestProfile
    console.log(`🔧 CORRECTION: Remplacement SEULEMENT des identifiants par les vraies données utilisateur`);
    console.log(`   Avant - iProfile: ${data.iProfile || '(non présent)'}`);
    console.log(`   Avant - iBasket: ${data.iBasket || '(non présent)'}`);
    console.log(`   GuestProfile - iProfile: ${guestProfile.iProfile}`);
    console.log(`   GuestProfile - iBasket: ${guestProfile.iBasket}`);
    
    // Remplacer SEULEMENT les identifiants par les vraies données
    if (guestProfile.iProfile) {
      data.iProfile = guestProfile.iProfile;
    }
    if (guestProfile.iBasket) {
      data.iBasket = guestProfile.iBasket;
    }
    
    console.log(`   Après - iProfile: ${data.iProfile || '(non présent)'}`);
    console.log(`   Après - iBasket: ${data.iBasket || '(non présent)'}`);
    console.log(`✅ Seuls les identifiants ont été remplacés, les autres données utilisateur sont préservées`);
    
    res.json(data);
  } catch (error) {
    console.error('❌ Get-Info-Profil Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Erreur lors de la récupération du profil',
      message: error.message
    });
  }
});

// **********************************************************************
// 🗺️ GET-IKEA-STORE-LIST: Récupération des magasins IKEA
// **********************************************************************
app.get('/api/get-ikea-store-list', async (req, res) => {
  console.log('**********************************************************************');
  console.log('🗺️ GET-IKEA-STORE-LIST: Récupération des magasins IKEA');
  console.log('**********************************************************************');
  
  const { lat, lng } = req.query;
  
  // Récupérer iProfile depuis les headers (envoyé par Flutter)
  const iProfile = req.headers['x-iprofile'] || req.headers['X-IProfile'] || '';
  
  console.log('📍 Paramètres reçus:', {
    lat: lat || 'non fourni',
    lng: lng || 'non fourni',
    iProfile: iProfile || 'non fourni'
  });

  try {
    const fetch = require('node-fetch');
    
    // Récupérer le cookie depuis la requête
    const cookieHeader = req.headers.cookie || '';
    
    // Construire le cookie GuestProfile avec iProfile si nécessaire
    let finalCookie = cookieHeader;
    
    if (iProfile && !cookieHeader.includes('GuestProfile')) {
      const guestProfile = {
        iProfile: iProfile,
        iBasket: '',
        sPaysLangue: getGuestProfileFromHeaders(req).sPaysLangue || '',
      };
      const guestProfileEncoded = encodeURIComponent(JSON.stringify(guestProfile));
      finalCookie = `GuestProfile=${guestProfileEncoded}${cookieHeader ? '; ' + cookieHeader : ''}`;
    }
    
    console.log('🍪 Cookie:', finalCookie ? finalCookie.substring(0, 100) + '...' : 'Aucun');

    // Construire l'URL SNAL
    const snalUrl = `https://jirig.be/api/get-ikea-store-list?lat=${lat || ''}&lng=${lng || ''}`;
    console.log('📱 Appel SNAL API:', snalUrl);

    console.log('🔄 Tentative de connexion à SNAL...');
    
    const response = await fetch(snalUrl, {
      method: 'GET',
      headers: {
        'Cookie': finalCookie,  // Utiliser finalCookie avec iProfile
        'Content-Type': 'application/json',
      }
    });

    console.log('📡 Response status:', response.status);
    console.log('📡 Response headers:', response.headers.raw());
    
    const contentType = response.headers.get('content-type');
    console.log('📄 Content-Type:', contentType);
    
    const data = await response.json();
    console.log('🏪 Type de réponse:', Array.isArray(data) ? 'Array' : 'Object');
    console.log('🏪 Nombre de magasins:', data.stores?.length || data.length || 0);
    
    if (data.stores && Array.isArray(data.stores)) {
      console.log('✅ Format: { stores: [...], userLat, userLng }');
      console.log('📊 Premiers magasins:', data.stores.slice(0, 3).map(s => s.name || s.sMagasinName));
    } else if (Array.isArray(data)) {
      console.log('✅ Format: Array direct');
      console.log('📊 Premiers magasins:', data.slice(0, 3).map(s => s.name || s.sMagasinName));
    }
    
    res.json(data);
  } catch (error) {
    console.error('❌ Erreur get-ikea-store-list:', error);
    console.error('❌ Error type:', error.constructor.name);
    console.error('❌ Error code:', error.code);
    console.error('❌ Error errno:', error.errno);
    console.error('❌ Error syscall:', error.syscall);
    res.status(500).json({ 
      success: false,
      message: 'Erreur lors de la récupération des magasins',
      error: error.message,
      stores: []
    });
  }
});

// **********************************************************************
// 🧩 TILE PROXY: contourner CORS pour les tuiles OpenStreetMap
// **********************************************************************
app.get('/api/tiles/:z/:x/:y.:ext', async (req, res) => {
  try {
    const { z, x, y, ext } = req.params;
    const { style } = req.query;
    
    let tileUrl;
    switch (style) {
      case 'satellite':
        tileUrl = `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/${z}/${y}/${x}`;
        break;
      case 'carto_light':
        tileUrl = `https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/${z}/${x}/${y}.png`;
        break;
      case 'dark':
        tileUrl = `https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/${z}/${x}/${y}.png`;
        break;
      case 'standard':
      default:
        tileUrl = `https://tile.openstreetmap.org/${z}/${x}/${y}.${ext}`;
        break;
    }
    
    console.log(`🧩 Proxy tuile (${style || 'standard'}): ${tileUrl}`);

    const fetch = require('node-fetch');
    const response = await fetch(tileUrl, {
      headers: {
        'User-Agent': 'Mobile-Flutter-App/1.0',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8'
      }
    });

    if (!response.ok) {
      return res.status(response.status).send('Tile not found');
    }

    res.set('Content-Type', response.headers.get('content-type') || 'image/png');
    res.set('Cache-Control', 'public, max-age=86400'); // cache 24h
    response.body.pipe(res);
  } catch (error) {
    console.error('❌ Tile proxy error:', error.message);
    res.status(500).send('Tile proxy error');
  }
});

// Proxy pour Nominatim (recherche géographique)
app.get('/api/nominatim/search', async (req, res) => {
  try {
    const query = req.query.q;
    const limit = req.query.limit || 5;
    const nominatimUrl = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=${limit}`;
    console.log(`🔍 Proxy Nominatim: ${nominatimUrl}`);

    const fetch = require('node-fetch');
    const response = await fetch(nominatimUrl, {
      headers: {
        'User-Agent': 'Mobile-Flutter-App/1.0',
        'Accept': 'application/json'
      }
    });

    if (!response.ok) {
      return res.status(response.status).json({ error: 'Nominatim API error' });
    }

    const data = await response.json();
    console.log(`✅ Nominatim found ${data.length} results`);
    res.json(data);
  } catch (error) {
    console.error('❌ Nominatim proxy error:', error.message);
    res.status(500).json({ error: 'Nominatim proxy error' });
  }
});

// Proxy vers l'API jirig.be en production pour les autres endpoints
app.use('/api', createProxyMiddleware({
  target: 'https://jirig.be',
  changeOrigin: true,
  secure: true,
  logLevel: 'debug',
  // ✅ Exclure les endpoints spécifiques déjà définis
  filter: (pathname, req) => {
    const excludedPaths = [
      '/api/projet-download',
      '/api/update-country-selected',
      '/api/add-product-to-wishlist',
      '/api/delete-article-wishlistBasket',
      '/api/update-country-wishlistBasket',
      '/api/update-quantity-articleBasket',
      '/api/get-basket-list-article',
      '/api/auth/init',
      '/api/auth/login',
      '/api/auth/login-with-code',  // Connexion avec code - géré spécifiquement
      '/api/auth/google-mobile',      // OAuth Google mobile - géré directement par Flutter
      '/api/auth/facebook',    // OAuth Facebook - géré directement par Flutter
      '/api/oauth/callback',   // Callback OAuth - non utilisé
      '/api/get-info-profil',
      '/api/profile/update',   // Mise à jour du profil - géré spécifiquement
      '/api/get-ikea-store-list',
      '/api/tiles',
      '/api/nominatim'
    ];
    return !excludedPaths.includes(pathname);
  },
  onError: (err, req, res) => {
    console.error('❌ Proxy Error:', err.message);
  },
  onProxyReq: (proxyReq, req, res) => {
    console.log(`🔄 Proxying to PRODUCTION: ${req.method} ${req.url}`);
  }
}));

// Route de test
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Proxy server is running' });
});

app.listen(PORT, () => {
  console.log(`🚀 Proxy server running on http://localhost:${PORT}`);
  console.log(`📡 Proxying requests to https://jirig.be`);
  console.log(`🌐 Accessible from Flutter Web at: http://localhost:${PORT}`);
  console.log(`🔍 Health check: http://localhost:${PORT}/health`);
});
