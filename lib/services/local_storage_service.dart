import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Service pour gérer le stockage local des informations de profil
/// Remplace les cookies par localStorage pour une approche mobile-first
class LocalStorageService {
  static const String _profileKey = 'user_profile';
  static const String _basketKey = 'user_basket';
  static const String _paysLangueKey = 'user_pays_langue';
  static const String _paysFavKey = 'user_pays_fav';
  static const String _currentRouteKey = 'current_route';
  static const String _selectedCountriesKey = 'selected_countries';
  static const String _lastUpdateCheckKey = 'last_update_check';

  /// Sauvegarder le profil utilisateur
  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();

    print('💾 saveProfile() - Données à sauvegarder:');
    print('   iProfile: ${profile['iProfile']}');
    print('   iBasket: ${profile['iBasket']}');
    print('   sPaysLangue: ${profile['sPaysLangue']}');
    print('   sPaysFav: ${profile['sPaysFav']}');
    print('   sEmail: ${profile['sEmail']}');

    // ✅ CORRECTION: Sauvegarder iProfile/iBasket uniquement s'ils ne sont pas vides
    // Ne pas écraser avec des chaînes vides
    final iProfileValue = profile['iProfile']?.toString() ?? '';
    final iBasketValue = profile['iBasket']?.toString() ?? '';
    
    print('🔍 Vérification des identifiants à sauvegarder:');
    print('   iProfile: "$iProfileValue" (null: ${profile['iProfile'] == null}, empty: ${iProfileValue.isEmpty}, length: ${iProfileValue.length})');
    print('   iBasket: "$iBasketValue" (null: ${profile['iBasket'] == null}, empty: ${iBasketValue.isEmpty}, length: ${iBasketValue.length})');
    
    // ✅ CORRECTION: Sauvegarder iProfile s'il est valide (non vide et non guest_)
    // Les valeurs hexadécimales (varbinary) comme 0x02000000... sont valides et doivent être sauvegardées
    if (iProfileValue.isNotEmpty && !iProfileValue.startsWith('guest_')) {
      await prefs.setString(_profileKey, iProfileValue);
      print('✅ iProfile sauvegardé: $iProfileValue (type: ${iProfileValue.startsWith('0x') ? 'hexadécimal/varbinary' : 'normal'})');
    } else {
      if (iProfileValue.isEmpty) {
        print('⚠️ iProfile vide, non sauvegardé (conservation de la valeur existante)');
      } else {
        print('⚠️ iProfile invalide (guest_), non sauvegardé: $iProfileValue');
      }
    }

    if (iBasketValue.isNotEmpty && !iBasketValue.startsWith('basket_')) {
      await prefs.setString(_basketKey, iBasketValue);
      print('✅ iBasket sauvegardé: $iBasketValue');
    } else {
      if (iBasketValue.isEmpty) {
        print('⚠️ iBasket vide, non sauvegardé (conservation de la valeur existante)');
      } else {
        print('⚠️ iBasket invalide (basket_), non sauvegardé: $iBasketValue');
      }
    }

    // ✅ CORRECTION: Sauvegarder TOUJOURS sPaysLangue et sPaysFav, même s'ils sont vides
    // Cela garantit que les modifications (y compris les suppressions) écrasent les anciennes valeurs
    if (profile['sPaysLangue'] != null) {
      await prefs.setString(_paysLangueKey, profile['sPaysLangue'].toString());
      print('✅ sPaysLangue sauvegardé (écrasement): "${profile['sPaysLangue']}"');
    }

    if (profile['sPaysFav'] != null) {
      await prefs.setString(_paysFavKey, profile['sPaysFav'].toString());
      print('✅ sPaysFav sauvegardé (écrasement): "${profile['sPaysFav']}"');
    }

    // ✅ CORRECTION: Sauvegarder TOUS les champs du profil
    // ÉCRASER les anciennes valeurs même si les nouvelles sont vides pour garantir la mise à jour
    if (profile['sEmail'] != null) {
      await prefs.setString('user_email', profile['sEmail'].toString());
      print('✅ sEmail sauvegardé (écrasement): "${profile['sEmail']}"');
    }

    if (profile['sNom'] != null) {
      await prefs.setString('user_nom', profile['sNom'].toString());
      print('✅ sNom sauvegardé (écrasement): "${profile['sNom']}"');
    }

