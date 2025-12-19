import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
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
    
    // Créer les sections pour l'affichage simple
    final List<Map<String, String>> sections = _buildSections();
    
    // Détection responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallMobile = screenWidth < 361;
    final isSmallMobile = screenWidth < 431;
    final isMobile = screenWidth < 768;
    
    // Titre traduit
    String privacyTitle = widget.translationService.translate('APPFOOTER_PRIVACY_POLICY');
    if (privacyTitle == 'APPFOOTER_PRIVACY_POLICY') {
      // Fallback sur d'autres clés ou texte par défaut si la traduction manque
      privacyTitle = widget.translationService.translate('PRIVACY_POLICY_TITLE');
      if (privacyTitle == 'PRIVACY_POLICY_TITLE') {
        privacyTitle = 'Politique de confidentialité';
      }
    }
    
    // ✅ Nettoyer le titre pour enlever les balises HTML éventuelles (ex: <h1>)
    privacyTitle = _extractTextFromHtml(privacyTitle);
    
    // Bouton fermer traduit
    String closeButton = widget.translationService.translate('ONBOARDING_VALIDATE');
    if (closeButton == 'ONBOARDING_VALIDATE') {
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
                      Icons.privacy_tip_outlined,
                      color: Colors.white,
                      size: isVerySmallMobile ? 22 : (isSmallMobile ? 24 : 26),
                    ),
                  ),
                  
                  SizedBox(width: isVerySmallMobile ? 12 : 16),
                  
                  // Titre
                  Expanded(
                    child: Text(
                      privacyTitle,
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
                    child: _buildPrivacyContent(sections, isVerySmallMobile, isSmallMobile, isMobile),
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
    
    // La clé principale pour la politique de confidentialité est HTML_TERMS_BODY-POLICY
    final htmlContent = widget.translationService.translate('HTML_TERMS_BODY-POLICY');
    
    if (htmlContent != 'HTML_TERMS_BODY-POLICY' && htmlContent.isNotEmpty) {
      // Parser le contenu pour extraire les sections (h2, h3)
      final parsedSections = _parseHtmlContentToSections(htmlContent);
      
      if (parsedSections.isNotEmpty) {
        // Utiliser les sections parsées
        for (final section in parsedSections) {
          final title = section['title'] ?? '';
          final text = section['text'] ?? '';
          
          if (text.isNotEmpty) {
            // Extraire et nettoyer le texte du HTML
            final cleanedText = _extractTextFromHtml(text);
            
            // ✅ Nettoyer le texte une deuxième fois pour supprimer toute indentation résiduelle
            final finalText = cleanedText
                .replaceAll(RegExp(r'^\s+', multiLine: true), '') // Supprimer espaces au début de chaque ligne
                .replaceAll(RegExp(r'\t'), ' ') // Remplacer tabulations par espaces
                .replaceAll(RegExp(r' {2,}'), ' ') // Normaliser espaces multiples
                .trim();
            
            // Créer une section simple avec titre et texte
            sections.add({
              'title': title.isNotEmpty ? title : 'Politique de confidentialité',
              'text': finalText,
            });
          }
        }
      } else {
        // Si le parsing échoue, utiliser le texte complet
        final textContent = _extractTextFromHtml(htmlContent);
        if (textContent.isNotEmpty) {
          final cleanedText = textContent
              .replaceAll(RegExp(r'^\s+', multiLine: true), '')
              .replaceAll(RegExp(r'\t'), ' ')
              .replaceAll(RegExp(r' {2,}'), ' ')
              .trim();
          
          sections.add({
            'title': 'Politique de confidentialité',
            'text': cleanedText,
          });
        }
      }
    }
    
    // Si aucune section n'est trouvée, ajouter une section par défaut
    if (sections.isEmpty) {
      sections.add({
        'title': 'Politique de confidentialité',
        'text': 'Cette politique de confidentialité décrit comment Jirig collecte, utilise et protège vos données personnelles.\n\n'
            'Pour plus d\'informations, consultez notre politique complète.',
      });
    }
    
    return sections;
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
      
      // Parcourir tous les éléments du body
      for (final element in body.children) {
        final tagName = element.localName?.toLowerCase() ?? '';
        
        if (tagName == 'h2' || tagName == 'h3') {
          // Si on a déjà du contenu, sauvegarder la section précédente
          if (currentTitle.isNotEmpty || currentText.isNotEmpty) {
            sections.add({
              'title': currentTitle,
              'text': currentText.trim(),
            });
            currentText = '';
          }
          
          // Nouveau titre
          currentTitle = element.text.trim();
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
            });
            currentTitle = '';
            currentText = '';
          }
        }
      }
      
      // Ajouter la dernière section
      if (currentTitle.isNotEmpty || currentText.isNotEmpty) {
        sections.add({
          'title': currentTitle,
          'text': currentText.trim(),
        });
      }
    } catch (e) {
      // Si le parsing échoue, retourner une liste vide
      print('Erreur lors du parsing HTML: $e');
    }
    
    return sections;
  }

  /// Construit le contenu de la politique de confidentialité de manière simple
  Widget _buildPrivacyContent(List<Map<String, String>> sections, bool isVerySmallMobile, bool isSmallMobile, bool isMobile) {
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

