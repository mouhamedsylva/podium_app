import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter_terms_viewer/flutter_terms_viewer.dart';
import '../services/translation_service.dart';

/// Widget modal réutilisable pour afficher la politique de confidentialité
class PrivacyPolicyModal extends StatefulWidget {
  final TranslationService translationService;

  const PrivacyPolicyModal({
    Key? key,
    required this.translationService,
  }) : super(key: key);

  /// Affiche le modal de la politique de confidentialité
  static void show(BuildContext context, {required TranslationService translationService}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      barrierDismissible: true,
      builder: (context) => PrivacyPolicyModal(translationService: translationService),
    );
  }

  @override
  State<PrivacyPolicyModal> createState() => _PrivacyPolicyModalState();
}

class _PrivacyPolicyModalState extends State<PrivacyPolicyModal> {
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
    final Terms terms = _buildPrivacyPolicy();
    
    // Détection responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallMobile = screenWidth < 361;
    final isSmallMobile = screenWidth < 431;
    final isMobile = screenWidth < 768;
    
    // Titre traduit
    String privacyTitle = widget.translationService.translate('HTML_TERMS_HEADER-POLICY');
    if (privacyTitle == 'HTML_TERMS_HEADER-POLICY') {
      privacyTitle = widget.translationService.translate('HTML_PRIVACY_HEADER_TITLE');
      if (privacyTitle == 'HTML_PRIVACY_HEADER_TITLE') {
        privacyTitle = widget.translationService.translate('PRIVACY_POLICY_TITLE');
        if (privacyTitle == 'PRIVACY_POLICY_TITLE') {
          privacyTitle = 'Politique de confidentialité';
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
                      Icons.privacy_tip_outlined,
                      color: const Color(0xFF2196F3),
                      size: isVerySmallMobile ? 20 : (isSmallMobile ? 22 : 24),
                    ),
                  ),
                  
                  SizedBox(width: isVerySmallMobile ? 10 : 12),
                  
                  // Titre
                  Expanded(
                    child: Text(
                      privacyTitle,
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

  /// Construit l'objet Terms pour TermsViewer à partir des traductions de la politique de confidentialité
  Terms _buildPrivacyPolicy() {
    final List<TermsData> contents = [];
    
    // La clé principale pour la politique de confidentialité est HTML_TERMS_BODY-POLICY
    final htmlContent = widget.translationService.translate('HTML_TERMS_BODY-POLICY');
    
    if (htmlContent != 'HTML_TERMS_BODY-POLICY' && htmlContent.isNotEmpty) {
      // Extraire le texte du HTML
      final textContent = _extractTextFromHtml(htmlContent);
      
      if (textContent.isNotEmpty) {
        // Parser le contenu pour extraire les sections (h2, h3)
        final sections = _parseHtmlContentToSections(htmlContent);
        
        if (sections.isNotEmpty) {
          // Utiliser les sections parsées
          for (int i = 0; i < sections.length; i++) {
            final section = sections[i];
              final titleTypeStr = section['titleType'] ?? 'h2';
              final titleType = titleTypeStr is String ? [titleTypeStr] : (titleTypeStr as List<String>);
              contents.add(
                TermsData(
                  position: i,
                  title: section['title']?.isNotEmpty == true 
                      ? [TermsSpan(text: section['title']!, types: titleType)]
                      : [],
                  text: section['text']?.isNotEmpty == true 
                      ? [TermsSpan(text: section['text']!)]
                      : [],
                ),
              );
          }
        } else {
          // Si le parsing échoue, utiliser le texte complet
          contents.add(
            TermsData(
              position: 0,
              title: [TermsSpan(text: 'Politique de confidentialité', types: ['h2'])],
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
          title: [TermsSpan(text: 'Politique de confidentialité', types: ['h2'])],
          text: [
            TermsSpan(
              text: 'Cette politique de confidentialité décrit comment Jirig collecte, utilise et protège vos données personnelles.\n\n'
                  'Pour plus d\'informations, consultez notre politique complète.',
            ),
          ],
        ),
      );
    }
    
    return Terms(contents: contents);
  }
  
  /// Parse le contenu HTML pour extraire les sections avec leurs titres (h2, h3)
  List<Map<String, String>> _parseHtmlContentToSections(String htmlContent) {
    final List<Map<String, String>> sections = [];
    
    try {
      final document = html_parser.parse(htmlContent);
      final body = document.body;
      
      if (body == null) return sections;
      
      String currentTitle = '';
      String currentText = '';
      String currentTitleType = 'h2';
      
      // Parcourir tous les éléments du body
      for (final element in body.children) {
        final tagName = element.localName?.toLowerCase() ?? '';
        
        if (tagName == 'h2' || tagName == 'h3') {
          // Si on a déjà du contenu, sauvegarder la section précédente
          if (currentTitle.isNotEmpty || currentText.isNotEmpty) {
            sections.add({
              'title': currentTitle,
              'text': currentText.trim(),
              'titleType': currentTitleType,
            });
            currentText = '';
          }
          
          // Nouveau titre
          currentTitle = element.text.trim();
          currentTitleType = tagName;
        } else if (tagName == 'p' || tagName == 'ul' || tagName == 'li' || tagName == 'div') {
          // Ajouter le texte au contenu actuel
          final text = element.text.trim();
          if (text.isNotEmpty) {
            if (currentText.isNotEmpty) {
              currentText += '\n\n';
            }
            currentText += text;
          }
        } else if (tagName == 'hr') {
          // Séparateur - sauvegarder la section actuelle
          if (currentTitle.isNotEmpty || currentText.isNotEmpty) {
            sections.add({
              'title': currentTitle,
              'text': currentText.trim(),
              'titleType': currentTitleType,
            });
            currentTitle = '';
            currentText = '';
            currentTitleType = 'h2';
          }
        }
      }
      
      // Ajouter la dernière section
      if (currentTitle.isNotEmpty || currentText.isNotEmpty) {
        sections.add({
          'title': currentTitle,
          'text': currentText.trim(),
          'titleType': currentTitleType,
        });
      }
    } catch (e) {
      // Si le parsing échoue, retourner une liste vide
      print('Erreur lors du parsing HTML: $e');
    }
    
    return sections;
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

