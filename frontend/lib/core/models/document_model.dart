import 'package:flutter/foundation.dart';

class Author {
  final String lastname;
  final String firstname;
  final String initials;
  final String affiliation;

  Author({
    required this.lastname,
    required this.firstname,
    required this.initials,
    required this.affiliation,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      lastname: json['lastname']?.toString() ?? '',
      firstname: json['firstname']?.toString() ?? '',
      initials: json['initials']?.toString() ?? '',
      affiliation: json['affiliation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastname': lastname,
      'firstname': firstname,
      'initials': initials,
      'affiliation': affiliation,
    };
  }
}

class AIGeneratedDocument {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final String filePath;
  final String subject;
  final int wordCount;
  final bool isCompleted;
  final List<DocumentSection> sections;
  final List<DocumentReference> references;
  final List<ProcessLogEntry> processLogs;

  AIGeneratedDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.filePath,
    required this.subject,
    required this.wordCount,
    this.isCompleted = false,
    required this.sections,
    required this.references,
    required this.processLogs,
  });

  factory AIGeneratedDocument.fromJson(Map<String, dynamic> json) {
    return AIGeneratedDocument(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['content']?.toString() ?? json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      filePath: json['file_path']?.toString() ?? json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? json['title']?.toString() ?? '',
      wordCount: json['word_count']?.toInt() ?? 0,
      isCompleted: json['is_completed']?.toBool() ?? false,
      sections: (json['sections'] as List?)
          ?.map((section) => DocumentSection.fromJson(section))
          .toList() ?? [],
      references: (json['references'] as List?)
          ?.map((ref) => DocumentReference.fromJson(ref))
          .toList() ?? [],
      processLogs: (json['processLogs'] as List?)
          ?.map((log) => ProcessLogEntry.fromJson(log))
          .toList() ?? [],
    );
  }
  
  // Method to convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': description,
      'created_at': createdAt.toIso8601String(),
      'file_path': filePath,
      'subject': subject,
      'word_count': wordCount,
      'is_completed': isCompleted,
      'sections': sections.map((s) => s.toJson()).toList(),
      'references': references.map((r) => r.toJson()).toList(),
      'process_logs': processLogs.map((l) => l.toJson()).toList(),
    };
  }
}

class DocumentSection {
  final String id;
  final String title;
  final String content;
  final List<PaperInstanse> preFilteredPapers;
  final List<PaperInstanse> filteredPapers;
  final List<PaperInstanse> selectedPapers;
  final List<DocumentCitation> citations;

  DocumentSection({
    required this.id,
    required this.title,
    required this.content,
    required this.preFilteredPapers,
    required this.filteredPapers,
    required this.selectedPapers,
    required this.citations,
  });

