
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../models/country.dart';
import '../services/local_storage_service.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../config/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = true; // Mode édition activé par défaut
  bool _isSaving = false;
  Country? _selectedCountry;
  
  // Controllers pour les champs du formulaire
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _rueController = TextEditingController();
  final _zipController = TextEditingController();
  final _cityController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _rueController.dispose();
    _zipController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      print('🔄 Chargement du profil utilisateur...');
      
      // ✅ CORRECTION: Charger D'ABORD depuis localStorage pour afficher immédiatement les modifications récentes
      final profile = await LocalStorageService.getProfile();
      print('📱 Données depuis localStorage: $profile');
      
      if (profile != null && mounted) {
        final normalizedProfile = Map<String, dynamic>.from(profile);
        normalizedProfile['sPaysFav'] =
            _normalizeCountriesString(profile['sPaysFav']?.toString() ?? '');

        setState(() {
          _profile = normalizedProfile;
          _isLoading = false;
          
          // Initialiser les controllers avec les données du profil
          _prenomController.text = normalizedProfile['sPrenom'] ?? '';
          _nomController.text = normalizedProfile['sNom'] ?? '';
          _emailController.text = normalizedProfile['sEmail'] ?? '';
          _telController.text = normalizedProfile['sTel'] ?? '';
          _rueController.text = normalizedProfile['sRue'] ?? '';
          _zipController.text = normalizedProfile['sZip'] ?? '';
          _cityController.text = normalizedProfile['sCity'] ?? '';
        });
      }

      final settingsService = SettingsService();
      final selected = await settingsService.getSelectedCountry();
      if (mounted) {
        Map<String, dynamic>? updatedProfileForStorage;
        setState(() {
          _selectedCountry = selected;
          if (selected != null) {
            final langue = selected.sPaysLangue ?? '${selected.sPays}/fr';
            updatedProfileForStorage = {
              ...?_profile,
              'sPaysLangue': langue,
            };
            _profile = updatedProfileForStorage;
          }
        });
        if (selected != null && updatedProfileForStorage != null) {
          await LocalStorageService.saveProfile(updatedProfileForStorage!);
        }
      }
      
      // ✅ Synchroniser avec l'API en arrière-plan (sans écraser les données locales immédiatement)
      final apiService = Provider.of<ApiService>(context, listen: false);
      final isLoggedIn = await LocalStorageService.isLoggedIn();
      
      if (isLoggedIn) {
        // Synchroniser en arrière-plan sans bloquer l'UI
        _syncProfileWithAPI();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement du profil: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// Synchroniser le profil avec l'API en arrière-plan
  Future<void> _syncProfileWithAPI() async {
    try {
      print('📡 Synchronisation du profil avec l\'API en arrière-plan...');
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Récupérer le profil depuis l'API
      final apiProfile = await apiService.getProfile();
      
      if (apiProfile.isNotEmpty) {
        print('✅ Données récupérées depuis l\'API: $apiProfile');
        
        // ✅ CORRECTION: Les données locales ont TOUJOURS priorité sur les données API
        // Ne jamais écraser les modifications locales avec les données API
        final currentProfile = await LocalStorageService.getProfile();
        if (currentProfile != null) {
          // Fusionner: garder TOUTES les données locales, ne mettre à jour que les identifiants critiques
          final mergedProfile = Map<String, dynamic>.from(currentProfile);
          
          // ✅ Toujours mettre à jour iProfile et iBasket depuis l'API (identifiants critiques)
          mergedProfile['iProfile'] = apiProfile['iProfile']?.toString() ?? mergedProfile['iProfile'] ?? '';
          mergedProfile['iBasket'] = apiProfile['iBasket']?.toString() ?? mergedProfile['iBasket'] ?? '';
          
          // ✅ NE PAS modifier sPaysFav et sPaysLangue - les données locales ont priorité absolue
          // Ces champs sont modifiés par l'utilisateur et doivent être conservés
          
          // ✅ Mettre à jour uniquement les champs qui sont vides dans le localStorage
          // Si un champ a une valeur locale (même vide mais défini), on le garde
          if ((mergedProfile['sEmail']?.toString().isEmpty ?? true) && 
              (apiProfile['sEmail']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sEmail'] = apiProfile['sEmail']?.toString() ?? '';
          }
          if ((mergedProfile['sNom']?.toString().isEmpty ?? true) && 
              (apiProfile['sNom']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sNom'] = apiProfile['sNom']?.toString() ?? '';
          }
          if ((mergedProfile['sPrenom']?.toString().isEmpty ?? true) && 
              (apiProfile['sPrenom']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sPrenom'] = apiProfile['sPrenom']?.toString() ?? '';
          }
          if ((mergedProfile['sTel']?.toString().isEmpty ?? true) && 
              (apiProfile['sTel']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sTel'] = apiProfile['sTel']?.toString() ?? '';
          }
          if ((mergedProfile['sRue']?.toString().isEmpty ?? true) && 
              (apiProfile['sRue']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sRue'] = apiProfile['sRue']?.toString() ?? '';
          }
          if ((mergedProfile['sZip']?.toString().isEmpty ?? true) && 
              (apiProfile['sZip']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sZip'] = apiProfile['sZip']?.toString() ?? '';
          }
          if ((mergedProfile['sCity']?.toString().isEmpty ?? true) && 
              (apiProfile['sCity']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sCity'] = apiProfile['sCity']?.toString() ?? '';
          }
          if ((mergedProfile['sPhoto']?.toString().isEmpty ?? true) && 
              (apiProfile['sPhoto']?.toString().isNotEmpty ?? false)) {
            mergedProfile['sPhoto'] = apiProfile['sPhoto']?.toString() ?? '';
          }
          
          // ✅ Sauvegarder le profil fusionné (les données locales sont préservées)
          await LocalStorageService.saveProfile(mergedProfile);
          
          print('✅ Profil synchronisé avec l\'API (données locales préservées)');
          print('   sPaysFav local: ${mergedProfile['sPaysFav']}');
          print('   sPaysLangue local: ${mergedProfile['sPaysLangue']}');
        } else {
          // Si pas de profil local, sauvegarder directement depuis l'API
          await LocalStorageService.saveProfile({
            'iProfile': apiProfile['iProfile']?.toString() ?? '',
            'iBasket': apiProfile['iBasket']?.toString() ?? '',
            'sPaysFav': apiProfile['sPaysFav']?.toString() ?? '',
            'sPaysLangue': apiProfile['sPaysLangue']?.toString() ?? '',
            'sEmail': apiProfile['sEmail']?.toString() ?? '',
            'sNom': apiProfile['sNom']?.toString() ?? '',
            'sPrenom': apiProfile['sPrenom']?.toString() ?? '',
            'sPhoto': apiProfile['sPhoto']?.toString() ?? '',
            'sTel': apiProfile['sTel']?.toString() ?? '',
            'sRue': apiProfile['sRue']?.toString() ?? '',
            'sZip': apiProfile['sZip']?.toString() ?? '',
            'sCity': apiProfile['sCity']?.toString() ?? '',
          });
        }
      }
    } catch (apiError) {
      // ✅ En cas d'erreur API, on garde les données locales (déjà affichées)
      print('⚠️ Erreur lors de la synchronisation avec l\'API (données locales conservées): $apiError');
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // ✅ CORRECTION: Récupérer TOUTES les valeurs actuelles depuis le localStorage
      // pour garantir qu'on ne perd aucune donnée existante
      final currentProfile = await LocalStorageService.getProfile();
      final token = currentProfile?['token'] ?? '';
      
      // ✅ CORRECTION: Sauvegarder TOUTES les données du profil, y compris pays favoris et pays principal
      final updateData = {
        'Prenom': _prenomController.text,
        'Nom': _nomController.text,
        'email': _emailController.text,
        'tel': _telController.text,
        'rue': _rueController.text,
        'zip': _zipController.text,
        'city': _cityController.text,
        'token': token,
      };
      
      // ✅ CORRECTION: Partir de TOUTES les valeurs actuelles du localStorage
      // pour garantir qu'on ne perd aucune donnée existante (même si elle n'est pas dans _profile)
      final updatedLocalProfile = Map<String, dynamic>.from(currentProfile ?? {});
      updatedLocalProfile['sPaysFav'] = _normalizeCountriesString(
        updatedLocalProfile['sPaysFav']?.toString() ??
            _profile?['sPaysFav']?.toString() ??
            '',
      );
      if (_selectedCountry != null) {
        updatedLocalProfile['sPaysLangue'] =
            _selectedCountry!.sPaysLangue ?? '${_selectedCountry!.sPays}/fr';
      }
      
      // ✅ Mettre à jour uniquement les champs modifiés dans le formulaire
      // Les autres champs conservent leurs valeurs actuelles depuis le localStorage
      updatedLocalProfile['sPrenom'] = _prenomController.text;
      updatedLocalProfile['sNom'] = _nomController.text;
      updatedLocalProfile['sEmail'] = _emailController.text;
      updatedLocalProfile['sTel'] = _telController.text;
      updatedLocalProfile['sRue'] = _rueController.text;
      updatedLocalProfile['sZip'] = _zipController.text;
      updatedLocalProfile['sCity'] = _cityController.text;
      
      // ✅ Conserver les pays favoris et le pays principal depuis le localStorage actuel
      // (ils ne sont pas modifiés dans le formulaire mais doivent être conservés)
      // Si ces valeurs ne sont pas dans currentProfile, elles seront conservées depuis _profile
      if (!updatedLocalProfile.containsKey('sPaysFav') || updatedLocalProfile['sPaysFav'] == null) {
        updatedLocalProfile['sPaysFav'] = _profile?['sPaysFav'] ?? '';
      }
      if (!updatedLocalProfile.containsKey('sPaysLangue') || updatedLocalProfile['sPaysLangue'] == null) {
        updatedLocalProfile['sPaysLangue'] = _profile?['sPaysLangue'] ?? '';
      }
      
      await LocalStorageService.saveProfile(updatedLocalProfile);
      
      // ✅ Mettre à jour via l'API (qui utilisera les pays favoris et pays principal depuis localStorage)
      final response = await apiService.updateProfile(updateData);
      
          if (mounted) {
        setState(() => _isSaving = false);
        
        // Vérifier si la réponse indique un succès
        // L'API peut retourner un objet avec success: true ou simplement un statut 200
        final isSuccess = response['success'] == true || 
                         response['status'] == 'OK' ||
                         (response is Map && response.isNotEmpty);
        
        if (isSuccess) {
          // ✅ CORRECTION: Sauvegarder explicitement les nouvelles données dans localStorage APRÈS le succès API
          // pour s'assurer que les données modifiées sont bien persistées et ÉCRASENT les anciennes
          // Utiliser les valeurs des controllers (nouvelles modifications) comme source de vérité
          final finalProfile = Map<String, dynamic>.from(updatedLocalProfile);
          finalProfile['sPaysFav'] = _normalizeCountriesString(
            finalProfile['sPaysFav']?.toString() ??
                _profile?['sPaysFav']?.toString() ??
                '',
          );
          
          // ✅ FORCER l'écrasement de TOUTES les données modifiées, même si elles sont vides
          // Cela garantit que les anciennes données sont remplacées par les nouvelles
          finalProfile['sPrenom'] = _prenomController.text;
          finalProfile['sNom'] = _nomController.text;
          finalProfile['sEmail'] = _emailController.text;
          finalProfile['sTel'] = _telController.text; // ✅ Écraser même si vide
          finalProfile['sRue'] = _rueController.text; // ✅ Écraser même si vide
          finalProfile['sZip'] = _zipController.text; // ✅ Écraser même si vide
          finalProfile['sCity'] = _cityController.text; // ✅ Écraser même si vide
          
          // ✅ Sauvegarder dans localStorage avec les nouvelles données
          // Cela ÉCRASE les anciennes données dans le localStorage
          await LocalStorageService.saveProfile(finalProfile);
          
          print('✅ Profil sauvegardé dans localStorage:');
          print('   sPrenom: ${finalProfile['sPrenom']}');
          print('   sNom: ${finalProfile['sNom']}');
          print('   sEmail: ${finalProfile['sEmail']}');
          print('   sTel: ${finalProfile['sTel']}');
          print('   sRue: ${finalProfile['sRue']}');
          print('   sZip: ${finalProfile['sZip']}');
          print('   sCity: ${finalProfile['sCity']}');
          print('   sPaysFav: ${finalProfile['sPaysFav']}');
          print('   sPaysLangue: ${finalProfile['sPaysLangue']}');
          
          // ✅ Mettre à jour le state local avec les nouvelles données
          setState(() {
            _profile = finalProfile;
            _isEditing = false;
          });
          
          // ✅ Ne PAS recharger depuis l'API immédiatement car cela pourrait écraser les nouvelles données
          // Les données locales sont déjà sauvegardées et sont la source de vérité
          // Le rechargement depuis l'API se fera lors du prochain chargement de l'écran
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(Provider.of<TranslationService>(context, listen: false).translateFromBackend('PROFILE_UPDATED')),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            
            // ✅ Rediriger vers profile_detail_screen après 1 seconde pour voir les mises à jour
            Future.delayed(const Duration(seconds: 1), () async {
              if (mounted) {
                try {
                  await LocalStorageService.saveCurrentRoute('/profil');
                } catch (_) {}
                context.go('/profil');
              }
            });
          }
        } else {
          // Afficher un message d'erreur si la réponse n'indique pas un succès
          final errorMessage = response['message'] ?? 
                              response['error'] ?? 
                              Provider.of<TranslationService>(context, listen: false).translateFromBackend('PROFILE_UPDATE_ERROR');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde du profil: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        
        // Extraire un message d'erreur plus clair
        String errorMessage = 'Erreur lors de la mise à jour du profil';
        
        if (e is DioException) {
          if (e.response != null) {
            final responseData = e.response?.data;
            if (responseData is Map) {
              errorMessage = responseData['message'] ?? 
                           responseData['error'] ?? 
                           'Erreur serveur (${e.response?.statusCode})';
            } else {
              errorMessage = 'Erreur serveur (${e.response?.statusCode})';
            }
          } else {
            errorMessage = 'Erreur de connexion. Vérifiez votre connexion internet.';
          }
        } else {
          errorMessage = e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  void _toggleEditMode() {
    setState(() {
      if (_isEditing) {
        // Annuler: recharger les données originales
        _prenomController.text = _profile?['sPrenom'] ?? '';
        _nomController.text = _profile?['sNom'] ?? '';
        _emailController.text = _profile?['sEmail'] ?? '';
        _telController.text = _profile?['sTel'] ?? '';
        _rueController.text = _profile?['sRue'] ?? '';
        _zipController.text = _profile?['sZip'] ?? '';
        _cityController.text = _profile?['sCity'] ?? '';
      }
      _isEditing = !_isEditing;
    });
  }

  /// Obtenir le code de pays depuis sPaysLangue
  String _getCountryCodeFromLangue(String langue) {
    if (langue.contains('/')) {
      return langue.split('/')[0];
    }
    if (langue.contains('-')) {
      return langue.split('-')[0];
    }
    return 'FR'; // Default
  }

  /// Obtenir le nom du pays depuis le code
  String _getCountryNameFromCode(String code) {
    switch (code.toUpperCase()) {
      case 'FR':
        return 'France';
      case 'DE':
        return 'Deutschland';
      case 'BE':
        return 'Belgique/België';
      case 'ES':
        return 'España';
      case 'IT':
        return 'Italia';
      case 'NL':
        return 'Nederland';
      case 'PT':
        return 'Portugal';
      case 'LU':
        return 'Luxembourg';
      default:
        return code;
    }
  }

  String _normalizeCountriesString(String raw) {
    if (raw.isEmpty) return '';
    final sanitized = raw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
    final codes = sanitized
        .split(',')
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList();
    return codes.join(',');
  }

  /// Obtenir le chemin du drapeau
  String _getFlagPath(String countryCode) {
    return 'img/flags/${countryCode.toUpperCase()}.PNG';
  }

  /// Obtenir tous les pays disponibles pour les favoris
  List<String> _getAllAvailableCountries() {
    return ['FR', 'BE', 'NL', 'DE', 'ES', 'IT', 'PT'];
  }

  /// Afficher le dialogue de sélection du pays principal
  void _showCountrySelectionDialog(bool isMobile) {
    final availableCountries = [
      {'code': 'FR', 'name': 'France', 'langue': 'FR/fr'},
      {'code': 'BE', 'name': 'Belgique', 'langue': 'BE/fr'},
      {'code': 'NL', 'name': 'Pays-Bas', 'langue': 'NL/nl'},
      {'code': 'DE', 'name': 'Allemagne', 'langue': 'DE/de'},
      {'code': 'LU', 'name': 'Luxembourg', 'langue': 'LU/fr'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sélectionner le pays principal',
          style: TextStyle(fontSize: isMobile ? 18 : 20),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableCountries.length,
            itemBuilder: (context, index) {
              final country = availableCountries[index];
              final isSelected = _profile?['sPaysLangue'] == country['langue'];
              
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected ? Border.all(color: const Color(0xFF3B82F6), width: 2) : null,
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      _getFlagPath(country['code']!),
                      width: 32,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 32,
                          height: 24,
                          color: Colors.grey[200],
                          child: Icon(Icons.flag, size: 16),
                        );
                      },
                    ),
                  ),
                  title: Text(
                    country['name']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF3B82F6)) : null,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _updateMainCountry(country['langue']!);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Afficher le dialogue de sélection des pays favoris
  void _showFavoriteCountriesDialog(bool isMobile) {
    final availableCountries = [
      {'code': 'FR', 'name': 'France'},
      {'code': 'BE', 'name': 'Belgique'},
      {'code': 'NL', 'name': 'Pays-Bas'},
      {'code': 'DE', 'name': 'Allemagne'},
      {'code': 'ES', 'name': 'Espagne'},
      {'code': 'IT', 'name': 'Italie'},
      {'code': 'PT', 'name': 'Portugal'},
    ];

    final currentFavorites = (_profile?['sPaysFav'] ?? '').split(',')
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Sélectionner les pays favoris',
              style: TextStyle(fontSize: isMobile ? 18 : 20),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableCountries.length,
                itemBuilder: (context, index) {
                  final country = availableCountries[index];
                  final isSelected = currentFavorites.contains(country['code']!.toUpperCase());
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: const Color(0xFF3B82F6), width: 2) : null,
                    ),
                    child: CheckboxListTile(
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          ApiConfig.getProxiedImageUrl('https://jirig.be/img/flags/${country['code']!.toUpperCase()}.PNG'),
                          width: 32,
                          height: 24,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 32,
                              height: 24,
                              color: Colors.grey[200],
                              child: Icon(Icons.flag, size: 16),
                            );
                          },
                        ),
                      ),
                      title: Text(
                        country['name']!,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
                        ),
                      ),
                      value: isSelected,
                      activeColor: const Color(0xFF3B82F6),
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            currentFavorites.add(country['code']!.toUpperCase());
                          } else {
                            currentFavorites.remove(country['code']!.toUpperCase());
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  Provider.of<TranslationService>(context).translateFromBackend('WISHLIST_Msg30'),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final newFavorites = currentFavorites.join(',');
                  await _updateFavoriteCountries(newFavorites);
                },
                child: const Text('Sauvegarder'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Mettre à jour le pays principal
  Future<void> _updateMainCountry(String newCountryLangue) async {
    try {
      // ✅ CORRECTION: Récupérer le profil COMPLET depuis localStorage avant de modifier
      final currentProfile = await LocalStorageService.getProfile();
      if (currentProfile == null) {
        print('❌ Impossible de récupérer le profil depuis localStorage');
        return;
      }
      
      // Mettre à jour le profil local avec TOUTES les données existantes
      final updatedProfile = Map<String, dynamic>.from(currentProfile);
      updatedProfile['sPaysLangue'] = newCountryLangue;
      
      // ✅ Sauvegarder immédiatement dans localStorage
      await LocalStorageService.saveProfile(updatedProfile);
      
      setState(() {
        _profile = updatedProfile;
      });
      
      // ✅ CORRECTION: Synchroniser avec l'API si l'utilisateur est connecté
      final isLoggedIn = await LocalStorageService.isLoggedIn();
      if (isLoggedIn) {
        // Synchroniser avec l'API en arrière-plan (sans bloquer l'UI)
        _syncMainCountryWithAPI(newCountryLangue);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du pays principal: $e');
    }
  }
  
  /// Synchroniser le pays principal avec l'API en arrière-plan
  Future<void> _syncMainCountryWithAPI(String newCountryLangue) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // ✅ CORRECTION: Récupérer le profil depuis localStorage (qui contient les nouvelles données)
      final currentProfile = await LocalStorageService.getProfile();
      if (currentProfile == null) {
        print('❌ Impossible de récupérer le profil depuis localStorage pour la synchronisation');
        return;
      }
      
      // ✅ CORRECTION: Utiliser les données du localStorage (qui contient les dernières modifications)
      // plutôt que _profile qui peut être obsolète
      final updateData = {
        'Prenom': currentProfile['sPrenom']?.toString() ?? '',
        'Nom': currentProfile['sNom']?.toString() ?? '',
        'email': currentProfile['sEmail']?.toString() ?? '',
        'tel': currentProfile['sTel']?.toString() ?? '',
        'rue': currentProfile['sRue']?.toString() ?? '',
        'zip': currentProfile['sZip']?.toString() ?? '',
        'city': currentProfile['sCity']?.toString() ?? '',
        'token': currentProfile['token']?.toString() ?? '',
      };
      
      print('📤 Synchronisation pays principal avec l\'API:');
      print('   sPaysLangue depuis localStorage: ${currentProfile['sPaysLangue']}');
      print('   sPaysFav depuis localStorage: ${currentProfile['sPaysFav']}');
      
      // Mettre à jour via l'API (qui utilisera sPaysLangue et sPaysFav depuis localStorage)
      final response = await apiService.updateProfile(updateData);
      
      if (response['success'] == true || response['status'] == 'OK' || response.isNotEmpty) {
        print('✅ Pays principal synchronisé avec l\'API');
        // ✅ Ne PAS recharger le profil depuis l'API pour éviter d'écraser les modifications locales
        // Les modifications locales sont déjà sauvegardées dans localStorage
      } else {
        print('⚠️ La mise à jour locale a été conservée, mais la synchronisation avec l\'API a échoué');
      }
    } catch (e) {
      // ✅ En cas d'erreur API, on garde la mise à jour locale
      print('⚠️ Erreur lors de la synchronisation du pays principal avec l\'API (mise à jour locale conservée): $e');
    }
  }

  /// Mettre à jour les pays favoris
  Future<void> _updateFavoriteCountries(String newFavorites) async {
    try {
      // ✅ CORRECTION: Récupérer le profil COMPLET depuis localStorage avant de modifier
      final currentProfile = await LocalStorageService.getProfile();
      if (currentProfile == null) {
        print('❌ Impossible de récupérer le profil depuis localStorage');
        return;
      }
      
      // Mettre à jour le profil local avec TOUTES les données existantes
      final updatedProfile = Map<String, dynamic>.from(currentProfile);
      final normalizedFavorites = _normalizeCountriesString(newFavorites);
      updatedProfile['sPaysFav'] = normalizedFavorites;
      
      // ✅ Sauvegarder immédiatement dans localStorage
      await LocalStorageService.saveProfile(updatedProfile);
      
      setState(() {
        _profile = updatedProfile;
      });
      
      // Vérifier si l'utilisateur est connecté pour synchroniser avec l'API
      final isLoggedIn = await LocalStorageService.isLoggedIn();
      
      if (isLoggedIn) {
        // ✅ Synchroniser avec l'API en arrière-plan (sans bloquer l'UI)
        _syncFavoriteCountriesWithAPI(normalizedFavorites);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour des pays favoris: $e');
    }
  }
  
  /// Synchroniser les pays favoris avec l'API en arrière-plan
  Future<void> _syncFavoriteCountriesWithAPI(String newFavorites) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // ✅ CORRECTION: Récupérer le profil depuis localStorage (qui contient les nouvelles données)
      final currentProfile = await LocalStorageService.getProfile();
      if (currentProfile == null) {
        print('❌ Impossible de récupérer le profil depuis localStorage pour la synchronisation');
        return;
      }
      
      // ✅ CORRECTION: Utiliser les données du localStorage (qui contient les dernières modifications)
      // plutôt que _profile qui peut être obsolète
      final updateData = {
        'Prenom': currentProfile['sPrenom']?.toString() ?? '',
        'Nom': currentProfile['sNom']?.toString() ?? '',
        'email': currentProfile['sEmail']?.toString() ?? '',
        'tel': currentProfile['sTel']?.toString() ?? '',
        'rue': currentProfile['sRue']?.toString() ?? '',
        'zip': currentProfile['sZip']?.toString() ?? '',
        'city': currentProfile['sCity']?.toString() ?? '',
        'token': currentProfile['token']?.toString() ?? '',
        'sPaysFav': currentProfile['sPaysFav']?.toString() ?? '',
        'sPaysFavList': (currentProfile['sPaysFav']?.toString() ?? '')
            .split(',')
            .map((code) => code.trim().toUpperCase())
            .where((code) => code.isNotEmpty)
            .toList(),
      };
      
      print('📤 Synchronisation pays favoris avec l\'API:');
      print('   sPaysFav depuis localStorage: ${currentProfile['sPaysFav']}');
      print('   sPaysLangue depuis localStorage: ${currentProfile['sPaysLangue']}');
      
      // Mettre à jour via l'API (qui utilisera sPaysFav et sPaysLangue depuis localStorage)
      final response = await apiService.updateProfile(updateData);
      
      if (response['success'] == true || response['status'] == 'OK' || response.isNotEmpty) {
        print('✅ Pays favoris synchronisés avec l\'API');
        // ✅ CORRECTION: Ne PAS recharger le profil depuis l'API pour éviter d'écraser les modifications locales
        // Les modifications locales sont déjà sauvegardées dans localStorage
        // On peut juste mettre à jour le profil local avec la réponse de l'API si nécessaire
        final updatedProfile = await LocalStorageService.getProfile();
        if (updatedProfile != null && mounted) {
          setState(() {
            _profile = updatedProfile;
          });
        }
      } else {
        print('⚠️ La mise à jour locale a été conservée, mais la synchronisation avec l\'API a échoué');
      }
    } catch (e) {
      // ✅ En cas d'erreur API, on garde la mise à jour locale
      // L'utilisateur a déjà vu le message de succès, donc on ne montre pas d'erreur
      print('⚠️ Erreur lors de la synchronisation avec l\'API (mise à jour locale conservée): $e');
      // La mise à jour locale reste active, l'utilisateur peut continuer à utiliser l'app
    }
  }

  /// Basculer un pays favori (ajouter ou retirer)
  Future<void> _toggleFavoriteCountry(String countryCode) async {
    try {
      // ✅ CORRECTION: Récupérer le profil COMPLET depuis localStorage
      final currentProfile = await LocalStorageService.getProfile();
      if (currentProfile == null) {
        print('❌ Impossible de récupérer le profil depuis localStorage');
        return;
      }
      
      final currentFavorites = <String>{};
      final sPaysFav = currentProfile['sPaysFav']?.toString() ?? '';
      if (sPaysFav.isNotEmpty) {
        final countries = sPaysFav.split(',');
        for (final country in countries) {
          final trimmed = country.trim().toUpperCase();
          if (trimmed.isNotEmpty) {
            currentFavorites.add(trimmed);
          }
        }
      }
      
      if (currentFavorites.contains(countryCode.toUpperCase())) {
        // Retirer le pays
        currentFavorites.remove(countryCode.toUpperCase());
      } else {
        // Ajouter le pays
        currentFavorites.add(countryCode.toUpperCase());
      }
      
      final newFavorites = currentFavorites.join(',');
      await _updateFavoriteCountries(newFavorites);
      
    } catch (e) {
      print('Erreur lors du basculement du pays favori: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return 
    // buildAnimatedScreen(
      Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 800,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: isMobile ? 0 : 40,
                  vertical: isMobile ? 0 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête du profil
                    _buildProfileHeader(isMobile),
                    
                    const SizedBox(height: 20),
                    
                    // Informations du profil
                    _buildProfileInfo(isMobile, translationService),
                    
                    const SizedBox(height: 20),
                    
                    // Options du profil
                    _buildProfileOptions(isMobile, translationService),
                    
                    const SizedBox(height: 20),
                    
                    // Bouton de déconnexion
                    _buildActionButtons(isMobile, translationService),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 4),
    );
  }

  Widget _buildProfileHeader(bool isMobile) {
    final firstName = _profile?['sPrenom'] ?? 'Utilisateur';
    final lastName = _profile?['sNom'] ?? '';
    final email = _profile?['sEmail'] ?? 'email@exemple.com';
    final initials = '${firstName.isNotEmpty ? firstName[0] : 'U'}${lastName.isNotEmpty ? lastName[0] : ''}';

    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF3B82F6),
            Color(0xFFF59E0B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Flèche de retour
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                // Rediriger vers wishlist_screen
                context.go('/wishlist');
              },
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 28,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Avatar
          Container(
            width: isMobile ? 100 : 120,
            height: isMobile ? 100 : 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  fontSize: isMobile ? 36 : 42,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Nom
          Text(
            '$firstName $lastName',
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Email
          Text(
            email,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(bool isMobile, TranslationService translationService) {
    if (_isEditing) {
      // Mode édition: afficher le formulaire
      return Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translationService.translateFromBackend('PROFIL_MAJ_PROFIL'),
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              
              const SizedBox(height: 20),
              
              _buildTextField(
                translationService.translateFromBackend('PROFIL_FIRST_NAME'),
                _prenomController,
                Icons.person,
                isMobile,
                hint: translationService.translateFromBackend('PROFILE_Enter-FIRST_NAME'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                translationService.translateFromBackend('PROFIL_SECOND_NAME'),
                _nomController,
                Icons.person_outline,
                isMobile,
                hint: translationService.translateFromBackend('PROFIL_ENTER_SECOND_NAME'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                translationService.translateFromBackend('PROFIL_EMAIL'),
                _emailController,
                Icons.email,
                isMobile,
                isEmail: true,
                hint: translationService.translateFromBackend('PROFILE_ENTER_MAIL'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                translationService.translateFromBackend('PROFIL_PHONE'),
                _telController,
                Icons.phone,
                isMobile,
                hint: translationService.translateFromBackend('PROFILE_ENTER_PHONE'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                translationService.translateFromBackend('PROFIL_STREET'),
                _rueController,
                Icons.home,
                isMobile,
                hint: translationService.translateFromBackend('PROFILE_ENTER_SREET'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                translationService.translateFromBackend('PROFILE_POSTAL_CODE'),
                _zipController,
                Icons.location_on,
                isMobile,
                hint: translationService.translateFromBackend('PROFILE_ENTER_POSTAL_CODE'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                translationService.translateFromBackend('PROFIL_CITY'),
                _cityController,
                Icons.location_city,
                isMobile,
                hint: translationService.translateFromBackend('PROFILE_ENTER_POSTAL_CITY'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Mode lecture seule: afficher les informations
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations personnelles',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoRow(
            Icons.person,
            'Prénom',
            _profile?['sPrenom'] ?? '-',
            isMobile,
          ),
          
          const Divider(height: 24),
          
          _buildInfoRow(
            Icons.person_outline,
            'Nom',
            _profile?['sNom'] ?? '-',
            isMobile,
          ),
          
          const Divider(height: 24),
          
          _buildInfoRow(
            Icons.email,
            'Email',
            _profile?['sEmail'] ?? '-',
            isMobile,
          ),
          
          const Divider(height: 24),
          
          _buildInfoRow(
            Icons.phone,
            'Téléphone',
            _profile?['sTel'] ?? '-',
            isMobile,
          ),
          
          const Divider(height: 24),
          
          _buildInfoRow(
            Icons.home,
            'Adresse',
            _profile?['sRue'] ?? '-',
            isMobile,
          ),
          
          const Divider(height: 24),
          
          _buildInfoRow(
            Icons.location_on,
            'Code postal',
            _profile?['sZip'] ?? '-',
            isMobile,
          ),
          
          const Divider(height: 24),
          
          _buildInfoRow(
            Icons.location_city,
            'Ville',
            _profile?['sCity'] ?? '-',
            isMobile,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isMobile, {
    bool isEmail = false,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: true, // S'assurer que le champ est activé
      readOnly: false, // S'assurer que le champ n'est pas en lecture seule
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isMobile ? 14 : 16,
        ),
      ),
      validator: (value) {
        if (isEmail && (value == null || value.isEmpty)) {
          return 'L\'email est requis';
        }
        if (isEmail && !value!.contains('@')) {
          return 'Email invalide';
        }
        return null;
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isMobile) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3B82F6),
            size: 20,
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOptions(bool isMobile, TranslationService translationService) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCountrySelectionTile(
            Icons.flag,
            translationService.translateFromBackend('PROFIL_COUNTRY'),
            _profile?['sPaysLangue'] ?? 'FR/fr',
            isMobile,
          ),
          
          const Divider(height: 1),
          
          _buildFavoriteCountriesTile(
            Icons.favorite,
            translationService.translateFromBackend('PROFIL_FAVOCOUNTRY'),
            _profile?['sPaysFav'] ?? '',
            isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isMobile,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountrySelectionTile(
    IconData icon,
    String title,
    String currentValue,
    bool isMobile,
  ) {
    final countryCode = _getCountryCodeFromLangue(currentValue);
    final countryName = _getCountryNameFromCode(countryCode);
    
    return InkWell(
      onTap: () => _showCountrySelectionDialog(isMobile),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    countryName,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCountriesTile(
    IconData icon,
    String title,
    String currentValue,
    bool isMobile,
  ) {
    final normalizedFavorites = _normalizeCountriesString(currentValue);
    final cleanCountries = normalizedFavorites.isNotEmpty
        ? normalizedFavorites.split(',')
        : <String>[];
    
    return InkWell(
      onTap: () => _showFavoriteCountriesDialog(isMobile),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getAllAvailableCountries().map((code) {
                final isSelected = cleanCountries.contains(code);
                return GestureDetector(
                  onTap: () => _toggleFavoriteCountry(code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF3B82F6).withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                            ? const Color(0xFF3B82F6).withOpacity(0.3)
                            : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            ApiConfig.getProxiedImageUrl('https://jirig.be/img/flags/${code.toUpperCase()}.PNG'),
                            width: 20,
                            height: 15,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 20,
                                height: 15,
                                color: Colors.grey[200],
                                child: Icon(Icons.flag, size: 10),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getCountryNameFromCode(code),
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: isSelected 
                                ? const Color(0xFF3B82F6)
                                : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isSelected ? Icons.close : Icons.add,
                          size: 16,
                          color: isSelected 
                              ? const Color(0xFF3B82F6).withOpacity(0.7)
                              : Colors.grey[500],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile, TranslationService translationService) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
      child: Column(
        children: [
          // Bouton "Mettre à jour le profil"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isEditing ? _saveProfile : _toggleEditMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Consumer<TranslationService>(builder: (context, t, _) {
                      return Text(
                        _isEditing
                            ? t.translateFromBackend('PROFIL_UPDATE_PROFIL')
                            : t.translateFromBackend('PROFIL_MAJ_PROFIL'),
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Bouton "Annuler" (anciennement "Se déconnecter")
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Si on est en mode édition, annuler les modifications
                if (_isEditing) {
                  // Recharger les données originales depuis le profil
                  setState(() {
                    _prenomController.text = _profile?['sPrenom'] ?? '';
                    _nomController.text = _profile?['sNom'] ?? '';
                    _emailController.text = _profile?['sEmail'] ?? '';
                    _telController.text = _profile?['sTel'] ?? '';
                    _rueController.text = _profile?['sRue'] ?? '';
                    _zipController.text = _profile?['sZip'] ?? '';
                    _cityController.text = _profile?['sCity'] ?? '';
                    _isEditing = false;
                  });
                }
                
                // Retourner à la page précédente
                if (context.canPop()) {
                  context.pop();
                } else {
                  // Si on ne peut pas pop, rediriger vers wishlist (page par défaut)
                  context.go('/wishlist');
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _isEditing ? Colors.orange : Colors.red,
                side: BorderSide(
                  color: _isEditing ? Colors.orange : Colors.red,
                  width: 1.5,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isEditing 
                  ? translationService.translateFromBackend('WISHLIST_Msg30')
                  : 'Retour',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

