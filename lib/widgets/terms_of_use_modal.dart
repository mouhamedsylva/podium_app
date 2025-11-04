import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter_terms_viewer/flutter_terms_viewer.dart';
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
    
    // Créer les sections pour TermsViewer
    final Terms terms = _buildTerms();
    
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
    String closeButton = widget.translationService.translate('ONBOARDING_Msg07');
    if (closeButton == 'ONBOARDING_Msg07') {
      closeButton = widget.translationService.translate('CLOSE');
      if (closeButton == 'CLOSE') {
        closeButton = 'Fermer';
      }
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVerySmallMobile ? 12 : (isSmallMobile ? 16 : (isMobile ? 20 : 24)),
        vertical: isVerySmallMobile ? 20 : (isSmallMobile ? 24 : 32),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      elevation: 24,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * (isMobile ? 0.88 : 0.85),
          maxWidth: isMobile ? double.infinity : 672,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 32,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header avec titre et bouton fermer
            Container(
              padding: EdgeInsets.fromLTRB(
                isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                isVerySmallMobile ? 12 : (isSmallMobile ? 16 : 20),
                isVerySmallMobile ? 12 : (isSmallMobile ? 16 : 20),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMobile ? 16 : 20),
                  topRight: Radius.circular(isMobile ? 16 : 20),
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
                  // Icône décorative
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: const Color(0xFF2196F3),
                      size: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                    ),
                  ),
                  
                  SizedBox(width: isVerySmallMobile ? 10 : 12),
                  
                  // Titre
                  Expanded(
                    child: Text(
                      termsTitle,
                      style: TextStyle(
                        fontSize: isVerySmallMobile ? 17 : (isSmallMobile ? 18 : (isMobile ? 20 : 22)),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  SizedBox(width: isVerySmallMobile ? 6 : 8),
                  
                  // Bouton de fermeture
                  Material(
                    color: Colors.grey[100],
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: isVerySmallMobile ? 32 : (isSmallMobile ? 36 : 40),
                        height: isVerySmallMobile ? 32 : (isSmallMobile ? 36 : 40),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.grey[700],
                          size: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu scrollable
            Flexible(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                  isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                  isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
                  isVerySmallMobile ? 12 : (isSmallMobile ? 16 : 20),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: !isMobile,
                  thickness: 6,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      right: isMobile ? 0 : 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TermsViewer(
                        data: terms,
                        titleStyleBuilder: (data, style, index) {
                          return style.copyWith(
                            fontFamily: 'Times',
                            fontSize: data.title.isNotEmpty && data.title.first.types.contains('h2') 
                                ? (isVerySmallMobile ? 15.0 : (isSmallMobile ? 15.5 : 16.0))
                                : (data.title.isNotEmpty && data.title.first.types.contains('h3')
                                    ? (isVerySmallMobile ? 14.0 : (isSmallMobile ? 14.5 : 15.0))
                                    : (isVerySmallMobile ? 13.0 : (isSmallMobile ? 13.5 : 14.0))),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                            height: 1.5,
                          );
                        },
                        textStyleBuilder: (data, style, index) {
                          return style.copyWith(
                            fontFamily: 'Times',
                            fontSize: isVerySmallMobile ? 12.0 : (isSmallMobile ? 12.5 : 13.0),
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFF374151),
                            height: 1.8,
                            letterSpacing: 0.1,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Footer avec bouton
            Container(
              padding: EdgeInsets.all(
                isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 24),
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isMobile ? 16 : 20),
                  bottomRight: Radius.circular(isMobile ? 16 : 20),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: isVerySmallMobile ? 44 : (isSmallMobile ? 48 : 52),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    closeButton,
                    style: TextStyle(
                      fontSize: isVerySmallMobile ? 15 : (isSmallMobile ? 16 : 17),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
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

  /// Construit l'objet Terms pour TermsViewer à partir des traductions
  Terms _buildTerms() {
    final List<TermsData> contents = [];
    
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
          
          // Créer TermsData avec title et text comme TermsSpan
          contents.add(
            TermsData(
              position: i,
              title: [TermsSpan(text: title, types: ['h2'])],
              text: [TermsSpan(text: textContent)],
            ),
          );
        }
      }
    }
    
    // Si aucune section n'est trouvée, ajouter une section par défaut
    if (contents.isEmpty) {
      contents.add(
        const TermsData(
          position: 0,
          title: [TermsSpan(text: 'Conditions d\'utilisation', types: ['h2'])],
          text: [
            TermsSpan(
              text: 'En utilisant Jirig, vous acceptez nos conditions d\'utilisation...\n\n'
                  'Pour plus d\'informations, consultez notre politique.',
            ),
          ],
        ),
      );
    }
    
    return Terms(contents: contents);
  }

  /// Extrait le texte d'un contenu HTML en supprimant les balises
  String _extractTextFromHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    
    try {
      // Parser le HTML
      final document = html_parser.parse(htmlString);
      
      // Extraire le texte en préservant la structure mais en supprimant l'indentation
      final text = document.body?.text ?? '';
      
      // Nettoyer le texte (supprimer les espaces multiples, tabulations, etc.)
      return text
          .replaceAll(RegExp(r'\t'), ' ') // Remplacer les tabulations par des espaces
          .replaceAll(RegExp(r'[ \t]+'), ' ') // Remplacer les espaces/tabs multiples par un seul espace
          .replaceAll(RegExp(r'\n[ \t]*'), '\n') // Supprimer l'indentation au début des lignes
          .replaceAll(RegExp(r'\n\s*\n+'), '\n\n') // Normaliser les sauts de ligne multiples
          .trim();
    } catch (e) {
      // Si le parsing échoue, retourner le HTML brut (sans les balises basiques)
      return htmlString
          .replaceAll(RegExp(r'<[^>]+>'), '') // Supprimer les balises HTML
          .replaceAll(RegExp(r'&nbsp;'), ' ')
          .replaceAll(RegExp(r'&amp;'), '&')
          .replaceAll(RegExp(r'&lt;'), '<')
          .replaceAll(RegExp(r'&gt;'), '>')
          .replaceAll(RegExp(r'&quot;'), '"')
          .replaceAll(RegExp(r'\t'), ' ') // Remplacer les tabulations
          .replaceAll(RegExp(r'[ \t]+'), ' ') // Normaliser les espaces
          .replaceAll(RegExp(r'\n[ \t]*'), '\n') // Supprimer l'indentation
          .trim();
    }
  }
}