  factory DocumentSection.fromJson(Map<String, dynamic> json) {
    // print("id:");
    // print(json['id']?.toString());
    // print("title:");
    // print(json['title']?.toString());
    // print("content:");
    // print(json['content']?.toString());
    // print("id:");
    // print(json['id']?.toString());
    // print("id:");
    // print(json['id']?.toString());

var selectedPapers = <PaperInstanse>[];
var preFilteredPapers = <PaperInstanse>[];
var filteredPapers = <PaperInstanse>[];
    // Create a map of papers for easy lookup (prefer entries with full-text data)
    final papersMap = <String, PaperInstanse>{};

    void rememberPaper(PaperInstanse paper) {
      if (paper.pmid.isEmpty) return;
      final existing = papersMap[paper.pmid];
      papersMap[paper.pmid] = existing == null
          ? paper
          : PaperInstanse.merge(existing, paper);
    }
    try{
     preFilteredPapers = (json['pre_filtered_papers'] as List?)
        ?.map((paper) {
          if (paper == null) return null;
          try {
            final paperInstance = PaperInstanse.fromJson(
                paper is Map<String, dynamic> ? paper : {'pmid': paper.toString()});
            if (paperInstance.pmid.isNotEmpty) {
              rememberPaper(paperInstance);
              return paperInstance;
            }
          } catch (e) {
            debugPrint('Error parsing pre-filtered paper: $e');
          }
          return null;
        })
        .whereType<PaperInstanse>() // Remove null values
        .toList() ?? [];
    }catch(e){
      
      print("pre_filtered_papers error: $e");
    }
    try{
    // Create filtered papers list using pre-filtered papers data
     filteredPapers = (json['filtered_papers'] as List?)
        ?.map((paper) {
          if (paper == null) return null;
          try {
            if (paper is Map<String, dynamic> && paper.containsKey('pmid')) {
              final pmid = paper['pmid']?.toString() ?? '';
              if (papersMap.containsKey(pmid)) {
                return papersMap[pmid]!;
              }
              final parsed = PaperInstanse.fromJson(paper);
              rememberPaper(parsed);
              return parsed;
            } else {
              return PaperInstanse.fromJson({'pmid': paper.toString()});
            }
          } catch (e) {
            debugPrint('Error parsing filtered paper: $e');
            return null;
          }
        })
        .whereType<PaperInstanse>() // Remove null values
        .toList() ?? [];
    }catch(e){
      
      print("filtered_papers error: $e");
    }
    try{
    // Create selected papers list using merged paper data
     selectedPapers = (json['selected_papers'] as List?)
        ?.map((paper) {
          if (paper == null) return null;
          try {
            if (paper is Map<String, dynamic> && paper.containsKey('pmid')) {
              final pmid = paper['pmid']?.toString() ?? '';
              if (papersMap.containsKey(pmid)) {
                return papersMap[pmid]!;
              }
              final parsed = PaperInstanse.fromJson(paper);
              rememberPaper(parsed);
              return parsed;
            } else {
              return PaperInstanse.fromJson({'pmid': paper.toString()});
            }
          } catch (e) {
            debugPrint('Error parsing selected paper: $e');
            return null;
          }
        })
        .whereType<PaperInstanse>() // Remove null values
        .toList() ?? [];
    }catch(e){
      
      print("selected_papers error: $e");
    }
    try{
    return DocumentSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      preFilteredPapers: preFilteredPapers,
      filteredPapers: filteredPapers,
      selectedPapers: selectedPapers,
      citations: (json['cited_papers'] as List?)
          ?.map((citation) {
            if (citation == null) return null;
            try {
              return DocumentCitation.fromJson(
                  citation is Map<String, dynamic> ? citation : {'pmid': citation.toString()});
            } catch (e) {
              debugPrint('Error parsing citation: $e');
              return null;
            }
          })
          .whereType<DocumentCitation>() // Remove null values
          .toList() ?? [],
    );
    }catch(e){
      print("citation error $e");
      return DocumentSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      preFilteredPapers: preFilteredPapers,
      filteredPapers: filteredPapers,
      selectedPapers: selectedPapers,
      citations: [],
    );
      
    }
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'pre_filtered_papers': preFilteredPapers.map((p) => p.toJson()).toList(),
      'filtered_papers': filteredPapers.map((p) => p.toJson()).toList(),
      'selected_papers': selectedPapers.map((p) => p.toJson()).toList(),
      'cited_papers': citations.map((c) => c.toJson()).toList(),
    };
  }
}

class PaperInstanse {
  final String id;
  final String pmid;
  final String title;
  final List<Author> authors;
  final String journal;
  final String publicationDate;
  final String abstract;
  final double relevanceScore;
  final String? summary;
  final String? fullText;
  final String? fullTextPreview;
  final bool hasFullText;
  final String? pmcId;

  bool get hasSummary => summary?.isNotEmpty ?? false;

  String get authorString => authors.map((a) => '${a.lastname}, ${a.firstname}').join('; ');

  PaperInstanse({
    required this.id,
    required this.pmid,
    required this.title,
    required this.authors,
    required this.journal,
    required this.publicationDate,
    required this.abstract,
    required this.relevanceScore,
    this.summary,
    this.fullText,
    this.fullTextPreview,
    this.hasFullText = false,
    this.pmcId,
  });

