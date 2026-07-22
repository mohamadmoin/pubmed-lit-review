import 'package:flutter/material.dart';
import 'package:litreview_app/ui/widgets/glass_panel.dart';
import 'package:litreview_app/core/theme/app_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/document_model.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/theme/colors.dart';
import '../../components/app_top_bar.dart';
import '../../widgets/documents/generated_document_download.dart';
import 'document_content_view.dart';
import 'document_sources_view.dart';
import 'document_process_view.dart';

class DocumentViewPage extends StatefulWidget {
  final String documentId;

  const DocumentViewPage({
    Key? key,
    required this.documentId,
  }) : super(key: key);

  @override
  _DocumentViewPageState createState() => _DocumentViewPageState();
}

class _DocumentViewPageState extends State<DocumentViewPage> {
  @override
  void initState() {
    super.initState();
    // Load the document when the page is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DocumentProvider>(context, listen: false)
          .loadDocument(widget.documentId);
    });
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
            if (documentProvider.isLoading) {
              return _buildLoadingView();
            }

            if (documentProvider.error != null) {
              return _buildErrorView(documentProvider.error!);
            }

            if (documentProvider.currentDocument == null) {
              return _buildEmptyView();
            }

            return _buildDocumentView(context, documentProvider);
          },
        ),
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
            'Loading document...',
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
            'Error loading document',
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Provider.of<DocumentProvider>(context, listen: false)
                  .loadDocument(widget.documentId);
            },
            child: Text('Retry'),
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
            'No document found',
            style: AppFonts.heading(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The requested document could not be found',
            style: AppFonts.inter(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentView(BuildContext context, DocumentProvider provider) {
    final document = provider.currentDocument!;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDocumentHeader(document),
          const SizedBox(height: 24),
          _buildTabBar(provider),
          const SizedBox(height: 24),
          Expanded(
            child: _buildTabContent(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader(AIGeneratedDocument document) {
    return GlassContainer.clearGlass(
      height: 250,
      width: double.infinity,
      color: Colors.white.withOpacity(0.3),
      borderRadius: BorderRadius.circular(18),
      elevation: 30,
      blur: 0.5,
      borderColor: Colors.white.withOpacity(0.7),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.7),
          Colors.white.withOpacity(0.4),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: AppFonts.heading(
                        color: AppColors.primaryText,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      document.description,
                      style: AppFonts.inter(
                        color: AppColors.secondaryText,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _buildDocInfoBox(document),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocInfoBox(AIGeneratedDocument document) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentBlue.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Created',
            '${document.createdAt.day}/${document.createdAt.month}/${document.createdAt.year}',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.text_fields,
            'Word Count',
            document.wordCount.toString(),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.subject,
            'Sections',
            document.sections.length.toString(),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.format_quote,
            'References',
            document.references.length.toString(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.download_outlined,
                label: 'Download',
                onTap: () => downloadGeneratedDocument(context, document),
              ),
              _buildActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.accentBlue,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppFonts.inter(
            color: AppColors.tertiaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppFonts.inter(
            color: AppColors.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: AppColors.accentBlue,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppFonts.inter(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(DocumentProvider provider) {
    return SizedBox(
      height: 50,
      child: GlassContainer.clearGlass(
        height: 50,
        width: double.infinity,
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        elevation: 10,
        blur: 0.5,
        borderColor: Colors.white.withOpacity(0.5),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.3),
          ],
        ),
        child: Row(
          children: [
            _buildTabButton(
              icon: Icons.article_outlined,
              label: 'Document',
              isActive: provider.activeTab == 'document',
              onTap: () => provider.setActiveTab('document'),
            ),
            _buildTabButton(
              icon: Icons.source_outlined,
              label: 'Sources',
              isActive: provider.activeTab == 'sources',
              onTap: () => provider.setActiveTab('sources'),
            ),
            _buildTabButton(
              icon: Icons.grain_outlined,
              label: 'Process',
              isActive: provider.activeTab == 'process',
              onTap: () => provider.setActiveTab('process'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentPurple.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppColors.accentPurple : AppColors.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppFonts.inter(
                  color: isActive ? AppColors.accentPurple : AppColors.secondaryText,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(DocumentProvider provider) {
    switch (provider.activeTab) {
      case 'document':
        return DocumentContentView(document: provider.currentDocument!);
      case 'sources':
        return DocumentSourcesView(document: provider.currentDocument!);
      case 'process':
        return DocumentProcessView(document: provider.currentDocument!);
      default:
        return DocumentContentView(document: provider.currentDocument!);
    }
  }
} 