import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../services/translation_service.dart';

/// Widget modal réutilisable pour afficher les conditions d'utilisation
class TermsOfUseModal extends StatefulWidget {
  final TranslationService translationService;

  const TermsOfUseModal({
    Key? key,
    required this.translationService,
  }) : super(key: key);

  /// Affiche le modal des conditions d'utilisation
  static void show(BuildContext context, {required TranslationService translationService}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      barrierDismissible: true,
      builder: (context) => TermsOfUseModal(translationService: translationService),
    );
  }

  @override
  State<TermsOfUseModal> createState() => _TermsOfUseModalState();
}

class _TermsOfUseModalState extends State<TermsOfUseModal> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    // Créer les sections pour l'affichage simple
    final List<Map<String, String>> sections = _buildSections();
    
    // Détection responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallMobile = screenWidth < 361;
    final isSmallMobile = screenWidth < 431;
    final isMobile = screenWidth < 768;
    
    // Titre traduit
    String termsTitle = widget.translationService.translate('HTML_TERMS_HEADER_TITLE');
    if (termsTitle == 'HTML_TERMS_HEADER_TITLE') {
      termsTitle = widget.translationService.translate('ONBOARDING_Msg09');
      if (termsTitle == 'ONBOARDING_Msg09') {
        termsTitle = widget.translationService.translate('ONBOARDING_Msg06');
        if (termsTitle == 'ONBOARDING_Msg06') {
          termsTitle = 'Conditions d\'utilisation';
        }
      }
    }
    
    // Bouton fermer traduit
    String closeButton = widget.translationService.translate('WISHLIST_Msg26');
    if (closeButton == 'WISHLIST_Msg26') {
      closeButton = widget.translationService.translate('CLOSE');
      if (closeButton == 'CLOSE') {
        closeButton = 'Fermer';
      }
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : (isMobile ? 24 : 32)),
        vertical: isVerySmallMobile ? 24 : (isSmallMobile ? 32 : 40),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
      ),
      elevation: 24,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * (isMobile ? 0.88 : 0.85),
          maxWidth: isMobile ? double.infinity : 700,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 80,
              offset: const Offset(0, 32),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header moderne avec dégradé subtil
            Container(
              padding: EdgeInsets.fromLTRB(
                isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
                isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
                isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    const Color(0xFF2196F3).withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMobile ? 20 : 24),
                  topRight: Radius.circular(isMobile ? 20 : 24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Icône décorative améliorée
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2196F3),
                          const Color(0xFF1976D2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: Colors.white,
                      size: isVerySmallMobile ? 22 : (isSmallMobile ? 24 : 26),
                    ),
                  ),
                  
                  SizedBox(width: isVerySmallMobile ? 12 : 16),
                  
                  // Titre
                  Expanded(
                    child: Text(
                      termsTitle,
                      style: TextStyle(
                        fontSize: isVerySmallMobile ? 18 : (isSmallMobile ? 20 : (isMobile ? 22 : 24)),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  SizedBox(width: isVerySmallMobile ? 8 : 12),
                  
                  // Bouton de fermeture amélioré
                  Material(
                    color: Colors.grey[100],
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: isVerySmallMobile ? 36 : (isSmallMobile ? 40 : 44),
                        height: isVerySmallMobile ? 36 : (isSmallMobile ? 40 : 44),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.grey[700],
                          size: isVerySmallMobile ? 22 : (isSmallMobile ? 24 : 26),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu scrollable avec meilleur alignement
            Flexible(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
                  isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
                  isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
                  isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: !isMobile,
                  thickness: 6,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      right: isMobile ? 0 : 12,
                    ),
                    child: _buildTermsContent(sections, isVerySmallMobile, isSmallMobile, isMobile),
                  ),
                ),
              ),
            ),
            
            // Footer moderne avec bouton amélioré
            Container(
              padding: EdgeInsets.all(
                isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 28),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isMobile ? 20 : 24),
                  bottomRight: Radius.circular(isMobile ? 20 : 24),
                ),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: isVerySmallMobile ? 48 : (isSmallMobile ? 52 : 56),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ).copyWith(
                    overlayColor: MaterialStateProperty.all(
                      Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    closeButton,
                    style: TextStyle(
                      fontSize: isVerySmallMobile ? 16 : (isSmallMobile ? 17 : 18),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la liste des sections à partir des traductions
  List<Map<String, String>> _buildSections() {
    final List<Map<String, String>> sections = [];
    
    // Mapping des clés HTML_TERMS_* vers des titres de sections
    final Map<String, String> sectionTitles = {
      'HTML_TERMS_BLOCK1': 'Introduction',
      'HTML_TERMS_BLOCK2': 'Plateforme',
      'HTML_TERMS_DEFINITIONS': 'Définitions',
      'HTML_TERMS_SERVICES': 'Services offerts par JIRIG',
      'HTML_TERMS_CREATIONS': 'Création du compte',
      'HTML_TERMS_PROJECTS_CREATIONS': 'Création d\'un projet',
      'HTML_TERMS_ABONNEMENT': 'Abonnement',
      'HTML_TERMS_ACCEPTATIONS': 'Acceptation des conditions générales',
      'HTML_TERMS_OBLIGATIONS': 'Obligations de l\'utilisateur',
      'HTML_TERMS_PRIX_PROPRIETE': 'Propriété intellectuelle',
      'HTML_TERMS_RESPONSABILITE': 'Responsabilité',
      'HTML_TERMS_RECLAMATIONS': 'Règlement des réclamations',
      'HTML_TERMS_RECLAMATIONS-RIGHT': 'Droit de rétractation',
      'HTML_TERMS_DONNEES': 'Données personnelles',
    };
    
    // Liste des clés dans l'ordre logique pour construire le document
    final List<String> termsKeys = [
      'HTML_TERMS_BLOCK1',
      'HTML_TERMS_BLOCK2',
      'HTML_TERMS_DEFINITIONS',
      'HTML_TERMS_SERVICES',
      'HTML_TERMS_CREATIONS',
      'HTML_TERMS_PROJECTS_CREATIONS',
      'HTML_TERMS_ABONNEMENT',
      'HTML_TERMS_ACCEPTATIONS',
      'HTML_TERMS_OBLIGATIONS',
      'HTML_TERMS_PRIX_PROPRIETE',
      'HTML_TERMS_RESPONSABILITE',
      'HTML_TERMS_RECLAMATIONS',
      'HTML_TERMS_RECLAMATIONS-RIGHT',
      'HTML_TERMS_DONNEES',
    ];
    
    // Récupérer chaque section et créer un TermsData
    for (int i = 0; i < termsKeys.length; i++) {
      final key = termsKeys[i];
      final htmlContent = widget.translationService.translate(key);
      if (htmlContent != key) {
        // Extraire le texte du HTML
        final textContent = _extractTextFromHtml(htmlContent);
        if (textContent.isNotEmpty) {
          // Obtenir le titre de la section ou utiliser la clé comme titre
          final title = sectionTitles[key] ?? key.replaceAll('HTML_TERMS_', '').replaceAll('_', ' ');
          
          // ✅ Nettoyer le texte une deuxième fois pour supprimer toute indentation résiduelle
          final cleanedText = textContent
              .replaceAll(RegExp(r'^\s+', multiLine: true), '') // Supprimer espaces au début de chaque ligne
              .replaceAll(RegExp(r'\t'), ' ') // Remplacer tabulations par espaces
              .replaceAll(RegExp(r' {2,}'), ' ') // Normaliser espaces multiples
              .trim();
          
          // Créer une section simple avec titre et texte
          sections.add({
            'title': title,
            'text': cleanedText,
          });
        }
      }
    }
    
    // Si aucune section n'est trouvée, ajouter une section par défaut
    if (sections.isEmpty) {
      sections.add({
        'title': 'Conditions d\'utilisation',
        'text': 'En utilisant Jirig, vous acceptez nos conditions d\'utilisation...\n\n'
            'Pour plus d\'informations, consultez notre politique.',
      });
    }
    
    return sections;
  }

  /// Construit le contenu des termes d'utilisation de manière simple
  Widget _buildTermsContent(List<Map<String, String>> sections, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        final title = section['title'] ?? '';
        final text = section['text'] ?? '';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de la section
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Times',
                fontSize: isVerySmallMobile ? 16.0 : (isSmallMobile ? 17.0 : 18.0),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
                height: 1.4,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            // Texte de la section (justifié)
            Text(
              text,
              textAlign: TextAlign.justify, // ✅ Alignement justifié (gauche et droite)
              style: TextStyle(
                fontFamily: 'Times',
                fontSize: isVerySmallMobile ? 13.0 : (isSmallMobile ? 13.5 : 14.0),
                fontWeight: FontWeight.w400,
                color: const Color(0xFF374151),
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 32), // Espacement entre les sections
          ],
        );
      }).toList(),
    );
  }

  /// Extrait le texte d'un contenu HTML en supprimant les balises
  String _extractTextFromHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    
    try {
      // Parser le HTML
      final document = html_parser.parse(htmlString);
      
      // Extraire le texte en préservant la structure
      final text = document.body?.text ?? '';
      
      // ✅ Nettoyer le texte en forçant l'alignement à gauche (supprimer toute indentation)
      // Étape 1: Supprimer les tabulations et normaliser les espaces
      var cleanedText = text
          .replaceAll(RegExp(r'\t'), ' ') // Remplacer tabulations par espaces
          .replaceAll(RegExp(r' {3,}'), ' ') // Normaliser espaces multiples (3+ à 1)
          .trim();
      
      // Étape 2: Traiter ligne par ligne pour supprimer toute indentation au début
      final lines = cleanedText.split('\n');
      final cleanedLines = lines
          .map((line) {
            // ✅ Supprimer tous les espaces/tabs au début de chaque ligne
            var trimmed = line.trimLeft();
            // ✅ Supprimer aussi les tabulations qui pourraient rester
            trimmed = trimmed.replaceAll(RegExp(r'^\s+'), '');
            return trimmed;
          })
          .where((line) => line.isNotEmpty) // Supprimer lignes vides
          .toList();
      
      // Étape 3: Joindre les lignes avec un seul saut de ligne
      cleanedText = cleanedLines.join('\n');
      
      // Étape 4: Nettoyage final
      return cleanedText
          .replaceAll(RegExp(r' {2,}'), ' ') // Normaliser espaces multiples à un seul espace
          .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Max 2 sauts de ligne consécutifs
          .trim();
    } catch (e) {
      // Si le parsing échoue, retourner le HTML nettoyé
      final cleanedHtml = htmlString
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'&nbsp;'), ' ')
          .replaceAll(RegExp(r'&amp;'), '&')
          .replaceAll(RegExp(r'&lt;'), '<')
          .replaceAll(RegExp(r'&gt;'), '>')
          .replaceAll(RegExp(r'&quot;'), '"')
          .replaceAll(RegExp(r'\t'), '');
      
      // ✅ Nettoyer le HTML en forçant l'alignement à gauche (même processus que le parsing HTML)
      // Étape 1: Normaliser les espaces et tabulations
      var cleanedHtmlText = cleanedHtml
          .replaceAll(RegExp(r' {3,}'), ' ') // Normaliser espaces multiples (3+ à 1)
          .trim();
      
      // Étape 2: Traiter ligne par ligne pour supprimer toute indentation au début
      final htmlLines = cleanedHtmlText.split('\n');
      final cleanedHtmlLines = htmlLines
          .map((line) {
            // ✅ Supprimer tous les espaces/tabs au début de chaque ligne
            var trimmed = line.trimLeft();
            // ✅ Supprimer aussi les tabulations qui pourraient rester
            trimmed = trimmed.replaceAll(RegExp(r'^\s+'), '');
            return trimmed;
          })
          .where((line) => line.isNotEmpty) // Supprimer lignes vides
          .toList();
      
      // Étape 3: Joindre avec un seul saut de ligne
      final finalHtml = cleanedHtmlLines.join('\n');
      
      // Étape 4: Nettoyage final
      return finalHtml
          .replaceAll(RegExp(r' {2,}'), ' ') // Normaliser espaces multiples à un seul espace
          .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Max 2 sauts de ligne consécutifs
          .trim();
    }
  }
}