  factory PaperInstanse.fromJson(Map<String, dynamic> json) {
    List<Author> parseAuthors(dynamic authorsData) {
      if (authorsData == null) return [];
      
      // If authorsData is a string, parse it as a comma-separated list of authors
      if (authorsData is String) {
        try {
          // Split the string by comma and space
          final authorStrings = authorsData.split(', ');
          
          return authorStrings.map((authorStr) {
            // Split each author into parts
            final parts = authorStr.split(' ');
            if (parts.length >= 2) {
              return Author(
                lastname: parts[0],
                firstname: parts[1],
                initials: parts.length > 2 ? parts.sublist(2).join(' ') : '',
                affiliation: '',
              );
            } else {
              return Author(
                lastname: authorStr,
                firstname: '',
                initials: '',
                affiliation: '',
              );
            }
          }).toList();
        } catch (e) {
          debugPrint('Error parsing authors string: $e');
          return [];
        }
      }

      if (authorsData is List) {
        return authorsData.map((author) {
          if (author is Map<String, dynamic>) {
            return Author.fromJson(author);
          }
          if (author is String) {
            return Author(
              lastname: author,
              firstname: '',
              initials: '',
              affiliation: '',
            );
          }
          return Author(
            lastname: author.toString(),
            firstname: '',
            initials: '',
            affiliation: '',
          );
        }).toList();
      }
      
      return [];
    }

    // Handle PMID that might contain newlines
    String cleanPmid(dynamic pmid) {
      if (pmid == null) return '';
      String pmidStr = pmid.toString();
      // Take the first PMID if multiple are provided
      return pmidStr.split('\n').first.trim();
    }

    // If the JSON only contains pmid, create a minimal PaperInstanse
    if (json.length == 1 && json.containsKey('pmid')) {
      return PaperInstanse(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pmid: cleanPmid(json['pmid']),
        title: '',
        authors: [],
        journal: '',
        publicationDate: '',
        abstract: '',
        relevanceScore: 1.0,
      );
    }

    return PaperInstanse(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      pmid: cleanPmid(json['pmid']),
      title: json['title']?.toString() ?? '',
      authors: parseAuthors(json['authors']),
      journal: json['journal']?.toString() ?? '',
      publicationDate: json['publication_date']?.toString() ?? '',
      abstract: json['abstract']?.toString() ?? '',
      relevanceScore: 1.0,
      summary: json['summary']?.toString(),
      fullText: json['full_text']?.toString(),
      fullTextPreview: json['full_text_preview']?.toString(),
      hasFullText: json['has_full_text'] == true ||
          (json['full_text_preview']?.toString().isNotEmpty ?? false) ||
          (json['full_text']?.toString().isNotEmpty ?? false),
      pmcId: json['pmc_id']?.toString(),
    );
  }

  /// Merge two paper records, preferring non-empty full-text and metadata fields.
  static PaperInstanse merge(PaperInstanse base, PaperInstanse overlay) {
    String pick(String? primary, String? fallback) {
      if (primary != null && primary.isNotEmpty) return primary;
      return fallback ?? '';
    }

    String? pickNullable(String? primary, String? fallback) {
      if (primary != null && primary.isNotEmpty) return primary;
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return null;
    }

    return PaperInstanse(
      id: pick(overlay.id, base.id),
      pmid: pick(overlay.pmid, base.pmid),
      title: pick(overlay.title, base.title),
      authors: overlay.authors.isNotEmpty ? overlay.authors : base.authors,
      journal: pick(overlay.journal, base.journal),
      publicationDate: pick(overlay.publicationDate, base.publicationDate),
      abstract: pick(overlay.abstract, base.abstract),
      relevanceScore: overlay.relevanceScore != 1.0 ? overlay.relevanceScore : base.relevanceScore,
      summary: pickNullable(overlay.summary, base.summary),
      fullText: pickNullable(overlay.fullText, base.fullText),
      fullTextPreview: pickNullable(overlay.fullTextPreview, base.fullTextPreview),
      hasFullText: overlay.hasFullText || base.hasFullText,
      pmcId: pickNullable(overlay.pmcId, base.pmcId),
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pmid': pmid,
      'title': title,
      'authors': authors.map((a) => a.toJson()).toList(),
      'journal': journal,
      'publicationDate': publicationDate,
      'abstract': abstract,
      'summary': summary,
      'relevanceScore': relevanceScore,
      'full_text': fullText,
      'full_text_preview': fullTextPreview,
      'has_full_text': hasFullText,
      'pmc_id': pmcId,
    };
  }
}

