import '../models/document_model.dart';

/// Resolved target for an in-text citation number.
class CitationTarget {
  final DocumentReference? reference;
  final PaperInstanse? paper;

  const CitationTarget({this.reference, this.paper});
}

/// Maps PMIDs and citation numbers for a generated document.
class DocumentCitationResolver {
  final AIGeneratedDocument document;
  final Map<String, int> pmidToNumber = {};
  final Map<int, CitationTarget> numberToTarget = {};

  DocumentCitationResolver(this.document) {
    _buildMaps();
  }

  PaperInstanse? findPaperByPmid(String pmid) {
    if (pmid.isEmpty) return null;
    for (final section in document.sections) {
      for (final paper in [
        ...section.selectedPapers,
        ...section.filteredPapers,
        ...section.preFilteredPapers,
        ...section.citations.map(
          (c) => PaperInstanse(
            id: c.id,
            pmid: c.pmid,
            title: c.title,
            authors: [],
            journal: c.journal,
            publicationDate: c.publicationDate,
            abstract: '',
            relevanceScore: 1.0,
          ),
        ),
      ]) {
        if (paper.pmid == pmid) return paper;
      }
    }
    return null;
  }

  void _buildMaps() {
    for (var i = 0; i < document.references.length; i++) {
      final ref = document.references[i];
      var number = i + 1;
      final leading = RegExp(r'^(\d+)\.').firstMatch(ref.formattedReference.trim());
      if (leading != null) {
        number = int.parse(leading.group(1)!);
      }
      numberToTarget.putIfAbsent(
        number,
        () => CitationTarget(
          reference: ref,
          paper: findPaperByPmid(ref.pmid),
        ),
      );
      if (ref.pmid.isNotEmpty) {
        pmidToNumber[ref.pmid] = number;
      }
    }

    var nextNumber = numberToTarget.keys.isEmpty
        ? 1
        : numberToTarget.keys.reduce((a, b) => a > b ? a : b) + 1;

    for (final section in document.sections) {
      for (final citation in section.citations) {
        if (citation.pmid.isEmpty || pmidToNumber.containsKey(citation.pmid)) {
          continue;
        }
        pmidToNumber[citation.pmid] = nextNumber;
        numberToTarget[nextNumber] = CitationTarget(
          paper: findPaperByPmid(citation.pmid),
        );
        nextNumber++;
      }

      for (final match in _pmidPattern.allMatches(section.content)) {
        final pmid = match.group(1) ?? match.group(2)!;
        if (pmidToNumber.containsKey(pmid)) continue;
        pmidToNumber[pmid] = nextNumber;
        numberToTarget[nextNumber] = CitationTarget(paper: findPaperByPmid(pmid));
        nextNumber++;
      }
    }
  }

  static final _pmidPattern = RegExp(r'\[\s*PMID:(\d+)\s*\]|PMID:(\d+)');

  String normalizeContent(String content) {
    var normalized = content;
    for (final entry in pmidToNumber.entries) {
      normalized = normalized.replaceAll('[PMID:${entry.key}]', '[${entry.value}]');
      normalized = normalized.replaceAll('[PMID: ${entry.key}]', '[${entry.value}]');
      normalized = normalized.replaceAll('PMID:${entry.key}', '[${entry.value}]');
    }
    return normalized;
  }

  CitationTarget? targetForNumber(int number) => numberToTarget[number];
}