    if (profile['sPrenom'] != null) {
      await prefs.setString('user_prenom', profile['sPrenom'].toString());
      print('✅ sPrenom sauvegardé (écrasement): "${profile['sPrenom']}"');
    }

    if (profile['sPhoto'] != null) {
      await prefs.setString('user_photo', profile['sPhoto'].toString());
      print('✅ sPhoto sauvegardé (écrasement): "${profile['sPhoto']}"');
    }

    // ✅ Sauvegarder les autres champs (sTel, sRue, sZip, sCity)
    if (profile['sTel'] != null) {
      await prefs.setString('user_tel', profile['sTel'].toString());
      print('✅ sTel sauvegardé (écrasement): "${profile['sTel']}"');
    }

    if (profile['sRue'] != null) {
      await prefs.setString('user_rue', profile['sRue'].toString());
      print('✅ sRue sauvegardé (écrasement): "${profile['sRue']}"');
    }

    if (profile['sZip'] != null) {
      await prefs.setString('user_zip', profile['sZip'].toString());
      print('✅ sZip sauvegardé (écrasement): "${profile['sZip']}"');
    }

    if (profile['sCity'] != null) {
      await prefs.setString('user_city', profile['sCity'].toString());
      print('✅ sCity sauvegardé (écrasement): "${profile['sCity']}"');
    }

    // ✅ Vérification après sauvegarde
    final savedIProfile = prefs.getString(_profileKey);
    final savedIBasket = prefs.getString(_basketKey);
    print('🔍 Vérification après sauvegarde:');
    print('   iProfile sauvegardé: $savedIProfile (null: ${savedIProfile == null}, empty: ${savedIProfile?.isEmpty ?? true})');
    print('   iBasket sauvegardé: $savedIBasket (null: ${savedIBasket == null}, empty: ${savedIBasket?.isEmpty ?? true})');
    
    // ✅ Vérifier que les identifiants attendus ont bien été sauvegardés
    if (iProfileValue.isNotEmpty && !iProfileValue.startsWith('guest_')) {
      if (savedIProfile != iProfileValue) {
        print('❌ ERREUR: iProfile attendu "$iProfileValue" mais sauvegardé "$savedIProfile"');
      } else {
        print('✅ iProfile correctement sauvegardé');
      }
    }
    
