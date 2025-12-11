import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/local_storage_service.dart';
import '../services/route_tracker.dart';
import '../config/api_config.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/search_modal.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:math' as math;
import 'dart:async';

class PodiumScreen extends StatefulWidget {
  final String productCode;
  final String? productCodeCrypt;
  
  const PodiumScreen({
    super.key,
    required this.productCode,
    this.productCodeCrypt,
  });

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen> 
    with RouteTracker, TickerProviderStateMixin {
  Map<String, dynamic>? _productData;
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentQuantity = 1;
  int _currentImageIndex = 0;
  String? _userCountryCode; // Code du pays de l'utilisateur
  bool _hasInitiallyLoaded = false; // Suivre si les données ont été chargées initialement
  bool _isAuthError = false; // Indique si c'est une erreur d'authentification
  int _countdownSeconds = 3; // Compteur pour la redirection
  Timer? _countdownTimer; // Timer pour le compteur
  String? _loadingInLoader; // Valeur LOADING_IN_LOADER depuis le backend
  String? _currentIBasket; // iBasket de la wishlist sélectionnée (depuis l'URL ou le profil)
  
  // Controllers d'animation (style "Explosion & Reveal" - différent des autres pages)
  late AnimationController _productController;
  late AnimationController _podiumController;
  late AnimationController _otherCountriesController;
  
  late Animation<double> _productScaleAnimation;
  late Animation<double> _productRotationAnimation;
  late Animation<double> _productFadeAnimation;
  
  bool _animationsInitialized = false;
  
  ApiService get _apiService => Provider.of<ApiService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _initializeAnimationControllers();
    // Ne pas charger les données ici - attendre didChangeDependencies
  }
  
