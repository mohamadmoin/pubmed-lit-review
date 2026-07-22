import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:provider/provider.dart';
import '../../../core/models/document_model.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme.dart';
import 'document_generation_progress_screen.dart';
import '../../components/app_top_bar.dart';

class DocumentGenerationPage extends StatefulWidget {
  const DocumentGenerationPage({Key? key}) : super(key: key);

  @override
  _DocumentGenerationPageState createState() => _DocumentGenerationPageState();
}

class _DocumentGenerationPageState extends State<DocumentGenerationPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _wordCount = 2000;
  bool _isGenerating = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildGenerationForm(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _buildInfoPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerationForm() {
    return GlassContainer.clearGlass(
      height: double.infinity,
      width: double.infinity,
      color: Colors.white.withOpacity(0.3),
      borderRadius: BorderRadius.circular(18),
      elevation: 20,
      blur: 0.5,
      borderColor: Colors.white.withOpacity(0.6),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.6),
          Colors.white.withOpacity(0.3),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate AI Document',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _subjectController,
                label: 'Subject',
                hint: 'Enter the main subject of your document',
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe what you want the document to cover',
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              _buildWordCountSlider(),
              const SizedBox(height: 32),
              _buildGenerateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            color: AppColors.primaryText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: AppColors.tertiaryText,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.accentPurple,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildWordCountSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Word Count: $_wordCount',
          style: GoogleFonts.poppins(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.accentPurple,
            inactiveTrackColor: AppColors.accentPurple.withOpacity(0.2),
            thumbColor: AppColors.accentPurple,
            overlayColor: AppColors.accentPurple.withOpacity(0.1),
          ),
          child: Slider(
            value: _wordCount.toDouble(),
            min: 1000,
            max: 5000,
            divisions: 40,
            onChanged: (value) {
              setState(() {
                _wordCount = value.round();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _handleGenerate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isGenerating
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                'Generate Document',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return GlassContainer.clearGlass(
      height: double.infinity,
      width: double.infinity,
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(18),
      elevation: 15,
      blur: 0.5,
      borderColor: Colors.white.withOpacity(0.5),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Document Generation',
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'How it works',
              content: 'Our AI system will:',
              bulletPoints: [
                'Search relevant academic papers',
                'Generate comprehensive summaries',
                'Create structured content',
                'Add proper citations',
                'Format the final document'
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoCard(
              title: 'Tips',
              content: 'For best results:',
              bulletPoints: [
                'Be specific with your subject',
                'Provide detailed description',
                'Include key aspects to cover',
                'Specify target audience if any'
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required List<String> bulletPoints,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: AppColors.accentBlue,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(
              color: AppColors.primaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...bulletPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 14,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _handleGenerate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      print(_subjectController.text);
      print(_descriptionController.text);
      print(_wordCount);
      await Provider.of<DocumentProvider>(context, listen: false)
          .generateDocument(
        subject: _subjectController.text,
        description: _descriptionController.text,
        wordCount: _wordCount,
      );

      // Navigate to the progress tracking screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DocumentGenerationProgressScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Extract error message from the response if available
        String errorMessage = e.toString();
        if (errorMessage.contains('Failed to generate document: ')) {
          errorMessage = errorMessage.replaceAll('Exception: Failed to generate document: ', '');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
} 