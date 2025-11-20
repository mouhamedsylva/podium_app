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
  bool _hasExplicitlyDeselectedAll = false; // Flag pour indiquer qu'on a explicitement tout décoché
  
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

      // ✅ CRITIQUE: Charger d'abord le profil local (source de vérité)
      final localProfile = await LocalStorageService.getProfile();
      final localPaysFav = localProfile?['sPaysFav']?.toString() ?? '';
      
      // ✅ Ne charger le profil distant QUE si le profil local n'a pas de sPaysFav
      // (comme SNAL qui charge depuis l'API uniquement au onMounted, pas à chaque navigation)
      // ⚠️ Si localPaysFav est une chaîne vide explicite (''), on ne charge PAS depuis la BDD
      // car cela signifie que l'utilisateur a tout décoché et on veut restaurer depuis sPaysLangue
      // ⚠️ Si _hasExplicitlyDeselectedAll est true, on ne charge PAS depuis la BDD non plus
      Map<String, dynamic>? mergedProfile = localProfile;
      if (_hasExplicitlyDeselectedAll) {
        print('✅ Désélection explicite détectée - Ne pas charger depuis la BDD');
        // Réinitialiser le flag après utilisation
        _hasExplicitlyDeselectedAll = false;
      } else if (localPaysFav.isEmpty && localProfile?['sPaysFav'] != '') {
        // localPaysFav est null/undefined, pas une chaîne vide explicite
        print('📡 Profil local sans sPaysFav - Chargement depuis l\'API...');
        final remoteProfile = await apiService.getProfile();
        
        if (remoteProfile.isNotEmpty) {
          mergedProfile = _composeProfileData(
            base: localProfile,
            overrides: remoteProfile,
          );
          
          // ✅ Sauvegarder le profil mergé uniquement si on a récupéré des données
          if (mergedProfile['iProfile']?.toString().isNotEmpty == true ||
              mergedProfile['iBasket']?.toString().isNotEmpty == true) {
            await LocalStorageService.saveProfile(mergedProfile);
          }
        }
      } else if (localPaysFav.isEmpty && localProfile?['sPaysFav'] == '') {
        print('✅ Profil local avec sPaysFav vide (tout décoché) - Ne pas charger depuis la BDD');
      } else {
        print('✅ Utilisation du profil local (sPaysFav: $localPaysFav)');
      }

      // ✅ Utiliser le profil mergé ou local pour récupérer sPaysFav
      final storedProfile = mergedProfile ?? await LocalStorageService.getProfile();
      var favoritesRaw = storedProfile?['sPaysFav']?.toString() ?? '';
      
      // ✅ CRITIQUE: Si sPaysFav est vide (même après avoir chargé depuis la BDD),
      // restaurer UNIQUEMENT le pays de sPaysLangue (country_selection)
      // (comme SNAL qui restaure le pays choisi dans country_selection au retour sur la page)
      // ⚠️ NE PAS restaurer si _hasExplicitlyDeselectedAll est true (on vient de tout décocher)
      if (!_hasExplicitlyDeselectedAll && (favoritesRaw.isEmpty || favoritesRaw.trim().isEmpty)) {
        final sPaysLangue = storedProfile?['sPaysLangue']?.toString() ?? '';
        if (sPaysLangue.isNotEmpty) {
          // sPaysLangue est au format "BE/FR" ou "FR/FR" - extraire les 2 premiers caractères
          final countryCodeFromLangue = sPaysLangue.split('/').first.toUpperCase();
          if (countryCodeFromLangue.length == 2) {
            // Vérifier que ce code pays existe dans la liste des pays disponibles
            final countryExists = countries.any((country) => 
              (country.sPays ?? country.code ?? '').toUpperCase() == countryCodeFromLangue
            );
            if (countryExists) {
              // ✅ Restaurer UNIQUEMENT ce pays (pas plusieurs pays)
              favoritesRaw = countryCodeFromLangue;
              print('✅ Pays restauré depuis sPaysLangue (country_selection): $countryCodeFromLangue');
              
              // ✅ Sauvegarder le pays restauré dans le profil
              final updatedProfile = Map<String, dynamic>.from(storedProfile ?? {});
              updatedProfile['sPaysFav'] = countryCodeFromLangue;
              await LocalStorageService.saveProfile(updatedProfile);
              
              // ✅ Mettre à jour mergedProfile pour éviter de recharger depuis la BDD
              mergedProfile = updatedProfile;
            }
          }
        }
      } else if (_hasExplicitlyDeselectedAll) {
        print('✅ Désélection explicite - Ne pas restaurer depuis sPaysLangue maintenant');
        // Ne pas restaurer maintenant, laisser l'utilisateur voir qu'il a tout décoché
        favoritesRaw = '';
      }
      
      // ✅ Ne PAS ajouter de pays par défaut - on a déjà restauré depuis sPaysLangue si nécessaire
      // (comme SNAL qui ne fait pas de fallback automatique)
      final favorites = _buildFavoriteSet(favoritesRaw, countries, allowDefault: false);
      
      print('📊 Pays favoris finaux après _buildFavoriteSet: ${favorites.toList()}');

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

  LinkedHashSet<String> _buildFavoriteSet(String favoritesRaw, List<Country> availableCountries, {bool allowDefault = true}) {
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

    // ✅ Ne PAS ajouter de pays par défaut si allowDefault est false
    // (comme SNAL qui ne fait pas de fallback si l'utilisateur a déjà choisi des pays)
    if (favorites.isEmpty && allowDefault && availableCountries.isNotEmpty) {
      print('⚠️ Aucun pays favori trouvé - Ajout de pays par défaut (première initialisation)');
      for (final country in availableCountries) {
        final code = (country.sPays ?? '').toUpperCase();
        if (code.length == 2 && availableCodes.contains(code)) {
          favorites.add(code);
        }
        if (favorites.length >= 5) {
          break;
        }
      }
    } else if (favorites.isEmpty && !allowDefault) {
      print('✅ Aucun pays favori - L\'utilisateur n\'a pas encore choisi de pays');
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
      
      // ✅ Utiliser la traduction pour le code d'erreur en privilégiant le backend
      String errorDisplayMessage;
      if (e.errorCode.isNotEmpty) {
        // Essayer de traduire le code d'erreur (ex: HTML_SEARCH_BADREFERENCE) en privilégiant le backend
        final translatedError = translationService.translateFromBackend(e.errorCode);
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

  /// ✅ ALIGNÉ AVEC SNAL-PROJECT : Permettre recherche par nom ET par code
  /// Gestion de la saisie de recherche (texte libre, pas de formatage)
  void _onInputSearch(String value) {
    final cleanQuery = value.trim();
    
    // ✅ ALIGNÉ AVEC SNAL-PROJECT : Minimum 3 caractères pour lancer la recherche
    // (useSearchArticle.ts ligne 19)
    if (cleanQuery.length >= 3) {
      _searchProducts(cleanQuery);
    } else {
      setState(() {
        _filteredProducts = [];
        _errorMessage = '';
        _isLoading = false;
        _hasSearched = false; // Pas de recherche si moins de 3 caractères
      });
    }
  }

  Future<void> _toggleCountry(String countryCode) async {
    if (_isLoadingCountries) {
      print('⚠️ _toggleCountry: _isLoadingCountries est true, retour');
      return;
    }

    final normalizedCode = countryCode.toUpperCase();
    if (normalizedCode.length != 2) {
      print('⚠️ _toggleCountry: Code pays invalide: $countryCode');
      return;
    }
    
    final previousFavorites = LinkedHashSet<String>.from(_favoriteCountryCodes);
    final updatedFavorites = LinkedHashSet<String>.from(_favoriteCountryCodes);
    final isCurrentlySelected = updatedFavorites.contains(normalizedCode);
    
    print('🔄 _toggleCountry: $normalizedCode - Actuellement sélectionné: $isCurrentlySelected');
    print('📋 Pays sélectionnés avant: ${previousFavorites.toList()}');

    // ✅ Permettre de tout décocher (comme SNAL)
    // Le pays de sPaysLangue sera restauré au retour sur la page
    if (isCurrentlySelected) {
      updatedFavorites.remove(normalizedCode);
      print('✅ Pays $normalizedCode décoché - Pays restants: ${updatedFavorites.toList()}');
    } else {
      updatedFavorites.add(normalizedCode);
      print('✅ Pays $normalizedCode coché - Pays sélectionnés: ${updatedFavorites.toList()}');
    }

    final orderedFavorites = _orderedFavoritesList(updatedFavorites);
    final newFavoritesString = orderedFavorites.join(',');

    // ✅ CRITIQUE: Mettre à jour l'UI IMMÉDIATEMENT, même si on a tout décoché
    // (comme SNAL qui met à jour formData.sPaysFav immédiatement)
    if (mounted) {
      setState(() {
        _favoriteCountryCodes = LinkedHashSet<String>.from(orderedFavorites);
      });
    }

    Map<String, dynamic>? previousProfile;
    try {
      previousProfile = await LocalStorageService.getProfile();

      final apiService = ApiService();
      
      // ✅ Si on a tout décoché (newFavoritesString est vide), restaurer immédiatement le pays de sPaysLangue
      // (comme SNAL qui restaure le pays choisi dans country_selection)
      if (newFavoritesString.isEmpty) {
        print('⚠️ Tous les pays décochés - Restauration du pays de sPaysLangue');
        
        // ✅ Récupérer le pays de sPaysLangue (country_selection)
        final sPaysLangue = previousProfile?['sPaysLangue']?.toString() ?? '';
        String? countryCodeFromLangue;
        
        if (sPaysLangue.isNotEmpty) {
          // sPaysLangue est au format "BE/FR" ou "FR/FR" - extraire les 2 premiers caractères
          countryCodeFromLangue = sPaysLangue.split('/').first.toUpperCase();
          if (countryCodeFromLangue.length == 2) {
            // Vérifier que ce code pays existe dans la liste des pays disponibles
            final countryExists = _allCountries.any((country) => 
              (country.sPays ?? country.code ?? '').toUpperCase() == countryCodeFromLangue
            );
            if (countryExists) {
              // ✅ Restaurer immédiatement ce pays dans l'UI
              final restoredFavorites = LinkedHashSet<String>.from([countryCodeFromLangue!]);
              final restoredOrderedFavorites = _orderedFavoritesList(restoredFavorites);
              final restoredFavoritesString = restoredOrderedFavorites.join(',');
              
              print('✅ Pays restauré depuis sPaysLangue (country_selection): $countryCodeFromLangue');
              
              // ✅ Mettre à jour l'UI immédiatement
              if (mounted) {
                setState(() {
                  _favoriteCountryCodes = LinkedHashSet<String>.from(restoredOrderedFavorites);
                });
              }
              
              // ✅ Sauvegarder le pays restauré dans le profil
              final restoredProfile = _composeProfileData(
                base: previousProfile,
                overrides: {
                  'sPaysFav': restoredFavoritesString,
                },
              );
              await LocalStorageService.saveProfile(restoredProfile);
              
              // ✅ Appeler l'API pour sauvegarder le pays restauré
              try {
                final apiService = ApiService();
                final updateResponse = await apiService.updateProfile({
                  'sPaysFav': restoredFavoritesString,
                });
                
                if (updateResponse.isNotEmpty) {
                  final mergedProfile = _composeProfileData(
                    base: restoredProfile,
                    overrides: updateResponse,
                  );
                  mergedProfile['sPaysFav'] = restoredFavoritesString;
                  await LocalStorageService.saveProfile(mergedProfile);
                  print('✅ Pays restauré sauvegardé dans la BDD: $restoredFavoritesString');
                }
              } catch (e) {
                print('⚠️ Erreur lors de la sauvegarde du pays restauré: $e');
              }
              
              return; // Ne pas continuer avec la logique normale
            }
          }
        }
        
        // ✅ Si on n'a pas pu restaurer depuis sPaysLangue, sauvegarder une chaîne vide
        // (le pays sera restauré au retour sur la page)
        print('⚠️ Impossible de restaurer depuis sPaysLangue - Sauvegarde d\'une chaîne vide');
        _hasExplicitlyDeselectedAll = true;
        
        final emptyProfile = _composeProfileData(
          base: previousProfile,
          overrides: {
            'sPaysFav': '', // Chaîne vide explicite
          },
        );
        await LocalStorageService.saveProfile(emptyProfile);
        print('✅ Profil sauvegardé avec sPaysFav vide - Le pays de sPaysLangue sera restauré au retour');
        return; // Ne pas appeler l'API si on a tout décoché
      }
      
      // ✅ Réinitialiser le flag si on a des pays sélectionnés
      _hasExplicitlyDeselectedAll = false;
      
      // ✅ Appeler updateProfile qui retourne le profil mis à jour
      final updateResponse = await apiService.updateProfile({
        'sPaysFav': newFavoritesString,
      });

      // ✅ Utiliser directement la réponse de updateProfile (qui contient déjà le profil mis à jour)
      // Ne pas appeler getProfile() car il peut retourner l'ancien profil depuis la session SNAL
      if (updateResponse.isNotEmpty) {
        // ✅ Merger avec le profil précédent mais donner la priorité au sPaysFav de la réponse
        final mergedProfile = _composeProfileData(
          base: previousProfile,
          overrides: updateResponse,
        );
        
        // ✅ CRITIQUE: Forcer le nouveau sPaysFav même si updateResponse ne le contient pas
        // (comme SNAL qui met à jour directement formData.sPaysFav)
        mergedProfile['sPaysFav'] = newFavoritesString;
        
        await LocalStorageService.saveProfile(mergedProfile);
        
        print('✅ Pays favoris mis à jour: $newFavoritesString');
      } else {
        // ✅ Fallback: Sauvegarder directement le nouveau sPaysFav
        final fallbackProfile = _composeProfileData(
          base: previousProfile,
          overrides: {
            'sPaysFav': newFavoritesString,
          },
        );
        await LocalStorageService.saveProfile(fallbackProfile);
        
        print('✅ Pays favoris sauvegardés (fallback): $newFavoritesString');
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
    final selectedCountries = orderedFavorites
        .map(_findCountryByCode)
        .whereType<Country>()
        .toList();

    // ✅ Ne PAS ajouter de pays par défaut si l'utilisateur a explicitement tout décoché
    // (comme SNAL qui n'ajoute pas de pays par défaut)
    // ⚠️ Cette logique ne doit s'appliquer que lors de la première initialisation
    // Si _favoriteCountryCodes est vide ET qu'on n'a pas explicitement décoché, alors on peut ajouter des pays par défaut
    // Mais si _hasExplicitlyDeselectedAll est true, on ne doit rien ajouter

    // ✅ Créer une liste unique de tous les pays à afficher (comme SNAL displayedCountries)
    // Les pays sélectionnés en premier, puis les non sélectionnés
    final selectedCodes = _favoriteCountryCodes.toSet();
    final allCountriesToDisplay = <Country>[];
    
    // ✅ D'abord ajouter les pays sélectionnés (dans l'ordre)
    for (final code in orderedFavorites) {
      final country = _findCountryByCode(code);
      if (country != null) {
        allCountriesToDisplay.add(country);
      }
    }
    
    // ✅ Ensuite ajouter les pays non sélectionnés (dans l'ordre de _allCountries)
    for (final country in _allCountries) {
      final code = (country.sPays ?? country.code ?? '').toUpperCase();
      if (code.length == 2 && !selectedCodes.contains(code)) {
        allCountriesToDisplay.add(country);
      }
    }

    // ✅ Créer les chips pour tous les pays (sélectionnés et non sélectionnés, sans duplication)
    final allCountryChips = allCountriesToDisplay
        .map((country) {
          final code = (country.sPays ?? country.code ?? '').toUpperCase();
          final isSelected = selectedCodes.contains(code);
          return _buildCountryChip(country, isSelected, isMobile);
        })
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
              // ✅ Affichage des pays : 4 en haut et 3 en bas (responsive pour éviter le débordement)
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final isMobile = screenWidth < 768;
                  
                  // Calculer la largeur disponible et ajuster l'espacement/taille
                  final containerPadding = isMobile ? 32.0 : 64.0; // padding horizontal du container
                  final availableWidth = screenWidth - containerPadding;
                  
                  // Pour 4 pays en haut : calculer l'espacement et la largeur max des chips
                  final itemsPerRow = 4;
                  final spacing = isMobile ? 6.0 : 6.0; // Espacement augmenté sur mobile
                  final totalSpacing = spacing * (itemsPerRow - 1);
                  // ✅ Augmenter la largeur des chips en utilisant plus d'espace disponible
                  final maxChipWidth = isMobile ? (availableWidth - totalSpacing) / itemsPerRow : null;
                  
                  return Column(
                    children: [
                      // Première ligne : 4 pays
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < allCountryChips.length && i < 4; i++)
                            Padding(
                              padding: EdgeInsets.only(right: i < 3 ? spacing : 0.0),
                              child: maxChipWidth != null
                                  ? ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: maxChipWidth),
                                      child: allCountryChips[i],
                                    )
                                  : allCountryChips[i],
                            ),
                        ],
                      ),
                      // Deuxième ligne : 3 pays (si il y en a plus de 4)
                      if (allCountryChips.length > 4)
                        Padding(
                          padding: EdgeInsets.only(top: spacing),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int i = 4; i < allCountryChips.length && i < 7; i++)
                                Padding(
                                  padding: EdgeInsets.only(right: i < 6 ? spacing : 0.0),
                                  child: maxChipWidth != null
                                      ? ConstrainedBox(
                                          constraints: BoxConstraints(maxWidth: maxChipWidth),
                                          child: allCountryChips[i],
                                        )
                                      : allCountryChips[i],
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryChip(Country country, bool isSelected, bool isMobile) {
    final countryCode = country.sPays.toUpperCase();

    return GestureDetector(
      onTap: () => _toggleCountry(countryCode),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 22 : 24, // ✅ Encore augmenté sur mobile pour utiliser plus d'espace
          vertical: isMobile ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          // ✅ Pas de box-shadow ni de bordures (comme SNAL)
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, // ✅ Centrer le contenu
            children: [
              // Drapeau du pays
              Text(
                _flagEmoji(countryCode),
                style: TextStyle(fontSize: isMobile ? 16 : 18), // ✅ Taille augmentée sur mobile
              ),
              SizedBox(width: isMobile ? 8 : 8), // ✅ Espacement augmenté sur mobile
              // Icône : coche bleue si sélectionné, plus gris si non sélectionné (comme SNAL)
              Icon(
                isSelected ? Icons.check : Icons.add,
                size: isMobile ? 16 : 18, // ✅ Taille augmentée sur mobile
                color: isSelected 
                    ? const Color(0xFF0D6EFD) // Bleu pour sélectionné (comme SNAL i-lucide-check)
                    : Colors.grey[400], // Gris pour non sélectionné (comme SNAL i-lucide-plus text-gray-400)
              ),
            ],
          ),
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
                    closedColor: const Color(0xFF0058CC), // ✅ Couleur #0058CC
                    closedBuilder: (context, action) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 12 : 14, // ✅ Hauteur réduite
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
                    _buildErrorState(translationService)
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
        onChanged: _onInputSearch, // ✅ Changé pour permettre les lettres
        keyboardType: TextInputType.text, // ✅ Permettre texte ET chiffres
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: translationService.translate('INPUT_IKEA_REFERENCE_OR_NAME'),
          hintStyle: TextStyle(color: Colors.grey[400]),
          // ✅ Icône search enlevée
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // ✅ Hauteur réduite
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

  Widget _buildErrorState(TranslationService translationService) {
    // Récupérer les traductions en privilégiant le backend
    final errorTitle = translationService.translateFromBackend('PRODUCTCODE_Msg04');
    
    // Si _errorMessage contient une clé de traduction (commence par une majuscule et contient des underscores),
    // essayer de la traduire, sinon utiliser _errorMessage tel quel
    String errorMessage;
    if (_errorMessage.isNotEmpty) {
      // Vérifier si _errorMessage ressemble à une clé de traduction
      if (_errorMessage.contains('_') && _errorMessage == _errorMessage.toUpperCase()) {
        // C'est probablement une clé de traduction, essayer de la traduire
        final translated = translationService.translateFromBackend(_errorMessage);
        errorMessage = (translated != _errorMessage) ? translated : _errorMessage;
      } else {
        // C'est déjà un message traduit, l'utiliser tel quel
        errorMessage = _errorMessage;
      }
    } else {
      // Utiliser la traduction par défaut
      errorMessage = translationService.translateFromBackend('HTML_SEARCH_BADREFERENCE');
    }
    
    // Remplacer <br> par des sauts de ligne
    final formattedMessage = errorMessage.replaceAll('<br>', '\n');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Titre de l'erreur
          Text(
            errorTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Message d'erreur principal (gère les sauts de ligne automatiquement)
          Text(
            formattedMessage,
            style: TextStyle(
              fontSize: 15,
              color: Colors.blue[600],
              height: 1.5,
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
            translationService.translate('WISHLIST_Msg48'),
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