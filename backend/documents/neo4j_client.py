"""
Neo4j Client Module

This module provides a client for interacting with the Neo4j graph database
to store and retrieve document generation process data.
"""

from datetime import datetime
import os
import re
import uuid
import logging
from typing import Dict, List, Optional, Any, Tuple, Union
from neo4j import GraphDatabase
from django.conf import settings
from .python_document_generated_graph.ai_pubmed_search import (
    DocumentStructure,
    SearchResult,
    ContentSection
)

logger = logging.getLogger(__name__)

class Neo4jClient:
    """
    Client for interacting with Neo4j document graph database.
    
    This client provides methods to:
    1. Store and retrieve document generation process data
    2. Track user edits and versioning
    3. Manage document sections and their relationships
    4. Handle paper citations and references
    """
    
    def __init__(self, 
                 uri: str = settings.NEO4J_URI,
                 user: str = settings.NEO4J_USER, 
                 password: str = settings.NEO4J_PASSWORD):
        """
        Initialize Neo4j connection with the provided credentials.
        
        Args:
            uri: Neo4j connection URI
            user: Neo4j username
            password: Neo4j password
        """
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
        self.fs_storage_path = settings.TEXT_STORAGE_PATH
        logger.info(f"Neo4j client initialized with URI: {uri}")
        logger.info(f"Using file storage path: {self.fs_storage_path}")
    
    def close(self):
        """Close the Neo4j connection safely."""
        if self.driver:
            self.driver.close()
    
    def _run_query(self, query: str, parameters: Optional[Dict] = None) -> List:
        """
        Execute a Cypher query and return results safely.
        
        Args:
            query: Cypher query string
            parameters: Dictionary of query parameters
            
        Returns:
            List of query results
            
        Raises:
            Exception: If the Neo4j query fails
        """
        try:
            with self.driver.session() as session:
                result = session.run(query, parameters or {})
                return list(result)
        except Exception as e:
            logger.error(f"Neo4j query error: {e}")
            raise
    
    def _retrieve_text_from_file(self, path: str) -> Optional[str]:
        """
        Retrieve text content from file if path exists.
        
        Args:
            path: Path to the text file
            
        Returns:
            Text content or None if file not found
        """
        if not path:
            return None
        
        # Try potential file locations in order
        possible_paths = self._get_possible_file_paths(path)
        
        for file_path in possible_paths:
            if os.path.exists(file_path):
                logger.info(f"Found text file at: {file_path}")
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        return f.read()
                except Exception as e:
                    logger.error(f"Error reading file {file_path}: {e}")
                    break
        
        logger.error(f"Could not locate text file: {path}")
        return None
    
    def _get_possible_file_paths(self, path: str) -> List[str]:
        """
        Generate a list of possible file paths to try.
        
        Args:
            path: Original file path
            
        Returns:
            List of possible file paths
        """
        basename = os.path.basename(path)
        return [
            path if os.path.isabs(path) else os.path.join(self.fs_storage_path, basename),
            os.path.join(self.fs_storage_path, basename),
            os.path.join(settings.BASE_DIR.parent, 'data', 'text_storage', basename)
        ]
    
    def get_all_documents(self, user_id=None) -> List[Dict[str, Any]]:
        """
        Retrieve all documents from Neo4j with basic metadata.
        
        This method returns a list of documents with their basic information
        without the full content of sections and references to reduce response size.
        
        Args:
            user_id: Optional user ID to filter documents by owner
            
        Returns:
            List of document dictionaries with basic metadata
        """
        if user_id:
            query = """
            MATCH (d:Document {user_id: $user_id})
            OPTIONAL MATCH (d)-[:HAS_SECTION]->(s:Section)
            RETURN d, count(s) as section_count
            ORDER BY d.created_at DESC
            """
            results = self._run_query(query, {'user_id': str(user_id)})
        else:
            query = """
            MATCH (d:Document)
            OPTIONAL MATCH (d)-[:HAS_SECTION]->(s:Section)
            RETURN d, count(s) as section_count
            ORDER BY d.created_at DESC
            """
            results = self._run_query(query)
        
        documents = []
        
        for record in results:
            doc = record['d']
            documents.append({
                'id': doc['id'],
                'title': doc['title'],
                'description': doc['description'],
                'citation_style': doc['citation_style'],
                'status': doc['status'],
                'created_at': doc['created_at'],
                'updated_at': doc.get('updated_at'),
                'completed_at': doc.get('completed_at'),
                'error_message': doc.get('error_message'),
                'file_path': doc.get('file_path'),
                'user_id': doc.get('user_id'),
                'section_count': record['section_count']
            })
        
        return documents
    
    def create_document_structure(self, document_id: str, structure: DocumentStructure, user_id=None):
        """
        Create document structure nodes and relationships.
        
        Args:
            document_id: Document identifier
            structure: DocumentStructure object
            user_id: User ID to associate with the document
        """
        query = """
        CREATE (d:Document {
            id: $document_id,
            title: $title,
            description: $description,
            citation_style: $citation_style,
            created_at: datetime(),
            status: 'in_progress',
            user_id: $user_id
        })
        WITH d
        UNWIND $sections as section
        CREATE (s:Section {
            id: section.id,
            title: section.title,
            description: section.description,
            search_terms: section.search_terms,
            filter_keywords: section.filter_keywords,
            created_at: datetime()
        })
        CREATE (d)-[:HAS_SECTION]->(s)
        """
        
        parameters = {
            'document_id': document_id,
            'title': structure.title,
            'description': structure.description,
            'citation_style': structure.citation_style,
            'user_id': str(user_id) if user_id else None,
            'sections': [
                {
                    'id': str(uuid.uuid4()),
                    'title': s['title'],
                    'description': s['description'],
                    'search_terms': s['search_terms'],
                    'filter_keywords': s['filter_keywords']
                }
                for s in structure.sections
            ]
        }
        
        self._run_query(query, parameters)
    
    def store_search_results(self, document_id: str, results: List[SearchResult]):
        """
        Store PubMed search results and their relationships.
        
        Args:
            document_id: Document identifier
            results: List of SearchResult objects
        """
        query = """
        MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(s:Section)
        WHERE s.title = $section_title
        WITH s
        MERGE (p:Paper {
            pmid: $pmid,
            title: $title,
            authors: $authors,
            journal: $journal,
            publication_date: $publication_date,
            abstract: $abstract
        })
        CREATE (s)-[:FOUND_PAPER {
            search_term: $search_term,
            timestamp: datetime()
        }]->(p)
        """
        
        for result in results:
            parameters = {
                'document_id': document_id,
                'section_title': result.section_title,
                'pmid': result.pmid,
                'title': result.title,
                'authors': result.authors,
                'journal': result.journal,
                'publication_date': str(result.publication_date),
                'abstract': result.abstract,
                'search_term': result.search_term
            }
            self._run_query(query, parameters)
   
    def store_pre_filtered_search_results(self, document_id: str, results: List[SearchResult]):
        """
        Store PubMed search results and their relationships.
        
        Args:
            document_id: Document identifier
            results: List of SearchResult objects
        """
        query = """
        MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(s:Section)
        WHERE s.title = $section_title
        WITH s
        MERGE (p:Paper {
            pmid: $pmid,
            title: $title,
            authors: $authors,
            journal: $journal,
            publication_date: $publication_date,
            abstract: $abstract
        })
        CREATE (s)-[:FOUND_PAPER_PRE_FILTERED {
            search_term: $search_term,
            timestamp: datetime()
        }]->(p)
        """
        
        for result in results:
            parameters = {
                'document_id': document_id,
                'section_title': result.section_title,
                'pmid': result.pmid,
                'title': result.title,
                'authors': result.authors,
                'journal': result.journal,
                'publication_date': str(result.publication_date),
                'abstract': result.abstract,
                'search_term': result.search_term
            }
            self._run_query(query, parameters)
    
    def store_selected_papers(self, document_id: str, papers_by_section: Dict[str, List[SearchResult]]):
        """
        Store selected papers for each section.
        
        Args:
            document_id: Document identifier
            papers_by_section: Dictionary mapping section titles to selected papers
        """
        query = """
        MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(s:Section)
        WHERE s.title = $section_title
        WITH s
        MATCH (p:Paper {pmid: $pmid})
        CREATE (s)-[:SELECTED_PAPER {
            relevance_score: $relevance_score,
            timestamp: datetime()
        }]->(p)
        """
        
        for section_title, papers in papers_by_section.items():
            for paper in papers:
                parameters = {
                    'document_id': document_id,
                    'section_title': section_title,
                    'pmid': paper.pmid,
                    'relevance_score': paper.relevance_score
                }
                self._run_query(query, parameters)
    
    def store_full_text_paths(self, document_id: str, papers_by_section: Dict[str, List[SearchResult]]):
        """
        Store full text file paths for papers.
        
        Args:
            document_id: Document identifier
            papers_by_section: Dictionary mapping section titles to papers with full text
        """
        query = """
        MATCH (p:Paper {pmid: $pmid})
        SET p.full_text_path = $full_text_path,
            p.has_full_text = $has_full_text,
            p.pmc_id = $pmc_id
        """
        
        for section_papers in papers_by_section.values():
            for paper in section_papers:
                has_full_text = bool(paper.full_text)
                file_path = None
                if has_full_text:
                    file_path = os.path.join(
                        self.fs_storage_path,
                        f"paper_{paper.pmid}_full_text.txt"
                    )
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(paper.full_text)

                parameters = {
                    'pmid': paper.pmid,
                    'full_text_path': file_path,
                    'has_full_text': has_full_text,
                    'pmc_id': getattr(paper, 'pmc_id', None),
                }
                self._run_query(query, parameters)
    
    def _section_content_path(self, document_id: str, section_title: str) -> str:
        safe_title = re.sub(r'[^a-z0-9]+', '_', section_title.lower()).strip('_')
        return os.path.join(
            self.fs_storage_path,
            f"section_{document_id}_{safe_title}.txt",
        )

    def store_section_content(self, document_id: str, sections: List[ContentSection]):
        """
        Store section content and its relationships.
        
        Args:
            document_id: Document identifier
            sections: List of ContentSection objects
        """
        set_content_query = """
        MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(s:Section)
        WHERE s.title = $section_title
        SET s.content_path = $content_path,
            s.ai_generated = $ai_generated,
            s.updated_at = datetime()
        """
        cite_query = """
        MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(s:Section)
        WHERE s.title = $section_title
        MATCH (p:Paper {pmid: $pmid})
        MERGE (s)-[:CITES]->(p)
        """
        
        for section in sections:
            content_path = self._section_content_path(document_id, section.title)
            with open(content_path, "w", encoding="utf-8") as f:
                f.write(section.content or '')

            self._run_query(set_content_query, {
                'document_id': document_id,
                'section_title': section.title,
                'content_path': content_path,
                'ai_generated': section.ai_generated,
            })

            for pmid, title, authors, journal, date in section.citations:
                self._run_query(cite_query, {
                    'document_id': document_id,
                    'section_title': section.title,
                    'pmid': pmid,
                })
    
    def store_citations(self, document_id: str, sections: List[ContentSection], references: str):
        """
        Store formatted citations and references.
        
        Args:
            document_id: Document identifier
            sections: List of ContentSection objects
            references: Formatted references text
        """
        # Save references to file
        refs_path = os.path.join(
            self.fs_storage_path,
            f"document_{document_id}_references.txt"
        )
        with open(refs_path, "w", encoding="utf-8") as f:
            f.write(references)
        
        # Update document with references path
        query = """
        MATCH (d:Document {id: $document_id})
        SET d.references_path = $references_path,
            d.updated_at = datetime()
        """
        
        parameters = {
            'document_id': document_id,
            'references_path': refs_path
        }
        self._run_query(query, parameters)
    
    def store_document_path(self, document_id: str, doc_path: str):
        """
        Store the path to the generated Word document.
        
        Args:
            document_id: Document identifier
            doc_path: Path to the Word document
        """
        query = """
        MATCH (d:Document {id: $document_id})
        SET d.file_path = $file_path,
            d.updated_at = datetime()
        """
        
        parameters = {
            'document_id': document_id,
            'file_path': doc_path
        }
        self._run_query(query, parameters)
    
    def mark_document_completed(self, document_id: str):
        """
        Mark a document as completed.
        
        Args:
            document_id: Document identifier
        """
        query = """
        MATCH (d:Document {id: $document_id})
        SET d.status = 'completed',
            d.completed_at = datetime(),
            d.updated_at = datetime()
        """
        
        self._run_query(query, {'document_id': document_id})
    
    def mark_document_failed(self, document_id: str, error_message: str):
        """
        Mark a document as failed with an error message.
        
        Args:
            document_id: Document identifier
            error_message: Error message to store
        """
        query = """
        MATCH (d:Document {id: $document_id})
        SET d.status = 'failed',
            d.error_message = $error_message,
            d.updated_at = datetime()
        """
        
        self._run_query(query, {
            'document_id': document_id,
            'error_message': error_message
        })
    
    def track_section_edit(
        self,
        document_id: str,
        section_id: str,
        new_content: str,
        user_id: str
    ) -> str:
        """
        Track a user's edit to a section.
        
        Args:
            document_id: Document identifier
            section_id: Section identifier
            new_content: New content for the section
            user_id: ID of the user making the edit
            
        Returns:
            ID of the edit record
        """
        edit_id = str(uuid.uuid4())
        
        # Save new content to file
        content_path = os.path.join(
            self.fs_storage_path,
            f"section_{section_id}_edit_{edit_id}.txt"
        )
        with open(content_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        
        # Create edit record and update section
        query = """
        MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(s:Section {id: $section_id})
        CREATE (e:Edit {
            id: $edit_id,
            user_id: $user_id,
            timestamp: datetime(),
            content_path: $content_path
        })
        CREATE (e)-[:EDITED]->(s)
        SET s.content_path = $content_path,
            s.ai_generated = false,
            s.updated_at = datetime()
        """
        
        parameters = {
            'document_id': document_id,
            'section_id': section_id,
            'edit_id': edit_id,
            'user_id': user_id,
            'content_path': content_path
        }
        
        self._run_query(query, parameters)
        return edit_id
    
    def store_process_log(self, document_id: str, log_entry: Dict[str, Any]):
        """
        Store a process log entry for a document.
        
        Args:
            document_id: Document identifier
            log_entry: Dictionary containing log entry data
        """
        query = """
        MATCH (d:Document {id: $document_id})
        CREATE (l:ProcessLog {
            id: $log_id,
            timestamp: datetime($timestamp),
            message: $message,
            level: $level,
            source: $source
        })
        CREATE (d)-[:HAS_LOG]->(l)
        """
        
        parameters = {
            'document_id': document_id,
            'log_id': str(uuid.uuid4()),
            'timestamp': log_entry['timestamp'].isoformat(),
            'message': log_entry['message'],
            'level': log_entry['level'],
            'source': log_entry['source']
        }
        
        self._run_query(query, parameters)
    
    def get_document_by_id(self, document_id: str, user_id=None) -> Dict[str, Any]:
        """
        Retrieve a document and its generation process.
        
        Args:
            document_id: Document identifier
            user_id: Optional user ID to verify document ownership
            
        Returns:
            Dictionary containing document data and process information
        """
        # If user_id is provided, verify ownership
        if user_id:
            check_query = """
            MATCH (d:Document {id: $document_id})
            RETURN d.user_id as user_id
            """
            results = self._run_query(check_query, {'document_id': document_id})
            
            if not results:
                return None
                
            doc_user_id = results[0].get('user_id')
            
            # If document has user_id and it doesn't match provided user_id
            if doc_user_id and str(doc_user_id) != str(user_id):
                return None
                
        # Proceed with original query...
        query = """
        MATCH (d:Document {id: $document_id})
        OPTIONAL MATCH (d)-[:HAS_SECTION]->(s:Section)
        OPTIONAL MATCH (s)-[fp:FOUND_PAPER]->(pf:Paper)
        OPTIONAL MATCH (s)-[fpp:FOUND_PAPER_PRE_FILTERED]->(ppf:Paper)
        OPTIONAL MATCH (s)-[sp:SELECTED_PAPER]->(spp:Paper)
        OPTIONAL MATCH (s)-[c:CITES]->(cited:Paper)
        OPTIONAL MATCH (d)-[:HAS_LOG]->(l:ProcessLog)
        WITH d, s,
            collect(DISTINCT {
                 paper: ppf,
                 relationship: fpp
             }) as pre_filtered,
            collect(DISTINCT {
                 paper: pf,
                 relationship: fp
             }) as filtered,
             collect(DISTINCT {
                 paper: spp,
                 relationship: sp
             }) as selected,
             collect(DISTINCT {
                 paper: cited,
                 relationship: c
             }) as citations,
             collect(DISTINCT l) as logs
        RETURN d,
               collect({
                   section: s,
                   pre_filtered_papers: pre_filtered,
                   filtered_papers: filtered,
                   selected_papers: selected,
                   cited_papers: citations
               }) as sections,
               logs
        """
        
        results = self._run_query(query, {'document_id': document_id})
        
        if not results:
            return None
        
        record = results[0]
        document = dict(record['d'])
        
        # Process logs
        process_logs = []
        for log in record['logs']:
            if log:
                process_logs.append({
                    'id': log['id'],
                    'timestamp': log['timestamp'].isoformat() if hasattr(log['timestamp'], 'isoformat') else str(log['timestamp']),
                    'message': log['message'],
                    'level': log['level'],
                    'source': log['source']
                })
        
        # Sort logs by timestamp
        process_logs.sort(key=lambda x: x['timestamp'])
        
        # Convert Neo4j Node to dictionary
        document = dict(record['d'])
        
        # Convert DateTime objects to ISO format strings in document data
        for date_field in ['created_at', 'updated_at', 'completed_at']:
            if date_field in document and hasattr(document[date_field], 'iso_format'):
                document[date_field] = document[date_field].iso_format()

        # Process sections
        sections = []
        for section_data in record['sections']:
            if not section_data['section']:  # Skip if section is null
                continue
            
            # Convert Neo4j Node to dictionary
            section = dict(section_data['section'])
            
            # Convert DateTime objects in section
            for date_field in ['created_at', 'updated_at']:
                if date_field in section and hasattr(section[date_field], 'iso_format'):
                    section[date_field] = section[date_field].iso_format()
                    
                    
                    
            
            # Convert paper nodes to dictionaries
            selected_papers = [dict(item['paper']) for item in section_data['selected_papers'] if item['paper']]
            pre_filtered_papers = [dict(item['paper']) for item in section_data.get('pre_filtered_papers', []) if item['paper']]
            filtered_papers = [dict(item['paper']) for item in section_data.get('filtered_papers', []) if item['paper']]
            cited_papers = [dict(item['paper']) for item in section_data['cited_papers'] if item['paper']]
            
            # Get section content
            content = None
            if section.get('content_path'):
                content = self._retrieve_text_from_file(section['content_path'])
            
            # Helper function to get preview text
            def get_text_preview(path):
                if not path:
                    return None
                text = self._retrieve_text_from_file(path)
                return text[:3000] if text else None

            def serialize_paper(p):
                preview = get_text_preview(p.get('full_text_path'))
                has_full_text = bool(p.get('has_full_text')) or bool(preview)
                return {
                    'pmid': p.get('pmid'),
                    'title': p.get('title'),
                    'authors': p.get('authors'),
                    'journal': p.get('journal'),
                    'publication_date': p.get('publication_date'),
                    'abstract': p.get('abstract'),
                    'summary': p.get('summary'),
                    'pmc_id': p.get('pmc_id'),
                    'has_full_text': has_full_text,
                    'full_text_path': p.get('full_text_path'),
                    'full_text_preview': preview,
                }
            
            sections.append({
                'id': section['id'],
                'title': section['title'],
                'description': section['description'],
                'content': content,
                'ai_generated': section.get('ai_generated', True),
                'search_terms': section.get('search_terms', []),
                'filter_keywords': section.get('filter_keywords', []),
                'pre_filtered_papers': [serialize_paper(p) for p in pre_filtered_papers],
                'filtered_papers': [serialize_paper(p) for p in filtered_papers],
                'selected_papers': [serialize_paper(p) for p in selected_papers],
                'cited_papers': [
                    {
                        'pmid': p['pmid'],
                        'title': p['title'],
                        'authors': p['authors'],
                        'journal': p['journal'],
                        'publication_date': p['publication_date']
                    }
                    for p in cited_papers
                ]
            })
        
        # Get references
        references = None
        if document.get('references_path'):
            references = self._retrieve_text_from_file(document['references_path'])
        
        return {
            'id': document['id'],
            'title': document['title'],
            'description': document['description'],
            'citation_style': document['citation_style'],
            'status': document['status'],
            'created_at': document['created_at'],
            'updated_at': document.get('updated_at'),
            'completed_at': document.get('completed_at'),
            'error_message': document.get('error_message'),
            'file_path': document.get('file_path'),
            'references': references,
            'sections': sections,
            'processLogs': process_logs
        }
    
    def get_paper_full_text_for_document(self, document_id: str, pmid: str) -> Optional[str]:
        """Load full text file for a paper associated with a document."""
        query = """
        MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(:Section)-[]->(p:Paper {pmid: $pmid})
        RETURN DISTINCT p.full_text_path AS path, p.has_full_text AS has_full_text
        LIMIT 1
        """
        results = self._run_query(query, {'document_id': document_id, 'pmid': pmid})
        if not results:
            return None
        record = results[0]
        if not record.get('has_full_text') and not record.get('path'):
            return None
        path = record.get('path')
        if not path:
            return None
        for candidate in self._get_possible_file_paths(path):
            if os.path.exists(candidate):
                try:
                    with open(candidate, 'r', encoding='utf-8') as f:
                        return f.read()
                except OSError as e:
                    logger.error(f"Error reading full text {candidate}: {e}")
                    return None
        return None
    
    def get_section_by_id(self, section_id: str) -> Dict[str, Any]:
        """
        Retrieve a section and its relationships.
        
        Args:
            section_id: Section identifier
            
        Returns:
            Dictionary containing section data
        """
        query = """
        MATCH (s:Section {id: $section_id})
        OPTIONAL MATCH (s)-[:SELECTED_PAPER]->(p:Paper)
        OPTIONAL MATCH (s)-[:CITES]->(cited:Paper)
        RETURN s, collect(DISTINCT p) as selected_papers, collect(DISTINCT cited) as cited_papers
        """
        
        results = self._run_query(query, {'section_id': section_id})
        
        if not results:
            return None
        
        record = results[0]
        section = record['s']
        
        # Get section content
        content = None
        if section.get('content_path'):
            content = self._retrieve_text_from_file(section['content_path'])
        
        return {
            'id': section['id'],
            'title': section['title'],
            'description': section['description'],
            'content': content,
            'ai_generated': section.get('ai_generated', True),
            'search_terms': section.get('search_terms', []),
            'filter_keywords': section.get('filter_keywords', []),
            'selected_papers': [
                {
                    'pmid': p['pmid'],
                    'title': p['title'],
                    'authors': p['authors'],
                    'journal': p['journal'],
                    'publication_date': p['publication_date'],
                    'abstract': p['abstract'],
                    'full_text_path': p.get('full_text_path')
                }
                for p in record['selected_papers']
            ],
            'cited_papers': [
                {
                    'pmid': p['pmid'],
                    'title': p['title'],
                    'authors': p['authors'],
                    'journal': p['journal'],
                    'publication_date': p['publication_date']
                }
                for p in record['cited_papers']
            ]
        }
    
    def get_section_papers(self, section_id: str) -> List[Dict[str, Any]]:
        """
        Get papers associated with a section.
        
        Args:
            section_id: Section identifier
            
        Returns:
            List of paper dictionaries
        """
        query = """
        MATCH (s:Section {id: $section_id})-[:SELECTED_PAPER]->(p:Paper)
        RETURN p
        """
        
        results = self._run_query(query, {'section_id': section_id})
        
        return [
            {
                'pmid': record['p']['pmid'],
                'title': record['p']['title'],
                'authors': record['p']['authors'],
                'journal': record['p']['journal'],
                'publication_date': record['p']['publication_date'],
                'abstract': record['p']['abstract'],
                'full_text_path': record['p'].get('full_text_path')
            }
            for record in results
        ]
    
    def update_section_content(
        self,
        section_id: str,
        new_content: str,
        citations: List[Tuple[str, str, str, str, str]]
    ):
        """
        Update a section's content and citations.
        
        Args:
            section_id: Section identifier
            new_content: New content for the section
            citations: List of citation tuples (pmid, title, authors, journal, date)
        """
        # Save new content to file
        content_path = os.path.join(
            self.fs_storage_path,
            f"section_{section_id}_update_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        )
        with open(content_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        
        # Update section content and citations
        query = """
        MATCH (s:Section {id: $section_id})
        SET s.content_path = $content_path,
            s.updated_at = datetime()
        WITH s
        MATCH (p:Paper {pmid: $pmid})
        CREATE (s)-[:CITES]->(p)
        """
        
        # Update content path
        self._run_query(
            "MATCH (s:Section {id: $section_id}) SET s.content_path = $content_path",
            {'section_id': section_id, 'content_path': content_path}
        )
        
        # Update citations
        for pmid, title, authors, journal, date in citations:
            parameters = {
                'section_id': section_id,
                'content_path': content_path,
                'pmid': pmid
            }
            self._run_query(query, parameters)
    
    def store_paper_summaries(self, document_id: str, paper_summaries: Dict[str, str]):
        """
        Store paper summaries in Neo4j.
        
        Args:
            document_id: Document identifier
            paper_summaries: Dictionary mapping PMIDs to their summary text
        """
        query = """
        MATCH (p:Paper {pmid: $pmid})
        SET p.summary = $summary,
            p.summary_length = $summary_length,
            p.summary_updated_at = datetime()
        """
        
        for pmid, summary in paper_summaries.items():
            parameters = {
                'pmid': pmid,
                'summary': summary,
                'summary_length': len(summary) if summary else 0
            }
            self._run_query(query, parameters) 