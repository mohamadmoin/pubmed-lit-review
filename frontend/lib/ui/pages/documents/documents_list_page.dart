import 'package:flutter/material.dart';
import 'package:litreview_app/core/theme/app_fonts.dart';
import 'package:litreview_app/ui/widgets/glass_panel.dart';
import 'package:provider/provider.dart';
import 'package:litreview_app/ui/pages/documents/document_preview_screen.dart';
import '../../../core/models/document_model.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/theme/colors.dart';
import '../../components/app_top_bar.dart';
import 'document_view_page.dart';
import 'dart:async';
import 'document_generation_page.dart';

class DocumentsListPage extends StatefulWidget {
  const DocumentsListPage({Key? key}) : super(key: key);

  @override
  _DocumentsListPageState createState() => _DocumentsListPageState();
}

class _DocumentsListPageState extends State<DocumentsListPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh document list every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        Provider.of<DocumentProvider>(context, listen: false).refreshDocuments();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
        child: Consumer<DocumentProvider>(
          builder: (context, documentProvider, child) {
            if (documentProvider.isLoading && documentProvider.documents.isEmpty) {
              return _buildLoadingView();
            }

            if (documentProvider.error != null && documentProvider.documents.isEmpty) {
              return _buildErrorView(documentProvider.error!);
            }

            if (documentProvider.documents.isEmpty) {
              return _buildEmptyView();
            }

            return _buildDocumentsList(context, documentProvider);
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'generate',
            backgroundColor: AppColors.accentPurple,
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DocumentGenerationPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'refresh',
            backgroundColor: AppColors.accentPurple,
            child: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<DocumentProvider>(context, listen: false)
                  .refreshDocuments();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.accentPurple,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading documents...',
            style: AppFonts.inter(
              color: AppColors.primaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading documents',
            style: AppFonts.heading(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppFonts.inter(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade700),
            ),
            child: Column(
              children: [
                Text(
                  'Troubleshooting:',
                  style: AppFonts.heading(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Ensure Django API is running (python manage.py runserver)\n2. Verify Neo4j is running\n3. Check network connectivity',
                  style: AppFonts.inter(
                    color: Colors.orange.shade900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Provider.of<DocumentProvider>(context, listen: false).refreshDocuments();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: AppColors.tertiaryText,
          ),
          const SizedBox(height: 16),
          Text(
            'No AI-Generated Documents',
            style: AppFonts.heading(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI-generated documents will appear here',
            style: AppFonts.inter(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(BuildContext context, DocumentProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI-Generated Documents',
            style: AppFonts.heading(
              color: AppColors.primaryText,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a document to view its content and sources',
            style: AppFonts.inter(
              color: AppColors.secondaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshDocuments(),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: provider.documents.length,
                itemBuilder: (context, index) {
                  final document = provider.documents[index];
                  return _buildDocumentCard(context, document);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, AIGeneratedDocument document) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentPreviewScreen(documentId: document.id),
            // DocumentViewPage(documentId: document.id),
          ),
        );
      },
      child: GlassContainer.clearGlass(
        height: double.infinity,
        width: double.infinity,
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        elevation: 10,
        blur: 0.5,
        borderColor: Colors.white.withOpacity(0.7),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.7),
            Colors.white.withOpacity(0.4),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: AppColors.accentPurple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI-Generated',
                        style: AppFonts.inter(
                          color: AppColors.accentPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(document.createdAt),
                  style: AppFonts.inter(
                    color: AppColors.tertiaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: AppFonts.heading(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    document.description,
                    style: AppFonts.inter(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  Icons.text_fields,
                  '${document.wordCount} words',
                ),
                _buildInfoChip(
                  Icons.subject,
                  '${document.sections.length} sections',
                ),
                _buildInfoChip(
                  Icons.format_quote,
                  '${document.references.length} refs',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.accentBlue,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppFonts.inter(
              color: AppColors.accentBlue,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 