"""
Document Generator Module

This module provides a high-level interface for generating research documents
while maintaining a graph database representation of the process and enabling
user edits at various stages.
"""

import json
import os
import uuid
import logging
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
from neo4j import GraphDatabase
from django.conf import settings
from .neo4j_client import Neo4jClient
from .python_document_generated_graph.ai_pubmed_search import (
    DocumentStructure,
    ProcessLogger,
    SearchResult,
    ContentSection,
    create_word_document,
    format_citations,
    generate_content,
    generate_research_content,
    get_document_structure,
    retrieve_full_text,
    search_pubmed_with_filtering,
    select_relevant_papers
)

logger = logging.getLogger(__name__)

class DocumentGenerator:
    """
    High-level interface for document generation with Neo4j storage and user edit capabilities.
    
    This class wraps the core document generation functionality while adding:
    1. Neo4j storage of the generation process
    2. User edit tracking and versioning
    3. Selective regeneration capabilities
    4. Process state management
    """
    
    def __init__(self, neo4j_client: Optional[Neo4jClient] = None):
        """
        Initialize the document generator.
        
        Args:
            neo4j_client: Optional Neo4jClient instance. If None, creates a new one.
        """
        self.neo4j_client = neo4j_client or Neo4jClient()
        self.text_storage_path = settings.TEXT_STORAGE_PATH
        self.process_logger = ProcessLogger()  # Initialize process logger at class level
    
    def _add_process_log(self, document_id: str, message: str, level: str, source: str):
        """
        Add a process log entry.
        
        Args:
            document_id: Document identifier
            message: Log message
            level: Log level (INFO, ERROR, etc.)
            source: Source of the log entry
        """
        self.neo4j_client.store_process_log(document_id, {
            'timestamp': datetime.now(),
            'message': message,
            'level': level,
            'source': source
        })
    
    def generate_document(
        self,
        subject: str,
        description: str,
        num_words: int,
        openai_client: Any,
        document_id:str,
        entrez_client: Optional[Any] = None,
        use_enhanced_filtering: bool = True,
        user_id: Optional[str] = None
        
    ) -> Dict[str, Any]:
        """
        Generate a research document and store the process in Neo4j.
        
        Args:
            subject: Main subject of the research document
            description: Detailed description of the research document
            num_words: Target number of words
            openai_client: OpenAI client instance
            document_id: Unique ID for the document
            entrez_client: Optional EntrezClient instance
            use_enhanced_filtering: Whether to use enhanced NLP filtering
            user_id: Optional user ID for tracking ownership
            
        Returns:
            Dictionary with document data
        """
        try:
            # Log initial step
            self._add_process_log(
                document_id, 
                "Starting document generation process", 
                "INFO", 
                "DocumentGenerator"
            )
            
            # Step 1: Generate document structure
            structure = self._generate_structure(subject, description, num_words, openai_client, document_id)
            
            # Create document structure in Neo4j (with user ID)
            self.neo4j_client.create_document_structure(document_id, structure, user_id)
            self._add_process_log(
                document_id,
                f"Document Structure: Completed - Created {len(structure.sections)} sections",
                "INFO",
                "Document Structure",
            )
            
            # Store initial log
            self._add_process_log(
                document_id,
                "Starting document generation",
                "INFO",
                "Initialization"
            )
            
            # 2. Search PubMed and filter results
            search_terms_summary = {
                section['title']: section['search_terms']
                for section in structure.sections
            }
            self.process_logger.log_step("PubMed Search", "Started", f"Section-specific search terms: {json.dumps(search_terms_summary)}")
            self._add_process_log(document_id, f"PubMed Search: Started - Section-specific search terms: {json.dumps(search_terms_summary)}", "INFO", "PubMed Search")
            
            search_results = self._search_and_filter(
                structure, use_enhanced_filtering, document_id
            )
            self.process_logger.log_step("PubMed Search", "Completed", f"Found {len(search_results)} papers")
            self._add_process_log(document_id, f"PubMed Search: Completed - Found {len(search_results)} papers", "INFO", "PubMed Search")
            
            # 3. Select relevant papers
            self.process_logger.log_step("Paper Selection", "Started")
            self._add_process_log(document_id, "Paper Selection: Started", "INFO", "Paper Selection")
            
            selected_papers = self._select_papers(
                search_results, structure, openai_client, document_id
            )
            all_selected_papers = []
            for section_title, papers in selected_papers.items():
                self.process_logger.log_step("Paper Selection", "Section Completed", f"Selected {len(papers)} papers for section: {section_title}")
                self._add_process_log(document_id, f"Paper Selection: Section Completed - Selected {len(papers)} papers for section: {section_title}", "INFO", "Paper Selection")
                for paper in papers:
                    self.process_logger.log_paper(paper)
                    self._add_process_log(document_id, f"Paper Selected: {paper.title}", "INFO", "Paper Selection")
                    all_selected_papers.append(paper)
            
            self.process_logger.log_step("Paper Selection", "Completed", f"Selected total of {len(all_selected_papers)} papers across all sections")
            self._add_process_log(document_id, f"Paper Selection: Completed - Selected total of {len(all_selected_papers)} papers across all sections", "INFO", "Paper Selection")
            
            # 4. Retrieve full text
            self.process_logger.log_step("Full Text Retrieval", "Started")
            self._add_process_log(document_id, "Full Text Retrieval: Started", "INFO", "Full Text Retrieval")
            
            papers_with_text = self._retrieve_full_text(
                selected_papers, entrez_client, document_id
            )
            
            # 5. Generate content
            self.process_logger.log_step("Content Generation", "Started")
            self._add_process_log(document_id, "Content Generation: Started", "INFO", "Content Generation")
            
            sections = self._generate_content(
                papers_with_text, structure, openai_client, document_id
            )
            self.process_logger.log_step("Content Generation", "Completed", f"Generated {len(sections)} sections")
            self._add_process_log(document_id, f"Content Generation: Completed - Generated {len(sections)} sections", "INFO", "Content Generation")
            
            for section in sections:
                self.process_logger.log_section(section)
                self._add_process_log(document_id, f"Section Generated: {section.title}", "INFO", "Content Generation")
            
            # 6. Format citations and create references
            self.process_logger.log_step("Citation Formatting", "Started")
            self._add_process_log(document_id, "Citation Formatting: Started", "INFO", "Citation Formatting")
            
            final_sections, references = self._format_citations(
                sections, structure.citation_style, document_id
            )
            self.process_logger.log_step("Citation Formatting", "Completed")
            self._add_process_log(document_id, "Citation Formatting: Completed", "INFO", "Citation Formatting")
            
            # 7. Create Word document
            self.process_logger.log_step("Document Creation", "Started")
            self._add_process_log(document_id, "Document Creation: Started", "INFO", "Document Creation")
            
            doc_path = self._create_word_document(
                final_sections, references, document_id
            )
            self.process_logger.log_step("Document Creation", "Completed", f"Document saved to: {doc_path}")
            self._add_process_log(document_id, f"Document Creation: Completed - Document saved to: {doc_path}", "INFO", "Document Creation")
            
            # Mark process as completed
            self.process_logger.log_step("Process", "Completed", "All steps completed successfully")
            self._add_process_log(document_id, "Process: Completed - All steps completed successfully", "INFO", "Process")
            
            # Mark document as completed
            self._mark_document_completed(document_id)
            
            return {
                'id': document_id,
                'title': structure.title,
                'sections': [s.dict() for s in final_sections],
                'references': references,
                'doc_path': doc_path,
                'created_at': datetime.now().isoformat(),
                'user_id': user_id
            }
            
        except Exception as e:
            logger.error(f"Error generating document {document_id}: {e}")
            self._mark_document_failed(document_id, str(e))
            # Store error logs if any
            if hasattr(self.process_logger, 'errors_df') and not self.process_logger.errors_df.empty:
                for _, row in self.process_logger.errors_df.iterrows():
                    self._add_process_log(document_id, f"Error: {row['Error Message']} - {row['Details']}", "ERROR", row['Step'])
            raise
    
    def _generate_structure(
        self,
        subject: str,
        description: str,
        num_words: int,
        openai_client: Any,
        document_id: str
    ) -> DocumentStructure:
        """Generate and store document structure."""
        structure = get_document_structure(
            subject, description, num_words, openai_client
        )
        
        # Store structure in Neo4j
        self.neo4j_client.create_document_structure(document_id, structure)
        
        return structure
    
    def _search_and_filter(
        self,
        structure: DocumentStructure,
        use_enhanced_filtering: bool,
        document_id: str
    ) -> List[SearchResult]:
        """Search PubMed and filter results."""
        results, df_pre_filtered = search_pubmed_with_filtering(
            structure,
            use_enhanced_filtering=use_enhanced_filtering
        )
        
        # Store search results in Neo4j
        self.neo4j_client.store_search_results(document_id, results)
        self.neo4j_client.store_pre_filtered_search_results(document_id, df_pre_filtered)
        return results
    
    def _select_papers(
        self,
        results: List[SearchResult],
        structure: DocumentStructure,
        openai_client: Any,
        document_id: str
    ) -> Dict[str, List[SearchResult]]:
        """Select relevant papers for each section."""
        selected_papers = select_relevant_papers(
            results, structure, openai_client
        )
        
        # Store selected papers in Neo4j
        self.neo4j_client.store_selected_papers(document_id, selected_papers)
        
        return selected_papers
    
    def _retrieve_full_text(
        self,
        papers_by_section: Dict[str, List[SearchResult]],
        entrez_client: Any,
        document_id: str
    ) -> Dict[str, List[SearchResult]]:
        """Retrieve full text for selected papers."""
        papers_with_text = retrieve_full_text(
            papers_by_section, entrez_client
        )
        
        ft_count = sum(
            1 for papers in papers_with_text.values() for p in papers if p.full_text
        )
        self.process_logger.log_step(
            "Full Text Retrieval", "Completed",
            f"Retrieved full text for {ft_count} papers",
        )
        self._add_process_log(
            document_id,
            f"Full Text Retrieval: Completed - Retrieved full text for {ft_count} papers",
            "INFO",
            "Full Text Retrieval",
        )

        self.neo4j_client.store_full_text_paths(document_id, papers_with_text)

        return papers_with_text

    def _generate_content(
        self,
        papers_by_section: Dict[str, List[SearchResult]],
        structure: DocumentStructure,
        openai_client: Any,
        document_id: str
    ) -> List[ContentSection]:
        """Generate content for each section."""
        sections = generate_content(
            papers_by_section, 
            structure, 
            openai_client,
            document_id,
            self.neo4j_client
        )
        
        # Store section content in Neo4j and file system
        self.neo4j_client.store_section_content(document_id, sections)
        
        return sections
    
    def _format_citations(
        self,
        sections: List[ContentSection],
        citation_style: str,
        document_id: str
    ) -> Tuple[List[ContentSection], str]:
        """Format citations and create references section."""
        final_sections, references = format_citations(
            sections, citation_style
        )
        
        # Store formatted citations in Neo4j
        self.neo4j_client.store_citations(document_id, final_sections, references)
        
        return final_sections, references
    
    def _create_word_document(
        self,
        sections: List[ContentSection],
        references: str,
        document_id: str
    ) -> str:
        """Create Word document and store path."""
        doc_path = create_word_document(
            sections,
            references,
            output_dir=self.text_storage_path,
            filename=f"document_{document_id}.docx"
        )
        
        # Store document path in Neo4j
        self.neo4j_client.store_document_path(document_id, doc_path)
        
        return doc_path
    
    def _mark_document_completed(self, document_id: str):
        """Mark document as completed in Neo4j."""
        self.neo4j_client.mark_document_completed(document_id)
    
    def _mark_document_failed(self, document_id: str, error_message: str):
        """Mark document as failed in Neo4j."""
        self.neo4j_client.mark_document_failed(document_id, error_message)
    
    def get_document(self, document_id: str, user_id=None) -> Dict[str, Any]:
        """
        Retrieve a document by ID.
        
        Args:
            document_id: Document identifier
            user_id: Optional user ID to verify document ownership
            
        Returns:
            Dictionary with document data or None if not found
        """
        try:
            # Retrieve document from Neo4j, filtering by user_id if provided
            return self.neo4j_client.get_document_by_id(document_id, user_id=user_id)
        except Exception as e:
            logger.error(f"Error retrieving document {document_id}: {e}")
            return None
    
    def edit_section(
        self,
        document_id: str,
        section_id: str,
        new_content: str,
        user_id: str
    ) -> Dict[str, Any]:
        """
        Edit a section's content and track the change.
        
        Args:
            document_id: Document identifier
            section_id: Section identifier
            new_content: New content for the section
            user_id: ID of the user making the edit
            
        Returns:
            Updated section data
        """
        # Store edit in Neo4j
        edit_id = self.neo4j_client.track_section_edit(
            document_id,
            section_id,
            new_content,
            user_id
        )
        
        # Get updated section data
        section_data = self.neo4j_client.get_section_by_id(section_id)
        
        return {
            'edit_id': edit_id,
            'section': section_data,
            'timestamp': datetime.now().isoformat()
        }
    
    def regenerate_from_section(
        self,
        document_id: str,
        section_id: str,
        openai_client: Any,
        entrez_client: Optional[Any] = None
    ) -> Dict[str, Any]:
        """
        Regenerate document content from a specific section.
        
        Args:
            document_id: Document identifier
            section_id: Section identifier
            openai_client: OpenAI client instance
            entrez_client: Optional EntrezClient instance
            
        Returns:
            Updated document data
        """
        # Get document data
        document_data = self.get_document(document_id)
        
        # Get papers for the section
        section_papers = self.neo4j_client.get_section_papers(section_id)
        
        # Generate new content for the section
        new_section = generate_content(
            {section_id: section_papers},
            document_data['structure'],
            openai_client
        )[0]
        
        # Update section in Neo4j
        self.neo4j_client.update_section_content(
            section_id,
            new_section.content,
            new_section.citations
        )
        
        # Get updated document data
        return self.get_document(document_id)
    
    def close(self):
        """Close Neo4j connection."""
        if self.neo4j_client:
            self.neo4j_client.close() 