import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
// Import conditionnel pour le web uniquement - géré dans WebUtils
import '../utils/web_utils.dart';
import '../models/country.dart';
import '../config/api_config.dart';
import 'profile_service.dart';
import 'local_storage_service.dart';

/// Exception pour les erreurs de recherche d'articles
/// Utilise les clés envoyées par le backend: success, error, message
class SearchArticleException implements Exception {
  final bool success;
  final String errorCode;
  final String message;

  SearchArticleException({
    required this.success,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() => message.isNotEmpty ? message : errorCode;
}

/// Service API pour se connecter au backend SNAL-Project
/// Mobile-First: Gestion automatique des cookies sur mobile, proxy sur web
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Dio? _dio;
  CookieJar? _cookieJar;
  final ProfileService _profileService = ProfileService();
  bool _isInitializing = false;
  bool _isInitialized = false;

  /// Helper pour récupérer le profil avec le bon type explicite
  /// Évite l'inférence de type problématique dans les intercepteurs
  Future<Map<String, dynamic>?> _getProfileForInterceptor() async {
    return await LocalStorageService.getProfile();
  }

  Future<void> initialize() async {
    // Si déjà complètement initialisé
    if (_isInitialized && _dio != null) {
      return;
    }

    // Si en cours d'initialisation, attendre
    if (_isInitializing) {
      print('⏳ Attente de la fin de l\'initialisation...');
      int attempts = 0;
      while (_isInitializing && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      return;
    }

    // Marquer comme en cours d'initialisation
    _isInitializing = true;
    print('🔄 Initialisation de l\'API Service...');

    // Afficher la configuration actuelle (debug)
    ApiConfig.printConfig();

    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: ApiConfig.defaultHeaders,
    ));

    // Mobile-First: Gestion des cookies seulement sur mobile
    if (ApiConfig.useCookieManager) {
      try {
        // Obtenir le répertoire de l'application pour sauvegarder les cookies
        final appDocDir = await getApplicationDocumentsDirectory();
        final cookiePath = '${appDocDir.path}/.cookies/';

        // Créer le répertoire s'il n'existe pas
        await Directory(cookiePath).create(recursive: true);

        // Initialiser PersistCookieJar pour sauvegarder les cookies sur le disque
        _cookieJar = PersistCookieJar(
          storage: FileStorage(cookiePath),
        );

        // Ajouter le gestionnaire de cookies à Dio
        _dio!.interceptors.add(CookieManager(_cookieJar!));

        print('✅ Cookie Manager activé (Mobile)');
        print('   Cookies sauvegardés dans: $cookiePath');
      } catch (e) {
        print('⚠️ Erreur lors de l\'initialisation du Cookie Manager: $e');
      }
    } else {
      print('ℹ️ Cookie Manager désactivé (Web - le navigateur gère les cookies)');
    }

    // Intercepteur pour les logs de debug détaillés
    _dio!.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (obj) {
        print('🔵 API LOG: $obj');
      },
    ));

    // Intercepteur pour vérifier les cookies reçus dans les réponses
    _dio!.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) async {
        print('📥 Réponse reçue: ${response.requestOptions.path}');
        print('📋 Headers de réponse: ${response.headers}');

        // Vérifier les Set-Cookie dans les headers
        final setCookieHeaders = response.headers['set-cookie'];
        if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
          print('🍪 Set-Cookie reçus: $setCookieHeaders');

          // Extraire le GuestProfile
          for (final cookie in setCookieHeaders) {
            if (cookie.contains('GuestProfile')) {
              print('🎯 Cookie GuestProfile trouvé dans Set-Cookie: $cookie');
            }
          }
        }

        handler.next(response);
      },
    ));

    // Intercepteur pour ajouter le GuestProfile dans les headers ET comme cookie
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Récupérer le profil local
        // ✅ CORRECTION: Utiliser une méthode helper de la classe pour éviter l'inférence de type problématique
        Map<String, dynamic>? profile;
        try {
          profile = await _getProfileForInterceptor();
        } catch (e) {
          print('⚠️ Erreur lors de la récupération du profil dans l\'intercepteur: $e');
          profile = null;
        }

        // ✅ RÉCUPÉRER LES VRAIES VALEURS DEPUIS LES COOKIES
        // SNAL gère les identifiants côté serveur via les cookies
        if (profile != null) {
          final iProfile = profile['iProfile']?.toString() ?? '0';
          final iBasket = profile['iBasket']?.toString() ?? '0';
          final sPaysLangue = profile['sPaysLangue']?.toString() ?? '';
          final sPaysFav = profile['sPaysFav']?.toString() ?? '';

          // ✅ UTILISER LES VRAIES VALEURS directement depuis le localStorage
          String finalIProfile = iProfile;
          String finalIBasket = iBasket;

          // Si ce sont des identifiants par défaut, utiliser '0' (comme le proxy) et non des chaînes vides
          if (iProfile.isEmpty || iProfile == '0' || iProfile.startsWith('guest_')) {
            finalIProfile = '0';
          }
          if (iBasket.isEmpty || iBasket == '0' || iBasket.startsWith('basket_')) {
            finalIBasket = '0';
          }

          if (finalIProfile != '0' && finalIBasket != '0') {
            print('✅ Vrais identifiants utilisés directement: iProfile=$finalIProfile, iBasket=$finalIBasket');
          } else {
            print('⚠️ Identifiants par défaut détectés, envoi de iProfile=0 / iBasket=0 (comme proxy web)...');
          }

          // Créer le GuestProfile (comme SNAL / proxy)
          final guestProfile = {
            'iProfile': finalIProfile,
            'iBasket': finalIBasket,
            'sPaysLangue': sPaysLangue,
            'sPaysFav': sPaysFav,
          };

          // ✅ Ajouter le GuestProfile JSON dans les headers (comme SNAL)
          final guestProfileJson = jsonEncode(guestProfile);
          options.headers['X-Guest-Profile'] = guestProfileJson;
          options.headers['x-guest-profile'] = guestProfileJson;

          // ✅ IMPORTANT : Ajouter le GuestProfile comme COOKIE (comme SNAL)
          final guestProfileEncoded = Uri.encodeComponent(guestProfileJson);
          final cookieParts = <String>[
            'GuestProfile=' + guestProfileEncoded,
          ];

          if (finalIProfile.isNotEmpty) {
            cookieParts.add('iProfile=' + Uri.encodeComponent(finalIProfile));
          }
          if (finalIBasket.isNotEmpty) {
            cookieParts.add('iBasket=' + Uri.encodeComponent(finalIBasket));
          }

          final cookieHeader = cookieParts.join('; ');
          options.headers['Cookie'] = cookieHeader;
          options.headers['cookie'] = cookieHeader;

          print('🍪 GuestProfile envoyé: ' + guestProfile.toString());
          print('🍪 Cookie: ' + cookieHeader);
        }

        handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        if (error.response != null) {
          print('Status Code: ${error.response?.statusCode}');
          print('Response Data: ${error.response?.data}');
        }
        handler.next(error);
      },
    ));

    // Marquer comme initialisé
    _isInitializing = false;
    _isInitialized = true;
    print('✅ API Service initialisé avec succès');
  }

  /// Nettoyer les cookies (utile pour la déconnexion)
  Future<void> clearCookies() async {
    if (_cookieJar != null) {
      await _cookieJar!.deleteAll();
      print('🗑️ Cookies supprimés');
    }
  }

  /// Rechercher des articles par code ou description
  /// Implémentation conforme à SNAL-Project
  Future<List<dynamic>> searchArticle(String query, {String? token, int limit = 10}) async {
    try {
      // S'assurer que l'API est initialisée
      if (_dio == null) {
        await initialize();
      }

      // Validation conforme à SNAL-Project
      if (query.isEmpty) return [];

      final cleanQuery = query.trim();

      // Validation : seuls les chiffres et points sont autorisés (conforme à SNAL-Project)
      if (RegExp(r'[^0-9.]').hasMatch(cleanQuery)) {
        return []; // contient des lettres → on ne fait rien
      }

      // Minimum 3 caractères (conforme à SNAL-Project)
      if (cleanQuery.length < 3) {
        return []; // pas assez de caractères → on ne fait rien
      }

      // Maximum 9 chiffres (conforme à SNAL-Project)
      final numericQuery = cleanQuery.replaceAll(RegExp(r'[^\d]'), '');
      if (numericQuery.length > 9) {
        return [];
      }

      // Utiliser exactement la même approche que SNAL-Project (sans XML en paramètre)
      final response = await _dio!.get('/search-article', queryParameters: {
        'search': cleanQuery,
        'token': token ?? '', // Token obligatoire selon SNAL-Project
        'limit': limit,
        'type': RegExp(r'^\d+$').hasMatch(cleanQuery) ? 'code' : 'description',
      });

      // ✅ CORRECTION: Gérer les erreurs du backend avec success: false, error, message
      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        
        // Vérifier si c'est une erreur du backend
        if (data['success'] == false) {
          final errorCode = data['error']?.toString() ?? '';
          final errorMessage = data['message']?.toString() ?? '';
          
          print('⚠️ Erreur backend détectée:');
          print('   success: ${data['success']}');
          print('   error: $errorCode');
          print('   message: $errorMessage');
          
          // ✅ Lancer une exception avec les détails de l'erreur pour que les écrans puissent les gérer
          throw SearchArticleException(
            errorCode: errorCode,
            message: errorMessage,
            success: false,
          );
        }

        // Vérifier si c'est un objet unique avec STATUS ERROR
        if (data['STATUS'] == 'ERROR' || data['STATUS'] == 'SYSTEM_ERROR') {
          return []; // Erreur de la base de données
        }
      }

      // Gestion de la réponse conforme à SNAL-Project
      if (response.data is List) {
        // L'API retourne directement un tableau de résultats
        return _filterSearchResults(response.data, cleanQuery);
      }

      return [];
    } on SearchArticleException {
      // ✅ Re-lancer l'exception pour que les écrans puissent la gérer
      rethrow;
    } catch (e) {
      print('❌ Erreur lors de la recherche: $e');
      // ✅ Si c'est une DioException avec une réponse, vérifier si c'est une erreur backend
      if (e is DioException && e.response?.data is Map) {
        final responseData = e.response!.data as Map<String, dynamic>;
        if (responseData['success'] == false) {
          final errorCode = responseData['error']?.toString() ?? '';
          final errorMessage = responseData['message']?.toString() ?? '';
          throw SearchArticleException(
            errorCode: errorCode,
            message: errorMessage,
            success: false,
          );
        }
      }
      return []; // Retourner une liste vide en cas d'erreur générique
    }
  }

  /// Télécharger le PDF du projet (wishlist) comme dans SNAL (GET /projet-download)
  Future<Response<dynamic>> downloadProjetPdf({required String iBasket, String? iProfile}) async {
    // S'assurer que l'API est initialisée
    if (_dio == null) {
      await initialize();
    }

    print('📄 === DOWNLOAD PROJET PDF ===');
    print('📦 iBasket fourni: $iBasket');
    print('👤 iProfile fourni: ${iProfile ?? "(vide)"}');

    // Si iProfile n'est pas fourni, le récupérer depuis LocalStorage
    String finalIProfile = iProfile ?? '';
    if (finalIProfile.isEmpty) {
      final profileData = await LocalStorageService.getProfile();
      finalIProfile = profileData?['iProfile']?.toString() ?? '';
      print('👤 iProfile récupéré depuis LocalStorage: $finalIProfile');
    }

    // ✅ CORRECTION CRITIQUE: Ne PAS passer iBasket en query parameter
    // Le proxy Express va le récupérer depuis les headers et l'ajouter lui-même en query
    final String url = '/projet-download';

    print('📤 GET $url (sans query params)');
    print('📤 iBasket sera envoyé via header X-IBasket');
    print('📤 iProfile sera envoyé via header X-IProfile');

    final response = await _dio!.get(
      url,
      // ✅ Pas de queryParameters - le proxy s'occupe de tout
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'application/pdf',
          // Les headers X-IProfile et X-IBasket sont automatiquement ajoutés
          // par l'intercepteur onRequest (lignes 108-126 du fichier actuel)
        },
      ),
    );

    print('📡 Response status: ${response.statusCode}');
    print('📄 PDF bytes reçus: ${response.data?.length ?? 0} bytes');

    return response;
  }


  /// Filtrer les résultats de recherche côté client (conforme à SNAL-Project)
  List<dynamic> _filterSearchResults(List<dynamic> results, String cleanQuery) {
    // Vérifier s'il y a une erreur dans le tableau
    final error = results.firstWhere(
          (item) => item['STATUS'] == 'ERROR',
      orElse: () => null,
    );

    if (error != null) {
      return []; // Erreur trouvée, retourner liste vide
    }

    // Pour les codes numériques, recherche progressive
    if (RegExp(r'^\d+$').hasMatch(cleanQuery)) {
      return results.where((item) {
        final itemCode = (item['sCodeArticle'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
        return itemCode.contains(cleanQuery);
      }).toList();
    }

    // Pour les recherches textuelles, recherche dans description et code
    return results.where((item) {
      final description = (item['sDescr'] ?? '').toString().toLowerCase();
      final code = (item['sCodeArticle'] ?? '').toString().toLowerCase();
      final searchQuery = cleanQuery.toLowerCase();
      return description.contains(searchQuery) || code.contains(searchQuery);
    }).toList();
  }

  /// Récupérer toutes les informations de statut (pays, langues, drapeaux)
  Future<Map<String, dynamic>> getInfosStatus() async {
    try {
      // S'assurer que l'API est initialisée
      if (_dio == null) {
        await initialize();
      }

      print('🚀 APPEL API: GET /get-infos-status');
      print('📡 URL complète: ${_dio!.options.baseUrl}/get-infos-status');
      final response = await _dio!.get('/get-infos-status');

      if (response.statusCode == 200) {
        print('✅ RÉPONSE API: Status ${response.statusCode}');
        print('📦 Données reçues: ${response.data}');
        return response.data;
      } else {
        print('❌ ERREUR API: Status ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des infos status: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getInfosStatus: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Récupérer tous les pays disponibles (fallback)
  Future<List<Country>> getAllCountries() async {
    try {
      print('🚀 APPEL API: GET /get-all-country');
      print('📡 URL complète: ${_dio!.options.baseUrl}/get-all-country');
      final response = await _dio!.get('/get-all-country');

      if (response.statusCode == 200) {
        print('✅ RÉPONSE API: Status ${response.statusCode}');
        print('📦 Données reçues: ${response.data}');
        final List<dynamic> data = response.data;
        return data.map((json) => Country.fromJson(json)).toList();
      } else {
        print('❌ ERREUR API: Status ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des pays: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getAllCountries: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Récupérer les drapeaux des pays
  Future<List<Map<String, dynamic>>> getCountryFlags() async {
    try {
      print('🚀 APPEL API: GET /flags');
      print('📡 URL complète: ${_dio!.options.baseUrl}/flags');
      final response = await _dio!.get('/flags');

      if (response.statusCode == 200) {
        print('✅ RÉPONSE API: Status ${response.statusCode}');
        print('📦 Données reçues: ${response.data}');
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        print('❌ ERREUR API: Status ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des drapeaux: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getCountryFlags: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Récupérer les informations détaillées pour un pays
  Future<Map<String, dynamic>> getCountryInfo(int iPaysSelected) async {
    try {
      final response = await _dio!.post('/get-all-infos-4country', data: {
        'iPaysSelected': iPaysSelected,
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Erreur lors de la récupération des infos pays: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getCountryInfo: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Initialiser le profil utilisateur avec la sélection de pays
  Future<Map<String, dynamic>> initializeUserProfile({
    required String sPaysLangue,
    required List<String> sPaysFav,
    required bool bGeneralConditionAgree,
  }) async {
    try {
      print('🚀 APPEL API: POST /auth/init');
      print('📡 URL complète: ${_dio!.options.baseUrl}/auth/init');
      print('📤 Données envoyées: {');
      print('   sPaysLangue: $sPaysLangue,');
      print('   sPaysFav: $sPaysFav,');
      print('   bGeneralConditionAgree: $bGeneralConditionAgree');
      print('}');
      final response = await _dio!.post('/auth/init', data: {
        'sPaysLangue': sPaysLangue,
        'sPaysFav': sPaysFav, // ✅ Array tel quel (SNAL le gère)
        'bGeneralConditionAgree': bGeneralConditionAgree,
      });

      if (response.statusCode == 200) {
        print('✅ RÉPONSE API: Status ${response.statusCode}');
        print('📦 Données reçues: ${response.data}');

        // ✅ Sauvegarder les identifiants générés par l'API d'initialisation
        final data = response.data;
        if (data != null && data is Map<String, dynamic>) {
          final iProfile = data['iProfile']?.toString();
          final iBasket = data['iBasket']?.toString();
          final sPaysLangueFromResponse = data['sPaysLangue']?.toString() ?? sPaysLangue;
          final sPaysFavFromResponse = data['sPaysFav']?.toString() ?? sPaysFav.join(',');

          if (iProfile != null && iBasket != null) {
            // Sauvegarder les identifiants générés dans le localStorage
            await LocalStorageService.saveProfile({
              'iProfile': iProfile,
              'iBasket': iBasket,
              'sPaysLangue': sPaysLangueFromResponse,
              'sPaysFav': sPaysFavFromResponse,
            });
            print('✅ Identifiants sauvegardés: iProfile=$iProfile, iBasket=$iBasket');
          }
        }

        return response.data;
      } else {
        print('❌ ERREUR API: Status ${response.statusCode}');
        throw Exception('Erreur lors de l\'initialisation: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur initializeUserProfile: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Récupérer les cookies depuis le navigateur (Web uniquement)
  Future<Map<String, String>> _getCookiesFromBrowser() async {
    if (!kIsWeb) {
      return {};
    }

    try {
      // Utiliser dart:html pour récupérer les cookies
      final cookies = <String, String>{};
      final cookieString = _getCookiesFromBrowserSync();

      if (cookieString.isNotEmpty) {
        final cookiePairs = cookieString.split(';');
        for (final pair in cookiePairs) {
          final trimmedPair = pair.trim();
          final equalIndex = trimmedPair.indexOf('=');
          if (equalIndex > 0) {
            final name = trimmedPair.substring(0, equalIndex);
            final value = trimmedPair.substring(equalIndex + 1);
            cookies[name] = value;
          }
        }
      }

      print('🍪 Cookies récupérés depuis le navigateur: $cookies');
      return cookies;
    } catch (e) {
      print('❌ Erreur lors de la récupération des cookies: $e');
      return {};
    }
  }

  /// Obtenir les traductions pour une langue
  Future<Map<String, dynamic>> getTranslations(String language) async {
    try {
      print('🚀 APPEL API: GET /translations/$language');
      print('📡 URL complète: ${_dio!.options.baseUrl}/translations/$language');

      final response = await _dio!.get('/translations/$language');

      if (response.statusCode == 200) {
        print('✅ RÉPONSE API: Status ${response.statusCode}');
        print('📦 Traductions reçues: ${response.data}');
        return response.data;
      } else {
        print('❌ ERREUR API: Status ${response.statusCode}');
        throw Exception('Erreur lors de la récupération des traductions: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getTranslations: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }


  /// Rechercher des articles
  Future<List<Map<String, dynamic>>> searchArticles({
    required String search,
    int limit = 10,
  }) async {
    try {
      final response = await _dio!.get('/search-article', queryParameters: {
        'search': search,
        'limit': limit,
      });

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw Exception('Erreur lors de la recherche: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur searchArticles: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }


  /// Mettre à jour la sélection de pays pour un article
  Future<Map<String, dynamic>> updateCountrySelection({
    required int iBasket,
    required String sCodeArticle,
    required int newPaysSelected,
    required double newPriceSelected,
  }) async {
    try {
      final response = await _dio!.post('/change-seleceted-country', queryParameters: {
        'iBasket': iBasket,
        'sCodeArticle': sCodeArticle,
        'newPaysSelected': newPaysSelected,
        'newPriceSelected': newPriceSelected,
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Erreur lors de la mise à jour: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur updateCountrySelection: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Obtenir les informations du panier
  Future<List<Map<String, dynamic>>> getBasketArticles(int iBasket) async {
    try {
      final response = await _dio!.get('/get-basket-list-article', queryParameters: {
        'iBasket': iBasket,
      });

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw Exception('Erreur lors de la récupération du panier: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getBasketArticles: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Obtenir les données de comparaison d'un produit (comme SNAL-Project)
  Future<Map<String, dynamic>?> getComparaisonByCode({
    required String sCodeArticle,
    String? sCodeArticleCrypt,
    String? iProfile,
    String? iBasket,
    int? iQuantite,
  }) async {
    try {
      if (_dio == null) {
        await initialize();
      }

      final queryParams = <String, dynamic>{
        'sCodeArticle': sCodeArticleCrypt ?? sCodeArticle,
      };

      if (iProfile != null) queryParams['iProfile'] = iProfile;
      if (iBasket != null) queryParams['iBasket'] = iBasket;
      if (iQuantite != null) queryParams['iQuantite'] = iQuantite;

      final response = await _dio!.get('/comparaison-by-code-30041025', queryParameters: queryParams);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print('Erreur getComparaisonByCode: $e');
      return null;
    }
  }

  /// Méthode pour tester la connexion
  Future<bool> testConnection() async {
    try {
      final response = await _dio!.get('/get-all-country');
      return response.statusCode == 200;
    } catch (e) {
      print('Test de connexion échoué: $e');
      return false;
    }
  }

  /// Récupérer la wishlist par profil
  Future<Map<String, dynamic>?> getWishlistByProfile({
    required int iProfile,
    int? iBasket,
  }) async {
    try {
      final response = await _dio!.get('/get-wishlist-by-profil', queryParameters: {
        'iProfile': iProfile,
        if (iBasket != null) 'iBasket': iBasket,
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Erreur lors de la récupération de la wishlist: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getWishlistByProfile: $e');
      return null;
    }
  }

  /// Récupérer les articles d'un panier
  /// Basé sur SNAL-Project: get-basket-list-article.get.ts
  Future<Map<String, dynamic>?> getBasketListArticle({
    required dynamic iBasket,  // Peut être String (crypté) ou int
    required dynamic iProfile, // iProfile (pour URL et header)
    String sAction = 'INIT',   // Action par défaut
    String? sPaysFav,          // ✅ Liste des pays favoris
  }) async {
    try {
      print('📦 getBasketListArticle - iProfile: $iProfile, iBasket: $iBasket, sAction: $sAction, sPaysFav: $sPaysFav');

      // ✅ Passer iProfile et iBasket dans les HEADERS pour éviter URL trop longue
      final queryParams = {
        'sAction': sAction,  // ✅ Seulement sAction en query param
      };

      // ✅ Headers avec toutes les données importantes
      final headers = {
        'X-IProfile': iProfile.toString(), // ✅ iProfile dans header
        'X-IBasket': iBasket.toString(),   // ✅ iBasket dans header (évite URL trop longue)
      };

      // ✅ Ajouter sPaysFav dans header ET query si disponible
      if (sPaysFav != null && sPaysFav.isNotEmpty) {
        queryParams['sPaysFav'] = sPaysFav;
        headers['X-SPaysFav'] = sPaysFav; // ✅ Aussi dans header pour fiabilité
      }

      print('📤 Query params: $queryParams');
      print('📤 Headers: $headers');

      final response = await _dio!.get(
        '/get-basket-list-article',
        queryParameters: queryParams,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Erreur lors de la récupération des articles: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur getBasketListArticle: $e');
      return null;
    }
  }

  /// Supprimer un article de la wishlist
  Future<Map<String, dynamic>?> deleteArticleWishlist({
    required int iProfile,
    required String sCodeArticle,
  }) async {
    try {
      final response = await _dio!.get('/delete-article-wishlist', queryParameters: {
        'iProfile': iProfile,
        'sCodeArticle': sCodeArticle,
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Erreur lors de la suppression: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur deleteArticleWishlist: $e');
      return null;
    }
  }

  /// Supprimer un article du panier wishlist (comme SNAL-Project)
  Future<Map<String, dynamic>?> deleteArticleBasketWishlist({
    required String sCodeArticle,
  }) async {
    try {
      print('🗑️ Suppression article: $sCodeArticle');
      print('🌐 URL complète: ${_dio!.options.baseUrl}/delete-article-wishlistBasket');
      print('🌐 Base URL configurée: ${_dio!.options.baseUrl}');
      print('🌐 Plateforme Web: ${kIsWeb}');
      print('📤 Données envoyées: {sCodeArticle: $sCodeArticle}');

      // Récupérer iProfile et iBasket depuis le localStorage
      final profileData = await LocalStorageService.getProfile();
      final iProfile = profileData?['iProfile']?.toString() ?? '';
      final iBasket = profileData?['iBasket']?.toString() ?? '';

      print('👤 iProfile récupéré: $iProfile');
      print('🛒 iBasket récupéré: $iBasket');

      final response = await _dio!.post('/delete-article-wishlistBasket',
        data: {
          'sCodeArticle': sCodeArticle,
        },
        options: Options(
          headers: {
            'X-IProfile': iProfile,
            'X-IBasket': iBasket,
          },
        ),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Headers: ${response.headers}');
      print('📡 Données brutes: ${response.data}');
      print('📡 Type de données: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        print('✅ Article supprimé avec succès');
        print('✅ Données retournées: ${response.data}');
        return response.data;
      } else {
        print('❌ Status code non-200: ${response.statusCode}');
        print('❌ Données d\'erreur: ${response.data}');
        throw Exception('Erreur lors de la suppression: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur deleteArticleBasketWishlist: $e');
      print('❌ Type d\'erreur: ${e.runtimeType}');
      if (e is DioException) {
        print('❌ DioException - Type: ${e.type}');
        print('❌ DioException - Message: ${e.message}');
        print('❌ DioException - Response: ${e.response?.data}');
        print('❌ DioException - Status Code: ${e.response?.statusCode}');
      }
      return null;
    }
  }

  /// Mettre à jour la quantité d'un article dans la wishlist (comme SNAL)
  Future<Map<String, dynamic>?> updateQuantityArticleBasket({
    required String sCodeArticle,
    required int iQte,
  }) async {
    try {
      print('📊 Mise à jour quantité: $sCodeArticle -> $iQte');
      print('🌐 URL complète: ${_dio!.options.baseUrl}/update-quantity-articleBasket');
      print('📤 Données envoyées: {sCodeArticle: $sCodeArticle, iQte: $iQte}');

      // Récupérer iProfile et iBasket depuis le localStorage
      final profileData = await LocalStorageService.getProfile();
      final iProfile = profileData?['iProfile']?.toString() ?? '';
      final iBasket = profileData?['iBasket']?.toString() ?? '';

      print('👤 iProfile récupéré: $iProfile');
      print('🛒 iBasket récupéré: $iBasket');

      final response = await _dio!.post('/update-quantity-articleBasket',
        data: {
          'sCodeArticle': sCodeArticle,
          'iQte': iQte,
        },
        options: Options(
          headers: {
            'X-IProfile': iProfile,
            'X-IBasket': iBasket,
          },
        ),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Réponse: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Quantité mise à jour avec succès');
        return response.data;
      } else {
        print('❌ Status code non-200: ${response.statusCode}');
        throw Exception('Erreur lors de la mise à jour de la quantité: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur updateQuantityArticleBasket: $e');
      if (e is DioException) {
        print('❌ DioException - Type: ${e.type}');
        print('❌ DioException - Message: ${e.message}');
        print('❌ DioException - Response: ${e.response?.data}');
      }
      return null;
    }
  }

  /// Changer le pays sélectionné pour un article (comme SNAL avec CHANGEPAYS)
  Future<Map<String, dynamic>?> updateCountrySelected({
    required String iBasket,
    required String sCodeArticle,
    required String sNewPaysSelected,
  }) async {
    try {
      print('🔄 Appel API updateCountrySelected (CHANGEPAYS):');
      print('   iBasket: $iBasket');
      print('   sCodeArticle: $sCodeArticle');
      print('   sNewPaysSelected: $sNewPaysSelected');

      // Récupérer les données du profil depuis le LocalStorage
      final profileData = await LocalStorageService.getProfile();
      final iProfile = profileData?['iProfile']?.toString() ?? '';
      final sPaysLangue = profileData?['sPaysLangue']?.toString() ?? '';
      final sPaysFav = profileData?['sPaysFav']?.toString() ?? '';

      final response = await _dio!.post(
        '/update-country-selected',
        data: {
          'iBasket': iBasket,
          'sCodeArticle': sCodeArticle,
          'sNewPaysSelected': sNewPaysSelected,
        },
        options: Options(
          headers: {
            'X-IProfile': iProfile,
            'X-Pays-Langue': sPaysLangue,
            'X-Pays-Fav': sPaysFav,
          },
        ),
      );

      print('✅ Réponse updateCountrySelected: ${response.data}');
      return response.data;
    } catch (e) {
      print('❌ Erreur updateCountrySelected: $e');
      if (e is DioException) {
        print('❌ DioException - Response: ${e.response?.data}');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Mettre à jour la liste des pays de la wishlist (comme SNAL)
  Future<Map<String, dynamic>?> updateCountryWishlistBasket({
    required String sPaysListe,
  }) async {
    try {
      print('🌍 Mise à jour liste pays: $sPaysListe');
      print('🌐 URL complète: ${_dio!.options.baseUrl}/update-country-wishlistBasket');

      // Récupérer iProfile et iBasket depuis le localStorage
      final profileData = await LocalStorageService.getProfile();
      final iProfile = profileData?['iProfile']?.toString() ?? '';
      final iBasket = profileData?['iBasket']?.toString() ?? '';

      print('👤 iProfile récupéré: $iProfile');
      print('🛒 iBasket récupéré: $iBasket');
      print('🌍 sPaysListe: $sPaysListe');

      final response = await _dio!.post(
        '/update-country-wishlistBasket',
        data: {
          'sPaysListe': sPaysListe,
        },
        queryParameters: {
          if (iBasket.isNotEmpty) 'iBasket': iBasket,
        },
        options: Options(
          headers: {
            'X-IProfile': iProfile,
            'X-IBasket': iBasket,
          },
        ),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📡 Réponse: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Liste des pays mise à jour avec succès');
        await LocalStorageService.saveProfile({
          'iProfile': iProfile,
          'iBasket': iBasket,
          'sPaysFav': sPaysListe,
        });
        return response.data;
      } else {
        print('❌ Status code non-200: ${response.statusCode}');
        throw Exception('Erreur lors de la mise à jour des pays: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur updateCountryWishlistBasket: $e');
      if (e is DioException) {
        print('❌ DioException - Type: ${e.type}');
        print('❌ DioException - Message: ${e.message}');
        print('❌ DioException - Response: ${e.response?.data}');
      }
      return null;
    }
  }

  /// Ajouter un pays à la wishlist
  Future<Map<String, dynamic>?> addCountryToWishlist({
    required int iProfile,
    required int iPaysSelected,
  }) async {
    try {
      final response = await _dio!.post('/add-country-wishlist', queryParameters: {
        'iProfile': iProfile,
        'iPaysSelected': iPaysSelected,
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Erreur lors de l\'ajout du pays: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur addCountryToWishlist: $e');
      return null;
    }
  }

  /// Obtenir les informations de la wishlist
  Future<Map<String, dynamic>?> getWishlistInfo({
    required int iProfile,
  }) async {
    try {
      final response = await _dio!.get('/get-wishlist-info', queryParameters: {
        'iProfile': iProfile,
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Erreur lors de la récupération des infos wishlist: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getWishlistInfo: $e');
      return null;
    }
  }

  /// Ajouter un article à la wishlist
  Future<Map<String, dynamic>?> addToWishlist({
    required String sCodeArticle,
    required String sPays,
    required double iPrice,
    required int iQuantity,
    dynamic currentIBasket, // ✅ Peut être String (crypté) ou int ou null
    String? iProfile, // ✅ Ajouter iProfile pour le cookie
    String? sPaysLangue, // ✅ Ajouter sPaysLangue
    String? sPaysFav, // ✅ Ajouter sPaysFav
    String sTokenUrl = '',
  }) async {
    print('\n🔥 === API SERVICE - addToWishlist APPELÉ ===');
    try {
      print('🛒 addToWishlist - Données envoyées:');
      print('   sCodeArticle: $sCodeArticle');
      print('   sPays: $sPays');
      print('   iPrice: $iPrice');
      print('   iQuantity: $iQuantity');
      print('   currenentibasket: $currentIBasket (${currentIBasket?.runtimeType})');
      print('   iProfile: $iProfile');
      print('   sPaysLangue: $sPaysLangue');
      print('   sPaysFav: $sPaysFav');

      print('📡 URL complète: ${_dio!.options.baseUrl}/add-product-to-wishlist');
      print('🔄 Envoi de la requête POST...');

      final response = await _dio!.post('/add-product-to-wishlist', data: {
        'sCodeArticle': sCodeArticle,
        'sPays': sPays,
        'iPrice': iPrice,
        'iQuantity': iQuantity,
        'currenentibasket': currentIBasket?.toString() ?? '', // ✅ Toujours envoyer en String
        'iProfile': iProfile ?? '', // ✅ Ajouter iProfile pour le cookie
        'sPaysLangue': sPaysLangue ?? 'FR/FR', // ✅ Ajouter sPaysLangue
        'sPaysFav': sPaysFav ?? '', // ✅ Ajouter sPaysFav
        'sTokenUrl': sTokenUrl,
      });

      print('📡 Réponse reçue - Status: ${response.statusCode}');
      print('📡 Réponse data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ addToWishlist SUCCESS');
        return response.data;
      } else {
        print('❌ addToWishlist - Status code non-200: ${response.statusCode}');
        throw Exception('Erreur lors de l\'ajout à la wishlist: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ERREUR CRITIQUE addToWishlist: $e');
      if (e is DioException) {
        print('❌ DioException - Type: ${e.type}');
        print('❌ DioException - Message: ${e.message}');
        print('❌ DioException - Response: ${e.response?.data}');
      }
      return null;
    }
  }

  /// Récupérer la liste des magasins IKEA
  Future<Map<String, dynamic>> getIkeaStores({
    required double lat,
    required double lng,
  }) async {
    try {
      print('🗺️ ========== GET-IKEA-STORE-LIST ==========');
      print('📍 Paramètres: lat=$lat, lng=$lng');

      // Récupérer iProfile depuis localStorage
      final profile = await LocalStorageService.getProfile();
      final iProfile = profile?['iProfile'] ?? '';

      print('👤 iProfile: $iProfile');

      final response = await _dio!.get(
        '/get-ikea-store-list',  // Sans /api car déjà dans baseUrl
        queryParameters: {
          'lat': lat,
          'lng': lng,
        },
        options: Options(
          headers: {
            'X-IProfile': iProfile,  // Passer iProfile dans les headers
          },
        ),
      );

      print('📡 Response status: ${response.statusCode}');
      print('🏪 Type de réponse: ${response.data.runtimeType}');

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        print('🏪 Nombre de magasins: ${data['stores']?.length ?? 0}');

        if (data['stores'] != null && data['stores'] is List) {
          print('✅ Format: { stores: [...], userLat, userLng }');
          print('📊 Magasins: ${(data['stores'] as List).take(3).map((s) => s['name'] ?? s['sMagasinName']).join(', ')}');
        }

        return data;
      } else if (response.data is List) {
        print('🏪 Nombre de magasins: ${(response.data as List).length}');
        print('✅ Format: Array direct');
        print('📊 Magasins: ${(response.data as List).take(3).map((s) => s['name'] ?? s['sMagasinName']).join(', ')}');

        return {
          'stores': response.data,
          'userLat': lat,
          'userLng': lng,
        };
      }

      return {
        'stores': [],
        'userLat': lat,
        'userLng': lng,
      };
    } catch (e) {
      print('❌ Erreur getIkeaStores: $e');
      if (e is DioException) {
        print('❌ DioException - Type: ${e.type}');
        print('❌ DioException - Message: ${e.message}');
      }
      return {
        'stores': [],
        'userLat': lat,
        'userLng': lng,
      };
    }
  }

  /// Connexion avec code (basé sur SNAL login-with-code.ts)
  /// - Si code est null : Étape 1 (demande du code par email)
  /// - Si code est fourni : Étape 2 (validation du code)
  Future<Map<String, dynamic>> login(String email, {String? code}) async {
    try {
      final isCodeValidation = code != null && code.isNotEmpty;

      if (isCodeValidation) {
        print('🔑 Validation du code pour: $email');
      } else {
        print('📧 Demande de code pour: $email');
      }

      // ✅ MÊME LOGIQUE QUE SNAL : Ne pas envoyer d'identifiants
      // SNAL gère les identifiants côté serveur via les cookies
      final sLangue = 'fr'; // Langue par défaut

      // Construire xXml comme le proxy pour aider SNAL (évite erreurs varbinary)
      String xXml = '';
      try {
        final profile = await LocalStorageService.getProfile();
        final iProfileLocal = profile?['iProfile']?.toString() ?? '0';
        final sPaysLangueLocal = profile?['sPaysLangue']?.toString() ?? '';
        final sPaysFavLocal = profile?['sPaysFav']?.toString() ?? '';

        final xmlIProfile = (iProfileLocal.isEmpty || iProfileLocal == '0') ? '0' : iProfileLocal;
        final xmlSPaysLangue = sPaysLangueLocal;
        final sLang = sLangue;
        final passwordCleaned = code ?? '';
        const sTypeAccount = 'EMAIL';

        xXml = (
          '<root>'
          '<iProfile>' + xmlIProfile + '</iProfile>'
          '<sProvider>magic-link</sProvider>'
          '<email>' + email + '</email>'
          '<code>' + passwordCleaned + '</code>'
          '<sTypeAccount>' + sTypeAccount + '</sTypeAccount>'
          '<iPaysOrigine>' + xmlSPaysLangue + '</iPaysOrigine>'
          '<sLangue>' + xmlSPaysLangue + '</sLangue>'
          '<sPaysListe>' + sPaysFavLocal + '</sPaysListe>'
          '<sPaysLangue>' + xmlSPaysLangue + '</sPaysLangue>'
          '<sCurrentLangue>' + sLang + '</sCurrentLangue>'
          '</root>'
        );
      } catch (e) {
        // Si génération xXml échoue, on continue sans
        xXml = '';
      }

      final response = await _dio!.post(
        '/auth/login-with-code',
        data: {
          'email': email,
          'sLangue': sLangue,
          if (code != null && code.isNotEmpty) 'password': code,
          if (xXml.isNotEmpty) 'xXml': xXml,
        },
      );

      print('✅ Réponse login-with-code: ${response.data}');
      print('🔍 Analyse de la réponse reçue:');
      print('   Type: ${response.data.runtimeType}');
      print('   Contenu: ${response.data}');

      final data = response.data ?? {};

      // ✅ DEBUG: Vérifier si les nouveaux identifiants sont présents
      print('🔍 Vérification des nouveaux identifiants dans la réponse:');
      print('   newIProfile: ${data['newIProfile']}');
      print('   newIBasket: ${data['newIBasket']}');
      print('   iProfile: ${data['iProfile']}');
      print('   iBasket: ${data['iBasket']}');
      print('   Toutes les clés: ${data.keys.toList()}');

      // Si c'est la validation du code (étape 2), sauvegarder le profil
      if (isCodeValidation && data['status'] == 'OK') {
        print('✅ Code validé avec succès');
        print('🔍 Analyse de la réponse reçue du proxy:');
        print('   Réponse complète: $data');
        print('   Clés disponibles: ${data.keys.toList()}');

        // ✅ PRIORITÉ 1: Récupérer les nouveaux identifiants depuis la réponse enrichie du proxy
        String? newIProfile = data['newIProfile']?.toString();
        String? newIBasket = data['newIBasket']?.toString();

        if (newIProfile != null && newIBasket != null) {
          print('✅ Nouveaux identifiants récupérés depuis la réponse enrichie du proxy:');
          print('   newIProfile: $newIProfile');
          print('   newIBasket: $newIBasket');
        } else {
          // ✅ PRIORITÉ 2: Extraire directement depuis les Set-Cookie headers de la réponse
          print('⚠️ Aucun identifiant dans la réponse enrichie, récupération depuis les Set-Cookie headers...');

          try {
            final setCookieHeaders = response.headers['set-cookie'];
            if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
              print('🍪 Set-Cookie headers trouvés: ${setCookieHeaders.length} cookies');
              
              for (final cookieHeader in setCookieHeaders) {
                if (cookieHeader.contains('GuestProfile=')) {
                  print('🎯 Cookie GuestProfile trouvé dans Set-Cookie: $cookieHeader');
                  
                  try {
                    // Extraire la valeur du cookie (format: "GuestProfile=value; Max-Age=...; Path=...")
                    final cookieParts = cookieHeader.split(';');
                    if (cookieParts.isNotEmpty) {
                      final cookiePair = cookieParts[0].trim();
                      if (cookiePair.startsWith('GuestProfile=')) {
                        final cookieValue = cookiePair.substring('GuestProfile='.length);
                        print('🍪 Valeur du cookie (raw): $cookieValue');
                        
                        // Le cookie est URL-encodé, le décoder
                        String decodedValue = Uri.decodeComponent(cookieValue);
                        print('🍪 Cookie décodé (1er): $decodedValue');
                        
                        // Vérifier si un deuxième décodage est nécessaire
                        if (decodedValue.contains('%')) {
                          decodedValue = Uri.decodeComponent(decodedValue);
                          print('🍪 Cookie décodé (2ème): $decodedValue');
                        }
                        
                        // Parser le JSON
                        final guestProfile = jsonDecode(decodedValue);
                        final cookieIProfile = guestProfile['iProfile']?.toString();
                        final cookieIBasket = guestProfile['iBasket']?.toString();
                        
                        print('🔍 Identifiants extraits depuis Set-Cookie:');
                        print('   iProfile: $cookieIProfile');
                        print('   iBasket: $cookieIBasket');
                        
                        if (cookieIProfile != null && cookieIBasket != null &&
                            cookieIProfile.isNotEmpty && cookieIBasket.isNotEmpty &&
                            !cookieIProfile.startsWith('guest_') && !cookieIBasket.startsWith('basket_')) {
                          newIProfile = cookieIProfile;
                          newIBasket = cookieIBasket;
                          
                          print('✅ Nouveaux identifiants récupérés depuis les Set-Cookie headers:');
                          print('   iProfile: $newIProfile');
                          print('   iBasket: $newIBasket');
                          break; // Sortir de la boucle si on a trouvé les nouveaux identifiants
                        } else {
                          print('⚠️ Identifiants vides ou invalides dans le cookie Set-Cookie');
                        }
                      }
                    }
                  } catch (e) {
                    print('⚠️ Erreur lors du décodage du cookie depuis Set-Cookie: $e');
                  }
                }
              }
            }
          } catch (e) {
            print('⚠️ Erreur lors de l\'extraction des Set-Cookie: $e');
          }
          
          // ✅ FALLBACK: Si toujours pas trouvé, essayer depuis les cookies du navigateur/jar
          if (newIProfile == null || newIBasket == null) {
            print('⚠️ Identifiants non trouvés dans Set-Cookie, tentative depuis les cookies stockés...');

          // ✅ PRIORITÉ 3: Récupérer depuis les cookies si pas dans la réponse ni dans Set-Cookie
          if (kIsWeb) {
            print('🍪 Récupération des identifiants depuis les cookies du navigateur...');

            // Essayer plusieurs fois avec des délais pour s'assurer que les cookies sont mis à jour
            for (int attempt = 1; attempt <= 5; attempt++) {
              try {
                print('🔄 Tentative $attempt/5...');

                // Attendre que les cookies soient mis à jour par le proxy
                await Future.delayed(Duration(milliseconds: attempt * 1000));

                final cookies = await _getCookiesFromBrowser();
                print('🍪 Cookies récupérés: $cookies');

                final guestProfileCookie = cookies['GuestProfile'];

                if (guestProfileCookie != null) {
                  print('🍪 Cookie GuestProfile trouvé: $guestProfileCookie');

                  final guestProfile = jsonDecode(guestProfileCookie);
                  final cookieIProfile = guestProfile['iProfile']?.toString();
                  final cookieIBasket = guestProfile['iBasket']?.toString();

                  print('🔍 Identifiants extraits du cookie:');
                  print('   iProfile: $cookieIProfile');
                  print('   iBasket: $cookieIBasket');

                  if (cookieIProfile != null && cookieIBasket != null &&
                      cookieIProfile.isNotEmpty && cookieIBasket.isNotEmpty &&
                      !cookieIProfile.startsWith('guest_') && !cookieIBasket.startsWith('basket_')) {
                    newIProfile = cookieIProfile;
                    newIBasket = cookieIBasket;

                    print('✅ Nouveaux identifiants récupérés depuis les cookies:');
                    print('   iProfile: $newIProfile');
                    print('   iBasket: $newIBasket');
                    break; // Sortir de la boucle si on a trouvé les nouveaux identifiants
                  } else {
                    print('⚠️ Identifiants vides ou invalides dans le cookie, tentative suivante...');
                  }
                } else {
                  print('⚠️ Cookie GuestProfile non trouvé, tentative suivante...');
                }
              } catch (e) {
                print('⚠️ Erreur lors de la tentative $attempt: $e');
              }
            }
          } else {
            // ✅ CORRECTION CRITIQUE: Récupération des identifiants sur mobile
            print('🍪 Récupération des identifiants depuis les cookies sur mobile...');

            // Essayer plusieurs fois avec des délais pour s'assurer que les cookies sont mis à jour
            for (int attempt = 1; attempt <= 5; attempt++) {
              try {
                print('🔄 Tentative mobile $attempt/5...');

                // Attendre que les cookies soient mis à jour
                await Future.delayed(Duration(milliseconds: attempt * 1000));

                // Récupérer les cookies depuis le cookie jar sur mobile
                if (_cookieJar != null) {
                  final apiUrl = Uri.parse('https://jirig.be/api/');
                  final cookies = await _cookieJar!.loadForRequest(apiUrl);
                  print('🍪 Cookies récupérés du cookie jar: ${cookies.map((c) => '${c.name}=${c.value}').join(', ')}');

                  final guestProfileCookie = cookies.firstWhere(
                        (c) => c.name == 'GuestProfile',
                    orElse: () => Cookie('', ''),
                  );

                  if (guestProfileCookie.name.isNotEmpty) {
                    print('🍪 Cookie GuestProfile trouvé: ${guestProfileCookie.value}');

                    try {
                      // ✅ CORRECTION: Le cookie est double-encodé, décoder deux fois
                      String decodedCookieValue = guestProfileCookie.value;

                      // Premier décodage URL
                      decodedCookieValue = Uri.decodeComponent(decodedCookieValue);
                      print('🍪 Cookie décodé (1er): $decodedCookieValue');

                      // Deuxième décodage URL si nécessaire
                      if (decodedCookieValue.contains('%')) {
                        decodedCookieValue = Uri.decodeComponent(decodedCookieValue);
                        print('🍪 Cookie décodé (2ème): $decodedCookieValue');
                      }

                      final guestProfile = jsonDecode(decodedCookieValue);
                      final cookieIProfile = guestProfile['iProfile']?.toString();
                      final cookieIBasket = guestProfile['iBasket']?.toString();

                      print('🔍 Identifiants extraits du cookie mobile:');
                      print('   iProfile: $cookieIProfile');
                      print('   iBasket: $cookieIBasket');

                      if (cookieIProfile != null && cookieIBasket != null &&
                          cookieIProfile.isNotEmpty && cookieIBasket.isNotEmpty &&
                          !cookieIProfile.startsWith('guest_') && !cookieIBasket.startsWith('basket_')) {
                        newIProfile = cookieIProfile;
                        newIBasket = cookieIBasket;

                        print('✅ Nouveaux identifiants récupérés depuis les cookies mobile:');
                        print('   iProfile: $newIProfile');
                        print('   iBasket: $newIBasket');
                        break; // Sortir de la boucle si on a trouvé les nouveaux identifiants
                      } else {
                        print('⚠️ Identifiants vides ou invalides dans le cookie mobile, tentative suivante...');
                      }
                    } catch (e) {
                      print('⚠️ Erreur lors du décodage du cookie mobile: $e');
                    }
                  } else {
                    print('⚠️ Cookie GuestProfile non trouvé dans le cookie jar, tentative suivante...');
                  }
                } else {
                  print('⚠️ Cookie jar non disponible sur mobile');
                }
              } catch (e) {
                print('⚠️ Erreur lors de la tentative mobile $attempt: $e');
              }
            }
          }
          } // Fin du if (newIProfile == null || newIBasket == null) pour le fallback
        }

        if (newIProfile != null && newIBasket != null) {
          print('🔄 Mise à jour des identifiants après connexion:');
          print('   Nouveau iProfile: $newIProfile');
          print('   Nouveau iBasket: $newIBasket');

          // ✅ CORRECTION CRITIQUE: Récupérer TOUTES les infos utilisateur depuis la réponse
          final sEmail = data['sEmail']?.toString();
          final sNom = data['sNom']?.toString();
          final sPrenom = data['sPrenom']?.toString();
          final sPhoto = data['sPhoto']?.toString();

          print('📧 Email dans la réponse: $sEmail');
          print('👤 Nom dans la réponse: $sNom');
          print('👤 Prénom dans la réponse: $sPrenom');

          // Mettre à jour le profil local avec TOUTES les informations
          final currentProfile = await LocalStorageService.getProfile();
          final updatedProfile = {
            ...?currentProfile,
            'iProfile': newIProfile,
            'iBasket': newIBasket,
            // ✅ SAUVEGARDER l'email et les infos utilisateur (CRITIQUE pour isLoggedIn())
            if (sEmail != null && sEmail.isNotEmpty) 'sEmail': sEmail,
            if (sNom != null) 'sNom': sNom,
            if (sPrenom != null) 'sPrenom': sPrenom,
            if (sPhoto != null) 'sPhoto': sPhoto,
          };

          await LocalStorageService.saveProfile(updatedProfile);
          print('💾 Nouveaux identifiants ET infos utilisateur sauvegardés dans le profil local');

          // ✅ FORCER LA MISE À JOUR DES COOKIES
          await _updateCookiesWithNewIdentifiers(newIProfile, newIBasket);

          // ✅ CRITIQUE: Attendre que les cookies soient mis à jour avant de continuer
          print('⏳ Attente de la mise à jour des cookies...');
          await Future.delayed(Duration(seconds: 1));

          print('✅ Connexion réussie - identifiants et infos utilisateur mis à jour');
        } else {
          print('❌ Impossible de récupérer les nouveaux identifiants');
          print('⚠️ Les identifiants ne sont pas disponibles dans la réponse ou les cookies');

          // ✅ CORRECTION CRITIQUE: Sur mobile, forcer la récupération depuis l'API
          if (!kIsWeb) {
            print('🔄 Tentative de récupération forcée depuis l\'API sur mobile...');
            try {
              // Attendre un peu pour que l'API soit mise à jour
              await Future.delayed(Duration(seconds: 2));

              // Récupérer le profil depuis l'API pour obtenir les nouveaux identifiants
              final profileResponse = await getProfile();
              print('🔍 Réponse getProfile: $profileResponse');

              if (profileResponse.isNotEmpty) {
                final apiIProfile = profileResponse['iProfile']?.toString();
                final apiIBasket = profileResponse['iBasket']?.toString();

                if (apiIProfile != null && apiIBasket != null &&
                    apiIProfile.isNotEmpty && apiIBasket.isNotEmpty &&
                    !apiIProfile.startsWith('guest_') && !apiIBasket.startsWith('basket_')) {

                  print('✅ Nouveaux identifiants récupérés depuis l\'API:');
                  print('   iProfile: $apiIProfile');
                  print('   iBasket: $apiIBasket');

                  // ✅ CORRECTION: Récupérer TOUTES les infos utilisateur depuis getProfile()
                  final apiSEmail = profileResponse['sEmail']?.toString();
                  final apiSNom = profileResponse['sNom']?.toString();
                  final apiSPrenom = profileResponse['sPrenom']?.toString();
                  final apiSPhoto = profileResponse['sPhoto']?.toString();

                  print('📧 Email depuis API: $apiSEmail');
                  print('👤 Nom depuis API: $apiSNom');
                  print('👤 Prénom depuis API: $apiSPrenom');

                  // Mettre à jour le profil local avec TOUTES les informations
                  final currentProfile = await LocalStorageService.getProfile();
                  final updatedProfile = {
                    ...?currentProfile,
                    'iProfile': apiIProfile,
                    'iBasket': apiIBasket,
                    // ✅ SAUVEGARDER l'email et les infos utilisateur (CRITIQUE pour isLoggedIn())
                    if (apiSEmail != null && apiSEmail.isNotEmpty) 'sEmail': apiSEmail,
                    if (apiSNom != null) 'sNom': apiSNom,
                    if (apiSPrenom != null) 'sPrenom': apiSPrenom,
                    if (apiSPhoto != null) 'sPhoto': apiSPhoto,
                  };

                  await LocalStorageService.saveProfile(updatedProfile);
                  print('💾 Nouveaux identifiants ET infos utilisateur sauvegardés dans le profil local');

                  // Forcer la mise à jour des cookies
                  await _updateCookiesWithNewIdentifiers(apiIProfile, apiIBasket);

                  print('✅ Connexion réussie - identifiants et infos utilisateur récupérés depuis l\'API');
                } else {
                  print('⚠️ Identifiants invalides dans la réponse API');
                }
              } else {
                print('⚠️ Aucune réponse de l\'API getProfile');
              }
            } catch (e) {
              print('❌ Erreur lors de la récupération forcée depuis l\'API: $e');
            }
          }
        }
      }

      return data;
    } catch (e) {
      print('❌ Erreur lors de la connexion: $e');
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    try {
      print('🚪 Déconnexion...');

      // Supprimer les données locales
      await LocalStorageService.clearProfile();

      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur logout: $e');
      rethrow;
    }
  }

  /// Mettre à jour les cookies avec les nouveaux identifiants
  Future<void> _updateCookiesWithNewIdentifiers(String newIProfile, String newIBasket) async {
    try {
      print('🍪 Mise à jour des cookies avec les nouveaux identifiants...');
      print('🍪 Nouveaux identifiants: iProfile=$newIProfile, iBasket=$newIBasket');

      // Récupérer le profil actuel pour conserver les autres données
      final currentProfile = await LocalStorageService.getProfile();
      final sPaysLangue = currentProfile?['sPaysLangue'] ?? 'FR/FR';
      final sPaysFav = currentProfile?['sPaysFav'] ?? 'FR';

      // Créer le nouveau GuestProfile avec les nouveaux identifiants
      final newGuestProfile = {
        'iProfile': newIProfile,
        'iBasket': newIBasket,
        'sPaysLangue': sPaysLangue,
        'sPaysFav': sPaysFav,
      };

      final guestProfileJson = jsonEncode(newGuestProfile);
      final guestProfileEncoded = Uri.encodeComponent(guestProfileJson);

      print('🍪 Nouveau GuestProfile: $newGuestProfile');
      print('🍪 GuestProfile encodé: $guestProfileEncoded');

      // ✅ CORRECTION CRITIQUE: Mettre à jour les cookies sur mobile
      if (ApiConfig.useCookieManager && _cookieJar != null) {
        print('🍪 Mise à jour du cookie jar sur mobile...');

        // ✅ Méthode 1: Supprimer l'ancien cookie d'abord
        try {
          await _cookieJar!.deleteAll();
          print('🗑️ Anciens cookies supprimés');
        } catch (e) {
          print('⚠️ Erreur lors de la suppression des anciens cookies: $e');
        }

        // ✅ Méthode 2: Créer le nouveau cookie avec les bons paramètres
        final cookie = Cookie('GuestProfile', guestProfileEncoded);
        cookie.domain = 'jirig.be';
        cookie.path = '/';
        cookie.maxAge = 864000; // 10 jours
        cookie.secure = true; // HTTPS requis
        cookie.httpOnly = false; // Accessible depuis JavaScript si nécessaire

        print('🍪 Cookie créé: ${cookie.name}=${cookie.value}');
        print('🍪 Domain: ${cookie.domain}, Path: ${cookie.path}');

        // ✅ Méthode 3: Sauvegarder le cookie avec l'URL complète
        final apiUrl = Uri.parse('https://jirig.be/api/');
        await _cookieJar!.saveFromResponse(apiUrl, [cookie]);

        print('✅ Cookie GuestProfile sauvegardé dans le cookie jar');

        // ✅ Méthode 4: Vérifier que le cookie a été sauvegardé
        try {
          final savedCookies = await _cookieJar!.loadForRequest(apiUrl);
          print('🔍 Cookies sauvegardés: ${savedCookies.map((c) => '${c.name}=${c.value}').join(', ')}');

          final guestProfileCookie = savedCookies.firstWhere(
                (c) => c.name == 'GuestProfile',
            orElse: () => Cookie('', ''),
          );

          if (guestProfileCookie.name.isNotEmpty) {
            print('✅ Cookie GuestProfile confirmé: ${guestProfileCookie.value}');
          } else {
            print('❌ Cookie GuestProfile non trouvé après sauvegarde');
          }
        } catch (e) {
          print('⚠️ Erreur lors de la vérification des cookies: $e');
        }
      } else {
        print('ℹ️ Cookie Manager non disponible (Web ou non initialisé)');
      }

    } catch (e) {
      print('❌ Erreur lors de la mise à jour des cookies: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Récupérer le profil utilisateur (pour vérifier la session)
  Future<Map<String, dynamic>> getProfile() async {
    try {
      print('👤 Récupération du profil utilisateur...');
      print('🔍 Plateforme: ${kIsWeb ? "Web" : "Mobile"}');

      final response = await _dio!.get('/get-info-profil');

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Data Type: ${response.data.runtimeType}');
      print('📦 Response Data: ${response.data}');

      if (response.data != null && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        print('✅ Profil récupéré: ${data.keys.join(', ')}');
        print('📧 Email dans la réponse: ${data['sEmail']}');
        print('👤 Nom dans la réponse: ${data['sNom']}');
        print('👤 Prénom dans la réponse: ${data['sPrenom']}');
        print('🆔 iProfile dans la réponse: ${data['iProfile']}');
        return data;
      }

      print('⚠️ Aucune donnée de profil trouvée');
      return {};
    } catch (e) {
      print('❌ Erreur lors de la récupération du profil: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {};
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      await initialize();

      print('\n' + '='*70);
      print('👤 UPDATE PROFILE: Mise à jour du profil utilisateur');
      print('='*70);
      print('📤 Données envoyées:');
      print('   Prénom: ' + (profileData['Prenom']?.toString() ?? ''));
      print('   Nom: ' + (profileData['Nom']?.toString() ?? ''));
      print('   Email: ' + (profileData['email']?.toString() ?? ''));
      print('   Téléphone: ' + (profileData['tel']?.toString() ?? ''));
      print('   Rue: ' + (profileData['rue']?.toString() ?? ''));
      print('   Code postal: ' + (profileData['zip']?.toString() ?? ''));
      print('   Ville: ' + (profileData['city']?.toString() ?? ''));

      // Récupérer iProfile, iBasket et préférences depuis le stockage local
      final gp = await LocalStorageService.getProfile();
      final iProfile = gp?['iProfile']?.toString();
      final iBasket = gp?['iBasket']?.toString() ?? '';

      // Gérer sPaysFav provenant du payload ou du profil existant
      final payloadPaysFavString = profileData['sPaysFav']?.toString();
      final payloadPaysFavList = (profileData['sPaysFavList'] as List?)
          ?.map((e) => e.toString().toUpperCase())
          .where((code) => code.isNotEmpty)
          .toList();

      final existingPaysFavString = gp?['sPaysFav']?.toString() ?? '';

      final basePaysFavString = payloadPaysFavString != null && payloadPaysFavString.trim().isNotEmpty
          ? payloadPaysFavString
          : existingPaysFavString;

      final basePaysFavListFromString = basePaysFavString
          .split(',')
          .map((code) => code.trim().toUpperCase())
          .where((code) => code.isNotEmpty)
          .toList();

      final effectivePaysFavList = payloadPaysFavList != null && payloadPaysFavList.isNotEmpty
          ? payloadPaysFavList
          : basePaysFavListFromString;

      final effectivePaysFavString = effectivePaysFavList.join(',');

      final sPaysLangue = gp?['sPaysLangue']?.toString() ?? '';

      if (iProfile == null || iProfile.isEmpty) {
        throw Exception('iProfile manquant – impossible de mettre à jour le profil');
      }

      // Mapper les champs Flutter vers le format SNAL (comme le proxy)
      final snalProfileData = {
        'sPaysFav': effectivePaysFavString,
      };

      print('📤 Données mappées SNAL: ' + snalProfileData.toString());
      print('📤 iProfile: $iProfile');
      print('📤 iBasket: $iBasket');
      print('📤 sPaysFav envoyé: $effectivePaysFavList');
      print('📤 sPaysLangue envoyé: $sPaysLangue');

      // ✅ CORRECTION: Ajouter explicitement les headers X-IProfile et X-IBasket
      // Appel direct SNAL (PUT) – l'intercepteur ajoutera GuestProfile aux headers/cookies
      final response = await _dio!.put(
        '/update-info-profil/' + iProfile,
        data: snalProfileData,
        options: Options(
          headers: {
            'X-IProfile': iProfile,
            'X-IBasket': iBasket.isNotEmpty ? iBasket : '0',
            'X-Pays-Langue': sPaysLangue.isNotEmpty ? sPaysLangue : '',
            'X-Pays-Fav': effectivePaysFavString.isNotEmpty ? effectivePaysFavString : '',
          },
        ),
      );

      print('\n📥 Réponse API:');
      print('   Status: ' + (response.statusCode?.toString() ?? ''));

      // Mettre à jour localement les infos connues
      if (response.data is Map<String, dynamic>) {
        final respMap = response.data as Map<String, dynamic>;
        final responsePaysFav = respMap['sPaysFav'];
        final normalizedPaysFav = responsePaysFav is List
            ? responsePaysFav.map((e) => e.toString().toUpperCase()).join(',')
            : responsePaysFav?.toString() ?? effectivePaysFavString;
        final normalizedPaysLangue = respMap['sPaysLangue']?.toString() ?? sPaysLangue;

        await LocalStorageService.saveProfile({
          'iProfile': iProfile,
          'iBasket': gp?['iBasket']?.toString() ?? '',
          'sPaysFav': normalizedPaysFav,
          'sPaysLangue': normalizedPaysLangue,
          'sEmail': respMap['sEmail']?.toString() ?? (profileData['email']?.toString() ?? ''),
          'sNom': respMap['sNom']?.toString() ?? (profileData['Nom']?.toString() ?? ''),
          'sPrenom': respMap['sPrenom']?.toString() ?? (profileData['Prenom']?.toString() ?? ''),
          'sPhoto': respMap['sPhoto']?.toString() ?? '',
        });
        print('✅ Profil mis à jour localement');
      }

      return (response.data as Map).cast<String, dynamic>();
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du profil: ' + e.toString());
      rethrow;
    }
  }

  /// Récupérer les informations utilisateur (comme SNAL)
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      await initialize(); // Ensure Dio is initialized

      print('\n${'='*70}');
      print('👤 GET USER INFO: Récupération des informations utilisateur');
      print('='*70);

      final response = await _dio!.get(
        '/get-info-profil', // Relative URL
      );

      print('\n📥 Réponse API:');
      print('   Status: ${response.statusCode}');
      print('   Data: ${response.data}');

      if (response.statusCode == 200) {
        final userData = response.data as Map<String, dynamic>;
        print('✅ Informations utilisateur récupérées avec succès');
        return userData;
      } else {
        print('⚠️ Statut de réponse inattendu: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des informations utilisateur: $e');
      return null;
    }
  }

  /// Récupère les cookies du navigateur (web uniquement) - Version synchrone
  String _getCookiesFromBrowserSync() {
    if (kIsWeb) {
      try {
        // Utiliser WebUtils pour récupérer les cookies
        return WebUtils.getCookies();
      } catch (e) {
        print('⚠️ Erreur lors de la récupération des cookies: $e');
        return '';
      }
    }
    return '';
  }
}
