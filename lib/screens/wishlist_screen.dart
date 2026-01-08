import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/search_modal.dart';
import '../widgets/simple_map_modal.dart';
import '../widgets/location_info_dialog.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../config/api_config.dart';
import '../services/local_storage_service.dart';
import '../services/route_tracker.dart';
import '../services/auth_notifier.dart';
// Import conditionnel pour dart:html (Web uniquement)
import '../utils/web_utils.dart';
import 'package:animations/animations.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:numberpicker/numberpicker.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> with RouteTracker, WidgetsBindingObserver, TickerProviderStateMixin {

  /// Afficher un dialogue pour la saisie manuelle de la quantité avec un sélecteur à défilement
  Future<void> _showQuantityPickerDialog(String codeCrypt, int currentQuantity) async {
    // ✅ CRITIQUE: S'assurer que le notifier existe AVANT d'ouvrir le modal
    // Cela évite le délai lors de la première mise à jour
    if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
      final List<dynamic> pivotArray = List<dynamic>.from(_wishlistData!['pivotArray']);
      final articleIndex = pivotArray.indexWhere(
        (item) => item['sCodeArticleCrypt'] == codeCrypt || item['sCodeArticle'] == codeCrypt
      );
      
      if (articleIndex != -1) {
        final article = Map<String, dynamic>.from(pivotArray[articleIndex]);
        // ✅ CRITIQUE: Utiliser _ensureArticleNotifier au lieu de créer manuellement
        // Cela garantit que le notifier est correctement initialisé et synchronisé
        final notifier = _ensureArticleNotifier(article);
        // ✅ CRITIQUE: Ajouter un _lastUpdate initial pour protéger la valeur
        // Cela évite que _buildArticlesContent n'écrase la valeur lors du premier rebuild
        if (!notifier.value.containsKey('_lastUpdate')) {
          final updatedValue = Map<String, dynamic>.from(notifier.value);
          updatedValue['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch;
          notifier.value = updatedValue;
        }
        print('🔧 Notifier initialisé via _ensureArticleNotifier pour: $codeCrypt');
      }
    }
    
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: false,
      builder: (BuildContext context) {
        // ✅ Initialiser avec la quantité actuelle pour pré-sélectionner la valeur existante
        int newQuantity = currentQuantity;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 32),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // iOS-style Picker Container
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              // Selection highlight rectangle (iOS style)
                              Center(
                                child: Container(
                                  height: 40,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Number Picker
                              Center(
                                child: NumberPicker(
                                  value: newQuantity,
                                  minValue: 1,
                                  maxValue: 100,
                                  step: 1,
                                  haptics: true,
                                  itemHeight: 40,
                                  itemWidth: 100,
                                  axis: Axis.vertical,
                                  onChanged: (value) {
                                    setState(() => newQuantity = value);
                                  },
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide.none,
                                      bottom: BorderSide.none,
                                    ),
                                  ),
                                  textStyle: TextStyle(
                                    fontSize: 20,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.35),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  selectedTextStyle: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action Button
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(newQuantity),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0066FF),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _translationService.translate('ONBOARDING_VALIDATE') ?? 'Valider',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    // ✅ CRITIQUE: Mettre à jour le notifier IMMÉDIATEMENT, même avant l'appel API
    // Cela garantit que l'UI se met à jour instantanément dès la première fois
    if (result != null) {
      print('📊 Résultat du modal de quantité: $result (quantité actuelle: $currentQuantity)');
      
      // ✅ TOUJOURS mettre à jour le notifier en premier pour un feedback immédiat
      // Ne pas utiliser await pour que la mise à jour soit synchrone et immédiate
      print('🔄 Mise à jour immédiate du notifier (avant API si nécessaire)...');
      _forceUpdateArticleNotifierSync(codeCrypt, result);
      
      // Si la quantité a changé, appeler l'API pour synchroniser avec le backend (en arrière-plan)
      if (result != currentQuantity) {
        print('🔄 Quantité changée, appel API pour synchronisation en arrière-plan...');
        // Ne pas attendre l'API - l'appeler en arrière-plan
        _updateQuantity(codeCrypt, result).catchError((e) {
          print('❌ Erreur lors de la synchronisation API: $e');
        });
      } else {
        print('✅ Quantité identique, notifier déjà mis à jour');
      }
    }
  }
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
  AuthNotifier? _authNotifier; // Référence pour le listener
  bool _isHandlingAuthChange = false; // Garde pour éviter les appels multiples de _onAuthStateChanged
  
  // Variables pour le dropdown des baskets (comme SNAL-Project)
  List<Map<String, dynamic>> _baskets = []; // Liste des baskets disponibles
  int? _selectedBasketIndex; // Index du basket sélectionné (localId)
  
  // Variables pour l'animation du bouton "Tout supprimer"
  late ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false; // Indique si l'utilisateur est à la fin de la liste
  OverlayEntry? _currentSwipeHintOverlay; // Pour gérer l'overlay du message de swipe
  bool _isBasketDropdownOpen = false; // Pour l'animation de la flèche du dropdown
  
  // ✨ ANIMATIONS - Style "Cascade Fluide" (différent des 3 autres pages)
  late AnimationController _buttonsController;
  late AnimationController _cardsController;
  late AnimationController _articlesController;
  bool _animationsInitialized = false;
  
  // ✅ Animation de suppression de tous les articles
  Set<String> _articlesToDelete = {}; // Codes des articles en cours de suppression
  bool _isDeletingAll = false; // Flag pour indiquer qu'une suppression globale est en cours
  
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
      // ✅ CORRECTION: Toujours mettre à jour si les données diffèrent, même légèrement
      // Cela garantit que le notifier est toujours synchronisé avec les données source
      final currentValue = existing.value;
      bool needsUpdate = false;
      
      // Vérifier si iqte a changé
      if (currentValue['iqte'] != mapData['iqte']) {
        needsUpdate = true;
      }
      
      // Vérifier si d'autres champs importants ont changé
      if (!mapEquals(currentValue, mapData)) {
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        // ✅ Créer une nouvelle référence pour forcer la mise à jour
        existing.value = Map<String, dynamic>.from(mapData);
        print('🔄 Notifier mis à jour dans _ensureArticleNotifier: iqte=${mapData['iqte']}');
      }
      return existing;
    }
    final notifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(mapData));
    _articleNotifiers[key] = notifier;
    print('✅ Nouveau notifier créé: clé=$key, iqte=${mapData['iqte']}');
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
    
    // ✅ Ajouter le listener au ScrollController (déjà initialisé à la déclaration)
    _scrollController.addListener(_onScroll);
    
    // ✅ Écouter les changements d'authentification pour vider la wishlist lors de la déconnexion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authNotifier = Provider.of<AuthNotifier>(context, listen: false);
        _authNotifier?.addListener(_onAuthStateChanged);
      }
    });
  }
  
  /// Écouter les changements de scroll pour détecter si on est à la fin de la liste
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Détecter si on est proche de la fin (dans les 200 derniers pixels)
    final threshold = 200.0;
    final isAtBottom = (maxScroll - currentScroll) < threshold;
    
    if (isAtBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = isAtBottom;
      });
    }
  }
  
  /// Callback appelé quand l'état d'authentification change
  void _onAuthStateChanged() async {
    if (!mounted || _authNotifier == null) return;
    
    // ✅ GARDE: Éviter les appels multiples simultanés
    if (_isHandlingAuthChange) {
      print('⚠️ _onAuthStateChanged déjà en cours, ignoré');
      return;
    }
    
    _isHandlingAuthChange = true;
    
    try {
      // Si l'utilisateur s'est connecté, recharger les baskets et la wishlist
      if (_authNotifier!.isLoggedIn) {
        print('✅ Utilisateur connecté - Rechargement des baskets et de la wishlist...');
        
        // ✅ CRITIQUE: Attendre que les cookies soient bien synchronisés après la connexion
        // Le backend utilise les cookies pour identifier l'utilisateur
        print('⏳ Attente de la synchronisation des cookies (3 secondes)...');
        await Future.delayed(const Duration(seconds: 3));
        
        // ✅ VÉRIFICATION CRITIQUE: Vérifier que le profil local contient bien le nouveau iProfile
        // Faire plusieurs tentatives pour s'assurer que le profil est bien synchronisé
        Map<String, dynamic>? profileData;
        String iProfile = '';
        String sEmail = '';
        int retryCount = 0;
        const maxRetries = 3;
        
        while (retryCount < maxRetries && (iProfile.isEmpty || iProfile.startsWith('guest_') || sEmail.isEmpty)) {
          profileData = await LocalStorageService.getProfile();
          iProfile = profileData?['iProfile']?.toString() ?? '';
          sEmail = profileData?['sEmail']?.toString() ?? '';
          
          print('🔍 Vérification du profil après connexion (tentative ${retryCount + 1}/$maxRetries):');
          print('   iProfile: $iProfile');
          print('   sEmail: $sEmail');
          print('   Est connecté: ${sEmail.isNotEmpty}');
          
          if (iProfile.isEmpty || iProfile.startsWith('guest_') || sEmail.isEmpty) {
            print('⚠️ Profil non synchronisé - Attente de 1 seconde...');
            await Future.delayed(const Duration(seconds: 1));
            retryCount++;
          }
        }
        
        if (iProfile.isNotEmpty && !iProfile.startsWith('guest_') && sEmail.isNotEmpty) {
          print('✅ Profil valide détecté - Rechargement des baskets...');
          print('   iProfile final: $iProfile');
          print('   sEmail final: $sEmail');
          
          // ✅ CRITIQUE: Recharger les baskets d'abord (pour obtenir tous les baskets de l'utilisateur)
          // Le backend SNAL utilise le cookie GuestProfile pour identifier l'utilisateur
          // et retourner tous ses baskets (y compris ceux créés sur le web)
          await _loadBaskets();
          
          // ✅ Après avoir chargé les baskets, récupérer le premier basket (celui créé sur le web)
          // Comme SNAL-Project ligne 3657-3659: fallback sur le premier basket
          final updatedProfileData = await LocalStorageService.getProfile();
          final firstIBasket = updatedProfileData?['iBasket']?.toString() ?? '';
          
          if (firstIBasket.isNotEmpty && mounted) {
            print('✅ Rechargement de la wishlist avec le premier basket: $firstIBasket');
            // Recharger la wishlist avec le premier basket (celui créé sur le web)
            await _loadArticlesDirectly(iProfile, firstIBasket);
          } else if (mounted) {
            // Fallback: utiliser _loadWishlistData si pas de basket trouvé
            await _loadWishlistData(force: true);
          }
        } else {
          print('⚠️ Profil invalide ou non synchronisé - Réessayer dans 1 seconde...');
          // Réessayer après un délai supplémentaire
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            await _loadBaskets();
            
            // ✅ Après avoir chargé les baskets, récupérer le premier basket
            final updatedProfileData = await LocalStorageService.getProfile();
            final firstIBasket = updatedProfileData?['iBasket']?.toString() ?? '';
            final retryIProfile = updatedProfileData?['iProfile']?.toString() ?? '';
            
            if (firstIBasket.isNotEmpty && retryIProfile.isNotEmpty && mounted) {
              print('✅ Rechargement de la wishlist avec le premier basket (retry): $firstIBasket');
              await _loadArticlesDirectly(retryIProfile, firstIBasket);
            } else if (mounted) {
              await _loadWishlistData(force: true);
            }
          }
        }
      } 
      // Si l'utilisateur s'est déconnecté, vider la wishlist
      else {
        final articles = (_wishlistData?['pivotArray'] as List?) ?? [];
        final hasArticles = articles.isNotEmpty;
        
        print('🚪 Utilisateur déconnecté - Vidage de la wishlist (${articles.length} articles)');
        
        setState(() {
          _wishlistData = {
            'meta': {
              'iBestResultJirig': 0,
              'iTotalPriceArticleSelected': 0.0,
              'sResultatGainPerte': '0€',
            },
            'pivotArray': [],
          };
          _selectedBasketName = 'Wishlist (0 Art.)';
          _baskets = []; // Vider aussi la liste des baskets
          _selectedBasketIndex = null;
          _hasLoaded = true;
          _isLoading = false; // Arrêter le chargement
        });
        
        // Nettoyer les notifiers d'articles
        for (final notifier in _articleNotifiers.values) {
          notifier.dispose();
        }
        _articleNotifiers.clear();
        
        print('✅ Wishlist vidée - Ne pas recharger automatiquement après déconnexion');
        // ❌ NE PAS recharger automatiquement la wishlist après déconnexion
        // L'utilisateur devra recharger manuellement ou naviguer vers une autre page
      }
    } finally {
      // ✅ Libérer le garde après traitement
      _isHandlingAuthChange = false;
    }
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
    
    // ✅ Retirer le listener d'authentification
    try {
      _authNotifier?.removeListener(_onAuthStateChanged);
      _authNotifier = null;
    } catch (e) {
      print('⚠️ Erreur retrait listener auth: $e');
    }
    
    // ✅ Disposer du ScrollController
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    
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
      // Charger d'abord la liste des baskets (comme SNAL-Project)
      await _loadBaskets();
      
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

  /// Charger la liste des baskets de l'utilisateur (comme SNAL-Project getAllBasket4User)
  Future<void> _loadBaskets() async {
    try {
      // ✅ CRITIQUE: Vérifier le profil avant de charger les baskets
      final profileData = await LocalStorageService.getProfile();
      final iProfile = profileData?['iProfile']?.toString() ?? '';
      final sEmail = profileData?['sEmail']?.toString() ?? '';
      
      print('📦 Chargement de la liste des baskets...');
      print('🔍 Profil actuel:');
      print('   iProfile: $iProfile');
      print('   sEmail: $sEmail');
      print('   Est connecté: ${sEmail.isNotEmpty}');
      
      // L'API utilise les cookies pour identifier l'utilisateur
      // L'intercepteur Dio ajoute automatiquement le GuestProfile dans les headers et cookies
      final response = await _apiService.getAllBasket4User();
      
      print('📡 Réponse getAllBasket4User:');
      print('   success: ${response?['success']}');
      print('   error: ${response?['error']}');
      print('   data: ${response?['data']}');
      print('   nombre de baskets: ${(response?['data'] as List?)?.length ?? 0}');
      
      // ✅ Gérer les erreurs comme SNAL-Project
      if (response == null) {
        print('❌ Réponse null - Aucun basket récupéré');
        _baskets = [];
        if (mounted) setState(() {});
        return;
      }
      
      // Vérifier si c'est une erreur
      if (response['success'] == false || response.containsKey('error')) {
        final errorMessage = response['error'] ?? 'Erreur lors de la récupération des baskets';
        print('❌ Erreur getAllBasket4User: $errorMessage');
        _baskets = [];
        if (mounted) setState(() {});
        return;
      }
      
      // ✅ Vérifier si c'est un succès avec data
      if (response['success'] == true && response['data'] != null) {
        final basketsData = response['data'] as List;
        
        if (basketsData.isEmpty) {
          print('⚠️ Aucun basket trouvé dans la réponse');
          _baskets = [];
          if (mounted) setState(() {});
          return;
        }
        
        // Transformer les données comme SNAL-Project (avec localId = index)
        _baskets = basketsData.asMap().entries.map((entry) {
          final index = entry.key;
          final basket = entry.value as Map<String, dynamic>;
          return {
            'label': basket['sBasketName'] ?? 'Wishlist',
            'iBasket': basket['iBasket']?.toString() ?? '',
            'localId': index, // Index comme localId (comme SNAL)
          };
        }).toList();
        
        print('✅ ${_baskets.length} baskets chargés');
        print('📋 Liste des baskets:');
        for (var i = 0; i < _baskets.length; i++) {
          final basket = _baskets[i];
          print('   ${i + 1}. ${basket['label']} (iBasket: ${basket['iBasket']})');
        }
        
        // ✅ CRITIQUE: Sélectionner le basket comme SNAL-Project
        // PRIORITÉ 1: Utiliser l'iBasket de l'URL s'il est présent (venant du podium)
        // PRIORITÉ 2: Utiliser l'iBasket du profil
        // PRIORITÉ 3: Utiliser le premier basket
        if (_baskets.isNotEmpty) {
          final profileData = await LocalStorageService.getProfile();
          final sEmail = profileData?['sEmail']?.toString() ?? '';
          
          // ✅ PRIORITÉ 1: Vérifier si un iBasket est passé dans l'URL (venant du podium)
          String? iBasketFromUrl;
          String? basketNameFromUrl;
          try {
            final uri = GoRouterState.of(context).uri;
            final iBasketParam = uri.queryParameters['iBasket'];
            final basketNameParam = uri.queryParameters['basketName'];
            print('🔍 Paramètres URL: ${uri.queryParameters}');
            print('🔍 iBasketParam brut: $iBasketParam');
            print('🔍 basketNameParam brut: $basketNameParam');
            if (iBasketParam != null && iBasketParam.isNotEmpty) {
              iBasketFromUrl = Uri.decodeComponent(iBasketParam);
              print('🛒 iBasket récupéré depuis l\'URL (décodé): $iBasketFromUrl');
              print('🛒 Longueur: ${iBasketFromUrl.length}');
            } else {
              print('⚠️ Aucun iBasket trouvé dans l\'URL');
            }
            if (basketNameParam != null && basketNameParam.isNotEmpty) {
              basketNameFromUrl = Uri.decodeComponent(basketNameParam);
              print('🛒 Nom du basket récupéré depuis l\'URL (décodé): $basketNameFromUrl');
            } else {
              print('⚠️ Aucun nom de basket trouvé dans l\'URL');
            }
          } catch (e) {
            print('⚠️ Erreur lors de la récupération de l\'iBasket depuis l\'URL: $e');
          }
          
          // Déterminer quel iBasket utiliser
          String? iBasketToUse;
          if (iBasketFromUrl != null && iBasketFromUrl.isNotEmpty) {
            iBasketToUse = iBasketFromUrl;
            print('✅ Utilisation de l\'iBasket depuis l\'URL (priorité absolue)');
          } else {
            iBasketToUse = profileData?['iBasket']?.toString() ?? '';
            print('✅ Utilisation de l\'iBasket depuis le profil');
          }
          
          // ✅ PRIORITÉ 0: Vérifier si un index est sauvegardé dans le localStorage
          // Si oui, l'utiliser en priorité ABSOLUE (même si un iBasket est dans l'URL)
          // C'est la sélection manuelle de l'utilisateur qui doit être préservée
          int? savedIndex;
          try {
            final prefs = await SharedPreferences.getInstance();
            savedIndex = prefs.getInt('selectedBasketIndex');
            if (savedIndex != null && savedIndex >= 0 && savedIndex < _baskets.length) {
              final savedBasket = _baskets[savedIndex];
              final savedIBasket = savedBasket['iBasket']?.toString() ?? '';
              if (savedIBasket.isNotEmpty) {
                print('✅ Index sauvegardé trouvé: $savedIndex (basket: ${savedBasket['label']})');
                print('   iBasket du basket sauvegardé: $savedIBasket');
                print('   iBasket de l\'URL: $iBasketFromUrl');
                
                // ✅ PRIORITÉ ABSOLUE: Utiliser l'index sauvegardé si valide
                // Même si l'iBasket de l'URL ne correspond pas, on préserve la sélection manuelle
                _selectedBasketIndex = savedIndex;
                _selectedBasketName = savedBasket['label']?.toString() ?? 'Wishlist';
                print('✅ Utilisation de l\'index sauvegardé (priorité absolue): $savedIndex');
                
                // Mettre à jour le profil avec l'iBasket du basket sauvegardé
                if (profileData != null) {
                  await LocalStorageService.saveProfile({
                    ...profileData,
                    'iBasket': savedIBasket,
                  });
                  print('💾 Profil mis à jour avec l\'iBasket sauvegardé: $savedIBasket');
                }
                
                // ✅ CRITIQUE: Sortir de la logique de recherche pour éviter toute réinitialisation
                if (mounted) {
                  setState(() {});
                }
                print('✅ Retour anticipé - Index sauvegardé utilisé, pas de réinitialisation');
                return; // ✅ RETOURNER ICI pour éviter de réinitialiser l'index
              } else {
                print('⚠️ Index sauvegardé invalide: iBasket vide pour l\'index $savedIndex');
              }
            } else {
              print('⚠️ Index sauvegardé invalide ou hors limites: $savedIndex (baskets: ${_baskets.length})');
            }
          } catch (e) {
            print('⚠️ Erreur lors de la récupération de l\'index sauvegardé: $e');
          }
          
          // ✅ PRIORITÉ: Si un iBasket est passé dans l'URL (venant du podium), l'utiliser TOUJOURS
          // Sinon, si l'utilisateur vient de se connecter, utiliser le premier basket
          // (comme SNAL-Project ligne 3657-3658 de wishlist/[icode].vue)
          // Le premier basket est celui retourné par la procédure stockée (trié)
          bool shouldUseFirstBasket = sEmail.isNotEmpty && iBasketFromUrl == null; // Utilisateur connecté ET pas d'iBasket dans l'URL
          
          int foundIndex = -1;
          // ✅ Chercher le basket correspondant au iBasket à utiliser (même si utilisateur connecté)
          if (iBasketToUse.isNotEmpty) {
            print('🔍 Recherche du basket avec iBasket: $iBasketToUse (longueur: ${iBasketToUse.length})');
            foundIndex = _baskets.indexWhere(
              (basket) {
                final basketIBasket = basket['iBasket']?.toString() ?? '';
                final match = basketIBasket == iBasketToUse;
                if (!match && basketIBasket.isNotEmpty) {
                  print('   ⚠️ Comparaison: "$basketIBasket" != "$iBasketToUse"');
                }
                return match;
              },
            );
            if (foundIndex >= 0) {
              print('✅ Basket trouvé avec iBasket: index $foundIndex, nom: ${_baskets[foundIndex]['label']}');
            } else {
              print('⚠️ Basket non trouvé avec iBasket: $iBasketToUse');
              print('   🔍 Baskets disponibles (${_baskets.length}):');
              for (var i = 0; i < _baskets.length; i++) {
                final basketIBasket = _baskets[i]['iBasket']?.toString() ?? '';
                print('      $i: "${_baskets[i]['label']}" - iBasket: "$basketIBasket" (longueur: ${basketIBasket.length})');
              }
              
              // ✅ FALLBACK: Si l'iBasket n'est pas trouvé mais qu'un nom de basket est fourni, chercher par nom
              if (basketNameFromUrl != null && basketNameFromUrl.isNotEmpty) {
                print('🔄 Tentative de recherche par nom du basket: $basketNameFromUrl');
                foundIndex = _baskets.indexWhere(
                  (basket) {
                    final basketLabel = basket['label']?.toString() ?? '';
                    final match = basketLabel == basketNameFromUrl;
                    if (match) {
                      print('   ✅ Basket trouvé par nom: index ${_baskets.indexOf(basket)}, nom: $basketLabel');
                    }
                    return match;
                  },
                );
                if (foundIndex >= 0) {
                  print('✅ Basket trouvé avec nom (fallback): index $foundIndex, nom: ${_baskets[foundIndex]['label']}');
                  // Mettre à jour iBasketToUse avec le vrai iBasket du basket trouvé
                  final foundBasket = _baskets[foundIndex];
                  final foundIBasket = foundBasket['iBasket']?.toString() ?? '';
                  if (foundIBasket.isNotEmpty) {
                    iBasketToUse = foundIBasket;
                    print('✅ iBasket mis à jour avec celui du basket trouvé: $iBasketToUse');
                  }
                } else {
                  print('⚠️ Basket non trouvé avec nom: $basketNameFromUrl');
                }
              }
            }
          }
          
          // ✅ Si trouvé, utiliser cet index (même si utilisateur connecté, si iBasket vient de l'URL)
          if (foundIndex >= 0) {
            _selectedBasketIndex = foundIndex;
            final selectedBasket = _baskets[foundIndex];
            _selectedBasketName = selectedBasket['label']?.toString() ?? 'Wishlist';
            print('✅ Basket sélectionné (correspond au iBasket utilisé): index $foundIndex, nom: $_selectedBasketName');
            
            // ✅ CRITIQUE: Sauvegarder l'index du basket sélectionné dans le localStorage
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('selectedBasketIndex', foundIndex);
              print('💾 Index du basket sélectionné sauvegardé: $foundIndex');
            } catch (e) {
              print('⚠️ Erreur lors de la sauvegarde de l\'index: $e');
            }
            
            // ✅ Mettre à jour le profil avec le basket sélectionné
            if (profileData != null && iBasketToUse.isNotEmpty) {
              await LocalStorageService.saveProfile({
                ...profileData,
                'iBasket': iBasketToUse,
              });
              print('💾 Profil mis à jour avec l\'iBasket sélectionné: $iBasketToUse');
            }
          } else {
            // ✅ Si pas de basket trouvé, essayer de restaurer l'index sauvegardé
            bool shouldPreserveSelection = false;
            int? savedIndex;
            
            // ✅ PRIORITÉ 1: Vérifier si un index est sauvegardé dans le localStorage
            try {
              final prefs = await SharedPreferences.getInstance();
              savedIndex = prefs.getInt('selectedBasketIndex');
              if (savedIndex != null && savedIndex >= 0 && savedIndex < _baskets.length) {
                final savedBasket = _baskets[savedIndex];
                final savedIBasket = savedBasket['iBasket']?.toString() ?? '';
                if (savedIBasket.isNotEmpty) {
                  shouldPreserveSelection = true;
                  _selectedBasketIndex = savedIndex;
                  _selectedBasketName = savedBasket['label']?.toString() ?? 'Wishlist';
                  print('✅ Restauration du basket depuis localStorage (index $savedIndex): $_selectedBasketName');
                  // Mettre à jour le profil avec l'iBasket du basket restauré
                  if (profileData != null) {
                    await LocalStorageService.saveProfile({
                      ...profileData,
                      'iBasket': savedIBasket,
                    });
                    print('💾 Profil mis à jour avec l\'iBasket restauré: $savedIBasket');
                  }
                }
              }
            } catch (e) {
              print('⚠️ Erreur lors de la récupération de l\'index sauvegardé: $e');
            }
            
            // ✅ PRIORITÉ 2: Si pas d'index sauvegardé, préserver l'index actuel s'il est valide
            if (!shouldPreserveSelection && 
                _selectedBasketIndex != null && 
                _selectedBasketIndex! >= 0 && 
                _selectedBasketIndex! < _baskets.length) {
              // Vérifier que le basket sélectionné existe toujours
              final currentBasket = _baskets[_selectedBasketIndex!];
              final currentIBasket = currentBasket['iBasket']?.toString() ?? '';
              final profileIBasket = profileData?['iBasket']?.toString() ?? '';
              
              // Préserver si :
              // 1. L'iBasket du profil correspond au basket sélectionné, OU
              // 2. On ne vient pas d'une redirection depuis le podium (pas d'iBasket dans l'URL)
              if (currentIBasket.isNotEmpty && 
                  (currentIBasket == profileIBasket || iBasketFromUrl == null)) {
                shouldPreserveSelection = true;
                _selectedBasketName = currentBasket['label']?.toString() ?? 'Wishlist';
                print('✅ Préservation du basket sélectionné (index $_selectedBasketIndex): $_selectedBasketName');
                print('   iBasket du basket: $currentIBasket');
                print('   iBasket du profil: $profileIBasket');
                print('   iBasket de l\'URL: $iBasketFromUrl');
                // Mettre à jour le profil avec l'iBasket du basket préservé
                if (profileData != null) {
                  await LocalStorageService.saveProfile({
                    ...profileData,
                    'iBasket': currentIBasket,
                  });
                  print('💾 Profil mis à jour avec l\'iBasket préservé: $currentIBasket');
                }
              }
            }
            
            if (!shouldPreserveSelection) {
              // ✅ PRIORITÉ: Utiliser le PREMIER basket (comme SNAL-Project)
              // C'est le basket existant créé sur le web, pas le iBasketMagikLink de la connexion
              _selectedBasketIndex = 0;
              final firstBasket = _baskets[0];
              final firstIBasket = firstBasket['iBasket']?.toString() ?? '';
              _selectedBasketName = firstBasket['label']?.toString() ?? 'Wishlist';
              
              // Sauvegarder l'index du premier basket
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('selectedBasketIndex', 0);
                print('💾 Index du premier basket sauvegardé: 0');
              } catch (e) {
                print('⚠️ Erreur lors de la sauvegarde de l\'index: $e');
              }
              
              if (profileData != null && firstIBasket.isNotEmpty) {
                // ✅ CRITIQUE: Mettre à jour le profil avec le premier basket (celui créé sur le web)
                await LocalStorageService.saveProfile({
                  ...profileData,
                  'iBasket': firstIBasket, // Utiliser le premier basket au lieu du iBasketMagikLink
                });
                print('✅ Premier basket sélectionné (basket existant créé sur le web):');
                print('   iBasket: $firstIBasket');
                print('   nom: $_selectedBasketName');
                print('   ⚠️ Ce basket remplace le iBasketMagikLink de la connexion');
              }
            }
          }
        }
        
        if (mounted) {
          setState(() {});
        }
      } else {
        print('⚠️ Aucun basket trouvé ou réponse invalide');
        print('   Réponse complète: $response');
        _baskets = [];
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des baskets: $e');
      _baskets = [];
    }
  }

  /// Gérer le changement de basket (comme SNAL-Project handleBasketChange)
  Future<void> _handleBasketChange(int? newIndex) async {
    if (newIndex == null || newIndex < 0 || newIndex >= _baskets.length) {
      return;
    }
    
    try {
      print('🔄 Changement de basket: index $newIndex');
      
      final selectedBasket = _baskets[newIndex];
      final newIBasket = selectedBasket['iBasket']?.toString() ?? '';
      
      if (newIBasket.isEmpty) {
        print('❌ iBasket vide pour le basket sélectionné');
        return;
      }
      
      // Mettre à jour l'index sélectionné
      _selectedBasketIndex = newIndex;
      
      // Mettre à jour le nom du basket sélectionné
      final basketLabel = selectedBasket['label']?.toString() ?? 'Wishlist';
      _selectedBasketName = basketLabel;
      
      // ✅ CRITIQUE: Sauvegarder l'index du basket sélectionné dans le localStorage
      // pour pouvoir le restaurer lors du rechargement
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedBasketIndex', newIndex);
      print('💾 Index du basket sélectionné sauvegardé: $newIndex');
      
      // Mettre à jour le profil avec le nouveau iBasket
      final profileData = await LocalStorageService.getProfile();
      if (profileData != null) {
        final iProfile = profileData['iProfile']?.toString() ?? '';
        await LocalStorageService.saveProfile({
          ...profileData,
          'iBasket': newIBasket,
        });
        
        // Recharger les articles avec le nouveau basket
        if (iProfile.isNotEmpty) {
          setState(() {
            _isLoading = true;
            _wishlistData = null;
          });
          
          await _loadArticlesDirectly(iProfile, newIBasket);
        }
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Erreur lors du changement de basket: $e');
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
            // ✅ CRITIQUE: Créer une nouvelle référence pour forcer Flutter à détecter le changement
            // Stocker une copie de 'data' qui contient pivotArray et meta
            _wishlistData = Map<String, dynamic>.from(data);
            _wishlistData!['pivotArray'] = List<dynamic>.from(data['pivotArray'] ?? []);
            if (data['meta'] != null) {
              _wishlistData!['meta'] = Map<String, dynamic>.from(data['meta']);
            }
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
      print('🔍 État actuel des baskets:');
      print('   Nombre de baskets: ${_baskets.length}');
      print('   Index sélectionné: $_selectedBasketIndex');
      print('   Nom du basket sélectionné: $_selectedBasketName');
      
      // ✅ PRIORITÉ: Utiliser l'iBasket du basket actuellement sélectionné dans le dropdown
      // au lieu de celui du profil (qui peut être obsolète)
      String? iBasket;
      if (_baskets.isNotEmpty && 
          _selectedBasketIndex != null && 
          _selectedBasketIndex! >= 0 && 
          _selectedBasketIndex! < _baskets.length) {
        final selectedIndex = _selectedBasketIndex!;
        iBasket = _baskets[selectedIndex]['iBasket']?.toString();
        print('✅ iBasket récupéré depuis le basket sélectionné:');
        print('   Index: $selectedIndex');
        print('   Nom: ${_baskets[selectedIndex]['label']}');
        print('   iBasket: $iBasket (longueur: ${iBasket?.length ?? 0})');
        
        // Vérifier que l'iBasket n'est pas vide
        if (iBasket == null || iBasket.isEmpty) {
          print('⚠️ iBasket vide pour le basket sélectionné, utilisation du fallback');
          iBasket = null; // Forcer le fallback
        }
      } else {
        print('⚠️ Pas de basket sélectionné valide:');
        print('   _baskets.isNotEmpty: ${_baskets.isNotEmpty}');
        print('   _selectedBasketIndex: $_selectedBasketIndex');
        if (_baskets.isNotEmpty) {
          print('   _baskets.length: ${_baskets.length}');
        }
      }
      
      // Fallback: Si pas de basket sélectionné, utiliser celui du profil
      if (iBasket == null || iBasket.isEmpty) {
        final profileData = await LocalStorageService.getProfile();
        iBasket = profileData?['iBasket']?.toString() ?? '';
        print('🛒 iBasket récupéré depuis le profil (fallback): $iBasket (longueur: ${iBasket.length})');
      }
      
      // Construire l'URL avec les paramètres (comme SNAL-Project)
      // Le podium Flutter attend le code normal dans l'URL et le crypté en query param
      if (iBasket.isNotEmpty) {
        // Avec iBasket, crypt ET quantité dans les query params
        context.go('/podium/$sCodeArticle?crypt=$sCodeArticleCrypt&iBasket=${Uri.encodeComponent(iBasket)}&iQuantite=$iQuantite');
        print('✅ Navigation vers podium avec iBasket: $iBasket');
      } else {
        // Sans iBasket mais avec crypt et quantité
        context.go('/podium/$sCodeArticle?crypt=$sCodeArticleCrypt&iQuantite=$iQuantite');
        print('⚠️ Navigation vers podium sans iBasket');
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
        message: _translationService.translate('CONFIRM_DELETE_ITEM'),
      );

      if (confirmed != true) {
        print('❌ Suppression annulée par l\'utilisateur');
        return;
      }

      // ✅ CRITIQUE: Suppression optimiste - Mettre à jour l'UI IMMÉDIATEMENT AVANT l'appel API
      // Cela garantit un feedback instantané pour l'utilisateur (sans await pour ne pas bloquer)
      print('⚡ Suppression optimiste - Mise à jour UI immédiate...');
      _updateDataAfterDeletionOptimistic(sCodeArticleCrypt).catchError((e) {
        print('❌ Erreur suppression optimiste: $e');
      });
      
      // Appel API pour supprimer l'article (en arrière-plan)
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
        print('✅ Article supprimé avec succès côté API');
        
        // Mettre à jour les métadonnées depuis la réponse API (totaux, etc.)
        await _updateDataAfterDeletion(response, sCodeArticleCrypt);
        
        // Afficher le message de succès (sans await pour ne pas bloquer l'UI)
        _showNotiflixSuccessDialog(
          title: _translationService.translate('SUCCESS_TITTLE'),
          message: _translationService.translate('SUCCES_DELETE_ARTICLE'),
        );
        
      } else {
        print('❌ Erreur lors de la suppression côté API: ${response?['error'] ?? 'Erreur inconnue'}');
        print('❌ Détails de l\'erreur: ${response?['details'] ?? 'Aucun détail'}');
        print('❌ Stack trace: ${response?['stack'] ?? 'Aucun stack trace'}');
        
        // ✅ CRITIQUE: Même en cas d'erreur API, l'article a déjà été supprimé de manière optimiste
        // Ne PAS restaurer l'article - l'utilisateur a déjà vu qu'il a été supprimé
        // On affiche juste un message d'erreur mais on garde l'article supprimé
        print('⚠️ Erreur API mais article déjà supprimé de manière optimiste - on garde la suppression');
        
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

  /// Supprimer tous les articles de la wishlist (comme SNAL-Project)
  Future<void> _deleteAllArticles() async {
    try {
      print('🗑️ Suppression de tous les articles de la wishlist');
      
      // Afficher une confirmation (comme SNAL avec Notiflix)
      final bool? confirmed = await _showNotiflixConfirmDialog(
        title: _translationService.translate('CONFIRM_TITLE'),
        message: _translationService.translate('CONFIRM_DELETE_ALL_ITEM') ?? 'Êtes-vous sûr de vouloir supprimer tous les articles ?',
      );

      if (confirmed != true) {
        print('❌ Suppression annulée par l\'utilisateur');
        return;
      }

      // ✅ DÉCLENCHER L'ANIMATION DE SUPPRESSION AVANT L'APPEL API
      final articles = _wishlistData?['pivotArray'] as List? ?? [];
      if (articles.isNotEmpty && mounted) {
        setState(() {
          _isDeletingAll = true;
          // Marquer tous les articles pour suppression
          _articlesToDelete = Set<String>.from(
            articles.map((article) => 
              article['sCodeArticleCrypt']?.toString() ?? 
              article['sCodeArticle']?.toString() ?? 
              ''
            ).where((code) => code.isNotEmpty)
          );
        });
        
        print('🎬 Animation de suppression déclenchée pour ${_articlesToDelete.length} articles');
        
        // Attendre que l'animation soit terminée (durée totale: ~800ms pour le dernier article)
        final animationDuration = Duration(milliseconds: 300 + (articles.length * 50));
        await Future.delayed(animationDuration);
      }

      // Appel API pour supprimer tous les articles
      print('🚀 Envoi de la requête de suppression de tous les articles...');
      
      final response = await _apiService.deleteAllArticleBasketWishlist();

      print('📥 Réponse complète de l\'API:');
      print('📥 Type de réponse: ${response.runtimeType}');
      print('📥 Contenu de la réponse: $response');
      
      if (response != null) {
        print('📥 Clés disponibles dans la réponse: ${response.keys.toList()}');
        print('📥 Success: ${response['success']}');
        print('📥 Message: ${response['message']}');
        print('📥 ParsedData: ${response['parsedData']}');
        print('📥 Error: ${response['error']}');
      }

      if (response != null && response['success'] == true) {
        print('✅ Tous les articles supprimés avec succès');
        
        // Mettre à jour les données locales IMMÉDIATEMENT (comme SNAL)
        await _updateDataAfterDeleteAll(response);
        
        // Réinitialiser l'état d'animation
        if (mounted) {
          setState(() {
            _isDeletingAll = false;
            _articlesToDelete.clear();
          });
        }
        
        // Afficher le message de succès
        _showNotiflixSuccessDialog(
          title: _translationService.translate('SUCCESS_TITTLE'),
          message: _translationService.translate('ALL_ARTICLE_DELETED_SUCCESS') ?? 'Tous les articles ont été supprimés avec succès',
        );
        
        // Recharger les données depuis l'API pour garantir la synchronisation
        if (mounted) {
          await _loadWishlistData(force: true);
        }
        
      } else {
        // En cas d'erreur, réinitialiser l'état d'animation
        if (mounted) {
          setState(() {
            _isDeletingAll = false;
            _articlesToDelete.clear();
          });
        }
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
      print('❌ Erreur lors de la suppression de tous les articles: $e');
      
      // Réinitialiser l'état d'animation en cas d'erreur
      if (mounted) {
        setState(() {
          _isDeletingAll = false;
          _articlesToDelete.clear();
        });
      }
      
      // Afficher un message d'erreur style Notiflix
      await _showNotiflixErrorDialog(
        title: _translationService.translate('ERROR_TITLE'),
        message: _translationService.translate('DELETE_ERROR') ?? "Une erreur s'est produite lors de la suppression: $e",
      );
    }
  }

  /// Mettre à jour les données locales après suppression de tous les articles
  Future<void> _updateDataAfterDeleteAll(Map<String, dynamic> response) async {
    try {
      print('🔄 Mise à jour des données après suppression de tous les articles: $response');
      
      // ✅ CRITIQUE: Réinitialiser complètement la wishlist
      _wishlistData = {
        'meta': {
          'iBestResultJirig': 0.0,
          'iTotalQteArticleSelected': 0,
          'iTotalPriceArticleSelected': 0.0,
          'iTotalQteArticle': 0,
          'sResultatGainPerte': '0€',
          'iResultatGainPertePercentage': 0.0,
          'iTotalSelected4PaysProfile': 0.0,
          'iTotalPriceSelected4PaysProfile': 0.0,
          // Conserver iBasket si présent dans l'ancienne meta
          if (_wishlistData?['meta'] != null && _wishlistData!['meta']['iBasket'] != null)
            'iBasket': _wishlistData!['meta']['iBasket'],
        },
        'pivotArray': [],
      };
      
      // Nettoyer tous les notifiers
      for (var notifier in _articleNotifiers.values) {
        notifier.dispose();
      }
      _articleNotifiers.clear();
      print('✅ Tous les notifiers nettoyés');
      
      // Mettre à jour le nom du panier
      _selectedBasketName = 'Wishlist (0 Art.)';
      
      // ✅ CRITIQUE: Mettre à jour aussi le label du basket dans _baskets
      if (_selectedBasketIndex != null && 
          _selectedBasketIndex! >= 0 && 
          _selectedBasketIndex! < _baskets.length) {
        // Créer une nouvelle copie du basket pour forcer la détection du changement
        _baskets[_selectedBasketIndex!] = Map<String, dynamic>.from(_baskets[_selectedBasketIndex!]);
        _baskets[_selectedBasketIndex!]['label'] = 'Wishlist (0 Art.)';
        print('✅ Label du basket mis à jour dans _baskets: Wishlist (0 Art.)');
      }
      
      // ✅ CRITIQUE: Rafraîchir l'interface IMMÉDIATEMENT
      if (mounted) {
        setState(() {
          // Forcer la mise à jour en créant une nouvelle référence complète
          _wishlistData = Map<String, dynamic>.from(_wishlistData!);
        });
        print('✅ setState() appelé - UI devrait se rafraîchir immédiatement');
      }
      
      print('✅ Données mises à jour après suppression de tous les articles - UI devrait se rafraîchir immédiatement');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des données: $e');
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

  /// Forcer la mise à jour du notifier d'un article de manière SYNCHRONE (sans appel API)
  /// Utile pour un feedback immédiat dans l'UI
  void _forceUpdateArticleNotifierSync(String sCodeArticleCrypt, int quantity) {
    try {
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        final List<dynamic> pivotArray = List<dynamic>.from(_wishlistData!['pivotArray']);
        
        // Trouver l'article
        final articleIndex = pivotArray.indexWhere(
          (item) => item['sCodeArticleCrypt'] == sCodeArticleCrypt || item['sCodeArticle'] == sCodeArticleCrypt
        );
        
        if (articleIndex != -1) {
          final articleToUpdate = Map<String, dynamic>.from(pivotArray[articleIndex]);
          articleToUpdate['iqte'] = quantity;
          
          final articleKey = _articleKey(articleToUpdate);
          print('🔑 Clé utilisée pour trouver le notifier: $articleKey (codeCrypt: $sCodeArticleCrypt)');
          ValueNotifier<Map<String, dynamic>>? notifier = _articleNotifiers[articleKey];
          
          // ✅ CRITIQUE: Si le notifier n'est pas trouvé avec cette clé, essayer de le trouver avec le codeCrypt
          if (notifier == null) {
            print('⚠️ Notifier non trouvé avec clé $articleKey, recherche alternative...');
            print('   📦 Clés disponibles: ${_articleNotifiers.keys.toList()}');
            for (var entry in _articleNotifiers.entries) {
              final notifValue = entry.value.value;
              final notifCodeCrypt = notifValue['sCodeArticleCrypt']?.toString() ?? '';
              final notifCode = notifValue['sCodeArticle']?.toString() ?? '';
              if (notifCodeCrypt == sCodeArticleCrypt || notifCode == sCodeArticleCrypt) {
                print('✅ Notifier trouvé avec clé alternative: ${entry.key}');
                notifier = entry.value;
                // Mettre à jour la clé pour utiliser la bonne clé
                _articleNotifiers[articleKey] = notifier;
                if (entry.key != articleKey) {
                  _articleNotifiers.remove(entry.key);
                }
                break;
              }
            }
          }
          
          // ✅ CRITIQUE: Créer updatedArticle avec timestamp
          final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
          final updatedArticle = Map<String, dynamic>.from(articleToUpdate);
          updatedArticle['_lastUpdate'] = currentTimestamp;
          updatedArticle['iqte'] = quantity; // S'assurer que la quantité est correcte
          
          // ✅ CRITIQUE ÉTAPE 1: Mettre à jour _wishlistData EN PREMIER
          // Cela garantit que _buildArticlesContent verra la bonne valeur lors du rebuild
          final newPivotArray = List<dynamic>.from(pivotArray);
          newPivotArray[articleIndex] = articleToUpdate;
          _wishlistData = Map<String, dynamic>.from(_wishlistData!);
          _wishlistData!['pivotArray'] = newPivotArray;
          
          print('✅ ÉTAPE 1: _wishlistData mis à jour en premier');
          
          // ✅ CRITIQUE ÉTAPE 2: Mettre à jour le notifier APRÈS _wishlistData
          // Le ValueListenableBuilder se reconstruira automatiquement
          if (notifier == null) {
            print('⚠️ Notifier non trouvé, création pour: $sCodeArticleCrypt (clé: $articleKey)');
            notifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(updatedArticle));
            _articleNotifiers[articleKey] = notifier;
            print('✅ ÉTAPE 2: Nouveau notifier créé avec timestamp: iqte=$quantity (clé: $articleKey)');
            print('   📦 Notifiers disponibles: ${_articleNotifiers.keys.toList()}');
          } else {
            // ✅ CRITIQUE: Créer une NOUVELLE référence pour forcer la notification
            final oldValue = notifier.value['iqte'];
            // ✅ FORCER une nouvelle référence en créant un nouveau Map
            final newValue = Map<String, dynamic>.from(updatedArticle);
            // ✅ S'assurer que c'est vraiment une nouvelle référence
            newValue['_updateId'] = DateTime.now().millisecondsSinceEpoch;
            notifier.value = newValue;
            print('✅ ÉTAPE 2: Notifier mis à jour avec timestamp: iqte=$quantity (ancien: $oldValue, clé: $articleKey, timestamp: $currentTimestamp)');
            print('   📦 Valeur actuelle du notifier après mise à jour: ${notifier.value['iqte']}');
            print('   🔄 Nouvelle référence créée avec _updateId: ${newValue['_updateId']}');
          }
          
          // ✅ AUSSI: Mettre à jour tous les notifiers qui pourraient correspondre
          for (var entry in _articleNotifiers.entries) {
            final notifValue = entry.value.value;
            final notifCodeCrypt = notifValue['sCodeArticleCrypt']?.toString() ?? '';
            final notifCode = notifValue['sCodeArticle']?.toString() ?? '';
            
            if ((notifCodeCrypt == sCodeArticleCrypt || notifCode == sCodeArticleCrypt) && entry.key != articleKey) {
              final updatedCopy = Map<String, dynamic>.from(updatedArticle);
              entry.value.value = updatedCopy;
            }
          }
          
          // ✅ CRITIQUE: Le ValueListenableBuilder se reconstruira automatiquement quand notifier.value change
          // PAS besoin de setState() - cela causerait un rebuild prématuré qui pourrait écraser la valeur
          print('✅ Notifier mis à jour - ValueListenableBuilder se reconstruira automatiquement');
        }
      }
    } catch (e) {
      print('❌ Erreur _forceUpdateArticleNotifierSync: $e');
    }
  }

  /// Forcer la mise à jour du notifier d'un article (sans appel API) - Version async (pour compatibilité)
  /// Utile quand la quantité est identique mais qu'on veut garantir la synchronisation
  Future<void> _forceUpdateArticleNotifier(String sCodeArticleCrypt, int quantity) async {
    try {
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        final List<dynamic> pivotArray = List<dynamic>.from(_wishlistData!['pivotArray']);
        
        // Trouver l'article
        final articleIndex = pivotArray.indexWhere(
          (item) => item['sCodeArticleCrypt'] == sCodeArticleCrypt || item['sCodeArticle'] == sCodeArticleCrypt
        );
        
        if (articleIndex != -1) {
          final articleToUpdate = Map<String, dynamic>.from(pivotArray[articleIndex]);
          articleToUpdate['iqte'] = quantity;
          
          // ✅ CRITIQUE: Mettre à jour le notifier AVANT de mettre à jour _wishlistData
          final articleKey = _articleKey(articleToUpdate);
          ValueNotifier<Map<String, dynamic>>? notifier = _articleNotifiers[articleKey];
          
          if (notifier == null) {
            print('⚠️ Notifier non trouvé, création pour: $sCodeArticleCrypt');
            notifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(articleToUpdate));
            _articleNotifiers[articleKey] = notifier;
          }
          
          // ✅ FORCER la mise à jour avec une nouvelle référence AVANT de mettre à jour pivotArray
          final updatedArticle = Map<String, dynamic>.from(articleToUpdate);
          updatedArticle['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch;
          notifier.value = Map<String, dynamic>.from(updatedArticle);
          
          print('✅ Notifier forcé mis à jour AVANT pivotArray: $sCodeArticleCrypt, quantité: $quantity (clé: $articleKey)');
          
          // ✅ CRITIQUE: Mettre à jour aussi _wishlistData pour garantir la cohérence
          final newPivotArray = List<dynamic>.from(pivotArray);
          newPivotArray[articleIndex] = articleToUpdate;
          _wishlistData = Map<String, dynamic>.from(_wishlistData!);
          _wishlistData!['pivotArray'] = newPivotArray;
          
          // ✅ AUSSI: Mettre à jour tous les notifiers qui pourraient correspondre
          for (var entry in _articleNotifiers.entries) {
            final notifValue = entry.value.value;
            final notifCodeCrypt = notifValue['sCodeArticleCrypt']?.toString() ?? '';
            final notifCode = notifValue['sCodeArticle']?.toString() ?? '';
            
            if ((notifCodeCrypt == sCodeArticleCrypt || notifCode == sCodeArticleCrypt) && entry.key != articleKey) {
              final updatedCopy = Map<String, dynamic>.from(updatedArticle);
              entry.value.value = updatedCopy;
              print('✅ Notifier alternatif forcé mis à jour (clé: ${entry.key})');
            }
          }
          
          if (mounted) {
            setState(() {});
            print('✅ setState() appelé après _forceUpdateArticleNotifier');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur _forceUpdateArticleNotifier: $e');
    }
  }

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
          // ✅ CORRECTION: Créer une copie complète de l'article et mettre à jour la quantité
          final articleToUpdate = Map<String, dynamic>.from(pivotArray[articleIndex]);
          articleToUpdate['iqte'] = newQuantity;
          
          // ✅ CRITIQUE: Mettre à jour le notifier AVANT de mettre à jour _wishlistData
          // Cela garantit que le ValueListenableBuilder utilise la nouvelle valeur
          final articleKey = _articleKey(articleToUpdate);
          ValueNotifier<Map<String, dynamic>>? notifier = _articleNotifiers[articleKey];
          
          if (notifier == null) {
            // Créer le notifier s'il n'existe pas
            notifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(articleToUpdate));
            _articleNotifiers[articleKey] = notifier;
            print('✅ Notifier créé AVANT mise à jour pivotArray: clé=$articleKey, iqte=$newQuantity');
          } else {
            // Mettre à jour le notifier IMMÉDIATEMENT
            final updatedArticle = Map<String, dynamic>.from(articleToUpdate);
            updatedArticle['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch;
            notifier.value = Map<String, dynamic>.from(updatedArticle);
            print('✅ Notifier mis à jour AVANT pivotArray: clé=$articleKey, iqte=$newQuantity');
          }
          
          // ✅ CRITIQUE: Créer une nouvelle liste avec l'article mis à jour
          final newPivotArray = List<dynamic>.from(pivotArray);
          newPivotArray[articleIndex] = articleToUpdate;

          print('✅ Quantité locale mise à jour pour l\'article: ${articleToUpdate['sName']}');

          // ✅ CRITIQUE: Créer une nouvelle copie de meta pour forcer la détection du changement
          Map<String, dynamic> newMeta = {};
          if (_wishlistData!['meta'] != null) {
            newMeta = Map<String, dynamic>.from(_wishlistData!['meta']);
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
                  newMeta[key] = totals[key];
                }
              }
              
              print('✅ Totaux mis à jour');
            }
          }
          
          // ✅ CRITIQUE: Créer une NOUVELLE référence de _wishlistData pour forcer Flutter à détecter le changement
          _wishlistData = Map<String, dynamic>.from(_wishlistData!);
          _wishlistData!['pivotArray'] = newPivotArray;
          _wishlistData!['meta'] = newMeta;

          // ✅ Le notifier a déjà été mis à jour AVANT (voir plus haut aux lignes 2002-2016)
          // Vérifier que le notifier est bien synchronisé avec articleToUpdate
          if (notifier != null) {
            // Vérifier que le notifier a bien la bonne valeur
            if (notifier.value['iqte'] != newQuantity) {
              // Forcer la mise à jour si nécessaire
              final updatedArticle = Map<String, dynamic>.from(articleToUpdate);
              updatedArticle['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch;
              notifier.value = Map<String, dynamic>.from(updatedArticle);
              print('✅ Notifier resynchronisé: iqte=${notifier.value['iqte']}');
            }
            
            // ✅ AUSSI: Mettre à jour tous les notifiers qui pourraient correspondre
            for (var entry in _articleNotifiers.entries) {
              final notifValue = entry.value.value;
              final notifCodeCrypt = notifValue['sCodeArticleCrypt']?.toString() ?? '';
              final notifCode = notifValue['sCodeArticle']?.toString() ?? '';
              
              if ((notifCodeCrypt == sCodeArticleCrypt || notifCode == sCodeArticleCrypt) && entry.key != articleKey) {
                final updatedCopy = Map<String, dynamic>.from(articleToUpdate);
                updatedCopy['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch;
                entry.value.value = updatedCopy;
                print('✅ Notifier alternatif mis à jour (clé: ${entry.key})');
              }
            }
            
            print('✅ ValueNotifier final: iqte=${notifier.value['iqte']} (clé: $articleKey)');
          } else {
            print('⚠️ Notifier non trouvé après mise à jour pivotArray, création...');
            notifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(articleToUpdate));
            _articleNotifiers[articleKey] = notifier;
            print('✅ Nouveau notifier créé: iqte=${notifier.value['iqte']} (clé: $articleKey)');
          }
        }
        
        // ✅ CRITIQUE: Appeler setState() APRÈS avoir mis à jour le notifier et créé de nouvelles références
        // pour garantir que l'UI se rebuild avec les nouvelles données
        if (mounted) {
          setState(() {});
          print('✅ Interface mise à jour - quantité devrait s\'afficher immédiatement');
        }
        
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
      // ✅ Vérifier si un pays est sélectionné (comme SNAL isCountrySelected)
      final rawSpaysSelected = article['spaysSelected'] ?? article['sPaysSelected'];
      final bool isCountrySelected = rawSpaysSelected != null && 
                                     rawSpaysSelected != '' && 
                                     rawSpaysSelected != false &&
                                     rawSpaysSelected != '-1' &&
                                     rawSpaysSelected.toString().trim().isNotEmpty;
      
      // ✅ Utiliser defaultSelectedCountry si fourni ET si un pays est sélectionné, sinon utiliser spaysSelected s'il est valide, sinon vide
      // Si isCountrySelected est false, ne pas utiliser defaultSelectedCountry (même s'il est fourni)
      final currentSelectedCountry = isCountrySelected
          ? ((defaultSelectedCountry?.toString() ?? '').isNotEmpty
              ? defaultSelectedCountry!.toString()
              : rawSpaysSelected.toString().trim())
          : '';
      
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
          // ✅ Récupérer le prix de CET article pour ce pays (comme SNAL: item[countryCode])
          // Le backend stocke les prix avec des codes ISO directement (FR, DE, NL, PT, etc.)
          String priceStr = article[code]?.toString() ?? '';
          
          if (priceStr.isNotEmpty) {
            print('💰 Prix trouvé pour $code: "$priceStr"');
          } else {
            print('⚠️ Prix non trouvé pour $code dans l\'article');
            // ✅ Vérifier toutes les clés de pays dans l'article pour debug
            final countryKeys = article.keys.where((k) => 
              k.length == 2 && 
              k.toUpperCase() == k && 
              RegExp(r'^[A-Z]{2}$').hasMatch(k)
            ).toList();
            print('   📋 Clés de pays disponibles dans l\'article: $countryKeys');
          }
          
          // ✅ Logique comme SNAL: si priceStr est null, undefined, vide, ou "Indisponible" → indisponible
          // Sinon → disponible (même si c'est "Floute" ou autre)
          final isPriceAvailable = priceStr.isNotEmpty && 
                                   priceStr.toLowerCase() != 'n/a' &&
                                   priceStr.toLowerCase() != 'indisponible' &&
                                   priceStr.toLowerCase() != 'unavailable';
          
          // ✅ Corriger l'URL du drapeau (éviter le double https://jirig.be)
          final flagUrl = _normalizeFlagUrl(flag);
          
          // ✅ Formatage du prix pour l'affichage (comme SNAL)
          String displayPrice = priceStr;
          if (priceStr.isEmpty || !isPriceAvailable) {
            displayPrice = 'N/A'; // Sera traduit en "Indisponible" dans l'UI
          }
          
          print('🖼️ URL drapeau final: $flagUrl');
          print('💰 Prix final pour $code: "$displayPrice" (disponible: $isPriceAvailable)');
          
          allCountries.add({
            'code': code,
            'name': name.isNotEmpty ? name : code, // ✅ Fallback sur le code si nom manquant
            'flag': flagUrl, // ✅ URL avec proxy
            'price': displayPrice, // ✅ Prix réel pour cet article (ou "N/A" si indisponible)
            'isAvailable': isPriceAvailable, // ✅ Indique si le prix est disponible (comme SNAL)
          });
        } else if (code == 'AT' || code == 'CH') {
          print('🚫 Pays exclu: $code (${code == 'AT' ? 'Autriche' : 'Suisse'})');
        }
      }
      
      print('✅ ${allCountries.length} pays préparés pour le modal depuis get-infos-status');
      print('🌍 Tous les pays disponibles pour l\'article: ${allCountries.map((c) => c['code']).toList()}');
      print('🌍 Pays actuellement sélectionné: $currentSelectedCountry');
      
      // ✅ Récupérer aussi tous les pays disponibles (pas seulement ceux avec un prix pour cet article)
      // Cela permet d'afficher les pays sélectionnés dans CountryManagementModal même s'ils n'ont pas de prix pour cet article
      final allAvailableCountries = _getAllAvailableCountries();
      print('🌍 Tous les pays disponibles (tous pays): ${allAvailableCountries.map((c) => c['code']).toList()}');
      
      // ✅ Ne PAS filtrer ici - passer tous les pays disponibles à CountrySidebarModal
      // Le filtrage se fera dans CountrySidebarModal selon les pays sélectionnés dans localStorage
      // Cela permet d'afficher les nouveaux pays sélectionnés dans CountryManagementModal
      
      // ✅ Créer un NOUVEAU ValueNotifier local pour le modal (copie de l'article)
      // Cela évite les problèmes de dispose car chaque modal a son propre ValueNotifier
      final modalNotifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(article));
      
      // ✅ Si un articleNotifier est fourni, écouter ses changements et mettre à jour le modalNotifier
      ValueNotifier<Map<String, dynamic>>? sourceNotifier = articleNotifier;
      VoidCallback? syncListener;
      
      if (sourceNotifier != null) {
        // Écouter les changements du sourceNotifier et les propager au modalNotifier
        syncListener = () {
          try {
            if (modalNotifier.value.isNotEmpty) {
              // ✅ Copier toutes les données depuis sourceNotifier, y compris les prix pour tous les pays
              final sourceValue = sourceNotifier!.value;
              final updatedValue = Map<String, dynamic>.from(sourceValue);
              
              // ✅ Debug: Vérifier les prix dans sourceNotifier
              print('🔄 syncListener - Clés de pays dans sourceNotifier: ${sourceValue.keys.where((k) => k.length == 2 && k.toUpperCase() == k).toList()}');
              
              // ✅ S'assurer que tous les prix sont copiés (y compris ceux des nouveaux pays sélectionnés)
              modalNotifier.value = updatedValue;
              print('🔄 modalNotifier mis à jour depuis sourceNotifier');
            }
          } catch (e) {
            // Le sourceNotifier a été disposé, ignorer
            print('⚠️ Source notifier disposé, arrêt de la synchronisation: $e');
          }
        };
        sourceNotifier.addListener(syncListener);
      }
      
      // ✅ Utiliser showModalBottomSheet pour un vrai sidebar plein écran
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext modalContext) {
          return _CountrySidebarModal(
            articleNotifier: modalNotifier,
            availableCountries: allCountries,
            allAvailableCountries: allAvailableCountries,
            currentSelected: currentSelectedCountry,
            homeCountryCode: _getHomeCountryCode(article),
            onCountrySelected: (String countryCode) async {
              // Ne PAS fermer le modal - il restera ouvert et se mettra à jour
              await _changeArticleCountry(article, countryCode, sourceNotifier);
            },
            onManageCountries: () => _openCountryManagementModal(
              presentationContext: modalContext,
              articleNotifier: sourceNotifier,
              modalNotifier: modalNotifier,
            ),
          );
        },
      ).whenComplete(() {
        _isCountrySidebarOpen = false;
        // Nettoyer le listener et disposer le modalNotifier
        if (syncListener != null && sourceNotifier != null) {
          try {
            sourceNotifier.removeListener(syncListener);
          } catch (e) {
            print('⚠️ Erreur lors du retrait du listener: $e');
          }
        }
        try {
          modalNotifier.dispose();
        } catch (e) {
          print('⚠️ Erreur lors de la disposition du modalNotifier: $e');
        }
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
  /// Affiche le popup de localisation avant d'ouvrir la carte si nécessaire
  Future<void> _toggleMapView() async {
    // Si on ferme la carte, simplement la fermer
    if (_showMap) {
      setState(() {
        _showMap = false;
      });
      return;
    }

    // Si on ouvre la carte, vérifier si le popup doit être affiché
    final shouldShowPopup = await _shouldShowLocationInfo();
    
    if (shouldShowPopup && mounted) {
      // Afficher le popup avant d'ouvrir la carte
      final bool? accepted = await LocationInfoDialog.show(context);
      
      // Sauvegarder le choix
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_info_shown', true);
      await prefs.setBool('location_permission_refused', accepted == false);
      
      if (accepted == true && mounted) {
        // Si l'utilisateur accepte, demander la permission
        await _requestLocationPermission();
      } else if (accepted == false && mounted) {
        // Si l'utilisateur refuse, afficher un message informatif
        _showLocationRefusedMessage();
      }
    }
    
    // Ouvrir la carte après le popup (ou directement si pas de popup)
    if (mounted) {
      setState(() {
        _showMap = true;
      });
    }
  }

  /// Vérifier si le popup de localisation doit être affiché
  Future<bool> _shouldShowLocationInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const String locationInfoShownKey = 'location_info_shown';
      
      // Vérifier si le popup a déjà été affiché
      final bool hasShown = prefs.getBool(locationInfoShownKey) ?? false;
      
      return !hasShown;
    } catch (e) {
      print('⚠️ Erreur lors de la vérification du popup: $e');
      return false;
    }
  }

  /// Demander la permission de localisation
  Future<void> _requestLocationPermission() async {
    try {
      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        print('⚠️ Service de localisation désactivé');
        if (mounted) {
          _showLocationServiceDisabledMessage();
        }
        return;
      }

      // Vérifier la permission actuelle
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Demander la permission
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          print('❌ Permission de localisation refusée');
          if (mounted) {
            _showLocationRefusedMessage();
          }
        } else {
          print('✅ Permission de localisation accordée');
          // Sauvegarder que la permission a été accordée
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('location_permission_refused', false);
        }
      } else if (permission == LocationPermission.deniedForever) {
        print('❌ Permission de localisation refusée définitivement');
        if (mounted) {
          _showLocationDeniedForeverMessage();
        }
      } else {
        print('✅ Permission de localisation déjà accordée');
        // Sauvegarder que la permission a été accordée
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('location_permission_refused', false);
      }
    } catch (e) {
      print('❌ Erreur lors de la demande de permission: $e');
    }
  }

  /// Afficher un message informatif lorsque l'utilisateur refuse la localisation
  void _showLocationRefusedMessage() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'L\'application fonctionnera normalement. La carte utilisera une position par défaut.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Afficher un message lorsque le service de localisation est désactivé
  void _showLocationServiceDisabledMessage() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.location_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Le service de localisation est désactivé. Activez-le dans les paramètres pour utiliser la carte.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Afficher un message lorsque la permission est refusée définitivement
  void _showLocationDeniedForeverMessage() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.settings, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pour activer la localisation, allez dans les paramètres de l\'application.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Paramètres',
          textColor: Colors.white,
          onPressed: () async {
            await Geolocator.openLocationSettings();
          },
        ),
      ),
    );
  }

  Future<_CountryManagementData?> _prepareCountryManagementData() async {
    print('🔧 Préparation des données pour la gestion des pays');
    try {
      final infosStatus = await _apiService.getInfosStatus();
      if (mounted) {
    setState(() {
          _wishlistData?['infosStatus'] = infosStatus;
        });
      }
      print('✅ Données get-infos-status récupérées pour la gestion des pays');
    } catch (e) {
      print('⚠️ Impossible de récupérer get-infos-status: $e');
    }

    if (!mounted) {
      return null;
    }

      final selectedCountries = await _getCurrentSelectedCountries();
      final primaryCountryCode = await _getPrimaryCountryCode();
      // ✅ Ne pas ajouter le primaryCountryCode s'il est AT ou CH
      if (primaryCountryCode != null && 
          primaryCountryCode.isNotEmpty && 
          primaryCountryCode != 'AT' && 
          primaryCountryCode != 'CH' &&
          !selectedCountries.contains(primaryCountryCode)) {
        selectedCountries.add(primaryCountryCode);
      }

    final uniqueSelected = selectedCountries.map((c) => c.toUpperCase()).toSet().toList();
    final availableCountries = _getAllAvailableCountries();

    return _CountryManagementData(
      availableCountries: availableCountries,
      selectedCountries: uniqueSelected,
            lockedCountryCode: primaryCountryCode,
    );
  }

  /// Ouvrir le modal de gestion des pays (comme SNAL openModalCountryFromSlideover)
  Future<List<Map<String, dynamic>>?> _openCountryManagementModal({
    BuildContext? presentationContext,
    ValueNotifier<Map<String, dynamic>>? articleNotifier,
    ValueNotifier<Map<String, dynamic>>? modalNotifier,
  }) async {
    print('🔧 Ouverture du modal de gestion des pays');
    final dialogBaseContext = presentationContext ?? (mounted ? context : null);
    if (dialogBaseContext == null) {
      print('⚠️ Impossible d\'ouvrir le modal: contexte invalide');
      return null;
    }

    final data = await _prepareCountryManagementData();
    if (data == null) {
      print('⚠️ Données de gestion des pays indisponibles');
      return null;
    }

    final updatedCountries = await showGeneralDialog<List<Map<String, dynamic>>>(
      context: dialogBaseContext,
      barrierDismissible: true,
      barrierLabel: 'country-management',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;
        final isMobile = size.width < 768; // ✅ Utiliser 768 comme seuil pour mobile (cohérent avec le reste de l'app)
        final isVerySmallMobile = size.width < 361;
        final isSmallMobile = size.width < 431;
        
        // ✅ Utiliser une hauteur maximale adaptative pour tous les écrans mobiles
        final maxHeight = isMobile 
            ? (isVerySmallMobile ? size.height * 0.80 : (isSmallMobile ? size.height * 0.82 : size.height * 0.85))
            : size.height * 0.75;
        final maxWidth = isMobile 
            ? (isVerySmallMobile ? size.width * 0.92 : (isSmallMobile ? size.width * 0.94 : size.width * 0.95))
            : size.width * 0.6;

        return SafeArea(
          child: Align(
            alignment: Alignment.center, // ✅ Centrer le modal sur tous les écrans
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                maxWidth: maxWidth,
              ),
              child: _CountryManagementModal(
                availableCountries: data.availableCountries,
                selectedCountries: data.selectedCountries,
                lockedCountryCode: data.lockedCountryCode,
                onSave: (selectedCountries) => _saveCountryChanges(
                  selectedCountries,
                  articleNotifier: articleNotifier,
                  modalNotifier: modalNotifier,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        // ✅ Animation d'apparition : scale + fade
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
    
    // ✅ CORRECTION: Ne pas rediriger vers /wishlist
    // Le CountrySidebarModal restera ouvert après la fermeture du CountryManagementModal
    // Cela permet à l'utilisateur de continuer à sélectionner un pays pour l'article
    
    return updatedCountries;
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
          String flagCandidate = flagMap[code]?.toString() ?? '';
          if (flagCandidate.isEmpty || flagCandidate.startsWith('#')) {
            flagCandidate = pays['sFlag']?.toString() ?? '';
          }
          final normalizedFlag = _normalizeFlagUrl(flagCandidate);

          return {
            'code': code,
            'name': pays['sDescr']?.toString() ?? code,
            'flag': normalizedFlag,
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
      
      return paysListe.map((pays) {
        final code = pays['sPays']?.toString() ?? '';
        final normalizedFlag = _normalizeFlagUrl(pays['sFlag']?.toString());

        return {
          'code': code,
          'name': pays['sDescr']?.toString() ?? pays['sPays']?.toString() ?? code,
          'flag': normalizedFlag,
        };
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
  /// Ce pays est verrouillé dans le modal et ne change PAS quand on change de langue
  Future<String?> _getPrimaryCountryCode() async {
    try {
      // ✅ Récupérer le pays depuis SettingsService.getSelectedCountry() (choisi lors de l'onboarding)
      // Ce pays est sauvegardé lors de l'onboarding et ne doit PAS être modifié par custom_app_bar
      // même si l'utilisateur change de langue (seul sPaysLangue change dans le profil)
      final settingsService = SettingsService();
      final selectedCountry = await settingsService.getSelectedCountry(); // ✅ Toujours lire depuis les paramètres sauvegardés
      final code = selectedCountry?.sPays?.toString().toUpperCase();
      
      if (code != null && code.isNotEmpty) {
        print('✅ Pays verrouillé depuis SettingsService (onboarding): $code');
        return code;
      }
      
      // ✅ Fallback: Si SettingsService n'a pas de pays, extraire depuis sPaysLangue du profil
      // (mais ce n'est pas idéal car sPaysLangue peut changer avec la langue)
      print('⚠️ SettingsService.selectedCountry non disponible, fallback vers sPaysLangue');
      final profile = await LocalStorageService.getProfile();
      final sPaysLangue = profile?['sPaysLangue']?.toString() ?? '';
      
      if (sPaysLangue.isNotEmpty) {
        // sPaysLangue est au format "BE/FR" ou "FR/FR" - extraire les 2 premiers caractères (code pays)
        final countryCode = sPaysLangue.split('/').first.toUpperCase();
        if (countryCode.length == 2) {
          print('⚠️ Pays verrouillé depuis sPaysLangue (fallback): $countryCode');
          return countryCode;
        }
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
      // ✅ Filtrer AT et CH qui ne figurent pas dans le projet
      final normalizedSaved = _normalizeCountriesList(savedCountries)
          .where((code) => code != 'AT' && code != 'CH')
          .toList();
      if (normalizedSaved.isNotEmpty) {
        final primaryCountryCode = await _getPrimaryCountryCode();
        // ✅ Ne pas ajouter le primaryCountryCode s'il est AT ou CH
        if (primaryCountryCode != null && 
            primaryCountryCode != 'AT' && 
            primaryCountryCode != 'CH' &&
            !normalizedSaved.contains(primaryCountryCode)) {
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
      // ✅ Ne pas ajouter le primaryCountryCode s'il est AT ou CH
      if (primaryCountryCode != null && 
          primaryCountryCode.isNotEmpty && 
          primaryCountryCode != 'AT' && 
          primaryCountryCode != 'CH' &&
          !countries.contains(primaryCountryCode)) {
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
  Future<List<Map<String, dynamic>>?> _saveCountryChanges(
    List<String> selectedCountries, {
    ValueNotifier<Map<String, dynamic>>? articleNotifier,
    ValueNotifier<Map<String, dynamic>>? modalNotifier,
  }) async {
    print('💾 Sauvegarde des changements de pays: $selectedCountries');
    
    // ✅ Construire les métadonnées (nom, drapeau) pour les pays sélectionnés AVANT les blocs try-catch
    // Cela permet d'utiliser metadataByCode dans les return statements des catch/if
    final allMetadata = _getAllAvailableCountries();
    final metadataByCode = {
      for (final country in allMetadata)
        (country['code']?.toString().toUpperCase() ?? ''): country,
    };
    
    try {
      final normalizedCountries = LinkedHashSet<String>.from(
        selectedCountries.map((c) => c.toUpperCase()).where((c) => c.isNotEmpty),
      ).toList();
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
        return null;
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
        
        // ✅ CORRECTION CRITIQUE: Mettre à jour modalNotifier IMMÉDIATEMENT après le rechargement
        // Cela garantit que le modal affiche les nouveaux prix dès que les données sont chargées
        if (modalNotifier != null && _wishlistData != null) {
          try {
            final pivotArray = _wishlistData!['pivotArray'] as List? ?? [];
            if (pivotArray.isNotEmpty) {
              // ✅ Récupérer le sCodeArticleCrypt depuis le modalNotifier actuel pour trouver le bon article
              final currentModalArticle = modalNotifier.value;
              final modalArticleCrypt = currentModalArticle['sCodeArticleCrypt']?.toString() ?? '';
              
              // ✅ Chercher l'article correspondant dans pivotArray
              Map<String, dynamic>? articleToUse;
              if (modalArticleCrypt.isNotEmpty) {
                for (final item in pivotArray) {
                  final itemCrypt = item['sCodeArticleCrypt']?.toString() ?? '';
                  if (itemCrypt == modalArticleCrypt) {
                    articleToUse = item as Map<String, dynamic>;
                    print('✅ Article trouvé dans pivotArray pour modalNotifier: $modalArticleCrypt');
                    break;
                  }
                }
              }
              
              // ✅ Si pas trouvé, utiliser le premier article de pivotArray
              if (articleToUse == null && pivotArray.isNotEmpty) {
                articleToUse = pivotArray[0] as Map<String, dynamic>;
                print('⚠️ Article non trouvé, utilisation du premier article de pivotArray pour modalNotifier');
              }
              
              if (articleToUse != null) {
                // ✅ Créer une copie complète avec TOUS les prix depuis pivotArray
                final updatedArticle = Map<String, dynamic>.from(articleToUse);
                modalNotifier.value = updatedArticle;
                print('✅ modalNotifier mis à jour IMMÉDIATEMENT depuis pivotArray après rechargement');
                print('   📦 Clés de pays dans modalNotifier: ${updatedArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k)).toList()}');
                for (final key in updatedArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k))) {
                  print('   💰 $key: ${updatedArticle[key]}');
                }
              }
            }
          } catch (e) {
            print('⚠️ Erreur lors de la mise à jour immédiate du modalNotifier: $e');
          }
        }

        // Mettre à jour l'article dans le notifier si fourni (pour mettre à jour le SidebarModal)
        if (articleNotifier != null) {
          try {
            // Attendre un peu pour s'assurer que localStorage est bien synchronisé
            await Future.delayed(const Duration(milliseconds: 300));
            
            // Vérifier si le notifier est toujours valide en accédant à sa valeur
            final currentArticle = articleNotifier.value;
            final sCodeArticleCrypt = currentArticle['sCodeArticleCrypt']?.toString() ?? '';
            
            if (sCodeArticleCrypt.isNotEmpty) {
              // Trouver l'article mis à jour dans la wishlist
              final pivotArray = _wishlistData?['pivotArray'] as List? ?? [];
              
              // ✅ Debug: Vérifier le contenu de pivotArray
              print('📦 pivotArray contient ${pivotArray.length} articles');
              if (pivotArray.isNotEmpty) {
                final firstArticle = pivotArray[0] as Map<String, dynamic>?;
                if (firstArticle != null) {
                  print('📦 Premier article - clés de pays: ${firstArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k).toList()}');
                  print('📦 Premier article - ES: ${firstArticle['ES']}, FR: ${firstArticle['FR']}, PT: ${firstArticle['PT']}');
                }
              }
              
              // ✅ Chercher l'article dans pivotArray
              Map<String, dynamic>? foundArticle;
              for (final item in pivotArray) {
                final itemCrypt = item['sCodeArticleCrypt']?.toString() ?? '';
                if (itemCrypt == sCodeArticleCrypt) {
                  foundArticle = item as Map<String, dynamic>?;
                  print('✅ Article trouvé dans pivotArray avec sCodeArticleCrypt: $sCodeArticleCrypt');
                  break;
                }
              }
              
              // ✅ Si l'article n'est pas trouvé, utiliser le premier article de pivotArray (au cas où sCodeArticleCrypt a changé)
              if (foundArticle == null && pivotArray.isNotEmpty) {
                foundArticle = pivotArray[0] as Map<String, dynamic>?;
                print('⚠️ Article non trouvé avec sCodeArticleCrypt, utilisation du premier article de pivotArray');
                print('📦 Premier article - sCodeArticleCrypt: ${foundArticle?['sCodeArticleCrypt']}');
              }
              
              // ✅ Utiliser l'article trouvé ou l'article original
              final updatedArticle = foundArticle ?? currentArticle;
              
              // ✅ Debug: Vérifier quel article est utilisé
              if (foundArticle != null) {
                print('📦 Utilisation de l\'article depuis pivotArray');
                print('📦 Article trouvé - sCodeArticleCrypt: ${foundArticle['sCodeArticleCrypt']}');
                final countryKeys = foundArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k)).toList();
                print('📦 Article trouvé - clés de pays: $countryKeys');
                for (final key in countryKeys) {
                  print('   💰 $key: ${foundArticle[key]}');
                }
              } else {
                print('⚠️ Article non trouvé dans pivotArray, utilisation de currentArticle');
              }
              
              // ✅ CORRECTION CRITIQUE: Copier TOUS les prix directement depuis pivotArray
              // Le backend retourne TOUS les prix dans pivotArray (FR, PT, NL, etc.)
              // Il faut les copier TOUS dès le début, sans vérifications multiples
              
              // ✅ D'abord, trouver l'article dans pivotArray qui correspond à sCodeArticleCrypt
              Map<String, dynamic>? articleFromPivot;
              for (final item in pivotArray) {
                final itemCrypt = item['sCodeArticleCrypt']?.toString() ?? '';
                if (itemCrypt == sCodeArticleCrypt) {
                  articleFromPivot = item as Map<String, dynamic>;
                  print('✅ Article trouvé dans pivotArray: $sCodeArticleCrypt');
                  break;
                }
              }
              
              // ✅ Si pas trouvé, utiliser le premier article de pivotArray
              if (articleFromPivot == null && pivotArray.isNotEmpty) {
                articleFromPivot = pivotArray[0] as Map<String, dynamic>;
                print('⚠️ Article non trouvé, utilisation du premier article de pivotArray');
              }
              
              // ✅ Créer une copie PROFONDE de l'article avec TOUTES les propriétés
              // Utiliser l'article depuis pivotArray qui contient TOUS les prix
              final updatedArticleCopy = Map<String, dynamic>.from(articleFromPivot ?? updatedArticle);
              
              // ✅ CORRECTION CRITIQUE: Copier TOUS les prix depuis articleFromPivot (qui vient de pivotArray)
              // Le backend retourne TOUS les prix dans pivotArray (FR: "9.99 €", PT: "9.99 €", NL: "9.99 €")
              // Il faut les copier TOUS, même ceux qui ne sont pas dans normalizedCountries
              if (articleFromPivot != null) {
                print('📦 Copie de TOUS les prix depuis articleFromPivot (pivotArray)...');
                final allCountryKeys = articleFromPivot.keys.where((k) => 
                  k.length == 2 && 
                  k.toUpperCase() == k && 
                  RegExp(r'^[A-Z]{2}$').hasMatch(k)
                ).toList();
                print('   📋 Clés de pays trouvées: $allCountryKeys');
                
                // ✅ Copier TOUS les prix depuis articleFromPivot
                for (final key in allCountryKeys) {
                  final priceValue = articleFromPivot[key];
                  updatedArticleCopy[key] = priceValue; // ✅ Copier même si null
                  print('   ✅ Prix $key copié: $priceValue');
                }
              }
              
              print('🔍 Vérification des prix pour les pays sélectionnés: $normalizedCountries');
              for (final countryCode in normalizedCountries) {
                final upperCode = countryCode.toUpperCase();
                if (updatedArticleCopy.containsKey(upperCode)) {
                  print('   ✅ $upperCode: ${updatedArticleCopy[upperCode]}');
                } else {
                  print('   ❌ $upperCode: MANQUANT dans updatedArticleCopy');
                }
              }
              
              // ✅ Debug: Vérifier les prix disponibles dans l'article mis à jour
              print('📦 Article mis à jour - sCodeArticleCrypt: ${updatedArticleCopy['sCodeArticleCrypt']}');
              print('📦 Article mis à jour - TOUTES les clés: ${updatedArticleCopy.keys.toList()}');
              
              // ✅ Vérifier TOUS les pays disponibles dans l'article (pas seulement ceux normalisés)
              final allCountryKeysInUpdated = updatedArticleCopy.keys.where((k) => 
                k.length == 2 && 
                k.toUpperCase() == k && 
                RegExp(r'^[A-Z]{2}$').hasMatch(k)
              ).toList();
              print('📦 Tous les pays avec prix dans updatedArticle: $allCountryKeysInUpdated');
              for (final countryKey in allCountryKeysInUpdated) {
                print('   💰 $countryKey: ${updatedArticleCopy[countryKey]}');
              }
              
              // Vérifier que les pays sélectionnés sont bien dans localStorage
              final storedCountries = await LocalStorageService.getSelectedCountries();
              print('📋 Pays dans localStorage après sauvegarde: $storedCountries');
              print('📋 Pays normalisés: $normalizedCountries');
              
              // ✅ S'assurer que TOUS les prix pour TOUS les pays sélectionnés sont présents dans l'article
              // Si un prix manque, essayer de le récupérer depuis pivotArray directement
              for (final countryCode in normalizedCountries) {
                final upperCode = countryCode.toUpperCase();
                if (!updatedArticleCopy.containsKey(upperCode) || 
                    updatedArticleCopy[upperCode] == null ||
                    updatedArticleCopy[upperCode].toString().trim().isEmpty) {
                  print('⚠️ Pas de prix pour $upperCode dans updatedArticle - chercher dans pivotArray');
                  
                  // ✅ Chercher le prix directement dans tous les articles de pivotArray
                  bool priceFound = false;
                  
                  // ✅ D'abord, chercher dans l'article avec le même sCodeArticleCrypt
                  // ✅ CORRECTION: Copier même si c'est "Indisponible" ou null
                  for (final item in pivotArray) {
                    final itemCrypt = item['sCodeArticleCrypt']?.toString() ?? '';
                    if (itemCrypt == sCodeArticleCrypt) {
                      if (item.containsKey(upperCode)) {
                        // ✅ Copier même si c'est null ou "Indisponible"
                        updatedArticleCopy[upperCode] = item[upperCode];
                        print('✅ Prix pour $upperCode copié depuis pivotArray (même sCodeArticleCrypt): ${item[upperCode]}');
                        priceFound = true;
                        break;
                      }
                    }
                  }
                  
                  // ✅ Si pas trouvé, chercher dans tous les articles de pivotArray (au cas où sCodeArticleCrypt a changé)
                  // ✅ CORRECTION: Copier même si c'est "Indisponible" ou null
                  if (!priceFound) {
                    for (final item in pivotArray) {
                      if (item.containsKey(upperCode)) {
                        // ✅ Copier même si c'est null ou "Indisponible"
                        updatedArticleCopy[upperCode] = item[upperCode];
                        print('✅ Prix pour $upperCode copié depuis pivotArray (n\'importe quel article): ${item[upperCode]}');
                        priceFound = true;
                        break;
                      }
                    }
                  }
                  
                  // ✅ Si toujours pas trouvé, essayer depuis currentArticle
                  // ✅ CORRECTION: Copier même si c'est "Indisponible" ou null
                  if (!priceFound && currentArticle.containsKey(upperCode)) {
                    updatedArticleCopy[upperCode] = currentArticle[upperCode];
                    print('✅ Prix pour $upperCode copié depuis currentArticle: ${currentArticle[upperCode]}');
                  } else if (!priceFound) {
                    print('⚠️ Prix pour $upperCode non disponible nulle part');
                  }
                } else {
                  final price = updatedArticleCopy[upperCode];
                  print('✅ Prix pour $upperCode présent dans updatedArticle: $price (type: ${price.runtimeType})');
                }
              }
              
              // ✅ IMPORTANT: Copier TOUS les prix depuis pivotArray (pas seulement ceux des pays sélectionnés)
              // Le backend retourne tous les prix dans pivotArray (FR, DE, NL, PT, etc.)
              // Il faut les copier TOUS pour que _buildCountryDetails puisse les trouver
              if (foundArticle != null) {
                // ✅ CORRECTION CRITIQUE: Copier TOUS les prix depuis foundArticle (qui vient de pivotArray)
                // Même ceux qui sont "Indisponible" ou null
                for (final key in foundArticle.keys) {
                  // ✅ Copier toutes les clés qui sont des codes de pays (2 lettres majuscules)
                  if (key.length == 2 && 
                      key.toUpperCase() == key && 
                      RegExp(r'^[A-Z]{2}$').hasMatch(key)) {
                    final priceValue = foundArticle[key];
                    // ✅ CORRECTION: Copier TOUJOURS, même si c'est null, "Indisponible", ou vide
                    updatedArticleCopy[key] = priceValue; // ✅ Copier même si null
                    if (priceValue != null && priceValue.toString().trim().isNotEmpty) {
                      print('✅ Prix $key copié depuis foundArticle: $priceValue');
                    } else {
                      print('⚠️ Prix $key copié depuis foundArticle (null/vide/indisponible): $priceValue');
                    }
                  }
                }
              } else {
                // ✅ Si foundArticle est null, chercher dans tous les articles de pivotArray
                // ✅ CORRECTION CRITIQUE: Copier TOUS les prix, même ceux qui sont "Indisponible" ou null
                for (final item in pivotArray) {
                  final itemCrypt = item['sCodeArticleCrypt']?.toString() ?? '';
                  if (itemCrypt == sCodeArticleCrypt) {
                    // ✅ Copier TOUS les prix depuis cet article
                    for (final key in item.keys) {
                      if (key.length == 2 && 
                          key.toUpperCase() == key && 
                          RegExp(r'^[A-Z]{2}$').hasMatch(key)) {
                        final priceValue = item[key];
                        // ✅ CORRECTION: Copier TOUJOURS, même si c'est null, "Indisponible", ou vide
                        updatedArticleCopy[key] = priceValue; // ✅ Copier même si null
                        if (priceValue != null && priceValue.toString().trim().isNotEmpty) {
                          print('✅ Prix $key copié depuis pivotArray: $priceValue');
                        } else {
                          print('⚠️ Prix $key copié depuis pivotArray (null/vide/indisponible): $priceValue');
                        }
                      }
                    }
                    break;
                  }
                }
              }
              
              // ✅ S'assurer que TOUS les prix des pays sélectionnés sont présents dans updatedArticleCopy
              // Vérifier une dernière fois et copier depuis pivotArray si nécessaire
              for (final countryCode in normalizedCountries) {
                final upperCode = countryCode.toUpperCase();
                if (!updatedArticleCopy.containsKey(upperCode) || 
                    updatedArticleCopy[upperCode] == null ||
                    updatedArticleCopy[upperCode].toString().trim().isEmpty) {
                  // Chercher dans tous les articles de pivotArray
                  // ✅ CORRECTION: Copier même si c'est "Indisponible" ou null
                  for (final item in pivotArray) {
                    if (item.containsKey(upperCode)) {
                      // ✅ Copier même si c'est null ou "Indisponible"
                      updatedArticleCopy[upperCode] = item[upperCode];
                      print('✅ Prix pour $upperCode copié depuis pivotArray (vérification finale): ${item[upperCode]}');
                      break;
                    }
                  }
                }
              }
              
              // ✅ CORRECTION CRITIQUE: Copier TOUS les prix depuis pivotArray, même "Indisponible"
              // Le backend retourne TOUS les prix dans pivotArray (BE, DE, ES, IT, NL, etc.)
              // Il faut les copier TOUS (y compris "Indisponible") pour que _buildCountryDetails puisse les trouver
              
              // ✅ D'abord, utiliser foundArticle s'il existe
              Map<String, dynamic>? sourceArticle = foundArticle;
              
              // ✅ Si foundArticle est null, chercher dans tous les articles de pivotArray
              if (sourceArticle == null) {
                for (final item in pivotArray) {
                  final itemCrypt = item['sCodeArticleCrypt']?.toString() ?? '';
                  if (itemCrypt == sCodeArticleCrypt) {
                    sourceArticle = item as Map<String, dynamic>?;
                    print('✅ Article trouvé dans pivotArray avec sCodeArticleCrypt: $sCodeArticleCrypt');
                    break;
                  }
                }
              }
              
              // ✅ Si toujours null, utiliser le premier article de pivotArray (fallback)
              if (sourceArticle == null && pivotArray.isNotEmpty) {
                sourceArticle = pivotArray[0] as Map<String, dynamic>?;
                print('⚠️ Utilisation du premier article de pivotArray comme fallback');
              }
              
              // ✅ CORRECTION CRITIQUE: Copier TOUS les prix depuis sourceArticle (y compris "Indisponible")
              // MAIS aussi vérifier que TOUS les prix sont bien copiés, même ceux qui existent déjà dans updatedArticleCopy
              if (sourceArticle != null) {
                print('📦 Copie de TOUS les prix depuis sourceArticle...');
                print('📦 sourceArticle contient les clés: ${sourceArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k)).toList()}');
                
                // ✅ CORRECTION CRITIQUE: Copier TOUS les prix depuis sourceArticle, EN ÉCRASANT ceux qui existent déjà
                // Cela garantit que les prix les plus récents depuis pivotArray sont utilisés
                // ✅ IMPORTANT: Copier même si c'est "Indisponible", null, ou vide
                // Le backend retourne TOUS les prix dans pivotArray, même ceux qui sont "Indisponible"
                for (final key in sourceArticle.keys) {
                  // ✅ Copier toutes les clés qui sont des codes de pays (2 lettres majuscules)
                  if (key.length == 2 && 
                      key.toUpperCase() == key && 
                      RegExp(r'^[A-Z]{2}$').hasMatch(key)) {
                    final priceValue = sourceArticle[key];
                    // ✅ CORRECTION CRITIQUE: Copier TOUJOURS, même si c'est null, "Indisponible", ou vide
                    // Cela garantit que la clé existe dans updatedArticleCopy pour que _buildCountryDetails puisse la trouver
                    // ✅ IMPORTANT: Écraser même si la clé existe déjà dans updatedArticleCopy
                    // pour s'assurer qu'on utilise les prix les plus récents depuis pivotArray
                    updatedArticleCopy[key] = priceValue; // ✅ Copier même si null
                    if (priceValue != null && priceValue.toString().trim().isNotEmpty) {
                      print('   ✅ Prix $key copié (écrasé si existait): $priceValue');
                    } else {
                      print('   ⚠️ Prix $key copié (null/vide/indisponible): $priceValue');
                    }
                  }
                }
                
                // ✅ CORRECTION CRITIQUE: Vérifier que TOUS les pays sélectionnés ont un prix après la copie
                // Si un pays sélectionné n'a pas de prix dans sourceArticle, chercher dans TOUS les articles de pivotArray
                for (final countryCode in normalizedCountries) {
                  final upperCode = countryCode.toUpperCase();
                  if (!updatedArticleCopy.containsKey(upperCode) || 
                      updatedArticleCopy[upperCode] == null ||
                      updatedArticleCopy[upperCode].toString().trim().isEmpty) {
                    print('   ⚠️ Prix manquant pour $upperCode dans sourceArticle, recherche dans TOUS les articles de pivotArray...');
                    // ✅ Chercher dans TOUS les articles de pivotArray
                    // ✅ CORRECTION: Copier même si c'est "Indisponible" ou null
                    for (final item in pivotArray) {
                      if (item.containsKey(upperCode)) {
                        // ✅ Copier même si c'est null ou "Indisponible"
                        updatedArticleCopy[upperCode] = item[upperCode];
                        print('   ✅ Prix $upperCode trouvé dans un autre article de pivotArray et ajouté: ${item[upperCode]}');
                        break;
                      }
                    }
                  }
                }
                
                // ✅ CORRECTION CRITIQUE: Vérifier spécifiquement PT (le pays qui pose problème)
                if (updatedArticleCopy.containsKey('PT') && updatedArticleCopy['PT'] != null) {
                  print('   ✅ PT présent dans updatedArticleCopy après copie: ${updatedArticleCopy['PT']}');
                } else {
                  print('   ❌ PT MANQUANT ou null dans updatedArticleCopy après copie depuis sourceArticle');
                  print('   🔍 Vérification dans sourceArticle: PT = ${sourceArticle['PT']}');
                  // ✅ Si PT est manquant dans sourceArticle, chercher dans TOUS les articles de pivotArray
                  // ✅ CORRECTION: Copier même si c'est "Indisponible" ou null
                  print('   🔍 Recherche de PT dans TOUS les articles de pivotArray...');
                  for (final item in pivotArray) {
                    if (item.containsKey('PT')) {
                      // ✅ Copier même si c'est null ou "Indisponible"
                      updatedArticleCopy['PT'] = item['PT'];
                      print('   ✅ PT trouvé dans un autre article de pivotArray et ajouté: ${item['PT']}');
                      break;
                    }
                  }
                }
              } else {
                print('❌ Aucun article source trouvé dans pivotArray');
                // ✅ Si aucun article source, copier TOUS les prix depuis le premier article de pivotArray
                // ✅ CORRECTION CRITIQUE: Copier même les prix null ou "Indisponible"
                if (pivotArray.isNotEmpty) {
                  final firstArticle = pivotArray[0] as Map<String, dynamic>?;
                  if (firstArticle != null) {
                    print('📦 Copie de TOUS les prix depuis le premier article de pivotArray (fallback)...');
                    for (final key in firstArticle.keys) {
                      if (key.length == 2 && 
                          key.toUpperCase() == key && 
                          RegExp(r'^[A-Z]{2}$').hasMatch(key)) {
                        final priceValue = firstArticle[key];
                        // ✅ CORRECTION CRITIQUE: Copier TOUJOURS, même si c'est null, "Indisponible", ou vide
                        updatedArticleCopy[key] = priceValue; // ✅ Copier même si null
                        if (priceValue != null && priceValue.toString().trim().isNotEmpty) {
                          print('   ✅ Prix $key copié depuis premier article: $priceValue');
                        } else {
                          print('   ⚠️ Prix $key copié depuis premier article (null/vide/indisponible): $priceValue');
                        }
                      }
                    }
                  }
                }
              }
              
              // ✅ S'assurer que TOUTES les propriétés sont copiées (y compris les prix par pays)
              // Créer une copie complète avec toutes les clés
              final newArticle = Map<String, dynamic>.from(updatedArticleCopy);
              
              // Ajouter un timestamp pour forcer la mise à jour (nécessaire pour déclencher le listener)
              newArticle['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch;
              
              // ✅ Debug: Vérifier que tous les prix sont dans newArticle avant de mettre à jour le notifier
              final allCountryKeysInNew = newArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k)).toList();
              print('📦 newArticle avant mise à jour du notifier - clés de pays: $allCountryKeysInNew');
              for (final countryKey in allCountryKeysInNew) {
                print('   💰 $countryKey: ${newArticle[countryKey]}');
              }
              
              // ✅ CORRECTION CRITIQUE: Vérifier spécifiquement PT (le pays qui pose problème)
              if (newArticle.containsKey('PT')) {
                print('   ✅ PT présent dans newArticle: ${newArticle['PT']}');
              } else {
                print('   ❌ PT MANQUANT dans newArticle !');
                print('   🔍 Vérification dans updatedArticleCopy: PT = ${updatedArticleCopy['PT']}');
                // ✅ Si PT est manquant, essayer de le récupérer directement depuis pivotArray
                for (final item in pivotArray) {
                  if (item.containsKey('PT') && item['PT'] != null) {
                    newArticle['PT'] = item['PT'];
                    print('   ✅ PT récupéré directement depuis pivotArray et ajouté à newArticle: ${item['PT']}');
                    break;
                  }
                }
              }
              
              // ✅ Vérifier spécifiquement les pays sélectionnés
              print('📋 Vérification finale des prix pour les pays sélectionnés:');
              for (final countryCode in normalizedCountries) {
                final upperCode = countryCode.toUpperCase();
                if (newArticle.containsKey(upperCode) && 
                    newArticle[upperCode] != null &&
                    newArticle[upperCode].toString().trim().isNotEmpty) {
                  print('   ✅ $upperCode: ${newArticle[upperCode]}');
                } else {
                  print('   ❌ $upperCode: MANQUANT ou vide');
                  // ✅ Dernière tentative : récupérer depuis pivotArray
                  bool found = false;
                  for (final item in pivotArray) {
                    if (item.containsKey(upperCode) && item[upperCode] != null) {
                      newArticle[upperCode] = item[upperCode];
                      print('   ✅ $upperCode récupéré depuis pivotArray et ajouté à newArticle: ${item[upperCode]}');
                      found = true;
                      break;
                    }
                  }
                  if (!found) {
                    print('   ❌ $upperCode non trouvé dans pivotArray');
                  }
                }
              }
              
              // ✅ CORRECTION CRITIQUE: Vérifier spécifiquement PT une dernière fois
              if (newArticle.containsKey('PT') && 
                  newArticle['PT'] != null &&
                  newArticle['PT'].toString().trim().isNotEmpty) {
                print('   ✅ PT présent dans newArticle FINAL: ${newArticle['PT']}');
              } else {
                print('   ❌ PT MANQUANT ou vide dans newArticle FINAL !');
                print('   🔍 Dernière tentative: recherche dans pivotArray...');
                for (final item in pivotArray) {
                  if (item.containsKey('PT') && item['PT'] != null) {
                    newArticle['PT'] = item['PT'];
                    print('   ✅ PT récupéré depuis pivotArray et ajouté à newArticle: ${item['PT']}');
                    break;
                  }
                }
              }
              
              // ✅ CORRECTION CRITIQUE: Vérifier que le notifier n'est pas disposé avant de le mettre à jour
              // Si le notifier est disposé, on ne peut pas le mettre à jour, mais les prix sont dans pivotArray
              // et seront disponibles au prochain rechargement ou si on force la mise à jour de modalNotifier
              bool notifierUpdated = false;
              try {
                // Tester si le notifier est toujours valide en accédant à sa valeur
                final _ = articleNotifier.value;
                
                // ✅ CORRECTION CRITIQUE: Forcer la mise à jour en créant un nouvel objet (nécessaire pour déclencher le listener)
                // Ajouter un timestamp pour forcer la mise à jour même si les données sont identiques
                final firstUpdate = Map<String, dynamic>.from(newArticle);
                firstUpdate['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch;
                articleNotifier.value = Map<String, dynamic>.from(firstUpdate);
                notifierUpdated = true;
                print('🔄 Article mis à jour dans le notifier (première fois)');
                print('   📦 Clés de pays dans newArticle: ${newArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k)).toList()}');
                
                // ✅ Forcer une deuxième mise à jour après un court délai pour s'assurer que le listener est déclenché
                await Future.delayed(const Duration(milliseconds: 200));
                try {
                  // Vérifier à nouveau que le notifier n'est pas disposé
                  final currentValue = articleNotifier.value;
                  if (currentValue['sCodeArticleCrypt'] == sCodeArticleCrypt) {
                    // Créer un nouvel objet avec un nouveau timestamp pour forcer le listener
                    final secondUpdate = Map<String, dynamic>.from(newArticle);
                    secondUpdate['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch + 1;
                    articleNotifier.value = Map<String, dynamic>.from(secondUpdate);
                    print('🔄 Article mis à jour dans le notifier (deuxième fois)');
                    
                    // ✅ Forcer une troisième mise à jour après un autre délai pour garantir que le listener est déclenché
                    await Future.delayed(const Duration(milliseconds: 200));
                    try {
                      final thirdValue = articleNotifier.value;
                      if (thirdValue['sCodeArticleCrypt'] == sCodeArticleCrypt) {
                        final thirdUpdate = Map<String, dynamic>.from(newArticle);
                        thirdUpdate['_lastUpdate'] = DateTime.now().millisecondsSinceEpoch + 2;
                        articleNotifier.value = Map<String, dynamic>.from(thirdUpdate);
                        print('🔄 Article mis à jour dans le notifier (troisième fois)');
                      }
                    } catch (e) {
                      print('ℹ️ Notifier disposé lors de la troisième mise à jour: $e');
                    }
                  }
                } catch (e) {
                  print('ℹ️ Notifier disposé lors de la deuxième mise à jour: $e');
                }
              } catch (e) {
                print('❌ Notifier disposé AVANT la mise à jour, impossible de propager les prix: $e');
                print('   ⚠️ Tentative de mise à jour via _articleNotifiers...');
                
                // ✅ CORRECTION CRITIQUE: Même si le notifier est disposé, on peut mettre à jour
                // le notifier dans _articleNotifiers directement, ce qui permettra au modal
                // de récupérer les nouveaux prix lors de la prochaine reconstruction
                try {
                  final articleKey = _articleKey({'sCodeArticleCrypt': sCodeArticleCrypt});
                  final existingNotifier = _articleNotifiers[articleKey];
                  if (existingNotifier != null) {
                    // Créer un nouveau notifier avec les nouveaux prix si l'ancien est disposé
                    try {
                      existingNotifier.value = Map<String, dynamic>.from(newArticle);
                      notifierUpdated = true;
                      print('✅ Notifier mis à jour via _articleNotifiers malgré dispose');
                    } catch (e2) {
                      // Le notifier est vraiment disposé, créer un nouveau
                      print('   ⚠️ Notifier vraiment disposé, création d\'un nouveau...');
                      final newNotifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(newArticle));
                      _articleNotifiers[articleKey] = newNotifier;
                      notifierUpdated = true;
                      print('✅ Nouveau notifier créé dans _articleNotifiers');
                    }
                  } else {
                    // Créer un nouveau notifier s'il n'existe pas
                    final newNotifier = ValueNotifier<Map<String, dynamic>>(Map<String, dynamic>.from(newArticle));
                    _articleNotifiers[articleKey] = newNotifier;
                    notifierUpdated = true;
                    print('✅ Nouveau notifier créé dans _articleNotifiers (n\'existait pas)');
                  }
                } catch (e3) {
                  print('   ⚠️ Impossible de mettre à jour via _articleNotifiers: $e3');
                }
              }
              
              // ✅ CORRECTION CRITIQUE: Toujours mettre à jour _wishlistData['pivotArray'] avec les nouveaux prix
              // Cela garantit que les prix sont disponibles même si le notifier est disposé
              if (_wishlistData != null && pivotArray.isNotEmpty) {
                // Trouver l'article correspondant dans pivotArray et mettre à jour _wishlistData
                for (final item in pivotArray) {
                  final itemCrypt = item['sCodeArticleCrypt']?.toString() ?? '';
                  if (itemCrypt == sCodeArticleCrypt) {
                    // Mettre à jour l'article dans _wishlistData avec les nouveaux prix
                    final articleIndex = (_wishlistData!['pivotArray'] as List).indexWhere(
                      (a) => (a['sCodeArticleCrypt']?.toString() ?? '') == sCodeArticleCrypt
                    );
                    if (articleIndex >= 0) {
                      // ✅ CORRECTION CRITIQUE: Copier TOUS les prix depuis newArticle vers l'article dans pivotArray
                      // Cela garantit que les prix sont disponibles dans _wishlistData
                      for (final key in newArticle.keys) {
                        if (key.length == 2 && 
                            key.toUpperCase() == key && 
                            RegExp(r'^[A-Z]{2}$').hasMatch(key)) {
                          (_wishlistData!['pivotArray'] as List)[articleIndex][key] = newArticle[key];
                        }
                      }
                      print('✅ Prix mis à jour dans _wishlistData pour l\'article $sCodeArticleCrypt');
                      print('   📦 Clés de pays mises à jour: ${newArticle.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k)).toList()}');
                      
                      // ✅ CORRECTION CRITIQUE: Mettre à jour modalNotifier directement depuis _wishlistData
                      // Cela garantit que le modal affiche les nouveaux prix même si sourceNotifier est disposé
                      if (modalNotifier != null) {
                        try {
                          final updatedArticleFromPivot = Map<String, dynamic>.from((_wishlistData!['pivotArray'] as List)[articleIndex]);
                          modalNotifier.value = updatedArticleFromPivot;
                          print('✅ modalNotifier mis à jour directement depuis _wishlistData');
                          print('   📦 Clés de pays dans modalNotifier: ${updatedArticleFromPivot.keys.where((k) => k.length == 2 && k.toUpperCase() == k && RegExp(r'^[A-Z]{2}$').hasMatch(k)).toList()}');
                        } catch (e) {
                          print('⚠️ Impossible de mettre à jour modalNotifier: $e');
                        }
                      }
                    }
                    break;
                  }
                }
              }
            }
          } catch (e) {
            // Le notifier a été disposé, ce n'est pas grave
            print('ℹ️ Notifier disposé, impossible de mettre à jour le SidebarModal: $e');
          }
        }

        // ✅ metadataByCode est déjà déclaré au début de la fonction, pas besoin de le redéclarer
        final enriched = normalizedCountries.map((code) {
          final meta = metadataByCode[code] ?? const {};
          final flag = _normalizeFlagUrl(meta['flag']?.toString());
          final name = meta['name']?.toString() ?? code;
          return {
            'code': code,
            'name': name,
            'flag': flag,
          };
        }).toList();

        return enriched;
      } else {
        print('❌ Erreur lors de la sauvegarde: ${response?['error']}');
      }
      
    } catch (e) {
      print('❌ Erreur _saveCountryChanges: $e');
    }
    return null;
  }

  /// Changer le pays d'un article (comme SNAL avec updateDisplayChoice)
  /// countryCode peut être un code pays pour sélectionner, ou '-1' pour désélectionner
  Future<void> _changeArticleCountry(Map<String, dynamic> article, String countryCode, [ValueNotifier<Map<String, dynamic>>? articleNotifier]) async {
    try {
      final sCodeArticleCrypt = article['sCodeArticleCrypt'] ?? '';
      final currentSelected = article['spaysSelected'] ?? article['sPaysSelected'] ?? '';
      final isDeselecting = countryCode == '-1' || countryCode.isEmpty;
      
      if (isDeselecting) {
        print('🔄 Désélection du pays pour l\'article: $currentSelected → (aucun)');
      } else {
        print('🔄 Changement du pays pour l\'article: $currentSelected → $countryCode');
      }
      print('🔄 Appel API updateCountrySelected (CHANGEPAYS):');

      // ✅ Optimistic UI update immédiat (avant l'appel API)
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        final pivotArray = List<dynamic>.from(_wishlistData!['pivotArray'] as List);
        final articleIndex = pivotArray.indexWhere(
          (item) => item['sCodeArticleCrypt'] == sCodeArticleCrypt
        );
        if (articleIndex != -1) {
          // ✅ Si désélection (-1), mettre à vide, sinon mettre le code du pays
          final newSelected = isDeselecting ? '' : countryCode;
          
          // ✅ CRITIQUE: Créer une nouvelle copie de l'article pour forcer la détection du changement
          final updatedArticle = Map<String, dynamic>.from(pivotArray[articleIndex]);
          updatedArticle['spaysSelected'] = newSelected;
          updatedArticle['sPaysSelected'] = newSelected;
          updatedArticle['sPays'] = newSelected;
          
          // ✅ CRITIQUE: Créer une nouvelle liste avec l'article mis à jour
          final newPivotArray = List<dynamic>.from(pivotArray);
          newPivotArray[articleIndex] = updatedArticle;
          
          // ✅ CRITIQUE: Créer une NOUVELLE référence de _wishlistData pour forcer Flutter à détecter le changement
          _wishlistData = Map<String, dynamic>.from(_wishlistData!);
          _wishlistData!['pivotArray'] = newPivotArray;
          
          // ✅ Mettre à jour le notifier du modal
          if (articleNotifier != null) {
            articleNotifier.value = Map<String, dynamic>.from(updatedArticle);
          }
          
          // ✅ CORRECTION CRITIQUE: Mettre à jour AUSSI le notifier du wishlist_screen
          // pour que le ValueListenableBuilder dans le build method se mette à jour automatiquement
          final wishlistNotifier = _articleNotifiers[sCodeArticleCrypt];
          if (wishlistNotifier != null) {
            wishlistNotifier.value = Map<String, dynamic>.from(updatedArticle);
            print('⚡ ValueNotifier du wishlist_screen mis à jour (optimistic)');
          } else {
            // Si le notifier n'existe pas encore, le créer
            _articleNotifiers[sCodeArticleCrypt] = ValueNotifier<Map<String, dynamic>>(
              Map<String, dynamic>.from(updatedArticle)
            );
            print('⚡ ValueNotifier du wishlist_screen créé (optimistic)');
          }
          
          if (mounted) setState(() {});
          print('⚡ UI mise à jour immédiatement (optimistic) avec pays: ${isDeselecting ? "(aucun)" : countryCode}');
          unawaited(_loadWishlistData(force: true));
        }
      }
      
      // ✅ Appeler l'API pour changer le pays (comme SNAL)
      final profileData = await LocalStorageService.getProfile();
      final iBasket = profileData?['iBasket']?.toString() ?? '';
      
      print('   iBasket: $iBasket');
      print('   sCodeArticle: $sCodeArticleCrypt');
      print('   sNewPaysSelected: ${isDeselecting ? "-1" : countryCode}');
      
      // ✅ Appeler l'endpoint update-country-selected (comme SNAL ligne 4075)
      // Passer -1 pour désélectionner, sinon le code du pays
      final response = await _apiService.updateCountrySelected(
        iBasket: iBasket,
        sCodeArticle: sCodeArticleCrypt,
        sNewPaysSelected: isDeselecting ? '-1' : countryCode,
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
            final pivotArray = List<dynamic>.from(_wishlistData!['pivotArray'] as List);
            final articleIndex = pivotArray.indexWhere(
              (item) => item['sCodeArticleCrypt'] == sCodeArticleCrypt
            );
            
            if (articleIndex != -1) {
              // ✅ Mettre à jour l'article avec le nouveau pays sélectionné (comme SNAL ligne 4090)
              // Si sNewPaysSelected est -1 ou vide, désélectionner (mettre à vide)
              final rawNewSelected = totals['sNewPaysSelected']?.toString() ?? '';
              final newSelected = (rawNewSelected == '-1' || rawNewSelected.isEmpty) ? '' : rawNewSelected;
              
              // ✅ CRITIQUE: Créer une nouvelle copie de l'article pour forcer la détection du changement
              final updatedArticle = Map<String, dynamic>.from(pivotArray[articleIndex]);
              updatedArticle['spaysSelected'] = newSelected;
              updatedArticle['sPaysSelected'] = newSelected;
              updatedArticle['sPays'] = newSelected;
              updatedArticle['sMyHomeIcon'] = totals['sMyHomeIcon'];
              updatedArticle['sPaysListe'] = totals['sPaysListe'];
              
              // ✅ CRITIQUE: Créer une nouvelle liste avec l'article mis à jour
              final newPivotArray = List<dynamic>.from(pivotArray);
              newPivotArray[articleIndex] = updatedArticle;
              
              // ✅ CRITIQUE: Créer une nouvelle copie de meta pour forcer la détection du changement
              Map<String, dynamic> newMeta = {};
              if (_wishlistData!['meta'] != null) {
                newMeta = Map<String, dynamic>.from(_wishlistData!['meta']);
              }
              
              // Mettre à jour les totaux (comme SNAL lignes 4097-4108)
              newMeta['iBestResultJirig'] = totals['iBestResultJirig'];
              newMeta['iTotalPriceArticleSelected'] = totals['iTotalPriceArticleSelected'];
              newMeta['sResultatGainPerte'] = totals['sResultatGainPerte'];
              newMeta['iResultatGainPertePercentage'] = totals['iResultatGainPertePercentage'];
              newMeta['iTotalQteArticleSelected'] = totals['iTotalQteArticleSelected'];
              print('✅ Totaux mis à jour dans meta');
              
              // ✅ CRITIQUE: Créer une NOUVELLE référence de _wishlistData pour forcer Flutter à détecter le changement
              _wishlistData = Map<String, dynamic>.from(_wishlistData!);
              _wishlistData!['pivotArray'] = newPivotArray;
              _wishlistData!['meta'] = newMeta;
              
              print('✅ Article mis à jour localement:');
              print('   Nouveau pays: ${updatedArticle['spaysSelected']}');
              print('   sMyHomeIcon: ${updatedArticle['sMyHomeIcon']}');
              
              // ✅ Mettre à jour le ValueNotifier du modal AVANT le setState pour que le modal se mette à jour
              if (articleNotifier != null) {
                articleNotifier.value = Map<String, dynamic>.from(updatedArticle);
                print('✅ ValueNotifier du modal mis à jour avec le nouvel article');
              }
              
              // ✅ CORRECTION CRITIQUE: Mettre à jour AUSSI le notifier du wishlist_screen
              // pour que le ValueListenableBuilder dans le build method se mette à jour automatiquement
              final wishlistNotifier = _articleNotifiers[sCodeArticleCrypt];
              if (wishlistNotifier != null) {
                wishlistNotifier.value = Map<String, dynamic>.from(updatedArticle);
                print('✅ ValueNotifier du wishlist_screen mis à jour');
              } else {
                // Si le notifier n'existe pas encore, le créer
                _articleNotifiers[sCodeArticleCrypt] = ValueNotifier<Map<String, dynamic>>(
                  Map<String, dynamic>.from(updatedArticle)
                );
                print('✅ ValueNotifier du wishlist_screen créé');
              }
              
              // ✅ Forcer la mise à jour de l'interface principale
              if (mounted) {
                setState(() {});
                print('✅ Interface principale mise à jour - UI devrait se rafraîchir immédiatement');
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

  /// ✅ Suppression optimiste - Mise à jour UI immédiate avant la réponse API
  Future<void> _updateDataAfterDeletionOptimistic(String deletedCode) async {
    try {
      print('⚡ Suppression optimiste de l\'article: $deletedCode');
      
      // Retirer l'article de la liste locale IMMÉDIATEMENT
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        final List<dynamic> pivotArray = List<dynamic>.from(_wishlistData!['pivotArray']);
        
        // Supprimer l'article
        int removedCount = 0;
        pivotArray.removeWhere((item) {
          final itemCode = item['sCodeArticle']?.toString() ?? '';
          final itemCryptCode = item['sCodeArticleCrypt']?.toString() ?? '';
          final shouldRemove = itemCryptCode == deletedCode || itemCode == deletedCode;
          
          if (shouldRemove) {
            removedCount++;
          }
          
          return shouldRemove;
        });
        
        if (removedCount > 0) {
          // Nettoyer les notifiers IMMÉDIATEMENT
          final keysToRemove = <String>[];
          for (var entry in _articleNotifiers.entries) {
            final notifValue = entry.value.value;
            final notifCodeCrypt = notifValue['sCodeArticleCrypt']?.toString() ?? '';
            final notifCode = notifValue['sCodeArticle']?.toString() ?? '';
            
            if (notifCodeCrypt == deletedCode || notifCode == deletedCode) {
              keysToRemove.add(entry.key);
            }
          }
          
          for (var key in keysToRemove) {
            _articleNotifiers[key]?.dispose();
            _articleNotifiers.remove(key);
          }
          
          // Mettre à jour _wishlistData IMMÉDIATEMENT
          final articleCount = pivotArray.length;
          _wishlistData = Map<String, dynamic>.from(_wishlistData!);
          _wishlistData!['pivotArray'] = List<dynamic>.from(pivotArray);
          _selectedBasketName = 'Wishlist ($articleCount Art.)';
          
          // ✅ CRITIQUE: setState IMMÉDIATEMENT pour feedback instantané
          if (mounted) {
            setState(() {});
            print('⚡ setState() appelé IMMÉDIATEMENT - Article supprimé visuellement');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur suppression optimiste: $e');
    }
  }

  /// Mettre à jour les métadonnées après suppression (l'article est déjà supprimé de manière optimiste)
  Future<void> _updateDataAfterDeletion(Map<String, dynamic> response, String deletedCode) async {
    try {
      print('🔄 Mise à jour des métadonnées après suppression: $response');
      print('🗑️ Code supprimé (déjà retiré de manière optimiste): $deletedCode');
      
      // ✅ CRITIQUE: L'article a déjà été supprimé de manière optimiste dans _updateDataAfterDeletionOptimistic
      // On ne doit PAS le supprimer à nouveau, seulement mettre à jour les métadonnées (totaux, etc.)
      if (_wishlistData != null && _wishlistData!['pivotArray'] != null) {
        // Lire pivotArray depuis _wishlistData qui a déjà été mis à jour de manière optimiste
        final currentPivotArray = List<dynamic>.from(_wishlistData!['pivotArray'] ?? []);
        final articleCount = currentPivotArray.length;
        
        print('📊 Articles actuels dans pivotArray (après suppression optimiste): $articleCount');
        
        // ✅ CRITIQUE: Créer une nouvelle copie de meta pour forcer la détection du changement
        Map<String, dynamic> newMeta = {};
        if (_wishlistData!['meta'] != null) {
          newMeta = Map<String, dynamic>.from(_wishlistData!['meta']);
        }
        
        // ✅ CORRECTION: Si le panier est vide après suppression, réinitialiser tous les totaux à 0
        if (articleCount == 0) {
          print('📊 Panier vide - Réinitialisation des totaux à 0');
          newMeta['iBestResultJirig'] = 0.0;
          newMeta['iTotalQteArticleSelected'] = 0;
          newMeta['iTotalPriceArticleSelected'] = 0.0;
          newMeta['iTotalQteArticle'] = 0;
          newMeta['sResultatGainPerte'] = '0€';
          newMeta['iResultatGainPertePercentage'] = 0.0;
          newMeta['iTotalSelected4PaysProfile'] = 0.0;
          newMeta['iTotalPriceSelected4PaysProfile'] = 0.0;
          
          // ✅ CRITIQUE: NE PAS recharger les données depuis l'API - l'article est déjà supprimé
          // Le rechargement pourrait restaurer l'article si l'API n'est pas encore synchronisée
          print('✅ Panier vide - Métadonnées réinitialisées (pas de rechargement pour éviter restauration)');
        } else {
          // Mettre à jour les totaux depuis parsedData (comme SNAL) seulement si le panier n'est pas vide
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
                  newMeta[key] = totals[key];
                }
              }
              
              print('✅ Métadonnées mises à jour depuis parsedData');
            }
          }
        }
        
        print('📊 Articles actuels dans pivotArray (après suppression optimiste): $articleCount');
        
        // Mettre à jour _wishlistData avec les nouvelles métadonnées
        _wishlistData = Map<String, dynamic>.from(_wishlistData!);
        _wishlistData!['meta'] = newMeta; // Nouvelle map meta avec les totaux mis à jour
        
        // Mettre à jour le nom du panier si nécessaire
        _selectedBasketName = 'Wishlist ($articleCount Art.)';
        
        // ✅ CRITIQUE: Mettre à jour aussi le label du basket dans _baskets pour que le dropdown affiche le bon nombre
        if (_selectedBasketIndex != null && 
            _selectedBasketIndex! >= 0 && 
            _selectedBasketIndex! < _baskets.length) {
          // Créer une nouvelle copie du basket pour forcer la détection du changement
          _baskets[_selectedBasketIndex!] = Map<String, dynamic>.from(_baskets[_selectedBasketIndex!]);
          _baskets[_selectedBasketIndex!]['label'] = 'Wishlist ($articleCount Art.)';
          print('✅ Label du basket mis à jour dans _baskets: Wishlist ($articleCount Art.)');
        }
        
        // ✅ CRITIQUE: Mettre à jour l'UI pour refléter les nouvelles métadonnées (totaux, etc.)
        // Mais NE PAS recharger les données depuis l'API pour éviter de restaurer l'article
        if (mounted) {
          setState(() {
            // _wishlistData est déjà mis à jour avec les nouvelles métadonnées
          });
          print('✅ setState() appelé pour mettre à jour les métadonnées (totaux, etc.)');
        }
        
        print('✅ Métadonnées mises à jour après suppression - Totaux synchronisés avec l\'API');
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
      // ✅ Bouton flottant "Tout supprimer" - apparaît quand il y a 2 articles ou plus ET que l'utilisateur n'est PAS à la fin
      floatingActionButton: (_shouldShowDeleteAllButton() && !_isAtBottom)
          ? AnimatedOpacity(
              opacity: _shouldShowDeleteAllButton() && !_isAtBottom ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton.extended(
                onPressed: _deleteAllArticles,
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                icon: const Icon(Icons.delete_sweep),
                label: Text(
                  _translationService.translate('WISHLIST_DELETE_ALL') ?? 'Tout supprimer',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                elevation: 4,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// Vérifier si le bouton "Tout supprimer" doit être affiché
  /// Le bouton apparaît quand il y a 2 articles ou plus
  bool _shouldShowDeleteAllButton() {
    final articles = _wishlistData?['pivotArray'] as List? ?? [];
    return articles.length >= 2;
  }
  
  /// Vérifier si la liste est assez longue pour nécessiter un scroll
  /// Si la liste est courte, le bouton sera placé en fin de liste au lieu d'être flottant
  bool _shouldUseFloatingButton(BuildContext context) {
    final articles = _wishlistData?['pivotArray'] as List? ?? [];
    if (articles.length < 2) return false;
    
    // Obtenir la hauteur de l'écran
    final screenHeight = MediaQuery.maybeOf(context)?.size.height ?? 800;
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final isMobile = screenWidth < 768;
    
    // Estimer la hauteur totale du contenu
    // Hauteur approximative par article (avec espacement)
    final estimatedArticleHeight = isMobile ? 180.0 : 200.0;
    final estimatedHeaderHeight = isMobile ? 400.0 : 500.0; // Section top avec cartes, etc.
    final estimatedTotalHeight = estimatedHeaderHeight + (articles.length * estimatedArticleHeight);
    
    // Si le contenu dépasse 80% de la hauteur de l'écran, utiliser le bouton flottant
    // Sinon, placer le bouton en fin de liste
    return estimatedTotalHeight > (screenHeight * 0.8);
  }
  
  /// Construire le bouton "Tout supprimer"
  Widget _buildDeleteAllButton(TranslationService translationService) {
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final isMobile = screenWidth < 768;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      child: FilledButton.icon(
        onPressed: _deleteAllArticles,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.delete_sweep),
        label: Text(
          translationService.translate('WISHLIST_DELETE_ALL') ?? 'Tout supprimer',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
                translationService.translate('LOADING_IN_LOADER'),
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
        controller: _scrollController,
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
    
    // S'assurer que _baskets est toujours une liste valide (gérer le cas null/undefined en JavaScript/Web)
    final baskets = (_baskets.isNotEmpty) ? _baskets : <Map<String, dynamic>>[];

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
                // Dropdown fonctionnel (comme SNAL-Project)
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? 180 : 250,
                    ),
                    child: baskets.isEmpty
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: isMobile ? 10 : 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFCED4DA),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                      fontWeight: FontWeight.w500,
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
                          )
                        : _buildBasketDropdownWithSwipe(baskets, isMobile),
                  ),
                ),
                
                SizedBox(width: isMobile ? 12 : 200),
                
                // Trois boutons circulaires oranges avec animation Float
                _buildCircleButton(
                  Icons.flag_outlined,
                  const Color(0xFFf59e0b),
                  onTap: () => _openCountryManagementModal(),
                  isMobile: isMobile,
                  index: 0,
                ),
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
                      // Bouton Ajouter (avec hasArticles=true car il y a des articles)
                      _buildAddButton(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile, hasArticles: true),
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
          else ...[
            _buildArticlesContent(translationService, articles, isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
            
            // ✅ Bouton "Tout supprimer" en fin de liste avec animation
            // Le bouton apparaît en fin de liste quand l'utilisateur est à la fin du scroll
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: (_shouldShowDeleteAllButton() && _isAtBottom)
                  ? _buildDeleteAllButton(translationService)
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ],
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
  Widget _buildAddButton({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false, bool hasArticles = false}) {
    // Utiliser WISHLIST_Msg15 ("Ajouter") quand il y a des articles, sinon WISHLIST_Msg06 ("Ajouter un article")
    final buttonTextKey = hasArticles ? 'WISHLIST_Msg15' : 'WISHLIST_Msg06';
    
    return _BreathingButton(
      onPressed: _openAddArticleModal,
      child: GestureDetector(
        onTap: _openAddArticleModal,
        child: Container(
          constraints: BoxConstraints(), // Pas de limitation de largeur
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle,
                size: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : (isMobile ? 20 : 20)), // Taille augmentée sur mobile
                color: Colors.white,
              ),
              SizedBox(width: isVerySmallMobile ? 2 : (isSmallMobile ? 3 : (isMobile ? 4 : 6))),
              Flexible(
                child: Text(
                  _translationService.translate(buttonTextKey),
                  style: TextStyle(
                    fontSize: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : (isMobile ? 14 : 15)), // Taille réduite pour éviter l'overflow
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget personnalisé pour le dropdown avec swipe pour les PDF
  Widget _buildBasketDropdownWithSwipe(List<Map<String, dynamic>> baskets, bool isMobile) {
    final selectedBasket = _selectedBasketIndex != null && _selectedBasketIndex! >= 0 && _selectedBasketIndex! < baskets.length
        ? baskets[_selectedBasketIndex!]
        : null;
    final selectedLabel = selectedBasket?['label']?.toString() ?? 'Wishlist';
    final isSelectedPdf = selectedLabel.toLowerCase().contains('.pdf');
    
    // Vérifier s'il y a des PDF dans la liste
    final hasPdfBaskets = baskets.any((basket) {
      final label = basket['label']?.toString() ?? '';
      return label.toLowerCase().contains('.pdf');
    });
    
    return PopupMenuButton<int>(
      offset: Offset(isMobile ? 0 : -65, isMobile ? 48 : 52),
      constraints: BoxConstraints(
        maxWidth: isMobile ? 180 : 380, // Limiter la largeur du menu
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      color: Colors.white,
      onOpened: () {
        setState(() {
          _isBasketDropdownOpen = true;
        });
      },
      onCanceled: () {
        setState(() {
          _isBasketDropdownOpen = false;
        });
      },
      onSelected: (int? index) {
        setState(() {
          _isBasketDropdownOpen = false;
        });
        if (index != null && mounted) {
          _handleBasketChange(index);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFCED4DA),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedLabel,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: const Color(0xFF212529),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _isBasketDropdownOpen ? math.pi : 0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value,
                  child: child,
                );
              },
              child: Icon(
                Icons.keyboard_arrow_down,
                color: const Color(0xFF6C757D),
                size: isMobile ? 20 : 24,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return List.generate(baskets.length, (index) {
          final basket = baskets[index];
          final label = basket['label']?.toString() ?? 'Wishlist';
          final isPdf = label.toLowerCase().contains('.pdf');
          final isLast = index == baskets.length - 1;
          
          return PopupMenuItem<int>(
            value: index,
            padding: EdgeInsets.zero,
            enabled: true,
            child: SizedBox(
              width: double.infinity, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BasketListItemWithSwipe(
                    basket: basket,
                    index: index,
                    isPdf: isPdf,
                    isSelected: _selectedBasketIndex == index,
                    isMobile: isMobile,
                    onTap: () {
                    },
                    onDelete: isPdf ? () {
                      if (mounted) {
                        _deleteBasketPdf(basket, context);
                      }
                    } : null,
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey[200],
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
  
  /// Afficher le message d'alerte pour indiquer qu'on peut swiper pour supprimer
  void _showSwipeHintMessage() {
    if (!mounted) return;
    
    // Retirer le message précédent s'il existe
    if (_currentSwipeHintOverlay != null) {
      _currentSwipeHintOverlay!.remove();
      _currentSwipeHintOverlay = null;
    }
    
    // Utiliser un OverlayEntry pour positionner le message en bas à droite
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80, // Au-dessus de la barre de navigation
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Builder(
            builder: (builderContext) {
              final translationService = Provider.of<TranslationService>(builderContext, listen: true);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF17A2B8), // Vert info
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swipe_left,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        translationService.translate('SWIPE_TO_DELETE_HINT'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    _currentSwipeHintOverlay = overlayEntry;
    
    // Retirer le message après 4 secondes
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _currentSwipeHintOverlay == overlayEntry) {
        overlayEntry.remove();
        _currentSwipeHintOverlay = null;
      }
    });
  }

  /// Supprimer un panier PDF
  Future<void> _deleteBasketPdf(Map<String, dynamic> basket, BuildContext menuContext) async {
    final iBasket = basket['iBasket']?.toString() ?? '';
    if (iBasket.isEmpty) {
      _showErrorDialog(
        _translationService.translate('ERROR') ?? 'Erreur',
        _translationService.translate('WISHLIST_ERROR_INVALID_BASKET') ?? 'Panier invalide',
      );
      return;
    }
    
    // Confirmation avant suppression
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            _translationService.translate('DELETE') ?? 'Supprimer',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            _translationService.translate('WISHLIST_DELETE_PDF_CONFIRM') ?? 
            'Êtes-vous sûr de vouloir supprimer ce projet PDF ?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                _translationService.translate('CANCEL') ?? 'Annuler',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_translationService.translate('DELETE') ?? 'Supprimer'),
            ),
          ],
        );
      },
    );
    
    if (confirmed != true) return;
    
    try {
      final result = await _apiService.deleteBasketPdf(iBasket: iBasket);
      
      if (result != null && result['success'] == true) {
        // Fermer le menu déroulant en cas de succès
        if (menuContext.mounted) {
          Navigator.of(menuContext).pop();
        }

        // Recharger la liste des baskets
        await _loadBaskets();
        
        // Afficher un message de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _translationService.translate('WISHLIST_PDF_DELETED') ?? 
                'Projet PDF supprimé avec succès',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        _showErrorDialog(
          _translationService.translate('ERROR') ?? 'Erreur',
          result?['message'] ?? result?['error'] ?? 
          (_translationService.translate('WISHLIST_ERROR_DELETE_PDF') ?? 'Erreur lors de la suppression'),
        );
      }
    } catch (e) {
      print('❌ Erreur suppression PDF: $e');
      _showErrorDialog(
        _translationService.translate('ERROR') ?? 'Erreur',
        _translationService.translate('WISHLIST_ERROR_DELETE_PDF') ?? 'Erreur lors de la suppression du projet PDF',
      );
    }
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
        _showErrorDialog(_translationService.translate('WISHLIST_Msg18'), _translationService.translate('ALERT_PDF'));
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
        ? _translationService.translate('WISHLIST_Msg62')
        : _translationService.translate('WISHLIST_Msg63');

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

    // ✅ Extraire la valeur numérique (comme SNAL getResultColor/getResultLabel)
    double numValue = 0.0;
    try {
      final cleanValue = sResultatGainPerte
          .replaceAll(RegExp(r'[^\d.,-]'), '')
          .replaceAll(',', '.');
      numValue = double.tryParse(cleanValue) ?? 0.0;
    } catch (e) {
      print('⚠️ Erreur parsing sResultatGainPerte: $e');
    }

    // ✅ Déterminer si c'est un bénéfice (>= 0) ou une perte (< 0)
    final isProfit = numValue >= 0;
    final labelText = isProfit 
        ? _translationService.translate('WISHLIST_Msg04a') 
        : _translationService.translate('WISHLIST_Msg04b');
    
    // ✅ Couleurs selon SNAL : vert pour bénéfice, rouge pour perte
    final labelColor = isProfit 
        ? const Color(0xFF10b981) // Vert
        : const Color(0xFFEF4444); // Rouge
    final labelBackgroundColor = isProfit 
        ? const Color(0xFFF0FDF4) // Vert très clair
        : const Color(0xFFFEF2F2); // Rouge très clair
    final amountColor = isProfit 
        ? const Color(0xFF2563eb) // Bleu pour bénéfice
        : const Color(0xFFDC2626); // Rouge pour perte
    final indicatorColor = isProfit 
        ? const Color(0xFF10b981) // Vert
        : const Color(0xFFEF4444); // Rouge

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
              // Point indicateur en haut à droite (vert pour bénéfice, rouge pour perte) avec animation de clignotement
              Positioned(
                top: -2,
                right: -2,
                child: _PulsingIndicatorDot(color: indicatorColor),
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
              // Texte "Bénéfice" ou "Perte" en badge coloré, remonté vers la bordure haute
              Transform.translate(
                offset: Offset(0, isMobile ? -18 : -20),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10,
                    vertical: isMobile ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: labelBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13, // Taille réduite
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              SizedBox(height: 2),
              // Montant coloré (bleu pour bénéfice, rouge pour perte)
              Transform.translate(
                offset: Offset(0, isMobile ? -6 : -8),
                child: Text(
                  sResultatGainPerte,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 24,
                    fontWeight: FontWeight.w800, // plus gras
                    color: amountColor,
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
          translationService.translate('WISHLIST_Msg18'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212529),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Texte secondaire
        Text(
          translationService.translate('WISHLIST_Msg19'),
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
              
              // ✅ CRITIQUE: Le notifier est la source de vérité pour les mises à jour en temps réel
              // Ne PAS écraser la valeur du notifier avec sourceArticle si le notifier a une valeur plus récente
              // Vérifier si le notifier a un timestamp de mise à jour récent (moins de 2 secondes)
              final notifierLastUpdate = notifier.value['_lastUpdate'] as int?;
              final sourceQuantity = sourceArticle['iqte'] ?? 1;
              final notifierQuantity = notifier.value['iqte'] ?? 1;
              
              // Vérifier si le timestamp est récent (moins de 2 secondes)
              final isRecentUpdate = notifierLastUpdate != null && 
                (DateTime.now().millisecondsSinceEpoch - notifierLastUpdate) < 2000;
              
              // ✅ CRITIQUE: Si le notifier a un timestamp récent, TOUJOURS le protéger en PRIORITÉ
              // Ne JAMAIS écraser une mise à jour récente, même si les quantités diffèrent
              if (isRecentUpdate) {
                // Le notifier a été mis à jour récemment, ne JAMAIS l'écraser
                // Mais s'assurer que tous les autres champs sont synchronisés
                final syncedArticle = Map<String, dynamic>.from(notifier.value);
                syncedArticle.addAll(sourceArticle);
                // Garder iqte du notifier (priorité absolue pour les mises à jour récentes)
                syncedArticle['iqte'] = notifierQuantity;
                syncedArticle['_lastUpdate'] = notifierLastUpdate;
                // Ne mettre à jour que si nécessaire pour éviter les rebuilds inutiles
                if (!mapEquals(syncedArticle, notifier.value)) {
                  notifier.value = Map<String, dynamic>.from(syncedArticle);
                }
              } else if (sourceQuantity != notifierQuantity) {
                // Seulement synchroniser si le notifier n'a PAS de timestamp récent ET que les quantités diffèrent
                final syncedArticle = Map<String, dynamic>.from(notifier.value);
                syncedArticle.addAll(sourceArticle);
                syncedArticle['iqte'] = sourceQuantity; // Utiliser la quantité de sourceArticle
                notifier.value = Map<String, dynamic>.from(syncedArticle);
              } else {
                // Les quantités sont identiques et pas de mise à jour récente, juste synchroniser les autres champs
                final syncedArticle = Map<String, dynamic>.from(notifier.value);
                syncedArticle.addAll(sourceArticle);
                syncedArticle['iqte'] = sourceQuantity;
                if (!mapEquals(syncedArticle, notifier.value)) {
                  notifier.value = Map<String, dynamic>.from(syncedArticle);
                }
              }
              
              return ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: notifier,
                builder: (context, articleValue, _) {
                  // ✅ CRITIQUE: TOUJOURS utiliser la valeur du notifier si elle existe et contient des données valides
                  // Le notifier est la source de vérité pour les mises à jour en temps réel
                  Map<String, dynamic> displayArticle;
                  
                  if (articleValue.isNotEmpty && articleValue.containsKey('iqte')) {
                    // Utiliser la valeur du notifier (source de vérité pour les mises à jour)
                    displayArticle = Map<String, dynamic>.from(articleValue);
                    // Fusionner avec sourceArticle pour garantir tous les champs
                    displayArticle.addAll(sourceArticle);
                    // Mais garder iqte du notifier (priorité absolue)
                    displayArticle['iqte'] = articleValue['iqte'];
                  } else {
                    // Fallback: utiliser sourceArticle si le notifier est vide
                    displayArticle = Map<String, dynamic>.from(sourceArticle);
                  }
                  
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
            flex: isVerySmallMobile ? 6 : (isSmallMobile ? 4 : (isMobile ? 3 : 3)),
            child: _buildLeftColumn(baseArticle, translationService, imageUrl, name, code, quantity, codeCrypt, articleNotifier: articleNotifier, isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
          ),
          
          SizedBox(width: isVerySmallMobile ? 2 : (isSmallMobile ? 3 : (isMobile ? 6 : 8))),
          
          // Colonne droite - Prix et pays
          Expanded(
            flex: isVerySmallMobile ? 4 : (isSmallMobile ? 3 : (isMobile ? 2 : 2)),
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
    
    // ✅ Vérifier si cet article est en cours de suppression
    final articleCode = codeCrypt.isNotEmpty ? codeCrypt : code;
    final isDeleting = _isDeletingAll && _articlesToDelete.contains(articleCode);
    
    if (!_animationsInitialized) {
      return rowWidget;
    }
    
    // ✨ Animation de SUPPRESSION : Fade out + Slide out + Scale down (en cascade)
    if (isDeleting) {
      // Utiliser l'index passé en paramètre pour créer un délai progressif
      // Chaque article commence son animation avec un délai de 50ms * index
      final delayMs = itemIndex * 50; // 50ms entre chaque article pour l'effet cascade
      
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500), // Durée de l'animation de suppression
        tween: Tween<double>(begin: 1.0, end: 0.0),
        curve: Curves.easeInCubic, // Animation fluide de sortie
        builder: (context, value, child) {
          // Calculer la valeur avec délai : si on est dans la période de délai, value reste à 1.0
          final totalDuration = 500.0;
          final delayRatio = delayMs / totalDuration;
          final animatedValue = value > (1.0 - delayRatio)
              ? 1.0 // Pendant le délai, garder à 1.0
              : ((value - (1.0 - delayRatio)) / delayRatio).clamp(0.0, 1.0); // Après le délai, animer
          
          // Combinaison de fade, slide et scale pour un effet élégant
          final opacity = animatedValue.clamp(0.0, 1.0);
          final scale = 0.5 + (animatedValue * 0.5); // Scale de 1.0 à 0.5 (rétrécissement prononcé)
          final slideOffset = 400 * (1 - animatedValue); // Slide vers la droite (400px max)
          
          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(slideOffset, 0), // Slide vers la droite
              child: Opacity(
                opacity: opacity, // Fade out progressif
                child: child,
              ),
            ),
          );
        },
        child: rowWidget,
      );
    }
    
    // ✨ Animation Articles : Slide in séquencé depuis le bas avec bounce (entrée normale)
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
                         String imageUrl, String name, String code, int quantity, String codeCrypt, {ValueNotifier<Map<String, dynamic>>? articleNotifier, bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false}) {
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
        // Dans _buildLeftColumn, remplacez le Container du sélecteur de quantité par ceci :

        // Contrôles (trophée, poubelle, quantité)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Utiliser spaceBetween au lieu de Spacer
          children: [
            // Groupe Gauche: Trophée + Poubelle
            Row(
              mainAxisSize: MainAxisSize.min, // Important pour ne pas prendre toute la place
              children: [
                // Bouton Podium
                GestureDetector(
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

                SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 12 : 16)),
                
                // Bouton Supprimer
                GestureDetector(
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
              ],
            ),
            
            // Espace flexible minimal si nécessaire (optionnel car spaceBetween gère l'espace)
            // SizedBox(width: isVerySmallMobile ? 4 : 8),
            
            // Contrôle quantité
            Flexible(
              fit: FlexFit.loose, // Important: loose pour ne pas forcer l'expansion
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox( // ✅ Ajout de FittedBox pour réduire la taille si nécessaire
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    // ✅ Largeur maximale contrainte
                    constraints: BoxConstraints(
                      maxWidth: isVerySmallMobile ? 90 : (isSmallMobile ? 100 : 110),
                    ),
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
                    child: articleNotifier != null
                      ? ValueListenableBuilder<Map<String, dynamic>>(
                          valueListenable: articleNotifier,
                          builder: (context, articleValue, _) {
                            final currentQuantity = articleValue['iqte'] as int? ?? quantity;
                            print('🔄 ValueListenableBuilder reconstruit - quantité affichée: $currentQuantity (depuis notifier: ${articleValue['iqte']}, fallback: $quantity)');
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Bouton moins
                                GestureDetector(
                                  onTap: currentQuantity > 1 ? () => _updateQuantity(codeCrypt, currentQuantity - 1) : null,
                                  child: Container(
                                    width: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
                                    height: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
                                    decoration: BoxDecoration(
                                      color: currentQuantity > 1 ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        bottomLeft: Radius.circular(8),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16),
                                      color: currentQuantity > 1 ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                                // Zone du nombre - ✅ Utilise currentQuantity du ValueListenableBuilder parent
                                GestureDetector(
                                  onTap: () => _showQuantityPickerDialog(codeCrypt, currentQuantity),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      minWidth: isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
                                      maxWidth: isVerySmallMobile ? 28 : (isSmallMobile ? 32 : 36),
                                    ),
                                    height: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
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
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$currentQuantity',
                                        style: TextStyle(
                                          fontSize: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : 14),
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Bouton plus
                                GestureDetector(
                                  onTap: () => _updateQuantity(codeCrypt, currentQuantity + 1),
                                  child: Container(
                                    width: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
                                    height: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
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
                            );
                          },
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bouton moins (fallback sans notifier)
                            GestureDetector(
                              onTap: quantity > 1 ? () => _updateQuantity(codeCrypt, quantity - 1) : null,
                              child: Container(
                                width: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
                                height: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
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
                            // Zone du nombre (fallback sans notifier)
                            GestureDetector(
                              onTap: () => _showQuantityPickerDialog(codeCrypt, quantity),
                              child: Container(
                                constraints: BoxConstraints(
                                  minWidth: isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
                                  maxWidth: isVerySmallMobile ? 28 : (isSmallMobile ? 32 : 36),
                                ),
                                height: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
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
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$quantity',
                                    style: TextStyle(
                                      fontSize: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : 14),
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Bouton plus (fallback sans notifier)
                            GestureDetector(
                              onTap: () => _updateQuantity(codeCrypt, quantity + 1),
                              child: Container(
                                width: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
                                height: isVerySmallMobile ? 24 : (isSmallMobile ? 28 : 32),
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
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ Helper pour construire une ligne de drapeau de pays avec icône panier si nécessaire
  Widget _buildCountryFlagRow(
    String countryCode,
    Map<String, dynamic> article, {
    bool isMobile = false,
    bool isSmallMobile = false,
  }) {
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
    // ✅ Vérifier si un pays est sélectionné (comme SNAL isCountrySelected)
    // spaysSelected peut être null, '', false, ou un code pays
    final rawSpaysSelected = article['spaysSelected'] ?? article['sPaysSelected'];
    final bool isCountrySelected = rawSpaysSelected != null && 
                                   rawSpaysSelected != '' && 
                                   rawSpaysSelected != false &&
                                   rawSpaysSelected.toString().trim().isNotEmpty;
    
    // ✅ Utiliser le pays sélectionné si disponible, sinon utiliser le meilleur prix comme fallback
    String? selectedCountry;
    if (isCountrySelected) {
      selectedCountry = rawSpaysSelected.toString().trim().toUpperCase();
    }
    
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
    
    // Si un pays est sélectionné, utiliser son prix
    if (isCountrySelected && selectedCountry?.isNotEmpty == true) {
      final priceStr = article[selectedCountry]?.toString() ?? '';
      selectedPrice = _extractPriceFromString(priceStr);
    }
    
    // ✅ Si pas de pays sélectionné, utiliser le meilleur prix UNIQUEMENT pour l'affichage du prix
    // mais NE PAS considérer ce pays comme "sélectionné" (isCountrySelected reste false)
    String? displayCountry = selectedCountry;
    double displayPrice = selectedPrice;
    if (!isCountrySelected) {
      // Aucun pays sélectionné : afficher le meilleur prix en gris
      if (bestPriceCountry?.isNotEmpty == true && bestPrice < double.infinity) {
        displayCountry = bestPriceCountry;
        displayPrice = bestPrice;
      }
    }
    
    if (displayCountry != null && displayCountry!.isNotEmpty && paysListe.isNotEmpty) {
      final pays = paysListe.firstWhere(
        (p) => p['sPays'] == displayCountry,
        orElse: () => paysListe.first,
      );
      
      final sDescr = pays['sDescr'] ?? displayCountry;
      final sFlag = pays['sFlag'] ?? '';
      
      // Vérifier si ce pays a le meilleur prix
      final isBestPrice = displayCountry == bestPriceCountry;
      
      // ✅ Couleurs selon si un pays est sélectionné (comme SNAL)
      // Si isCountrySelected = false : container gris très clair, texte gris (même si on affiche le meilleur prix)
      // Si isCountrySelected = true : vert, texte blanc
      final buttonColor = isCountrySelected 
          ? const Color(0xFF22C55F) // Vert #22C55F (comme SNAL green)
          : Colors.grey[100]!; // ✅ Gris très clair pour le container (comme SNAL gray soft)
      final textColor = isCountrySelected 
          ? Colors.white 
          : Colors.grey[400]!; // text-gray-400 (comme SNAL)
      
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
                // ✅ Médaille toujours en noir (même si pas sélectionné)
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
                      defaultSelectedCountry: isCountrySelected ? (selectedCountry ?? '') : '',
                      articleNotifier: articleNotifier,
                    ),
                    child: Text(
                      sDescr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF212529), // ✅ Toujours en noir
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
          // ✅ Container gris très clair si pas de pays sélectionné (comme SNAL variant="soft" color="gray")
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openCountrySidebarForArticle(
                sourceArticle ?? article,
                defaultSelectedCountry: isCountrySelected ? (selectedCountry ?? '') : '',
                articleNotifier: articleNotifier,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: buttonColor, // ✅ Gris très clair si pas sélectionné, vert si sélectionné
                  borderRadius: BorderRadius.circular(20), // Forme de capsule
                ),
                child: Text(
                  displayPrice > 0 
                      ? '${displayPrice.toStringAsFixed(2)} €'
                      : 'N/A',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor, // ✅ text-gray-400 si pas sélectionné, blanc si sélectionné
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Autres drapeaux + bouton + (Wrap pour éviter overflow)
          // ✅ Utiliser les pays sélectionnés globalement dans CountryManagementModal (comme SNAL countriesList.slice(0, 3))
          // MAIS exclure le pays déjà affiché en haut (selectedCountry)
          FutureBuilder<List<String>>(
            future: _getCurrentSelectedCountries(),
            builder: (context, snapshot) {
              // Récupérer les pays sélectionnés globalement
              final globalSelectedCountries = snapshot.data ?? [];
              
              // ✅ Filtrer pour exclure AT/CH uniquement, mais inclure tous les autres pays sélectionnés
              // (y compris le displayCountry s'il fait partie des pays sélectionnés)
              final filteredCountries = globalSelectedCountries
                  .where((code) => 
                    code.isNotEmpty && 
                    code != 'AT' && 
                    code != 'CH'
                  )
                  .toList();
              
              // ✅ Prendre les 3 premiers pays sélectionnés (comme SNAL countriesList.slice(0, 3))
              // Inclure le displayCountry s'il fait partie des pays sélectionnés
              final finalAvailableCountries = filteredCountries.take(3).toList();
              
              // ✅ Ne pas afficher les drapeaux si aucun pays disponible
              if (finalAvailableCountries.isEmpty) {
                return Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: isMobile ? 4 : 6,
                  runSpacing: 2,
                  children: [
                    // Bouton + bleu uniquement (pas de drapeaux)
                    GestureDetector(
                      onTap: () => _openCountrySidebarForArticle(
                        article,
                        defaultSelectedCountry: isCountrySelected ? (selectedCountry ?? '') : '',
                      ),
                      child: Container(
                        width: 24,
                        height: 24,
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
                );
              }
              
              final countriesToShow = finalAvailableCountries;
              final hasOnlyOneCountry = countriesToShow.length == 1;
              
              return Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: isMobile ? 4 : 6,
                runSpacing: 2,
                children: [
                  // ✅ Si un seul pays, mettre le drapeau et le bouton + dans un Row centré
                  if (hasOnlyOneCountry)
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCountryFlagRow(
                            countriesToShow[0],
                            article,
                            isMobile: isMobile,
                            isSmallMobile: isSmallMobile,
                          ),
                          // Bouton + bleu à côté du drapeau
                          GestureDetector(
                            onTap: () => _openCountrySidebarForArticle(
                              article,
                              defaultSelectedCountry: isCountrySelected ? (selectedCountry ?? '') : '',
                            ),
                            child: Container(
                              width: 24,
                              height: 24,
                              margin: EdgeInsets.only(left: isMobile ? 4 : 6),
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
                    )
                  else ...[
                    // Plusieurs pays : afficher les drapeaux puis le bouton +
                    ...countriesToShow.map((countryCode) {
                      return _buildCountryFlagRow(
                        countryCode,
                        article,
                        isMobile: isMobile,
                        isSmallMobile: isSmallMobile,
                      );
                    }).toList(),
                    // Bouton + bleu (ouvre le sidebar de sélection de pays pour cet article)
                    GestureDetector(
                      onTap: () => _openCountrySidebarForArticle(
                        article,
                        defaultSelectedCountry: isCountrySelected ? (selectedCountry ?? '') : '',
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
                ],
              );
            },
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
      // Debug log désactivé pour éviter la pollution des logs
      // print('🔍 Prix trouvé pour $selectedCountry: $selectedPrice');
      
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
                    // fontFamily non spécifié = utilise la police système (équivalent à system-ui)
                    fontStyle: FontStyle.normal, // Style: normal
                    fontSize: 16.0, // Size: 16px
                    fontWeight: FontWeight.w400, // Weight: 400 (normal)
                    color: Color.fromRGBO(0, 0, 0, 1.0), // Color: rgb(0, 0, 0) - noir
                    height: 24.0 / 16.0, // Line Height: 24px / 16px = 1.5
                    letterSpacing: 0.0, // Pas de letterSpacing
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

  String _normalizeFlagUrl(String? rawFlag) {
    final value = rawFlag?.trim();
    if (value == null || value.isEmpty) {
      return '';
    }

    final lower = value.toLowerCase();
    if (value.startsWith('#') || lower.startsWith('rgb')) {
      return '';
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return ApiConfig.getProxiedImageUrl(value);
    }

    if (value.startsWith('//')) {
      return ApiConfig.getProxiedImageUrl('https:$value');
    }

    if (value.startsWith('/')) {
      return ApiConfig.getProxiedImageUrl('https://jirig.be$value');
    }

    return ApiConfig.getProxiedImageUrl('https://jirig.be/$value');
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
class _CountryManagementData {
  final List<Map<String, dynamic>> availableCountries;
  final List<String> selectedCountries;
  final String? lockedCountryCode;

  const _CountryManagementData({
    required this.availableCountries,
    required this.selectedCountries,
    required this.lockedCountryCode,
  });

  _CountryManagementData copyWith({
    List<Map<String, dynamic>>? availableCountries,
    List<String>? selectedCountries,
    String? lockedCountryCode,
  }) {
    return _CountryManagementData(
      availableCountries: availableCountries ?? this.availableCountries,
      selectedCountries: selectedCountries ?? this.selectedCountries,
      lockedCountryCode: lockedCountryCode ?? this.lockedCountryCode,
    );
  }
}

class _CountrySidebarModal extends StatefulWidget {
  final ValueNotifier<Map<String, dynamic>> articleNotifier;
  final List<Map<String, dynamic>> availableCountries;
  final List<Map<String, dynamic>> allAvailableCountries; // ✅ Tous les pays disponibles (pas seulement ceux avec un prix)
  final String currentSelected;
  final String? homeCountryCode;
  final Future<void> Function(String) onCountrySelected;
  final Future<List<Map<String, dynamic>>?> Function() onManageCountries;

  const _CountrySidebarModal({
    Key? key,
    required this.articleNotifier,
    required this.availableCountries,
    required this.allAvailableCountries,
    required this.currentSelected,
    required this.homeCountryCode,
    required this.onCountrySelected,
    required this.onManageCountries,
  }) : super(key: key);

  @override
  State<_CountrySidebarModal> createState() => _CountrySidebarModalState();
}

class _CountrySidebarModalState extends State<_CountrySidebarModal> with SingleTickerProviderStateMixin {
  late String _selectedCountry;
  late Map<String, dynamic> _currentArticle;
  bool _isChanging = false;
  late String _initialHomeCountryCode;
  late final List<Map<String, dynamic>> _baseCountries;
  late List<Map<String, dynamic>> _availableCountries;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isDisposed = false; // ✅ Flag pour éviter les appels après dispose

  @override
  void initState() {
    super.initState();
    // ✅ Vérifier si un pays est sélectionné (comme SNAL isCountrySelected)
    // Si spaysSelected est vide/false/null, aucun pays n'est sélectionné
    final rawSpaysSelected = widget.currentSelected;
    final bool isCountrySelected = rawSpaysSelected != null && 
                                   rawSpaysSelected != '' && 
                                   rawSpaysSelected != false &&
                                   rawSpaysSelected != '-1' &&
                                   rawSpaysSelected.toString().trim().isNotEmpty;
    // ✅ Initialiser à vide si aucun pays n'est sélectionné
    _selectedCountry = isCountrySelected ? rawSpaysSelected.toString().trim().toUpperCase() : '';
    print('🔍 CountrySidebarModal initState:');
    print('   widget.currentSelected: $rawSpaysSelected');
    print('   isCountrySelected: $isCountrySelected');
    print('   _selectedCountry initialisé à: "${_selectedCountry.isEmpty ? "(vide - aucun pays sélectionné)" : _selectedCountry}"');
    _currentArticle = widget.articleNotifier.value;
    _initialHomeCountryCode = (widget.homeCountryCode ?? '').toUpperCase();
    _baseCountries = widget.availableCountries.map((c) => Map<String, dynamic>.from(c)).toList();
    
    // ✅ Initialiser _availableCountries de manière synchrone avec tous les pays de base
    // La méthode asynchrone _initializeAvailableCountries() mettra à jour la liste ensuite
    _availableCountries = _baseCountries.map((c) => Map<String, dynamic>.from(c)).toList();
    
    // ✅ Filtrer les pays disponibles selon ceux sélectionnés dans localStorage (asynchrone)
    _initializeAvailableCountries();
    
    widget.articleNotifier.addListener(_onArticleNotifierChanged);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
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
    
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  /// Initialiser les pays disponibles selon ceux sélectionnés dans localStorage
  Future<void> _initializeAvailableCountries({bool useSetState = false}) async {
    try {
      // ✅ CORRECTION: Mettre à jour _currentArticle depuis widget.articleNotifier AVANT de construire les pays
      // Cela garantit que les prix des nouveaux pays ajoutés sont disponibles
      try {
        _currentArticle = Map<String, dynamic>.from(widget.articleNotifier.value);
        print('🔄 _initializeAvailableCountries - _currentArticle mis à jour depuis articleNotifier');
        
        // ✅ Debug: Afficher tous les prix disponibles dans _currentArticle
        final allCountryKeys = _currentArticle.keys.where((k) => 
          k.length == 2 && 
          k.toUpperCase() == k && 
          RegExp(r'^[A-Z]{2}$').hasMatch(k)
        ).toList();
        print('📦 Tous les prix dans _currentArticle (initialisation):');
        for (final key in allCountryKeys) {
          print('   💰 $key: ${_currentArticle[key]}');
        }
        
        // ✅ CORRECTION CRITIQUE: Si des prix sont manquants dans _currentArticle,
        // cela signifie que le notifier n'a pas été mis à jour avec les nouveaux prix.
        // Dans ce cas, on doit forcer la mise à jour depuis widget.articleNotifier.value
        // qui pourrait avoir été mis à jour par syncListener même si sourceNotifier est disposé
        final sCodeArticleCrypt = _currentArticle['sCodeArticleCrypt']?.toString() ?? '';
        if (sCodeArticleCrypt.isNotEmpty) {
          // Récupérer les pays sélectionnés pour vérifier les prix manquants
          final selectedCountries = await LocalStorageService.getSelectedCountries();
          final selectedCodes = selectedCountries.map((c) => c.toUpperCase()).toSet();
          final missingPrices = <String>[];
          for (final countryCode in selectedCodes) {
            if (!_currentArticle.containsKey(countryCode) || 
                _currentArticle[countryCode] == null ||
                _currentArticle[countryCode].toString().trim().isEmpty) {
              missingPrices.add(countryCode);
            }
          }
          
          if (missingPrices.isNotEmpty) {
            print('⚠️ Prix manquants détectés dans _currentArticle pour: $missingPrices');
            print('   🔍 Tentative de récupération depuis widget.articleNotifier.value...');
            try {
              final notifierValue = widget.articleNotifier.value;
              for (final countryCode in missingPrices) {
                if (notifierValue.containsKey(countryCode) && 
                    notifierValue[countryCode] != null &&
                    notifierValue[countryCode].toString().trim().isNotEmpty) {
                  _currentArticle[countryCode] = notifierValue[countryCode];
                  print('   ✅ Prix $countryCode récupéré depuis widget.articleNotifier.value: ${notifierValue[countryCode]}');
                }
              }
            } catch (e) {
              print('   ⚠️ Erreur lors de la récupération depuis widget.articleNotifier.value: $e');
            }
          }
        }
      } catch (e) {
        print('⚠️ Impossible de mettre à jour _currentArticle: $e');
      }
      
      // Récupérer les pays sélectionnés depuis localStorage
      final selectedCountries = await LocalStorageService.getSelectedCountries();
      final selectedCodes = selectedCountries.map((c) => c.toUpperCase()).toSet();
      
      print('🌍 Pays sélectionnés dans localStorage: $selectedCodes');
      print('📋 Pays de base disponibles: ${_baseCountries.map((c) => c['code']).toList()}');
      
      // ✅ Créer un map des pays de base pour un accès rapide
      final baseCountriesMap = <String, Map<String, dynamic>>{};
      for (final baseCountry in _baseCountries) {
        final code = baseCountry['code']?.toString().toUpperCase() ?? '';
        if (code.isNotEmpty) {
          baseCountriesMap[code] = baseCountry;
        }
      }
      
      // ✅ CORRECTION CRITIQUE: Construire TOUJOURS la liste complète des pays sélectionnés
      // Cela garantit que tous les pays sélectionnés sont affichés, même ceux qui viennent d'être ajoutés
      final filteredCountries = <Map<String, dynamic>>[];
      final processedCodes = <String>{};
      
      // ✅ Étape 1: Ajouter les pays sélectionnés qui sont dans _baseCountries (avec leurs prix)
      for (final baseCountry in _baseCountries) {
        final code = baseCountry['code']?.toString().toUpperCase() ?? '';
        if (code.isNotEmpty && selectedCodes.contains(code)) {
          // ✅ _currentArticle a été mis à jour, donc _buildCountryDetails peut récupérer les prix
          final countryDetails = _buildCountryDetails(code);
          filteredCountries.add(countryDetails);
          processedCodes.add(code);
          print('✅ Pays ajouté depuis _baseCountries (init): $code - prix: ${countryDetails['price']}');
        }
      }
      
      // ✅ Étape 2: Ajouter les pays sélectionnés qui ne sont PAS dans _baseCountries
      // Ces pays ont été sélectionnés dans CountryManagementModal et ont maintenant des prix dans _currentArticle
      // On doit les récupérer depuis widget.allAvailableCountries pour avoir leurs infos (nom, drapeau)
      final allAvailableMap = <String, Map<String, dynamic>>{};
      for (final country in widget.allAvailableCountries) {
        final code = country['code']?.toString().toUpperCase() ?? '';
        if (code.isNotEmpty) {
          allAvailableMap[code] = country;
        }
      }
      
      // ✅ CORRECTION CRITIQUE: Parcourir TOUS les pays sélectionnés
      for (final selectedCode in selectedCodes) {
        if (!processedCodes.contains(selectedCode)) {
          // Ce pays est sélectionné mais n'a pas encore été ajouté
          // Récupérer ses infos depuis widget.allAvailableCountries
          final countryInfo = allAvailableMap[selectedCode];
          if (countryInfo != null) {
            // Construire les détails du pays avec les infos disponibles
            // ✅ _buildCountryDetails récupère automatiquement le prix depuis _currentArticle (mis à jour)
            // On passe seulement les infos de base (nom, drapeau) et laisse _buildCountryDetails gérer le prix
            final countryDetails = _buildCountryDetails(
              selectedCode,
              nameOverride: countryInfo['name']?.toString(),
              flagOverride: countryInfo['flag']?.toString(),
              // ✅ Ne pas passer priceOverride, laisser _buildCountryDetails récupérer depuis _currentArticle
            );
            
            print('💰 Pays $selectedCode ajouté (init) - isAvailable: ${countryDetails['isAvailable']}, price: ${countryDetails['price']}');
            print('   📦 Prix dans _currentArticle: ${_currentArticle[selectedCode]}');
            filteredCountries.add(countryDetails);
            processedCodes.add(selectedCode);
            print('✅ Ajout du pays sélectionné (init): $selectedCode');
          } else {
            // ✅ Fallback: Si le pays n'est pas dans allAvailableCountries, créer un pays basique
            print('⚠️ Pays $selectedCode non trouvé dans allAvailableCountries (init), création d\'un pays basique');
            final countryDetails = _buildCountryDetails(selectedCode);
            filteredCountries.add(countryDetails);
            processedCodes.add(selectedCode);
            print('✅ Pays basique créé (init): $selectedCode - prix: ${countryDetails['price']}');
          }
        }
      }
      
      // ✅ CORRECTION CRITIQUE: Vérifier qu'on a bien tous les pays sélectionnés
      final missingCountries = selectedCodes.difference(processedCodes);
      if (missingCountries.isNotEmpty) {
        print('⚠️ Pays sélectionnés manquants dans la liste finale (init): $missingCountries');
        // Essayer de les ajouter quand même
        for (final missingCode in missingCountries) {
          final countryDetails = _buildCountryDetails(missingCode);
          filteredCountries.add(countryDetails);
          print('✅ Pays manquant ajouté (init): $missingCode - prix: ${countryDetails['price']}');
        }
      }
      
      // Si aucun pays n'est sélectionné, utiliser tous les pays de base (fallback)
      final newAvailableCountries = filteredCountries.isNotEmpty 
          ? filteredCountries 
          : _baseCountries.map((c) => Map<String, dynamic>.from(c)).toList();
      
      // ✅ Toujours utiliser setState si le widget est monté pour mettre à jour l'UI
      if (mounted && !_isDisposed) {
        setState(() {
          _availableCountries = newAvailableCountries;
        });
      } else {
        _availableCountries = newAvailableCountries;
      }
      
      print('📊 Pays disponibles après initialisation: ${_availableCountries.map((c) => c['code']).toList()}');
      print('📊 Nombre de pays: ${_availableCountries.length}');
      for (final country in _availableCountries) {
        final code = country['code']?.toString() ?? '';
        final price = country['price']?.toString() ?? 'N/A';
        final isAvailable = country['isAvailable'] ?? false;
        print('   💰 $code: $price (disponible: $isAvailable)');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des pays disponibles: $e');
      // Fallback sur tous les pays de base
      final fallbackCountries = _baseCountries.map((c) => Map<String, dynamic>.from(c)).toList();
      if (mounted && !_isDisposed) {
        setState(() {
          _availableCountries = fallbackCountries;
        });
      } else {
        _availableCountries = fallbackCountries;
      }
    }
  }

  void _onArticleNotifierChanged() async {
    // ✅ Vérifier le flag de dispose en premier
    if (_isDisposed || !mounted) return;
    
    print('🔄 ========== _onArticleNotifierChanged DÉCLENCHÉ ==========');
    
    // ✅ CORRECTION CRITIQUE: Récupérer IMMÉDIATEMENT la valeur la plus récente depuis articleNotifier.value
    // Ne pas utiliser newArticle qui pourrait être une ancienne référence
    Map<String, dynamic> latestArticle;
    try {
      latestArticle = widget.articleNotifier.value;
      print('✅ Article récupéré depuis articleNotifier.value');
      
      // ✅ Debug: Afficher TOUS les prix disponibles
      final allCountryKeys = latestArticle.keys.where((k) => 
        k.length == 2 && 
        k.toUpperCase() == k && 
        RegExp(r'^[A-Z]{2}$').hasMatch(k)
      ).toList();
      print('📦 TOUS les prix dans articleNotifier.value:');
      for (final key in allCountryKeys) {
        print('   💰 $key: ${latestArticle[key]}');
      }
    } catch (e) {
      print('⚠️ ValueNotifier disposé, arrêt de la mise à jour: $e');
      return;
    }
    
    // ✅ CORRECTION CRITIQUE: Mettre à jour _currentArticle IMMÉDIATEMENT avec la valeur la plus récente
    // Cela garantit que _buildCountryDetails() peut toujours trouver les prix
    _currentArticle = Map<String, dynamic>.from(latestArticle);
    print('✅ _currentArticle mis à jour depuis articleNotifier.value');
    
    // Récupérer les pays sélectionnés depuis localStorage pour reconstruire la liste
    final selectedCountries = await LocalStorageService.getSelectedCountries();
    
    // ✅ Vérifier que le widget est toujours monté et non disposé après l'opération async
    if (_isDisposed || !mounted) return;
    
    final selectedCodes = selectedCountries.map((c) => c.toUpperCase()).toSet();
    
    print('🔄 Pays sélectionnés: $selectedCodes');
    
    // ✅ Vérifier une dernière fois que le widget est monté et non disposé avant setState
    if (_isDisposed || !mounted) return;
    
    // ✅ CORRECTION CRITIQUE: Toujours reconstruire la liste complète
    // Car les prix peuvent avoir changé même si les pays sélectionnés sont les mêmes
    // De plus, de nouveaux pays peuvent avoir été ajoutés dans CountryManagementModal
    
    setState(() {
      // ✅ Vérifier si un pays est sélectionné (comme SNAL isCountrySelected)
      final rawSpaysSelected = _currentArticle['spaysSelected'] ?? _currentArticle['sPaysSelected'];
      final bool isCountrySelected = rawSpaysSelected != null && 
                                     rawSpaysSelected != '' && 
                                     rawSpaysSelected != false &&
                                     rawSpaysSelected != '-1' &&
                                     rawSpaysSelected.toString().trim().isNotEmpty;
      // ✅ Mettre à jour _selectedCountry : vide si désélectionné, sinon le code du pays
      final newSelectedCountry = isCountrySelected ? rawSpaysSelected.toString().trim().toUpperCase() : '';
      if (newSelectedCountry != _selectedCountry) {
        _selectedCountry = newSelectedCountry;
      }

      // ✅ CORRECTION CRITIQUE: Reconstruire TOUJOURS la liste complète des pays sélectionnés
      // Cela garantit que les nouveaux pays ajoutés dans CountryManagementModal sont immédiatement visibles
      final orderedAvailableCountries = <Map<String, dynamic>>[];
      final processedCodes = <String>{};
      
      // ✅ Étape 1: Ajouter les pays sélectionnés qui sont dans _baseCountries (avec leurs prix)
      // Ces pays ont déjà des prix dans _currentArticle
      for (final baseCountry in _baseCountries) {
        final code = baseCountry['code']?.toString().toUpperCase() ?? '';
        if (code.isNotEmpty && selectedCodes.contains(code)) {
          // Le pays est sélectionné, l'ajouter dans l'ordre original
          // ✅ _currentArticle a été mis à jour AVANT setState, donc _buildCountryDetails peut récupérer les prix
          final countryDetails = _buildCountryDetails(code);
          orderedAvailableCountries.add(countryDetails);
          processedCodes.add(code);
          print('✅ Pays ajouté depuis _baseCountries: $code - prix: ${countryDetails['price']}, disponible: ${countryDetails['isAvailable']}');
        }
      }
      
      // ✅ Étape 2: Ajouter les pays sélectionnés qui ne sont PAS dans _baseCountries
      // Ces pays ont été ajoutés dans CountryManagementModal et ont maintenant des prix dans _currentArticle
      // On doit les récupérer depuis widget.allAvailableCountries pour avoir leurs infos (nom, drapeau)
      final allAvailableMap = <String, Map<String, dynamic>>{};
      for (final country in widget.allAvailableCountries) {
        final code = country['code']?.toString().toUpperCase() ?? '';
        if (code.isNotEmpty) {
          allAvailableMap[code] = country;
        }
      }
      
      // ✅ CORRECTION CRITIQUE: Parcourir TOUS les pays sélectionnés, pas seulement ceux qui ne sont pas dans _baseCountries
      // Car un pays peut être dans _baseCountries mais avoir un nouveau prix après modification
      for (final selectedCode in selectedCodes) {
        if (!processedCodes.contains(selectedCode)) {
          // Ce pays est sélectionné mais n'a pas encore été ajouté
          // Récupérer ses infos depuis widget.allAvailableCountries
          final countryInfo = allAvailableMap[selectedCode];
          if (countryInfo != null) {
            // Construire les détails du pays avec les infos disponibles
            // ✅ _buildCountryDetails récupère automatiquement le prix depuis _currentArticle (mis à jour AVANT setState)
            // On passe seulement les infos de base (nom, drapeau) et laisse _buildCountryDetails gérer le prix
            final countryDetails = _buildCountryDetails(
              selectedCode,
              nameOverride: countryInfo['name']?.toString(),
              flagOverride: countryInfo['flag']?.toString(),
              // ✅ Ne pas passer priceOverride, laisser _buildCountryDetails récupérer depuis _currentArticle
            );
            
            print('💰 Pays $selectedCode ajouté - isAvailable: ${countryDetails['isAvailable']}, price: ${countryDetails['price']}');
            print('   📦 Prix dans _currentArticle: ${_currentArticle[selectedCode]}');
            orderedAvailableCountries.add(countryDetails);
            processedCodes.add(selectedCode);
            print('✅ Ajout du pays sélectionné: $selectedCode');
          } else {
            // ✅ Fallback: Si le pays n'est pas dans allAvailableCountries, créer un pays basique
            // Cela peut arriver si un nouveau pays a été ajouté mais n'est pas encore dans allAvailableCountries
            print('⚠️ Pays $selectedCode non trouvé dans allAvailableCountries, création d\'un pays basique');
            final countryDetails = _buildCountryDetails(selectedCode);
            orderedAvailableCountries.add(countryDetails);
            processedCodes.add(selectedCode);
            print('✅ Pays basique créé: $selectedCode - prix: ${countryDetails['price']}');
          }
        }
      }
      
      // ✅ CORRECTION CRITIQUE: Vérifier qu'on a bien tous les pays sélectionnés
      final missingCountries = selectedCodes.difference(processedCodes);
      if (missingCountries.isNotEmpty) {
        print('⚠️ Pays sélectionnés manquants dans la liste finale: $missingCountries');
        // Essayer de les ajouter quand même
        for (final missingCode in missingCountries) {
          final countryDetails = _buildCountryDetails(missingCode);
          orderedAvailableCountries.add(countryDetails);
          print('✅ Pays manquant ajouté: $missingCode - prix: ${countryDetails['price']}');
        }
      }
      
      // ✅ Toujours mettre à jour _availableCountries, même si la liste est vide
      // Cela garantit que l'UI se met à jour avec les nouveaux pays
      _availableCountries = orderedAvailableCountries.isNotEmpty 
          ? orderedAvailableCountries 
          : _baseCountries.map((c) => Map<String, dynamic>.from(c)).toList();
      
      print('📊 Pays disponibles après mise à jour: ${_availableCountries.map((c) => c['code']).toList()}');
      print('📊 Nombre de pays: ${_availableCountries.length}');
      for (final country in _availableCountries) {
        final code = country['code']?.toString() ?? '';
        final price = country['price']?.toString() ?? 'N/A';
        final isAvailable = country['isAvailable'] ?? false;
        print('   💰 $code: $price (disponible: $isAvailable)');
      }
    });
  }

  bool _setsEqual(Set<String> set1, Set<String> set2) {
    if (set1.length != set2.length) return false;
    for (final item in set1) {
      if (!set2.contains(item)) return false;
    }
    return true;
  }

  String _resolveHomeCountryCode() {
    final articleHome = _currentArticle['sMyHomeIcon'] ?? _currentArticle['smyhomeicon'];
    if (articleHome is String && articleHome.isNotEmpty) {
      return articleHome.toUpperCase();
    }
    return _initialHomeCountryCode;
  }

  double _parsePrice(String rawPrice) {
    final cleaned = rawPrice.replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
    final match = RegExp(r'\d+\.?\d*').firstMatch(cleaned);
    if (match != null) {
      return double.tryParse(match.group(0) ?? '') ?? 0.0;
    }
    return 0.0;
  }

  String _normalizeFlagUrl(String? rawFlag) {
    final value = rawFlag?.trim();
    if (value == null || value.isEmpty) {
      return '';
    }

    final lower = value.toLowerCase();
    if (value.startsWith('#') || lower.startsWith('rgb')) {
      return '';
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return ApiConfig.getProxiedImageUrl(value);
    }

    if (value.startsWith('//')) {
      return ApiConfig.getProxiedImageUrl('https:$value');
    }

    if (value.startsWith('/')) {
      return ApiConfig.getProxiedImageUrl('https://jirig.be$value');
    }

    return ApiConfig.getProxiedImageUrl('https://jirig.be/$value');
  }

  Map<String, dynamic> _buildCountryDetails(
    String code, {
    String? nameOverride,
    String? flagOverride,
    String? priceOverride,
  }) {
    final normalized = code.toUpperCase();
    final existingIndex = _baseCountries.indexWhere(
      (c) => (c['code']?.toString().toUpperCase() ?? '') == normalized,
    );
    final existing = existingIndex >= 0 ? _baseCountries[existingIndex] : null;

    String name = nameOverride?.isNotEmpty == true
        ? nameOverride!
        : (existing?['name']?.toString() ?? normalized);

    String flag = flagOverride?.toString() ?? existing?['flag']?.toString() ?? '';
    flag = _normalizeFlagUrl(flag);

    // ✅ CORRECTION CRITIQUE: Toujours récupérer depuis articleNotifier.value en premier (le plus récent)
    // Priorité: 1) articleNotifier.value (le plus récent), 2) _currentArticle, 3) priceOverride, 4) existing
    String rawPrice = '';
    
    // ✅ D'abord, essayer de récupérer depuis articleNotifier.value (le plus récent)
    // Cela garantit qu'on récupère toujours le prix le plus à jour
    Map<String, dynamic>? originalArticle;
    try {
      originalArticle = widget.articleNotifier.value;
      print('✅ Article original récupéré depuis articleNotifier.value');
    } catch (e) {
      print('⚠️ Impossible de récupérer l\'article original: $e');
      // Fallback sur _currentArticle
      originalArticle = _currentArticle;
    }
    
    // ✅ Debug: Vérifier toutes les clés possibles
    print('🔍 _buildCountryDetails pour $code (normalized: $normalized) - Recherche du prix...');
    
    // ✅ CORRECTION: Afficher TOUTES les clés de pays disponibles AVANT de chercher
    if (originalArticle != null) {
      final allCountryKeys = originalArticle.keys.where((k) => 
        k.length == 2 && 
        k.toUpperCase() == k && 
        RegExp(r'^[A-Z]{2}$').hasMatch(k)
      ).toList();
      print('   📋 TOUTES les clés de pays dans article original: $allCountryKeys');
      for (final key in allCountryKeys) {
        print('      💰 $key: ${originalArticle[key]} (type: ${originalArticle[key].runtimeType})');
      }
    }
    
    // ✅ Debug: Afficher aussi les clés dans _currentArticle
    final allCurrentKeys = _currentArticle.keys.where((k) => 
      k.length == 2 && 
      k.toUpperCase() == k && 
      RegExp(r'^[A-Z]{2}$').hasMatch(k)
    ).toList();
    print('   📋 TOUTES les clés de pays dans _currentArticle: $allCurrentKeys');
    for (final key in allCurrentKeys) {
      print('      💰 $key: ${_currentArticle[key]} (type: ${_currentArticle[key].runtimeType})');
    }
    
    // ✅ Le backend stocke les prix avec des codes ISO directement (FR, DE, NL, PT, etc.)
    // Comme SNAL: item[countryCode] où countryCode est le code ISO
    bool keyExistsInOriginal = false;
    if (originalArticle != null) {
      // ✅ Essayer d'abord avec normalized (code ISO en majuscules) - comme SNAL
      if (originalArticle.containsKey(normalized)) {
        keyExistsInOriginal = true;
        final priceValue = originalArticle[normalized];
        rawPrice = priceValue?.toString() ?? '';
        print('   ✅ Prix trouvé dans article original avec normalized ($normalized): valeur="$priceValue", rawPrice="$rawPrice"');
      }
      // ✅ Si pas trouvé, essayer avec le code original
      else if (originalArticle.containsKey(code)) {
        keyExistsInOriginal = true;
        final priceValue = originalArticle[code];
        rawPrice = priceValue?.toString() ?? '';
        print('   ✅ Prix trouvé dans article original avec code ($code): valeur="$priceValue", rawPrice="$rawPrice"');
      }
      // ✅ Dernier essai avec lowercase
      else if (originalArticle.containsKey(code.toLowerCase())) {
        keyExistsInOriginal = true;
        final priceValue = originalArticle[code.toLowerCase()];
        rawPrice = priceValue?.toString() ?? '';
        print('   ✅ Prix trouvé dans article original avec lowercase (${code.toLowerCase()}): valeur="$priceValue", rawPrice="$rawPrice"');
      } else {
        // ✅ Debug: Afficher toutes les clés de pays disponibles dans l'article
        final countryKeys = originalArticle.keys.where((k) => 
          k.length == 2 && 
          k.toUpperCase() == k && 
          RegExp(r'^[A-Z]{2}$').hasMatch(k)
        ).toList();
        print('   ❌ Prix NON trouvé pour $code (essayé: $normalized, $code, ${code.toLowerCase()})');
        print('   📋 Clés de pays disponibles dans l\'article original: $countryKeys');
        if (countryKeys.isNotEmpty) {
          print('   ⚠️ Le prix pour $code n\'existe PAS dans l\'article original');
          // ✅ CORRECTION: Si le prix n'est pas dans originalArticle, vérifier _currentArticle immédiatement
          // au lieu d'attendre la section suivante
          if (_currentArticle.containsKey(normalized)) {
            final priceValue = _currentArticle[normalized];
            rawPrice = priceValue?.toString() ?? '';
            keyExistsInOriginal = true; // On marque comme trouvé même si c'est dans _currentArticle
            print('   ✅ Prix trouvé dans _currentArticle avec normalized ($normalized): valeur="$priceValue", rawPrice="$rawPrice"');
          } else if (_currentArticle.containsKey(code)) {
            final priceValue = _currentArticle[code];
            rawPrice = priceValue?.toString() ?? '';
            keyExistsInOriginal = true;
            print('   ✅ Prix trouvé dans _currentArticle avec code ($code): valeur="$priceValue", rawPrice="$rawPrice"');
          }
        }
      }
    }
    
    // ✅ Si pas trouvé dans l'article original, essayer _currentArticle
    bool keyExistsInCurrent = false;
    if (rawPrice.trim().isEmpty) {
      // ✅ Essayer d'abord avec normalized (code ISO en majuscules)
      if (_currentArticle.containsKey(normalized)) {
        keyExistsInCurrent = true;
        final priceValue = _currentArticle[normalized];
        rawPrice = priceValue?.toString() ?? '';
        print('   ✅ Prix trouvé dans _currentArticle avec normalized ($normalized): valeur="$priceValue", rawPrice="$rawPrice"');
      }
      // ✅ Si pas trouvé, essayer avec le code original
      else if (_currentArticle.containsKey(code)) {
        keyExistsInCurrent = true;
        final priceValue = _currentArticle[code];
        rawPrice = priceValue?.toString() ?? '';
        print('   ✅ Prix trouvé dans _currentArticle avec code ($code): valeur="$priceValue", rawPrice="$rawPrice"');
      }
      // ✅ Dernier essai avec lowercase
      else if (_currentArticle.containsKey(code.toLowerCase())) {
        keyExistsInCurrent = true;
        final priceValue = _currentArticle[code.toLowerCase()];
        rawPrice = priceValue?.toString() ?? '';
        print('   ✅ Prix trouvé dans _currentArticle avec lowercase (${code.toLowerCase()}): valeur="$priceValue", rawPrice="$rawPrice"');
      } else {
        // ✅ Debug: Afficher toutes les clés de pays disponibles dans l'article
        final countryKeys = _currentArticle.keys.where((k) => 
          k.length == 2 && 
          k.toUpperCase() == k && 
          RegExp(r'^[A-Z]{2}$').hasMatch(k)
        ).toList();
        print('   ⚠️ Prix non trouvé pour $code dans _currentArticle');
        print('   📋 Clés de pays disponibles dans _currentArticle: $countryKeys');
      }
    }
    
    // ✅ Si pas trouvé dans l'article, utiliser priceOverride
    if (rawPrice.trim().isEmpty) {
      rawPrice = priceOverride?.toString() ?? '';
      if (rawPrice.isNotEmpty) {
        print('   ✅ Prix trouvé dans priceOverride: "$rawPrice"');
      }
    }
    
    // ✅ Si toujours vide, utiliser existing
    if (rawPrice.trim().isEmpty) {
      rawPrice = existing?['price']?.toString() ?? '';
      if (rawPrice.isNotEmpty) {
        print('   ✅ Prix trouvé dans existing: "$rawPrice"');
      }
    }

    // ✅ Important: Vérifier si la clé du prix existe dans l'article (même si la valeur est null)
    // Si la clé existe mais la valeur est null/vide, c'est indisponible
    // Si la clé n'existe pas du tout, c'est aussi indisponible
    final priceExistsInArticle = keyExistsInOriginal || keyExistsInCurrent;
    
    final hasPrice = rawPrice.isNotEmpty && 
                     rawPrice.toLowerCase() != 'n/a' &&
                     rawPrice.toLowerCase() != 'indisponible' &&
                     rawPrice.toLowerCase() != 'unavailable';
    
    final priceValue = _parsePrice(rawPrice);
    
    print('🔍 _buildCountryDetails pour $code: rawPrice="$rawPrice", hasPrice=$hasPrice, priceValue=$priceValue, priceExistsInArticle=$priceExistsInArticle');

    String displayPrice = '';
    // ✅ Logique comme SNAL: si rawPrice existe (même s'il est null/vide), essayer de le formater
    // Si le prix existe dans l'article mais est null/vide, on affiche quand même quelque chose
    if (priceExistsInArticle) {
      if (hasPrice) {
        // Prix valide trouvé
        if (rawPrice.trim().isEmpty || rawPrice.toLowerCase() == 'n/a') {
          displayPrice = priceValue > 0 ? '${priceValue.toStringAsFixed(2)} €' : '';
        } else if (rawPrice.contains('€')) {
          displayPrice = rawPrice;
        } else {
          displayPrice = rawPrice.endsWith('€') ? rawPrice : '$rawPrice €';
        }
      } else if (rawPrice.toLowerCase() == 'floute') {
        // ✅ Gérer le cas "Floute" comme dans SNAL
        displayPrice = 'Floute';
      } else if (rawPrice.trim().isEmpty && priceExistsInArticle) {
        // ✅ Si le prix existe dans l'article mais est vide/null, c'est indisponible
        // On laisse displayPrice vide pour afficher "indisponible" dans l'UI
        displayPrice = '';
      }
    } else {
      // ✅ Si le prix n'existe pas du tout dans l'article, displayPrice reste vide
      displayPrice = '';
    }

    // ✅ isAvailable: true si le prix existe ET est valide (comme SNAL)
    // Si le prix existe dans l'article mais est null/vide/indisponible, isAvailable = false
    final isAvailable = hasPrice || rawPrice.toLowerCase() == 'floute';
    
    final updated = <String, dynamic>{
      'code': normalized,
      'name': name,
      'flag': flag,
      'price': displayPrice,
      'isAvailable': isAvailable,
    };

    if (existingIndex >= 0) {
      _baseCountries[existingIndex] = {
        ..._baseCountries[existingIndex],
        ...updated,
      };
    } else {
      _baseCountries.add(Map<String, dynamic>.from(updated));
    }

    return Map<String, dynamic>.from(updated);
  }

  @override
  void dispose() {
    // ✅ Marquer comme disposé AVANT de retirer le listener
    _isDisposed = true;
    
    // Retirer le listener de manière sécurisée
    // Vérifier d'abord si le ValueNotifier est encore valide
    try {
      // Tester si le ValueNotifier est encore accessible
      final _ = widget.articleNotifier.value;
      widget.articleNotifier.removeListener(_onArticleNotifierChanged);
    } catch (e) {
      // Le ValueNotifier a été disposé, ignorer l'erreur
      print('⚠️ ValueNotifier déjà disposé, impossible de retirer le listener: $e');
    }
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _openManagementDialog() async {
    try {
      // Le modal se ferme immédiatement et la sauvegarde se fait en arrière-plan
      await widget.onManageCountries();
      
      // Attendre que la sauvegarde soit terminée (la sauvegarde prend du temps)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ✅ CORRECTION CRITIQUE: Forcer la reconstruction complète après CountryManagementModal
      // Attendre un peu plus longtemps pour que le notifier soit complètement mis à jour
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!_isDisposed && mounted) {
        try {
          print('🔄 ========== RECONSTRUCTION APRÈS CountryManagementModal ==========');
          
          // ✅ Étape 1: Essayer de récupérer depuis articleNotifier.value
          Map<String, dynamic> latestArticle;
          try {
            latestArticle = widget.articleNotifier.value;
            print('✅ Article récupéré depuis articleNotifier.value');
          } catch (e) {
            print('⚠️ Notifier disposé, utilisation de _currentArticle...');
            // ✅ CORRECTION CRITIQUE: Si le notifier est disposé, utiliser _currentArticle
            // qui devrait contenir les prix les plus récents depuis l'initialisation
            latestArticle = Map<String, dynamic>.from(_currentArticle);
            print('✅ Article récupéré depuis _currentArticle (notifier disposé)');
            
            // ✅ Debug: Afficher les prix disponibles dans _currentArticle
            final allCountryKeys = latestArticle.keys.where((k) => 
              k.length == 2 && 
              k.toUpperCase() == k && 
              RegExp(r'^[A-Z]{2}$').hasMatch(k)
            ).toList();
            print('   📦 Clés de pays dans _currentArticle: $allCountryKeys');
            for (final key in allCountryKeys) {
              print('      💰 $key: ${latestArticle[key]}');
            }
            
            // ✅ Si _currentArticle ne contient pas tous les prix, ils seront récupérés
            // lors de la reconstruction de la liste via _buildCountryDetails()
            // qui cherchera dans articleNotifier.value (qui peut être disposé) puis _currentArticle
          }
          
          // ✅ Mettre à jour _currentArticle avec les prix les plus récents
          _currentArticle = Map<String, dynamic>.from(latestArticle);
          print('✅ _currentArticle mis à jour');
          
          // ✅ Debug: Afficher TOUS les prix disponibles
          final allCountryKeys = _currentArticle.keys.where((k) => 
            k.length == 2 && 
            k.toUpperCase() == k && 
            RegExp(r'^[A-Z]{2}$').hasMatch(k)
          ).toList();
          print('📦 TOUS les prix dans _currentArticle:');
          for (final key in allCountryKeys) {
            print('   💰 $key: ${_currentArticle[key]}');
          }
          
          // ✅ Étape 2: Réinitialiser les pays disponibles
          print('🔄 Réinitialisation des pays disponibles...');
          await _initializeAvailableCountries(useSetState: true);
          
          // ✅ Étape 3: Forcer la reconstruction via _onArticleNotifierChanged
          print('🔄 Déclenchement de _onArticleNotifierChanged...');
          _onArticleNotifierChanged();
          
          // ✅ Étape 4: Attendre un peu et forcer une deuxième reconstruction pour être sûr
          await Future.delayed(const Duration(milliseconds: 300));
          if (!_isDisposed && mounted) {
            try {
              // Mettre à jour _currentArticle une dernière fois
              final finalArticle = widget.articleNotifier.value;
              _currentArticle = Map<String, dynamic>.from(finalArticle);
              print('✅ _currentArticle mis à jour une dernière fois');
              
              // Reconstruire la liste
              await _initializeAvailableCountries(useSetState: true);
              _onArticleNotifierChanged();
              print('✅ Reconstruction finale terminée');
            } catch (e) {
              print('⚠️ Erreur lors de la reconstruction finale: $e');
            }
          }
        } catch (e) {
          print('⚠️ Erreur lors de la reconstruction après CountryManagementModal: $e');
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des pays: $e');
    }
  }

  Future<void> _handleCountryChange(String countryCode, {bool closeModal = false}) async {
    if (_isChanging) {
      return; // Un changement est déjà en cours
    }

    // ✅ Vérifier si c'est le même pays (comme SNAL isSame)
    // Si oui, désélectionner (passer -1), sinon sélectionner
    final isSame = _selectedCountry.toUpperCase() == countryCode.toUpperCase();
    final countryToSelect = isSame ? '-1' : countryCode; // ✅ Passer -1 pour désélectionner (comme SNAL)
    
    print('🔄 ${isSame ? "Désélection" : "Sélection"} du pays: $countryCode');

    // Vérifier si le pays a un prix disponible (seulement si on sélectionne)
    if (!isSame) {
      final country = _availableCountries.firstWhere(
        (c) => c['code'] == countryCode,
        orElse: () => {},
      );
      final isAvailable = country['isAvailable'] ?? false;
      if (!isAvailable) {
        print('ℹ️ Pays $countryCode sélectionné sans prix disponible – tentative de mise à jour.');
      }
    }

    setState(() {
      _isChanging = true;
      // ✅ Mettre à jour _selectedCountry : vide si désélection, sinon le code du pays
      _selectedCountry = isSame ? '' : countryCode;
    });

    final changeFuture = widget.onCountrySelected(countryToSelect);

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
    // ✅ Vérifier si un pays est sélectionné (comme SNAL isCountrySelected)
    final rawSpaysSelected = _currentArticle['spaysSelected'] ?? _currentArticle['sPaysSelected'];
    final bool isCountrySelected = rawSpaysSelected != null && 
                                   rawSpaysSelected != '' && 
                                   rawSpaysSelected != false &&
                                   rawSpaysSelected != '-1' &&
                                   rawSpaysSelected.toString().trim().isNotEmpty;
    
    // ✅ Ne rien afficher si aucun pays n'est sélectionné
    if (!isCountrySelected) {
      return const SizedBox.shrink();
    }
    
    final selectedCountryCode = rawSpaysSelected.toString().trim().toUpperCase();
    final homeCountryCode = _resolveHomeCountryCode();
    
    // Trouver les données du pays sélectionné
    final selectedCountryData = _availableCountries.firstWhere(
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
    final translationService = Provider.of<TranslationService>(context, listen: true);
    final priceByCountryLabel = translationService.translate('PRICE_BY_COUNTRY');
    final manageCountriesLabel = translationService.translate('ADD_REMOVE_COUNTRY');
    final closeLabel = translationService.translate('FRONTPAGE_Msg101');
    final emptyStateLabel = translationService.translate('WISHLIST_COUNTRY_EMPTY');
    final unavailableLabel = translationService.translate('WISHLIST_Msg23');
    final bestPriceLabel = translationService.translate('WISHLIST_Msg24');
    const neutralBorder = Color(0xFFE5E7EB);
    const selectedBackground = Color(0xFFE6F9EF);
    const selectedBorder = Color(0xFF34D399);
    const buttonBlueColor = Color(0xFF60A5FA); // ✅ Couleur unique pour texte et bordure

    // Utilisation sécurisée de MediaQuery pour éviter les erreurs
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    final screenHeight = MediaQuery.maybeOf(context)?.size.height ?? 768;
    final isVerySmallMobile = screenWidth < 361;
    final isSmallMobile = screenWidth < 431;
    final isMobile = screenWidth < 768;
    final isWeb = screenWidth >= 768;
    final modalWidth = isWeb ? screenWidth * 0.75 : screenWidth;

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
                    // Titre "Prix par pays"
                    Text(
                      priceByCountryLabel,
                      style: TextStyle(
                        fontSize: isVerySmallMobile ? 18 : (isSmallMobile ? 20 : 22),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
                    
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
            
                      Expanded(
              child: _availableCountries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            emptyStateLabel,
                            style: const TextStyle(
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
                      for (final c in _availableCountries) {
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
                      itemCount: _availableCountries.length,
                          itemBuilder: (context, index) {
                  final country = _availableCountries[index];
                            final code = country['code']?.toString() ?? '';
                            final name = country['name']?.toString() ?? '';
                            final flag = country['flag']?.toString() ?? '';
                  final price = country['price']?.toString() ?? 'N/A';
                  final isAvailable = country['isAvailable'] ?? false;
                  // ✅ Vérifier si le pays est sélectionné (comme SNAL isSelected)
                  final isSelected = _selectedCountry.isNotEmpty && code.toUpperCase() == _selectedCountry.toUpperCase();
                  final isBest = code == bestCountryCode;
                  final normalizedCode = code.toUpperCase();
                  final isHomeCountry = homeCountryCode.isNotEmpty && normalizedCode == homeCountryCode;
                  final containerColor = isSelected
                      ? selectedBackground
                      : Colors.white;
                  final borderColor = isSelected ? selectedBorder : neutralBorder;
                  final borderWidth = isSelected ? 1.8 : 1.0;
                            
                            // ✨ Animation : Chaque pays apparaît en vague
                            final bool isTouchPlatform = defaultTargetPlatform == TargetPlatform.iOS ||
                                defaultTargetPlatform == TargetPlatform.android;

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
                      onTap: _isChanging
                          ? null
                          : () => _handleCountryChange(
                                code,
                                closeModal: isTouchPlatform,
                              ),
                      onDoubleTap: _isChanging
                          ? null
                          : () => _handleCountryChange(code, closeModal: true),
                      child: Opacity(
                        opacity: (_isChanging && !isSelected) ? 0.5 : 1.0,
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
                            // Style: system-ui, normal, weight 400, size 16px, line height 24px, color black
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                          children: [
                                    Text(
                                              name,
                                              style: TextStyle(
                                                // fontFamily non spécifié = utilise la police système (équivalent à system-ui)
                                                fontStyle: FontStyle.normal, // Style: normal
                                                fontSize: 16.0, // Size: 16px
                                                fontWeight: FontWeight.w400, // Weight: 400 (normal)
                                                color: const Color.fromRGBO(0, 0, 0, 1.0), // Color: rgb(0, 0, 0) - noir
                                                height: 24.0 / 16.0, // Line Height: 24px / 16px = 1.5
                                                letterSpacing: 0.0, // Pas de letterSpacing
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
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isBest && isAvailable) ...[
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
                                                    bestPriceLabel,
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
                                            isAvailable ? price : unavailableLabel,
                                            style: TextStyle(
                                              fontSize: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                                              fontWeight: FontWeight.w700,
                                              color: isAvailable
                                                  ? (isSelected ? const Color(0xFF10B981) : const Color(0xFF374151))
                                                  : const Color(0xFF6B7280),
                                              fontStyle: isAvailable ? FontStyle.normal : FontStyle.italic,
                                            ),
                                          ),
                                          ],
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
                    // Bouton Ajouter/Supprimer un pays (pill-shaped, blanc avec bordure bleue)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _openManagementDialog();
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: buttonBlueColor, // ✅ Même couleur que la bordure
                          padding: EdgeInsets.symmetric(
                            vertical: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                            horizontal: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // Pill-shaped
                            side: BorderSide(color: buttonBlueColor, width: 1.5), // ✅ Bordure avec même couleur que le texte
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icône drapeau avec plus
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.flag,
                                  size: isVerySmallMobile ? 18 : (isSmallMobile ? 20 : 22),
                                  color: buttonBlueColor, // ✅ Même couleur
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: isVerySmallMobile ? 10 : 12,
                                    height: isVerySmallMobile ? 10 : 12,
                                    decoration: BoxDecoration(
                                      color: buttonBlueColor, // ✅ Même couleur
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                            Text(
                              manageCountriesLabel,
                              style: TextStyle(
                                fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                                fontWeight: FontWeight.w600,
                                color: buttonBlueColor, // ✅ Même couleur que la bordure
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isVerySmallMobile ? 10 : (isSmallMobile ? 12 : 16)),

                    // Bouton Fermer (bleu solide, rectangulaire)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonBlueColor, // ✅ Même couleur
                          foregroundColor: Colors.white, // Texte blanc
                          padding: EdgeInsets.symmetric(
                            vertical: isVerySmallMobile ? 18 : (isSmallMobile ? 20 : 22), // Hauteur augmentée
                            horizontal: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8), // Coins arrondis modérés
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          closeLabel,
                          style: TextStyle(
                            fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                            fontWeight: FontWeight.w600,
                            color: Colors.white, // Texte blanc
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

class _ManagementSidebarView extends StatelessWidget {
  final _CountryManagementData? data;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final VoidCallback onClose;
  final Future<List<Map<String, dynamic>>?> Function(List<String>) onSave;
  final String manageLabel;

  const _ManagementSidebarView({
    required this.data,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onClose,
    required this.onSave,
    required this.manageLabel,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Réessayer'),
              ),
          ],
        ),
      );
    }

    if (data == null) {
      return const Center(
        child: Text('Aucune donnée disponible.'),
      );
    }

    return _EmbeddedCountryManagementPanel(
      data: data!,
      onClose: onClose,
      onSave: onSave,
      title: manageLabel,
    );
  }
}

class _EmbeddedCountryManagementPanel extends StatefulWidget {
  final _CountryManagementData data;
  final Future<List<Map<String, dynamic>>?> Function(List<String>) onSave;
  final VoidCallback onClose;
  final String title;

  const _EmbeddedCountryManagementPanel({
    Key? key,
    required this.data,
    required this.onSave,
    required this.onClose,
    required this.title,
  }) : super(key: key);

  @override
  State<_EmbeddedCountryManagementPanel> createState() => _EmbeddedCountryManagementPanelState();
}

class _EmbeddedCountryManagementPanelState extends State<_EmbeddedCountryManagementPanel> {
  late List<String> _selectedCountries;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    final locked = widget.data.lockedCountryCode?.toUpperCase();
    _selectedCountries = widget.data.selectedCountries.map((c) => c.toUpperCase()).toSet().toList();
    if (locked != null && locked.isNotEmpty && !_selectedCountries.contains(locked)) {
      _selectedCountries.add(locked);
    }
  }

  void _toggleCountry(String code) {
    final normalized = code.toUpperCase();
    final locked = widget.data.lockedCountryCode?.toUpperCase();
    if (locked != null && locked == normalized) {
      return;
    }

    setState(() {
      if (_selectedCountries.contains(normalized)) {
        _selectedCountries.remove(normalized);
      } else {
        _selectedCountries.add(normalized);
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_selectedCountries);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(context, listen: true);
    final availableCountriesLabel = translationService.translate('WISHLIST_Msg29');
    final availableCountriesHint = translationService.translate('WISHLIST_COUNTRY_MODAL_HELP');
    final cancelLabel = translationService.translate('WISHLIST_Msg30');
    final saveLabel = translationService.translate('WISHLIST_Msg31');

    final mediaQuery = MediaQuery.maybeOf(context);
    final screenWidth = mediaQuery?.size.width ?? 360;
    final isSmall = screenWidth < 480;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onClose,
            ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48), // équilibre de l'icon button
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(isSmall ? 12 : 16, 0, isSmall ? 12 : 16, isSmall ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            availableCountriesLabel,
                            style: const TextStyle(
                              fontSize: 16,
                  fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            availableCountriesHint,
                            style: TextStyle(
                  fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.data.availableCountries.map((country) {
                final code = country['code']?.toString().toUpperCase() ?? '';
                final name = country['name']?.toString() ?? code;
                final isSelected = _selectedCountries.contains(code);
                final isLocked = widget.data.lockedCountryCode?.toUpperCase() == code;

                return GestureDetector(
                  onTap: () => _toggleCountry(code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE0F2FE) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isLocked
                                      ? const Color(0xFF0284C7)
                            : (isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFD1D5DB)),
                        width: isLocked ? 2 : 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                            fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isLocked
                                          ? const Color(0xFF0284C7)
                                : (isSelected ? const Color(0xFF0369A1) : const Color(0xFF4B5563)),
                                    ),
                                  ),
                                  if (isLocked) ...[
                                    const SizedBox(width: 6),
                          const Icon(Icons.lock, size: 16, color: Color(0xFF0284C7)),
                        ],
                                ],
                              ),
                            ),
                );
                      }).toList(),
                    ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(isSmall ? 12 : 16, 12, isSmall ? 12 : 16, isSmall ? 16 : 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : widget.onClose,
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(saveLabel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Modal de gestion des pays (comme SNAL)
class _CountryManagementModal extends StatefulWidget {
  final List<Map<String, dynamic>> availableCountries;
  final List<String> selectedCountries;
  final Future<List<Map<String, dynamic>>?> Function(List<String>) onSave;
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

class _CountryManagementModalState extends State<_CountryManagementModal> {
  late List<String> _selectedCountries;
  late final String? _lockedCountryCode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lockedCountryCode = widget.lockedCountryCode?.toUpperCase();
    _selectedCountries = widget.selectedCountries
        .map((code) => code.toUpperCase())
        .toSet()
        .toList();
    if (_lockedCountryCode != null &&
        _lockedCountryCode!.isNotEmpty &&
        !_selectedCountries.contains(_lockedCountryCode)) {
      _selectedCountries.add(_lockedCountryCode!);
    }
  }

  void _toggleCountry(String code) {
    final normalized = code.toUpperCase();
    // Ne pas permettre la désélection du pays verrouillé
    if (_lockedCountryCode != null && normalized == _lockedCountryCode) {
      print('🔒 Pays verrouillé, impossible de modifier: $normalized');
      return;
    }

    print('🔄 Toggle pays: $normalized');
    print('📋 Pays sélectionnés avant: $_selectedCountries');
    
    setState(() {
      // Créer une nouvelle liste pour forcer la mise à jour
      final newSelected = List<String>.from(_selectedCountries);
      final wasSelected = newSelected.contains(normalized);
      
      if (wasSelected) {
        newSelected.remove(normalized);
        print('➖ Pays désélectionné: $normalized');
      } else {
        newSelected.add(normalized);
        print('➕ Pays sélectionné: $normalized');
      }
      
      _selectedCountries = newSelected;
      print('📋 Pays sélectionnés après: $_selectedCountries');
    });
  }

  String _countryName(String code) {
    final upper = code.toUpperCase();
    final matches = widget.availableCountries.where(
      (country) => (country['code']?.toString().toUpperCase() ?? '') == upper,
    );
    if (matches.isNotEmpty) {
      return matches.first['name']?.toString() ?? upper;
    }
    return upper;
  }

  String? _countryFlag(String code) {
    final upper = code.toUpperCase();
    final matches = widget.availableCountries.where(
      (country) => (country['code']?.toString().toUpperCase() ?? '') == upper,
    );
    if (matches.isNotEmpty) {
      final flag = matches.first['flag']?.toString();
      if (flag == null || flag.isEmpty) return null;
      return flag;
    }
    return null;
  }

  List<Map<String, dynamic>> _filteredCountries() {
    // Filtrer les pays disponibles en excluant AT et CH
    return widget.availableCountries.where((country) {
      final code = country['code']?.toString().toUpperCase() ?? '';
      return code.isNotEmpty && code != 'AT' && code != 'CH';
    }).toList();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final result = await widget.onSave(_selectedCountries);
      if (mounted) {
        // ✅ CORRECTION: Fermer seulement le CountryManagementModal
        // Le CountrySidebarModal parent restera ouvert
        Navigator.of(context).pop(result);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(context, listen: true);
    final titleText = translationService.translate('WISHLIST_Msg28');
    final availableCountriesLabel = translationService.translate('WISHLIST_Msg29');
    final helperText = translationService.translate('WISHLIST_COUNTRY_MODAL_HELP');
    final cancelLabel = translationService.translate('WISHLIST_Msg30');
    final saveLabel = translationService.translate('WISHLIST_Msg31');

    final media = MediaQuery.of(context);
    final size = media.size;
    final isMobile = size.width < 768; // ✅ Utiliser 768 comme seuil pour mobile (cohérent avec le reste de l'app)
    final isVerySmallMobile = size.width < 361;
    final isSmallMobile = size.width < 431;
    final isCompact = isMobile; // ✅ Alias pour compatibilité
    final horizontalPadding = isMobile 
        ? (isVerySmallMobile ? 16.0 : (isSmallMobile ? 18.0 : 20.0))
        : 32.0;
    final filteredCountries = _filteredCountries();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isMobile 
              ? (isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12))
              : 24,
          vertical: isMobile 
              ? (isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12))
              : 24,
        ),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 24),
              decoration: BoxDecoration(
                color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 32,
              offset: const Offset(0, 8), // ✅ Ajuster l'offset pour un modal centré
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // ✅ Permettre au modal de s'adapter à son contenu
          children: [
            Text(
              titleText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCompact ? 20 : 23,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              availableCountriesLabel,
              style: TextStyle(
                fontSize: isCompact ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView( // ✅ Ajouter le scroll pour permettre de voir tous les pays
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: filteredCountries.map((country) {
                    final code =
                        country['code']?.toString().toUpperCase() ?? '';
                    final name = country['name']?.toString() ?? code;
                    final flag = country['flag']?.toString();
                    final isLocked = _lockedCountryCode != null &&
                        code == _lockedCountryCode;
                    final isSelected = _selectedCountries.contains(code);

                    // Couleur de fond : bleu clair pour sélectionné, gris clair pour non sélectionné
                    final backgroundColor = isLocked
                        ? const Color(0xFFF0F9FF) // Bleu très clair pour le pays verrouillé
                        : isSelected
                            ? const Color(0xFFE0F2FE) // Bleu clair pour sélectionné
                            : const Color(0xFFF3F4F6); // Gris clair pour non sélectionné

                    // Couleur du texte : grisé pour le pays verrouillé, bleu pour sélectionné, gris pour non sélectionné
                    final textColor = isLocked
                        ? const Color(0xFF9CA3AF) // Gris pour le pays verrouillé
                        : isSelected
                            ? const Color(0xFF2563EB) // Bleu pour sélectionné
                            : const Color(0xFF6B7280); // Gris pour non sélectionné

                    return GestureDetector(
                      onTap: isLocked ? null : () {
                        print('👆 Tap détecté sur pays: $code');
                        _toggleCountry(code);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (flag != null && flag.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Image.network(
                                  flag,
                                  width: 20,
                                  height: 14,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: isCompact ? 14 : 15,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                  Expanded(
                    child: ElevatedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                        foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        cancelLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                        saveLabel,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Pas de ressources à libérer dans ce widget
    super.dispose();
  }
}

/// Widget pour le point indicateur qui clignote (comme SNAL animate-pulse)
class _PulsingIndicatorDot extends StatefulWidget {
  final Color color;

  const _PulsingIndicatorDot({
    Key? key,
    required this.color,
  }) : super(key: key);

  @override
  State<_PulsingIndicatorDot> createState() => _PulsingIndicatorDotState();
}

class _PulsingIndicatorDotState extends State<_PulsingIndicatorDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Contrôleur d'animation pour le clignotement
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // Durée du cycle de clignotement
      vsync: this,
    );

    // Animation d'opacité pour l'effet de clignotement (de 0.3 à 1.0)
    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Démarrer l'animation en boucle
    _controller.repeat(reverse: true);
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
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        );
      },
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

  @override
  void initState() {
    super.initState();
    
    // Contrôleur d'animation pour le pulse
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

    // Démarrer l'animation en boucle après un léger délai
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
        final scaleValue = _scaleAnimation.value;
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

/// Widget pour un item de basket avec swipe pour révéler le bouton delete (pour les PDF)
class _BasketListItemWithSwipe extends StatelessWidget {
  final Map<String, dynamic> basket;
  final int index;
  final bool isPdf;
  final bool isSelected;
  final bool isMobile;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _BasketListItemWithSwipe({
    Key? key,
    required this.basket,
    required this.index,
    required this.isPdf,
    required this.isSelected,
    required this.isMobile,
    required this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final label = basket['label']?.toString() ?? 'Wishlist';
    
    // Le PopupMenuItem gère le clic automatiquement via onSelected.
    // On retourne juste le contenu visuel.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Texte du label
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                color: const Color(0xFF212529),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),

          // Icône de suppression si c'est un PDF et qu'une action de suppression est fournie
          if (isPdf && onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              onPressed: () {
                // La fonction onDelete fournie par le parent se charge déjà
                // de fermer le menu et de lancer la suppression.
                onDelete?.call();
              },
              // Style pour que le bouton ne prenne pas trop de place
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Supprimer le projet',
            ),
          ]
        ],
      ),
    );
  }
}








