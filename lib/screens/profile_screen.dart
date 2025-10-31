
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/local_storage_service.dart';
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
      
      // 1. D'abord essayer de récupérer depuis l'API (comme SNAL)
      final apiService = Provider.of<ApiService>(context, listen: false);
      try {
        print('📡 Appel API pour récupérer les données utilisateur...');
        final apiProfile = await apiService.getUserInfo();
        
        if (apiProfile != null && apiProfile.isNotEmpty) {
          print('✅ Données récupérées depuis l\'API: $apiProfile');
          
          // Sauvegarder les données API dans le localStorage
          await LocalStorageService.saveProfile(apiProfile);
          
          if (mounted) {
            setState(() {
              _profile = apiProfile;
              _isLoading = false;
              
              // Initialiser les controllers avec les données du profil
              _prenomController.text = apiProfile['sPrenom'] ?? '';
              _nomController.text = apiProfile['sNom'] ?? '';
              _emailController.text = apiProfile['sEmail'] ?? '';
              _telController.text = apiProfile['sTel'] ?? '';
              _rueController.text = apiProfile['sRue'] ?? '';
              _zipController.text = apiProfile['sZip'] ?? '';
              _cityController.text = apiProfile['sCity'] ?? '';
            });
          }
          return;
        }
      } catch (apiError) {
        print('⚠️ Erreur API, fallback vers localStorage: $apiError');
      }
      
      // 2. Fallback vers localStorage si l'API échoue
      final profile = await LocalStorageService.getProfile();
      print('📱 Données depuis localStorage: $profile');
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          
          // Initialiser les controllers avec les données du profil
          _prenomController.text = profile?['sPrenom'] ?? '';
          _nomController.text = profile?['sNom'] ?? '';
          _emailController.text = profile?['sEmail'] ?? '';
          _telController.text = profile?['sTel'] ?? '';
          _rueController.text = profile?['sRue'] ?? '';
          _zipController.text = profile?['sZip'] ?? '';
          _cityController.text = profile?['sCity'] ?? '';
        });
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
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final profile = await LocalStorageService.getProfile();
      final token = profile?['token'] ?? '';
      
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
      
      final response = await apiService.updateProfile(updateData);
      
      if (response['success'] == true && mounted) {
        // Mettre à jour le profil local
        await _loadProfile();
        
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Rediriger vers wishlist après 2 secondes
          Future.delayed(const Duration(seconds: 2), () async {
            if (mounted) {
              try {
                await LocalStorageService.saveCurrentRoute('/wishlist');
              } catch (_) {}
              context.go('/wishlist');
            }
          });
        }
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde du profil: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: Colors.red,
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
        return 'Allemagne';
      case 'BE':
        return 'Belgique';
      case 'ES':
        return 'Espagne';
      case 'IT':
        return 'Italie';
      case 'NL':
        return 'Pays-Bas';
      case 'PT':
        return 'Portugal';
      case 'LU':
        return 'Luxembourg';
      default:
        return code;
    }
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
                child: const Text('Annuler'),
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
      // Mettre à jour le profil local
      final updatedProfile = Map<String, dynamic>.from(_profile ?? {});
      updatedProfile['sPaysLangue'] = newCountryLangue;
      
      await LocalStorageService.saveProfile(updatedProfile);
      
      setState(() {
        _profile = updatedProfile;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pays principal mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du pays principal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mettre à jour les pays favoris
  Future<void> _updateFavoriteCountries(String newFavorites) async {
    try {
      // Mettre à jour le profil local
      final updatedProfile = Map<String, dynamic>.from(_profile ?? {});
      updatedProfile['sPaysFav'] = newFavorites;
      
      await LocalStorageService.saveProfile(updatedProfile);
      
      setState(() {
        _profile = updatedProfile;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pays favoris mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la mise à jour des pays favoris: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Basculer un pays favori (ajouter ou retirer)
  Future<void> _toggleFavoriteCountry(String countryCode) async {
    try {
      final currentFavorites = <String>{};
      final sPaysFav = _profile?['sPaysFav'] ?? '';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                    _buildActionButtons(isMobile),
                    
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
                'Modifier les informations',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              
              const SizedBox(height: 20),
              
              _buildTextField('Prénom', _prenomController, Icons.person, isMobile),
              const SizedBox(height: 16),
              
              _buildTextField('Nom', _nomController, Icons.person_outline, isMobile),
              const SizedBox(height: 16),
              
              _buildTextField('Email', _emailController, Icons.email, isMobile, isEmail: true),
              const SizedBox(height: 16),
              
              _buildTextField('Téléphone', _telController, Icons.phone, isMobile),
              const SizedBox(height: 16),
              
              _buildTextField('Rue', _rueController, Icons.home, isMobile),
              const SizedBox(height: 16),
              
              _buildTextField('Code postal', _zipController, Icons.location_on, isMobile),
              const SizedBox(height: 16),
              
              _buildTextField('Ville', _cityController, Icons.location_city, isMobile),
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
  }) {
    return TextFormField(
      controller: controller,
      enabled: true, // S'assurer que le champ est activé
      readOnly: false, // S'assurer que le champ n'est pas en lecture seule
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
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
        if (label == 'Email' && (value == null || value.isEmpty)) {
          return 'L\'email est requis';
        }
        if (label == 'Email' && !value!.contains('@')) {
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
            'Pays principal',
            _profile?['sPaysLangue'] ?? 'FR/fr',
            isMobile,
          ),
          
          const Divider(height: 1),
          
          _buildFavoriteCountriesTile(
            Icons.favorite,
            'Pays favoris',
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
    final favoriteCountries = currentValue.isNotEmpty ? currentValue.split(',') : [];
    final cleanCountries = favoriteCountries
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList();
    
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

  Widget _buildActionButtons(bool isMobile) {
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
                  : Text(
                      _isEditing ? 'Sauvegarder' : 'Mettre à jour le profil',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Bouton "Annuler" (anciennement "Se déconnecter")
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Essayer de pop, sinon aller à l'accueil
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
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
                _isEditing ? 'Annuler' : 'Retour',
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

