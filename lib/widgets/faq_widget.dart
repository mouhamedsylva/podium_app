import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';

/// ✅ Widget FAQ professionnel moderne avec animations fluides
class FaqWidget extends StatefulWidget {
  final bool isMobile;
  final VoidCallback? onContactPressed;

  const FaqWidget({
    Key? key,
    required this.isMobile,
    this.onContactPressed,
  }) : super(key: key);

  @override
  State<FaqWidget> createState() => _FaqWidgetState();
}

class _FaqWidgetState extends State<FaqWidget> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _faqList = [];
  bool _isLoadingFaq = false;
  int? _expandedIndex;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  /// ✅ Vérifie si la recherche n'est pas vide (sûr pour web)
  bool get _hasSearchQuery => _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFaqData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ Charger les données FAQ depuis l'API
  Future<void> _loadFaqData() async {
    setState(() {
      _isLoadingFaq = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.dio.get('/get-faq-list-question');

      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _faqList = List<Map<String, dynamic>>.from(response.data);
          _isLoadingFaq = false;
        });
      } else {
        setState(() {
          _isLoadingFaq = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement de la FAQ: $e');
      setState(() {
        _isLoadingFaq = false;
      });
    }
  }

  /// ✅ Filtrer les FAQ selon la recherche
  List<Map<String, dynamic>> get _filteredFaqList {
    if (_searchQuery.isEmpty) return _faqList;
    
    final translationService = Provider.of<TranslationService>(context, listen: false);
    return _faqList.where((faq) {
      final label = translationService.translate(faq['label']?.toString() ?? '').toLowerCase();
      final content = translationService.translate(faq['content']?.toString() ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return label.contains(query) || content.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(context, listen: false);

    return Container(
      constraints: BoxConstraints(
        maxWidth: widget.isMobile ? double.infinity : 1000,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header avec titre, sous-titre et recherche
          _buildHeader(translationService),
          
          const SizedBox(height: 32),
          
          // Widget FAQ
          _buildFaqContent(translationService),
          
          const SizedBox(height: 24),
          
          // Footer avec CTA
          _buildFooter(translationService),
        ],
      ),
    );
  }

  /// ✅ En-tête moderne avec recherche
  Widget _buildHeader(TranslationService translationService) {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 24 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0051BA),
            const Color(0xFF0051BA).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0051BA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icône décorative
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Titre
          Text(
            translationService.translate('FRONTPAGE_Msg44'),
            style: TextStyle(
              fontSize: widget.isMobile ? 28 : 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Sous-titre
          Text(
            translationService.translate('FRONTPAGE_Msg45'),
            style: TextStyle(
              fontSize: widget.isMobile ? 15 : 17,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 28),
          
          // Barre de recherche
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _expandedIndex = null; // Fermer tous les items lors de la recherche
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher une question...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: widget.isMobile ? 15 : 16,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: const Color(0xFF0051BA),
                  size: 24,
                ),
                suffixIcon: _hasSearchQuery
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: widget.isMobile ? 16 : 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Construit le contenu de la FAQ
  Widget _buildFaqContent(TranslationService translationService) {
    if (_isLoadingFaq) {
      return _buildLoadingState();
    }

    final filteredList = _filteredFaqList;

    if (filteredList.isEmpty) {
      return _buildEmptyState(translationService);
    }

    return Column(
      children: filteredList.asMap().entries.map((entry) {
        final index = entry.key;
        final faqItem = entry.value;
        return _buildFaqItem(index, faqItem, translationService);
      }).toList(),
    );
  }

  /// ✅ Item FAQ avec animation
  Widget _buildFaqItem(int index, Map<String, dynamic> faqItem, TranslationService translationService) {
    final isExpanded = _expandedIndex == index;
    final label = faqItem['label']?.toString() ?? '';
    final content = faqItem['content']?.toString() ?? '';
    final iconName = faqItem['icon']?.toString() ?? '';
    final iconData = _getIconFromHeroicon(iconName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded 
              ? const Color(0xFF0051BA).withOpacity(0.3)
              : Colors.grey[200]!,
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded 
                ? const Color(0xFF0051BA).withOpacity(0.15)
                : Colors.grey.withOpacity(0.08),
            blurRadius: isExpanded ? 12 : 8,
            offset: Offset(0, isExpanded ? 6 : 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            child: Column(
              children: [
                // En-tête de la question
                Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 20 : 24),
                  child: Row(
                    children: [
                      // Icône
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0051BA),
                              const Color(0xFF0051BA).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0051BA).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          iconData,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Question
                      Expanded(
                        child: Text(
                          translationService.translate(label),
                          style: TextStyle(
                            fontSize: widget.isMobile ? 16 : 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Icône expand/collapse avec animation
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0051BA).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF0051BA),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Réponse avec animation
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      widget.isMobile ? 20 : 24,
                      0,
                      widget.isMobile ? 20 : 24,
                      widget.isMobile ? 20 : 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0051BA).withOpacity(0.02),
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFF0051BA).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: widget.isMobile ? 0 : 52,
                        top: widget.isMobile ? 16 : 20,
                      ),
                      child: Text(
                        translationService.translate(content),
                        style: TextStyle(
                          fontSize: widget.isMobile ? 15 : 16,
                          color: Colors.grey[700],
                          height: 1.7,
                        ),
                      ),
                    ),
                  ),
                  crossFadeState: isExpanded 
                      ? CrossFadeState.showSecond 
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ État de chargement
  Widget _buildLoadingState() {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 40 : 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0051BA)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Chargement des questions...',
            style: TextStyle(
              fontSize: widget.isMobile ? 15 : 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ État vide
  Widget _buildEmptyState(TranslationService translationService) {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 40 : 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasSearchQuery 
                  ? Icons.search_off_rounded 
                  : Icons.quiz_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _hasSearchQuery
                ? 'Aucun résultat trouvé'
                : 'Aucune question disponible',
            style: TextStyle(
              fontSize: widget.isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasSearchQuery
                ? 'Essayez avec d\'autres mots-clés'
                : 'Les questions seront bientôt disponibles',
            style: TextStyle(
              fontSize: widget.isMobile ? 14 : 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Footer avec CTA
  Widget _buildFooter(TranslationService translationService) {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 24 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[50]!,
            Colors.grey[100]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.help_center_rounded,
            size: 40,
            color: const Color(0xFF0051BA).withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Vous ne trouvez pas votre réponse ?',
            style: TextStyle(
              fontSize: widget.isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Notre équipe est là pour vous aider',
            style: TextStyle(
              fontSize: widget.isMobile ? 14 : 15,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: widget.onContactPressed ?? () {},
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Contactez-nous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051BA),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 24 : 32,
                vertical: widget.isMobile ? 16 : 18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Convertit les noms d'icônes heroicons en IconData Material
  IconData _getIconFromHeroicon(String iconName) {
    final iconMap = {
      'heroicons:cog-6-tooth': Icons.settings_rounded,
      'heroicons:arrow-path': Icons.refresh_rounded,
      'heroicons:tag': Icons.local_offer_rounded,
      'heroicons:scale': Icons.balance_rounded,
      'heroicons:receipt-percent': Icons.receipt_rounded,
      'heroicons:bookmark': Icons.bookmark_rounded,
      'heroicons:exclamation-triangle': Icons.warning_rounded,
      'heroicons:shopping-cart': Icons.shopping_cart_rounded,
      'heroicons:cube': Icons.inventory_rounded,
      'heroicons:device-phone-mobile': Icons.phone_android_rounded,
    };

    return iconMap[iconName] ?? Icons.help_outline_rounded;
  }
}