class DocumentCitation {
  final String id;
  final String pmid;
  final String title;
  final String authors;
  final String journal;
  final String publicationDate;
  final String citationText;
  final int positionInSection;

  DocumentCitation({
    required this.id,
    required this.pmid,
    required this.title,
    required this.authors,
    required this.journal,
    required this.publicationDate,
    required this.citationText,
    required this.positionInSection,
  });

  factory DocumentCitation.fromJson(Map<String, dynamic> json) {
    String parseAuthors(dynamic authorsData) {
      if (authorsData == null) return '';
      
      if (authorsData is String) {
        return authorsData;
      }
      
      if (authorsData is List) {
        return authorsData
            .map((author) => '${author['lastname']}, ${author['firstname']}')
            .join('; ');
      }
      
      return '';
    }

    return DocumentCitation(
      id: json['id']?.toString() ?? '',
      pmid: json['pmid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      authors: parseAuthors(json['authors']),
      journal: json['journal']?.toString() ?? '',
      publicationDate: json['publication_date']?.toString() ?? json['publicationDate']?.toString() ?? '',
      citationText: json['citation_text']?.toString() ?? json['citationText']?.toString() ?? '[${json['pmid']}]',
      positionInSection: json['position_in_section']?.toInt() ?? json['positionInSection']?.toInt() ?? 0,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pmid': pmid,
      'title': title,
      'authors': authors,
      'journal': journal,
      'publicationDate': publicationDate,
      'citationText': citationText,
      'positionInSection': positionInSection,
    };
  }
}

class DocumentReference {
  final String id;
  final String pmid;
  final String formattedReference;
  final List<String> citedInSectionIds;

  DocumentReference({
    required this.id,
    required this.pmid,
    required this.formattedReference,
    required this.citedInSectionIds,
  });

  factory DocumentReference.fromJson(Map<String, dynamic> json) {
    return DocumentReference(
      id: json['id']?.toString() ?? '',
      pmid: json['pmid']?.toString() ?? '',
      formattedReference: json['formatted_reference']?.toString() ?? '',
      citedInSectionIds: (json['cited_in_section_ids'] as List?)
          ?.map((id) => id.toString())
          .toList() ?? [],
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pmid': pmid,
      'formatted_reference': formattedReference,
      'cited_in_section_ids': citedInSectionIds,
    };
  }
}

class SearchTerm {
  final String id;
  final String term;
  final List<String> foundPaperIds;
  final String sectionId;

  SearchTerm({
    required this.id,
    required this.term,
    required this.foundPaperIds,
    required this.sectionId,
  });

  factory SearchTerm.fromJson(Map<String, dynamic> json) {
    return SearchTerm(
      id: json['id'],
      term: json['term'],
      foundPaperIds: List<String>.from(json['foundPaperIds']),
      sectionId: json['sectionId'],
    );
  }
}

class ProcessLogEntry {
  final String id;
  final DateTime timestamp;
  final String? message;
  final String? level;
  final String? source;

  ProcessLogEntry({
    required this.id,
    required this.timestamp,
    this.message,
    this.level,
    this.source,
  });

  factory ProcessLogEntry.fromJson(Map<String, dynamic> json) {
   
    return ProcessLogEntry(
      id: json['id'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      message: json['message'],
      level: json['level'],
      source: json['source'],
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'level': level,
      'source': source,
    };
  }
}

class GraphRelationship {
  final String sourceId;
  final String targetId;
  final String type;
  final Map<String, dynamic>? properties;

  GraphRelationship({
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.properties,
  });

  factory GraphRelationship.fromJson(Map<String, dynamic> json) {
    return GraphRelationship(
      sourceId: json['sourceId'],
      targetId: json['targetId'],
      type: json['type'],
      properties: json['properties'],
    );
  }
}
