import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:animations/animations.dart';
import 'dart:collection';

import '../models/country.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/country_service.dart';
import '../config/api_config.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/qr_scanner_modal.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> 
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredProducts = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _hasSearched = false; // Nouveau flag pour savoir si une recherche a été effectuée
  
  // Gestion dynamique des pays favoris
  final CountryService _countryService = CountryService();
  List<Country> _allCountries = [];
  LinkedHashSet<String> _favoriteCountryCodes = LinkedHashSet<String>();
  bool _isLoadingCountries = true;
  
  // Controllers d'animation (style différent de home_screen)
  late AnimationController _heroController;
  late AnimationController _countryController;
  late AnimationController _searchController2; // Différent de _searchController (TextField)
  late AnimationController _resultsController;
  
  late Animation<double> _heroSlideAnimation;
  late Animation<double> _heroOpacityAnimation;

  @override
  void initState() {
    super.initState();
    try {
      _initializeAnimations();
      _initializeServices();
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
    }
  }
  
  /// Initialiser les animations avec des styles différents
  void _initializeAnimations() {
    try {
      // Hero section : Slide from top (style différent)
      _heroController = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      
      _heroSlideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _heroController,
          curve: Curves.easeOutBack, // Courbe avec rebond
        ),
      );
      
      _heroOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _heroController,
          curve: Curves.easeIn,
        ),
      );
      
      // Country section : Rotation + Scale (style unique)
      _countryController = AnimationController(
        duration: const Duration(milliseconds: 900),
        vsync: this,
      );
      
      // Search section : Bounce effect
      _searchController2 = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      // Results : Cascade animation
      _resultsController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      
      print('✅ Animations initialisées avec succès');
      
      // Démarrer les animations de manière échelonnée
      _startAnimations();
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des animations: $e');
    }
  }
  
  /// Démarrer les animations avec des délais différents
  void _startAnimations() async {
    try {
      // Attendre un frame pour s'assurer que tout est monté
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      
      _heroController.forward();
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _countryController.forward();
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _searchController2.forward();
    } catch (e) {
      print('❌ Erreur lors du démarrage des animations: $e');
    }
  }

  Future<void> _initializeServices() async {
    try {
      // L'ApiService est déjà initialisé dans app.dart via le Provider
      // Pas besoin de réappeler initialize()
      
      // Initialiser le profil utilisateur
      await _initializeProfile();
      await _loadCountryData();
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des services: $e');
    }
  }

  Future<void> _initializeProfile() async {
    try {
      // ⚠️ Le profil est déjà initialisé dans app.dart
      // Pas besoin de le réinitialiser ici
      final profileData = await LocalStorageService.getProfile();
      if (profileData != null) {
        print('✅ Profil déjà initialisé - iProfile: ${profileData['iProfile']}');
      } else {
        print('⚠️ Pas de profil trouvé dans LocalStorage');
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification du profil: $e');
    }
  }

  Future<void> _loadCountryData() async {
    try {
      final shouldShowSpinner = _allCountries.isEmpty;

      if (shouldShowSpinner && mounted) {
        setState(() {
          _isLoadingCountries = true;
        });
      }

      await _countryService.initialize();
      final rawCountries = _countryService.getAllCountries();
      final countries = _dedupeCountriesByCode(rawCountries);

      final apiService = ApiService();
      await apiService.initialize();

      final localProfile = await LocalStorageService.getProfile();
      final remoteProfile = await apiService.getProfile();

      final mergedProfile = _composeProfileData(
        base: localProfile,
        overrides: remoteProfile.isNotEmpty ? remoteProfile : null,
      );

      if (mergedProfile['iProfile']?.toString().isNotEmpty == true ||
          mergedProfile['iBasket']?.toString().isNotEmpty == true) {
        await LocalStorageService.saveProfile(mergedProfile);
      }

      final storedProfile = await LocalStorageService.getProfile();
      final favoritesRaw = storedProfile?['sPaysFav']?.toString() ?? '';
      final favorites = _buildFavoriteSet(favoritesRaw, countries);

      if (mounted) {
        setState(() {
          _allCountries = countries;
          _favoriteCountryCodes = favorites;
          _isLoadingCountries = false;
        });
      } else if (shouldShowSpinner) {
        _isLoadingCountries = false;
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des pays favoris: $e');
      if (mounted) {
        setState(() {
          _isLoadingCountries = false;
        });
      } else {
        _isLoadingCountries = false;
      }
    }
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

    if (favorites.isEmpty && availableCountries.isNotEmpty) {
      for (final country in availableCountries) {
        final code = (country.sPays ?? '').toUpperCase();
        if (code.length == 2 && availableCodes.contains(code)) {
          favorites.add(code);
        }
        if (favorites.length >= 5) {
          break;
        }
      }
    }

    return favorites;
  }

  List<String> _orderedFavoritesList(Iterable<String> favorites) {
    final normalized = favorites
        .map((code) => code.toUpperCase())
        .where((code) => code.length == 2)
        .toSet();
    final ordered = <String>[];

    for (final country in _allCountries) {
      final code = (country.sPays ?? country.code ?? '').toUpperCase();
      if (code.length == 2 && normalized.contains(code)) {
        ordered.add(code);
      }
    }

    return ordered;
  }

  Country? _findCountryByCode(String code) {
    try {
      if (code.length != 2) {
        return null;
      }
      return _allCountries.firstWhere(
        (country) =>
            ((country.sPays ?? country.code ?? '').toUpperCase()) == code.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }

  List<Country> _dedupeCountriesByCode(List<Country> countries) {
    final unique = <String, Country>{};

    for (final country in countries) {
      final code = (country.sPays ?? country.code ?? '').toUpperCase();
      if (code.length == 2 && !unique.containsKey(code)) {
        unique[code] = country;
      }
    }

    return unique.values.toList();
  }

  String _flagEmoji(String countryCode) {
    const overrides = {
      'UK': 'GB',
      'EN': 'GB',
    };

    final normalized = overrides[countryCode.toUpperCase()] ?? countryCode.toUpperCase();
    if (normalized.length != 2) {
      return '🏳️';
    }

    final codeUnits = normalized.codeUnits;
    return String.fromCharCodes([
      0x1F1E6 + codeUnits[0] - 65,
      0x1F1E6 + codeUnits[1] - 65,
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    try {
      _heroController.dispose();
      _countryController.dispose();
      _searchController2.dispose();
      _resultsController.dispose();
    } catch (e) {
      print('⚠️ Erreur lors du dispose des controllers: $e');
    }
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredProducts = [];
        _errorMessage = '';
        _hasSearched = false; // Réinitialiser le flag si la recherche est vide
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _filteredProducts = [];
      _hasSearched = true; // Marquer qu'une recherche a été effectuée
    });
    
    // Réinitialiser l'animation des résultats
    _resultsController.reset();

    // Utiliser directement l'API avec le système mobile-first
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // ApiService déjà initialisé dans app.dart
      
      // ✅ Récupérer le token depuis le LocalStorage (déjà initialisé dans app.dart)
      String? token;
      try {
        final profileData = await LocalStorageService.getProfile();
        token = profileData?['iProfile']?.toString();
        print('🔑 Profil complet récupéré: $profileData');
        print('🔑 iProfile: $token');
        
        if (token == null || token.isEmpty) {
          print('⚠️ ATTENTION: Pas de iProfile valide ! Le profil n\'est pas initialisé.');
          setState(() {
            _filteredProducts = [];
            _isLoading = false;
            _errorMessage = 'Veuillez sélectionner un pays avant de faire une recherche.';
          });
          return;
        }
      } catch (e) {
        print('⚠️ Erreur lors de la récupération du token: $e');
      }
      
      final results = await apiService.searchArticle(query, token: token, limit: 10);
      
      setState(() {
        _filteredProducts = results;
        _isLoading = false;
        if (results.isEmpty) {
          _errorMessage = 'Aucun produit trouvé pour "$query"';
        } else {
          // Démarrer l'animation des résultats
          _resultsController.forward();
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
      
      print('⚠️ Erreur backend détectée:');
      print('   errorCode: ${e.errorCode}');
      print('   message: ${e.message}');
      print('   message affiché: $errorDisplayMessage');
      
      setState(() {
        _isLoading = false;
        _filteredProducts = [];
        _errorMessage = errorDisplayMessage;
      });
    } catch (e) {
      print('❌ Erreur de recherche: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur de recherche: $e';
      });
    }
  }

  String? _getFirstImageUrl(dynamic product) {
    // Gérer le cas où aImageLink est une chaîne XML (comme dans les logs)
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
      if (imageLinks.isEmpty) return null;
      
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

  /// Mettre en surbrillance le texte de recherche (comme SNAL-Project)
  Widget _highlightMatch(String? text, String query, {bool isCode = false}) {
    if (text == null || text.isEmpty || query.isEmpty) {
      return Text(
        text ?? '',
        style: isCode
            ? const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              )
            : const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
      );
    }
    
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    if (!lowerText.contains(lowerQuery)) {
      return Text(
        text,
        style: isCode
            ? const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              )
            : const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
      );
    }
    
    final index = lowerText.indexOf(lowerQuery);
    final beforeMatch = text.substring(0, index);
    final match = text.substring(index, index + query.length);
    final afterMatch = text.substring(index + query.length);
    
    return RichText(
      text: TextSpan(
        style: isCode
            ? const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              )
            : const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
        children: [
          TextSpan(text: beforeMatch),
          TextSpan(
            text: match,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.yellow[200],
              color: Colors.black,
            ),
          ),
          TextSpan(text: afterMatch),
        ],
      ),
    );
  }

  void _selectProduct(dynamic product) {
    // Comportement comme SNAL-Project
    // 1. Mettre à jour le champ de recherche avec le code produit
    _searchController.text = product['sCodeArticle'] ?? '';
    
    // 2. Vider les résultats de recherche
    setState(() {
      _filteredProducts = [];
      _hasSearched = false;
    });
    
    // 3. Naviguer vers la page podium avec le code produit et le code crypté
    final codeArticle = product['sCodeArticle'] ?? '';
    final codeArticleCrypt = product['sCodeArticleCrypt'] ?? '';
    context.go('/podium/$codeArticle?crypt=$codeArticleCrypt');
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

    // Rechercher seulement si on a au moins 3 chiffres
    if (digitsOnly.length >= 3) {
      _searchProducts(digitsOnly);
    } else {
      setState(() {
        _filteredProducts = [];
        _errorMessage = '';
        _isLoading = false;
        _hasSearched = false; // Pas de recherche si moins de 3 chiffres
      });
    }
  }

  Future<void> _toggleCountry(String countryCode) async {
    if (_isLoadingCountries) return;

    final normalizedCode = countryCode.toUpperCase();
    if (normalizedCode.length != 2) {
      return;
    }
    final previousFavorites = LinkedHashSet<String>.from(_favoriteCountryCodes);
    final updatedFavorites = LinkedHashSet<String>.from(_favoriteCountryCodes);
    final isCurrentlySelected = updatedFavorites.contains(normalizedCode);

    if (isCurrentlySelected) {
      if (updatedFavorites.length <= 1) {
        // Toujours garder au moins un pays sélectionné
        return;
      }
      updatedFavorites.remove(normalizedCode);
    } else {
      updatedFavorites.add(normalizedCode);
    }

    final orderedFavorites = _orderedFavoritesList(updatedFavorites);
    final newFavoritesString = orderedFavorites.join(',');

    if (mounted) {
      setState(() {
        _favoriteCountryCodes = LinkedHashSet<String>.from(orderedFavorites);
      });
    }

    Map<String, dynamic>? previousProfile;
    try {
      previousProfile = await LocalStorageService.getProfile();

      final apiService = ApiService();
      final updateResponse = await apiService.updateProfile({
        'sPaysFav': newFavoritesString,
      });
      final refreshedProfile = updateResponse.isNotEmpty
          ? updateResponse
          : await apiService.getProfile();

      if (refreshedProfile.isNotEmpty) {
        final mergedProfile = _composeProfileData(
          base: previousProfile,
          overrides: refreshedProfile,
        );
        await LocalStorageService.saveProfile(mergedProfile);
      } else {
        final fallbackProfile = _composeProfileData(
          base: previousProfile,
          overrides: {
            'sPaysFav': newFavoritesString,
          },
        );
        await LocalStorageService.saveProfile(fallbackProfile);
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des pays favoris: $e');
      if (previousProfile != null) {
        await LocalStorageService.saveProfile(previousProfile);
      }
      if (mounted) {
        setState(() {
          _favoriteCountryCodes = previousFavorites;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: const CustomAppBar(),
      ),
      body: Consumer<TranslationService>(
        builder: (context, translationService, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeroSection(isMobile, translationService),
                _buildCountrySection(isMobile, translationService),
                _buildSearchSection(isMobile, translationService),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildHeroSection(bool isMobile, TranslationService translationService) {
    // Animation : Slide from top + Fade (différent de home_screen)
    return AnimatedBuilder(
      animation: _heroController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _heroSlideAnimation.value),
          child: Opacity(
            opacity: _heroOpacityAnimation.value,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0D6EFD),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24.0 : 48.0,
                  vertical: isMobile ? 20.0 : 28.0,
                ),
                child: Column(
                  children: [
                    Text(
                      translationService.translate('FRONTPAGE_Msg05'),
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildCountrySection(bool isMobile, TranslationService translationService) {
    if (_isLoadingCountries) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : 32.0,
          vertical: isMobile ? 32.0 : 48.0,
        ),
        color: const Color(0xFFFFD43B),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_allCountries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : 32.0,
          vertical: isMobile ? 24.0 : 32.0,
        ),
        color: const Color(0xFFFFD43B),
        child: Text(
          'Aucun pays disponible pour le moment',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final orderedFavorites = _orderedFavoritesList(_favoriteCountryCodes);
    var selectedCountries = orderedFavorites
        .map(_findCountryByCode)
        .whereType<Country>()
        .toList();

    if (selectedCountries.isEmpty && _allCountries.isNotEmpty) {
      selectedCountries = _allCountries.take(4).toList();
    }

    final unselectedCountries = _allCountries
        .where((country) {
          final code = (country.sPays ?? '').toUpperCase();
          return code.length == 2 && !_favoriteCountryCodes.contains(code);
        })
        .toList();

    final selectedCountryChips = selectedCountries
        .map((country) => _buildCountryChip(country, true, isMobile))
        .toList();

    final unselectedCountryChips = unselectedCountries
        .map((country) => _buildCountryChip(country, false, isMobile))
        .toList();

    // Animation : SharedAxisTransition (slide horizontal - style Material Design)
    return SharedAxisTransition(
      animation: _countryController,
      secondaryAnimation: AlwaysStoppedAnimation(0.0),
      transitionType: SharedAxisTransitionType.horizontal,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD43B),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 32.0,
            vertical: isMobile ? 16.0 : 20.0,
          ),
          child: Column(
            children: [
              Text(
                translationService.translate('FRONTPAGE_Msg04'),
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Affichage des drapeaux sans overflow
              _buildCountryGrid(
                selectedCountryChips,
                unselectedCountryChips,
                isMobile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryGrid(
    List<Widget> selectedChips,
    List<Widget> unselectedChips,
    bool isMobile,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double horizontalGap = 12.0;
        const double verticalGap = 10.0;

        final List<Widget> allChips = [...selectedChips, ...unselectedChips];
        if (allChips.isEmpty) {
          return const SizedBox.shrink();
        }

        final pattern = [4, 3];
        final rows = <Widget>[];
        int cursor = 0;
        int patternIndex = 0;

        while (cursor < allChips.length) {
          final count = pattern[patternIndex % pattern.length];
          final end = (cursor + count).clamp(0, allChips.length);
          final rowChildren = <Widget>[];

          for (int j = cursor; j < end; j++) {
            final chipIndex = j;
            rowChildren.add(
              Expanded(
                child: TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (chipIndex * 50)),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.5 + (value * 0.5),
                      child: Opacity(
                        opacity: (value.clamp(0.0, 1.0) as double),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: isMobile ? 36.0 : 40.0,
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalGap * 0.15,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: allChips[j],
                ),
              ),
            );

            if (j < end - 1) {
              rowChildren.add(SizedBox(width: horizontalGap));
            }
          }

          rows.add(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: rowChildren,
            ),
          );

          cursor = end;
          patternIndex++;

          if (cursor < allChips.length) {
            rows.add(const SizedBox(height: verticalGap));
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }

  Widget _buildCountryChip(Country country, bool isSelected, bool isMobile) {
    final countryCode = country.sPays.toUpperCase();

    return GestureDetector(
      onTap: () => _toggleCountry(countryCode),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 22 : 28,
          vertical: isMobile ? 6 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 24 : 28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _flagEmoji(countryCode),
              style: TextStyle(fontSize: isMobile ? 18 : 20),
            ),
            const SizedBox(width: 12),
            Text(
              isSelected ? '✓' : '+',
              style: TextStyle(
                fontSize: isMobile ? 15 : 17,
                color: isSelected ? const Color(0xFF0D6EFD) : Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isMobile, TranslationService translationService) {
    // Animation : Scale from bottom + Fade (effet bounce)
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(
          parent: _searchController2,
          curve: Curves.easeOutBack, // Effet bounce subtil
        ),
      ),
      child: FadeTransition(
        opacity: _searchController2,
        child: Container(
          margin: EdgeInsets.only(
            left: isMobile ? 16.0 : 32.0,
            right: isMobile ? 16.0 : 32.0,
            top: 8.0,
            bottom: 24.0,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
            child: Column(
              children: [
                // Bouton Scanner avec animation au clic
                SizedBox(
                  width: double.infinity,
                  child: OpenContainer(
                    transitionType: ContainerTransitionType.fade,
                    transitionDuration: const Duration(milliseconds: 400),
                    openBuilder: (context, action) {
                      return const QrScannerModal();
                    },
                    closedElevation: 2,
                    closedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    closedColor: const Color(0xFF0D6EFD),
                    closedBuilder: (context, action) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 16 : 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner, size: 24, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              translationService.translate('FRONTPAGE_Msg08'),
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Champ de recherche
                _buildSearchInput(isMobile, translationService),
                
                const SizedBox(height: 16),
                
                // Affichage des résultats ou état initial avec animation
                if (_hasSearched) ...[
                  if (_isLoading)
                    _buildLoadingState(isMobile)
                  else if (_errorMessage.isNotEmpty)
                    _buildErrorState()
                  else if (_filteredProducts.isNotEmpty)
                    _buildSearchResults(isMobile)
                  else
                    _buildNoResultsState(),
                ] else ...[
                  // État initial - message pour commencer la recherche
                  _buildInitialState(isMobile, translationService),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput(bool isMobile, TranslationService translationService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onInputCode,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: translationService.translate('PRODUCTSEARCH_HINT_CODE'),
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _isLoading
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(12),
                  child: LoadingAnimationWidget.progressiveDots(
                    color: Colors.blue,
                    size: 20,
                  ),
                )
              : _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _filteredProducts = [];
                          _errorMessage = '';
                          _hasSearched = false;
                        });
                      },
                    )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Container(
      color: Colors.white, // Page entièrement blanche
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingAnimationWidget.progressiveDots(
              color: Colors.blue,
              size: 60,
            ),
            const SizedBox(height: 24),
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
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de recherche',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(bool isMobile, TranslationService translationService) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            translationService.translate('PRODUCTSEARCH_ENTER_CODE'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun produit trouvé pour "${_searchController.text.trim()}"',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Vérifiez le code produit ou essayez une recherche différente',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isMobile) {
    // Animation : FadeThroughTransition pour l'apparition des résultats
    return FadeThroughTransition(
      animation: _resultsController,
      secondaryAnimation: AlwaysStoppedAnimation(0.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // En-tête des résultats (style SNAL-Project)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredProducts.length} résultat${_filteredProducts.length > 1 ? 's' : ''} trouvé${_filteredProducts.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            
            // Liste des produits avec animation en cascade
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredProducts.length,
              separatorBuilder: (context, index) => Container(
                height: 0,
                color: Colors.transparent,
              ),
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                
                // Animation en cascade pour chaque résultat (comme une vague)
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 400 + (index * 100)), // Délai progressif
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(30 * (1 - value), 0), // Slide depuis la droite
                      child: Opacity(
                        opacity: value,
                        child: _buildProductItem(product, isMobile),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(dynamic product, bool isMobile) {
    final imageUrl = _getFirstImageUrl(product);
    final isAvailable = product['bAvailable'] == 1;
    final isValidProduct = product['sName'] != 'Item not found' && 
                          product['sName'] != 'No Description';
    
    // Animation au clic : OpenContainer avec transition élégante
    return Opacity(
      opacity: isAvailable && isValidProduct ? 1.0 : 0.5, // Griser si indisponible
      child: IgnorePointer(
        ignoring: !(isAvailable && isValidProduct), // Désactiver les clics si indisponible/invalide
        child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 500),
        openBuilder: (context, action) {
          // Navigation vers le podium
          final codeArticle = product['sCodeArticle'] ?? '';
          final codeArticleCrypt = product['sCodeArticleCrypt'] ?? '';
          Future.delayed(Duration.zero, () {
            if (context.mounted) {
              context.go('/podium/$codeArticle?crypt=$codeArticleCrypt');
            }
          });
          return const SizedBox();
        },
        closedElevation: 0,
        closedColor: isAvailable && isValidProduct ? Colors.white : Colors.grey[100]!,
        closedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        closedBuilder: (context, action) {
          return Container(
            decoration: BoxDecoration(
              color: isAvailable && isValidProduct ? Colors.white : Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[100]!,
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Image (comme SNAL-Project - 64x64)
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[100],
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey[400],
                                        size: 32,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[100],
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      // Badge "Indisponible" sur l'image
                      if (!isAvailable || !isValidProduct)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Indisponible',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                
                const SizedBox(width: 16),
                
                // Section Contenu (comme SNAL-Project)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Code produit + Nom (comme SNAL-Project)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _highlightMatch(
                              product['sCodeArticle'] ?? '',
                              _searchController.text.trim(),
                              isCode: true,
                            ),
                          ),
                          if (!isValidProduct)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[300]!),
                              ),
                              child: Text(
                                'Non disponible',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Text(
                              product['sName'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 14,
                                color: (isAvailable && isValidProduct) ? Colors.grey[500] : Colors.grey[600],
                                decoration: (isAvailable && isValidProduct) ? TextDecoration.none : TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Description (comme SNAL-Project)
                      if (product['sDescr'] != null && 
                          product['sDescr'].toString().isNotEmpty &&
                          product['sDescr'] != 'No description (Indisponible)')
                        _highlightMatch(
                          product['sDescr'],
                          _searchController.text.trim(),
                        ),
                      
                      const SizedBox(height: 4),
                      
                      // Prix (comme SNAL-Project)
                      if (product['iPrice'] != null && 
                          product['iPrice'].toString().isNotEmpty)
                        Text(
                          '${product['iPrice']}${product['sCurrency'] ?? ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ], // Ferme children du Row
            ), // Ferme Row
          ), // Ferme Padding
        ); // Ferme Container et return du closedBuilder
        }, // Ferme closedBuilder
      ), // Ferme OpenContainer
      ),
    ); // Ferme Opacity et return de _buildProductItem
  }
}