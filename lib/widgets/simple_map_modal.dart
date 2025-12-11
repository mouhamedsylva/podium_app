import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'location_search_widget.dart';

class SimpleMapModal extends StatefulWidget {
  final VoidCallback? onClose;
  final bool isEmbedded;
  
  const SimpleMapModal({
    Key? key, 
    this.onClose,
    this.isEmbedded = false,
  }) : super(key: key);

  @override
  State<SimpleMapModal> createState() => _SimpleMapModalState();
}

class _SimpleMapModalState extends State<SimpleMapModal> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  LatLng? _userLocation;
  bool _isLoading = true; // Afficher le loader au démarrage
  String _errorMessage = '';
  List<Map<String, dynamic>> _ikeaStores = [];
  List<Map<String, dynamic>> _sortedStores = []; // Magasins triés par distance
  bool _useFallbackTiles = false; // bascule vers un autre provider si OSM échoue
  int _tileErrorCount = 0;        // compteur d'erreurs de tuiles pour déclencher le fallback
  bool _tilesLoading = true;      // indicateur de chargement des tuiles
  AnimationController? _breathingController;
  Animation<double>? _breathingAnimation;
  String _searchQuery = ''; // Recherche de magasins
  bool _showStoresContainer = false; // Contrôle l'affichage du container des magasins
  final TextEditingController _storeSearchController = TextEditingController();
  
  // Styles de carte
  String _currentMapStyle = 'standard'; // 'standard', 'satellite', 'carto_light', 'dark'
  bool _showMapStyleMenu = false;
  double _currentZoom = 2.5; // Zoom actuel de la carte
  
  ApiService get _apiService => Provider.of<ApiService>(context, listen: false);
  TranslationService get _translationService => Provider.of<TranslationService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    print('🗺️ ========== SimpleMapModal initState ==========');
    print('🗺️ Mode: ${widget.isEmbedded ? "Embedded" : "Dialog"}');
    
    // Initialiser l'animation de respiration
    _breathingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _breathingController!,
      curve: Curves.easeInOut,
    ));
    
    // Démarrer l'animation en boucle
    _breathingController!.repeat(reverse: true);
    print('🎯 Animation de respiration démarrée');
    
    // Masquer l'indicateur de chargement des tuiles après 3 secondes
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _tilesLoading = false;
        });
      }
    });
    
    _getUserLocation();
  }

  @override
  void dispose() {
    _breathingController?.dispose();
    _storeSearchController.dispose();
    super.dispose();
  }

  /// Récupérer la position de l'utilisateur sans loading
  Future<void> _getUserLocationWithoutLoading() async {
    print('🗺️ Début getUserLocationWithoutLoading');
    
    try {
      // 1. Vérifier les permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Service de localisation activé: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('⚠️ Service de localisation désactivé, utilisation position par défaut');
        // Position par défaut: Bruxelles
        _userLocation = LatLng(50.8467, 4.3499);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Permission actuelle: $permission');
      
      if (permission == LocationPermission.denied) {
        print('⚠️ Permission refusée, demande en cours...');
        permission = await Geolocator.requestPermission();
        print('📍 Nouvelle permission: $permission');
        
        if (permission == LocationPermission.denied) {
          print('❌ Permission refusée définitivement');
          _userLocation = LatLng(50.8467, 4.3499);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Permission refusée pour toujours');
        _userLocation = LatLng(50.8467, 4.3499);
        return;
      }

      // 2. Récupérer la position
      print('📍 Récupération position GPS...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      print('✅ Position obtenue: ${position.latitude}, ${position.longitude}');
      
      _userLocation = LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('❌ Erreur getUserLocationWithoutLoading: $e');
      // Position par défaut en cas d'erreur
      _userLocation = LatLng(50.8467, 4.3499);
    }
  }

  /// Récupérer la position de l'utilisateur
  Future<void> _getUserLocation() async {
    print('🗺️ Début getUserLocation');
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Vérifier les permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Service de localisation activé: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('⚠️ Service de localisation désactivé, utilisation position par défaut');
        // Position par défaut: Bruxelles
        setState(() {
          _userLocation = LatLng(50.8467, 4.3499);
          _isLoading = false;
        });
        await _loadStores();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Permission actuelle: $permission');
      
      if (permission == LocationPermission.denied) {
        print('⚠️ Permission refusée, demande en cours...');
        permission = await Geolocator.requestPermission();
        print('📍 Nouvelle permission: $permission');
        
        if (permission == LocationPermission.denied) {
          print('❌ Permission refusée définitivement');
          setState(() {
            _userLocation = LatLng(50.8467, 4.3499);
            _isLoading = false;
          });
          await _loadStores();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Permission refusée pour toujours');
        setState(() {
          _userLocation = LatLng(50.8467, 4.3499);
          _isLoading = false;
        });
        await _loadStores();
        return;
      }

      // 2. Récupérer la position
      print('📍 Récupération position GPS...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      print('✅ Position obtenue: ${position.latitude}, ${position.longitude}');
      
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      // 3. Charger les magasins
      await _loadStores();
    } catch (e) {
      print('❌ Erreur getUserLocation: $e');
      // Position par défaut en cas d'erreur
      setState(() {
        _userLocation = LatLng(50.8467, 4.3499);
      });
      await _loadStores();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Charger les magasins depuis l'API SNAL
  Future<void> _loadStores() async {
    if (_userLocation == null) {
      print('❌ Impossible de charger les magasins: position utilisateur non disponible');
      return;
    }

    print('🏪 Chargement des magasins depuis API SNAL...');
    
    try {
      final data = await _apiService.getIkeaStores(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );

      print('📦 Données reçues: ${data.keys.join(', ')}');

      // Extraire les magasins du format SNAL
      List<dynamic> storesData = [];
      
      if (data['stores'] != null && data['stores'] is List) {
        storesData = data['stores'] as List;
        print('✅ Format: { stores: [...] }');
      }

      print('🏪 Nombre de magasins reçus: ${storesData.length}');

      // Convertir les données SNAL vers format Flutter avec calcul de distance
      _ikeaStores = storesData.map((store) {
        final lat = (store['lat'] as num?)?.toDouble() ?? 0.0;
        final lng = (store['lng'] as num?)?.toDouble() ?? 0.0;
        final name = store['name'] ?? store['sMagasinName'] ?? 'Magasin IKEA';
        
        // Calculer la distance depuis la position utilisateur (comme SNAL)
        final distance = _calculateDistance(
          _userLocation!.latitude,
          _userLocation!.longitude,
          lat,
          lng,
        );
        
        print('  🏪 ${name}: (${lat}, ${lng}) - ${distance.toStringAsFixed(1)} km');
        
        return {
          'id': store['id'] ?? store['iMagasin'],
          'name': name,
          'address': store['address'] ?? store['sFullAddress'] ?? 'Adresse non disponible',
          'lat': lat,
          'lng': lng,
          'country': store['country'] ?? store['sPays'] ?? '',
          'flag': store['flag'] ?? '/img/flags/FR.PNG',
          'url': store['url'] ?? store['sUrl'] ?? '',
          'phone': store['phone'] ?? '',
          'hours': store['hours'] ?? '10h00 - 21h00',
          'type': store['type'] ?? 'SHOP',
          'distance': distance, // Distance en km
          'travelTime': (distance * 1.5).round(), // Temps de trajet estimé (comme SNAL)
        };
      }).toList();

      // Trier par distance (comme SNAL)
      _sortedStores = List.from(_ikeaStores);
      _sortedStores.sort((a, b) {
        final distanceA = (a['distance'] as num?)?.toDouble() ?? 0.0;
        final distanceB = (b['distance'] as num?)?.toDouble() ?? 0.0;
        return distanceA.compareTo(distanceB);
      });

      setState(() {
        _isLoading = false;
      });

      print('✅ ${_ikeaStores.length} magasins chargés et affichés');

      // Ajuster la caméra pour afficher tous les magasins si disponibles
      if (_ikeaStores.isNotEmpty && mounted) {
        // Calculer les bounds couvrant tous les magasins
        final lats = _ikeaStores.map((s) => (s['lat'] as num).toDouble()).toList();
        final lngs = _ikeaStores.map((s) => (s['lng'] as num).toDouble()).toList();
        final southWest = LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b));
        final northEast = LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds(southWest, northEast),
                padding: const EdgeInsets.all(40),
              ),
            );
          } catch (_) {}
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des magasins: $e');
      
      // Fallback: données factices en cas d'erreur
      print('⚠️ Utilisation des données factices en fallback');
      _ikeaStores = _getFallbackStores();
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Charger les magasins pour une position donnée (recherche par nom / code postal)
  Future<void> _loadStoresForLocation(double lat, double lon) async {
    try {
      print('🏪 Chargement des magasins pour: lat=$lat, lon=$lon');
      final data = await _apiService.getIkeaStores(
        lat: lat,
        lng: lon,
      );

      List<dynamic> storesData = [];
      if (data['stores'] != null && data['stores'] is List) {
        storesData = data['stores'] as List;
      }

      // Convertir et calculer la distance depuis la position recherchée
      final LatLng anchor = LatLng(lat, lon);
      _ikeaStores = storesData.map((store) {
        final sLat = (store['lat'] as num?)?.toDouble() ?? 0.0;
        final sLng = (store['lng'] as num?)?.toDouble() ?? 0.0;
        final name = store['name'] ?? store['sMagasinName'] ?? 'Magasin IKEA';

        final distance = _calculateDistance(
          anchor.latitude,
          anchor.longitude,
          sLat,
          sLng,
        );

        return {
          'id': store['id'] ?? store['iMagasin'],
          'name': name,
          'address': store['address'] ?? store['sFullAddress'] ?? 'Adresse non disponible',
          'lat': sLat,
          'lng': sLng,
          'country': store['country'] ?? store['sPays'] ?? '',
          'flag': store['flag'] ?? '/img/flags/FR.PNG',
          'url': store['url'] ?? store['sUrl'] ?? '',
          'phone': store['phone'] ?? '',
          'hours': store['hours'] ?? '10h00 - 21h00',
          'type': store['type'] ?? 'SHOP',
          'distance': distance,
          'travelTime': (distance * 1.5).round(),
        };
      }).toList();

      _sortedStores = List.from(_ikeaStores);
      _sortedStores.sort((a, b) {
        final distanceA = (a['distance'] as num?)?.toDouble() ?? 0.0;
        final distanceB = (b['distance'] as num?)?.toDouble() ?? 0.0;
        return distanceA.compareTo(distanceB);
      });

      setState(() {});
      print('✅ ${_ikeaStores.length} magasins chargés pour la recherche');
    } catch (e) {
      print('❌ Erreur _loadStoresForLocation: $e');
    }
  }

  /// Données factices en fallback (si API échoue)
  List<Map<String, dynamic>> _getFallbackStores() {
    if (_userLocation == null) return [];
    
    final baseLat = _userLocation!.latitude;
    final baseLng = _userLocation!.longitude;
    
    print('⚠️ Génération de 3 magasins factices autour de ($baseLat, $baseLng)');
    
    return [
      {
        'name': 'IKEA Bruxelles',
        'address': 'Boulevard de la Woluwe 34, 1200 Woluwe-Saint-Lambert',
        'lat': baseLat + 0.01,
        'lng': baseLng + 0.01,
        'phone': '+32 2 720 00 00',
        'hours': '10h00 - 21h00',
        'distance': '2.5 km',
        'country': 'BE',
        'flag': '/img/flags/belgium.png',
      },
      {
        'name': 'IKEA Anderlecht',
        'address': 'Chaussée de Mons 150, 1070 Anderlecht',
        'lat': baseLat - 0.008,
        'lng': baseLng + 0.015,
        'phone': '+32 2 520 00 00',
        'hours': '10h00 - 21h00',
        'distance': '3.2 km',
        'country': 'BE',
        'flag': '/img/flags/belgium.png',
      },
      {
        'name': 'IKEA Zaventem',
        'address': 'Boulevard de la Woluwe 100, 1930 Zaventem',
        'lat': baseLat + 0.02,
        'lng': baseLng - 0.005,
        'phone': '+32 2 730 00 00',
        'hours': '10h00 - 21h00',
        'distance': '4.1 km',
        'country': 'BE',
        'flag': '/img/flags/belgium.png',
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser listen: true pour que le widget se mette à jour quand les traductions changent
    final translationService = Provider.of<TranslationService>(context, listen: true);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Si mode intégré (embedded), afficher avec taille réduite et fond flou
    if (widget.isEmbedded) {
      print('🗺️ BUILD: Mode Embedded - _showStoresContainer = $_showStoresContainer');
      final screenSize = MediaQuery.of(context).size;
      final containerWidth = screenSize.width * 0.92; // 92% de la largeur
      final containerHeight = screenSize.height * 0.88; // 88% de la hauteur
      
      return Stack(
        children: [
          // Fond semi-transparent de la page wishlist
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
            ),
          ),
          
          // Modale centrée
          Center(
              child: Container(
                width: containerWidth,
                height: containerHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                  // En-tête avec recherche intégrée
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                    ),
                    child: Row(
                      children: [
                        // Champ de recherche géographique avec suggestions (utilise LocationSearchWidget)
                        Expanded(
                          child: LocationSearchWidget(
                            placeholder: translationService.translate('WISHLIST_Msg35'),
                            debounceDelay: 300,
                            minSearchLength: 3,
                            resultLimit: 5,
                            onLocationSelected: (location) {
                              _selectLocationSuggestion(location);
                            },
                            onSearchError: (query, error) {
                              print('❌ Erreur de recherche: $error');
                            },
                            onSearchSuccess: (query, results) {
                              print('✅ Recherche réussie: ${results.length} résultats');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bouton X pour fermer
                        GestureDetector(
                          onTap: () {
                            if (widget.onClose != null) {
                              widget.onClose!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red[500],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red[700]!, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Carte avec overlay de liste des magasins
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          // Carte en fond
                          _buildMap(),
                          
                          
                          // Boutons de zoom + et - (position fixe) - Optimisé pour mobile
                          Positioned(
                            top: 16, // Remis en haut maintenant que le bouton X est dans l'AppBar
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12), // Plus arrondi
                                border: Border.all(color: Colors.grey[300]!, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Bouton +
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _currentZoom = (_currentZoom + 1).clamp(1.0, 18.0);
                                      });
                                      // Amélioration du zoom pour éviter les zones grises
                                      _mapController.move(
                                        _mapController.camera.center, 
                                        _currentZoom,
                                        offset: Offset.zero,
                                      );
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Container(
                                        width: 48, // Augmenté pour mobile
                                        height: 40, // Augmenté pour mobile
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: Color(0xFF666666),
                                          size: 22, // Icône plus grande
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bouton -
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _currentZoom > 1.0 ? () {
                                      setState(() {
                                        _currentZoom = (_currentZoom - 1).clamp(1.0, 18.0);
                                      });
                                      // Amélioration du zoom pour éviter les zones grises
                                      _mapController.move(
                                        _mapController.camera.center, 
                                        _currentZoom,
                                        offset: Offset.zero,
                                      );
                                    } : null,
                                    child: MouseRegion(
                                      cursor: _currentZoom > 1.0 
                                          ? SystemMouseCursors.click 
                                          : SystemMouseCursors.forbidden,
                                      child: Container(
                                        width: 48, // Augmenté pour mobile
                                        height: 40, // Augmenté pour mobile
                                        child: Icon(
                                          Icons.remove,
                                          color: _currentZoom > 1.0 
                                              ? Color(0xFF666666) 
                                              : Color(0xFFCCCCCC),
                                          size: 22, // Icône plus grande
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Bouton principal du sélecteur de style (position fixe)
                          Positioned(
                            top: 144, // 70 + 64 (hauteur des boutons zoom) + 10 (espacement plus grand)
                            right: 16,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _showMapStyleMenu = !_showMapStyleMenu;
                                });
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!, width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.layers,
                                    color: Color(0xFF666666),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Menu de sélection de style (position fixe) - s'ouvre à gauche
                          if (_showMapStyleMenu)
                            Positioned(
                              top: 90, // Même hauteur que le bouton principal
                              right: 68, // 16 (marge droite) + 40 (largeur bouton) + 12 (espacement)
                              child: Container(
                                width: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildMapStyleOptionNew('standard', translationService.translate('STANDARD')),
                                    _buildMapStyleOptionNew('satellite', translationService.translate('SATELLITE')),
                                    _buildMapStyleOptionNew('carto_light', translationService.translate('CARTO_LIGHT')),
                                    _buildMapStyleOptionNew('dark', translationService.translate('DARK_MODE')),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Container des magasins à proximité avec défilement vertical (style SNAL)
                          if (_ikeaStores.isNotEmpty)
                            Builder(
                              builder: (context) {
                                final screenSize = MediaQuery.of(context).size;
                                final isMobile = screenSize.width < 768;
                                
                                // Utiliser les dimensions du container de la carte (92% x 88%)
                                final containerWidth = screenSize.width * 0.92;
                                final containerHeight = screenSize.height * 0.88;
                                
                                // Largeur du modal : 90% du container sur mobile, 380px sur desktop
                                final modalWidth = isMobile ? containerWidth * 0.9 : 380.0;
                                // Hauteur du modal : calculée depuis le container de la carte
                                final modalHeight = containerHeight - 32; // Marges de 16px en haut et en bas
                                
                                return AnimatedPositioned(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  top: 16, // Marge du haut
                                  right: (_showStoresContainer ?? false) ? 16 : -modalWidth - 50,
                                  child: IgnorePointer(
                                    ignoring: !(_showStoresContainer ?? false),
                                    child: AnimatedOpacity(
                                      duration: Duration(milliseconds: 300),
                                      opacity: (_showStoresContainer ?? false) ? 1.0 : 0.0,
                                      child: Container(
                                        width: modalWidth,
                                        height: modalHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 0,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                child: Column(
                                  children: [
                                    // En-tête du container (style SNAL)
                                    Container(
                                      padding: EdgeInsets.all(isMobile ? 12 : 20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF0051BA),
                                            Color(0xFF003D82),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                flex: 0,
                                                child: Container(
                                                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    Icons.store,
                                                    color: Colors.white,
                                                    size: isMobile ? 20 : 24,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: isMobile ? 8 : 12),
                                                Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      translationService.translate('STORES_NEARBY'),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: isMobile ? 16 : 18,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      '${translationService.translate('SORTED_BY_PROXIMITY')} • ${_ikeaStores.length}',
                                                      style: TextStyle(
                                                        fontSize: isMobile ? 12 : 14,
                                                        color: Colors.white.withOpacity(0.8),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: isMobile ? 12 : 16),
                                          // Options de tri (comme SNAL)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: isMobile ? 6 : 8,
                                                    horizontal: isMobile ? 8 : 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [Color(0xFF0051BA), Color(0xFF003D82)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        color: Colors.white,
                                                        size: isMobile ? 14 : 16,
                                                      ),
                                                      SizedBox(width: isMobile ? 4 : 8),
                                                      Flexible(
                                                        child: Text(
                                                          translationService.translate('YOUR_POSITION'),
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w500,
                                                            fontSize: isMobile ? 10 : 12,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: isMobile ? 6 : 8,
                                                    horizontal: isMobile ? 8 : 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [Color(0xFF0051BA), Color(0xFF003D82)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.store,
                                                        color: Colors.white,
                                                        size: isMobile ? 14 : 16,
                                                      ),
                                                      SizedBox(width: isMobile ? 4 : 8),
                                                      Flexible(
                                                        child: Text(
                                                          translationService.translate('IKEA_STORES'),
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w500,
                                                            fontSize: isMobile ? 10 : 12,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: isMobile ? 8 : 12),
                                          // Champ de recherche de magasins (nom/pays/ville)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.grey[300]!),
                                            ),
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 8),
                                                const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: TextField(
                                                    controller: _storeSearchController,
                                                    textInputAction: TextInputAction.search,
                                                    decoration: InputDecoration(
                                                      hintText: translationService.translate('SEARCH_STORE_PLACEHOLDER'),
                                                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: isMobile ? 12 : 13),
                                                      border: InputBorder.none,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: isMobile ? 10 : 12),
                                                    ),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _searchQuery = value.trim();
                                                      });
                                                    },
                                                    onSubmitted: (value) {
                                                      setState(() {
                                                        _searchQuery = value.trim();
                                                      });
                                                    },
                                                  ),
                                                ),
                                                if (_searchQuery.isNotEmpty)
                                                  IconButton(
                                                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                                                    onPressed: () {
                                                      setState(() {
                                                        _searchQuery = '';
                                                        _storeSearchController.clear();
                                                      });
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Liste déroulante des magasins (style SNAL)
                                    Expanded(
                                      child: ListView.builder(
                                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                                        itemCount: _getFilteredStores().length,
                                        itemBuilder: (context, index) {
                                          final store = _getFilteredStores()[index];
                                          final lat = store['lat'] as double?;
                                          final lng = store['lng'] as double?;
                                          final country = _getCountryFromCoordinates(lat, lng);
                                          final countryCode = _getCountryCodeFromName(country);
                                          final flagPath = _getFlagPath(countryCode);
                                          
                                          return Container(
                                            margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                                            child: Container(
                                                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(
                                                      color: Colors.grey[200]!,
                                                      width: 1,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.05),
                                                        blurRadius: 8,
                                                        spreadRadius: 0,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      // Contenu principal
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          // Nom du magasin avec drapeau
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  store['name']?.toString() ?? 'Magasin IKEA',
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: isMobile ? 14 : 16,
                                                                    color: Color(0xFF0051BA),
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              SizedBox(width: 8),
                                                              // Drapeau et nom du pays
                                                              Flexible(
                                                                flex: 0,
                                                                child: Container(
                                                                  padding: EdgeInsets.symmetric(
                                                                    horizontal: isMobile ? 6 : 8,
                                                                    vertical: 4,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.grey[50],
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    border: Border.all(
                                                                      color: Colors.grey[200]!,
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      // Drapeau du pays
                                                                      Container(
                                                                        width: isMobile ? 20 : 24,
                                                                        height: isMobile ? 14 : 16,
                                                                        decoration: BoxDecoration(
                                                                          borderRadius: BorderRadius.circular(3),
                                                                          border: Border.all(
                                                                            color: Colors.grey[300]!,
                                                                            width: 0.5,
                                                                          ),
                                                                        ),
                                                                        child: ClipRRect(
                                                                          borderRadius: BorderRadius.circular(2),
                                                                          child: Image.asset(
                                                                            flagPath,
                                                                            fit: BoxFit.cover,
                                                                            errorBuilder: (context, error, stackTrace) {
                                                                              return Container(
                                                                                color: Colors.grey[200],
                                                                                child: Icon(
                                                                                  Icons.flag,
                                                                                  size: 10,
                                                                                  color: Colors.grey[400],
                                                                                ),
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      SizedBox(width: isMobile ? 4 : 6),
                                                                      // Nom du pays
                                                                      Flexible(
                                                                        child: Text(
                                                                          country,
                                                                          style: TextStyle(
                                                                            fontSize: isMobile ? 10 : 12,
                                                                            color: Colors.grey[700],
                                                                            fontWeight: FontWeight.w600,
                                                                          ),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          SizedBox(height: isMobile ? 6 : 8),
                                                          
                                                          // Adresse complète
                                                      Text(
                                                        store['address']?.toString() ?? 'Adresse non disponible',
                                                        style: TextStyle(
                                                          fontSize: isMobile ? 12 : 14,
                                                          color: Colors.grey[700],
                                                          height: 1.4,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: isMobile ? 10 : 12),
                                                      
                                                      // Informations de distance et temps (comme SNAL)
                                                      Row(
                                                        children: [
                                                          // Distance
                                                          // Distance avec animation de respiration
                                                          AnimatedBuilder(
                                                            animation: _breathingController!,
                                                            builder: (context, child) {
                                                              final scale = 1.0 + (_breathingController!.value * 0.1);
                                                              final opacity = 0.8 + (_breathingController!.value * 0.2);
                                                              
                                                              return Transform.scale(
                                                                scale: scale,
                                                                child: Container(
                                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                                  decoration: BoxDecoration(
                                                                    color: Color(0xFF10B981).withOpacity(opacity * 0.15),
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    border: Border.all(
                                                                      color: Color(0xFF10B981).withOpacity(opacity * 0.4),
                                                                      width: 1.5,
                                                                    ),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Color(0xFF10B981).withOpacity(_breathingController!.value * 0.2),
                                                                        blurRadius: 4,
                                                                        spreadRadius: 1,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(
                                                                        Icons.location_on,
                                                                        size: isMobile ? 12 : 14,
                                                                        color: Color(0xFF10B981),
                                                                      ),
                                                                      SizedBox(width: 4),
                                                                      Flexible(
                                                                        child: Text(
                                                                          '${(store['distance'] as num?)?.toStringAsFixed(1) ?? '0.0'} km',
                                                                          style: TextStyle(
                                                                            fontSize: isMobile ? 10 : 11,
                                                                            color: Color(0xFF10B981),
                                                                            fontWeight: FontWeight.bold,
                                                                          ),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: isMobile ? 10 : 12),
                                                      
                                                      // Bouton Itinéraire (comme SNAL)
                                                      GestureDetector(
                                                        onTap: () => _openDirections(store),
                                                        child: Container(
                                                          width: double.infinity,
                                                          padding: EdgeInsets.symmetric(
                                                            vertical: isMobile ? 8 : 10,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                Color(0xFF0051BA),
                                                                Color(0xFF003D82),
                                                              ],
                                                            ),
                                                            borderRadius: BorderRadius.circular(12),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Color(0xFF0051BA).withOpacity(0.3),
                                                                blurRadius: 8,
                                                                spreadRadius: 0,
                                                                offset: Offset(0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                Icons.directions,
                                                                size: isMobile ? 16 : 18,
                                                                color: Colors.white,
                                                              ),
                                                              SizedBox(width: isMobile ? 6 : 8),
                                                              Text(
                                                                translationService.translate('WISHLIST_Msg40'),
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: isMobile ? 12 : 14,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          
                          // Bouton flottant "Ma position" (en dessous du sélecteur de carte) - masqué quand le modal Magasins est ouvert
                          if (!(_showStoresContainer ?? false))
                            Positioned(
                              top: 194, // En dessous du sélecteur de carte (144 + 40 + 10)
                              right: 16,
                            child: GestureDetector(
                              onTap: () async {
                                print('📍 Bouton position cliqué');
                                
                                // Si on a déjà une position, on centre directement
                                if (_userLocation != null) {
                                  print('📍 Centrage sur position existante: ${_userLocation!.latitude}, ${_userLocation!.longitude}');
                                  _mapController.move(_userLocation!, 15.0);
                                  return;
                                }
                                
                                // Sinon, on récupère la position sans afficher le loading
                                await _getUserLocationWithoutLoading();
                                if (_userLocation != null) {
                                  print('📍 Centrage sur nouvelle position: ${_userLocation!.latitude}, ${_userLocation!.longitude}');
                                  _mapController.move(_userLocation!, 15.0);
                                } else {
                                  print('❌ Position utilisateur null');
                                }
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.my_location,
                                  color: Color(0xFF0051BA),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          
                          // Bouton flottant pour afficher/masquer les magasins (bas à droite)
                          Positioned(
                            bottom: 24,
                            right: 24,
                            child: GestureDetector(
                              onTap: () {
                                print('🔘 ====== BOUTON CLIQUÉ! ======');
                                print('🔘 État actuel: $_showStoresContainer');
                                print('🔘 Mounted: $mounted');
                                setState(() {
                                  _showStoresContainer = !(_showStoresContainer ?? false);
                                  print('🔘 Nouvel état après setState: $_showStoresContainer');
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF0051BA), Color(0xFF003D82)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (_showStoresContainer ?? false) ? Icons.close : Icons.store,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      (_showStoresContainer ?? false) 
                                          ? translationService.translate('FRONTPAGE_Msg101')
                                          : translationService.translate('WISHLIST_Msg34'),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Sinon, afficher en mode Dialog avec taille réduite
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.92; // 92% de la largeur
    final dialogHeight = screenSize.height * 0.88; // 88% de la hauteur
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: (screenSize.width - dialogWidth) / 2,
        vertical: (screenSize.height - dialogHeight) / 2,
      ),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
        child: Column(
          children: [
            // En-tête avec bouton fermer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[700], size: 24),
                  const SizedBox(width: 12),
                  Text(
                    translationService.translate('IKEA_STORES_NEARBY'),
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Carte
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: _buildMap(),
              ),
            ),
          ],
        ),
      ),
          
          // Bouton X pour fermer (coin supérieur droit du Dialog) - Optimisé pour mobile
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                width: 40, // Augmenté pour mobile
                height: 40, // Augmenté pour mobile
                decoration: BoxDecoration(
                  color: Colors.red[500],
                  borderRadius: BorderRadius.circular(20), // Plus rond
                  border: Border.all(color: Colors.red[700]!, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20, // Icône plus grande
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget carte
  Widget _buildMap() {
    // Afficher le loader pendant le chargement
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.progressiveDots(
          color: Color(0xFF0051BA), // Bleu IKEA
          size: 50,
        ),
      );
    }

    if (_userLocation == null) {
      return Center(
        child: Text(
          'Impossible de récupérer la position',
          style: TextStyle(color: Colors.grey[700]),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: IgnorePointer(
        ignoring: _showMapStyleMenu,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // Vue monde par défaut; on recadrera automatiquement après chargement
                initialCenter: const LatLng(20.0, 0.0),
                initialZoom: 2.5,
                minZoom: 1.0, // Réduit pour éviter les zones grises
                maxZoom: 18.0,
                // Options d'interaction optimisées pour mobile
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  enableMultiFingerGestureRace: true,
                  pinchZoomWinGestures: MultiFingerGesture.pinchZoom,
                  pinchMoveWinGestures: MultiFingerGesture.none,
                ),
                onTap: (tapPosition, point) {
                  // Fermer le menu de style si ouvert
                  if (_showMapStyleMenu) {
                    setState(() {
                      _showMapStyleMenu = false;
                    });
                  }
                },
              ),
              children: [
        // Tuiles optimisées pour mobile et web
        TileLayer(
          urlTemplate: _useFallbackTiles ? _getFallbackTileUrl() : _getTileUrl(),
          userAgentPackageName: 'com.jirig.app',
          maxZoom: 19,
          minZoom: 1, // Ajouté pour éviter les tuiles vides
          // Provider optimisé qui gère mieux CORS sur web
          tileProvider: CancellableNetworkTileProvider(),
          subdomains: const ['a', 'b', 'c'],
          // Amélioration de la gestion des erreurs de tuiles
          errorTileCallback: (tile, error, stackTrace) {
            _tileErrorCount++;
            print('❌ Erreur tuile: $error');
            // après plusieurs erreurs, basculer vers un provider de secours
            if (_tileErrorCount >= 3 && !_useFallbackTiles && mounted) {
              print('⚠️ Erreurs de tuiles répétées (${_tileErrorCount}). Bascule vers provider fallback.');
              setState(() {
                _useFallbackTiles = true;
              });
            }
          },
          // Amélioration du chargement des tuiles
          tileBuilder: (context, tileWidget, tile) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: tileWidget,
            );
          },
        ),

        // Marqueur utilisateur (séparé du clustering)
        Builder(
          builder: (context) {
            if (_userLocation != null) {
              print('📍 Affichage marqueur utilisateur à: ${_userLocation!.latitude}, ${_userLocation!.longitude}');
            } else {
              print('❌ Position utilisateur null, pas de marqueur');
            }
            return MarkerLayer(
              markers: [
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 60,
                    height: 60,
                    child: _buildBreathingUserMarker(),
                  ),
              ],
            );
          },
        ),

        // Marqueurs magasins IKEA avec clustering (comme SNAL)
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 80,  // Comme SNAL
            size: const Size(40, 40),
            markers: _getFilteredStores().map((store) {
              return Marker(
                point: LatLng(store['lat'], store['lng']),
                width: 60, // Légèrement plus grand pour accommoder "IKEA"
                height: 60,
                child: GestureDetector(
                  onTap: () => _showStoreInfo(store),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF0058A3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFFFFDB00), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'IKEA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8, // Réduire la taille pour que "IKEA" rentre
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            builder: (context, markers) {
              // Widget de cluster (comme SNAL)
              return Container(
                decoration: BoxDecoration(
                  color: Color(0xFF0051ba),  // Bleu IKEA
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    markers.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
              ],
            ),
            
            // Indicateur de chargement des tuiles
            if (_tilesLoading)
              Container(
                color: Colors.grey[100],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0058A3)),
                      ),
                      SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final translationService = Provider.of<TranslationService>(context, listen: true);
                          return Text(
                            translationService.translate('LOADING_CHART'),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Calculer la distance entre deux points (formule de Haversine comme SNAL)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Rayon de la Terre en km
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * 
        math.cos(lat2 * math.pi / 180) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (R * c * 10).round() / 10; // Arrondi à 1 décimale comme SNAL
  }

  /// Obtenir le chemin du drapeau selon le pays (comme SNAL)
  String _getFlagPath(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'SN':
        return '/img/flags/FR.PNG'; // Pas de drapeau Sénégal, utiliser FR par défaut
      case 'FR':
        return '/img/flags/FR.PNG';
      case 'DE':
        return '/img/flags/DE.PNG';
      case 'ES':
        return '/img/flags/ES.PNG';
      case 'PT':
        return '/img/flags/PT.PNG';
      case 'IT':
        return '/img/flags/IT.PNG';
      case 'GB':
        return '/img/flags/england.png';
      case 'BE':
        return '/img/flags/BE.PNG';
      case 'NL':
        return '/img/flags/NL.PNG';
      case 'LU':
        return '/img/flags/LU.PNG';
      case 'US':
        return '/img/flags/usa.png';
      // Pays sans drapeau disponible - utiliser FR par défaut
      case 'CH':
      case 'AT':
      case 'SE':
      case 'NO':
      case 'DK':
      case 'FI':
      case 'PL':
      case 'CZ':
      case 'HU':
      case 'RO':
      case 'BG':
      case 'GR':
      case 'MA':
      case 'TN':
      case 'DZ':
      case 'TR':
      default:
        return 'assets/img/flags/FR.PNG'; // Drapeau par défaut
    }
  }

  /// Déterminer le pays en fonction des coordonnées GPS
  String _getCountryFromCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return 'France';
    
    // Portugal
    if (lat >= 36.8 && lat <= 42.2 && lng >= -9.5 && lng <= -6.2) {
      return 'Portugal';
    }
    
    // Espagne
    if (lat >= 35.2 && lat <= 43.8 && lng >= -9.3 && lng <= 4.3) {
      return 'Espagne';
    }
    
    // France
    if (lat >= 41.3 && lat <= 51.1 && lng >= -5.6 && lng <= 9.6) {
      return 'France';
    }
    
    // Belgique
    if (lat >= 49.5 && lat <= 51.5 && lng >= 2.5 && lng <= 6.4) {
      return 'Belgique';
    }
    
    // Pays-Bas
    if (lat >= 50.8 && lat <= 53.6 && lng >= 3.4 && lng <= 7.2) {
      return 'Pays-Bas';
    }
    
    // Allemagne
    if (lat >= 47.3 && lat <= 55.1 && lng >= 5.9 && lng <= 15.0) {
      return 'Allemagne';
    }
    
    // Italie
    if (lat >= 35.5 && lat <= 47.1 && lng >= 6.6 && lng <= 18.5) {
      return 'Italie';
    }
    
    // Suisse
    if (lat >= 45.8 && lat <= 47.8 && lng >= 5.9 && lng <= 10.5) {
      return 'Suisse';
    }
    
    // Autriche
    if (lat >= 46.4 && lat <= 49.0 && lng >= 9.5 && lng <= 17.2) {
      return 'Autriche';
    }
    
    // Royaume-Uni
    if (lat >= 49.9 && lat <= 60.9 && lng >= -8.2 && lng <= 1.8) {
      return 'Royaume-Uni';
    }
    
    // Suède
    if (lat >= 55.3 && lat <= 69.1 && lng >= 11.0 && lng <= 24.2) {
      return 'Suède';
    }
    
    // Norvège
    if (lat >= 58.0 && lat <= 80.7 && lng >= 4.6 && lng <= 31.3) {
      return 'Norvège';
    }
    
    // Danemark
    if (lat >= 54.6 && lat <= 57.8 && lng >= 8.1 && lng <= 15.2) {
      return 'Danemark';
    }
    
    // Finlande
    if (lat >= 59.8 && lat <= 70.1 && lng >= 20.6 && lng <= 31.6) {
      return 'Finlande';
    }
    
    // Pologne
    if (lat >= 49.0 && lat <= 54.8 && lng >= 14.1 && lng <= 24.1) {
      return 'Pologne';
    }
    
    // République tchèque
    if (lat >= 48.6 && lat <= 51.1 && lng >= 12.1 && lng <= 18.9) {
      return 'République tchèque';
    }
    
    // Hongrie
    if (lat >= 45.7 && lat <= 48.6 && lng >= 16.1 && lng <= 22.9) {
      return 'Hongrie';
    }
    
    // Roumanie
    if (lat >= 43.7 && lat <= 48.3 && lng >= 20.2 && lng <= 30.0) {
      return 'Roumanie';
    }
    
    // Bulgarie
    if (lat >= 41.2 && lat <= 44.2 && lng >= 22.4 && lng <= 28.6) {
      return 'Bulgarie';
    }
    
    // Grèce
    if (lat >= 34.8 && lat <= 41.7 && lng >= 19.4 && lng <= 29.7) {
      return 'Grèce';
    }
    
    // Turquie (partie européenne)
    if (lat >= 40.0 && lat <= 42.1 && lng >= 26.0 && lng <= 45.0) {
      return 'TR';
    }
    
    // Sénégal
    if (lat >= 12.3 && lat <= 16.7 && lng >= -17.5 && lng <= -11.3) {
      return 'SN';
    }
    
    // Maroc
    if (lat >= 27.7 && lat <= 35.9 && lng >= -17.0 && lng <= -1.0) {
      return 'MA';
    }
    
    // Tunisie
    if (lat >= 30.2 && lat <= 37.5 && lng >= 7.5 && lng <= 11.6) {
      return 'TN';
    }
    
    // Algérie
    if (lat >= 18.9 && lat <= 37.1 && lng >= -8.7 && lng <= 12.0) {
      return 'DZ';
    }
    
    // Par défaut, France
    return 'France';
  }

  /// Convertir le nom complet du pays en code pour le drapeau
  String _getCountryCodeFromName(String countryName) {
    switch (countryName) {
      case 'Portugal': return 'PT';
      case 'Espagne': return 'ES';
      case 'France': return 'FR';
      case 'Belgique': return 'BE';
      case 'Pays-Bas': return 'NL';
      case 'Allemagne': return 'DE';
      case 'Italie': return 'IT';
      case 'Suisse': return 'CH';
      case 'Autriche': return 'AT';
      case 'Royaume-Uni': return 'GB';
      case 'Suède': return 'SE';
      case 'Norvège': return 'NO';
      case 'Danemark': return 'DK';
      case 'Finlande': return 'FI';
      case 'Pologne': return 'PL';
      case 'République tchèque': return 'CZ';
      case 'Hongrie': return 'HU';
      case 'Roumanie': return 'RO';
      case 'Bulgarie': return 'BG';
      case 'Grèce': return 'GR';
      default: return 'FR';
    }
  }

  /// Obtenir le nom du pays en français (comme SNAL)
  String _getCountryName(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'SN':
        return 'Sénégal';
      case 'FR':
        return 'France';
      case 'DE':
        return 'Allemagne';
      case 'ES':
        return 'Espagne';
      case 'PT':
        return 'Portugal';
      case 'IT':
        return 'Italie';
      case 'GB':
        return 'Royaume-Uni';
      case 'BE':
        return 'Belgique';
      case 'NL':
        return 'Pays-Bas';
      case 'CH':
        return 'Suisse';
      case 'AT':
        return 'Autriche';
      case 'SE':
        return 'Suède';
      case 'NO':
        return 'Norvège';
      case 'DK':
        return 'Danemark';
      case 'FI':
        return 'Finlande';
      case 'PL':
        return 'Pologne';
      case 'CZ':
        return 'République tchèque';
      case 'HU':
        return 'Hongrie';
      case 'RO':
        return 'Roumanie';
      case 'BG':
        return 'Bulgarie';
      case 'GR':
        return 'Grèce';
      case 'MA':
        return 'Maroc';
      case 'TN':
        return 'Tunisie';
      case 'DZ':
        return 'Algérie';
      case 'TR':
        return 'Turquie';
      default:
        return 'France'; // Pays par défaut
    }
  }

  /// Calculer le temps de trajet estimé (comme SNAL)
  int _calculateTravelTime(double distanceKm) {
    // Estimation basée sur une vitesse moyenne de 50 km/h en ville
    // et 80 km/h sur route, avec un facteur de 1.5 comme dans SNAL
    final estimatedTime = (distanceKm * 1.5).round();
    return estimatedTime < 1 ? 1 : estimatedTime; // Minimum 1 minute
  }

  /// Filtrer les magasins par recherche
  List<Map<String, dynamic>> _getFilteredStores() {
    if (_sortedStores.isEmpty) return [];
    if (_searchQuery.isEmpty) return _sortedStores;
    
    return _sortedStores.where((store) {
      final name = store['name']?.toString().toLowerCase() ?? '';
      final address = store['address']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || address.contains(query);
    }).toList();
  }

  /// Focus sur un magasin spécifique (comme SNAL)
  void _focusOnStore(Map<String, dynamic> store) {
    final latLng = LatLng(store['lat'], store['lng']);
    _mapController.move(latLng, 15.0);
    
    // Afficher les infos du magasin
    _showStoreInfo(store);
  }

  /// Ouvrir l'itinéraire vers un magasin
  Future<void> _openDirections(Map<String, dynamic> store) async {
    final lat = store['lat'] as double?;
    final lng = store['lng'] as double?;
    final name = store['name'] as String? ?? 'Magasin IKEA';
    
    if (lat != null && lng != null) {
      try {
        // Ouvrir l'application de navigation par défaut
        final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name';
        
        print('🗺️ Ouverture de l\'itinéraire vers: $name ($lat, $lng)');
        print('🔗 URL: $url');
        
        // Importer url_launcher
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          print('❌ Impossible d\'ouvrir l\'URL: $url');
        }
      } catch (e) {
        print('❌ Erreur lors de l\'ouverture de l\'itinéraire: $e');
      }
    } else {
      print('❌ Coordonnées invalides pour le magasin: $name');
    }
  }

  /// Sélectionner une suggestion de lieu (appelé par LocationSearchWidget)
  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    final lat = suggestion['lat'] as double;
    final lon = suggestion['lon'] as double;
    
    // Centrer la carte sur le lieu sélectionné
    _mapController.move(LatLng(lat, lon), 13.0);
    print('📍 Carte centrée sur: ${suggestion['display_name']}');

    // Charger les magasins autour de ce lieu
    _loadStoresForLocation(lat, lon);
  }

  /// Changer le style de carte
  void _changeMapStyle(String style) {
    setState(() {
      _currentMapStyle = style;
      _showMapStyleMenu = false;
    });
  }

  /// Obtenir l'URL de tuiles selon le style
  String _getTileUrl() {
    // Utiliser des tuiles directement accessibles sur mobile
    switch (_currentMapStyle) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'carto_light':
        return 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=YOUR_API_KEY';
      case 'dark':
        return 'https://tiles.stadiamaps.com/tiles/alidade_dark/{z}/{x}/{y}{r}.png?api_key=YOUR_API_KEY';
      case 'standard':
      default:
        // Utiliser OpenStreetMap directement (plus fiable sur mobile)
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  /// Obtenir l'URL de tuiles de secours
  String _getFallbackTileUrl() {
    // Tuiles de secours plus fiables
    switch (_currentMapStyle) {
      case 'satellite':
        return 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';
      case 'carto_light':
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case 'dark':
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case 'standard':
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  /// Obtenir le nom du style pour l'affichage
  String _getStyleDisplayName(String style) {
    switch (style) {
      case 'standard':
        return _translationService.translate('STANDARD');
      case 'satellite':
        return _translationService.translate('SATELLITE');
      case 'carto_light':
        return _translationService.translate('CARTO_LIGHT');
      case 'dark':
        return _translationService.translate('DARK_MODE');
      default:
        return _translationService.translate('STANDARD');
    }
  }

  /// Obtenir l'icône du style
  IconData _getStyleIcon(String style) {
    switch (style) {
      case 'standard':
        return Icons.map;
      case 'satellite':
        return Icons.satellite;
      case 'carto_light':
        return Icons.wb_sunny;
      case 'dark':
        return Icons.dark_mode;
      default:
        return Icons.map;
    }
  }

  /// Widget pour une option de style de carte (nouveau design simple)
  Widget _buildMapStyleOptionNew(String style, String displayName) {
    final isSelected = _currentMapStyle == style;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _changeMapStyle(style),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFF3F4F6) : Colors.transparent,
          ),
          child: Row(
            children: [
              // Radio button simple
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Color(0xFF3B82F6) : Colors.grey[400]!,
                    width: 1.5,
                  ),
                  color: isSelected ? Color(0xFF3B82F6) : Colors.transparent,
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 8),
              // Nom du style
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: isSelected ? Color(0xFF3B82F6) : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget marqueur utilisateur avec animation de respiration
  Widget _buildBreathingUserMarker() {
    print('🎯 Construction marqueur utilisateur, animation null: ${_breathingAnimation == null}');
    
    if (_breathingAnimation == null) {
      print('⚠️ Animation null, affichage marqueur statique');
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 18,
        ),
      );
    }
    
    // Vérifier que l'animation fonctionne
    if (!_breathingController!.isAnimating) {
      print('⚠️ Animation arrêtée, redémarrage...');
      _breathingController!.repeat(reverse: true);
    }
    
    return AnimatedBuilder(
      animation: _breathingAnimation!,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Cercle de pulsation externe
            Container(
              width: 60 * _breathingAnimation!.value,
              height: 60 * _breathingAnimation!.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.3 * (1.2 - _breathingAnimation!.value)),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.6 * (1.2 - _breathingAnimation!.value)),
                  width: 2,
                ),
              ),
            ),
            // Cercle de pulsation moyen
            Container(
              width: 40 * _breathingAnimation!.value,
              height: 40 * _breathingAnimation!.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2 * (1.2 - _breathingAnimation!.value)),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.4 * (1.2 - _breathingAnimation!.value)),
                  width: 1.5,
                ),
              ),
            ),
            // Icône centrale (profil)
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Afficher les informations d'un magasin (comme SNAL)
  void _showStoreInfo(Map<String, dynamic> store) {
    final country = _getCountryFromCoordinates(store['lat'], store['lng']);
    final countryCode = _getCountryCodeFromName(country);
    final flagPath = _getFlagPath(countryCode);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 350,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bleu avec drapeau et nom
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF0058A3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Drapeau
                    Container(
                      width: 24,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(
                          image: AssetImage(flagPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store['name']?.toString() ?? 'Magasin IKEA',
                            style: TextStyle(
                              color: Color(0xFFFFDB00), // Jaune IKEA
                              fontWeight: FontWeight.bold,
                              fontSize: 20, // Augmenté de 16 à 20
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            country,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bouton fermer
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Contenu avec informations
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Adresse
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ADRESSE',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                store['address']?.toString() ?? 'Adresse non disponible',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Coordonnées
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.my_location, color: Colors.grey[600], size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COORDONNÉES',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${store['lat']?.toStringAsFixed(5) ?? 'N/A'}, ${store['lng']?.toStringAsFixed(5) ?? 'N/A'}',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Distance si disponible
                    if (store['distance'] != null) ...[
                      SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.directions, color: Colors.grey[600], size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DISTANCE',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${store['distance'].toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
