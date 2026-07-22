import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/models/document_model.dart';
import '../../widgets/documents/document_markdown_body.dart';
import '../../widgets/documents/generated_document_download.dart';
import '../../widgets/documents/paper_citation_sheet.dart';
import '../../../core/utils/document_citation_resolver.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String documentId;
  const DocumentPreviewScreen({Key? key, required this.documentId}) : super(key: key);

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  final ScrollController _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String? _searchQuery;
  bool _showTableOfContents = false;
  bool _showReferences = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void initState() {
    super.initState();
    // Load the document when the page is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DocumentProvider>(context, listen: false)
          .loadDocument(widget.documentId, showLoading: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, documentProvider, child) {
        final document = documentProvider.currentDocument;
        if (document == null) {
          return _buildLoadingState(context);
        }

        return Scaffold(
          body: Stack(
            children: [
              // Main content
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // App bar with document title
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: true,
                    pinned: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        document.title ?? 'Untitled Document',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              Theme.of(context).colorScheme.primary.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      // Search button
                      IconButton(
                        icon: Icon(_showSearch ? Icons.close : Icons.search),
                        onPressed: () {
                          setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _searchQuery = null;
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      // Table of contents button
                      IconButton(
                        icon: const Icon(Icons.menu_book),
                        onPressed: () {
                          setState(() => _showTableOfContents = !_showTableOfContents);
                        },
                      ),
                      // References button
                      IconButton(
                        icon: const Icon(Icons.format_quote),
                        onPressed: () {
                          setState(() => _showReferences = !_showReferences);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_outlined),
                        tooltip: 'Download Word document',
                        onPressed: () => downloadGeneratedDocument(context, document),
                      ),
                    ],
                  ),

                  // Search bar
                  if (_showSearch)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.surface,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search in document...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceVariant,
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                        ),
                      ),
                    ),

                  // Document content
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _buildDocumentContent(context, document),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Table of contents panel
              if (_showTableOfContents)
                _buildTableOfContents(context, document),

              // References panel
              if (_showReferences)
                _buildReferencesPanel(context, document),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentContent(BuildContext context, AIGeneratedDocument document) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocumentMetadata(context, document),
        const SizedBox(height: 24),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => downloadGeneratedDocument(context, document),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Download Word'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ...document.sections.expand((section) => [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (section.content.trim().isNotEmpty)
                      DocumentMarkdownBody(
                        content: section.content,
                        document: document,
                        documentId: document.id,
                        paragraphStyle: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
                      )
                    else
                      Text(
                        'No content generated for this section.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ]),
        if (document.references.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildReferencesSection(context, document),
        ],
      ],
    );
  }

  Widget _buildDocumentMetadata(BuildContext context, AIGeneratedDocument document) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (document.description != null && document.description!.isNotEmpty)
            Text(
              document.description!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                'Created ${_formatDate(document.createdAt)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableOfContents(BuildContext context, AIGeneratedDocument document) {
    final theme = Theme.of(context);
    final sections = document.sections;
    final content = sections.map((section) => section.content).join('\n\n');
    final lines = content.split('\n');
    final headings = <Map<String, dynamic>>[];

    for (final line in lines) {
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line.trim());
      if (heading != null) {
        headings.add({
          'level': heading.group(1)!.length,
          'title': heading.group(2)!.trim(),
        });
      }
    }

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Table of Contents',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _showTableOfContents = false);
                    },
                  ),
                ],
              ),
            ),
            
            // Contents
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: headings.length,
                itemBuilder: (context, index) {
                  final heading = headings[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: (heading['level'] - 2) * 16.0,
                      bottom: 8,
                    ),
                    child: InkWell(
                      onTap: () {
                        // TODO: Implement scroll to heading
                        setState(() => _showTableOfContents = false);
                      },
                      child: Text(
                        heading['title'],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencesPanel(BuildContext context, AIGeneratedDocument document) {
    final theme = Theme.of(context);
    
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.format_quote,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'References',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _showReferences = false);
                    },
                  ),
                ],
              ),
            ),
            
            // References list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: document.references.length,
                itemBuilder: (context, index) {
                  final reference = document.references[index];
                  final resolver = DocumentCitationResolver(document);
                  final number = _referenceNumber(reference, index + 1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => showPaperCitationSheet(
                        context,
                        citationNumber: number,
                        resolver: resolver,
                        documentId: document.id,
                      ),
                      child: Text(
                        reference.formattedReference,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary.withOpacity(0.35),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferencesSection(BuildContext context, AIGeneratedDocument document) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'References',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        ...document.references.asMap().entries.map((entry) {
          final index = entry.key;
          final reference = entry.value;
          final resolver = DocumentCitationResolver(document);
          final number = _referenceNumber(reference, index + 1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => showPaperCitationSheet(
                context,
                citationNumber: number,
                resolver: resolver,
                documentId: document.id,
              ),
              child: Text(
                reference.formattedReference,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.85),
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading document...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we prepare your document',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  int _referenceNumber(DocumentReference reference, int fallback) {
    final match = RegExp(r'^(\d+)\.').firstMatch(reference.formattedReference.trim());
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return fallback;
  }
} 