  /// Initialiser les controllers d'animation (style Explosion & Reveal)
  void _initializeAnimationControllers() {
    try {
      // Produit principal : Rotation 3D + Scale + Fade
      _productController = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      );
      
      _productScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
          parent: _productController,
          curve: Curves.elasticOut, // Super bounce
        ),
      );
      
      _productRotationAnimation = Tween<double>(begin: math.pi / 6, end: 0.0).animate(
        CurvedAnimation(
          parent: _productController,
          curve: Curves.easeOutBack,
        ),
      );
      
      _productFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _productController,
          curve: Curves.easeIn,
        ),
      );
      
      // Podium : Construction depuis le bas (comme si le podium se construit)
      _podiumController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      
      // Autres pays : Ripple effect
      _otherCountriesController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      _animationsInitialized = true;
      print('✅ Animations Podium initialisées (style Explosion & Reveal)');
    } catch (e) {
      print('❌ Erreur initialisation animations podium: $e');
    }
  }
  
  /// Démarrer les animations quand les données sont chargées
  void _startPodiumAnimations() async {
    if (!_animationsInitialized || !mounted) return;
    
    try {
      // Reset avant de commencer
      _productController.reset();
      _podiumController.reset();
      _otherCountriesController.reset();
      
      // Animation du produit principal (immédiate)
      _productController.forward();
      
      // Animation du podium (après 300ms)
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _podiumController.forward();
      
      // Animation des autres pays (après 600ms)
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _otherCountriesController.forward();
    } catch (e) {
      print('❌ Erreur démarrage animations: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ne recharger les données que si elles ne sont pas déjà chargées
    // pour éviter le rechargement lors du changement de langue
    if (!_hasInitiallyLoaded) {
      _hasInitiallyLoaded = true;
      _loadProductData();
    }
  }

  @override
  void didUpdateWidget(PodiumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si le code produit a changé, recharger les données
    if (oldWidget.productCode != widget.productCode || 
        oldWidget.productCodeCrypt != widget.productCodeCrypt) {
      print('🔄 Nouveau produit détecté : ${widget.productCode}');
      _hasInitiallyLoaded = false; // Réinitialiser le flag pour permettre le rechargement
      _loadProductData();
    }
  }
  
  @override
  void dispose() {
    try {
      _productController.dispose();
      _podiumController.dispose();
      _otherCountriesController.dispose();
      _countdownTimer?.cancel();
    } catch (e) {
      print('⚠️ Erreur dispose controllers podium: $e');
    }
    super.dispose();
  }
  
  /// Démarre le compteur de 3 secondes avant la redirection vers le login
  void _startCountdown() {
    // Annuler le timer précédent s'il existe
    _countdownTimer?.cancel();
    
    // Réinitialiser le compteur
    _countdownSeconds = 3;
    
    // Créer un nouveau timer qui se déclenche toutes les secondes
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _countdownSeconds--;
      });
      
      // Quand le compteur arrive à 0, rediriger vers le login
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _redirectToLogin();
      }
    });
  }
  
  /// Redirige vers la page de login
  void _redirectToLogin() {
    if (!mounted) return;
    
    // Sauvegarder l'URL actuelle pour y revenir après la connexion
    final currentPath = ModalRoute.of(context)?.settings.name ?? '/podium/${widget.productCode}';
    context.go('/login?callBackUrl=$currentPath&fromAuthError=true');
  }


  Future<void> _loadProductData() async {
    try {
      // ✅ Récupérer LOADING_IN_LOADER depuis le backend (pas de traduction locale)
      if (_loadingInLoader == null) {
        try {
          final infosStatus = await _apiService.getInfosStatus();
          // getInfosStatus retourne un tableau, chercher LOADING_IN_LOADER dans le premier élément
          if (infosStatus is List && infosStatus.isNotEmpty) {
            final firstItem = infosStatus[0] as Map<String, dynamic>?;
            _loadingInLoader = firstItem?['LOADING_IN_LOADER']?.toString();
          } else if (infosStatus is Map<String, dynamic>) {
            _loadingInLoader = infosStatus['LOADING_IN_LOADER']?.toString();
          }
          print('📦 LOADING_IN_LOADER récupéré depuis backend: $_loadingInLoader');
        } catch (e) {
          print('⚠️ Erreur lors de la récupération de LOADING_IN_LOADER: $e');
        }
      }
      
      // ✅ Récupérer la quantité et l'iBasket depuis l'URL (si venant de la wishlist)
      final uri = GoRouterState.of(context).uri;
      final iQuantiteFromUrl = uri.queryParameters['iQuantite'];
      final iBasketFromUrlRaw = uri.queryParameters['iBasket'];
      final initialQuantity = int.tryParse(iQuantiteFromUrl ?? '1') ?? 1;
      
      // ✅ Décoder l'iBasket s'il est encodé (car on utilise Uri.encodeComponent dans wishlist_screen)
      String? iBasketFromUrl;
      if (iBasketFromUrlRaw != null && iBasketFromUrlRaw.isNotEmpty) {
        try {
          iBasketFromUrl = Uri.decodeComponent(iBasketFromUrlRaw);
          print('🛒 iBasket récupéré depuis URL (brut): $iBasketFromUrlRaw');
          print('🛒 iBasket récupéré depuis URL (décodé): $iBasketFromUrl (longueur: ${iBasketFromUrl.length})');
        } catch (e) {
          // Si le décodage échoue, utiliser la valeur brute
          iBasketFromUrl = iBasketFromUrlRaw;
          print('⚠️ Erreur lors du décodage de l\'iBasket, utilisation de la valeur brute: $iBasketFromUrl');
        }
      }
      
      print('📦 Quantité récupérée depuis URL: $iQuantiteFromUrl → $initialQuantity');
      
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
          // ✅ Ne réinitialiser la quantité que si elle n'a pas été définie depuis l'URL
          if (_currentQuantity == 1 && initialQuantity != 1) {
            _currentQuantity = initialQuantity;
          }
          _currentImageIndex = 0; // Réinitialiser l'index d'image
        });
      }

      
      String? sTokenUrl;
      String? sPaysLangue;
      String? iBasket;
      
      try {
        // ✅ Récupérer le profil depuis LocalStorage (déjà initialisé dans app.dart)
        final profileData = await LocalStorageService.getProfile();
        sTokenUrl = profileData?['iProfile']?.toString();
        sPaysLangue = profileData?['sPaysLangue']?.toString();
        
        // ✅ PRIORITÉ: Utiliser l'iBasket de l'URL s'il est présent (wishlist sélectionnée)
        // Sinon, utiliser celui du profil
        if (iBasketFromUrl != null && iBasketFromUrl.isNotEmpty) {
          iBasket = iBasketFromUrl;
          print('✅ Utilisation de l\'iBasket depuis l\'URL (wishlist sélectionnée): $iBasket');
        } else {
          iBasket = profileData?['iBasket']?.toString();
          print('✅ Utilisation de l\'iBasket depuis le profil: $iBasket');
        }
        
        // ✅ Stocker l'iBasket dans la variable d'état pour l'utiliser dans _addToWishlist
        _currentIBasket = iBasket;
        
        print('🔑 Profil récupéré - iProfile: ${sTokenUrl != null ? "✅" : "❌"}');
        
        // Récupérer le pays de l'utilisateur
        final settingsService = SettingsService();
        final selectedCountry = await settingsService.getSelectedCountry();
        if (selectedCountry != null) {
          _userCountryCode = selectedCountry.sPays;
          // Utiliser sPaysLangue du profil ou du pays sélectionné
          sPaysLangue ??= selectedCountry.sPaysLangue ?? '${selectedCountry.sPays.toLowerCase()}/fr';
        }
      } catch (e) {
        print('⚠️ Erreur lors de la récupération du profil: $e');
      }

      String codeToUse = widget.productCode;
      if (widget.productCode.length > 50) {
        codeToUse = widget.productCode.replaceAll(RegExp(r'[^\d]'), '');
        if (codeToUse.length > 9) {
          codeToUse = codeToUse.substring(0, 9);
        }
      }
      
      print('🔍 Paramètres API:');
      print('  - sCodeArticle: $codeToUse');
      print('  - sCodeArticleCrypt: ${widget.productCodeCrypt}');
      print('  - iProfile: $sTokenUrl');
      print('  - iBasket: $iBasket');
      print('  - iQuantite: $_currentQuantity');
      
      final response = await _apiService.getComparaisonByCode(
        sCodeArticle: codeToUse,
        sCodeArticleCrypt: widget.productCodeCrypt,
        iProfile: sTokenUrl,
        iBasket: iBasket,
        iQuantite: _currentQuantity,
      );
      
      print('📡 Réponse API: $response');

      if (response != null) {
        if (response['error'] == true) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAuthError = false;
              _errorMessage = 'Erreur API: ${response['message'] ?? 'Erreur inconnue'}';
            });
          }
        } else if (response['Ui_Result'] == 'ARTICLE_NOT_FOUND') {
          // Afficher le message d'erreur normal pour la recherche par code
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAuthError = false;
              _errorMessage = 'ARTICLE_NOT_FOUND';
            });
          }
        } else if (response['Ui_Result'] == 'GIVE_EMAIL') {
          // Afficher le message d'erreur d'authentification avec compteur
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAuthError = true;
              _errorMessage = 'Erreur d\'authentification - Veuillez vous connecter ou vérifier votre profil';
              _countdownSeconds = 3;
            });
            // Démarrer le compteur de 3 secondes
            _startCountdown();
          }
        } else if (response['Ui_Result'] == 'GET_ABONNEMENT') {
          // Afficher le message d'erreur normal pour la recherche par code
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAuthError = false;
              _errorMessage = 'GET_ABONNEMENT';
            });
          }
        } else if (response['Articles'] == null || (response['Articles'] is List && (response['Articles'] as List).isEmpty)) {
          // Afficher le message d'erreur normal pour la recherche par code
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isAuthError = false;
              _errorMessage = 'Aucun article trouvé dans la réponse';
            });
          }
        } else {
          // Debug: Afficher un article pour voir les champs disponibles
          if (response['Articles'] != null && (response['Articles'] as List).isNotEmpty) {
            print('🏳️ DEBUG Article 0: ${response['Articles'][0]}');
            print('🏳️ sPaysDrapeau: ${response['Articles'][0]['sPaysDrapeau']}');
          }
          if (mounted) {
            setState(() {
              _productData = response;
              _isLoading = false;
            });
            // Démarrer les animations après chargement réussi
            _startPodiumAnimations();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Produit non trouvé - API response null';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors du chargement: $e';
        });
      }
    }
  }

  List<String> _collectImageUrls() {
    final urls = <String>[];

    // 1) aImageLink au niveau racine
    final root = _productData?['aImageLink'];
    if (root is List && root.isNotEmpty) {
      for (final it in root) {
        if (it is Map && (it['sHyperlink'] ?? '').toString().isNotEmpty) {
          final link = it['sHyperlink'].toString();
          if (!link.toLowerCase().contains('no_image')) {
            // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
            urls.add(ApiConfig.getProxiedImageUrl(link));
          }
        } else if (it is String && it.isNotEmpty) {
          if (!it.toLowerCase().contains('no_image')) {
            // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
            urls.add(ApiConfig.getProxiedImageUrl(it));
          }
        }
      }
    } else if (root is String && root.isNotEmpty) {
      // Peut être un XML <row><sHyperlink>...</sHyperlink></row>
      final m = RegExp(r'<sHyperlink>(.*?)<\/sHyperlink>', caseSensitive: false)
          .firstMatch(root);
      final link = m?.group(1) ?? '';
      if (link.isNotEmpty && !link.toLowerCase().contains('no_image')) {
        // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
        urls.add(ApiConfig.getProxiedImageUrl(link));
      }
    }

    // 2) aImageLink dans Articles[0]
    final articles = _productData?['Articles'];
    if (articles is List && articles.isNotEmpty) {
      final a0 = articles[0];
      final articleImages = (a0 is Map) ? a0['aImageLink'] : null;
      if (articleImages is List) {
        for (final it in articleImages) {
          if (it is Map && (it['sHyperlink'] ?? '').toString().isNotEmpty) {
            final link = it['sHyperlink'].toString();
            if (!link.toLowerCase().contains('no_image')) {
              // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
              urls.add(ApiConfig.getProxiedImageUrl(link));
            }
          } else if (it is String && it.isNotEmpty) {
            if (!it.toLowerCase().contains('no_image')) {
              // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
              urls.add(ApiConfig.getProxiedImageUrl(it));
            }
          }
        }
      } else if (articleImages is String && articleImages.isNotEmpty) {
        final m = RegExp(r'<sHyperlink>(.*?)<\/sHyperlink>', caseSensitive: false)
            .firstMatch(articleImages);
        final link = m?.group(1) ?? '';
        if (link.isNotEmpty && !link.toLowerCase().contains('no_image')) {
          // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
          urls.add(ApiConfig.getProxiedImageUrl(link));
        }
      }
    }

    return urls;
  }

  String _getCurrentImageUrl() {
    final urls = _collectImageUrls();
    if (urls.isEmpty) return '';
    final idx = (_currentImageIndex % urls.length).abs();
    return urls[idx];
  }

  void _nextImage() {
    final urls = _collectImageUrls();
    if (urls.isEmpty) return;
    
    // Animation désactivée pour Flutter Web
    if (mounted) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % urls.length;
      });
    }
  }

  void _prevImage() {
    final urls = _collectImageUrls();
    if (urls.isEmpty) return;
    
    // Animation désactivée pour Flutter Web
    if (mounted) {
      setState(() {
        _currentImageIndex = (_currentImageIndex - 1 + urls.length) % urls.length;
      });
    }
  }

  void _showSearchModal() {
    showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 280),
        reverseTransitionDuration: Duration(milliseconds: 220),
        barrierDismissible: true,
      ),
      builder: (context) {
        final media = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              elevation: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.9,
                  minHeight: media.size.height * 0.5,
                  maxWidth: 700,
                ),
                child: const SearchModal(),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Afficher l'image en plein écran
  void _showFullscreenImage() {
    final urls = _collectImageUrls();
    if (urls.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                // Zone de clic pour fermer (couvre tout l'écran)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                
                // Image centrée avec zoom et scroll
                Center(
                  child: Builder(
                    builder: (context) {
                      final media = MediaQuery.of(context);
                      final TransformationController _tc = TransformationController();
                      return ClipRect(
                        child: SizedBox(
                          width: media.size.width * 0.95,
                          height: media.size.height * 0.85,
                          child: InteractiveViewer(
                            constrained: true,
                            minScale: 1.0,
                            maxScale: 4.0,
                            panEnabled: true,
                            transformationController: _tc,
                            onInteractionUpdate: (details) {
                              final Matrix4 m = _tc.value.clone();
                              // Lock vertical translation (y) to 0 so we only scroll horizontally
                              if (m.storage[13] != 0.0) {
                                m.storage[13] = 0.0;
                                _tc.value = m;
                              }
                            },
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Image.network(
                                urls[_currentImageIndex % urls.length],
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
                      );
                    },
                  ),
                ),
                
                // Contrôles de navigation (si plusieurs images)
                if (urls.length > 1) ...[
                  // Bouton précédent
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentImageIndex = (_currentImageIndex - 1 + urls.length) % urls.length;
                            });
                          },
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
                              Icons.chevron_left,
                              color: Colors.white,
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
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentImageIndex = (_currentImageIndex + 1) % urls.length;
                            });
                          },
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
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                ],
                
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
          );
        },
      ),
    );
  }

  Color _getPodiumColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Doré clair
      case 2:
        return const Color(0xFF90A4AE); // Argent
      case 3:
        return const Color(0xFFFF6F00); // Bronze
      default:
        return Colors.grey;
    }
  }

  LinearGradient _getPodiumGradient(int rank) {
    switch (rank) {
      case 1:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFD700), // Doré clair (haut)
            Color(0xFFB8860B), // Doré foncé (bas)
          ],
        );
      case 2:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB0BEC5), // Argent clair
            Color(0xFF90A4AE), // Argent foncé
          ],
        );
      case 3:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFB74D), // Bronze clair
            Color(0xFFFF6F00), // Bronze foncé
          ],
        );
      default:
        return const LinearGradient(
          colors: [Colors.grey, Colors.grey],
        );
    }
  }

  Color _getPodiumNumberColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFB8860B); // Doré foncé
      case 2:
        return const Color(0xFF424242); // Gris foncé
      case 3:
        return const Color(0xFFD32F2F); // Rouge foncé
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallMobile = screenWidth < 361;   // Galaxy Fold fermé, Galaxy S8+ (≤360px)
    final isSmallMobile = screenWidth < 431;       // iPhone XR/14 Pro Max, Pixel 7, Galaxy S20/A51 (361-430px)
    final isMobile = screenWidth < 768;            // Tous les mobiles standards (431-767px)
    final translationService = Provider.of<TranslationService>(context, listen: true);
    
    // Précharger les traductions pour éviter les appels répétés
    final loadingText = translationService.translate('LOADING_IN_PROGRESS');
    final podiumMsg01 = translationService.translate('PODIUM_Msg01');
    final podiumMsg02 = translationService.translate('PODIUM_Msg02');
    final podiumMsg03 = translationService.translate('PODIUM_Msg03');
    final productcodeMsg08 = translationService.translate('PRODUCTCODE_Msg08');
    final productcodeMsg09 = translationService.translate('PRODUCTCODE_Msg09');
    final appHeaderHome = translationService.translate('APPHEADER_HOME');
    // ✅ Utiliser LOADING_IN_LOADER depuis le backend (pas de traduction locale)
    final scancodeTitle = _loadingInLoader ?? translationService.translate('LOADING_IN_LOADER');
    final appHeaderWishlist = translationService.translate('APPHEADER_WISHLIST');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(64),
        child: CustomAppBar(),
      ),
      body: Stack(
        children: [
          // Contenu principal
          _errorMessage.isNotEmpty
              ? _buildErrorState(podiumMsg01, isVerySmallMobile, isSmallMobile, isMobile)
              : _productData == null && !_isLoading
                  ? _buildNotFoundState(productcodeMsg08, productcodeMsg09, podiumMsg01, isVerySmallMobile, isSmallMobile, isMobile)
                  : _buildPodiumView(isMobile, isSmallMobile, isVerySmallMobile, podiumMsg01, podiumMsg02, podiumMsg03),
          
          // Loader en overlay complet
          if (_isLoading)
            Positioned.fill(
              child: _buildLoadingState(loadingText, isVerySmallMobile, isSmallMobile),
            ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildLoadingState(String loadingText, bool isVerySmallMobile, bool isSmallMobile) {
    return Container(
      color: Colors.white, // Page entièrement blanche
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation de chargement hexagonDots
            LoadingAnimationWidget.hexagonDots(
              color: Colors.blue,
              size: isVerySmallMobile ? 60 : (isSmallMobile ? 70 : 80),
            ),
            SizedBox(height: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24)),
            // Texte de chargement
            Text(
              loadingText,
              style: TextStyle(
                fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String podiumMsg01, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isVerySmallMobile ? 16.0 : (isSmallMobile ? 20.0 : 24.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isVerySmallMobile ? 48 : (isSmallMobile ? 56 : 64),
              color: Colors.red[600],
            ),
            SizedBox(height: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16)),
              textAlign: TextAlign.center,
            ),
            // Afficher le compteur si c'est une erreur d'authentification
            if (_isAuthError) ...[
              SizedBox(height: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                  vertical: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12),
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  'Redirection vers la page de connexion dans $_countdownSeconds seconde${_countdownSeconds > 1 ? 's' : ''}...',
                  style: TextStyle(
                    fontSize: isVerySmallMobile ? 12 : (isSmallMobile ? 13 : 14),
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_isAuthError) {
                    // Si c'est une erreur d'authentification, rediriger directement vers le login
                    _countdownTimer?.cancel();
                    _redirectToLogin();
                  } else {
                    // Sinon, afficher le modal de recherche
                    _showSearchModal();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_isAuthError ? 'Se connecter maintenant' : podiumMsg01),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState(String productcodeMsg08, String productcodeMsg09, String podiumMsg01, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isVerySmallMobile ? 16.0 : (isSmallMobile ? 20.0 : 24.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: isVerySmallMobile ? 48 : (isSmallMobile ? 56 : 64),
              color: Colors.grey[400],
            ),
            SizedBox(height: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
            Text(
              productcodeMsg08,
              style: TextStyle(
                fontSize: isVerySmallMobile ? 18 : (isSmallMobile ? 19 : 20),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isVerySmallMobile ? 6 : (isSmallMobile ? 7 : 8)),
            Text(
              productcodeMsg09,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isVerySmallMobile ? 12 : (isSmallMobile ? 13 : 14),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showSearchModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(podiumMsg01),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumView(bool isMobile, bool isSmallMobile, bool isVerySmallMobile, String podiumMsg01, String podiumMsg02, String podiumMsg03) {
    final articles = _productData?['Articles'] as List<dynamic>?;
    if (articles == null || articles.isEmpty) {
      // Variables temporaires pour les cas d'erreur
      final translationService = Provider.of<TranslationService>(context, listen: false);
      final productcodeMsg08 = translationService.translate('PRODUCTCODE_Msg08');
      final productcodeMsg09 = translationService.translate('PRODUCTCODE_Msg09');
      return _buildNotFoundState(productcodeMsg08, productcodeMsg09, podiumMsg01, isVerySmallMobile, isSmallMobile, isMobile);
    }

    final mainArticle = articles[0];
    // Afficher exactement les champs API (sans filtrage ni masquage)
    final productName = ((_productData?['sName'] as String?)
        ?? (mainArticle['sName'] as String?)
        ?? (mainArticle['sArticleName'] as String?)
        ?? '');
    final productDescr = ((_productData?['sDescr'] as String?)
        ?? (mainArticle['sDescr'] as String?)
        ?? (mainArticle['sArticleDescr'] as String?)
        ?? '');
    final productCode = _productData?['sCodeArticle'] ?? '';
    final productPrice = mainArticle['sPrice'];

    int? parsePosition(Map<String, dynamic> article) {
      final raw = article['iPodiumPosition']?.toString();
      if (raw == null) return null;
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed <= 0) return null;
      return parsed;
    }

    final allArticles = List<Map<String, dynamic>>.from(
      articles.map((e) => e as Map<String, dynamic>),
    );

    final sortedByPosition = List<Map<String, dynamic>>.from(allArticles);
    sortedByPosition.sort((a, b) {
      final posA = parsePosition(a);
      final posB = parsePosition(b);
      final hasPosA = posA != null;
      final hasPosB = posB != null;

      if (hasPosA && hasPosB) {
        return posA!.compareTo(posB!);
      }
      if (hasPosA) return -1;
      if (hasPosB) return 1;

      return 0;
      // final priceA = _extractPrice(a['sPrice'] ?? '');
      // final priceB = _extractPrice(b['sPrice'] ?? '');
      // return priceA.compareTo(priceB);
    });
    
    final topThree = sortedByPosition.take(3).toList();
    final otherCountries = sortedByPosition.skip(3).toList();

    // final podiumCandidates = sortedByPosition.where((article) {
    //   final pos = parsePosition(article);
    //   return pos != null && pos > 0 && pos <= 3;
    // }).toList();

    // if (podiumCandidates.length < 3) {
    //   final remaining = sortedByPosition.where((article) => !podiumCandidates.contains(article)).toList();
    //   remaining.sort((a, b) {
    //     final priceA = _extractPrice(a['sPrice'] ?? '');
    //     final priceB = _extractPrice(b['sPrice'] ?? '');
    //     return priceA.compareTo(priceB);
    //   });
    //   podiumCandidates.addAll(remaining.take(3 - podiumCandidates.length));
    // }

    // final topThree = podiumCandidates.isNotEmpty
    //     ? podiumCandidates.take(3).toList()
    //     : (() {
    //         final fallback = List<Map<String, dynamic>>.from(allArticles);
    //         fallback.sort((a, b) {
    //           final posA = parsePosition(a);
    //           final posB = parsePosition(b);
    //           final hasPosA = posA != null;
    //           final hasPosB = posB != null;

    //           if (hasPosA && hasPosB) {
    //             return posA!.compareTo(posB!);
    //           }
    //           if (hasPosA) return -1;
    //           if (hasPosB) return 1;

    //           return 0;
    //         });
    //         return fallback.take(3).toList();
    //       })();

    
    // final otherCountries = sortedByPosition.where((article) {
    //   final pos = parsePosition(article);
    //   if (pos != null) {
    //     return pos > 3;
    //   }
    //   return !topThree.contains(article);
    // }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Image et infos principales avec animation Rotation 3D + Scale + Fade
          AnimatedBuilder(
            animation: _productController,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(_productRotationAnimation.value), // Rotation 3D
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: _productScaleAnimation.value,
                  child: Opacity(
                    opacity: _productFadeAnimation.value,
                    child: child,
                  ),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isVerySmallMobile ? 6.0 : (isSmallMobile ? 7.0 : 8.0),
                vertical: isVerySmallMobile ? 8.0 : (isSmallMobile ? 10.0 : 12.0),
              ),
              child: Container(
                padding: EdgeInsets.all(isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                width: double.infinity,
                child: Column(
                  children: [
                    // En-tête compact sur mobile: image + textes côte à côte
                    if (isMobile) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: isVerySmallMobile ? 110 : (isSmallMobile ? 120 : 130),
                            height: isVerySmallMobile ? 110 : (isSmallMobile ? 120 : 130),
                            child: _buildProductImage(height: isVerySmallMobile ? 110 : (isSmallMobile ? 120 : 130)),
                          ),
                          SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: TextStyle(
                                    fontSize: isVerySmallMobile ? 15 : (isSmallMobile ? 16 : 17),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isVerySmallMobile ? 4 : 6),
                                Text(
                                  productCode,
                                  style: TextStyle(
                                    fontSize: isVerySmallMobile ? 11 : 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: isVerySmallMobile ? 4 : 6),
                                Text(
                                  productDescr,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: isVerySmallMobile ? 12 : 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        height: 220,
                        child: _buildProductImage(height: 220),
                      ),
                      SizedBox(height: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.left,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                          Text(
                            productCode,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        productDescr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                    SizedBox(height: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                    _buildQuantitySelector(),
                  ],
                ),
              ),
            ),
          ), // Ferme AnimatedBuilder
        
          // Podium avec top 3 - Animation construction depuis le bas  
          if (topThree.isNotEmpty) ...[
            SizedBox(height: isVerySmallMobile ? 8 : (isSmallMobile ? 12 : 16)),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5), // Depuis le bas
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _podiumController,
                  curve: Curves.easeOutBack, // Bounce effect
                ),
              ),
              child: FadeTransition(
                opacity: _podiumController,
                child: Container(
                  height: isVerySmallMobile ? 360 : (isSmallMobile ? 380 : 420),
                  padding: EdgeInsets.symmetric(horizontal: isVerySmallMobile ? 8 : (isSmallMobile ? 12 : 16)),
                  child: _buildPodium(topThree, isVerySmallMobile, isSmallMobile, isMobile),
                ),
              ),
            ),
          ],

          // Espace entre pieds de podium et bouton
          SizedBox(height: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24)),
          // Bouton nouvelle recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showSearchModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  podiumMsg01,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // Autres pays
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MediaQuery.of(context).size.width < 600
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        podiumMsg02,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            podiumMsg03,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.trending_down, size: 16, color: Colors.green[600]),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Text(
                        podiumMsg02,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          'Comparaison des prix en Europe',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Icon(Icons.trending_down, size: 16, color: Colors.green[600]),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          if (otherCountries.isNotEmpty)
            _buildOtherCountries(otherCountries, isVerySmallMobile, isSmallMobile, isMobile),
        ],
      ),
    );
  }

  Widget _buildProductImage({double? height}) {
    final imageUrl = _getCurrentImageUrl();
    final isMobile = MediaQuery.of(context).size.width < 768;
    final hasMultipleImages = _productData?['aImageLink'] != null && 
        _productData!['aImageLink'] is List &&
        (_productData!['aImageLink'] as List).length > 1;

    return Stack(
      children: [
        // Image avec animation et clic pour plein écran
        GestureDetector(
          onTap: _showFullscreenImage,
          child: Container(
            width: double.infinity,
            height: height ?? 200,
            decoration: BoxDecoration(
              color: Colors.white, // Background blanc
              borderRadius: BorderRadius.circular(12),
            ),
            child: imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey[400],
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.image,
                    size: 64,
                    color: Colors.grey[400],
                  ),
          ),
        ),
        
        // Indication visuelle sur mobile
        if (isMobile && imageUrl.isNotEmpty)
          Positioned(
            right: MediaQuery.of(context).size.width < 360 ? 8 : 12,
            bottom: MediaQuery.of(context).size.width < 360 ? 8 : 12,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 360 ? 6 : 10,
                vertical: MediaQuery.of(context).size.width < 360 ? 3 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_full,
                    size: MediaQuery.of(context).size.width < 360 ? 11 : 14,
                    color: Colors.white,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width < 360 ? 4 : 6,
                  ),
                  Consumer<TranslationService>(
                    builder: (context, translationService, child) => Text(
                      translationService.translate('PODIUM_ENLARGE'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width < 360 ? 9.5 : 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Boutons de navigation
        if (hasMultipleImages && !isMobile) ...[
          Positioned(
            left: 8,
            top: ((height ?? 200) / 2) - 20,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _prevImage,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: ((height ?? 200) / 2) - 20,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _nextImage,
                ),
              ),
            ),
          ),
          
        ],
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentQuantity > 1 ? () {
            if (mounted) setState(() => _currentQuantity--);
          } : null,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _currentQuantity > 1 ? const Color(0xFFBBDEFB) : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.remove, size: 20),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _currentQuantity.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            if (mounted) setState(() => _currentQuantity++);
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF81D4FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> topThree, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    // Réorganiser pour avoir 2, 1, 3 (argent, or, bronze)
    final arranged = [
      if (topThree.length > 1) topThree[1], // 2ème place
      if (topThree.isNotEmpty) topThree[0],  // 1ère place
      if (topThree.length > 2) topThree[2],  // 3ème place
    ];

    return Container(
      height: isVerySmallMobile ? 380 : (isSmallMobile ? 400 : 440), // ✅ Augmenter légèrement la hauteur pour accommoder 2 lignes de texte
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmallMobile ? 2.0 : (isSmallMobile ? 4.0 : 6.0), // ✅ Réduire encore plus le padding latéral pour éviter le débordement
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max, // ✅ Utiliser toute la largeur disponible
        children: arranged.asMap().entries.map((entry) {
          final visualIndex = entry.key;
          final article = entry.value;
          
          // Déterminer le rang réel (pas l'index visuel)
          int realRank;
          if (visualIndex == 0) realRank = 2; // Argent à gauche
          else if (visualIndex == 1) realRank = 1; // Or au centre
          else realRank = 3; // Bronze à droite

          // ✅ Utiliser Flexible avec flex pour éviter le débordement
          // Le centre (rank 1) a un flex de 3, les côtés ont un flex de 2 chacun
          // Total = 7, donc centre = 3/7 ≈ 42.8%, côtés = 2/7 ≈ 28.6% chacun
          return Flexible(
            flex: realRank == 1 ? 3 : 2, // ✅ Centre plus large, côtés égaux
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isVerySmallMobile ? 1.0 : (isSmallMobile ? 1.5 : 2.0), // ✅ Réduire encore plus les marges pour éviter le débordement
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildPodiumCard(article, realRank, isVerySmallMobile, isSmallMobile, isMobile),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPodiumCard(Map<String, dynamic> article, int rank, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    final cardColor = rank == 1 
        ? const Color(0xFFFFFBE6) 
        : (rank == 2 ? const Color(0xFFF5F5F5) : const Color(0xFFFFF3E0));
    final borderColor = rank == 1 
        ? const Color(0xFFFFB300) 
        : (rank == 2 ? const Color(0xFF90A4AE) : const Color(0xFFFF6F00));
    
    // Utiliser les données du backend pour l'écart de prix
    final sEcartPrice = article['sEcartPrice']?.toString() ?? '';
    final sEcartPriceColor = article['sEcartPriceColor']?.toString().toLowerCase() ?? '';
    final hasEcartPrice = sEcartPrice.isNotEmpty && sEcartPrice != '0' && sEcartPrice != '0.00 €';
    final isEconomy = sEcartPriceColor == 'green';
    
    final bool priceUnavailable =
        article['sPrice'] == null ||
        article['sPrice'].toString().trim().isEmpty ||
        article['sPrice'].toString().toUpperCase().contains('INDISPONIBLE');
    
    // Vérifier si c'est le pays de l'utilisateur
    final isUserCountry = _userCountryCode != null && 
        article['sPays']?.toString().toLowerCase() == _userCountryCode!.toLowerCase();

    final podiumHeight = isVerySmallMobile 
        ? (rank == 1 ? 80.0 : (rank == 2 ? 65.0 : 50.0))
        : (isSmallMobile 
            ? (rank == 1 ? 90.0 : (rank == 2 ? 72.0 : 55.0))
            : (rank == 1 ? 100.0 : (rank == 2 ? 80.0 : 60.0)));

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Carte du pays
        Container(
          // ✅ Pas de marge horizontale ici, elle est gérée par le Flexible parent
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmallMobile ? 2 : (isSmallMobile ? 4 : 6), // ✅ Réduire encore plus le padding horizontal sur mobile pour éviter le débordement
            vertical: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12),
          ),
          constraints: BoxConstraints(
            minHeight: isVerySmallMobile
                ? (rank == 1 ? 240 : (rank == 2 ? 180 : 200)) // ✅ Augmenter pour accommoder 2 lignes
                : (isSmallMobile
                    ? (rank == 1 ? 260 : (rank == 2 ? 200 : 220))
                    : (rank == 1 ? 300 : (rank == 2 ? 230 : 250))),
          ),
          width: double.infinity, // ✅ Utiliser toute la largeur disponible
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête (drapeau + pays + IKEA + icônes en bas)
              Container(
                width: double.infinity, // ✅ Utiliser toute la largeur disponible
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallMobile ? 2 : (isSmallMobile ? 4 : 6), // ✅ Réduire encore plus le padding horizontal sur mobile pour éviter le débordement
                  vertical: isVerySmallMobile ? 8 : (isSmallMobile ? 9 : 10), // ✅ Ajuster le padding vertical
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom du pays en haut (centré)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        article['sPays'] ?? 'Pays',
                        style: TextStyle(
                          fontStyle: FontStyle.normal,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w400,
                          color: const Color.fromRGBO(0, 0, 0, 1.0),
                          height: 24.0 / 16.0,
                          letterSpacing: 0.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: isVerySmallMobile ? 4 : 6),
                    // Row avec drapeau + IKEA d'un côté et icônes de l'autre
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Drapeau + IKEA à gauche
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Drapeau
                            Container(
                              margin: EdgeInsets.only(
                                right: isVerySmallMobile ? 4 : (isSmallMobile ? 6 : 8),
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey[300]!, width: 0.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: article['sPaysDrapeau'] != null
                                    ? Image.network(
                                        ApiConfig.getProxiedImageUrl('https://jirig.be${article['sPaysDrapeau']}'),
                                        width: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                                        height: isVerySmallMobile ? 13 : (isSmallMobile ? 14 : 16),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('❌ Erreur chargement drapeau: ${article['sPaysDrapeau']}');
                                          print('❌ URL complète: ${ApiConfig.getProxiedImageUrl('https://jirig.be${article['sPaysDrapeau']}')}');
                                          return Container(
                                            width: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                                            height: isVerySmallMobile ? 13 : (isSmallMobile ? 14 : 16),
                                            color: Colors.grey[200],
                                            child: Icon(Icons.flag, size: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12), color: Colors.grey[400]),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                                        height: isVerySmallMobile ? 13 : (isSmallMobile ? 14 : 16),
                                        color: Colors.grey[200],
                                        child: Icon(Icons.flag, size: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12), color: Colors.grey[400]),
                                      ),
                              ),
                            ),
                            // IKEA
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'IKEA',
                                style: TextStyle(
                                  fontSize: isVerySmallMobile ? 9 : (isSmallMobile ? 10 : 11),
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Icônes à droite
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: isVerySmallMobile ? 3 : (isSmallMobile ? 4 : 6),
                          runSpacing: isVerySmallMobile ? 3 : (isSmallMobile ? 4 : 6),
                          children: [
                            // Icône Home si sMyHomeIcon correspond au pays de l'article
                            Builder(
                              builder: (context) {
                                final articleCountryCode = (article['sLangueIso'] ?? article['sPays'] ?? '').toString().toUpperCase();
                                final sMyHomeIcon = _productData?['sMyHomeIcon']?.toString().toUpperCase() ?? '';
                                final shouldShowHomeIcon = sMyHomeIcon.isNotEmpty && 
                                    (articleCountryCode == sMyHomeIcon || 
                                     articleCountryCode.contains(sMyHomeIcon) || 
                                     sMyHomeIcon.contains(articleCountryCode));
                                
                                if (shouldShowHomeIcon) {
                                  return Container(
                                    padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 3 : 4)),
                                    decoration: BoxDecoration(
                                      color: Colors.green[400],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.home, 
                                      size: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : 14),
                                      color: Colors.white,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            // Icône Panier si IsInBasket correspond au pays de l'article
                            Builder(
                              builder: (context) {
                                final articleCountryCode = (article['sLangueIso'] ?? article['sPays'] ?? '').toString().toUpperCase();
                                final IsInBasket = _productData?['IsInBasket']?.toString().toUpperCase() ?? '';
                                final shouldShowCartIcon = IsInBasket.isNotEmpty && 
                                    (articleCountryCode == IsInBasket || 
                                     articleCountryCode.contains(IsInBasket) || 
                                     IsInBasket.contains(articleCountryCode));
                                
                                if (shouldShowCartIcon) {
                                  return Container(
                                    padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 3 : 4)),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[400],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.shopping_cart, 
                                      size: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : 14),
                                      color: Colors.white,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            // Trophée pour la 1ère place (si pas de home icon)
                            if (rank == 1 && (article['sMyHomeIcon'] == null || article['sMyHomeIcon'].toString().isEmpty))
                              Container(
                                padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 3 : 4)),
                                decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle),
                                child: Icon(
                                  Icons.emoji_events, 
                                  size: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : 14),
                                  color: const Color(0xFF7A5F00),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              
              // Prix centré
              Text(
                priceUnavailable ? 'Indisponible' : article['sPrice']?.toString() ?? 'N/A',
                style: TextStyle(
                  fontSize: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                  fontWeight: FontWeight.bold,
                  color: priceUnavailable ? Colors.grey : Colors.blue,
                ),
              ),
              SizedBox(height: isVerySmallMobile ? 3 : 4),
              
              
              // Badge d'écart de prix (utilise les données du backend)
              if (!priceUnavailable && hasEcartPrice)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12),
                    vertical: isVerySmallMobile ? 6 : (isSmallMobile ? 7 : 8),
                  ),
                  decoration: BoxDecoration(
                    color: isEconomy ? const Color(0xFF86EFAC) : Colors.red[300], // Tailwind green-300 ou rouge
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sEcartPrice,
                    style: TextStyle(
                      fontSize: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12),
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Texte noir
                    ),
                  ),
                ),
              SizedBox(
                height: isVerySmallMobile
                    ? (rank == 2 ? 18 : (rank == 1 ? 22 : (rank == 3 ? 12 : 50)))
                    : (isSmallMobile
                        ? (rank == 2 ? 22 : (rank == 1 ? 25 : (rank == 3 ? 18 : 55)))
                        : (rank == 2 ? 30 : (rank == 1 ? 30 : (rank == 3 ? 25 : 70)))),
              ),
              
              // Quantité - Réduire la taille sur mobile pour éviter le débordement
              FittedBox( // ✅ Utiliser FittedBox pour adapter automatiquement la taille
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MouseRegion(
                      cursor: _currentQuantity > 1 
                          ? SystemMouseCursors.click 
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            if (_currentQuantity > 1) {
                              _currentQuantity--;
                            }
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 3.5 : 4)), // ✅ Réduire le padding sur mobile
                        decoration: BoxDecoration(
                          color: _currentQuantity > 1 
                              ? const Color(0xFF64B5F6)  // Bleu vif quand cliquable
                                : const Color(0xFFE3F2FD), // Bleu très clair quand à 1
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove, 
                          size: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16), // ✅ Réduire la taille de l'icône sur mobile
                          color: _currentQuantity > 1 
                              ? Colors.white  // Blanc quand cliquable
                                : Colors.grey[300], // Gris clair quand à 1
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12), // ✅ Réduire l'espacement horizontal sur mobile
                      ),
                      child: Text(
                        _currentQuantity.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16), // ✅ Réduire la taille du texte sur mobile
                        ),
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _currentQuantity++;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 3.5 : 4)), // ✅ Réduire le padding sur mobile
                        decoration: const BoxDecoration(
                          color: Color(0xFF64B5F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add, 
                          size: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16), // ✅ Réduire la taille de l'icône sur mobile
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
              
              const SizedBox(height: 12),
              
              // Bouton cœur - Réduire la taille sur mobile pour éviter le débordement
              FittedBox( // ✅ Utiliser FittedBox pour adapter automatiquement la taille
                fit: BoxFit.scaleDown,
                child: MouseRegion(
                  cursor: priceUnavailable ? SystemMouseCursors.basic : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: priceUnavailable
                        ? null
                        : () {
                            _addToCart(article);
                          },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24), // ✅ Réduire le padding horizontal sur mobile
                        vertical: isVerySmallMobile ? 8 : (isSmallMobile ? 9 : 10), // ✅ Réduire le padding vertical sur mobile
                      ),
                      decoration: BoxDecoration(
                        color: priceUnavailable ? const Color(0xFFE0F2FF) : const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: priceUnavailable
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: priceUnavailable ? Colors.grey[400] : Colors.white,
                        size: isVerySmallMobile ? 18 : (isSmallMobile ? 19 : 20), // ✅ Réduire la taille de l'icône sur mobile
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: isVerySmallMobile ? 4 : (isSmallMobile ? 6 : 8)),
        
        // Bloc de base du podium
        Container(
          height: podiumHeight,
          margin: EdgeInsets.symmetric(horizontal: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16)),
          decoration: BoxDecoration(
            gradient: _getPodiumGradient(rank),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: _getPodiumColor(rank).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Effet de brillance sur le bloc
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: podiumHeight * 0.3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                ),
              ),
              // Numéro du rang
              Center(
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontSize: isVerySmallMobile ? 18 : (isSmallMobile ? 20 : 22),
                    fontWeight: FontWeight.bold,
                    color: _getPodiumNumberColor(rank),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildOtherCountries(List<Map<String, dynamic>> countries, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        
        // Vérifier si c'est le pays de l'utilisateur
        final isUserCountry = _userCountryCode != null && 
            country['sPays']?.toString().toLowerCase() == _userCountryCode!.toLowerCase();
        
        // Animation ripple effect : chaque pays apparaît avec un délai progressif
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 80)), // Délai progressif (ripple)
          tween: Tween<double>(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCirc, // Courbe circulaire (effet ripple)
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (value * 0.2), // Scale de 0.8 → 1.0
              child: Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(-20 * (1 - value), 0), // Slide depuis la gauche
                  child: child,
                ),
              ),
            );
          },
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // ✅ Augmenter le padding vertical
          // ✅ Ne pas fixer la hauteur, laisser le contenu déterminer la hauteur
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUserCountry ? Colors.green[400]! : Colors.grey[300]!,
              width: isUserCountry ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Centrer verticalement pour les icônes
            children: [
              // Drapeau
              if (country['sPaysDrapeau'] != null)
                Container(
                  width: 24,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  child: Image.network(
                    ApiConfig.getProxiedImageUrl('https://jirig.be${country['sPaysDrapeau']}'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.flag, size: 12, color: Colors.grey[400]);
                    },
                  ),
                ),
              
              // Infos pays - Structure en colonne
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom du pays
                    // Style: system-ui, normal, weight 400, size 16px, line height 24px, color black
                    Text(
                      country['sPays'] ?? 'Pays',
                      style: const TextStyle(
                        // fontFamily non spécifié = utilise la police système (équivalent à system-ui)
                        fontStyle: FontStyle.normal, // Style: normal
                        fontSize: 16.0, // Size: 16px
                        fontWeight: FontWeight.w400, // Weight: 400 (normal)
                        color: Color.fromRGBO(0, 0, 0, 1.0), // Color: rgb(0, 0, 0) - noir
                        height: 24.0 / 16.0, // Line Height: 24px / 16px = 1.5
                        letterSpacing: 0.0, // Pas de letterSpacing
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Icônes centrées verticalement au milieu du container
              Builder(
                builder: (context) {
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: isVerySmallMobile ? 3 : (isSmallMobile ? 4 : 6),
                    runSpacing: isVerySmallMobile ? 3 : (isSmallMobile ? 4 : 6),
                    children: [
                      // Icône Home si sMyHomeIcon correspond au pays
                      Builder(
                        builder: (context) {
                          // Récupérer le code pays (sLangueIso ou sPays)
                          final countryCode = (country['sLangueIso'] ?? country['sPays'] ?? '').toString().toUpperCase();
                          // Récupérer sMyHomeIcon depuis les données du produit (au niveau global)
                          final sMyHomeIcon = _productData?['sMyHomeIcon']?.toString().toUpperCase() ?? '';
                          // Vérifier si sMyHomeIcon correspond à ce pays
                          final shouldShowHomeIcon = sMyHomeIcon.isNotEmpty && 
                              (countryCode == sMyHomeIcon || 
                               countryCode.contains(sMyHomeIcon) || 
                               sMyHomeIcon.contains(countryCode));
                          
                          if (shouldShowHomeIcon) {
                            return Container(
                              padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 3 : 4)),
                              decoration: BoxDecoration(
                                color: Colors.green[400],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.home,
                                size: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : 14),
                                color: Colors.white,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Icône Panier si IsInBasket correspond au pays
                      Builder(
                        builder: (context) {
                          // Récupérer le code pays (sLangueIso ou sPays)
                          final countryCode = (country['sLangueIso'] ?? country['sPays'] ?? '').toString().toUpperCase();
                          // Récupérer IsInBasket depuis les données du produit (au niveau global)
                          final IsInBasket = _productData?['IsInBasket']?.toString().toUpperCase() ?? '';
                          // Vérifier si IsInBasket correspond à ce pays
                          final shouldShowCartIcon = IsInBasket.isNotEmpty && 
                              (countryCode == IsInBasket || 
                               countryCode.contains(IsInBasket) || 
                               IsInBasket.contains(countryCode));
                          
                          if (shouldShowCartIcon) {
                            return Container(
                              padding: EdgeInsets.all(isVerySmallMobile ? 3 : (isSmallMobile ? 3 : 4)),
                              decoration: BoxDecoration(
                                color: Colors.blue[400],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_cart,
                                size: isVerySmallMobile ? 11 : (isSmallMobile ? 12 : 14),
                                color: Colors.white,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  );
                },
              ),
              
              // Prix
              Builder(
                builder: (context) {
                  final priceStr = country['sPrice']?.toString() ?? '';
                  final bool priceUnavailable = priceStr.trim().isEmpty ||
                      priceStr.toUpperCase().contains('INDISPONIBLE') ||
                      priceStr == '0' ||
                      priceStr == '0.0';

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        priceUnavailable ? 'Indisponible' : priceStr,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: priceUnavailable ? Colors.grey : const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Wishlist
                      StatefulBuilder(
                        builder: (context, setState) {
                          bool isHovered = false;
                          final Color borderColor = priceUnavailable
                              ? Colors.grey[300]!
                              : (isHovered ? Colors.red : Colors.grey[300]!);
                          final Color labelColor = priceUnavailable
                              ? Colors.grey
                              : (isHovered ? Colors.red : Colors.grey[700]!);
                          final Color? backgroundColor = priceUnavailable
                              ? const Color(0xFFE5F3FF)
                              : (isHovered ? Colors.blue[100] : null);
                          final Color iconColor = priceUnavailable
                              ? Colors.grey[400]!
                              : (isHovered ? Colors.red : Colors.grey[700]!);

                          return MouseRegion(
                            cursor: priceUnavailable ? SystemMouseCursors.basic : SystemMouseCursors.click,
                            onEnter: (_) {
                              if (!priceUnavailable) setState(() => isHovered = true);
                            },
                            onExit: (_) => setState(() => isHovered = false),
                            child: OutlinedButton.icon(
                              onPressed: priceUnavailable
                                  ? null
                                  : () {
                                      _addToWishlist(country);
                                    },
                              icon: Icon(
                                isHovered && !priceUnavailable ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: iconColor,
                              ),
                              label: Text(
                                'Wishlist',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: labelColor,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: labelColor,
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                backgroundColor: backgroundColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(String appHeaderHome, String scancodeTitle, String appHeaderWishlist) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.home, appHeaderHome),
              _buildBottomNavItem(Icons.qr_code_scanner, scancodeTitle),
              _buildBottomNavItem(Icons.photo_library, 'Photos'),
              _buildBottomNavItem(Icons.favorite_border, appHeaderWishlist),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(height: 4),
        ],
      ),
    );
  }


  double _extractPrice(String priceString) {
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

  /// Ajouter un article au panier (basé sur SNAL-Project)
  Future<void> _addToCart(Map<String, dynamic> article) async {
    try {
      if (_productData == null) return;

      // Récupérer le profil utilisateur
      final profileData = await LocalStorageService.getProfile();
      if (profileData == null) {
        _showSnackBar('Veuillez vous connecter pour ajouter au panier');
        return;
      }

      final iProfile = profileData['iProfile'];
      // ✅ PRIORITÉ: Utiliser l'iBasket stocké (depuis l'URL ou le profil)
      // Sinon, utiliser celui du profil
      final iBasket = _currentIBasket ?? profileData['iBasket'];
      final sPaysFav = profileData['sPaysFav'] ?? '';
      
      print('🔍 DEBUG profileData (_addToCart):');
      print('   iProfile: $iProfile');
      print('   iBasket (utilisé): $iBasket');
      print('   iBasket (depuis état): $_currentIBasket');
      print('   iBasket (depuis profil): ${profileData['iBasket']}');
      print('   sPaysLangue: ${profileData['sPaysLangue']}');
      print('   sPaysFav: "$sPaysFav" (length: ${sPaysFav.length})');
      print('   Toutes les clés: ${profileData.keys.toList()}');
      
      if (iProfile == null) {
        _showSnackBar('Profil utilisateur invalide');
        return;
      }

      // Récupérer les données du produit (comme SNAL-Project)
      final sCodeArticle = _productData!['sCodeArticleCrypt'] ?? '';
      final sPays = article['sLangueIso'] ?? article['sPays'] ?? ''; // ✅ Utiliser sLangueIso (code pays: DE, FR, ES...)
      final iPrice = _extractPrice(article['sPrice'] ?? '');
      
      print('📦 Données du produit (_addToCart):');
      print('   sCodeArticle: $sCodeArticle');
      print('   sPays (code): $sPays');
      print('   sPays (nom): ${article['sPays']}');
      print('   iPrice: $iPrice');
      
      if (sCodeArticle.isEmpty || sPays.isEmpty || iPrice <= 0) {
        _showSnackBar('Données du produit invalides');
        return;
      }

      // ✅ Pas de loader nécessaire - redirection immédiate

      // ✅ iBasket est une chaîne cryptée, ne PAS la parser en int
      final iBasketStr = iBasket?.toString() ?? '';
      
      print('🛒 Ajout panier - iBasket: $iBasketStr');
      print('🛒 Pays sélectionné (code): $sPays');
      
      // Ajouter l'article au panier
      final result = await _apiService.addToWishlist(
        sCodeArticle: sCodeArticle,
        sPays: sPays,
        iPrice: iPrice,
        iQuantity: _currentQuantity,
        currentIBasket: iBasketStr,
        iProfile: iProfile.toString(),
        sPaysLangue: profileData['sPaysLangue'] ?? 'FR/FR',
        sPaysFav: profileData['sPaysFav'] ?? '',
      );

      print('📥 Résultat complet de addToWishlist: $result');
      
      // 🔍 Vérifier si l'API retourne Ui_Result == 'GIVE_EMAIL' (connexion requise après 5 articles)
      if (result != null && result['Ui_Result'] == 'GIVE_EMAIL') {
        print('🔒 ERREUR: Ui_Result == GIVE_EMAIL - Connexion requise après 5 articles !');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Vous avez atteint la limite de 5 articles. Veuillez vous connecter pour ajouter plus d\'articles à votre panier.';
          });
        }
        return;
      }
      
      if (result != null && result['success'] == true) {
        // ⚠️ Vérifier s'il y a une erreur SQL même si success=true (comme dans vos logs)
        if (result['data'] != null && result['data'] is List && result['data'].isNotEmpty) {
          final firstData = result['data'][0];
          
          // Vérifier si c'est un objet avec une erreur SQL
          if (firstData is Map && firstData.containsKey('JSON_F52E2B61-18A1-11d1-B105-00805F49916B')) {
            final jsonStr = firstData['JSON_F52E2B61-18A1-11d1-B105-00805F49916B'];
            print('⚠️ Réponse contient un JSON SQL: $jsonStr');
            
            // Vérifier si c'est une erreur
            if (jsonStr != null && jsonStr.toString().contains('sError')) {
              print('❌ ERREUR SQL détectée même avec success=true !');
              
              // 🔍 Vérifier si l'erreur demande la connexion (après 5 articles)
              final jsonStrLower = jsonStr.toString().toLowerCase();
              if (jsonStrLower.contains('connect') || 
                  jsonStrLower.contains('connexion') || 
                  jsonStrLower.contains('login') ||
                  jsonStrLower.contains('email') ||
                  jsonStrLower.contains('give_email') ||
                  jsonStrLower.contains('limite') ||
                  jsonStrLower.contains('limit')) {
                print('🔒 ERREUR: Connexion requise après 5 articles !');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Vous avez atteint la limite de 5 articles. Veuillez vous connecter pour ajouter plus d\'articles à votre panier.';
                  });
                }
                return;
              }
              
              _showSnackBar('Erreur SQL lors de l\'ajout au panier');
              return;
            }
          }
        }
        
        print('✅ Article ajouté/mis à jour dans le panier (pas d\'erreur SQL)');
        
        // ✅ PRIORITÉ: Récupérer le nouvel iBasket et le nom du basket retournés par l'API
        // L'API peut retourner un nouvel iBasket différent de celui envoyé
        String? newIBasketFromApi;
        String? newBasketNameFromApi;
        if (result['data'] != null && result['data'] is List && result['data'].isNotEmpty) {
          newIBasketFromApi = result['data'][0]['iBasket']?.toString();
          newBasketNameFromApi = result['data'][0]['sBasketName']?.toString();
          if (newIBasketFromApi != null && newIBasketFromApi.isNotEmpty) {
            print('🔄 Nouvel iBasket retourné par l\'API: $newIBasketFromApi');
            if (newBasketNameFromApi != null && newBasketNameFromApi.isNotEmpty) {
              print('🔄 Nom du basket retourné par l\'API: $newBasketNameFromApi');
            }
            
            // Sauvegarder le nouveau iBasket
            await LocalStorageService.saveProfile({
              'iProfile': iProfile.toString(),
              'iBasket': newIBasketFromApi,
              'sPaysLangue': profileData['sPaysLangue'] ?? '',
            });
            print('💾 Nouveau iBasket sauvegardé: $newIBasketFromApi');
            
            // ✅ Mettre à jour _currentIBasket avec le nouvel iBasket
            _currentIBasket = newIBasketFromApi;
            print('✅ _currentIBasket mis à jour avec le nouvel iBasket de l\'API');
          }
        }
        
        // Afficher un message de succès
        // _showSnackBar(
        //   '✓ Article ajouté au panier (${article['sPays']}) !',
        //   isSuccess: true,
        // );
        
        // ⏱️ Attendre un peu pour s'assurer que le serveur a traité l'ajout
        print('⏱️ Attente de 300ms pour s\'assurer que le serveur a bien traité l\'ajout...');
        await Future.delayed(const Duration(milliseconds: 300));
        
        // ✅ Redirection vers wishlist avec timestamp, iBasket et nom du basket pour sélectionner le bon basket
        print('🔄 Redirection vers /wishlist depuis _addToCart');
        if (mounted) {
          print('✅ Widget monté, redirection en cours...');
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          // ✅ PRIORITÉ: Utiliser le nouvel iBasket retourné par l'API
          // Sinon, utiliser _currentIBasket ou iBasket (fallback)
          final iBasketToUse = newIBasketFromApi ?? _currentIBasket ?? iBasket;
          final basketNameToUse = newBasketNameFromApi;
          
          // Construire l'URL avec iBasket et nom du basket (pour fallback si iBasket ne correspond pas)
          final queryParams = <String, String>{'refresh': timestamp.toString()};
          if (iBasketToUse != null && iBasketToUse.isNotEmpty) {
            queryParams['iBasket'] = Uri.encodeComponent(iBasketToUse);
          }
          if (basketNameToUse != null && basketNameToUse.isNotEmpty) {
            queryParams['basketName'] = Uri.encodeComponent(basketNameToUse);
          }
          
          final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
          print('🛒 Redirection avec iBasket (priorité: API > état > profil): $iBasketToUse');
          if (basketNameToUse != null) {
            print('🛒 Redirection avec nom du basket (fallback): $basketNameToUse');
          }
          context.go('/wishlist?$queryString');
        } else {
          print('❌ Widget non monté, redirection annulée');
        }
      } else if (result != null && result['error'] != null) {
        print('❌ Erreur addToWishlist: ${result['error']}');
        
        // 🔍 Vérifier si l'erreur demande la connexion
        final errorStr = result['error'].toString().toLowerCase();
        if (errorStr.contains('connect') || 
            errorStr.contains('connexion') || 
            errorStr.contains('login') ||
            errorStr.contains('email') ||
            errorStr.contains('give_email') ||
            errorStr.contains('limite') ||
            errorStr.contains('limit')) {
          print('🔒 ERREUR: Connexion requise après 5 articles !');
          _showSnackBar('Veuillez vous connecter pour ajouter plus de 5 articles au panier');
        } else {
          _showSnackBar('Erreur: ${result['error']}');
        }
      } else {
        print('❌ Réponse invalide de addToWishlist: $result');
        _showSnackBar('Erreur lors de l\'ajout au panier');
      }
      
    } catch (e) {
      print('Erreur _addToCart: $e');
      _showSnackBar('Erreur lors de l\'ajout au panier');
    }
  }

  /// Ajouter un article à la wishlist (basé sur SNAL-Project)
  Future<void> _addToWishlist(Map<String, dynamic> country) async {
    print('\n🚀 === DÉBUT _addToWishlist ===');
    print('🌍 Pays reçu: ${country['sPays']}');
    print('💰 Prix reçu: ${country['sPrice']}');
    
    try {
      if (_productData == null) {
        print('❌ _productData est null - RETOUR');
        return;
      }

      print('✅ _productData OK');

      // Récupérer le profil utilisateur
      final profileData = await LocalStorageService.getProfile();
      if (profileData == null) {
        print('❌ profileData est null - RETOUR');
        _showSnackBar('Veuillez vous connecter pour ajouter à la wishlist');
        return;
      }

      print('✅ profileData récupéré');

      final iProfile = profileData['iProfile'];
      // ✅ PRIORITÉ: Utiliser l'iBasket stocké (depuis l'URL ou le profil)
      // Sinon, utiliser celui du profil
      final iBasket = _currentIBasket ?? profileData['iBasket'];
      final sPaysFav = profileData['sPaysFav'] ?? '';
      
      print('🔍 DEBUG profileData (_addToWishlist):');
      print('   iProfile: $iProfile');
      print('   iBasket (utilisé): $iBasket');
      print('   iBasket (depuis état): $_currentIBasket');
      print('   iBasket (depuis profil): ${profileData['iBasket']}');
      print('   sPaysLangue: ${profileData['sPaysLangue']}');
      print('   sPaysFav: "$sPaysFav" (length: ${sPaysFav.length})');
      print('   Toutes les clés: ${profileData.keys.toList()}');
      
      if (iProfile == null) {
        print('❌ iProfile est null - RETOUR');
        _showSnackBar('Profil utilisateur invalide');
        return;
      }

      print('✅ iProfile OK');

      // Récupérer les données du produit (comme SNAL-Project)
      final sCodeArticle = _productData!['sCodeArticleCrypt'] ?? '';
      final sPays = country['sLangueIso'] ?? country['sPays'] ?? ''; // ✅ Utiliser sLangueIso (code pays: DE, FR, ES...)
      final iPrice = _extractPrice(country['sPrice'] ?? '');
      
      print('📦 Données du produit:');
      print('   sCodeArticle: $sCodeArticle');
      print('   sPays (code): $sPays');
      print('   sPays (nom): ${country['sPays']}');
      print('   iPrice: $iPrice');
      
      if (sCodeArticle.isEmpty || sPays.isEmpty || iPrice <= 0) {
        print('❌ Données invalides - RETOUR');
        print('   sCodeArticle.isEmpty: ${sCodeArticle.isEmpty}');
        print('   sPays.isEmpty: ${sPays.isEmpty}');
        print('   iPrice <= 0: ${iPrice <= 0}');
        _showSnackBar('Données du produit invalides');
        return;
      }

      print('✅ Données du produit OK');

      // ✅ iBasket est une chaîne cryptée, ne PAS la parser en int
      final iBasketStr = iBasket?.toString() ?? '';
      
      print('🛒 Ajout wishlist - iBasket: $iBasketStr');
      print('🛒 Pays sélectionné: $sPays');
      print('🔄 APPEL addToWishlist...');
      
      // Ajouter l'article à la wishlist
      final result = await _apiService.addToWishlist(
        sCodeArticle: sCodeArticle,
        sPays: sPays,
        iPrice: iPrice,
        iQuantity: _currentQuantity,
        currentIBasket: iBasketStr,
        iProfile: iProfile.toString(),
        sPaysLangue: profileData['sPaysLangue'] ?? 'FR/FR',
        sPaysFav: profileData['sPaysFav'] ?? '',
      );

      print('📥 Résultat complet de addToWishlist: $result');
      
      // 🔍 Vérifier si l'API retourne Ui_Result == 'GIVE_EMAIL' (connexion requise après 5 articles)
      if (result != null && result['Ui_Result'] == 'GIVE_EMAIL') {
        print('🔒 ERREUR: Ui_Result == GIVE_EMAIL - Connexion requise après 5 articles !');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Vous avez atteint la limite de 5 articles. Veuillez vous connecter pour ajouter plus d\'articles à votre panier.';
          });
        }
        return;
      }
      
      if (result != null && result['success'] == true) {
        // ⚠️ Vérifier s'il y a une erreur SQL même si success=true (comme dans vos logs)
        if (result['data'] != null && result['data'] is List && result['data'].isNotEmpty) {
          final firstData = result['data'][0];
          
          // Vérifier si c'est un objet avec une erreur SQL
          if (firstData is Map && firstData.containsKey('JSON_F52E2B61-18A1-11d1-B105-00805F49916B')) {
            final jsonStr = firstData['JSON_F52E2B61-18A1-11d1-B105-00805F49916B'];
            print('⚠️ Réponse contient un JSON SQL: $jsonStr');
            
            // Vérifier si c'est une erreur
            if (jsonStr != null && jsonStr.toString().contains('sError')) {
              print('❌ ERREUR SQL détectée même avec success=true !');
              
              // 🔍 Vérifier si l'erreur demande la connexion (après 5 articles)
              final jsonStrLower = jsonStr.toString().toLowerCase();
              if (jsonStrLower.contains('connect') || 
                  jsonStrLower.contains('connexion') || 
                  jsonStrLower.contains('login') ||
                  jsonStrLower.contains('email') ||
                  jsonStrLower.contains('give_email') ||
                  jsonStrLower.contains('limite') ||
                  jsonStrLower.contains('limit')) {
                print('🔒 ERREUR: Connexion requise après 5 articles !');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Vous avez atteint la limite de 5 articles. Veuillez vous connecter pour ajouter plus d\'articles à votre panier.';
                  });
                }
                return;
              }
              
              _showSnackBar('Erreur SQL lors de l\'ajout à la wishlist');
              return;
            }
          }
        }
        
        print('✅ Article ajouté/mis à jour dans la wishlist (pas d\'erreur SQL)');
        
        // ✅ PRIORITÉ: Récupérer le nouvel iBasket et le nom du basket retournés par l'API
        // L'API peut retourner un nouvel iBasket différent de celui envoyé
        String? newIBasketFromApi;
        String? newBasketNameFromApi;
        if (result['data'] != null && result['data'] is List && result['data'].isNotEmpty) {
          newIBasketFromApi = result['data'][0]['iBasket']?.toString();
          newBasketNameFromApi = result['data'][0]['sBasketName']?.toString();
          if (newIBasketFromApi != null && newIBasketFromApi.isNotEmpty) {
            print('🔄 Nouvel iBasket retourné par l\'API: $newIBasketFromApi');
            if (newBasketNameFromApi != null && newBasketNameFromApi.isNotEmpty) {
              print('🔄 Nom du basket retourné par l\'API: $newBasketNameFromApi');
            }
            
            // Sauvegarder le nouveau iBasket
            await LocalStorageService.saveProfile({
              'iProfile': iProfile.toString(),
              'iBasket': newIBasketFromApi,
              'sPaysLangue': profileData['sPaysLangue'] ?? '',
            });
            print('💾 Nouveau iBasket sauvegardé: $newIBasketFromApi');
            
            // ✅ Mettre à jour _currentIBasket avec le nouvel iBasket
            _currentIBasket = newIBasketFromApi;
            print('✅ _currentIBasket mis à jour avec le nouvel iBasket de l\'API');
          }
        }
        
        // Afficher un message de succès
        // _showSnackBar(
        //   '✓ Article ajouté à la wishlist (${country['sPays']}) !',
        //   isSuccess: true,
        // );
        
        // ⏱️ Attendre un peu pour s'assurer que le serveur a traité l'ajout
        print('⏱️ Attente de 300ms pour s\'assurer que le serveur a bien traité l\'ajout...');
        await Future.delayed(const Duration(milliseconds: 300));
        
        // ✅ Redirection vers wishlist avec timestamp, iBasket et nom du basket pour sélectionner le bon basket
        print('🔄 Redirection vers /wishlist depuis _addToWishlist');
        if (mounted) {
          print('✅ Widget monté, redirection en cours...');
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          // ✅ PRIORITÉ: Utiliser le nouvel iBasket retourné par l'API
          // Sinon, utiliser _currentIBasket ou iBasket (fallback)
          final iBasketToUse = newIBasketFromApi ?? _currentIBasket ?? iBasket;
          final basketNameToUse = newBasketNameFromApi;
          
          // Construire l'URL avec iBasket et nom du basket (pour fallback si iBasket ne correspond pas)
          final queryParams = <String, String>{'refresh': timestamp.toString()};
          if (iBasketToUse != null && iBasketToUse.isNotEmpty) {
            queryParams['iBasket'] = Uri.encodeComponent(iBasketToUse);
          }
          if (basketNameToUse != null && basketNameToUse.isNotEmpty) {
            queryParams['basketName'] = Uri.encodeComponent(basketNameToUse);
          }
          
          final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
          print('🛒 Redirection avec iBasket (priorité: API > état > profil): $iBasketToUse');
          if (basketNameToUse != null) {
            print('🛒 Redirection avec nom du basket (fallback): $basketNameToUse');
          }
          context.go('/wishlist?$queryString');
        } else {
          print('❌ Widget non monté, redirection annulée');
        }
      } else if (result != null && result['error'] != null) {
        print('❌ Erreur addToWishlist: ${result['error']}');
        
        // 🔍 Vérifier si l'erreur demande la connexion
        final errorStr = result['error'].toString().toLowerCase();
        if (errorStr.contains('connect') || 
            errorStr.contains('connexion') || 
            errorStr.contains('login') ||
            errorStr.contains('email') ||
            errorStr.contains('give_email') ||
            errorStr.contains('limite') ||
            errorStr.contains('limit')) {
          print('🔒 ERREUR: Connexion requise après 5 articles !');
          _showSnackBar('Veuillez vous connecter pour ajouter plus de 5 articles au panier');
        } else {
          _showSnackBar('Erreur: ${result['error']}');
        }
      } else {
        print('❌ Réponse invalide de addToWishlist: $result');
        _showSnackBar('Erreur lors de l\'ajout à la wishlist');
      }
    } catch (e) {
      print('Erreur _addToWishlist: $e');
      _showSnackBar('Erreur lors de l\'ajout à la wishlist');
    }
  }

  /// Afficher un message snackbar
  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}