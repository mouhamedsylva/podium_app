import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/country_service.dart';
import '../services/translation_service.dart';
import '../services/local_storage_service.dart';
import '../models/country.dart';
import '../config/api_config.dart';
import 'qr_scanner_modal.dart';

class SearchModal extends StatefulWidget {
  const SearchModal({Key? key}) : super(key: key);

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedCountries = [];
  LinkedHashSet<String> _favoriteCountryCodes = LinkedHashSet<String>();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _errorMessage = '';
  bool _hasSearched = false;
  
  // Gestion du profil utilisateur et du token
  String? _userToken;
  String? _userBasket;
  
  // Liste des pays disponibles (chargée dynamiquement)
  List<Country> _availableCountries = [];
  bool _isLoadingCountries = true;
  
  // Map des drapeaux emoji
  final Map<String, String> _countryFlags = {
    'BE': '🇧🇪',
    'DE': '🇩🇪',
    'ES': '🇪🇸',
    'FR': '🇫🇷',
    'IT': '🇮🇹',
    'NL': '🇳🇱',
    'PT': '🇵🇹',
    'LU': '🇱🇺',
    'EN': '🇬🇧',
  };

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideController.forward();
    _fadeController.forward();
    
    // Initialiser les services et charger les données
    _initializeServices();
  }

  /// Initialiser les services API et charger les pays
  Future<void> _initializeServices() async {
    try {
      // 1. Initialiser l'API service
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.initialize();
      
      // 2. Initialiser le profil utilisateur pour obtenir un token
      await _initializeProfile();
      
      // 3. Charger les pays disponibles
      await _loadCountries();
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des services: $e');
      setState(() {
        _isLoadingCountries = false;
      });
    }
  }

  /// Récupérer le token utilisateur depuis LocalStorage (déjà initialisé dans app.dart)
  Future<void> _initializeProfile() async {
    try {
      // ✅ Récupérer le profil depuis LocalStorage (déjà initialisé dans app.dart)
      final profileData = await LocalStorageService.getProfile();
      setState(() {
        _userToken = profileData?['iProfile']?.toString();
        _userBasket = profileData?['iBasket']?.toString();
      });
      print('✅ Token récupéré depuis LocalStorage: ${_userToken != null ? "✅" : "❌"}');
    } catch (e) {
      print('❌ Erreur lors de la récupération du profil: $e');
    }
  }

  /// Charger les pays disponibles depuis l'API
  Future<void> _loadCountries() async {
    try {
      final countryService = CountryService();
      await countryService.initialize();
      
      final countries = countryService.getAllCountries();
      final favorites = await _loadFavoritesFromProfile(countries);
      final orderedSelected = _orderedFavoritesList(favorites, countries);

      setState(() {
        _availableCountries = countries;
        _favoriteCountryCodes = favorites;
        _selectedCountries = orderedSelected;
        _isLoadingCountries = false;
      });
      
      print('✅ ${countries.length} pays chargés depuis l\'API');
    } catch (e) {
      print('❌ Erreur lors du chargement des pays: $e');
      setState(() {
        _isLoadingCountries = false;
      });
    }
  }

  Future<LinkedHashSet<String>> _loadFavoritesFromProfile(List<Country> countries) async {
    try {
      final profile = await LocalStorageService.getProfile();
      final favoritesRaw = profile?['sPaysFav']?.toString() ?? '';
      final favorites = _buildFavoriteSet(favoritesRaw, countries);
      if (favorites.isNotEmpty) {
        return favorites;
      }
    } catch (e) {
      print('⚠️ Erreur _loadFavoritesFromProfile: $e');
    }
    return _buildDefaultFavoriteSet(countries);
  }

  LinkedHashSet<String> _buildFavoriteSet(String favoritesRaw, List<Country> availableCountries) {
    final availableCodes = availableCountries
        .map((country) => (country.sPays ?? '').toUpperCase())
        .where((code) => code.length == 2)
        .toSet();

    final favorites = LinkedHashSet<String>();

    var sanitizedFavoritesRaw = favoritesRaw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '');

    if (sanitizedFavoritesRaw.isNotEmpty) {
      for (final part in sanitizedFavoritesRaw.split(',')) {
        final code = part.trim().toUpperCase();
        if (code.length == 2 && availableCodes.contains(code)) {
          favorites.add(code);
        }
      }
    }

    if (favorites.isEmpty) {
      return _buildDefaultFavoriteSet(availableCountries);
    }

    return favorites;
  }

  LinkedHashSet<String> _buildDefaultFavoriteSet(List<Country> availableCountries) {
    final defaults = LinkedHashSet<String>();
    for (final country in availableCountries) {
      final code = (country.sPays ?? '').toUpperCase();
      if (code.length == 2) {
        defaults.add(code);
      }
      if (defaults.length >= 5) break;
    }
    if (defaults.isEmpty) {
      defaults.addAll(['FR', 'BE', 'DE', 'NL', 'ES']);
    }
    return defaults;
  }

  List<String> _orderedFavoritesList(Iterable<String> favorites, List<Country> countries) {
    final normalized = favorites
        .map((code) => code.toUpperCase())
        .where((code) => code.length == 2)
        .toSet();
    final ordered = <String>[];

    for (final country in countries) {
      final code = (country.sPays ?? country.code ?? '').toUpperCase();
      if (code.length == 2 && normalized.contains(code)) {
        ordered.add(code);
      }
    }

    for (final code in normalized) {
      if (!ordered.contains(code)) {
        ordered.add(code);
      }
    }

    return ordered;
  }

  Map<String, dynamic> _composeProfileData({
    Map<String, dynamic>? base,
    Map<String, dynamic>? overrides,
  }) {
    String normalizeValue(dynamic value) {
      if (value == null) return '';
      if (value is Iterable) {
        final joined = value
            .map((item) => (item ?? '').toString().trim())
            .where((item) => item.isNotEmpty)
            .join(',');
        return joined;
      }
      final stringValue = value.toString();
      return stringValue.trim();
    }

    String pick(String key) {
      final overrideValue = overrides?[key];
      final normalizedOverride = normalizeValue(overrideValue);
      if (normalizedOverride.isNotEmpty) {
        return normalizedOverride;
      }

      final baseValue = base?[key];
      final normalizedBase = normalizeValue(baseValue);
      if (normalizedBase.isNotEmpty) {
        return normalizedBase;
      }
      return '';
    }

    final result = <String, dynamic>{
      'iProfile': pick('iProfile'),
      'iBasket': pick('iBasket'),
      'sPaysFav': pick('sPaysFav'),
      'sPaysLangue': pick('sPaysLangue'),
      'sEmail': pick('sEmail'),
      'sNom': pick('sNom'),
      'sPrenom': pick('sPrenom'),
      'sPhoto': pick('sPhoto'),
      'sTel': pick('sTel'),
      'sRue': pick('sRue'),
      'sZip': pick('sZip'),
      'sCity': pick('sCity'),
    };

    final token = overrides?['token'] ?? base?['token'];
    if (token != null) {
      result['token'] = token.toString();
    }

    return result;
  }

  @override
  void dispose() {
    try {
      // Arrêter les animations avant de les disposer
      if (_slideController.isAnimating) {
        _slideController.stop();
      }
      if (_fadeController.isAnimating) {
        _fadeController.stop();
      }
      _slideController.dispose();
      _fadeController.dispose();
      _searchController.dispose();
    } catch (e) {
      print('Erreur lors du dispose de SearchModal: $e');
    }
    super.dispose();
  }

  Future<void> _closeModal() async {
    try {
      if (mounted && _slideController.isAnimating == false) {
        await _slideController.reverse();
      }
      if (mounted && _fadeController.isAnimating == false) {
        await _fadeController.reverse();
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Erreur lors de la fermeture du modal: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _toggleCountry(String country) async {
    final normalizedCode = country.toUpperCase();
    if (normalizedCode.length != 2) {
      return;
    }

    final previousFavorites = LinkedHashSet<String>.from(_favoriteCountryCodes);
    final updatedFavorites = LinkedHashSet<String>.from(_favoriteCountryCodes);
    final isSelected = updatedFavorites.contains(normalizedCode);

    if (isSelected) {
      if (updatedFavorites.length <= 1) {
        return;
      }
      updatedFavorites.remove(normalizedCode);
    } else {
      updatedFavorites.add(normalizedCode);
    }

    final orderedFavorites = _orderedFavoritesList(updatedFavorites, _availableCountries);
    final newFavoritesString = orderedFavorites.join(',');

    if (mounted) {
      setState(() {
        _favoriteCountryCodes = updatedFavorites;
        _selectedCountries = orderedFavorites;
      });
    }

    Map<String, dynamic>? previousProfile;
    try {
      previousProfile = await LocalStorageService.getProfile();
      final updatedProfile = _composeProfileData(
        base: previousProfile,
        overrides: {
          'sPaysFav': newFavoritesString,
        },
      );

      await LocalStorageService.saveProfile(updatedProfile);

      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateProfile({
        'sPaysFav': newFavoritesString,
        'sPaysFavList': orderedFavorites,
      });
    } catch (e) {
      print('❌ Erreur _toggleCountry: $e');
      if (previousProfile != null) {
        await LocalStorageService.saveProfile(previousProfile);
      }
      if (mounted) {
        setState(() {
          _favoriteCountryCodes = previousFavorites;
          _selectedCountries = _orderedFavoritesList(previousFavorites, _availableCountries);
        });
      }
    }
  }

  void _onInputCode(String value) {
    String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length > 9) {
      digitsOnly = digitsOnly.substring(0, 9);
    }

    String formatted = '';
    if (digitsOnly.length > 6) {
      formatted = '${digitsOnly.substring(0, 3)}.${digitsOnly.substring(3, 6)}.${digitsOnly.substring(6)}';
    } else if (digitsOnly.length > 3) {
      formatted = '${digitsOnly.substring(0, 3)}.${digitsOnly.substring(3)}';
    } else {
      formatted = digitsOnly;
    }

    if (_searchController.text != formatted) {
      _searchController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.fromPosition(
          TextPosition(offset: formatted.length),
        ),
      );
    }

    if (digitsOnly.length >= 3) {
      _searchProduct(digitsOnly);
    } else {
      setState(() {
        _searchResults = [];
        _errorMessage = '';
        _isSearching = false;
        _hasSearched = false;
      });
    }
  }

  Future<void> _searchProduct(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = '';
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = '';
      _searchResults = [];
      _hasSearched = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.initialize();
      
      // Utiliser le token si disponible (comme dans product_search_screen)
      final results = await apiService.searchArticle(
        query.trim(),
        token: _userToken ?? '',
        limit: 10,
      );
      
      setState(() {
        _searchResults = results.cast<Map<String, dynamic>>();
        _isSearching = false;
        if (results.length == 0) {
          _errorMessage = 'Aucun produit trouvé pour "$query"';
        }
        
        // Debug: Afficher les champs disponibles dans les résultats
        if (results.isNotEmpty) {
          print('🔍 DEBUG - Premier résultat de recherche:');
          final firstResult = results.first as Map<String, dynamic>;
          print('📋 Champs disponibles: ${firstResult.keys.toList()}');
          print('📝 sDescr: "${firstResult['sDescr']}"');
          print('📝 sName: "${firstResult['sName']}"');
          print('📝 sCodeArticle: "${firstResult['sCodeArticle']}"');
        }
      });
    } on SearchArticleException catch (e) {
      // ✅ Gérer les erreurs spécifiques du backend avec success, error, message
      final translationService = Provider.of<TranslationService>(context, listen: false);
      
      // ✅ Utiliser la traduction pour le code d'erreur ou le message du backend
      String errorDisplayMessage;
      if (e.errorCode.isNotEmpty) {
        // Essayer de traduire le code d'erreur (ex: HTML_SEARCH_BADREFERENCE)
        final translatedError = translationService.translate(e.errorCode);
        // Si la traduction existe (pas le même texte que la clé), l'utiliser
        errorDisplayMessage = (translatedError != e.errorCode) 
            ? translatedError 
            : (e.message.isNotEmpty ? e.message : e.errorCode);
      } else {
        errorDisplayMessage = e.message.isNotEmpty ? e.message : 'Erreur de recherche';
      }
      
      // ✅ Convertir les balises HTML <br> en sauts de ligne \n
      errorDisplayMessage = errorDisplayMessage.replaceAll('<br>', '\n').replaceAll('<br/>', '\n').replaceAll('<br />', '\n');
      
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _errorMessage = errorDisplayMessage;
      });
      
      print('⚠️ Erreur backend détectée:');
      print('   errorCode: ${e.errorCode}');
      print('   message: ${e.message}');
      print('   message affiché: $errorDisplayMessage');
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Erreur de recherche: $e';
      });
    }
  }

  void _selectProduct(Map<String, dynamic> product) async {
    final codeArticle = product['sCodeArticle'] ?? '';
    final codeArticleCrypt = product['sCodeArticleCrypt'] ?? '';
    
    // Fermer le modal d'abord
    await _closeModal();
    
    // Attendre que le modal soit complètement fermé
    if (!mounted) return;
    
    // Utiliser replace pour remplacer la route actuelle et forcer le rechargement
    // Cela va déclencher initState dans PodiumScreen avec les nouvelles données
    context.replace('/podium/$codeArticle?crypt=$codeArticleCrypt');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallMobile = screenWidth < 361;   // Galaxy Fold fermé, Galaxy S8+ (≤360px)
    final isSmallMobile = screenWidth < 431;       // iPhone XR/14 Pro Max, Pixel 7, Galaxy S20/A51 (361-430px)
    final isMobile = screenWidth < 768;            // Tous les mobiles standards (431-767px)
    
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.black.withOpacity(0.6 * _fadeAnimation.value),
            child: GestureDetector(
              onTap: _closeModal,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: GestureDetector(
                          onTap: () {}, // Empêche la fermeture au tap sur le contenu
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: screenHeight * 0.92,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF8DC), // ✅ Jaune clair moutarde
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: _buildModalContent(isVerySmallMobile, isSmallMobile, isMobile),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalContent(bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle (réduit)
        Container(
          margin: EdgeInsets.only(
            top: isVerySmallMobile ? 4 : (isSmallMobile ? 5 : 6),
            bottom: isVerySmallMobile ? 4 : (isSmallMobile ? 5 : 6),
          ),
          width: isVerySmallMobile ? 35 : 40,
          height: isVerySmallMobile ? 3 : 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Positionner le bouton de fermeture en overlay sur la section jaune
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Section des pays en haut avec formes en pillules (pleine largeur)
                    _buildCountrySection(isVerySmallMobile, isSmallMobile, isMobile),
                
                // Padding pour le reste du contenu
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
                    isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                    isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  
                  // Titre "Rechercher un article" (centré et bleu)
                  SizedBox(
                    width: double.infinity, // ✅ Prend toute la largeur pour centrer
                    child: Consumer<TranslationService>(
                      builder: (context, translationService, child) {
                        return Text(
                          translationService.translate('FRONTPAGE_Msg05'),
                          textAlign: TextAlign.center, // ✅ Centré
                          style: TextStyle(
                            fontSize: isVerySmallMobile ? 18 : (isSmallMobile ? 20 : 22),
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8), // ✅ Bleu plus sombre
                            letterSpacing: -0.5,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20)),
                  
                  // Bouton Scanner (placé juste après le titre)
                  _buildScanButton(isVerySmallMobile, isSmallMobile, isMobile),
                  
                  SizedBox(height: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24)),
                  
                  // Champ de recherche moderne
                  _buildSearchField(isVerySmallMobile, isSmallMobile, isMobile),
                  
                  SizedBox(height: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24)),
                  
                  // Résultats ou états vides avec fond blanc pendant la recherche
                  Container(
                    color: _isSearching ? Colors.white : Colors.transparent,
                    child: _isSearching
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                children: [
                                  LoadingAnimationWidget.progressiveDots(
                                    color: Colors.blue,
                                    size: 50,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Recherche en cours...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildSearchResults(),
                  ),
                    ],
                  ),
                ),
              ],
            ),
          ),
              // Bouton de fermeture en overlay en haut à droite
              Positioned(
                top: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12),
                right: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
                child: GestureDetector(
                  onTap: _closeModal,
                  child: Container(
                    width: isVerySmallMobile ? 32 : (isSmallMobile ? 34 : 36),
                    height: isVerySmallMobile ? 32 : (isSmallMobile ? 34 : 36),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF666666),
                      size: isVerySmallMobile ? 18 : (isSmallMobile ? 19 : 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton(bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    final translationService = Provider.of<TranslationService>(context, listen: false);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Fermer ce modal puis ouvrir le modal scanner avec animation Fade+Scale
            await _closeModal();
            if (!mounted) return;
            showModal(
              context: context,
              configuration: const FadeScaleTransitionConfiguration(
                transitionDuration: Duration(milliseconds: 280),
                reverseTransitionDuration: Duration(milliseconds: 220),
                barrierDismissible: true,
              ),
              builder: (context) => const QrScannerModal(),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isVerySmallMobile ? 14 : (isSmallMobile ? 16 : 18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                ),
                SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                Text(
                  translationService.translate('FRONTPAGE_Msg08'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white, // ✅ Fond blanc
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchController.text.isNotEmpty 
                  ? const Color(0xFF2563EB) 
                  : Colors.grey[200]!,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onInputCode,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              hintText: translationService.translate('PRODUCTSEARCH_HINT_CODE'), // ✅ Utilise la clé de traduction
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                fontWeight: FontWeight.normal,
              ),
          prefixIcon: Icon(
            Icons.search,
            color: _searchController.text.isNotEmpty 
                ? const Color(0xFF2563EB) 
                : Colors.grey[400],
            size: isVerySmallMobile ? 20 : (isSmallMobile ? 21 : 22),
          ),
          suffixIcon: _isSearching
              ? Padding(
                  padding: EdgeInsets.all(isVerySmallMobile ? 12 : (isSmallMobile ? 13 : 14)),
                  child: SizedBox(
                    width: isVerySmallMobile ? 18 : 20,
                    height: isVerySmallMobile ? 18 : 20,
                    child: LoadingAnimationWidget.progressiveDots(
                      color: Colors.blue,
                      size: isVerySmallMobile ? 18 : 20,
                    ),
                  ),
                )
              : _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: isVerySmallMobile ? 18 : (isSmallMobile ? 19 : 20),
                      ),
                      padding: EdgeInsets.all(isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                      constraints: BoxConstraints(
                        minWidth: isVerySmallMobile ? 36 : (isSmallMobile ? 38 : 40),
                        minHeight: isVerySmallMobile ? 36 : (isSmallMobile ? 38 : 40),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _errorMessage = '';
                          _hasSearched = false;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                horizontal: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountrySection(bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    final translationService = Provider.of<TranslationService>(context, listen: false);

    final processedCountryCodes = <String>{};
    final selectedCountryChips = <Widget>[];
    final unselectedCountryChips = <Widget>[];
    final selectedCodes = _orderedFavoritesList(_favoriteCountryCodes, _availableCountries);

    if (_availableCountries.isEmpty) {
      final fallbackCodes = selectedCodes.isNotEmpty
          ? selectedCodes
          : ['FR', 'BE', 'DE', 'NL', 'ES', 'IT', 'PT'];

      for (final code in fallbackCodes) {
        final normalized = code.toUpperCase();
        if (processedCountryCodes.contains(normalized)) continue;
        processedCountryCodes.add(normalized);

        final isSelected = _favoriteCountryCodes.contains(normalized);
        (isSelected ? selectedCountryChips : unselectedCountryChips)
            .add(_buildCountryChip(normalized, isSelected, isVerySmallMobile, isSmallMobile, isMobile));
      }
    } else {
      for (final code in selectedCodes) {
        final normalized = code.toUpperCase();
        if (processedCountryCodes.contains(normalized)) continue;
        processedCountryCodes.add(normalized);
        selectedCountryChips.add(
          _buildCountryChip(normalized, true, isVerySmallMobile, isSmallMobile, isMobile),
        );
      }

      for (final country in _availableCountries) {
        final countryCode = (country.sPays ?? '').toUpperCase();
        if (countryCode.length != 2 || processedCountryCodes.contains(countryCode)) continue;
        processedCountryCodes.add(countryCode);
        final isSelected = _favoriteCountryCodes.contains(countryCode);
        (isSelected ? selectedCountryChips : unselectedCountryChips)
            .add(_buildCountryChip(countryCode, isSelected, isVerySmallMobile, isSmallMobile, isMobile));
      }
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFFD43B),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
          right: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
          top: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12),
          bottom: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
        ),
        child: Column(
          children: [
            Text(
              translationService.translate('FRONTPAGE_Msg04'),
              style: TextStyle(
                fontSize: isVerySmallMobile ? 16 : (isSmallMobile ? 18 : 20),
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _isLoadingCountries
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: LoadingAnimationWidget.progressiveDots(
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ),
                  )
                : _buildCountryGrid(selectedCountryChips, unselectedCountryChips, isMobile),
          ],
        ),
      ),
    );
  }

  /// Créer un chip de pays avec le style de product_search_screen (allongé)
  Widget _buildCountryChip(String countryCode, bool isSelected, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    // ✅ Allonger les pillules de manière responsive (valeur augmentée)
    // Pour très petit mobile: horizontal 24, vertical 6
    // Pour petit mobile: horizontal 26, vertical 7
    // Pour mobile: horizontal 28, vertical 8
    // Pour desktop: horizontal 32, vertical 8
    final double horizontalPadding = isVerySmallMobile ? 24.0 : (isSmallMobile ? 26.0 : (isMobile ? 28.0 : 32.0));
    final double verticalPadding = isVerySmallMobile ? 6.0 : (isSmallMobile ? 7.0 : 8.0);
    
    return GestureDetector(
      onTap: () => _toggleCountry(countryCode),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white, // ✅ Même couleur que product_search_screen
          borderRadius: BorderRadius.circular(15), // ✅ Même borderRadius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // ✅ Même ombre
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _countryFlags[countryCode] ?? '🏳️',
              style: TextStyle(fontSize: isMobile ? 16 : 18), // ✅ Même taille que product_search_screen
            ),
            SizedBox(width: isVerySmallMobile ? 14 : (isSmallMobile ? 16 : 18)), // ✅ Plus d'espace entre drapeau et symbole
            Text(
              isSelected ? '✓' : '+', // ✅ Même symbole que product_search_screen
              style: TextStyle(
                fontSize: isMobile ? 14 : 16, // ✅ Même taille que product_search_screen
                color: isSelected ? const Color(0xFF0D6EFD) : Colors.grey[500], // ✅ Même couleur
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grille avec 4 pays en haut et 3 en bas (comme product_search_screen)
  Widget _buildCountryGrid(
    List<Widget> selectedChips,
    List<Widget> unselectedChips,
    bool isMobile,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double horizontalGap = 8.0;
        const double verticalGap = 8.0;

        final List<Widget> allChips = [...selectedChips, ...unselectedChips];
        final int columns = isMobile ? 4 : 6;
        int cursor = 0;
        final List<Widget> rows = [];

        while (cursor < allChips.length) {
          final remaining = allChips.length - cursor;
          final count = remaining < columns ? remaining : columns;
          final double chipWidth = (constraints.maxWidth - horizontalGap * (columns - 1)) / columns;
          final double totalWidth = count * chipWidth + (count - 1) * horizontalGap;

          final List<Widget> rowChildren = [];
          for (int i = 0; i < count; i++) {
            final chipIndex = cursor + i;
            rowChildren.add(
              SizedBox(
                width: chipWidth,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: allChips[chipIndex],
                    ),
                  ),
                ),
              ),
            );
            if (i < count - 1) {
              rowChildren.add(const SizedBox(width: horizontalGap));
            }
          }

          rows.add(
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: totalWidth,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: rowChildren,
                ),
              ),
            ),
          );

          cursor += count;
          if (cursor < allChips.length) {
            rows.add(const SizedBox(height: verticalGap));
          }
        }

        return Column(children: rows);
      },
    );
  }

  Widget _buildSearchResults() {
    if (!_hasSearched && _searchResults.length == 0 && _errorMessage.isEmpty) {
      return _buildEmptyState();
    }
    
    if (_searchResults.length > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_searchResults.length} résultat${_searchResults.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          ..._searchResults.map((product) => _buildProductCard(product)).toList(),
        ],
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }
    
    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                Icons.search,
                size: 56, // ✅ Agrandie
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                translationService.translate('PRODUCTSEARCH_ENTER_CODE'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 12),
          Text(
            'Erreur de recherche',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    // Vérifier si le produit est disponible
    final isAvailable = product['bAvailable'] == true || 
                       product['bAvailable'] == 1 || 
                       product['bAvailable'] == '1' ||
                       product['bAvailable'] == null; // Par défaut disponible si non spécifié
    
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5, // Griser si indisponible
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isAvailable ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isAvailable ? Colors.grey[200]! : Colors.grey[300]!),
          boxShadow: isAvailable ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isAvailable ? () => _selectProduct(product) : null, // Désactiver le clic si indisponible
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Image du produit
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: _getProductImage(product),
                      ),
                      // Badge "Indisponible" si nécessaire
                      if (!isAvailable)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Indisponible',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: 14),
                  
                  // Informations
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['sDescr'] ?? product['sName'] ?? product['sTitle'] ?? product['sProductName'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Color(0xFF1A1A1A) : Colors.grey[600],
                            letterSpacing: -0.2,
                            decoration: isAvailable ? TextDecoration.none : TextDecoration.lineThrough,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product['sCodeArticle'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                        if (product['iPrice'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${product['iPrice']} ${product['sCurrency'] ?? '€'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isAvailable ? Color(0xFF1A1A1A) : Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  if (isAvailable)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getProductImage(Map<String, dynamic> product) {
    final imageUrl = _getFirstImageUrl(product);
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: 72,
          height: 72,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Erreur de chargement image: $error');
            return _buildDefaultImage();
          },
        ),
      );
    }
    
    return _buildDefaultImage();
  }

  /// Extraire l'URL de la première image valide (comme dans product_search_screen)
  String? _getFirstImageUrl(Map<String, dynamic> product) {
    if (product['aImageLink'] == null) {
      return null;
    }

    // Si c'est une chaîne XML, essayer d'extraire l'URL
    if (product['aImageLink'] is String) {
      final xmlString = product['aImageLink'] as String;
      final regex = RegExp(r'<sHyperlink>(.*?)<\/sHyperlink>', caseSensitive: false);
      final match = regex.firstMatch(xmlString);
      if (match != null) {
        final url = match.group(1) ?? '';
        if (url.isNotEmpty && !url.toLowerCase().contains('no_image')) {
          // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
          return ApiConfig.getProxiedImageUrl(url);
        }
      }
      return null;
    }

    // Si c'est une liste, chercher la première image valide
    if (product['aImageLink'] is List) {
      final imageLinks = product['aImageLink'] as List;
      if (imageLinks.length == 0) return null;
      
      for (var link in imageLinks) {
        if (link is Map && link['sHyperlink'] != null) {
          final hyperlink = link['sHyperlink'] as String;
          if (hyperlink.isNotEmpty && 
              !hyperlink.toLowerCase().contains('no_image') &&
              (hyperlink.toLowerCase().contains('.jpg') ||
               hyperlink.toLowerCase().contains('.jpeg') ||
               hyperlink.toLowerCase().contains('.png') ||
               hyperlink.toLowerCase().contains('.webp'))) {
            // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
            return ApiConfig.getProxiedImageUrl(hyperlink);
          }
        } else if (link is String && link.isNotEmpty) {
          if (!link.toLowerCase().contains('no_image')) {
            // Mobile-First: Utilise automatiquement le proxy en Web, URL directe en mobile
            return ApiConfig.getProxiedImageUrl(link);
          }
        }
      }
    }

    return null;
  }

  Widget _buildDefaultImage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Colors.grey[400],
      ),
    );
  }
}