    if (iBasketValue.isNotEmpty && !iBasketValue.startsWith('basket_')) {
      if (savedIBasket != iBasketValue) {
        print('❌ ERREUR: iBasket attendu "$iBasketValue" mais sauvegardé "$savedIBasket"');
      } else {
        print('✅ iBasket correctement sauvegardé');
      }
    }
  }

  /// Récupérer le profil utilisateur
  static Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final iProfile = prefs.getString(_profileKey);
    final iBasket = prefs.getString(_basketKey);
    final sPaysLangue = prefs.getString(_paysLangueKey);
    final sPaysFav = prefs.getString(_paysFavKey);

    print('📋 getProfile() - Valeurs récupérées depuis SharedPreferences:');
    print('   iProfile: "$iProfile" (null: ${iProfile == null}, empty: ${iProfile?.isEmpty ?? true}, length: ${iProfile?.length ?? 0})');
    print('   iBasket: "$iBasket" (null: ${iBasket == null}, empty: ${iBasket?.isEmpty ?? true}, length: ${iBasket?.length ?? 0})');
    print('   sPaysLangue: "$sPaysLangue"');
    print('   sPaysFav: "$sPaysFav"');

    if (iProfile == null && iBasket == null) {
      print('❌ getProfile() - Aucun identifiant iProfile/iBasket trouvé dans SharedPreferences');
      return null;
    }

    // ✅ Récupérer tous les champs du profil, même si certains identifiants sont manquants
    final profileResult = <String, dynamic>{
      'iProfile': iProfile ?? '',
      'iBasket': iBasket ?? '',
      'sPaysLangue': sPaysLangue ?? '',
      'sPaysFav': sPaysFav ?? '',
      'sEmail': prefs.getString('user_email') ?? '',
      'sNom': prefs.getString('user_nom') ?? '',
      'sPrenom': prefs.getString('user_prenom') ?? '',
      'sPhoto': prefs.getString('user_photo') ?? '',
      'sTel': prefs.getString('user_tel') ?? '',
      'sRue': prefs.getString('user_rue') ?? '',
      'sZip': prefs.getString('user_zip') ?? '',
      'sCity': prefs.getString('user_city') ?? '',
    };

    print('✅ getProfile() - Profil partiel/complété retourné: iProfile="${profileResult['iProfile']}", iBasket="${profileResult['iBasket']}"');
    print('   sPrenom: "${profileResult['sPrenom']}"');
    print('   sNom: "${profileResult['sNom']}"');
    print('   sEmail: "${profileResult['sEmail']}"');
    print('   sTel: "${profileResult['sTel']}"');
    print('   sRue: "${profileResult['sRue']}"');
    print('   sZip: "${profileResult['sZip']}"');
    print('   sCity: "${profileResult['sCity']}"');
    return profileResult;
  }

  /// Créer un profil invité par défaut (comme SNAL)
  static Future<Map<String, dynamic>> createGuestProfile() async {
    try {
      // ✅ Initialiser via l'API SNAL pour générer les vrais identifiants
      final apiService = ApiService();
      await apiService.initialize();

      final response = await apiService.initializeUserProfile(
        sPaysLangue: '', // ✅ Pas de valeur par défaut
        sPaysFav: [], // ✅ Pas de valeur par défaut
        bGeneralConditionAgree: true,
      );

      if (response != null && response is Map<String, dynamic>) {
        final iProfile = response['iProfile']?.toString() ?? '';
        final iBasket = response['iBasket']?.toString() ?? '';
        final sPaysLangue = response['sPaysLangue']?.toString() ?? '';
        final sPaysFav = response['sPaysFav']?.toString() ?? '';

        final guestProfile = {
          'iProfile': iProfile,
          'iBasket': iBasket,
          // ✅ Sauvegarder sPaysLangue et sPaysFav seulement s'ils ne sont pas vides
          if (sPaysLangue.isNotEmpty) 'sPaysLangue': sPaysLangue,
          if (sPaysFav.isNotEmpty) 'sPaysFav': sPaysFav,
        };

        await saveProfile(guestProfile);
        print('✅ Profil invité initialisé via API SNAL: iProfile=$iProfile, iBasket=$iBasket');

        return guestProfile;
      }
    } catch (e) {
      print('⚠️ Erreur lors de l\'initialisation via API, fallback vers profil par défaut: $e');
    }

    // Fallback: créer un profil par défaut avec des identifiants vides
    final guestProfile = {
      'iProfile': '', // Utiliser des identifiants vides pour que SNAL les crée
      'iBasket': '',  // Utiliser des identifiants vides pour que SNAL les crée
      // ✅ Pas de valeurs par défaut pour sPaysLangue et sPaysFav
    };

    await saveProfile(guestProfile);

    return guestProfile;
  }

  /// Vérifier si un profil existe
  static Future<bool> hasProfile() async {
    final profile = await getProfile();
    return profile != null;
  }

  /// Supprimer le profil (logout) - Conserve iProfile et iBasket
  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ Ne pas supprimer iProfile et iBasket - ils doivent persister après déconnexion
    // await prefs.remove(_profileKey);
    // await prefs.remove(_basketKey);
    
    // ✅ Conserver sPaysLangue et sPaysFav aussi
    // await prefs.remove(_paysLangueKey);
    // await prefs.remove(_paysFavKey);
    
    // ✅ Supprimer uniquement les informations de l'utilisateur connecté
    await prefs.remove('user_email');
    await prefs.remove('user_nom');
    await prefs.remove('user_prenom');
    await prefs.remove('user_photo');
    
    print('✅ Déconnexion: iProfile et iBasket conservés, informations utilisateur supprimées');
  }

  /// Vérifier si l'utilisateur est connecté (a un email sauvegardé)
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    print('🔍 isLoggedIn() - Email: $email');
    return email != null && email.isNotEmpty;
  }

  /// Récupérer les informations complètes de l'utilisateur
  static Future<Map<String, String>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString('user_email');
    final nom = prefs.getString('user_nom');
    final prenom = prefs.getString('user_prenom');
    final photo = prefs.getString('user_photo');

    print('🔍 getUserInfo() - Email: $email');
    print('🔍 getUserInfo() - Nom: $nom');
    print('🔍 getUserInfo() - Prénom: $prenom');
    print('🔍 getUserInfo() - Photo: $photo');

    if (email == null) {
      print('❌ getUserInfo() - Aucun email trouvé, utilisateur non connecté');
      return null;
    }

    final userInfo = {
      'email': email,
      'nom': nom ?? '',
      'prenom': prenom ?? '',
      'photo': photo ?? '',
    };

    print('✅ getUserInfo() - Informations utilisateur: $userInfo');
    return userInfo;
  }

  /// Initialiser le profil (créer un invité si nécessaire)
  static Future<Map<String, dynamic>> initializeProfile() async {
    final existingProfile = await getProfile();

    if (existingProfile != null) {
      return existingProfile;
    }

    return await createGuestProfile();
  }

  /// ✅ Sauvegarder la route actuelle
  static Future<void> saveCurrentRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentRouteKey, route);
    print('💾 Route sauvegardée: $route');
  }

  /// ✅ Récupérer la route actuelle
  static Future<String?> getCurrentRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString(_currentRouteKey);
    print('📖 Route récupérée: $route');
    return route;
  }

  /// ✅ Effacer la route actuelle
  static Future<void> clearCurrentRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentRouteKey);
    print('🗑️ Route effacée');
  }

  /// ✅ Gérer le callBackUrl comme SNAL
  static Future<void> saveCallBackUrl(String callBackUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('callback_url', callBackUrl);
    print('💾 CallBackUrl sauvegardé: $callBackUrl');
  }

  /// ✅ Récupérer le callBackUrl comme SNAL
  static Future<String?> getCallBackUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final callBackUrl = prefs.getString('callback_url');
    print('📖 CallBackUrl récupéré: $callBackUrl');
    return callBackUrl;
  }

  /// ✅ Effacer le callBackUrl
  static Future<void> clearCallBackUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('callback_url');
    print('🗑️ CallBackUrl effacé');
  }

  /// ✅ Sauvegarder les pays sélectionnés dans le modal de gestion
  static Future<void> saveSelectedCountries(List<String> countries) async {
    final prefs = await SharedPreferences.getInstance();
    final countriesString = countries.join(',');
    await prefs.setString(_selectedCountriesKey, countriesString);
    print('💾 Pays sélectionnés sauvegardés: $countriesString');
  }

  /// ✅ Récupérer les pays sélectionnés depuis le modal de gestion
  static Future<List<String>> getSelectedCountries() async {
    final prefs = await SharedPreferences.getInstance();
    final countriesString = prefs.getString(_selectedCountriesKey);
    if (countriesString != null && countriesString.isNotEmpty) {
      final countries = countriesString.split(',').where((c) => c.isNotEmpty).toList();
      print('📖 Pays sélectionnés récupérés: $countries');
      return countries;
    }
    print('📖 Aucun pays sélectionné trouvé');
    return [];
  }

  /// ✅ Effacer les pays sélectionnés
  static Future<void> clearSelectedCountries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedCountriesKey);
    print('🗑️ Pays sélectionnés effacés');
  }

  /// ✅ Sauvegarder la date de la dernière vérification de mise à jour
  static Future<void> saveLastUpdateCheck(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUpdateCheckKey, dateTime.toIso8601String());
    print('💾 Dernière vérification de mise à jour sauvegardée: ${dateTime.toIso8601String()}');
  }

  /// ✅ Récupérer la date de la dernière vérification de mise à jour
  static Future<DateTime?> getLastUpdateCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastUpdateCheckKey);
    if (dateString != null && dateString.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(dateString);
        print('📖 Dernière vérification de mise à jour: ${dateTime.toIso8601String()}');
        return dateTime;
      } catch (e) {
        print('❌ Erreur parsing date: $e');
        return null;
      }
    }
    print('📖 Aucune vérification de mise à jour trouvée');
    return null;
  }

  /// ✅ Vérifier si on doit vérifier les mises à jour (évite trop de requêtes)
  /// Retourne true si la dernière vérification date de plus de [hours] heures
  static Future<bool> shouldCheckForUpdate({int hours = 24}) async {
    final lastCheck = await getLastUpdateCheck();
    if (lastCheck == null) {
      return true; // Jamais vérifié, donc oui
    }
    final now = DateTime.now();
    final difference = now.difference(lastCheck);
    final shouldCheck = difference.inHours >= hours;
    print('🔍 Dernière vérification: ${difference.inHours}h - Doit vérifier: $shouldCheck');
    return shouldCheck;
  }
}
