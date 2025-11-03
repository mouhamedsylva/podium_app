import 'package:flutter/material.dart';
import '../services/location_search_service.dart';
import 'package:latlong2/latlong.dart';

/// Widget réutilisable pour la recherche de localisation
/// Conforme à l'architecture SNAL-Project (comme ProductSearch.vue)
class LocationSearchWidget extends StatefulWidget {
  /// Placeholder du champ de recherche
  final String placeholder;
  
  /// Label du bouton de recherche
  final String? searchButtonLabel;
  
  /// Message d'état initial
  final String initialStateMessage;
  
  /// Titre quand aucun résultat
  final String noResultsTitle;
  
  /// Sous-titre quand aucun résultat
  final String noResultsSubtitle;
  
  /// Titre d'erreur
  final String errorTitle;
  
  /// Délai de debounce en millisecondes (défaut: 300ms comme SNAL-Project)
  final int debounceDelay;
  
  /// Longueur minimale pour lancer une recherche (défaut: 3 comme SNAL-Project)
  final int minSearchLength;
  
  /// Limite de résultats (défaut: 5)
  final int resultLimit;
  
  /// Callback appelé quand une localisation est sélectionnée
  final Function(Map<String, dynamic> location)? onLocationSelected;
  
  /// Callback appelé en cas d'erreur
  final Function(String query, String error)? onSearchError;
  
  /// Callback appelé en cas de succès
  final Function(String query, List<Map<String, dynamic>> results)? onSearchSuccess;
  
  /// Callback appelé pendant le chargement
  final Function(bool isLoading)? onLoadingChanged;

  const LocationSearchWidget({
    Key? key,
    this.placeholder = 'Rechercher une ville, adresse ou code postal...',
    this.searchButtonLabel,
    this.initialStateMessage = 'Saisissez une localisation pour commencer la recherche',
    this.noResultsTitle = 'Aucun résultat trouvé',
    this.noResultsSubtitle = 'Essayez avec un autre terme de recherche',
    this.errorTitle = 'Erreur de recherche',
    this.debounceDelay = 300,
    this.minSearchLength = 3,
    this.resultLimit = 5,
    this.onLocationSelected,
    this.onSearchError,
    this.onSearchSuccess,
    this.onLoadingChanged,
  }) : super(key: key);

  @override
  State<LocationSearchWidget> createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  final LocationSearchService _searchService = LocationSearchService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _locationSuggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;
  String _errorMessage = '';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchService.cancelSearch();
    _searchController.dispose();
    super.dispose();
  }

  /// Gérer la recherche avec debounce (comme ProductSearch.vue)
  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _errorMessage = '';
    });

    // Validation minimale de la longueur (comme SNAL-Project)
    if (query.trim().length < widget.minSearchLength) {
      setState(() {
        _locationSuggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      widget.onLoadingChanged?.call(false);
      return;
    }

    // Lancer la recherche avec debounce
    _performSearch(query);
  }

  /// Effectuer la recherche (comme debouncedSearch dans ProductSearch.vue)
  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });
    widget.onLoadingChanged?.call(true);

    try {
      final results = await _searchService.searchLocations(
        query,
        limit: widget.resultLimit,
        debounceDelay: Duration(milliseconds: widget.debounceDelay),
      );

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _locationSuggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
      widget.onLoadingChanged?.call(false);

      // Émettre les événements (comme ProductSearch.vue)
      if (results.isNotEmpty) {
        widget.onSearchSuccess?.call(query, results);
      } else {
        // Pas d'erreur, juste aucun résultat
        widget.onSearchError?.call(query, 'Aucun résultat trouvé');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _locationSuggestions = [];
        _showSuggestions = false;
        _errorMessage = 'Erreur lors de la recherche: $e';
      });
      widget.onLoadingChanged?.call(false);

      widget.onSearchError?.call(query, _errorMessage);
    }
  }

  /// Sélectionner une localisation (comme handleSelectProduct dans ProductSearch.vue)
  void _selectLocation(Map<String, dynamic> location) {
    setState(() {
      _searchQuery = location['display_name'] ?? '';
      _searchController.text = _searchQuery;
      _showSuggestions = false;
      _locationSuggestions = [];
    });

    // Émettre l'événement (comme emit('product-selected'))
    widget.onLocationSelected?.call(location);
  }

  /// Effacer la recherche
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _locationSuggestions = [];
      _showSuggestions = false;
      _errorMessage = '';
    });
    widget.onLoadingChanged?.call(false);
  }

  /// Capitaliser le type de lieu (comme dans SNAL-Project)
  String _capitalizeType(String type) {
    if (type.isEmpty) return '';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  /// Formater le nom d'affichage avec highlight (simplifié - pas de regex HTML comme Vue)
  String _formatDisplayName(String displayName, String query) {
    // Version simplifiée du highlight (on pourrait utiliser RichText si nécessaire)
    return displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Champ de recherche (comme ProductSearch.vue)
        _buildSearchField(),
        
        // Liste des résultats ou états (comme ProductSearch.vue)
        if (_showSuggestions || _isSearching || _errorMessage.isNotEmpty || (_searchQuery.isNotEmpty && _locationSuggestions.isEmpty))
          _buildResultsContainer(),
      ],
    );
  }

  /// Construire le champ de recherche (comme dans ProductSearch.vue)
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.black),
                  onPressed: _clearSearch,
                )
              : Icon(Icons.search, color: Colors.grey[400]),
        ),
        onChanged: _handleSearch,
      ),
    );
  }

  /// Construire le conteneur des résultats (comme dans ProductSearch.vue)
  Widget _buildResultsContainer() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(maxHeight: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildResultsContent(),
        ),
      ),
    );
  }

  /// Construire le contenu des résultats selon l'état
  Widget _buildResultsContent() {
    // État: Chargement
    if (_isSearching) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Recherche en cours...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    // État: Erreur
    if (_errorMessage.isNotEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[600],
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              widget.errorTitle,
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // État: Aucun résultat
    if (_locationSuggestions.isEmpty && _searchQuery.isNotEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              color: Colors.grey[400],
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              widget.noResultsTitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.noResultsSubtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // État: Résultats
    if (_showSuggestions && _locationSuggestions.isNotEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _locationSuggestions.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFF3F4F6),
        ),
        itemBuilder: (context, index) {
          final location = _locationSuggestions[index];
          final isLast = index == _locationSuggestions.length - 1;

          return InkWell(
            onTap: () => _selectLocation(location),
            hoverColor: Color(0xFFF8F9FA),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: isLast ? null : Border(
                  bottom: BorderSide(
                    color: Color(0xFFF3F4F6),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Icône de localisation
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Informations de la localisation
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location['display_name'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (location['type'] != null)
                          Text(
                            _capitalizeType(location['type']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // État initial (quand rien n'est saisi)
    if (_searchQuery.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              color: Colors.grey[300],
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              widget.initialStateMessage,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SizedBox.shrink();
  }
}

