import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/terms_of_use_modal.dart';
import '../widgets/privacy_policy_modal.dart';
import '../widgets/faq_widget.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  
  // ✅ Sujet sélectionné depuis le dropdown
  String? _selectedSubject;
  
  // ✅ Clé pour scroller jusqu'au formulaire
  final GlobalKey _formSectionKey = GlobalKey();
  
  bool _isLoading = false;
  
  // ✅ FAQ
  List<Map<String, dynamic>> _faqList = [];
  bool _isLoadingFaq = false;
  Set<int> _expandedFaqItems = {};
  
  // Informations de contact
  final String _supportEmail = 'jirig@jirig.com';
  final String? _supportPhone = null; // Ajoutez un numéro si disponible

  // ✨ Animations
  late AnimationController _contactController;
  late AnimationController _formController;
  late AnimationController _linksController;
  
  late Animation<Offset> _contactSlideAnimation;
  late Animation<double> _contactFadeAnimation;
  
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _formFadeAnimation;
  
  late Animation<Offset> _linksSlideAnimation;
  late Animation<double> _linksFadeAnimation;
  
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  /// ✨ Initialiser les animations (Style "Cascade Support")
  void _initializeAnimations() {
    try {
      _animationsInitialized = true;
      
      // Section Contact : Slide from top + Fade
      _contactController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      
      _contactSlideAnimation = Tween<Offset>(
        begin: const Offset(0, -0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _contactController,
        curve: Curves.easeOutCubic,
      ));
      
      _contactFadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _contactController,
        curve: Curves.easeIn,
      ));
      
      // Section Formulaire : Slide from bottom + Fade
      _formController = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      
      _formSlideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _formController,
        curve: Curves.easeOutCubic,
      ));
      
      _formFadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _formController,
        curve: Curves.easeIn,
      ));
      
      // Section Liens Utiles : Slide from bottom + Fade
      _linksController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      _linksSlideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _linksController,
        curve: Curves.easeOutCubic,
      ));
      
      _linksFadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _linksController,
        curve: Curves.easeIn,
      ));
      
      print('✅ Animations Support initialisées');
      
      // Démarrer les animations de manière échelonnée
      _startStaggeredAnimations();
    } catch (e) {
      print('❌ Erreur initialisation animations support: $e');
      _animationsInitialized = false;
    }
  }

  /// Démarrer les animations de manière échelonnée
  void _startStaggeredAnimations() async {
    // Section Contact (immédiate)
    _contactController.forward();
    
    // Section Formulaire (après 200ms)
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _formController.forward();
    
    // Section Liens Utiles (après 400ms)
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _linksController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    
    // Dispose des animations
    if (_animationsInitialized) {
      _contactController.dispose();
      _formController.dispose();
      _linksController.dispose();
    }
    
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Appel API au backend SNAL-Project
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      final response = await apiService.dio.post(
        '/contact',
        data: {
          'sName': _nameController.text.trim(),
          'sEmail': _emailController.text.trim(),
          'sSubject': _selectedSubject ?? '',
          'sMessage': _messageController.text.trim(),
        },
      );

      // Vérifier la réponse
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _isLoading = false;
        });
        
        // ✅ Afficher un popup de succès
        await _showSuccessDialog();
        
        // Réinitialiser le formulaire après la fermeture du popup
        if (mounted) {
          setState(() {
            _formKey.currentState!.reset();
            _nameController.clear();
            _emailController.clear();
            _selectedSubject = null;
            _messageController.clear();
          });
        }
      } else {
        throw Exception(response.data['message'] ?? 'Erreur lors de l\'envoi du message');
      }
    } on DioException catch (e) {
      // ✅ Gestion d'erreur améliorée avec DioException
      String errorMessage = 'Erreur lors de l\'envoi du message';
      
      if (e.response != null) {
        // Erreur avec réponse du serveur
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        
        if (statusCode == 400) {
          errorMessage = responseData?['message'] ?? 
                        'Vérifiez que tous les champs sont remplis correctement';
        } else if (statusCode == 500) {
          errorMessage = 'Erreur serveur. Veuillez réessayer plus tard';
        } else {
          errorMessage = responseData?['message'] ?? errorMessage;
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Timeout de connexion. Vérifiez votre connexion internet';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Erreur de connexion. Vérifiez votre connexion internet';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Erreur générique
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openEmail() async {
    final mailtoUri = Uri.parse('mailto:$_supportEmail');
    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'application email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openPhone() async {
    if (_supportPhone != null) {
      final telUri = Uri.parse('tel:$_supportPhone');
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      }
    }
  }

  /// ✅ Afficher un popup de succès avec animation
  Future<void> _showSuccessDialog() async {
    final translationService = Provider.of<TranslationService>(context, listen: false);
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Fermer automatiquement après 3 secondes
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Icône de succès avec animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // ✅ Titre
                Text(
                  translationService.translate('SUPPORT_SUCCESS_TITLE'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // ✅ Message
                Text(
                  translationService.translate('SUPPORT_SUCCESS_MESSAGE'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // ✅ Bouton OK
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0051BA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      translationService.translate('SUPPORT_SUCCESS_BUTTON'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: const CustomAppBar(),
      ),
      body: Consumer<TranslationService>(
        builder: (context, translationService, child) {
          // Vérifier que le service est disponible
          if (translationService == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 24 : 32)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Contact Direct avec animation
                  if (_animationsInitialized)
                    FadeTransition(
                      opacity: _contactFadeAnimation,
                      child: SlideTransition(
                        position: _contactSlideAnimation,
                        child: _buildContactSection(isMobile, translationService),
                      ),
                    )
                  else
                    _buildContactSection(isMobile, translationService),
                  
                  const SizedBox(height: 24),

                  // Section Formulaire avec animation
                  if (_animationsInitialized)
                    FadeTransition(
                      opacity: _formFadeAnimation,
                      child: SlideTransition(
                        position: _formSlideAnimation,
                        child: _buildFormSection(isMobile, isTablet, translationService, key: _formSectionKey),
                      ),
                    )
                  else
                    _buildFormSection(isMobile, isTablet, translationService, key: _formSectionKey),

                  const SizedBox(height: 24),

                  // Section FAQ avec animation
                  if (_animationsInitialized)
                    FadeTransition(
                      opacity: _linksFadeAnimation,
                      child: SlideTransition(
                        position: _linksSlideAnimation,
                        child: _buildFaqSection(isMobile, translationService),
                      ),
                    )
                  else
                    _buildFaqSection(isMobile, translationService),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 4),
    );
  }

  Widget _buildContactSection(bool isMobile, TranslationService translationService) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0051BA).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0051BA).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0051BA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.contact_support,
                  color: Color(0xFF0051BA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                translationService.translate('FRONTPAGE_Msg27'),
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            translationService.translate('FRONTPAGE_Msg28'),
            style: TextStyle(
              fontSize: isMobile ? 14 : 15,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          // Bouton Email
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openEmail,
              icon: const Icon(Icons.email_outlined, color: Color(0xFF0051BA)),
              label: Text(
                _supportEmail,
                style: const TextStyle(
                  color: Color(0xFF0051BA),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isMobile ? 14 : 16,
                ),
                side: const BorderSide(color: Color(0xFF0051BA), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Bouton Téléphone (si disponible)
          if (_supportPhone != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openPhone,
                icon: const Icon(Icons.phone_outlined, color: Color(0xFF0051BA)),
                label: Text(
                  _supportPhone!,
                  style: const TextStyle(
                    color: Color(0xFF0051BA),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isMobile ? 14 : 16,
                  ),
                  side: const BorderSide(color: Color(0xFF0051BA), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormSection(bool isMobile, bool isTablet, TranslationService translationService, {Key? key}) {
    return Container(
      key: key,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0051BA).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0051BA).withOpacity(0.1),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0051BA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.message_outlined,
                    color: Color(0xFF0051BA),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  translationService.translate('FRONTPAGE_Msg29'),
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Champ Nom
            _buildTextField(
              translationService.translate('FRONTPAGE_Msg30'),
              _nameController,
              Icons.person_outlined,
              isMobile,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return translationService.translate('SUPPORT_NAME_REQUIRED');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Champ Email
            _buildTextField(
              translationService.translate('FRONTPAGE_Msg31'),
              _emailController,
              Icons.email_outlined,
              isMobile,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return translationService.translate('SUPPORT_EMAIL_REQUIRED');
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return translationService.translate('SUPPORT_EMAIL_INVALID');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Champ Sujet (Dropdown)
            _buildSubjectDropdown(
              translationService,
              isMobile,
            ),
            const SizedBox(height: 16),

            // Champ Message
            _buildTextField(
              translationService.translate('FRONTPAGE_Msg41'),
              _messageController,
              Icons.message_outlined,
              isMobile,
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return translationService.translate('SUPPORT_MESSAGE_REQUIRED');
                }
                if (value.trim().length < 10) {
                  return translationService.translate('SUPPORT_MESSAGE_TOO_SHORT');
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Bouton Envoyer
            SizedBox(
              width: double.infinity,
              height: isMobile ? 48 : 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0051BA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            translationService.translate('FRONTPAGE_Msg43'),
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 17,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isMobile, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black87),
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[600]),
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
          borderSide: const BorderSide(color: Color(0xFF0051BA), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isMobile ? (maxLines > 1 ? 16 : 14) : (maxLines > 1 ? 18 : 16),
        ),
      ),
    );
  }

  /// ✅ Construit le dropdown pour sélectionner le sujet
  Widget _buildSubjectDropdown(TranslationService translationService, bool isMobile) {
    // Liste des options du sujet avec leurs clés de traduction
    final List<Map<String, String>> subjectOptions = [
      {
        'key': 'FRONTPAGE_Msg35',
        'value': 'selectionnez un sujet',
      },
      {
        'key': 'FRONTPAGE_Msg36',
        'value': 'Problème de prix',
      },
      {
        'key': 'FRONTPAGE_Msg37',
        'value': 'Problème technique',
      },
      {
        'key': 'FRONTPAGE_Msg38',
        'value': 'Suggestions d\'amélioration',
      },
      {
        'key': 'FRONTPAGE_Msg39',
        'value': 'Proposition de partenariat',
      },
      {
        'key': 'FRONTPAGE_Msg40',
        'value': 'Avis général / Autre',
      },
    ];

    return DropdownButtonFormField<String>(
      value: _selectedSubject,
      decoration: InputDecoration(
        labelText: translationService.translate('FRONTPAGE_Msg34'),
        labelStyle: const TextStyle(color: Colors.black87),
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(Icons.subject_outlined, color: Colors.grey[600]),
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
          borderSide: const BorderSide(color: Color(0xFF0051BA), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isMobile ? 14 : 16,
        ),
      ),
      hint: Text(
        translationService.translate('FRONTPAGE_Msg35'),
        style: TextStyle(color: Colors.grey[400]),
      ),
      items: subjectOptions
          .where((option) => option['key'] != 'FRONTPAGE_Msg35') // Exclure le placeholder
          .map((option) {
        final translatedText = translationService.translate(option['key']!);
        final optionValue = option['value']!;
        
        return DropdownMenuItem<String>(
          value: optionValue,
          child: Text(
            translatedText,
            style: const TextStyle(color: Colors.black87),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedSubject = newValue;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return translationService.translate('SUPPORT_SUBJECT_REQUIRED');
        }
        return null;
      },
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
      dropdownColor: Colors.white,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
    );
  }

  /// ✅ Construit la section FAQ avec le widget FAQ
  Widget _buildFaqSection(bool isMobile, TranslationService translationService) {
    return FaqWidget(
      isMobile: isMobile,
      onContactPressed: _scrollToForm,
    );
  }
  
  /// ✅ Scrolle jusqu'au formulaire de contact
  void _scrollToForm() {
    final context = _formSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Afficher le formulaire légèrement en haut de l'écran
      );
    }
  }

  Widget _buildLinkTile(
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
    bool isMobile,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0051BA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF0051BA), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

