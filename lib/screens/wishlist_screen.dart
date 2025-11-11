import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/search_modal.dart';
import '../widgets/simple_map_modal.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../config/api_config.dart';
import '../services/local_storage_service.dart';
import '../services/route_tracker.dart';
// Import conditionnel pour dart:html (Web uniquement)
import '../utils/web_utils.dart';
import 'package:animations/animations.dart';
import 'dart:math' as math;

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> with RouteTracker, WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _wishlistData;
  String? _selectedBasketName;
  bool _hasLoaded = false; // Flag pour éviter les rechargements multiples
  String? _lastRefreshParam; // Pour détecter les changements de refresh query param (comme SNAL avec index)
  bool _showMap = false; // Pour afficher/masquer la carte
  DateTime? _lastLoadTime; // Timestamp du dernier chargement pour éviter les rechargements trop fréquents
  bool _isGreenLight = false; // Pour l'animation du point vert
  int _currentImageIndex = 0; // Index de l'image actuellement affichée en plein écran
  bool _isCountrySidebarOpen = false; // Empêcher ouvertures multiples du sidebar
  final Map<String, ValueNotifier<Map<String, dynamic>>> _articleNotifiers = {};
  
  // ✨ ANIMATIONS - Style "Cascade Fluide" (différent des 3 autres pages)
  late AnimationController _buttonsController;
  late AnimationController _cardsController;
  late AnimationController _articlesController;
  bool _animationsInitialized = false;
  
  ApiService get _apiService => Provider.of<ApiService>(context, listen: false);
  TranslationService get _translationService => Provider.of<TranslationService>(context, listen: false);

  String _articleKey(Map<String, dynamic> article) {
    return (article['sCodeArticleCrypt'] ??
            article['sCodeArticle'] ??
            article['sName'] ??
            article['sname'] ??
            article.hashCode)
        .toString();
  }

  ValueNotifier<Map<String, dynamic>> _ensureArticleNotifier(Map<String, dynamic> article) {
    final key = _articleKey(article);
    final mapData = Map<String, dynamic>.from(article);
    final existing = _articleNotifiers[key];
    if (existing != null) {
      if (!mapEquals(existing.value, mapData)) {
        existing.value = mapData;
      }
      return existing;
    }
    final notifier = ValueNotifier<Map<String, dynamic>>(mapData);
    _articleNotifiers[key] = notifier;
    return notifier;
  }

  void _refreshArticleNotifiers() {
    final articles = (_wishlistData?['pivotArray'] as List?) ?? const [];
    final activeKeys = <String>{};

    for (final item in articles) {
      if (item is Map) {
        final mapData = Map<String, dynamic>.from(item as Map);
        final key = _articleKey(mapData);
        activeKeys.add(key);
        final notifier = _articleNotifiers.putIfAbsent(key, () => ValueNotifier<Map<String, dynamic>>(mapData));
        if (!mapEquals(notifier.value, mapData)) {
          notifier.value = mapData;
        }
      }
    }

    final toRemove = _articleNotifiers.keys.where((key) => !activeKeys.contains(key)).toList();
    for (final key in toRemove) {
      _articleNotifiers[key]?.dispose();
      _articleNotifiers.remove(key);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _loadWishlistData();
    _startGreenAnimation();
  }
  
  /// ✨ Initialiser les animations (Style "Cascade Fluide")
  void _initializeAnimations() {
    try {
      // Marquer comme initialisé IMMÉDIATEMENT pour éviter les erreurs
      _animationsInitialized = true;
      
      // Boutons circulaires : Float effect (monte/descend légèrement)
      _buttonsController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      // Cartes : Cascade (apparaissent l'une après l'autre)
      _cardsController = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      );
      
      // Articles : Slide in séquencé
      _articlesController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      
      print('✅ Animations Wishlist initialisées (style Cascade Fluide)');
      
      // Démarrer les animations après un court délai
      Future.delayed(Duration.zero, () {
        if (mounted && _animationsInitialized) {
          try {
            _buttonsController.forward();
            _cardsController.forward();
            _articlesController.forward();
          } catch (e) {
            print('❌ Erreur démarrage animations: $e');
          }
        }
      });
    } catch (e) {
      print('❌ Erreur initialisation animations wishlist: $e');
      _animationsInitialized = false;
    }
  }

  void _startGreenAnimation() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isGreenLight = !_isGreenLight;
        });
        _startGreenAnimation(); // Répète l'animation
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose des animations
    try {
      if (_animationsInitialized) {
        _buttonsController.dispose();
        _cardsController.dispose();
        _articlesController.dispose();
      }
    } catch (e) {
      print('❌ Erreur dispose animations wishlist: $e');
    }
    for (final notifier in _articleNotifiers.values) {
      notifier.dispose();
    }
    _articleNotifiers.clear();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Détecter le changement du paramètre refresh (comme SNAL avec index dans query)
    // Cela force le rechargement quand on revient du podium avec un nouveau pays
    // OPTIMISATION: Ne vérifier que si pas déjà en cours de chargement
    if (_hasLoaded && mounted && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLoading) {
          _checkRefreshParamAndReload();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // OPTIMISATION: Recharger seulement si pas déjà en cours de chargement et après un délai
    if (state == AppLifecycleState.resumed && _hasLoaded && !_isLoading) {
      print('🔄 App resumed - Rechargement différé de la wishlist...');
      // Délai de 1 seconde pour éviter les rechargements trop fréquents
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_isLoading) {
          _loadWishlistData(force: true);
        }
      });
    }
  }

  /// ✅ Vérifier si le paramètre refresh a changé et recharger (comme SNAL avec query.index)
  void _checkRefreshParamAndReload() {
    try {
      final uri = GoRouterState.of(context).uri;
      final refreshParam = uri.queryParameters['refresh'];
      
      // Si le paramètre refresh a changé depuis le dernier chargement, recharger
      if (refreshParam != null && refreshParam != _lastRefreshParam) {
        print('🔄 Détection changement refresh param: $_lastRefreshParam → $refreshParam');
        print('🔄 Rechargement automatique de la wishlist (comme SNAL avec query.index)...');
        _lastRefreshParam = refreshParam;
        // OPTIMISATION: Vérifier qu'on n'est pas déjà en train de charger
        if (!_isLoading) {
          _loadWishlistData(force: true);
        }
      }
    } catch (e) {
      print('❌ Erreur _checkRefreshParamAndReload: $e');
    }
  }

  Future<void> _loadWishlistData({bool force = false}) async {
    // OPTIMISATION: Éviter les rechargements trop fréquents (moins de 5 secondes)
    final now = DateTime.now();
    if (!force && _lastLoadTime != null && now.difference(_lastLoadTime!).inSeconds < 5) {
      print('⏱️ Rechargement ignoré - trop récent (${now.difference(_lastLoadTime!).inSeconds}s)');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    _lastLoadTime = now;

    try {
      // 1. Récupérer le profil depuis le LocalStorage (déjà initialisé dans app.dart)
      final profileData = await LocalStorageService.getProfile();
      
      print('🔄 === RECHARGEMENT WISHLIST ===');
      print('📋 Profile récupéré: $profileData');
      print('📋 iProfile: ${profileData?['iProfile']}');
      print('📋 iBasket: ${profileData?['iBasket']}');
      print('📋 sPaysFav: ${profileData?['sPaysFav']}');
      print('📋 sPaysLangue: ${profileData?['sPaysLangue']}');
      
      if (profileData == null || 
          profileData['iProfile'] == null || 
          profileData['iProfile'].toString().isEmpty) {
        // Pas de profil valide -> Créer un profil guest
        print('⚠️ Pas de profil valide, création d\'un profil guest...');
        await _createGuestProfile();
        return;
      }

      // 2. Utiliser le profil existant (PAS de réinitialisation)
      final iProfile = profileData['iProfile'].toString();
      final iBasket = profileData['iBasket']?.toString();
      
      print('✅ Profil existant trouvé - iProfile: $iProfile');
      print('✅ iBasket: $iBasket');
      
      // 3. Charger directement la wishlist (sans réinitialiser le profil)
      await _loadWishlistWithProfile(iProfile);
    } catch (e) {
      print('❌ Erreur _loadWishlistData: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement de la wishlist: $e'; // Pas de clé spécifique dans l'API
      });
    }
  }

  Future<void> _createGuestProfile() async {
    try {
       // ⚠️ NE PAS appeler initializeUserProfile ici !
      // Le profil est déjà initialisé dans app.dart
      // On charge simplement avec un iBasket vide
      
        setState(() {
          _isLoading = false;
          _wishlistData = {
            'meta': {
              'iBestResultJirig': 0,
              'iTotalPriceArticleSelected': 0.0,
              'sResultatGainPerte': '0€',
            },
            'pivotArray': [],
          };
          _selectedBasketName = 'Wishlist (0 Art.)';
          _hasLoaded = true; // Marquer comme chargé même si vide
        });
        _refreshArticleNotifiers();
      
      print('⚠️ Pas de profil trouvé - Wishlist vide affichée');
    } catch (e) {
      print('❌ Erreur _createGuestProfile: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la création du profil: $e'; // Pas de clé spécifique dans l'API
      });
    }
  }

  Future<void> _loadWishlistWithProfile(String iProfile) async {
    try {
      // Récupérer iBasket depuis le LocalStorage (déjà disponible)
      final profileData = await LocalStorageService.getProfile();
      final iBasket = profileData?['iBasket']?.toString() ?? '';
      
      print('🛒 iBasket récupéré: $iBasket');
      print('⚡ Appel direct à getBasketListArticle avec sAction=INIT');
      
      // Appel DIRECT à getBasketListArticle (avec ou sans iBasket)
      // L'API SNAL-Project retourne iBasket dans la réponse si non fourni
      await _loadArticlesDirectly(iProfile, iBasket);
    } catch (e) {
      print('❌ Erreur _loadWishlistWithProfile: $e');
        setState(() {
          _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des données: $e'; // Pas de clé spécifique dans l'API
      });
    }
  }

  /// Charger les articles directement avec iProfile et iBasket (optimisé)
  Future<void> _loadArticlesDirectly(String iProfile, String iBasket) async {
    try {
      print('📦 Chargement des articles - iProfile: $iProfile, iBasket: ${iBasket.isEmpty ? "(vide)" : iBasket}');
      
      // ✅ Récupérer sPaysFav depuis le LocalStorage
      final profileData = await LocalStorageService.getProfile();
      final rawPaysFav = profileData?['sPaysFav']?.toString() ?? '';
      final sPaysFav = _normalizeCountriesString(rawPaysFav);
      final normalizedCountriesList = _normalizeCountriesList(
        _extractCountriesFromString(rawPaysFav),
      );
      if (normalizedCountriesList.isNotEmpty) {
        await LocalStorageService.saveSelectedCountries(normalizedCountriesList);
      }
      
      print('📞 Appel get-basket-list-article avec:');
      print('   - iProfile: $iProfile');
      print('   - iBasket: $iBasket (du LocalStorage)');
      print('   - sPaysFav: $sPaysFav');
      
      final articlesResponse = await _apiService.getBasketListArticle(
        iProfile: iProfile,
        iBasket: iBasket,     // ✅ Utiliser le iBasket du LocalStorage
        sAction: 'INIT',
        sPaysFav: sPaysFav,   // ✅ Passer sPaysFav
      );

      print('📦 articlesResponse: $articlesResponse');

      if (articlesResponse != null && articlesResponse['success'] == true) {
        // SNAL-Project retourne: { success: true, data: { pivotArray: [...], meta: { iBasket: "...", ... } } }
        // Mais les données de test retournent: { success: true, data: [...] }
        final responseData = articlesResponse['data'];
        
        // Vérifier si data est une List (données de test) ou un Map (données SNAL)
        if (responseData is List) {
          // Mode TEST : data est une List d'articles
          final articles = responseData;
          final articleCount = articles.length;
          
          // Convertir les articles en format pivotArray
          final pivotArray = articles.map((article) {
            return {
              'sCodeArticle': article['sCodeArticle'],
              'sDescr': article['sDescr'],
              'sDescription': article['sDescription'],
              'sPrix': article['sPrix'],
              'sPrixOptimal': article['sPrixOptimal'],
              'sPaysSelected': article['sPaysSelected'],
              'spaysSelected': article['spaysSelected'],
              'sPaysFav': article['sPaysFav'],
              'sImage': article['sImage'],
              'pivotArray': article['pivotArray'],
            };
          }).toList();
          
          setState(() {
            _wishlistData = {
              'pivotArray': pivotArray,
              'paysListe': articlesResponse['paysListe'] ?? [],
              'meta': {
                'iBestResultJirig': 0,
                'iTotalPriceArticleSelected': 0.0,
                'sResultatGainPerte': '0€',
              },
            };
            _selectedBasketName = 'Wishlist ($articleCount Art.)';
            _isLoading = false;
            _hasLoaded = true;
          });
          _refreshArticleNotifiers();
          print('✅ Articles de test chargés: $articleCount');
          return;
        } else if (responseData is Map<String, dynamic>) {
          // Mode SNAL : data est un Map avec pivotArray
          final data = responseData;
          final articleCount = (data['pivotArray'] as List?)?.length ?? 0;
          
          // Récupérer iBasket de la réponse (si non fourni initialement)
          final returnedIBasket = data['meta']?['iBasket']?.toString();
          if (returnedIBasket != null && returnedIBasket.isNotEmpty) {
            // Sauvegarder iBasket dans le LocalStorage pour les prochains chargements
            final profileData = await LocalStorageService.getProfile();
            await LocalStorageService.saveProfile({
              'iProfile': iProfile,
              'iBasket': returnedIBasket,
              'sPaysLangue': profileData?['sPaysLangue'] ?? '',
            });
            print('💾 iBasket sauvegardé: $returnedIBasket');
          }
          
          setState(() {
            // Stocker directement 'data' qui contient pivotArray et meta
            _wishlistData = data;
            _selectedBasketName = 'Wishlist ($articleCount Art.)';
            _isLoading = false;
            _hasLoaded = true; // Marquer comme chargé
          });
          _refreshArticleNotifiers();
          print('✅ Articles chargés: $articleCount');
        } else {
          // Pas de données
          setState(() {
            _isLoading = false;
            _wishlistData = {
              'meta': {
                'iBestResultJirig': 0,
                'iTotalPriceArticleSelected': 0.0,
                'sResultatGainPerte': '0€',
              },
              'pivotArray': [],
            };
            _selectedBasketName = 'Wishlist (0 Art.)';
            _hasLoaded = true; // Marquer comme chargé même si vide
          });
          _refreshArticleNotifiers();
        }
      } else {
        setState(() {
          _isLoading = false;
          _wishlistData = {
            'meta': {
              'iBestResultJirig': 0,
              'iTotalPriceArticleSelected': 0.0,
              'sResultatGainPerte': '0€',
            },
            'pivotArray': [],
          };
          _selectedBasketName = 'Wishlist (0 Art.)';
          _hasLoaded = true; // Marquer comme chargé même si vide
        });
        _refreshArticleNotifiers();
      }
    } catch (e) {
      print('❌ Erreur _loadArticlesDirectly: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des articles: $e';
      });
    }
  }

  /// Ouvrir le modal de recherche pour ajouter un article (comme SNAL-Project)
  void _openAddArticleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchModal(),
    );
  }

  /// Rediriger vers le podium avec les infos de l'article (comme SNAL-Project)
  Future<void> _goToPodium(String sCodeArticle, String sCodeArticleCrypt, int iQuantite) async {
    try {
      print('🏆 Navigation vers podium: $sCodeArticle (crypt: $sCodeArticleCrypt) avec quantité: $iQuantite');
      
      // Récupérer iBasket depuis le LocalStorage (comme SNAL)
      final profileData = await LocalStorageService.getProfile();
      final iBasket = profileData?['iBasket']?.toString() ?? '';
      
      print('🛒 iBasket récupéré: $iBasket');
      
      // Construire l'URL avec les paramètres (comme SNAL-Project)
      // Le podium Flutter attend le code normal dans l'URL et le crypté en query param
      if (iBasket.isNotEmpty) {
        // Avec iBasket, crypt ET quantité dans les query params
        context.go('/podium/$sCodeArticle?crypt=$sCodeArticleCrypt&iBasket=$iBasket&iQuantite=$iQuantite');
      } else {
        // Sans iBasket mais avec crypt et quantité
        context.go('/podium/$sCodeArticle?crypt=$sCodeArticleCrypt&iQuantite=$iQuantite');
      }
    } catch (e) {
      print('❌ Erreur lors de la navigation vers le podium: $e');
      // Navigation de secours sans iBasket
      context.go('/podium/$sCodeArticle?crypt=$sCodeArticleCrypt');
    }
  }

  /// Afficher l'image en plein écran avec navigation
  void _showFullscreenImage(Map<String, dynamic> article) {
    // Collecter toutes les images disponibles pour cet article
    final List<String> imageUrls = [];
    
    // Image principale
    final mainImage = article['sImage']?.toString() ?? '';
    if (mainImage.isNotEmpty) {
      imageUrls.add(ApiConfig.getProxiedImageUrl(mainImage));
    }
    
    // Images des pays disponibles
    final pivotArray = article['pivotArray'] as List<dynamic>? ?? [];
    for (var country in pivotArray) {
      final countryImage = country['sImage']?.toString() ?? '';
      if (countryImage.isNotEmpty && !imageUrls.contains(ApiConfig.getProxiedImageUrl(countryImage))) {
        imageUrls.add(ApiConfig.getProxiedImageUrl(countryImage));
      }
    }
    
    if (imageUrls.isEmpty) {
      // Pas d'images disponibles
      return;
    }
    
    // Réinitialiser l'index à 0
    _currentImageIndex = 0;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) {},
              child: Stack(
                children: [
                  // Image centrée avec zoom et scroll
                  Center(
                    child: GestureDetector(
                      onTap: () {}, // Empêcher la fermeture quand on clique sur l'image
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        panEnabled: true,
                        boundaryMargin: const EdgeInsets.all(100),
                        child: Image.network(
                          imageUrls[_currentImageIndex],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported,
                              size: 100,
                              color: Colors.white,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Contrôles de navigation (toujours visibles)
                  // Bouton précédent
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: imageUrls.length > 1 ? SystemMouseCursors.click : SystemMouseCursors.basic,
                        child: GestureDetector(
                          onTap: imageUrls.length > 1 ? () {
                            setState(() {
                              _currentImageIndex = (_currentImageIndex - 1 + imageUrls.length) % imageUrls.length;
                            });
                          } : null,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: imageUrls.length > 1 ? Colors.black54 : Colors.black26,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              color: imageUrls.length > 1 ? Colors.white : Colors.white70,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Bouton suivant
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: imageUrls.length > 1 ? SystemMouseCursors.click : SystemMouseCursors.basic,
                        child: GestureDetector(
                          onTap: imageUrls.length > 1 ? () {
                            setState(() {
                              _currentImageIndex = (_currentImageIndex + 1) % imageUrls.length;
                            });
                          } : null,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: imageUrls.length > 1 ? Colors.black54 : Colors.black26,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: imageUrls.length > 1 ? Colors.white : Colors.white70,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Indicateur de position (toujours visible)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1} / ${imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Bouton fermer
                  Positioned(
                    top: 40,
                    right: 16,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Supprimer un article de la wishlist (comme SNAL-Project)
  Future<void> _deleteArticle(String sCodeArticleCrypt, String articleName) async {
    try {
      print('🗑️ Suppression de l\'article: $sCodeArticleCrypt ($articleName)');
      
      // Afficher une confirmation (comme SNAL avec Notiflix)
      final bool? confirmed = await _showNotiflixConfirmDialog(
        title: _translationService.translate('CONFIRM_TITLE'),
        message: _translationService.translate('CONFIRM_DELETE_ITEM') ?? "Voulez-vous vraiment supprimer cet article ?",
      );

      if (confirmed != true) {
        print('❌ Suppression annulée par l\'utilisateur');
        return;
      }

      // Appel API pour supprimer l'article
      print('🚀 Envoi de la requête de suppression...');
      print('📤 Paramètres envoyés: sCodeArticle = $sCodeArticleCrypt');
      
      final response = await _apiService.deleteArticleBasketWishlist(
        sCodeArticle: sCodeArticleCrypt,
      );

      print('📥 Réponse complète de l\'API:');
      print('📥 Type de réponse: ${response.runtimeType}');
      print('📥 Contenu de la réponse: $response');
      
      if (response != null) {
        print('📥 Clés disponibles dans la réponse: ${response.keys.toList()}');
        print('📥 Success: ${response['success']}');
        print('📥 Message: ${response['message']}');
        print('📥 ParsedData: ${response['parsedData']}');
        print('📥 Error: ${response['error']}');
        
        if (response['parsedData'] != null) {
          print('📥 ParsedData type: ${response['parsedData'].runtimeType}');
          if (response['parsedData'] is List) {
            print('📥 ParsedData length: ${response['parsedData'].length}');
            if (response['parsedData'].isNotEmpty) {
              print('📥 Premier élément parsedData: ${response['parsedData'][0]}');
              if (response['parsedData'][0] is Map) {
                print('📥 Clés du premier élément: ${response['parsedData'][0].keys.toList()}');
              }
            }
          }
        }
      }

      if (response != null && response['success'] == true) {
        print('✅ Article supprimé avec succès');
        
        // Mettre à jour les données locales IMMÉDIATEMENT (comme SNAL)
        await _updateDataAfterDeletion(response, sCodeArticleCrypt);
        
        // Afficher le message de succès (sans await pour ne pas bloquer l'UI)
        _showNotiflixSuccessDialog(
          title: _translationService.translate('SUCCESS_TITLE'),
          message: _translationService.translate('SUCCESS_DELETE_ARTICLE'),
        );
        
      } else {
        print('❌ Erreur lors de la suppression: ${response?['error'] ?? 'Erreur inconnue'}');
        print('❌ Détails de l\'erreur: ${response?['details'] ?? 'Aucun détail'}');
        print('❌ Stack trace: ${response?['stack'] ?? 'Aucun stack trace'}');
        
        // Afficher un message d'erreur style Notiflix
        await _showNotiflixErrorDialog(
          title: _translationService.translate('ERROR_TITLE'),
          message: _translationService.translate('DELETE_ERROR') ?? "Erreur lors de la suppression: ${response?['error'] ?? 'Erreur inconnue'}",
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      
      // Afficher un message d'erreur style Notiflix
      await _showNotiflixErrorDialog(
        title: _translationService.translate('ERROR_TITLE'),
        message: _translationService.translate('DELETE_ERROR') ?? "Une erreur s'est produite lors de la suppression: $e",
      );
    }
  }

  /// Afficher un modal de confirmation style Notiflix (comme SNAL-Project)
  Future<bool?> _showNotiflixConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent, // Fond transparent
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: const Color(0xFF0D6EFD).withOpacity(0.9), // Modal transparent avec opacité
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header avec titre
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    children: [
                      // Titre
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Message
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Boutons
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      // Bouton "Non" (gauche) - Bleu clair
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), // Augmentation du padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // Coins plus arrondis
                            ),
                            backgroundColor: const Color(0xFF4A90E2), // Bleu clair
                            foregroundColor: Colors.white,
                            elevation: 2, // Ajout d'une légère élévation
                          ),
                          child: Text(
                            _translationService.translate('BUTTON_NO'),
                            style: TextStyle(
                              fontSize: 18, // Augmentation de la taille de police
                              fontWeight: FontWeight.w700, // Police plus grasse
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Bouton "Oui" (droite) - Rouge
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), // Augmentation du padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // Coins plus arrondis
                            ),
                            backgroundColor: const Color(0xFFDC3545), // Rouge
                            foregroundColor: Colors.white,
                            elevation: 2, // Ajout d'une légère élévation
                          ),
                          child: Text(
                            _translationService.translate('BUTTON_YES'),
                            style: TextStyle(
                              fontSize: 18, // Augmentation de la taille de police
                              fontWeight: FontWeight.w700, // Police plus grasse
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Espacement vers le coin droit
                SizedBox(width: MediaQuery.of(context).size.width < 768 ? 4 : 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mettre à jour la quantité d'un article (comme SNAL)
  Future<void> _updateQuantity(String sCodeArticleCrypt, int newQuantity) async {
    try {
      print('📊 Mise à jour quantité: $sCodeArticleCrypt -> $newQuantity');
      
      // Appel API pour mettre à jour la quantité
      final response = await _apiService.updateQuantityArticleBasket(
        sCodeArticle: sCodeArticleCrypt,
        iQte: newQuantity,
      );
      
      print('📥 Réponse de l\'API: $response');
      
      if (response != null && response['success'] == true) {
        print('✅ Quantité mise à jour avec succès');
        
        // Mettre à jour les données locales (comme SNAL)
        await _updateDataAfterQuantityChange(response, sCodeArticleCrypt, newQuantity);
        
      } else {
        print('❌ Erreur lors de la mise à jour: ${response?['error'] ?? 'Erreur inconnue'}');
      }
    } catch (e) {
      print('❌ Erreur _updateQuantity: $e');
    }
  }

  /// Mettre à jour les données locales après modification de quantité (comme SNAL)
  Future<void> _updateDataAfterQuantityChange(Map<String, dynamic> response, String sCodeArticleCrypt, int newQuantity) async {
    try {
      print('🔄 Mise à jour des données après changement de quantité');
      
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        final List<dynamic> pivotArray = List<dynamic>.from(_wishlistData!['pivotArray']);
        
        // Trouver l'article et mettre à jour sa quantité localement
        final articleIndex = pivotArray.indexWhere(
          (item) => item['sCodeArticleCrypt'] == sCodeArticleCrypt || item['sCodeArticle'] == sCodeArticleCrypt
        );
        
        if (articleIndex != -1) {
          pivotArray[articleIndex]['iqte'] = newQuantity;
          print('✅ Quantité locale mise à jour pour l\'article: ${pivotArray[articleIndex]['sName']}');
        }
        
        // Mettre à jour les totaux depuis parsedData (comme SNAL)
        if (response['parsedData'] != null && response['parsedData'] is List) {
          final List<dynamic> parsedData = response['parsedData'];
          if (parsedData.isNotEmpty) {
            final Map<String, dynamic> totals = parsedData[0];
            
            final List<String> keysToUpdate = [
              'iBestResultJirig',
              'iQuantite',
              'iTotalPriceArticleSelected',
              'iTotalPriceSelected4PaysProfile',
              'iTotalQteArticle',
              'iTotalQteArticleSelected',
              'sResultatGainPerte',
              'iResultatGainPertePercentage',
              'sWarningGeneralInfo'
            ];
            
            for (final key in keysToUpdate) {
              if (totals[key] != null) {
                if (_wishlistData!['meta'] == null) {
                  _wishlistData!['meta'] = {};
                }
                if (_wishlistData!['meta'][key] != null) {
                  _wishlistData!['meta'][key] = totals[key];
                } else {
                  _wishlistData![key] = totals[key];
                }
              }
            }
            
            print('✅ Totaux mis à jour');
          }
        }
        
        _wishlistData!['pivotArray'] = pivotArray;
        setState(() {});
        _refreshArticleNotifiers();
        
        print('✅ Données mises à jour après changement de quantité');
      }
    } catch (e) {
      print('❌ Erreur _updateDataAfterQuantityChange: $e');
    }
  }

  /// Ouvrir le sidebar pour sélectionner le pays d'un article (comme SNAL avec updateDisplayChoice)
  void _openCountrySidebarForArticle(Map<String, dynamic> article, {String? defaultSelectedCountry, ValueNotifier<Map<String, dynamic>>? articleNotifier}) async {
    if (_isCountrySidebarOpen) {
      return; // Sidebar déjà ouvert/ouvrant
    }
    _isCountrySidebarOpen = true;
    print('🌍 Ouverture du sidebar de sélection de pays pour l\'article: ${article['sname']}');
    print('📝 Champs de description disponibles:');
    print('   sDescr: ${article['sDescr']}');
    print('   sDescription: ${article['sDescription']}');
    print('   description: ${article['description']}');
    print('   desc: ${article['desc']}');
    
    try {
      final currentSelectedCountry = (defaultSelectedCountry?.toString() ?? '').isNotEmpty
          ? defaultSelectedCountry!.toString()
          : (article['spaysSelected'] ?? article['sPaysSelected'] ?? '');
      
      // ✅ Utiliser l'endpoint get-infos-status pour récupérer tous les pays
      print('🚀 Appel de getInfosStatus() pour récupérer tous les pays...');
      Map<String, dynamic> infosStatus;
      try {
        infosStatus = await _apiService.getInfosStatus();
        
        // ✅ Stocker les données dans _wishlistData pour les réutiliser
        if (mounted) {
          setState(() {
            _wishlistData?['infosStatus'] = infosStatus;
          });
        }
        print('💾 Données get-infos-status stockées dans _wishlistData');
      } catch (e) {
        print('❌ Erreur lors de l\'appel getInfosStatus: $e');
        print('🔄 Utilisation du fallback avec les données de la wishlist');
        infosStatus = {'paysListe': _wishlistData?['paysListe'] ?? []};
      }
      
      print('🔍 Structure complète de la réponse getInfosStatus:');
      print('📦 infosStatus: $infosStatus');
      print('📦 Clés disponibles: ${infosStatus.keys.toList()}');
      
      // Extraire la liste des pays depuis la réponse
      final paysListe = infosStatus['paysListe'] as List? ?? [];
      print('📊 Données paysListe depuis get-infos-status: ${paysListe.length} pays trouvés');
      
      // Si paysListe est vide, essayer d'autres clés possibles
      List<dynamic> finalPaysListe = paysListe;
      if (paysListe.isEmpty) {
        print('⚠️ paysListe est vide, recherche d\'autres clés...');
        if (infosStatus['countries'] != null) {
          print('🔍 Clé "countries" trouvée: ${infosStatus['countries']}');
          finalPaysListe = infosStatus['countries'] as List? ?? [];
        }
        if (finalPaysListe.isEmpty && infosStatus['pays'] != null) {
          print('🔍 Clé "pays" trouvée: ${infosStatus['pays']}');
          finalPaysListe = infosStatus['pays'] as List? ?? [];
        }
        if (finalPaysListe.isEmpty && infosStatus['data'] != null) {
          print('🔍 Clé "data" trouvée: ${infosStatus['data']}');
          finalPaysListe = infosStatus['data'] as List? ?? [];
        }
        
        // Si toujours vide, utiliser les données de la wishlist comme fallback
        if (finalPaysListe.isEmpty) {
          print('🔄 Fallback: utilisation des données paysListe de la wishlist');
          finalPaysListe = _wishlistData?['paysListe'] as List? ?? [];
          print('📊 Fallback paysListe: ${finalPaysListe.length} pays trouvés');
        }
      }
      
      // Construire la liste des pays disponibles avec leurs prix pour CET article
      final List<Map<String, dynamic>> allCountries = [];
      
      for (final pays in finalPaysListe) {
        final code = pays['sPays']?.toString() ?? '';
        final name = pays['sDescr']?.toString() ?? code;
        final flag = pays['sFlag']?.toString() ?? '';
        
        print('🏴 Pays: $code, Nom: $name, Flag: $flag');
        
        // ✅ Exclure AT (Autriche) et CH (Suisse)
        if (code.isNotEmpty && code != 'AT' && code != 'CH') {
          // ✅ Récupérer le prix de CET article pour ce pays
          final priceStr = article[code]?.toString() ?? 'N/A';
          final price = _extractPriceFromString(priceStr);
          final isPriceAvailable = price > 0;
          
          // ✅ Corriger l'URL du drapeau (éviter le double https://jirig.be)
          String flagUrl = '';
          if (flag.isNotEmpty) {
            // Si le flag commence déjà par https://, l'utiliser tel quel
            if (flag.startsWith('https://')) {
              flagUrl = ApiConfig.getProxiedImageUrl(flag);
            } else {
              // Sinon, construire l'URL complète
              flagUrl = ApiConfig.getProxiedImageUrl('https://jirig.be$flag');
            }
          }
          
          print('🖼️ URL drapeau final: $flagUrl');
          print('💰 Prix pour $code: $priceStr (disponible: $isPriceAvailable)');
          
          allCountries.add({
            'code': code,
            'name': name.isNotEmpty ? name : code, // ✅ Fallback sur le code si nom manquant
            'flag': flagUrl, // ✅ URL avec proxy
            'price': priceStr, // ✅ Prix réel pour cet article
            'isAvailable': isPriceAvailable, // ✅ Indique si le prix est disponible
          });
        } else if (code == 'AT' || code == 'CH') {
          print('🚫 Pays exclu: $code (${code == 'AT' ? 'Autriche' : 'Suisse'})');
        }
      }
      
      print('✅ ${allCountries.length} pays préparés pour le modal depuis get-infos-status');
      
      print('🌍 Pays disponibles: ${allCountries.length}');
      print('🌍 Pays actuellement sélectionné: $currentSelectedCountry');
      
      // ✅ Créer un ValueNotifier pour l'article
      final effectiveNotifier = articleNotifier ?? _ensureArticleNotifier(article);

      // ✅ Utiliser showModalBottomSheet pour un vrai sidebar plein écran
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext modalContext) {
          return _CountrySidebarModal(
            articleNotifier: effectiveNotifier,
            availableCountries: allCountries,
            currentSelected: currentSelectedCountry,
            homeCountryCode: _getHomeCountryCode(article),
            onManageCountries: () {
              Navigator.of(modalContext).pop(); // Fermer le modal de sélection
              _openCountryManagementModal(); // Ouvrir le modal de gestion
            },
            onCountrySelected: (String countryCode) async {
              // Ne PAS fermer le modal - il restera ouvert et se mettra à jour
              await _changeArticleCountry(article, countryCode, effectiveNotifier);
            },
          );
        },
      ).whenComplete(() {
        _isCountrySidebarOpen = false;
      });
    } catch (e) {
      print('❌ Erreur dans _openCountrySidebarForArticle: $e');
      _isCountrySidebarOpen = false;
    }
  }

  /// Ouvrir le sidebar de gestion des pays (depuis le bouton flag en haut)
  void _openCountrySidebar() {
    print('🌍 Ouverture du sidebar de gestion des pays (depuis le header)');
    
    try {
      // Utiliser le premier article comme référence
      final articles = _wishlistData?['pivotArray'] as List? ?? [];
      if (articles.isNotEmpty) {
        final firstArticle = articles[0];
        if (firstArticle is Map) {
          final mapArticle = firstArticle as Map<String, dynamic>;
          final notifier = _ensureArticleNotifier(mapArticle);
          _openCountrySidebarForArticle(mapArticle, articleNotifier: notifier); // Appel asynchrone
        }
      }
    } catch (e) {
      print('❌ Erreur dans _openCountrySidebar: $e');
    }
  }


  /// Ouvrir/fermer la vue carte dans la même page
  void _toggleMapView() {
    setState(() {
      _showMap = !_showMap;
    });
  }

  /// Ouvrir le modal de gestion des pays (comme SNAL openModalCountryFromSlideover)
  void _openCountryManagementModal() async {
    print('🔧 Ouverture du modal de gestion des pays');
    
    // Toujours récupérer les données de tous les pays depuis get-infos-status
    print('🔄 Récupération des données get-infos-status...');
    try {
      final infosStatus = await _apiService.getInfosStatus();
      if (mounted) {
    setState(() {
          _wishlistData?['infosStatus'] = infosStatus;
        });
      }
      print('✅ Données get-infos-status récupérées et stockées');
    } catch (e) {
      print('❌ Erreur lors de la récupération get-infos-status: $e');
    }
    
    if (mounted) {
      // Récupérer les pays sélectionnés de manière asynchrone
      final selectedCountries = await _getCurrentSelectedCountries();
      final primaryCountryCode = await _getPrimaryCountryCode();
      if (primaryCountryCode != null && primaryCountryCode.isNotEmpty && !selectedCountries.contains(primaryCountryCode)) {
        selectedCountries.add(primaryCountryCode);
      }
      final uniqueSelectedCountries = selectedCountries.map((c) => c.toUpperCase()).toSet().toList();
      
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return _CountryManagementModal(
            availableCountries: _getAllAvailableCountries(),
            selectedCountries: uniqueSelectedCountries,
            lockedCountryCode: primaryCountryCode,
            onSave: _saveCountryChanges,
          );
        },
      );
    }
  }

  /// Obtenir tous les pays disponibles depuis l'API (toujours tous les pays)
  List<Map<String, dynamic>> _getAllAvailableCountries() {
    try {
      print('🔍 _getAllAvailableCountries - Recherche des pays...');
      
      // Essayer d'abord de récupérer depuis get-infos-status (tous les pays)
      final infosStatus = _wishlistData?['infosStatus'] as Map<String, dynamic>?;
      print('📦 infosStatus disponible: ${infosStatus != null}');
      
      if (infosStatus != null) {
        // L'API get-infos-status retourne PAYS (pas paysListe)
        final paysListe = infosStatus['PAYS'] as List? ?? [];
        final paysLangueListe = infosStatus['PaysLangue'] as List? ?? [];
        print('✅ Utilisation des pays depuis get-infos-status (PAYS)');
        print('📊 Pays depuis get-infos-status: ${paysListe.length} pays');
        print('📋 Détails: ${paysListe.map((p) => p['sExternalRef']).toList()}');
        
        // Créer un map des drapeaux depuis PaysLangue
        final flagMap = <String, String>{};
        for (final paysLangue in paysLangueListe) {
          final code = paysLangue['sPaysLangue']?.toString().split('/')[0] ?? '';
          final flag = paysLangue['sColor']?.toString() ?? '';
          if (code.isNotEmpty && flag.isNotEmpty) {
            flagMap[code] = flag;
          }
        }
        print('🏳️ Drapeaux trouvés: ${flagMap.keys.toList()}');
        
        return paysListe.map((pays) {
          final code = pays['sExternalRef']?.toString() ?? '';
          return {
            'code': code,
            'name': pays['sDescr']?.toString() ?? code,
            'flag': flagMap[code] ?? '', // Utiliser le drapeau depuis PaysLangue
          };
        }).where((country) => 
          (country['code']?.toString().isNotEmpty == true) && 
          country['code'] != 'AT' && 
          country['code'] != 'CH' // Exclure AT et CH comme avant
        ).toList();
      }
      
      // Fallback sur paysListe de la wishlist si get-infos-status n'est pas disponible
      final paysListe = _wishlistData?['paysListe'] as List? ?? [];
      print('⚠️ Fallback sur paysListe de la wishlist (${paysListe.length} pays)');
      print('📋 Détails: ${paysListe.map((p) => p['sPays']).toList()}');
      
      return paysListe.map((pays) => {
        'code': pays['sPays']?.toString() ?? '',
        'name': pays['sDescr']?.toString() ?? pays['sPays']?.toString() ?? '',
        'flag': pays['sFlag']?.toString() ?? '',
      }).where((country) => 
        (country['code']?.toString().isNotEmpty == true) && 
        country['code'] != 'AT' && 
        country['code'] != 'CH' // Exclure AT et CH comme avant
      ).toList();
    } catch (e) {
      print('❌ Erreur _getAllAvailableCountries: $e');
      return [];
    }
  }

  /// Récupérer le code du pays principal choisi pendant l'onboarding
  Future<String?> _getPrimaryCountryCode() async {
    try {
      final settingsService = SettingsService();
      final selectedCountry = settingsService.selectedCountry ?? await settingsService.getSelectedCountry();
      final code = selectedCountry?.sPays?.toString().toUpperCase();
      if (code != null && code.isNotEmpty) {
        return code;
      }
    } catch (e) {
      print('❌ Erreur _getPrimaryCountryCode: $e');
    }
    return null;
  }

  String? _getHomeCountryCode([Map<String, dynamic>? article]) {
    try {
      final articleHome = article?['sMyHomeIcon'] ?? article?['smyhomeicon'];
      if (articleHome is String && articleHome.isNotEmpty) {
        return articleHome.toUpperCase();
      }
      final meta = _wishlistData?['meta'];
      final metaHome = meta?['sMyHomeIcon'] ?? meta?['smyhomeicon'] ?? meta?['sPaysMyHome'];
      if (metaHome is String && metaHome.isNotEmpty) {
        return metaHome.toUpperCase();
      }
      final rootHome = _wishlistData?['sMyHomeIcon'] ?? _wishlistData?['smyhomeicon'];
      if (rootHome is String && rootHome.isNotEmpty) {
        return rootHome.toUpperCase();
      }
    } catch (e) {
      print('❌ Erreur _getHomeCountryCode: $e');
    }
    return null;
  }

  /// Obtenir les pays actuellement sélectionnés (ceux qui sont activés)
  List<String> _normalizeCountriesList(Iterable<dynamic> codes) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final code in codes) {
      final normalized = code?.toString().toUpperCase().trim() ?? '';
      if (normalized.length == 2 && !seen.contains(normalized)) {
        seen.add(normalized);
        ordered.add(normalized);
      }
    }
    return ordered;
  }

  List<String> _extractCountriesFromString(String raw) {
    if (raw.isEmpty) return [];
    final sanitized = raw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
    final parts = sanitized.split(',');
    return _normalizeCountriesList(parts);
  }

  String _normalizeCountriesString(String raw) {
    final codes = _extractCountriesFromString(raw);
    return codes.join(',');
  }

  Future<List<String>> _getCurrentSelectedCountries() async {
    try {
      // D'abord, essayer de récupérer depuis le localStorage (pays ajoutés via le modal)
      final savedCountries = await LocalStorageService.getSelectedCountries();
      final normalizedSaved = _normalizeCountriesList(savedCountries);
      if (normalizedSaved.isNotEmpty) {
        final primaryCountryCode = await _getPrimaryCountryCode();
        if (primaryCountryCode != null && !normalizedSaved.contains(primaryCountryCode)) {
          normalizedSaved.add(primaryCountryCode);
        }
        print('✅ Pays récupérés depuis localStorage: $normalizedSaved');
        if (normalizedSaved.isNotEmpty) {
          await LocalStorageService.saveSelectedCountries(normalizedSaved);
        }
        return normalizedSaved;
      }
      
      // Fallback: Récupérer les pays sélectionnés depuis les données de la wishlist
      // Ces pays sont ceux qui sont actuellement "activés" et affichés
      final pivotArray = _wishlistData?['pivotArray'] as List? ?? [];
      final selectedCountries = <String>{};
      
      // Parcourir tous les articles pour récupérer les pays sélectionnés
      for (final article in pivotArray) {
        final spaysSelected = article['spaysSelected']?.toString();
        if (spaysSelected != null && spaysSelected.isNotEmpty) {
          selectedCountries.add(spaysSelected.toUpperCase());
        }
      }
      
      // Convertir en liste et filtrer
      final countries = _normalizeCountriesList(
        selectedCountries
            .where((code) => code.isNotEmpty && code != 'AT' && code != 'CH'),
      );

      final primaryCountryCode = await _getPrimaryCountryCode();
      if (primaryCountryCode != null && primaryCountryCode.isNotEmpty && !countries.contains(primaryCountryCode)) {
        countries.add(primaryCountryCode);
      }
      
      // Sauvegarder ces pays dans localStorage pour la prochaine fois
      if (countries.isNotEmpty) {
        await LocalStorageService.saveSelectedCountries(countries);
      }
      
      return countries;
    } catch (e) {
      print('❌ Erreur _getCurrentSelectedCountries: $e');
      return [];
    }
  }

  /// Sauvegarder les changements de pays (comme SNAL updateBasketListPays)
  Future<void> _saveCountryChanges(List<String> selectedCountries) async {
    print('💾 Sauvegarde des changements de pays: $selectedCountries');
    
    try {
      final normalizedCountries = selectedCountries.map((c) => c.toUpperCase()).where((c) => c.isNotEmpty).toSet().toList();
      final primaryCountryCode = await _getPrimaryCountryCode();
      if (primaryCountryCode != null && primaryCountryCode.isNotEmpty && !normalizedCountries.contains(primaryCountryCode)) {
        normalizedCountries.add(primaryCountryCode);
      }
      
      // Sauvegarder les pays sélectionnés dans localStorage pour la persistance
      await LocalStorageService.saveSelectedCountries(normalizedCountries);
      await LocalStorageService.saveProfile({
        'sPaysFav': normalizedCountries.join(','),
      });
      
      final profileData = await LocalStorageService.getProfile();
      final iBasket = profileData?['iBasket']?.toString() ?? '';
      
      if (iBasket.isEmpty) {
        print('❌ iBasket manquant');
        return;
      }

      // Formater la liste des pays en string (FR,BE,NL,PT,DE,ES,IT)
      final sPaysListe = normalizedCountries.join(',');
      print('📤 Envoi de sPaysListe: $sPaysListe');
      
      // Appeler l'API pour sauvegarder les pays sélectionnés (comme SNAL)
      final response = await _apiService.updateCountryWishlistBasket(
        sPaysListe: sPaysListe,
      );
      
      if (response != null && response['success'] == true) {
        print('✅ Pays sauvegardés avec succès');
        
        // Recharger les données de la wishlist
        await _loadWishlistData(force: true);
      } else {
        print('❌ Erreur lors de la sauvegarde: ${response?['error']}');
      }
      
    } catch (e) {
      print('❌ Erreur _saveCountryChanges: $e');
    }
  }

  /// Changer le pays d'un article (comme SNAL avec updateDisplayChoice)
  Future<void> _changeArticleCountry(Map<String, dynamic> article, String countryCode, [ValueNotifier<Map<String, dynamic>>? articleNotifier]) async {
    try {
      final sCodeArticleCrypt = article['sCodeArticleCrypt'] ?? '';
      final currentSelected = article['spaysSelected'] ?? article['sPaysSelected'] ?? '';
      
      // Si on clique sur le pays déjà sélectionné, ne rien faire
      if (countryCode == currentSelected) {
        print('ℹ️ Pays déjà sélectionné: $countryCode');
        return;
      }
      
      print('🔄 Changement du pays pour l\'article: $currentSelected → $countryCode');
      print('🔄 Appel API updateCountrySelected (CHANGEPAYS):');

      // ✅ Optimistic UI update immédiat (avant l'appel API)
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        final pivotArray = _wishlistData!['pivotArray'] as List;
        final articleIndex = pivotArray.indexWhere(
          (item) => item['sCodeArticleCrypt'] == sCodeArticleCrypt
        );
        if (articleIndex != -1) {
          pivotArray[articleIndex]['spaysSelected'] = countryCode;
          pivotArray[articleIndex]['sPaysSelected'] = countryCode;
          pivotArray[articleIndex]['sPays'] = countryCode;
          if (articleNotifier != null) {
            articleNotifier.value = Map<String, dynamic>.from(pivotArray[articleIndex]);
          }
          if (mounted) setState(() {});
          print('⚡ UI mise à jour immédiatement (optimistic) avec pays: $countryCode');
          unawaited(_loadWishlistData(force: true));
        }
      }
      
      // ✅ Appeler l'API pour changer le pays (comme SNAL)
      final profileData = await LocalStorageService.getProfile();
      final iBasket = profileData?['iBasket']?.toString() ?? '';
      
      print('   iBasket: $iBasket');
      print('   sCodeArticle: $sCodeArticleCrypt');
      print('   sNewPaysSelected: $countryCode');
      
      // ✅ Appeler l'endpoint update-country-selected (comme SNAL ligne 4075)
      final response = await _apiService.updateCountrySelected(
        iBasket: iBasket,
        sCodeArticle: sCodeArticleCrypt,
        sNewPaysSelected: countryCode,
      );
      
      print('📡 Response reçue de update-country-selected:');
      print('   Type: ${response.runtimeType}');
      print('   Keys: ${response?.keys.toList()}');
      print('   Full response: $response');
      
      if (response != null && response['success'] == true) {
        print('✅ Pays changé avec succès');
        
        // ✅ Mettre à jour localement sans recharger (comme SNAL)
        if (response['parsedData'] != null && response['parsedData'] is List && response['parsedData'].isNotEmpty) {
          final totals = response['parsedData'][0];
          print('📊 Totals reçus: $totals');
          print('📊 sNewPaysSelected dans totals: ${totals['sNewPaysSelected']}');
          
          // Trouver l'article dans pivotArray et mettre à jour spaysSelected
          if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
            final pivotArray = _wishlistData!['pivotArray'] as List;
            final articleIndex = pivotArray.indexWhere(
              (item) => item['sCodeArticleCrypt'] == sCodeArticleCrypt
            );
            
            if (articleIndex != -1) {
              // ✅ Mettre à jour l'article avec le nouveau pays sélectionné (comme SNAL ligne 4090)
              final newSelected = totals['sNewPaysSelected']?.toString() ?? countryCode;
              pivotArray[articleIndex]['spaysSelected'] = newSelected;
              pivotArray[articleIndex]['sPaysSelected'] = newSelected;
              pivotArray[articleIndex]['sPays'] = newSelected;
              pivotArray[articleIndex]['sMyHomeIcon'] = totals['sMyHomeIcon'];
              pivotArray[articleIndex]['sPaysListe'] = totals['sPaysListe'];
              
              print('✅ Article mis à jour localement:');
              print('   Nouveau pays: ${pivotArray[articleIndex]['spaysSelected']}');
              print('   sMyHomeIcon: ${pivotArray[articleIndex]['sMyHomeIcon']}');
              
              // Mettre à jour les totaux (comme SNAL lignes 4097-4108)
              if (_wishlistData!['meta'] != null) {
                final meta = _wishlistData!['meta'];
                meta['iBestResultJirig'] = totals['iBestResultJirig'];
                meta['iTotalPriceArticleSelected'] = totals['iTotalPriceArticleSelected'];
                meta['sResultatGainPerte'] = totals['sResultatGainPerte'];
                meta['iResultatGainPertePercentage'] = totals['iResultatGainPertePercentage'];
                meta['iTotalQteArticleSelected'] = totals['iTotalQteArticleSelected'];
                print('✅ Totaux mis à jour dans meta');
              }
              
              // ✅ Mettre à jour le ValueNotifier AVANT le setState pour que le modal se mette à jour
              if (articleNotifier != null) {
                articleNotifier.value = Map<String, dynamic>.from(pivotArray[articleIndex]);
                print('✅ ValueNotifier mis à jour avec le nouvel article');
              }
              
              // ✅ Forcer la mise à jour de l'interface principale
              if (mounted) {
                setState(() {});
                print('✅ Interface principale mise à jour');
              }
            } else {
              print('❌ Article non trouvé dans pivotArray');
            }
          }
        } else {
          print('❌ parsedData manquant ou vide dans la réponse');
        }
      } else {
        print('❌ Erreur lors du changement de pays: success=${response?['success']}, error=${response?['error']}');
      }
    } catch (e, stackTrace) {
      print('❌ Erreur _changeArticleCountry: $e');
      print('❌ StackTrace: $stackTrace');
    }
  }

  /// Afficher un modal de succès style Notiflix avec animation (comme SNAL-Project)
  /// Auto-fermeture après 1.5 secondes
  Future<void> _showNotiflixSuccessDialog({
    required String title,
    required String message,
  }) async {
    // Afficher le modal
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        // Auto-fermeture après 1.5 secondes (comme SNAL)
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.of(dialogContext).pop();
          }
        });
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: _AnimatedSuccessModal(
            title: title,
            message: message,
          ),
        );
      },
    );
  }

  /// Afficher un modal d'erreur style Notiflix (comme SNAL-Project)
  Future<void> _showNotiflixErrorDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: const Color(0xFF0D6EFD), // Fond bleu principal
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header avec icône
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Icône d'erreur (style bleu)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Titre
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Message
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                
                // Bouton OK
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D6EFD),
                        elevation: 0,
                      ),
                      child: Text(
                        'OK', // Pas de clé spécifique dans l'API
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mettre à jour les données après suppression (comme SNAL-Project)
  Future<void> _updateDataAfterDeletion(Map<String, dynamic> response, String deletedCode) async {
    try {
      print('🔄 Mise à jour des données après suppression: $response');
      print('🗑️ Code à supprimer: $deletedCode');
      
      // Retirer l'article de la liste locale (pivotArray)
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        final List<dynamic> pivotArray = List<dynamic>.from(_wishlistData!['pivotArray']);
        
        print('📊 Articles avant suppression: ${pivotArray.length}');
        
        // Supprimer l'article correspondant (chercher par code crypté principalement)
        pivotArray.removeWhere((item) {
          final itemCode = item['sCodeArticle']?.toString() ?? '';
          final itemCryptCode = item['sCodeArticleCrypt']?.toString() ?? '';
          final shouldRemove = itemCryptCode == deletedCode || itemCode == deletedCode;
          
          if (shouldRemove) {
            print('✅ Article supprimé: $itemCode (crypt: $itemCryptCode)');
          }
          
          return shouldRemove;
        });
        
        print('📊 Articles après suppression: ${pivotArray.length}');
        
        // Mettre à jour les totaux depuis parsedData (comme SNAL)
        if (response['parsedData'] != null && response['parsedData'] is List) {
          final List<dynamic> parsedData = response['parsedData'];
          if (parsedData.isNotEmpty) {
            final Map<String, dynamic> totals = parsedData[0];
            
            // Mettre à jour les clés importantes dans meta
            final List<String> keysToUpdate = [
              'iBestResultJirig',
              'iTotalQteArticleSelected', 
              'iTotalPriceArticleSelected',
              'sResultatGainPerte',
              'sWarningGeneralInfo'
            ];
            
            for (final key in keysToUpdate) {
              if (totals[key] != null) {
                if (_wishlistData!['meta'] == null) {
                  _wishlistData!['meta'] = {};
                }
                _wishlistData!['meta'][key] = totals[key];
              }
            }
          }
        }
        
        // Mettre à jour pivotArray
        _wishlistData!['pivotArray'] = pivotArray;
        
        // Mettre à jour le nom du panier
        final articleCount = pivotArray.length;
        _selectedBasketName = 'Wishlist ($articleCount Art.)';
        
        // Rafraîchir l'interface
        setState(() {});
        
        print('✅ Données mises à jour après suppression');
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des données: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(context, listen: true);
    
    // Utilisation sécurisée de MediaQuery pour éviter les erreurs
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final isMobile = screenWidth < 768;

    // Si la carte est affichée, montrer seulement la carte
    if (_showMap) {
      return Scaffold(
        body: SimpleMapModal(
          isEmbedded: true,
          onClose: _toggleMapView,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(64),
        child: CustomAppBar(),
      ),
      body: Stack(
        children: [
          // Contenu principal (wishlist)
          _isLoading && !_hasLoaded
              ? _buildLoadingState(translationService)
              : _errorMessage.isNotEmpty
                  ? _buildErrorState(translationService)
                  : _buildWishlistView(translationService),
          
          // Indicateur de rechargement discret en haut
          if (_isLoading && _hasLoaded)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF0D6EFD)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 3),
    );
  }


  Widget _buildLoadingState(TranslationService translationService) {
    // OPTIMISATION: Loading plus discret - seulement si c'est le premier chargement
    if (!_hasLoaded) {
      // Premier chargement - loading complet
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingAnimationWidget.hexagonDots(
                color: const Color(0xFF0D6EFD),
                size: 60, // Taille réduite
              ),
              const SizedBox(height: 16),
              Text(
                translationService.translate('SCANCODE_Processing'),
                style: const TextStyle(
                  fontSize: 16, // Taille réduite
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Rechargement - garder le contenu et afficher un indicateur discret
      return _buildWishlistView(translationService);
    }
  }

  Widget _buildErrorState(TranslationService translationService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[600],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadWishlistData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(translationService.translate('RETRY') ?? 'Réessayer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistView(TranslationService translationService) {
    return RefreshIndicator(
      onRefresh: _loadWishlistData,
      color: const Color(0xFF0D6EFD),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildTopSection(translationService),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(TranslationService translationService) {
    final articles = _wishlistData?['pivotArray'] as List? ?? [];
    final isEmpty = articles.isEmpty;
    final meta = _wishlistData?['meta'] ?? {};
    final optimalPrice = _extractPriceFromString(meta['iBestResultJirig']?.toString() ?? '0');
    final currentPrice = _extractPriceFromString(meta['iTotalPriceArticleSelected']?.toString() ?? '0');

    // Variables responsive - Breakpoints optimisés pour tous les mobiles
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final isVerySmallMobile = screenWidth < 361;   // Galaxy Fold fermé, Galaxy S8+ (≤360px)
    final isSmallMobile = screenWidth < 431;       // iPhone XR/14 Pro Max, Pixel 7, Galaxy S20/A51 (361-430px)
    final isMobile = screenWidth < 768;            // Tous les mobiles standards (431-767px)
    final isTablet = screenWidth >= 768 && screenWidth < 1024; // Tablettes

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(height: isMobile ? 16 : 24),
          
          // Section avec dropdown et icônes
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Dropdown (affichage uniquement)
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? 200 : 250,
                    ),
                    height: isMobile ? 44 : 48,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCED4DA)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedBasketName ?? (_translationService.translate('WISHLIST_EMPTY') ?? 'Wishlist (0 Art.)'),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: const Color(0xFF212529),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: const Color(0xFF6C757D),
                          size: isMobile ? 20 : 24,
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(width: isMobile ? 12 : 200),
                
                // Trois boutons circulaires oranges avec animation Float
                _buildCircleButton(Icons.flag_outlined, const Color(0xFFf59e0b), onTap: _openCountryManagementModal, isMobile: isMobile, index: 0),
                SizedBox(width: isMobile ? 6 : 8),
                _buildCircleButton(
                  _showMap ? Icons.close : Icons.location_on, 
                  const Color(0xFFf59e0b), 
                  onTap: _toggleMapView,
                  isMobile: isMobile,
                  index: 1,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                _buildCircleButton(Icons.share, const Color(0xFFf59e0b), onTap: _shareProjetPdf, isMobile: isMobile, index: 2),
                
                // Espacement vers le coin droit
                SizedBox(width: isMobile ? 20 : 40),
              ],
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 20),
          
          // Section avec cartes et boutons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 32),
            child: Column(
              children: [
                // Ligne 1: Carte Optimal à gauche, Carte Actuel en haut à droite
                Row(
                  children: [
                    // Espacement depuis le coin gauche
                    SizedBox(width: isMobile ? 8 : 24),
                    // Carte Optimal avec animation cascade
                    _buildPriceBox(
                      label: 'Optimal',
                      price: optimalPrice,
                      color: const Color(0xFFf59e0b), // Amber-500 SNAL
                      icon: '🥇',
                      isMobile: isMobile,
                      cardIndex: 0,
                    ),
                    const Spacer(), // Pousse la carte Actuel vers la droite
                    // Carte Actuel en haut à droite avec animation cascade
                    _buildPriceBox(
                      label: 'Actuel',
                      price: currentPrice,
                      color: const Color(0xFF3b82f6), // Blue-500 SNAL
                      icon: '💰',
                      isMobile: isMobile,
                      cardIndex: 1,
                    ),
                    // Espacement vers le coin droit (augmenté)
                    SizedBox(width: isMobile ? 24 : 56),
                  ],
                ),
                
                if (!isEmpty) ...[
                  SizedBox(height: isMobile ? 12 : 16),
                  
                  // Ligne 2: Bouton Ajouter à gauche, Carte Bénéfice à droite
                  Row(
                    children: [
                      // Espacement depuis le coin gauche
                      SizedBox(width: isMobile ? 8 : 24),
                      // Bouton Ajouter
                      _buildAddButton(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
                      const Spacer(), // Pousse la carte Bénéfice vers la droite
                      // Carte Bénéfice
                      _buildCompactBenefitCard(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
                      // Espacement vers le coin droit
                      SizedBox(width: isMobile ? 12 : 24),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 20),
          
          // Contenu (vide ou articles)
          if (isEmpty)
            _buildEmptyContent(translationService)
          else
            _buildArticlesContent(translationService, articles, isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, {VoidCallback? onTap, bool isMobile = false, int index = 0}) {
    if (!_animationsInitialized) {
      // Fallback sans animation si pas initialisé
      return GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          width: isMobile ? 40 : 48,
          height: isMobile ? 40 : 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFf59e0b), // Amber-500
                Color(0xFFf97316), // Orange-500
                Color(0xFFef4444), // Red-500
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFf97316).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isMobile ? 28 : 32,
          ),
        ),
      );
    }
    
    // ✨ Animation Float : monte et descend légèrement (effet flottant)
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)), // Délai progressif
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // Sécurité : clamp opacity entre 0.0 et 1.0
        final safeOpacity = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, -10 * (1 - value)), // Descend depuis le haut
          child: Opacity(
            opacity: safeOpacity,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          width: isMobile ? 40 : 48,
          height: isMobile ? 40 : 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFf59e0b), // Amber-500
                Color(0xFFf97316), // Orange-500
                Color(0xFFef4444), // Red-500
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFf97316).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isMobile ? 28 : 32,
          ),
        ),
      ),
    );
  }

  /// ✅ Bouton Ajouter avec animation de respiration
  Widget _buildAddButton({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false}) {
    return _BreathingButton(
      onPressed: _openAddArticleModal,
      child: GestureDetector(
        onTap: _openAddArticleModal,
        child: Container(
          width: isMobile ? double.infinity : double.infinity, // Largeur complète sur mobile
          constraints: isMobile ? BoxConstraints(maxWidth: 140) : BoxConstraints(), // Limiter la largeur sur mobile
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : (isMobile ? 12 : 20)), // Largeur réduite
            vertical: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : (isMobile ? 14 : 12)), // Hauteur augmentée
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFf59e0b), // Amber-500
                Color(0xFFf97316), // Orange-500
                Color(0xFFef4444), // Red-500
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFf97316).withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle,
                size: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : (isMobile ? 20 : 20)), // Taille augmentée sur mobile
                color: Colors.white,
              ),
              SizedBox(width: isVerySmallMobile ? 2 : (isSmallMobile ? 3 : (isMobile ? 4 : 6))),
              Flexible(
                child: Text(
                  _translationService.translate('ADD_ITEM'),
                  style: TextStyle(
                    fontSize: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : (isMobile ? 14 : 15)), // Taille réduite pour éviter l'overflow
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Partage/Téléchargement du projet PDF (comme SNAL: GET /projet-download)
  Future<void> _shareProjetPdf() async {
    try {
      final profileData = await LocalStorageService.getProfile();
      
      print('📄 === PARTAGE PROJET PDF - DEBUG ===');
      print('📋 ProfileData complet: $profileData');
      print('📋 Clés disponibles: ${profileData?.keys.toList()}');
      
      final iBasket = profileData?['iBasket']?.toString() ?? '';
      final iProfile = profileData?['iProfile']?.toString() ?? '';
      
      print('📦 iBasket extrait: "$iBasket" (vide: ${iBasket.isEmpty})');
      print('👤 iProfile extrait: "$iProfile" (vide: ${iProfile.isEmpty})');
      
      // Vérifier le contenu du panier
      final articles = _wishlistData?['pivotArray'] as List? ?? [];
      print('📦 Nombre d\'articles dans le panier: ${articles.length}');
      if (articles.isNotEmpty) {
        print('📦 Premier article: ${articles[0]}');
        print('📦 Meta du panier: ${_wishlistData?['meta']}');
      }
      
      if (iBasket.isEmpty) {
        print('❌ Impossible de partager: iBasket manquant');
        _showErrorDialog('Impossible de partager', 'Votre panier est vide ou non disponible.');
        return;
      }
      
      if (articles.isEmpty) {
        print('❌ Impossible de partager: aucun article dans le panier');
        _showErrorDialog('Panier vide', 'Ajoutez au moins un article avant de générer le PDF.');
        return;
      }
      
      // ✅ Comme SNAL: Pas de vérification de connexion
      // Le serveur accepte les utilisateurs invités (guestProfile)
      // Il suffit d'avoir un iProfile et un iBasket
      final email = profileData?['sEmail']?.toString() ?? '';
      final isAnonymous = email.isEmpty;
      print('👤 Utilisateur anonyme: $isAnonymous');
      print('👤 Email: $email');

      // Afficher un indicateur de chargement comme SNAL
      _showLoadingDialog('Préparation du PDF...');

      // Appel API pour télécharger le PDF (conforme à SNAL)
      print('📱 Appel downloadProjetPdf avec iBasket: "$iBasket", iProfile: "$iProfile"');
      print('📱 Longueur iBasket: ${iBasket.length} caractères');
      print('📱 Longueur iProfile: ${iProfile.length} caractères');
      
      final response = await _apiService.downloadProjetPdf(iBasket: iBasket, iProfile: iProfile);
      
      // Fermer le dialog de chargement
      if (mounted) Navigator.of(context).pop();
      
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response headers: ${response.headers}');
      print('📄 PDF bytes reçus: ${response.data?.length ?? 0} bytes');
      
      if (response.statusCode != 200) {
        print('❌ Erreur serveur: ${response.statusCode}');
        print('❌ Response data: ${response.data}');
        
        // Essayer de parser le message d'erreur du serveur
        String serverMessage = 'Erreur serveur: ${response.statusCode}';
        if (response.data != null) {
          try {
            // Si c'est une erreur JSON
            if (response.data is Map) {
              serverMessage = response.data['message'] ?? response.data['statusMessage'] ?? serverMessage;
            } else if (response.data is String) {
              serverMessage = response.data;
            }
          } catch (e) {
            print('⚠️ Impossible de parser le message d\'erreur: $e');
          }
        }
        
        throw Exception(serverMessage);
      }
      
      final bytes = response.data as List<int>;
      
      if (bytes.isEmpty) {
        throw Exception('Le PDF généré est vide');
      }
      
      // Vérifier que c'est bien un PDF (comme SNAL)
      if (bytes.length < 4 || bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
        print('⚠️ Format de fichier invalide - signature PDF manquante');
        throw Exception('Format de fichier invalide');
      }
      
      print('✅ PDF valide (signature %PDF détectée)');
      
      if (kIsWeb) {
        // Web: télécharger le PDF via le navigateur (comme SNAL downloadFallback)
        try {
          WebUtils.downloadFile(bytes, 'SHARED_PDF_$iBasket.pdf');
          print('🌐 PDF téléchargé sur Web');
        } catch (e) {
          print('⚠️ Erreur téléchargement Web: $e');
          _showErrorDialog('Erreur de téléchargement', 'Impossible de télécharger le PDF. Veuillez réessayer.');
        }
      } else {
        // Mobile: créer un fichier temporaire et partager (comme SNAL)
        final tempDir = await getTemporaryDirectory();
        final fileName = 'SHARED_PDF_$iBasket.pdf';
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        print('📱 PDF enregistré: $filePath (${bytes.length} bytes)');

        try {
          // Partager via Share Plus (équivalent à navigator.share de SNAL)
          final result = await Share.shareXFiles(
            [XFile(filePath)],
            subject: 'Partage du projet Jirig',
            text: 'Voici le fichier PDF du projet',
          );
          
          print('📱 Résultat du partage: ${result.status}');
          
          if (result.status == ShareResultStatus.success) {
            print('✅ Partage réussi');
          } else if (result.status == ShareResultStatus.dismissed) {
            print('⚠️ Partage annulé par l\'utilisateur');
            // Ne pas afficher d'erreur, c'est normal (comme SNAL avec AbortError)
          }
        } catch (shareError) {
          print('❌ Erreur lors du partage: $shareError');
          // Fallback: proposer de télécharger le fichier
          _showErrorDialog(
            'Partage impossible',
            'Le partage a échoué. Le PDF a été enregistré dans vos fichiers temporaires: $fileName'
          );
        }
      }
    } catch (e, st) {
      print('❌ Erreur partage projet: $e\n$st');
      
      // Fermer le dialog de chargement si encore ouvert
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Gestion spécifique des erreurs (comme SNAL)
      String errorTitle = 'Erreur de partage';
      String errorMessage = 'Une erreur est survenue lors du partage.';
      
      if (e.toString().contains('500')) {
        errorTitle = 'Erreur serveur';
        errorMessage = 'Le serveur rencontre un problème. Veuillez réessayer plus tard.';
      } else if (e.toString().contains('404')) {
        errorTitle = 'Fichier non trouvé';
        errorMessage = 'Le projet PDF n\'a pas pu être généré.';
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        errorTitle = 'Accès refusé';
        errorMessage = 'Vous n\'avez pas les permissions pour partager ce projet.';
      } else if (e.toString().contains('Format de fichier invalide')) {
        errorTitle = 'Format invalide';
        errorMessage = 'Le fichier généré n\'est pas un PDF valide.';
      }
      
      _showErrorDialog(errorTitle, errorMessage);
    }
  }
  
  /// Afficher un dialog de chargement
  void _showLoadingDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  /// Afficher une boîte de dialogue d'erreur
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600]),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'), // Pas de clé spécifique dans l'API
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriceBox({
    required String label,
    required double price,
    required Color color,
    required String icon,
    bool isMobile = false,
    int cardIndex = 0,
  }) {
    // Couleurs SNAL exactes
    final isOptimal = label == 'Optimal';
    final isActuel = label == 'Actuel';
    
    // Couleurs selon SNAL
    final iconColor = isOptimal ? const Color(0xFFf59e0b) : const Color(0xFF3b82f6); // Amber-500 ou Blue-500
    final badgeColor = isOptimal ? const Color(0xFFf59e0b) : const Color(0xFF3b82f6);
    final textColor = isOptimal ? const Color(0xFFd97706) : const Color(0xFF2563eb); // Amber-600 ou Blue-600
    
    final String displayLabel = isOptimal
        ? _translationService.translate('OPTIMAL')
        : _translationService.translate('CURRENT');

    final cardWidget = Container(
      constraints: BoxConstraints(
        minWidth: isMobile ? 96 : 110,
        minHeight: isMobile ? 44 : 50,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFe2e8f0)), // slate-200
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Aligné à gauche
        children: [
          // Icône
          Text(
            icon,
            style: TextStyle(
              fontSize: isMobile ? 18 : 24,
            ),
          ),
          const SizedBox(width: 4),
          // Badge (variant="soft" comme SNAL)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1), // variant="soft"
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              displayLabel,
              style: TextStyle(
                color: badgeColor,
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Prix aligné à gauche (comme SNAL)
          Text(
            '${price.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
    
    if (!_animationsInitialized) {
      return cardWidget;
    }
    
    // ✨ Animation Cascade : Apparition en décalé avec slide depuis la gauche
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (cardIndex * 150)), // Délai progressif
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Sécurité : clamp opacity et scale
        final safeOpacity = value.clamp(0.0, 1.0);
        final safeScale = (0.9 + (0.1 * value)).clamp(0.5, 1.5);
        return Transform.translate(
          offset: Offset(-30 * (1 - value), 0), // Slide depuis la gauche
          child: Opacity(
            opacity: safeOpacity,
            child: Transform.scale(
              scale: safeScale, // Petit effet de scale
              child: child,
            ),
          ),
        );
      },
      child: cardWidget,
    );
  }

  Widget _buildCompactBenefitCard({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false}) {
    // ✅ Utiliser directement sResultatGainPerte de l'API (comme SNAL)
    final meta = _wishlistData?['meta'] ?? _wishlistData ?? {};
    final sResultatGainPerte = meta['sResultatGainPerte']?.toString() ?? '0€';

    final benefitWidget = Container(
      constraints: BoxConstraints(
        minWidth: isMobile ? 110 : 160,
        maxWidth: isMobile ? 160 : 260,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFe2e8f0), width: 2), // Bordure plus épaisse
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stack pour l'icône avec le point vert
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Image get-money.png dans un container rond bleu
              Container(
                width: isMobile ? 40 : 52,
                height: isMobile ? 40 : 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF3b82f6), // Blue-500
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/img/get-money.png',
                    width: isMobile ? 22 : 30,
                    height: isMobile ? 22 : 30,
                    fit: BoxFit.contain,
                    color: Colors.white,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: isMobile ? 18 : 24,
                      );
                    },
                  ),
                ),
              ),
              // Point vert en haut à droite
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10b981), // Vert
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(width: isMobile ? 8 : 12),
          
          // Colonne avec "Bénéfice" et montant poussée à droite (loose + FittedBox pour éviter les overflows)
          Flexible(
            fit: FlexFit.loose,
            child: Align(
              alignment: Alignment.topRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
              // Texte "Bénéfice" en badge vert clair, remonté vers la bordure haute
              Transform.translate(
                offset: Offset(0, isMobile ? -18 : -20),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10,
                    vertical: isMobile ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4), // Vert très clair
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _translationService.translate('PROFIT'),
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13, // Taille réduite
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10b981),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              SizedBox(height: 2),
              // Montant en bleu
              Transform.translate(
                offset: Offset(0, isMobile ? -6 : -8),
                child: Text(
                  sResultatGainPerte,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 24,
                    fontWeight: FontWeight.w800, // plus gras
                    color: const Color(0xFF2563eb), // Blue-600
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
              ),
            ),
          ),
        ],
      ),
    );
    
    if (!_animationsInitialized) {
      return benefitWidget;
    }
    
    // ✨ Animation Cascade : Apparition depuis la droite avec scale
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1100), // Plus tard dans la séquence
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // Sécurité : clamp opacity et scale
        final safeOpacity = value.clamp(0.0, 1.0);
        final safeScale = (0.85 + (0.15 * value)).clamp(0.5, 1.5);
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0), // Slide depuis la droite
          child: Opacity(
            opacity: safeOpacity,
            child: Transform.scale(
              scale: safeScale, // Effet de scale plus prononcé
              child: child,
            ),
          ),
        );
      },
      child: benefitWidget,
    );
  }

  Widget _buildEmptyContent(TranslationService translationService) {
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final isMobile = screenWidth < 768;
    final isSmallMobile = screenWidth < 431;
    final isVerySmallMobile = screenWidth < 361;
    
    return Column(
      children: [
        // Icône panier vide (gris clair)
        Icon(
          Icons.shopping_cart_outlined,
          size: 120,
          color: Colors.grey[300],
        ),
        
        const SizedBox(height: 24),
        
        // Texte "Panier vide"
        Text(
          translationService.translate('EMPTY_CART_TITLE'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212529),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Texte secondaire
        Text(
          translationService.translate('EMPTY_CART_MESSAGE'),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Bouton Ajouter en bas quand le panier est vide
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40),
          child: _buildAddButton(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }


  Widget _buildArticlesContent(TranslationService translationService, List articles, {bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isVerySmallMobile ? 6 : (isSmallMobile ? 8 : (isMobile ? 12 : 16))),
      child: Column(
        children: [
          // En-tête du tableau
          // _buildTableHeader(),
          SizedBox(height: isMobile ? 8 : 12),
          
          // Contenu du tableau avec animations
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: articles.length,
            separatorBuilder: (context, index) => SizedBox(height: isMobile ? 8 : 12),
            itemBuilder: (context, index) {
              final rawArticle = articles[index];
              if (rawArticle is! Map) {
                return const SizedBox.shrink();
              }
              final sourceArticle = rawArticle as Map<String, dynamic>;
              final notifier = _ensureArticleNotifier(sourceArticle);
              return ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: notifier,
                builder: (context, articleValue, _) {
                  final displayArticle = articleValue.isNotEmpty ? articleValue : Map<String, dynamic>.from(sourceArticle);
                  return _buildTableRow(
                    displayArticle,
                    translationService,
                    sourceArticle: sourceArticle,
                    articleNotifier: notifier,
                    isMobile: isMobile,
                    isSmallMobile: isSmallMobile,
                    isVerySmallMobile: isVerySmallMobile,
                    itemIndex: index,
                  );
                },
              );
            },
          ),
          
          SizedBox(height: isMobile ? 24 : 40),
        ],
      ),
    );
  }

  /// En-tête du tableau à 2 colonnes
  // Widget _buildTableHeader() {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFFF8F9FA),
  //       border: Border.all(color: const Color(0xFFDEE2E6)),
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     // child: Row(
  //     //   // children: [
  //     //   //   // Colonne gauche - Articles
  //     //   //   Expanded(
  //     //   //     flex: 3,
  //     //   //     child: Text(
  //     //   //       'Articles',
  //     //   //       style: const TextStyle(
  //     //   //         fontSize: 14,
  //     //   //         fontWeight: FontWeight.w600,
  //     //   //         color: Color(0xFF495057),
  //     //   //       ),
  //     //   //     ),
  //     //   //   ),
          
  //     //   //   // Colonne droite - Prix et Origine
  //     //   //   Expanded(
  //     //   //     flex: 2,
  //     //   //     child: Text(
  //     //   //       'Prix et Origine',
  //     //   //       style: const TextStyle(
  //     //   //         fontSize: 14,
  //     //   //         fontWeight: FontWeight.w600,
  //     //   //         color: Color(0xFF495057),
  //     //   //       ),
  //     //   //       textAlign: TextAlign.center,
  //     //   //     ),
  //     //   //   ),
  //     //   // ],
  //     // ),
  //   );
  // }

  /// Ligne du tableau à 2 colonnes
  Widget _buildTableRow(
    Map<String, dynamic> article,
    TranslationService translationService, {
    Map<String, dynamic>? sourceArticle,
    ValueNotifier<Map<String, dynamic>>? articleNotifier,
    bool isMobile = false,
    bool isSmallMobile = false,
    bool isVerySmallMobile = false,
    int itemIndex = 0,
  }) {
    final baseArticle = sourceArticle ?? article;
    final imageUrl = article['sImage'] ?? '';
    final name = article['sname'] ?? translationService.translate('PRODUCTCODE_Msg08');
    final code = article['scodearticle'] ?? '';
    final quantity = article['iqte'] ?? 1;
    final codeCrypt = article['sCodeArticleCrypt'] ?? '';
    final paysListe = _wishlistData?['paysListe'] as List? ?? [];

    final rowWidget = Container(
      padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 5 : (isMobile ? 10 : 12))),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9ECEF)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne gauche - Détails de l'article
          Expanded(
            flex: isVerySmallMobile ? 1 : (isSmallMobile ? 1 : (isMobile ? 2 : 3)),
            child: _buildLeftColumn(baseArticle, translationService, imageUrl, name, code, quantity, codeCrypt, isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
          ),
          
          SizedBox(width: isVerySmallMobile ? 2 : (isSmallMobile ? 3 : (isMobile ? 6 : 8))),
          
          // Colonne droite - Prix et pays
          Expanded(
            flex: isVerySmallMobile ? 1 : (isSmallMobile ? 1 : (isMobile ? 2 : 2)),
            child: _buildRightColumn(
              article,
              paysListe,
              sourceArticle: baseArticle,
              articleNotifier: articleNotifier,
              isMobile: isMobile,
              isSmallMobile: isSmallMobile,
              isVerySmallMobile: isVerySmallMobile,
            ),
          ),
        ],
      ),
    );
    
    if (!_animationsInitialized) {
      return rowWidget;
    }
    
    // ✨ Animation Articles : Slide in séquencé depuis le bas avec bounce
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (itemIndex * 100)), // Délai progressif (vague)
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack, // Bounce effect
      builder: (context, value, child) {
        // Sécurité : clamp opacity entre 0.0 et 1.0
        final safeOpacity = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)), // Slide depuis le bas
          child: Opacity(
            opacity: safeOpacity,
            child: child,
          ),
        );
      },
      child: rowWidget,
    );
  }

  /// Colonne gauche - Détails de l'article avec contrôles
  Widget _buildLeftColumn(Map<String, dynamic> article, TranslationService translationService, 
                         String imageUrl, String name, String code, int quantity, String codeCrypt, {bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image et nom du produit
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image du produit - Flexible pour éviter les débordements
            Flexible(
              flex: 0,
              child: MouseRegion(
                cursor: imageUrl.isNotEmpty ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: imageUrl.isNotEmpty ? () => _showFullscreenImage(article) : null,
                  child: Container(
                    width: isVerySmallMobile ? 50 : (isSmallMobile ? 55 : 70),
                    height: isVerySmallMobile ? 50 : (isSmallMobile ? 55 : 70),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              ApiConfig.getProxiedImageUrl(imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.image_not_supported,
                                  color: const Color(0xFF6C757D),
                                  size: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 28),
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.image_not_supported,
                            color: const Color(0xFF6C757D),
                            size: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 28),
                ),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: isVerySmallMobile ? 4 : (isSmallMobile ? 5 : 14)),
            
            // Nom et code du produit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: isVerySmallMobile ? 12 : (isSmallMobile ? 13 : 16),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212529),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isVerySmallMobile ? 0.5 : (isSmallMobile ? 1 : 4)),
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 14),
                      fontFamily: 'monospace',
                      color: const Color(0xFF6C757D),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: isVerySmallMobile ? 6 : (isSmallMobile ? 8 : 14)),
        
        // Contrôles (trophée, poubelle, quantité)
        Row(
          children: [
            // Bouton Podium - Flexible pour s'adapter
            Flexible(
              flex: 0,
              child: GestureDetector(
                onTap: () => _goToPodium(code, codeCrypt, quantity),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallMobile ? 4 : (isSmallMobile ? 5 : 10), 
                    vertical: isVerySmallMobile ? 4 : (isSmallMobile ? 5 : 8)
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F1FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF0D6EFD)),
                  ),
                  child: Icon(
                    Icons.emoji_events, 
                    size: isVerySmallMobile ? 14 : (isSmallMobile ? 16 : 20), 
                    color: const Color(0xFF0D6EFD)
                  ),
                ),
              ),
            ),
            
            SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 12 : 16)),
            
            // Bouton Supprimer - Flexible pour s'adapter
            Flexible(
              flex: 0,
              child: GestureDetector(
                onTap: () => _deleteArticle(codeCrypt, name),
                child: Container(
                  padding: EdgeInsets.all(isVerySmallMobile ? 4 : (isSmallMobile ? 5 : 8)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDC3545)),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: isVerySmallMobile ? 14 : (isSmallMobile ? 16 : 20),
                    color: const Color(0xFFDC3545),
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            // Contrôle quantité - Flexible pour s'adapter
            Flexible(
              flex: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton moins
                    GestureDetector(
                      onTap: quantity > 1 ? () => _updateQuantity(codeCrypt, quantity - 1) : null,
                      child: Container(
                        width: isVerySmallMobile ? 26 : (isSmallMobile ? 28 : 32),
                        height: isVerySmallMobile ? 26 : (isSmallMobile ? 28 : 32),
                        decoration: BoxDecoration(
                          color: quantity > 1 ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.remove,
                          size: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16),
                          color: quantity > 1 ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    // Zone du nombre
                    Container(
                      width: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 28),
                      height: isVerySmallMobile ? 26 : (isSmallMobile ? 28 : 32),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border.symmetric(
                          vertical: BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        '$quantity',
                        style: TextStyle(
                          fontSize: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 14),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    // Bouton plus
                    GestureDetector(
                      onTap: () => _updateQuantity(codeCrypt, quantity + 1),
                      child: Container(
                        width: isVerySmallMobile ? 26 : (isSmallMobile ? 28 : 32),
                        height: isVerySmallMobile ? 26 : (isSmallMobile ? 28 : 32),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          size: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16),
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Colonne droite - Prix et pays d'origine
  Widget _buildRightColumn(
    Map<String, dynamic> article,
    List paysListe, {
    Map<String, dynamic>? sourceArticle,
    ValueNotifier<Map<String, dynamic>>? articleNotifier,
    bool isMobile = false,
    bool isSmallMobile = false,
    bool isVerySmallMobile = false,
  }) {
    // ✅ Utiliser le pays sélectionné (spaysSelected avec minuscule - comme l'API le retourne)
    String? selectedCountry = article['spaysSelected'] ?? // ✅ Minuscule 's' (comme l'API)
                             article['sPaysSelected'] ??   // Fallback majuscule
                             article['sPays'] ?? 
                             article['sLangueIso'] ?? 
                             '';
    
    print('🔍 _buildRightColumn - Pays sélectionné: $selectedCountry');
    print('🔍 Article keys: ${article.keys.toList()}');
    print('🔍 spaysSelected: ${article['spaysSelected']}');
    print('🔍 sPaysSelected: ${article['sPaysSelected']}');
    
    double selectedPrice = 0.0;
    String? bestPriceCountry = '';
      double bestPrice = double.infinity;
    
    // Trouver le meilleur prix parmi tous les pays disponibles
      for (final pays in paysListe) {
        final sPays = pays['sPays'] ?? '';
        final priceStr = article[sPays]?.toString() ?? '';
        final price = _extractPriceFromString(priceStr);
        
        if (price > 0 && price < bestPrice) {
          bestPrice = price;
        bestPriceCountry = sPays;
      }
    }
    
    if (selectedCountry?.isNotEmpty ?? false) {
      final priceStr = article[selectedCountry]?.toString() ?? '';
      selectedPrice = _extractPriceFromString(priceStr);
      print('🔍 Prix trouvé pour $selectedCountry: $selectedPrice');
    }
    
    // Si pas de prix trouvé pour le pays sélectionné, utiliser le meilleur prix
    if (selectedPrice <= 0 && (bestPriceCountry?.isNotEmpty ?? false)) {
      print('⚠️ Pas de prix trouvé pour le pays sélectionné, utilisation du meilleur prix...');
      selectedCountry = bestPriceCountry;
      selectedPrice = bestPrice;
      print('🔍 Meilleur prix utilisé: $selectedPrice pour $selectedCountry');
    }
    
    if (selectedCountry != null && selectedCountry!.isNotEmpty && paysListe.isNotEmpty) {
      final pays = paysListe.firstWhere(
        (p) => p['sPays'] == selectedCountry,
        orElse: () => paysListe.first,
      );
      
      final sDescr = pays['sDescr'] ?? selectedCountry;
      final sFlag = pays['sFlag'] ?? '';
      
      // Vérifier si ce pays a le meilleur prix
      final isBestPrice = selectedCountry == bestPriceCountry;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pays et drapeau avec médaille si c'est le meilleur prix (Wrap pour éviter overflow)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              if (isBestPrice) ...[
                // Médaille pour le meilleur prix (comme dans Optimal)
                const Text(
                  '🥇',
                  style: TextStyle(fontSize: 20),
                ),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? 120 : 140),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _openCountrySidebarForArticle(
                      sourceArticle ?? article,
                      defaultSelectedCountry: selectedCountry ?? '',
                      articleNotifier: articleNotifier,
                    ),
                    child: Text(
                      sDescr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF212529),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ),
              if (sFlag.isNotEmpty)
                Text(
                  _getFlagEmoji(sFlag),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.0,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Prix principal (tap ouvre le sidebar pays pour cet article)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openCountrySidebarForArticle(
                sourceArticle ?? article,
                defaultSelectedCountry: selectedCountry ?? '',
                articleNotifier: articleNotifier,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55F), // Vert #22C55F
                  borderRadius: BorderRadius.circular(20), // Forme de capsule
                ),
                child: Text(
                  '${selectedPrice.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Autres drapeaux + bouton + (Wrap pour éviter overflow)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: isMobile ? 4 : 6,
            runSpacing: 2,
            children: [
              // Drapeaux fixes (Allemagne, Belgique, Espagne) - Responsive
              ...['DE', 'BE', 'ES'].map((countryCode) {
                print('🏴 Affichage drapeau $countryCode - Mobile: $isMobile');
                // Récupérer IsInBasket depuis l'article
                final IsInBasket = article['IsInBasket']?.toString().toUpperCase() ?? '';
                // Vérifier si ce pays correspond à IsInBasket
                final isInBasketCountry = IsInBasket.isNotEmpty && 
                    (countryCode.toUpperCase() == IsInBasket || 
                     countryCode.toUpperCase().contains(IsInBasket) || 
                     IsInBasket.contains(countryCode.toUpperCase()));
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                  margin: EdgeInsets.only(right: isMobile ? 4 : 6),
                  width: isMobile ? 20 : 24,
                  height: isMobile ? 15 : 18,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(
                      ApiConfig.getProxiedImageUrl('https://jirig.be/img/flags/' + countryCode + '.PNG'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ Erreur chargement drapeau ' + countryCode + ': ' + error.toString());
                        return Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.flag,
                            size: isMobile ? 10 : 12,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                    ),
                    // Icône panier si ce pays correspond à IsInBasket
                    if (isInBasketCountry)
                      Container(
                        margin: const EdgeInsets.only(left: 2),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.blue[400],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shopping_cart,
                          size: isMobile ? 10 : 12,
                          color: Colors.white,
                        ),
                      ),
                  ],
                );
              }).toList(),
              
              // Bouton + bleu (ouvre le sidebar de sélection de pays pour cet article)
              GestureDetector(
                onTap: () => _openCountrySidebarForArticle(
                  article,
                  defaultSelectedCountry: selectedCountry ?? '',
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF007BFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildArticleCard(Map<String, dynamic> article, TranslationService translationService) {
    final imageUrl = article['sImage'] ?? '';
    final name = article['sname'] ?? translationService.translate('PRODUCTCODE_Msg08');
    final code = article['scodearticle'] ?? '';
    final quantity = article['iqte'] ?? 1;
    final codeCrypt = article['sCodeArticleCrypt'] ?? '';
    final paysListe = _wishlistData?['paysListe'] as List? ?? [];
    
    // Utilisation sécurisée de MediaQuery pour éviter les erreurs
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final isMobile = screenWidth < 768;
    final isSmallMobile = screenWidth < 400;
    
    // ✅ Debug: Afficher la structure de l'article pour comprendre le pays sélectionné
    print('🔍 DEBUG Article structure:');
    print('   Clés disponibles: ${article.keys.toList()}');
    print('   sPays: ${article['sPays']}');
    print('   sLangueIso: ${article['sLangueIso']}');
    print('   iPaysSelected: ${article['iPaysSelected']}');
    print('   sPaysSelected: ${article['sPaysSelected']}');

    return Container(
      padding: EdgeInsets.all(isMobile ? 4 : 5), // Responsive padding
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9ECEF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Layout mobile optimisé : Image + Infos + Prix principal
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image plus grande pour mobile (cliquable avec curseur pointer)
              MouseRegion(
                cursor: imageUrl.isNotEmpty ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: imageUrl.isNotEmpty ? () => _showFullscreenImage(article) : null,
                  child: Container(
                    width: isMobile ? 70 : 80,
                    height: isMobile ? 70 : 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ApiConfig.getProxiedImageUrl(imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.image_not_supported,
                                  color: Color(0xFF6C757D),
                                  size: isMobile ? 28 : 32,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.image_not_supported,
                            color: Color(0xFF6C757D),
                            size: isMobile ? 28 : 32,
                          ),
                  ),
                ),
              ),
              
              SizedBox(width: isMobile ? 6 : 8), // Responsive spacing
              
              // Infos produit + Prix principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom du produit
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212529),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isMobile ? 1 : 2), // Responsive spacing
                    
                    // ✅ Code produit + Pays + Prix sur la même ligne
                    if (isMobile) 
                      // Layout mobile : code et prix empilés
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Code produit
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 6 : 8,
                              vertical: isMobile ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFDEE2E6)),
                            ),
                            child: Text(
                              code,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
                                fontFamily: 'monospace',
                                color: Color(0xFF495057),
                              ),
                            ),
                          ),
                          SizedBox(height: isMobile ? 4 : 6),
                          // Prix principal avec pays
                          _buildMainPriceSection(article, paysListe),
                        ],
                      )
                    else
                      // Layout desktop : code et prix côte à côte (utiliser Wrap pour éviter l'overflow)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: isMobile ? 8 : 12,
                        runSpacing: 4,
                        children: [
                          // Code produit
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 6 : 8,
                              vertical: isMobile ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFDEE2E6)),
                            ),
                            child: Text(
                              code,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
                                fontFamily: 'monospace',
                                color: Color(0xFF495057),
                              ),
                            ),
                          ),
                          
                          // Prix principal avec pays (en face du code)
                          _buildMainPriceSection(article, paysListe),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: isMobile ? 4 : 6), // Responsive spacing
          
          // ✅ Actions et contrôles en une ligne compacte
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Actions principales
              Row(
                children: [
                  // Bouton Podium
                  GestureDetector(
                    onTap: () => _goToPodium(code, codeCrypt, quantity),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 6 : 8,
                        vertical: isMobile ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F1FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0D6EFD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events, 
                            size: isMobile ? 12 : 14, 
                            color: Color(0xFF0D6EFD),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(width: isMobile ? 12 : 16),
                  
                  // Bouton Supprimer
                  GestureDetector(
                    onTap: () => _deleteArticle(codeCrypt, name),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 4 : 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDC3545)),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: isMobile ? 14 : 16,
                        color: Color(0xFFDC3545),
                      ),
                    ),
                  ),
                ],
              ),
              
              // ✅ Contrôle quantité compact
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDEE2E6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: quantity > 1 ? () => _updateQuantity(codeCrypt, quantity - 1) : null,
                      child: Container(
                        width: isMobile ? 24 : 28,
                        height: isMobile ? 24 : 28,
                        decoration: BoxDecoration(
                          color: quantity > 1 ? const Color(0xFFE9ECEF) : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                          ),
                        ),
                        child: Icon(
                          Icons.remove,
                          size: isMobile ? 12 : 14,
                          color: quantity > 1 ? const Color(0xFF495057) : const Color(0xFFADB5BD),
                        ),
                      ),
                    ),
                    Container(
                      width: isMobile ? 24 : 28,
                      height: isMobile ? 24 : 28,
                      alignment: Alignment.center,
                      child: Text(
                        '$quantity',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _updateQuantity(codeCrypt, quantity + 1),
                      child: Container(
                        width: isMobile ? 24 : 28,
                        height: isMobile ? 24 : 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE9ECEF),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          size: isMobile ? 12 : 14,
                          color: Color(0xFF495057),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ✅ Section prix principal avec pays (style de l'image fournie)
  Widget _buildMainPriceSection(Map<String, dynamic> article, List paysListe) {
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final isMobile = screenWidth < 768;
    // ✅ Utiliser le pays sélectionné (spaysSelected avec minuscule - comme l'API le retourne)
    String? selectedCountry;
    double selectedPrice = 0.0;
    String? bestPriceCountry = '';
    double bestPrice = double.infinity;
    
    // Trouver le meilleur prix parmi tous les pays disponibles
    for (final pays in paysListe) {
      final sPays = pays['sPays'] ?? '';
      final priceStr = article[sPays]?.toString() ?? '';
      final price = _extractPriceFromString(priceStr);
      
      if (price > 0 && price < bestPrice) {
        bestPrice = price;
        bestPriceCountry = sPays;
      }
    }
    
    // Essayer différentes clés pour identifier le pays sélectionné
    selectedCountry = article['spaysSelected'] ?? // ✅ Minuscule 's' (comme l'API)
                     article['sPaysSelected'] ??   // Fallback majuscule
                     article['sPays'] ?? 
                     article['sLangueIso'] ?? 
                     '';
    
    print('🔍 _buildMainPriceSection - Pays sélectionné: $selectedCountry');
    
    // Si aucun pays spécifique trouvé, utiliser le premier pays disponible
    if ((selectedCountry?.isEmpty ?? true) && paysListe.isNotEmpty) {
      selectedCountry = paysListe.first['sPays'] ?? '';
      print('⚠️ Aucun pays sélectionné, utilisation du premier: $selectedCountry');
    }
    
    // Trouver le prix correspondant au pays sélectionné
    if (selectedCountry?.isNotEmpty ?? false) {
      final priceStr = article[selectedCountry]?.toString() ?? '';
      selectedPrice = _extractPriceFromString(priceStr);
      print('🔍 Prix trouvé pour $selectedCountry: $selectedPrice');
      
      // Si pas de prix trouvé pour ce pays, utiliser le meilleur prix
      if (selectedPrice <= 0 && (bestPriceCountry?.isNotEmpty ?? false)) {
        print('⚠️ Pas de prix pour le pays sélectionné, utilisation du meilleur prix...');
        selectedCountry = bestPriceCountry;
        selectedPrice = bestPrice;
        print('🔍 Meilleur prix utilisé: $selectedPrice pour $selectedCountry');
      }
    }
    
    if (selectedCountry != null && selectedCountry!.isNotEmpty && paysListe.isNotEmpty) {
      final pays = paysListe.firstWhere(
        (p) => p['sPays'] == selectedCountry,
        orElse: () => paysListe.first,
      );
      
      final sDescr = pays['sDescr'] ?? selectedCountry;
      final sFlag = pays['sFlag'] ?? '';
      
      // Vérifier si ce pays a le meilleur prix
      final isBestPrice = selectedCountry == bestPriceCountry;
      
      // Pays fixes pour les drapeaux (Allemagne, Belgique, Espagne)
      final fixedCountries = [
        {'sPays': 'DE', 'sFlag': '/img/flags/DE.PNG', 'sDescr': 'Allemagne'},
        {'sPays': 'BE', 'sFlag': '/img/flags/BE.PNG', 'sDescr': 'Belgique'},
        {'sPays': 'ES', 'sFlag': '/img/flags/ES.PNG', 'sDescr': 'Espagne'},
      ];
      
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom du pays et drapeau (Wrap pour éviter les overflows sur petits écrans)
          Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              if (isBestPrice) ...[
                // Médaille pour le meilleur prix (comme dans Optimal)
                const Text(
                  '🥇',
                  style: TextStyle(fontSize: 20),
                ),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  sDescr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212529),
                  ),
                ),
              ),
              if (sFlag.isNotEmpty)
                Text(
                  _getFlagEmoji(sFlag),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.0,
                  ),
                ),
              // Icône panier si le pays sélectionné correspond à IsInBasket
              Builder(
                builder: (context) {
                  // Récupérer IsInBasket depuis l'article
                  final IsInBasket = article['IsInBasket']?.toString().toUpperCase() ?? '';
                  // Vérifier si le pays sélectionné correspond à IsInBasket
                  final isInBasketCountry = IsInBasket.isNotEmpty && 
                      selectedCountry != null &&
                      (selectedCountry!.toUpperCase() == IsInBasket || 
                       selectedCountry!.toUpperCase().contains(IsInBasket) || 
                       IsInBasket.contains(selectedCountry!.toUpperCase()));
                  
                  if (isInBasketCountry) {
                    return Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue[400],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        size: 12,
                        color: Colors.white,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Prix en badge vert (taille augmentée)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55F), // Vert #22C55F
              borderRadius: BorderRadius.circular(20), // Forme de capsule
            ),
            child: Text(
              '${selectedPrice.toStringAsFixed(2)} €',
              style: const TextStyle(
                fontSize: 14, // Taille augmentée
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Autres drapeaux + bouton + (Wrap pour éviter overflow)
          Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              // Drapeaux des pays fixes (Allemagne, Belgique, Espagne)
              ...fixedCountries.map((pays) {
                final flag = pays['sFlag'] ?? '';
                final countryCode = (pays['sPays'] ?? '').toString().toUpperCase();
                // Récupérer IsInBasket depuis l'article
                final IsInBasket = article['IsInBasket']?.toString().toUpperCase() ?? '';
                // Vérifier si ce pays correspond à IsInBasket
                final isInBasketCountry = IsInBasket.isNotEmpty && 
                    (countryCode == IsInBasket || 
                     countryCode.contains(IsInBasket) || 
                     IsInBasket.contains(countryCode));
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: isMobile ? 20 : 24,
                  height: isMobile ? 15 : 18,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(
                          ApiConfig.getProxiedImageUrl('https://jirig.be/img/flags/$countryCode.PNG'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.flag,
                            size: 12,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                    ),
                    // Icône panier si ce pays correspond à IsInBasket
                    if (isInBasketCountry)
                      Container(
                        margin: const EdgeInsets.only(left: 2),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.blue[400],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shopping_cart,
                          size: isMobile ? 10 : 12,
                          color: Colors.white,
                        ),
                      ),
                  ],
                );
              }).toList(),
              
              // Bouton + bleu (ouvre le sidebar de sélection de pays pour cet article)
              GestureDetector(
                onTap: () => _openCountrySidebarForArticle(
                  article,
                  defaultSelectedCountry: selectedCountry ?? '',
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF007BFF), // Bleu comme dans l'image
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      );
    }
    
    return const SizedBox.shrink();
  }

  /// ✅ Convertir le chemin du drapeau en emoji
  String _getFlagEmoji(String flagPath) {
    final flagMap = {
      '/img/flags/FR.PNG': '🇫🇷',
      '/img/flags/BE.PNG': '🇧🇪',
      '/img/flags/NL.PNG': '🇳🇱',
      '/img/flags/DE.PNG': '🇩🇪',
      '/img/flags/ES.PNG': '🇪🇸', // Garder l'emoji mais on va l'ajuster dans le widget
      '/img/flags/IT.PNG': '🇮🇹',
      '/img/flags/PT.PNG': '🇵🇹',
      '/img/flags/AT.PNG': '🇦🇹',
      '/img/flags/CH.PNG': '🇨🇭',
    };
    return flagMap[flagPath] ?? '🏳️';
  }

  /// ✅ Widget pour afficher un drapeau avec alignement parfait
  Widget _buildFlagWidget(String flagPath) {
    final isSpain = flagPath.contains('/ES.PNG');
    
    // Pour l'Espagne, utiliser une image au lieu de l'emoji
    if (isSpain) {
      return Container(
        height: 16,
        width: 20,
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.network(
            ApiConfig.getProxiedImageUrl('https://jirig.be$flagPath'),
            height: 16,
            width: 20,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback vers l'emoji si l'image ne charge pas
              return Text(
                _getFlagEmoji(flagPath),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      );
    }
    
    // Pour les autres pays, utiliser l'emoji
    return Container(
      height: 16,
      width: 20,
      alignment: Alignment.center,
      child: Text(
        _getFlagEmoji(flagPath),
        style: const TextStyle(
          fontSize: 14,
          height: 1.0,
          textBaseline: TextBaseline.alphabetic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// ✅ Extraire un prix depuis une chaîne (ex: "9.99 €" -> 9.99)
  double _extractPriceFromString(String priceString) {
    // ✅ Nettoyer la chaîne de prix (enlever €, espaces, etc.)
    final cleanedPrice = priceString
        .replaceAll('€', '')           // Enlever €
        .replaceAll(' ', '')           // Enlever espaces
        .replaceAll(',', '.')          // Remplacer virgule par point
        .trim();
    
    // ✅ Extraire uniquement les chiffres et le point décimal
    final match = RegExp(r'\d+\.?\d*').firstMatch(cleanedPrice);
    if (match != null) {
      return double.tryParse(match.group(0)!) ?? 0.0;
    }
    return 0.0;
  }

}

/// Widget de modal de succès animé avec check (style Notiflix Report.success)
class _AnimatedSuccessModal extends StatefulWidget {
  final String title;
  final String message;
  
  const _AnimatedSuccessModal({
    Key? key,
    required this.title,
    required this.message,
  }) : super(key: key);
  
  @override
  State<_AnimatedSuccessModal> createState() => _AnimatedSuccessModalState();
}

class _AnimatedSuccessModalState extends State<_AnimatedSuccessModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    
    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    
    // Démarrer l'animation immédiatement
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
        color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 15),
            ),
          ],
        ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
            const SizedBox(height: 32),
            
            // Icône de succès avec animation de check
            Stack(
              alignment: Alignment.center,
              children: [
                // Cercle extérieur
              Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                // Check animé
                ScaleTransition(
                  scale: _checkAnimation,
                  child: const Icon(
                    Icons.check,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Titre
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Widget modal pour la sélection du pays (style sidebar plein écran)
class _CountrySidebarModal extends StatefulWidget {
  final ValueNotifier<Map<String, dynamic>> articleNotifier;
  final List<Map<String, dynamic>> availableCountries;
  final String currentSelected;
  final String? homeCountryCode;
  final Function(String) onCountrySelected;
  final VoidCallback onManageCountries;

  const _CountrySidebarModal({
    Key? key,
    required this.articleNotifier,
    required this.availableCountries,
    required this.currentSelected,
    required this.homeCountryCode,
    required this.onManageCountries,
    required this.onCountrySelected,
  }) : super(key: key);

  @override
  State<_CountrySidebarModal> createState() => _CountrySidebarModalState();
}

class _CountrySidebarModalState extends State<_CountrySidebarModal> with SingleTickerProviderStateMixin {
  late String _selectedCountry;
  late Map<String, dynamic> _currentArticle;
  bool _isChanging = false;
  late String _initialHomeCountryCode;
  
  // ✨ Animations
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.currentSelected;
    _currentArticle = widget.articleNotifier.value;
    _initialHomeCountryCode = (widget.homeCountryCode ?? '').toUpperCase();
    widget.articleNotifier.addListener(_onArticleNotifierChanged);
    
    // ✨ Initialiser animation du sidebar (slide depuis la droite)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Depuis la droite
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    // Démarrer l'animation
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  void _onArticleNotifierChanged() {
    if (mounted) {
      setState(() {
        _currentArticle = widget.articleNotifier.value;
        // Mettre à jour le pays sélectionné si l'article a changé
        final newSelectedCountry = _currentArticle['spaysSelected']?.toString() ?? '';
        if (newSelectedCountry.isNotEmpty && newSelectedCountry != _selectedCountry) {
          _selectedCountry = newSelectedCountry;
        }
      });
    }
  }

  String _resolveHomeCountryCode() {
    final articleHome = _currentArticle['sMyHomeIcon'] ?? _currentArticle['smyhomeicon'];
    if (articleHome is String && articleHome.isNotEmpty) {
      return articleHome.toUpperCase();
    }
    return _initialHomeCountryCode;
  }

  @override
  void dispose() {
    widget.articleNotifier.removeListener(_onArticleNotifierChanged);
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleCountryChange(String countryCode, {bool closeModal = false}) async {
    if (_selectedCountry == countryCode || _isChanging) {
      return; // Ne rien faire si c'est déjà le pays sélectionné ou si un changement est en cours
    }

    // Vérifier si le pays a un prix disponible
    final country = widget.availableCountries.firstWhere(
      (c) => c['code'] == countryCode,
      orElse: () => {},
    );
    final isAvailable = country['isAvailable'] ?? false;
    
    if (!isAvailable) {
      print('❌ Pays $countryCode non disponible (prix indisponible)');
      return; // Ne pas permettre la sélection si le prix n'est pas disponible
    }

    setState(() {
      _isChanging = true;
      _selectedCountry = countryCode;
    });

    final changeFuture = widget.onCountrySelected(countryCode);

    if (closeModal) {
      changeFuture.whenComplete(() {
        if (mounted) {
          setState(() {
            _isChanging = false;
          });
        }
      });
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      await changeFuture;
    } catch (e) {
      print('❌ Erreur lors du changement de pays: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChanging = false;
        });
      }
    }
  }

  Widget _buildSelectedCountryAndPrice() {
    final selectedCountryCode = _currentArticle['spaysSelected']?.toString() ?? '';
    final homeCountryCode = _resolveHomeCountryCode();
    
    if (selectedCountryCode.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Trouver les données du pays sélectionné
    final selectedCountryData = widget.availableCountries.firstWhere(
      (country) => country['code']?.toString() == selectedCountryCode,
      orElse: () => {},
    );
    
    final selectedCountryName = selectedCountryData['name']?.toString() ?? selectedCountryCode;
    final selectedCountryFlag = selectedCountryData['flag']?.toString() ?? '';
    final selectedCountryPrice = selectedCountryData['price']?.toString() ?? 'N/A';
    final isHomeCountry = homeCountryCode.isNotEmpty && selectedCountryCode.toUpperCase() == homeCountryCode;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCountryFlag.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                selectedCountryFlag,
                width: 32,
                height: 22,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 32,
                    height: 22,
                    color: Colors.grey[200],
                    child: const Icon(Icons.flag, size: 14, color: Colors.grey),
                  );
                },
              ),
            ),
          const SizedBox(height: 6),
          Text(
            selectedCountryName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$selectedCountryCode - $selectedCountryPrice €',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          if (isHomeCountry) ...[
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green[400],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.home,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation sécurisée de MediaQuery pour éviter les erreurs
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final screenHeight = MediaQuery.maybeOf(context)?.size.height ?? 768;
    final isVerySmallMobile = screenWidth < 361;   // Galaxy Fold fermé, Galaxy S8+ (≤360px)
    final isSmallMobile = screenWidth < 431;       // iPhone XR/14 Pro Max, Pixel 7, Galaxy S20/A51 (361-430px)
    final isMobile = screenWidth < 768;            // Tous les mobiles standards (431-767px)
    final isWeb = screenWidth >= 768;
    final modalWidth = isWeb 
        ? screenWidth * 0.75  // 75% sur web
        : screenWidth;        // 100% sur mobile
    
    // ✨ Animation : Sidebar slide depuis la droite
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: Alignment.centerRight, // ✅ Aligner à droite comme un sidebar
          child: Container(
        width: modalWidth,
        height: screenHeight,
                        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isWeb 
              ? const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                )
              : BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header avec informations de l'article
              Container(
                padding: EdgeInsets.fromLTRB(
                  isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                  isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
                  isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                  isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  children: [
                    
                    // Informations de l'article
                    Row(
                      children: [
                        // Photo de l'article
                        Container(
                          width: isVerySmallMobile ? 60 : (isSmallMobile ? 70 : 80),
                          height: isVerySmallMobile ? 60 : (isSmallMobile ? 70 : 80),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[100],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (_currentArticle['sImage']?.toString().isNotEmpty == true)
                                ? Image.network(
                                    ApiConfig.getProxiedImageUrl(_currentArticle['sImage']),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                          size: 24,
                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                      size: 24,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(width: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
                        
                        // Description et code de l'article
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                              // Nom de l'article
                              Text(
                                _currentArticle['sname'] ?? 'Article',
                                style: TextStyle(
                                  fontSize: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                                  fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              
                              // Description de l'article (si disponible)
                              Builder(
                                builder: (context) {
                                  // Chercher la description dans différents champs possibles
                                  String? description;
                                  if (_currentArticle['sDescr']?.toString().isNotEmpty == true) {
                                    description = _currentArticle['sDescr'];
                                  } else if (_currentArticle['sDescription']?.toString().isNotEmpty == true) {
                                    description = _currentArticle['sDescription'];
                                  } else if (_currentArticle['description']?.toString().isNotEmpty == true) {
                                    description = _currentArticle['description'];
                                  } else if (_currentArticle['desc']?.toString().isNotEmpty == true) {
                                    description = _currentArticle['desc'];
                                  }
                                  
                                  if (description != null && description.isNotEmpty) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: isVerySmallMobile ? 13 : (isSmallMobile ? 14 : 15),
                                            color: Color(0xFF1F2937),
                                            fontWeight: FontWeight.w500,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              
                              // Code de l'article dans un container gris
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _currentArticle['scodearticle'] ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12),
                                    color: Color(0xFF374151),
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
              ),
            ),
            
            // Liste des pays
                      Expanded(
              child: widget.availableCountries.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Aucun pays disponible',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : (() {
                      // Déterminer le pays avec le meilleur prix parmi ceux disponibles
                      String bestCountryCode = '';
                      double bestPrice = double.infinity;
                      for (final c in widget.availableCountries) {
                        final bool isAvailable = c['isAvailable'] ?? false;
                        if (!isAvailable) continue;
                        final String priceStr = (c['price']?.toString() ?? '').replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
                        final match = RegExp(r"\d+\.?\d*").firstMatch(priceStr);
                        final double priceVal = match != null ? (double.tryParse(match.group(0)!) ?? 0.0) : 0.0;
                        if (priceVal > 0 && priceVal < bestPrice) {
                          bestPrice = priceVal;
                          bestCountryCode = (c['code']?.toString() ?? '');
                        }
                      }

                      final homeCountryCode = _resolveHomeCountryCode();

                      return ListView.builder(
                      padding: EdgeInsets.all(isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
                      itemCount: widget.availableCountries.length,
                          itemBuilder: (context, index) {
                  final country = widget.availableCountries[index];
                            final code = country['code']?.toString() ?? '';
                            final name = country['name']?.toString() ?? '';
                            final flag = country['flag']?.toString() ?? '';
                  final price = country['price']?.toString() ?? 'N/A';
                  final isAvailable = country['isAvailable'] ?? false;
                  final isSelected = code == _selectedCountry;
                  final isBest = code == bestCountryCode;
                  final normalizedCode = code.toUpperCase();
                  final isHomeCountry = homeCountryCode.isNotEmpty && normalizedCode == homeCountryCode;
                  final containerColor = !isAvailable
                      ? Colors.grey[100]
                      : (isSelected
                          ? const Color(0xFFECFDF5)
                          : Colors.white);
                  final borderColor = isSelected
                      ? const Color(0xFF10B981)
                      : (!isAvailable ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB));
                  final borderWidth = isSelected ? 2.0 : 1.0;
                            
                            // ✨ Animation : Chaque pays apparaît en vague
                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 300 + (index * 60)), // Vague progressive
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                final safeOpacity = value.clamp(0.0, 1.0);
                                return Transform.translate(
                                  offset: Offset(20 * (1 - value), 0), // Slide depuis la droite
                                  child: Opacity(
                                    opacity: safeOpacity,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                              margin: EdgeInsets.only(bottom: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                              child: GestureDetector(
                      onTap: (_isChanging || !isAvailable) ? null : () => _handleCountryChange(code),
                      onDoubleTap: (_isChanging || !isAvailable)
                          ? null
                          : () => _handleCountryChange(code, closeModal: true),
                      child: Opacity(
                        opacity: (_isChanging && !isSelected) || !isAvailable ? 0.5 : 1.0,
                                  child: Container(
                                    padding: EdgeInsets.all(isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
                                    decoration: BoxDecoration(
                                      color: containerColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: borderColor,
                                        width: borderWidth,
                                      ),
                                      boxShadow: isSelected ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withOpacity(0.1),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ] : [],
                                    ),
                                    child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Drapeau
                                      Container(
                                        margin: EdgeInsets.only(right: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: flag.isNotEmpty
                                              ? Image.network(
                                                  flag,
                                                  width: isVerySmallMobile ? 36 : (isSmallMobile ? 38 : 40),
                                                  height: isVerySmallMobile ? 27 : (isSmallMobile ? 28.5 : 30),
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Container(
                                                      width: isVerySmallMobile ? 36 : (isSmallMobile ? 38 : 40),
                                                      height: isVerySmallMobile ? 27 : (isSmallMobile ? 28.5 : 30),
                                                      color: Colors.grey[100],
                                                      child: const Center(
                                                        child: SizedBox(
                                                          width: 12,
                                                          height: 12,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) {
                                                    print('❌ Erreur chargement drapeau $flag: $error');
                                                    return Container(
                                                      width: isVerySmallMobile ? 36 : (isSmallMobile ? 38 : 40),
                                                      height: isVerySmallMobile ? 27 : (isSmallMobile ? 28.5 : 30),
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.flag,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  width: isVerySmallMobile ? 36 : (isSmallMobile ? 38 : 40),
                                                  height: isVerySmallMobile ? 27 : (isSmallMobile ? 28.5 : 30),
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.flag,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      
                            // Nom du pays
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                          children: [
                                    Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                                                fontWeight: FontWeight.w600,
                                                color: isAvailable ? Colors.black : const Color(0xFF9CA3AF),
                                        height: 1.0,
                                      ),
                                              ),
                                            SizedBox(height: isVerySmallMobile ? 2 : 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            code,
                            style: TextStyle(
                              fontSize: isVerySmallMobile ? 12 : (isSmallMobile ? 13 : 14),
                              color: const Color(0xFF6B7280),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                                          ],
                                        ),
                                      ),
                
                if (isHomeCountry) ...[
                  Expanded(
                    child: Center(
                      child: Container(
                        width: isVerySmallMobile ? 28 : (isSmallMobile ? 32 : 36),
                        height: isVerySmallMobile ? 28 : (isSmallMobile ? 32 : 36),
                        decoration: BoxDecoration(
                          color: Colors.green[400],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.home,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 12),
                ],
                                      
                            // Prix ou Indisponible (pour layout normal)
                                      if (isAvailable)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isBest) ...[
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isVerySmallMobile ? 6 : (isSmallMobile ? 7 : 8),
                                                vertical: isVerySmallMobile ? 3 : 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED), // fond ambré très clair
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFF59E0B)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('🥇', style: TextStyle(fontSize: 14)),
                                                  SizedBox(width: isVerySmallMobile ? 2 : 4),
                                                  Text(
                                                    Provider.of<TranslationService>(context, listen: false).translate('BEST_PRICE'),
                                                    style: TextStyle(
                                                      fontSize: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12),
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: isVerySmallMobile ? 6 : (isSmallMobile ? 8 : 10)),
                                          ],
                                          Text(
                                            price,
                                            style: TextStyle(
                                              fontSize: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                                              fontWeight: FontWeight.w700,
                                              color: isSelected
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF374151),
                                            ),
                                          ),
                                          ],
                                      )
                                      else
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isVerySmallMobile ? 6 : (isSmallMobile ? 7 : 8),
                                            vertical: isVerySmallMobile ? 3 : 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFD1D5DB),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'Indisponible',
                                            style: TextStyle(
                                              fontSize: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12),
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ),
                            
                            // Check si sélectionné (pour layout normal)
                                      if (isSelected) ...[
                                        SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                                        Container(
                                width: isVerySmallMobile ? 24 : (isSmallMobile ? 26 : 28),
                                height: isVerySmallMobile ? 24 : (isSmallMobile ? 26 : 28),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            color: Colors.white,
                                  size: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                        ),
                                ),
                              ),
                              ), // Ferme TweenAnimationBuilder
                            );
                          },
                      );
                    })(),
              ),
              
            // Boutons en bas du modal (en colonne)
              Container(
                padding: EdgeInsets.all(isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  children: [
                    // Bouton Ajouter/Supprimer un pays
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onManageCountries,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                            vertical: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.swap_horiz,
                            size: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                            color: Colors.black,
                            ),
                            SizedBox(width: isVerySmallMobile ? 6 : (isSmallMobile ? 7 : 8)),
                            Text(
                              'Ajouter/Supprimer un pays',
                              style: TextStyle(
                              fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isVerySmallMobile ? 10 : (isSmallMobile ? 12 : 16)),
                    
                    // Bouton Fermer
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                            vertical: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Fermer',
                          style: TextStyle(
                            fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ), // Ferme Align
        ), // Ferme FadeTransition
      ), // Ferme SlideTransition
    );
  }
}

/// Modal de gestion des pays (comme SNAL)
class _CountryManagementModal extends StatefulWidget {
  final List<Map<String, dynamic>> availableCountries;
  final List<String> selectedCountries;
  final Future<void> Function(List<String>) onSave;
  final String? lockedCountryCode;

  const _CountryManagementModal({
    Key? key,
    required this.availableCountries,
    required this.selectedCountries,
    required this.onSave,
    this.lockedCountryCode,
  }) : super(key: key);
  
  @override
  State<_CountryManagementModal> createState() => _CountryManagementModalState();
}

class _CountryManagementModalState extends State<_CountryManagementModal> with SingleTickerProviderStateMixin {
  late List<String> _selectedCountries;
  late final String? _lockedCountryCode;
  
  // ✨ Animations
  late AnimationController _modalController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _lockedCountryCode = widget.lockedCountryCode?.toUpperCase();
    _selectedCountries = widget.selectedCountries.map((c) => c.toUpperCase()).toSet().toList();
    if (_lockedCountryCode != null && _lockedCountryCode!.isNotEmpty && !_selectedCountries.contains(_lockedCountryCode)) {
      _selectedCountries.add(_lockedCountryCode!);
    }
    
    // ✨ Initialiser animation du modal (fade + scale)
    _modalController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _modalController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _modalController,
      curve: Curves.easeOut,
    ));
    
    // Démarrer l'animation
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _modalController.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _modalController.dispose();
    super.dispose();
  }

  /// Toggle un pays (comme SNAL toggleCountry)
  void _toggleCountry(String countryCode) {
    final normalizedCode = countryCode.toUpperCase();
    if (_lockedCountryCode != null && normalizedCode == _lockedCountryCode) {
      print('⚠️ Pays principal non modifiable: $normalizedCode');
      return;
    }
    setState(() {
      final index = _selectedCountries.indexOf(normalizedCode);
      if (index == -1) {
        _selectedCountries.add(normalizedCode); // Ajouter
        print('✅ Pays activé: $normalizedCode');
      } else {
        _selectedCountries.removeAt(index); // Supprimer
        print('❌ Pays désactivé: $normalizedCode');
      }
    });
    print('🔄 Pays togglé: $normalizedCode, Sélectionnés: $_selectedCountries');
  }
  
  @override
  Widget build(BuildContext context) {
    // ✨ Animation : Modal fade + scale
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
        width: (MediaQuery.maybeOf(context)?.size.width ?? 1024) * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Titre centré
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: const Text(
                'Ajouter des pays',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Section Pays disponibles
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Sous-titre "Pays disponibles"
                  Text(
                    Provider.of<TranslationService>(context, listen: false).translate('AVAILABLE_COUNTRIES') ?? 'Pays disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cliquez pour activer/désactiver les pays dans votre wishlist',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grille des pays en chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableCountries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final country = entry.value;
                      final code = country['code']?.toString() ?? '';
                      final name = country['name']?.toString() ?? '';
                      final normalizedCode = code.toUpperCase();
                      final isSelected = _selectedCountries.contains(normalizedCode);
                      final isLocked = _lockedCountryCode != null && normalizedCode == _lockedCountryCode;

                      // ✨ Animation : Chaque chip apparaît en vague
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 200 + (index * 50)), // Vague rapide
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          final safeOpacity = value.clamp(0.0, 1.0);
                          final safeScale = (0.8 + (0.2 * value)).clamp(0.5, 1.5);
                          return Transform.scale(
                            scale: safeScale, // Scale de 0.8 → 1.0 avec bounce
                            child: Opacity(
                              opacity: safeOpacity,
                              child: child,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: isLocked ? null : () => _toggleCountry(normalizedCode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE0F7FF) : const Color(0xFFF3F4F6), // Aqua très clair si sélectionné, gris clair sinon
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isLocked
                                  ? const Color(0xFF0284C7)
                                  : (isSelected ? const Color(0xFF00BCD4) : const Color(0xFFD1D5DB)), // Aqua si sélectionné, gris sinon
                              width: isLocked ? 2 : (isSelected ? 2 : 1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isLocked
                                      ? const Color(0xFF0284C7)
                                      : (isSelected ? const Color(0xFF00BCD4) : const Color(0xFF6B7280)), // Aqua pour sélectionné, gris pour non sélectionné
                                ),
                              ),
                              if (isLocked) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.lock,
                                  size: 16,
                                  color: Color(0xFF0284C7),
                                ),
                              ],
                              // Pas de check icon quand sélectionné (demandé par l'utilisateur)
                            ],
                          ),
                          ),
                        ),
                      ); // Ferme TweenAnimationBuilder
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Boutons en bas
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Bouton Annuler (gris)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF607D8B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Bouton Modifier (aqua)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await widget.onSave(_selectedCountries);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4), // Aqua
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Modifier',
                style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ), // Ferme Dialog
        ), // Ferme FadeTransition
      ), // Ferme ScaleTransition
    );
  }
}

class _BreathingButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _BreathingButton({
    Key? key,
    required this.onPressed,
    required this.child,
  }) : super(key: key);

  @override
  State<_BreathingButton> createState() => _BreathingButtonState();
}

class _BreathingButtonState extends State<_BreathingButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    
    // Contrôleur d'animation pour le pulse
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // 1.5 secondes pour un cycle de pulse
      vsync: this,
    );

    // Animation de scale (pulse plus subtil)
    _scaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Animation d'opacité pour l'effet de pulsation
    _opacityAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Animation de bordure pour effet de pulse
    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // Courbe élastique pour un effet de pulse
    ));

    // Démarrer l'animation en boucle avec un délai pour éviter les problèmes de performance
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Vérification de sécurité pour éviter les erreurs d'initialisation
        final borderValue = _borderAnimation?.value ?? 1.0;
        final scaleValue = _scaleAnimation?.value ?? 1.0;
        final opacityValue = _opacityAnimation.value;
        
        return Transform.scale(
          scale: scaleValue,
          child: Opacity(
            opacity: opacityValue,
            child: widget.child,
          ),
        );
      },
    );
  }
}