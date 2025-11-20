import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:collection'; // ✅ Pour LinkedHashSet
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
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _errorMessage = '';
  bool _hasSearched = false;
  
  // Gestion du profil utilisateur et du token
  String? _userToken;
  String? _userBasket;
  
  // Gestion dynamique des pays favoris (comme product_search_screen.dart)
  final CountryService _countryService = CountryService();
  List<Country> _allCountries = [];
  LinkedHashSet<String> _favoriteCountryCodes = LinkedHashSet<String>();
  bool _isLoadingCountries = true;
  bool _hasExplicitlyDeselectedAll = false; // Flag pour indiquer qu'on a explicitement tout décoché
  

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

  /// Charger les pays disponibles depuis l'API (même logique que product_search_screen.dart)
  Future<void> _loadCountries() async {
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
      
      // ✅ S'assurer que countries est toujours une liste valide
      if (countries.isEmpty) {
        print('⚠️ Aucun pays trouvé dans le service');
      }

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
      // ✅ S'assurer que _allCountries reste une liste valide (même si vide) en cas d'erreur
      // (comme product_search_screen.dart)
      if (mounted) {
        setState(() {
          _isLoadingCountries = false;
        });
      } else {
        _isLoadingCountries = false;
      }
    }
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

  /// Méthodes de gestion des pays (comme product_search_screen.dart)
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
        .map((country) => (country.sPays ?? country.code ?? '').toUpperCase())
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
        final code = (country.sPays ?? country.code ?? '').toUpperCase();
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
    // ✅ Exactement comme product_search_screen.dart - pas de vérification isEmpty
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

  /// ✅ ALIGNÉ AVEC product_search_screen.dart : Recherche textuelle libre
  /// Accepte les lettres ET les chiffres, lance la recherche à partir de 3 caractères
  void _onInputSearch(String value) {
    final cleanQuery = value.trim();
    
    // ✅ ALIGNÉ AVEC SNAL-PROJECT : Minimum 3 caractères pour lancer la recherche
    // (useSearchArticle.ts ligne 19)
    if (cleanQuery.length >= 3) {
      _searchProduct(cleanQuery);
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
            onChanged: _onInputSearch, // ✅ Changé pour permettre les lettres
            keyboardType: TextInputType.text, // ✅ Permettre texte ET chiffres
            style: TextStyle(
              fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              hintText: translationService.translate('FRONTPAGE_Msg06'), // ✅ Utilise la clé de traduction
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                fontWeight: FontWeight.normal,
              ),
              // ✅ Icône search enlevée (comme product_search_screen.dart)
              contentPadding: EdgeInsets.symmetric(
                vertical: isVerySmallMobile ? 12 : (isSmallMobile ? 12 : 12), // ✅ Hauteur réduite
                horizontal: isVerySmallMobile ? 16 : (isSmallMobile ? 16 : 16),
              ),
              suffixIcon: _isSearching
                  ? Padding(
                      padding: EdgeInsets.all(isVerySmallMobile ? 12 : (isSmallMobile ? 12 : 12)),
                      child: SizedBox(
                        width: isVerySmallMobile ? 20 : 20,
                        height: isVerySmallMobile ? 20 : 20,
                        child: LoadingAnimationWidget.progressiveDots(
                          color: Colors.blue,
                          size: isVerySmallMobile ? 20 : 20,
                        ),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey[600],
                            size: isVerySmallMobile ? 18 : (isSmallMobile ? 19 : 20),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountrySection(bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    final translationService = Provider.of<TranslationService>(context, listen: false);
    
    // ✅ Vérifier l'état de chargement en premier (comme product_search_screen.dart)
    if (_isLoadingCountries) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : 32.0,
          vertical: isMobile ? 32.0 : 48.0,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFD43B),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ Vérifier que _allCountries est initialisé et non vide (comme product_search_screen.dart)
    // Ne pas utiliser try-catch ici car cela peut masquer des erreurs réelles
    if (_allCountries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : 32.0,
          vertical: isMobile ? 24.0 : 32.0,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFD43B),
        ),
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
    
    // ✅ Utiliser _favoriteCountryCodes directement (il est toujours initialisé comme LinkedHashSet vide)
    // ✅ Créer une liste unique de tous les pays à afficher (comme SNAL displayedCountries)
    // Les pays sélectionnés en premier, puis les non sélectionnés
    final selectedCodes = _favoriteCountryCodes.toSet();
    final orderedFavorites = _orderedFavoritesList(_favoriteCountryCodes);
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
          final isSelected = code.length == 2 && selectedCodes.contains(code);
          return _buildCountryChip(country, isSelected, isMobile);
        })
        .toList();
    
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFFD43B), // ✅ Même couleur de fond que product_search_screen
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
    );
  }

  /// Créer un chip de pays avec le style de product_search_screen (comme product_search_screen.dart)
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
                translationService.translate('FRONTPAGE_Msg07'),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Titre de l'erreur
          Text(
            'Erreur de recherche',
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
            _errorMessage.isNotEmpty ? _errorMessage : 'La référence ne semble pas être correcte.',
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