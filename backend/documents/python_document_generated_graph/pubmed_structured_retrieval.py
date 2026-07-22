#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
PubMed Structured Retrieval Tool

This script retrieves articles from PubMed using the Entrez E-utilities API,
extracts structured data including full text when available, and exports to Excel.

Features:
- Searches PubMed using query parameters
- Retrieves full article metadata
- Parses full text into structured sections (Intro, Methods, Results, Discussion)
- Downloads tables when available
- Exports to Excel with a structured, organized format

Usage:
    python pubmed_structured_retrieval.py
"""

import os
import re
import logging
import time
import pandas as pd
from datetime import datetime
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Tuple, Optional, Set, Any
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import Element
from tqdm import tqdm
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import io
import requests
from PIL import Image as PILImage

from .engine.entrez_client import EntrezClient

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s - %(message)s',
    handlers=[
        logging.FileHandler("pubmed_retrieval.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("PubMedStructured")

# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class ArticleAuthor:
    """Represents an author of a research article."""
    last_name: str = ""
    first_name: str = ""
    affiliation: str = ""
    email: Optional[str] = None
    
    def __str__(self) -> str:
        if self.first_name and self.last_name:
            return f"{self.last_name}, {self.first_name}"
        return self.last_name

@dataclass
class ArticleTable:
    """Represents a table in a research article."""
    caption: str = ""
    data: pd.DataFrame = field(default_factory=lambda: pd.DataFrame())
    label: str = ""
    footnote: str = ""

@dataclass
class ArticleFigure:
    """Represents a figure in a research article."""
    caption: str = ""
    label: str = ""
    url: str = ""

@dataclass
class ArticleSection:
    """Represents a section of a research article."""
    title: str = ""
    content: str = ""
    section_type: str = ""  # intro, methods, results, discussion, etc.
    subsections: List['ArticleSection'] = field(default_factory=list)

@dataclass
class FullTextArticle:
    """Represents a full-text research article with structured sections."""
    title: str = ""
    abstract: str = ""
    introduction: str = ""
    methods: str = ""
    results: str = ""
    discussion: str = ""
    conclusion: str = ""
    acknowledgments: str = ""
    references: str = ""
    raw_text: str = ""
    sections: List[ArticleSection] = field(default_factory=list)
    tables: List[ArticleTable] = field(default_factory=list)
    figures: List[ArticleFigure] = field(default_factory=list)
    citations: List[Tuple[str, str]] = field(default_factory=list)  # List of (ref_id, ref_text) tuples

@dataclass
class Article:
    """Represents a research article with metadata and potentially full text."""
    pmid: str = ""
    doi: str = ""
    pmc_id: str = ""
    title: str = ""
    authors: List[ArticleAuthor] = field(default_factory=list)
    journal: str = ""
    publication_date: str = ""
    publication_type: str = ""
    abstract: str = ""
    keywords: List[str] = field(default_factory=list)
    mesh_terms: List[str] = field(default_factory=list)
    full_text_available: bool = False
    full_text: Optional[FullTextArticle] = None
    
    def author_str(self) -> str:
        """Return a formatted string of authors."""
        return "; ".join(str(author) for author in self.authors)
    
    def get_section_text(self, section_type: str) -> str:
        """Get text from a specific section type of the full text."""
        if not self.full_text:
            return ""
        
        if section_type == "introduction":
            return self.full_text.introduction
        elif section_type == "methods":
            return self.full_text.methods
        elif section_type == "results":
            return self.full_text.results
        elif section_type == "discussion":
            return self.full_text.discussion
        elif section_type == "conclusion":
            return self.full_text.conclusion
        return ""

    def to_dict(self) -> Dict[str, Any]:
        """Convert article to dictionary for export."""
        result = {
            "PMID": self.pmid,
            "DOI": self.doi,
            "PMC ID": self.pmc_id,
            "Title": self.title,
            "Authors": self.author_str(),
            "Journal": self.journal,
            "Publication Date": self.publication_date,
            "Publication Type": self.publication_type,
            "Abstract": self.abstract,
            "Keywords": "; ".join(self.keywords),
            "MeSH Terms": "; ".join(self.mesh_terms),
            "Full Text Available": "Yes" if self.full_text_available else "No",
        }
        
        # Add full text sections if available
        if self.full_text:
            result.update({
                "Introduction": self.full_text.introduction,
                "Methods": self.full_text.methods,
                "Results": self.full_text.results,
                "Discussion": self.full_text.discussion,
                "Conclusion": self.full_text.conclusion,
                "Acknowledgments": self.full_text.acknowledgments,
                "References Count": len(self.full_text.references.split("\n")) if self.full_text.references else 0,
                "Tables Count": len(self.full_text.tables),
                "Figures Count": len(self.full_text.figures)
            })
        
        return result

# =============================================================================
# PubMed XML Parser Functions
# =============================================================================

def parse_pubmed_xml(xml_content: str) -> List[Article]:
    """
    Parse PubMed XML data (from EFetch) to extract article information.
    
    Args:
        xml_content: XML string from EFetch
        
    Returns:
        List of Article objects
    """
    articles = []
    try:
        root = ET.fromstring(xml_content)
        
        # Process each PubmedArticle
        for article_elem in root.findall(".//PubmedArticle"):
            article = Article()
            
            # Extract PMID
            pmid_elem = article_elem.find(".//PMID")
            if pmid_elem is not None and pmid_elem.text:
                article.pmid = pmid_elem.text
            
            # Extract DOI
            doi_elem = article_elem.find(".//ArticleId[@IdType='doi']")
            if doi_elem is not None and doi_elem.text:
                article.doi = doi_elem.text
            
            # Extract PMC ID
            pmc_elem = article_elem.find(".//ArticleId[@IdType='pmc']")
            if pmc_elem is not None and pmc_elem.text:
                article.pmc_id = pmc_elem.text
                article.full_text_available = True
            
            # Extract title
            title_elem = article_elem.find(".//ArticleTitle")
            if title_elem is not None and title_elem.text:
                article.title = title_elem.text
            
            # Extract journal info
            journal_elem = article_elem.find(".//Journal/Title")
            if journal_elem is not None and journal_elem.text:
                article.journal = journal_elem.text
            
            # Extract publication date
            pub_date = article_elem.find(".//PubDate")
            if pub_date is not None:
                year = pub_date.find("Year")
                month = pub_date.find("Month")
                day = pub_date.find("Day")
                
                date_parts = []
                if year is not None and year.text:
                    date_parts.append(year.text)
                if month is not None and month.text:
                    date_parts.append(month.text)
                if day is not None and day.text:
                    date_parts.append(day.text)
                
                if date_parts:
                    article.publication_date = "-".join(date_parts)
            
            # Extract publication type
            pub_types = article_elem.findall(".//PublicationType")
            if pub_types:
                article.publication_type = ", ".join([pt.text for pt in pub_types if pt.text])
            
            # Extract abstract
            abstract_elem = article_elem.find(".//Abstract")
            if abstract_elem is not None:
                abstract_texts = abstract_elem.findall(".//AbstractText")
                if abstract_texts:
                    full_abstract = []
                    
                    for abstract_text in abstract_texts:
                        # Check if the abstract is structured with labels
                        label = abstract_text.get("Label")
                        if label:
                            full_abstract.append(f"{label}: {abstract_text.text or ''}")
                        else:
                            full_abstract.append(abstract_text.text or '')
                    
                    article.abstract = " ".join(full_abstract)
            
            # Extract authors
            authors = []
            author_elems = article_elem.findall(".//Author")
            for author_elem in author_elems:
                last_name = author_elem.find("LastName")
                fore_name = author_elem.find("ForeName")
                affiliation = author_elem.find("Affiliation")
                
                author = ArticleAuthor()
                if last_name is not None and last_name.text:
                    author.last_name = last_name.text
                if fore_name is not None and fore_name.text:
                    author.first_name = fore_name.text
                if affiliation is not None and affiliation.text:
                    author.affiliation = affiliation.text
                
                authors.append(author)
            
            article.authors = authors
            
            # Extract MeSH terms
            mesh_terms = article_elem.findall(".//MeshHeading/DescriptorName")
            if mesh_terms:
                article.mesh_terms = [term.text for term in mesh_terms if term.text]
            
            # Extract keywords
            keyword_elems = article_elem.findall(".//Keyword")
            if keyword_elems:
                article.keywords = [kw.text for kw in keyword_elems if kw.text]
            
            articles.append(article)
    
    except ET.ParseError as e:
        logger.error(f"XML parse error: {e}")
    except Exception as e:
        logger.error(f"Error parsing PubMed XML: {e}")
    
    return articles

def parse_section(sec_elem: Element) -> Optional[ArticleSection]:
    """
    Parse a section element to extract title and content.
    
    Args:
        sec_elem: XML Element representing a section
        
    Returns:
        ArticleSection object or None if parsing fails
    """
    try:
        section = ArticleSection()
        
        # Extract section title
        title_elem = sec_elem.find(".//title")
        if title_elem is not None:
            section.title = ''.join(title_elem.itertext()).strip()
        
        # Get section type from sec-type attribute
        section_type = sec_elem.get("sec-type", "").lower()
        
        # Map sec-type to our section types
        section_type_mapping = {
            "intro": "introduction",
            "background": "introduction",
            "methods": "methods",
            "methodology": "methods",
            "materials": "methods",
            "results": "results",
            "findings": "results",
            "outcomes": "results",
            "discussion": "discussion",
            "conclusion": "conclusion",
            "summary": "conclusion"
        }
        
        # If no sec-type, try to determine from title
        if not section_type:
            section_title_lower = section.title.lower()
            
            # Main section types and their variations
            section_types = {
                "introduction": ["introduction", "background", "overview", "rationale", "context",
                               "purpose", "aim", "objective", "scope", "setting"],
                "methods": ["method", "methodology", "materials and methods", "experimental", 
                           "study design", "procedures", "study population", "participants",
                           "subjects", "sample", "data collection", "intervention",
                           "study protocol", "research design", "study setting",
                           "inclusion criteria", "exclusion criteria", "recruitment"],
                "results": ["result", "findings", "outcomes", "data analysis", "statistical analysis",
                           "main findings", "primary outcomes", "secondary outcomes",
                           "statistical results", "data presentation", "analysis results",
                           "key findings", "study outcomes", "treatment outcomes",
                           "clinical outcomes", "efficacy results", "safety results"],
                "discussion": ["discussion", "interpretation", "implications", "clinical significance",
                             "limitations", "strengths", "weaknesses", "clinical relevance",
                             "practical implications", "theoretical implications",
                             "future research", "research implications", "clinical implications",
                             "study limitations", "methodological considerations"],
                "conclusion": ["conclusion", "summary", "recommendations", "future directions",
                             "clinical implications", "take-home message", "key conclusions",
                             "main conclusions", "final thoughts", "concluding remarks",
                             "clinical recommendations", "practice implications"]
            }
            
            # Check if this is a main section
            for section_type, variations in section_types.items():
                if any(var in section_title_lower for var in variations):
                    section.section_type = section_type
                    break
        else:
            # Use the mapped section type
            section.section_type = section_type_mapping.get(section_type, "other")
        
        # Extract section content from paragraphs
        paragraphs = []
        for p_elem in sec_elem.findall(".//p"):
            p_text = ''.join(p_elem.itertext()).strip()
            if p_text:
                paragraphs.append(p_text)
        
        section.content = "\n\n".join(paragraphs)
        
        # Parse subsections recursively
        subsections = []
        for subsec_elem in sec_elem.findall(".//sec"):
            subsection = parse_section(subsec_elem)
            if subsection:
                subsections.append(subsection)
        
        section.subsections = subsections
        
        return section
    
    except Exception as e:
        logger.error(f"Error parsing section: {e}")
        return None

def table_to_dataframe(table_elem: Element) -> pd.DataFrame:
    """
    Convert an XML table element to a pandas DataFrame.
    
    Args:
        table_elem: XML Element representing a table
        
    Returns:
        pandas DataFrame containing the table data
    """
    try:
        # Extract table headers
        headers = []
        thead = table_elem.find(".//thead")
        if thead is not None:
            # Handle multi-row headers
            header_rows = thead.findall(".//tr")
            if header_rows:
                # Process each header row
                for tr in header_rows:
                    row_headers = []
                    for th in tr.findall("./td") + tr.findall("./th"):
                        # Handle colspan
                        colspan = int(th.get("colspan", "1"))
                        header_text = ''.join(th.itertext()).strip()
                        row_headers.extend([header_text] * colspan)
                    if row_headers:
                        headers.append(row_headers)
        
        # Extract table rows
        rows = []
        tbody = table_elem.find(".//tbody")
        if tbody is not None:
            for tr in tbody.findall(".//tr"):
                row = []
                for td in tr.findall("./td") + tr.findall("./th"):
                    # Handle colspan
                    colspan = int(td.get("colspan", "1"))
                    cell_text = ''.join(td.itertext()).strip()
                    row.extend([cell_text] * colspan)
                if row:
                    rows.append(row)
        
        # If no headers were found and there are rows, use the first row as header
        if not headers and rows:
            headers = [rows[0]]
            rows = rows[1:]
        
        # Create DataFrame
        if headers and rows:
            # Ensure all rows have the same length as headers
            max_cols = max(len(row) for row in rows)
            rows = [row + [""] * (max_cols - len(row)) for row in rows if row]
            return pd.DataFrame(rows, columns=headers[0])
        elif rows:
            return pd.DataFrame(rows)
    
    except Exception as e:
        logger.error(f"Error converting table to DataFrame: {e}")
    
    return pd.DataFrame()


def _local_tag(tag: str) -> str:
    """Strip XML namespace prefix from an element tag."""
    return tag.split('}')[-1] if '}' in tag else tag


def _find_element_by_local_name(root: Element, name: str) -> Optional[Element]:
    """Find the first descendant element matching a local tag name."""
    for elem in root.iter():
        if _local_tag(elem.tag) == name:
            return elem
    return None


def _findall_by_local_name(root: Element, name: str) -> List[Element]:
    """Find all descendant elements matching a local tag name."""
    return [elem for elem in root.iter() if _local_tag(elem.tag) == name]


def parse_pmc_xml(xml_content: str) -> FullTextArticle:
    """
    Parse PMC XML data to extract full text content.
    
    Args:
        xml_content: XML string from PMC
        
    Returns:
        FullTextArticle object with structured content
    """
    full_text = FullTextArticle()
    
    try:
        root = ET.fromstring(xml_content)
        
        # Extract article title (namespace-agnostic)
        title_elem = _find_element_by_local_name(root, "article-title")
        if title_elem is not None:
            full_text.title = ''.join(title_elem.itertext()).strip()
        
        # Extract abstract
        abstract_elem = _find_element_by_local_name(root, "abstract")
        if abstract_elem is not None:
            full_text.abstract = ''.join(abstract_elem.itertext()).strip()
        
        # Extract body text and organize by sections
        body_elem = _find_element_by_local_name(root, "body")
        if body_elem is not None:
            # Extract all sections
            sections = []
            for sec_elem in _findall_by_local_name(body_elem, "sec"):
                section = parse_section(sec_elem)
                if section:
                    sections.append(section)
            
            full_text.sections = sections
            
            # Special handling for common section types
            for section in sections:
                section_type = section.section_type
                
                if section_type == "introduction":
                    full_text.introduction += section.content + "\n\n"
                elif section_type == "methods":
                    full_text.methods += section.content + "\n\n"
                elif section_type == "results":
                    full_text.results += section.content + "\n\n"
                elif section_type == "discussion":
                    full_text.discussion += section.content + "\n\n"
                elif section_type == "conclusion":
                    full_text.conclusion += section.content + "\n\n"
            
            # Get raw full text
            full_text.raw_text = ''.join(body_elem.itertext()).strip()
        
        # Extract acknowledgments
        ack_elem = _find_element_by_local_name(root, "ack")
        if ack_elem is not None:
            full_text.acknowledgments = ''.join(ack_elem.itertext()).strip()
        
        # Extract references
        ref_list = _find_element_by_local_name(root, "ref-list")
        if ref_list is not None:
            refs = []
            for ref in _findall_by_local_name(ref_list, "ref"):
                ref_text = ''.join(ref.itertext()).strip()
                if ref_text:
                    refs.append(ref_text)
            full_text.references = "\n".join(refs)
        
        # Extract tables with their captions
        tables = []
        for table_wrap in root.findall(".//table-wrap"):
            table = ArticleTable()
            
            # Extract table caption
            caption_elem = table_wrap.find(".//caption")
            if caption_elem is not None:
                table.caption = ''.join(caption_elem.itertext()).strip()
            
            # Extract table label
            label_elem = table_wrap.find(".//label")
            if label_elem is not None:
                table.label = label_elem.text.strip() if label_elem.text else ""
            
            # Extract table footnote
            footnote_elem = table_wrap.find(".//table-wrap-foot")
            if footnote_elem is not None:
                table.footnote = ''.join(footnote_elem.itertext()).strip()
            
            # Extract table data
            table_elem = table_wrap.find(".//table")
            if table_elem is not None:
                # Try to convert the table to a pandas DataFrame
                df = table_to_dataframe(table_elem)
                if not df.empty:
                    table.data = df
            
            tables.append(table)
        
        full_text.tables = tables
        
        # Extract figures with their captions
        figures = []
        for fig_elem in root.findall(".//fig"):
            figure = ArticleFigure()
            
            # Extract figure caption
            caption_elem = fig_elem.find(".//caption")
            if caption_elem is not None:
                figure.caption = ''.join(caption_elem.itertext()).strip()
            
            # Extract figure label
            label_elem = fig_elem.find(".//label")
            if label_elem is not None:
                figure.label = label_elem.text.strip() if label_elem.text else ""
            
            # Extract figure URL (if available)
            graphic_elem = fig_elem.find(".//graphic")
            if graphic_elem is not None:
                href = graphic_elem.get("{http://www.w3.org/1999/xlink}href")
                if href:
                    figure.url = href
            
            figures.append(figure)
        
        full_text.figures = figures
        
        # Extract reference citations in text
        citations = []
        for xref in root.findall(".//xref[@ref-type='bibr']"):
            ref_id = xref.get("rid", "")
            ref_text = ''.join(xref.itertext()).strip()
            if ref_id and ref_text:
                citations.append((ref_id, ref_text))
        
        # Store citations in the full text object
        full_text.citations = citations
    
    except ET.ParseError as e:
        logger.error(f"XML parse error for PMC: {e}")
    except Exception as e:
        logger.error(f"Error parsing PMC XML: {e}")
    
    return full_text

# =============================================================================
# PubMed Search and Retrieval Functions
# =============================================================================

def search_pubmed(client: EntrezClient, query: str, max_results: int = 100, 
                 use_history: bool = True, **kwargs) -> List[str]:
    """
    Search PubMed and return a list of PMIDs.
    
    Args:
        client: EntrezClient instance
        query: PubMed search query string
        max_results: Maximum number of results to retrieve
        use_history: Whether to use the NCBI History server
        **kwargs: Additional parameters for the ESearch call
        
    Returns:
        List of PMIDs
    """
    logger.info(f"Searching PubMed with query: {query}")
    
    try:
        esearch_xml = client.esearch(
            db="pubmed",
            term=query,
            retmax=min(max_results, 5000),  # PubMed has a limit of 5000 results per query
            usehistory="y" if use_history else "n",
            **kwargs
        )
        
        root = ET.fromstring(esearch_xml)
        
        # Extract total number of results
        count_elem = root.find(".//Count")
        if count_elem is not None and count_elem.text:
            total_results = int(count_elem.text)
            logger.info(f"Found {total_results} results (retrieving up to {max_results})")
        
        # Extract PMIDs
        id_elems = root.findall(".//IdList/Id")
        pmids = [elem.text for elem in id_elems if elem.text]
        
        # If using History, extract query_key and WebEnv
        if use_history:
            query_key = root.find(".//QueryKey")
            webenv = root.find(".//WebEnv")
            
            if query_key is not None and query_key.text and webenv is not None and webenv.text:
                return pmids, query_key.text, webenv.text
        
        return pmids
    
    except Exception as e:
        logger.error(f"Error searching PubMed: {e}")
        return []

def fetch_article_details(client: EntrezClient, pmids: List[str], 
                         batch_size: int = 100) -> List[Article]:
    """
    Fetch detailed article information for a list of PMIDs.
    
    Args:
        client: EntrezClient instance
        pmids: List of PMIDs to fetch
        batch_size: Number of PMIDs to process in each batch
        
    Returns:
        List of Article objects
    """
    logger.info(f"Fetching details for {len(pmids)} articles")
    
    articles = []
    
    # Process PMIDs in batches to avoid overloading the server
    for i in range(0, len(pmids), batch_size):
        batch_pmids = pmids[i:i+batch_size]
        
        try:
            logger.debug(f"Fetching batch {i//batch_size + 1} ({len(batch_pmids)} articles)")
            
            efetch_xml = client.efetch(
                db="pubmed",
                id_list=batch_pmids,
                retmode="xml"
            )
            
            batch_articles = parse_pubmed_xml(efetch_xml)
            articles.extend(batch_articles)
            
            # Add a small delay to avoid overloading the NCBI servers
            time.sleep(0.5)
            
        except Exception as e:
            logger.error(f"Error fetching batch {i//batch_size + 1}: {e}")
    
    return articles

def lookup_pmc_ids_for_pmids(client: EntrezClient, pmids: List[str]) -> Dict[str, str]:
    """
    Resolve PMC IDs for a list of PMIDs via PubMed EFetch metadata.

    Returns a mapping of PMID -> PMC ID (e.g. 'PMC1234567').
    """
    mapping: Dict[str, str] = {}
    if not pmids:
        return mapping

    batch_size = 20
    for i in range(0, len(pmids), batch_size):
        batch = [p for p in pmids[i:i + batch_size] if p]
        if not batch:
            continue
        for attempt in range(3):
            try:
                pubmed_xml = client.efetch(db="pubmed", id_list=batch, retmode="xml")
                for article in parse_pubmed_xml(pubmed_xml):
                    if article.pmid and article.pmc_id:
                        mapping[article.pmid] = article.pmc_id
                time.sleep(0.5)
                break
            except Exception as e:
                if '429' in str(e) and attempt < 2:
                    wait = 2 ** (attempt + 1)
                    logger.warning(f"PubMed rate limit; retrying PMC lookup in {wait}s")
                    time.sleep(wait)
                    continue
                logger.error(f"Error looking up PMC IDs for PMIDs {batch}: {e}")
                break
    return mapping


def fetch_full_text(client: EntrezClient, pmc_id: str) -> Optional[FullTextArticle]:
    """
    Fetch full text for an article with a PMC ID.
    
    Args:
        client: EntrezClient instance
        pmc_id: PMC ID of the article
        
    Returns:
        FullTextArticle object or None if retrieval fails
    """
    logger.info(f"Fetching full text for PMC ID: {pmc_id}")
    
    try:
        # Remove the "PMC" prefix if present
        if pmc_id.startswith("PMC"):
            pmc_id = pmc_id[3:]
        
        pmc_xml = client.efetch(
            db="pmc",
            id_list=[pmc_id],
            retmode="xml"
        )
        
        return parse_pmc_xml(pmc_xml)
    
    except Exception as e:
        logger.error(f"Error fetching full text for PMC ID {pmc_id}: {e}")
        return None

def get_articles_with_full_text(client: EntrezClient, query: str, 
                               max_results: int = 100, 
                               include_full_text: bool = True,
                               **kwargs) -> List[Article]:
    """
    Search PubMed and retrieve articles with full text when available.
    
    Args:
        client: EntrezClient instance
        query: PubMed search query
        max_results: Maximum number of articles to retrieve
        include_full_text: Whether to fetch full text for articles with PMC IDs
        **kwargs: Additional parameters for the search
        
    Returns:
        List of Article objects
    """
    # Search PubMed
    results = search_pubmed(client, query, max_results=max_results, **kwargs)
    
    if not results:
        logger.warning("No results found")
        return []
    
    if len(results) == 3:  # Using History server
        pmids, query_key, webenv = results
    else:  # Not using History server
        pmids = results
    
    # Fetch article details
    articles = fetch_article_details(client, pmids)
    
    # Fetch full text for articles with PMC IDs
    if include_full_text:
        for article in tqdm(articles, desc="Fetching full text"):
            if article.pmc_id:
                full_text = fetch_full_text(client, article.pmc_id)
                if full_text:
                    article.full_text = full_text
                    article.full_text_available = True
    
    return articles

# =============================================================================
# Export Functions
# =============================================================================

def export_to_pdf(article: Article, filename: str = None) -> None:
    """
    Export an article to a beautifully formatted PDF.
    
    Args:
        article: Article object to export
        filename: Output PDF filename (default: article_title.pdf)
    """
    if not article.full_text:
        logger.warning("No full text available for PDF export")
        return
    
    # Generate default filename if not provided
    if not filename:
        # Create a safe filename from the article title
        safe_title = "".join(c for c in article.title if c.isalnum() or c in (' ', '-', '_')).rstrip()
        filename = f"{safe_title[:50]}.pdf"
    
    logger.info(f"Exporting article to PDF: {filename}")
    
    # Create the PDF document
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        rightMargin=72,
        leftMargin=72,
        topMargin=72,
        bottomMargin=72
    )
    
    # Get styles
    styles = getSampleStyleSheet()
    title_style = styles['Heading1']
    heading_style = styles['Heading2']
    normal_style = styles['Normal']
    
    # Create custom styles
    styles.add(ParagraphStyle(
        name='ArticleTitle',
        parent=styles['Heading1'],
        fontSize=24,
        spaceAfter=30,
        alignment=1  # Center alignment
    ))
    
    styles.add(ParagraphStyle(
        name='SectionTitle',
        parent=styles['Heading2'],
        fontSize=16,
        spaceBefore=20,
        spaceAfter=10,
        textColor=colors.HexColor('#2C3E50')
    ))
    
    styles.add(ParagraphStyle(
        name='TableCaption',
        parent=styles['Normal'],
        fontSize=10,
        italic=True,
        spaceBefore=10,
        spaceAfter=5
    ))
    
    # Build the PDF content
    story = []
    
    # Add title
    story.append(Paragraph(article.title, styles['ArticleTitle']))
    story.append(Spacer(1, 20))
    
    # Add authors
    story.append(Paragraph(article.author_str(), normal_style))
    story.append(Spacer(1, 20))
    
    # Add abstract
    if article.abstract:
        story.append(Paragraph("Abstract", heading_style))
        story.append(Paragraph(article.abstract, normal_style))
        story.append(Spacer(1, 20))
    
    # Add main sections
    sections = [
        ("Introduction", article.full_text.introduction),
        ("Methods", article.full_text.methods),
        ("Results", article.full_text.results),
        ("Discussion", article.full_text.discussion),
        ("Conclusion", article.full_text.conclusion)
    ]
    
    for section_title, section_content in sections:
        if section_content:
            story.append(Paragraph(section_title, styles['SectionTitle']))
            story.append(Paragraph(section_content, normal_style))
            story.append(Spacer(1, 20))
    
    # Add tables
    if article.full_text.tables:
        story.append(Paragraph("Tables", heading_style))
        story.append(Spacer(1, 10))
        
        for i, table in enumerate(article.full_text.tables, 1):
            # Add table caption
            caption = f"Table {i}"
            if table.label:
                caption += f" ({table.label})"
            if table.caption:
                caption += f": {table.caption}"
            story.append(Paragraph(caption, styles['TableCaption']))
            
            # Convert DataFrame to table
            if not table.data.empty:
                # Prepare table data
                data = [table.data.columns.tolist()] + table.data.values.tolist()
                
                # Create table
                t = Table(data)
                t.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2C3E50')),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                    ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (-1, 0), 12),
                    ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                    ('BACKGROUND', (0, 1), (-1, -1), colors.white),
                    ('TEXTCOLOR', (0, 1), (-1, -1), colors.black),
                    ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                    ('FONTSIZE', (0, 1), (-1, -1), 10),
                    ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                    ('GRID', (0, 0), (-1, -1), 1, colors.black),
                    ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ]))
                
                story.append(t)
                story.append(Spacer(1, 20))
    
    # Add figures
    if article.full_text.figures:
        story.append(Paragraph("Figures", heading_style))
        story.append(Spacer(1, 10))
        
        for i, figure in enumerate(article.full_text.figures, 1):
            # Add figure caption
            caption = f"Figure {i}"
            if figure.label:
                caption += f" ({figure.label})"
            if figure.caption:
                caption += f": {figure.caption}"
            story.append(Paragraph(caption, styles['TableCaption']))
            
            # Add figure if URL is available
            if figure.url:
                try:
                    # Download and process the image
                    response = requests.get(figure.url)
                    if response.status_code == 200:
                        img = PILImage.open(io.BytesIO(response.content))
                        
                        # Calculate dimensions to fit the page width
                        img_width, img_height = img.size
                        aspect = img_height / float(img_width)
                        max_width = letter[0] - 2*inch
                        max_height = letter[1] - 2*inch
                        
                        if img_width > max_width:
                            img_width = max_width
                            img_height = img_width * aspect
                        
                        if img_height > max_height:
                            img_height = max_height
                            img_width = img_height / aspect
                        
                        # Convert to ReportLab Image
                        img_buffer = io.BytesIO()
                        img.save(img_buffer, format='PNG')
                        img_buffer.seek(0)
                        reportlab_img = Image(img_buffer, width=img_width, height=img_height)
                        
                        story.append(reportlab_img)
                        story.append(Spacer(1, 20))
                except Exception as e:
                    logger.error(f"Error adding figure to PDF: {e}")
    
    # Add references
    if article.full_text.references:
        story.append(PageBreak())
        story.append(Paragraph("References", heading_style))
        story.append(Spacer(1, 10))
        
        # Split references into individual entries
        refs = article.full_text.references.split("\n")
        for i, ref in enumerate(refs, 1):
            if ref.strip():
                story.append(Paragraph(f"{i}. {ref.strip()}", normal_style))
                story.append(Spacer(1, 5))
    
    # Build the PDF
    doc.build(story)
    logger.info(f"PDF export complete: {filename}")

def export_to_excel(articles: List[Article], filename: str = None, 
                  include_tables: bool = True,
                  export_pdf: bool = False) -> None:
    """
    Export articles to an Excel file and optionally to PDF.
    
    Args:
        articles: List of Article objects
        filename: Output Excel filename (default: pubmed_results_YYYYMMDD.xlsx)
        include_tables: Whether to include tables in separate sheets
        export_pdf: Whether to also export each article to PDF
    """
    if not articles:
        logger.warning("No articles to export")
        return
    
    # Generate default filename if not provided
    if not filename:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"pubmed_results_{timestamp}.xlsx"
    
    logger.info(f"Exporting {len(articles)} articles to {filename}")
    
    # Convert articles to dictionaries for the main sheet
    articles_data = [article.to_dict() for article in articles]
    
    # Create a Pandas Excel writer
    with pd.ExcelWriter(filename, engine='xlsxwriter') as writer:
        # Write the main sheet with article information
        df_articles = pd.DataFrame(articles_data)
        df_articles.to_excel(writer, sheet_name="Articles", index=False)
        
        # Format the main sheet
        workbook = writer.book
        worksheet = writer.sheets["Articles"]
        
        # Set column widths
        worksheet.set_column('A:A', 10)  # PMID
        worksheet.set_column('B:B', 15)  # DOI
        worksheet.set_column('C:C', 10)  # PMC ID
        worksheet.set_column('D:D', 40)  # Title
        worksheet.set_column('E:E', 30)  # Authors
        worksheet.set_column('F:F', 20)  # Journal
        worksheet.set_column('G:G', 15)  # Publication Date
        worksheet.set_column('H:H', 15)  # Publication Type
        worksheet.set_column('I:I', 50)  # Abstract
        worksheet.set_column('J:J', 20)  # Keywords
        worksheet.set_column('K:K', 30)  # MeSH Terms
        worksheet.set_column('L:L', 10)  # Full Text Available
        
        # Create a format for the header row
        header_format = workbook.add_format({
            'bold': True,
            'text_wrap': True,
            'valign': 'top',
            'bg_color': '#D9E1F2',
            'border': 1
        })
        
        # Apply the header format
        for col_num, value in enumerate(df_articles.columns.values):
            worksheet.write(0, col_num, value, header_format)
        
        # If including tables, create a separate sheet for each article with tables
        if include_tables:
            table_articles = [a for a in articles if a.full_text and a.full_text.tables]
            
            if table_articles:
                logger.info(f"Exporting tables from {len(table_articles)} articles")
                
                # Create a summary sheet for tables
                table_summary = []
                
                for article in table_articles:
                    for i, table in enumerate(article.full_text.tables):
                        table_summary.append({
                            "PMID": article.pmid,
                            "Article Title": article.title,
                            "Table Number": i + 1,
                            "Table Label": table.label,
                            "Table Caption": table.caption,
                            "Rows": len(table.data) if not table.data.empty else 0,
                            "Columns": len(table.data.columns) if not table.data.empty else 0
                        })
                
                if table_summary:
                    df_tables = pd.DataFrame(table_summary)
                    df_tables.to_excel(writer, sheet_name="Tables Summary", index=False)
                
                # Create individual sheets for tables
                for article in table_articles:
                    for i, table in enumerate(article.full_text.tables):
                        if not table.data.empty:
                            # Limit sheet name to 31 characters (Excel limitation)
                            sheet_name = f"PMID{article.pmid}_Table{i+1}"
                            if len(sheet_name) > 31:
                                sheet_name = sheet_name[:31]
                            
                            # Export table to a sheet
                            table.data.to_excel(writer, sheet_name=sheet_name, index=False)
    
    # Export to PDF if requested
    if export_pdf:
        for article in articles:
            if article.full_text:
                # Create a safe filename from the article title
                safe_title = "".join(c for c in article.title if c.isalnum() or c in (' ', '-', '_')).rstrip()
                pdf_filename = f"{safe_title[:50]}.pdf"
                export_to_pdf(article, pdf_filename)

# =============================================================================
# Main Functions
# =============================================================================

def main():
    """CLI demo — requires PUBMED_EMAIL (and optional PUBMED_API_KEY) in environment."""
    import os

    email = os.getenv('PUBMED_EMAIL')
    if not email:
        raise SystemExit('Set PUBMED_EMAIL before running this script.')

    client = EntrezClient(
        tool=os.getenv('PUBMED_TOOL', 'LitReview'),
        email=email,
        api_key=os.getenv('PUBMED_API_KEY'),
        requests_per_second=3.0,
    )
    
    # Example search
    query = "machine learning AND cancer AND 2022:2023[dp]"
    max_results = 3  # Set to a small number for testing
    
    logger.info(f"Running search with query: {query}")
    
    # Get articles
    articles = get_articles_with_full_text(
        client, 
        query, 
        max_results=max_results, 
        include_full_text=True
    )
    
    # Export to Excel
    if articles:
        export_to_excel(articles, include_tables=True, export_pdf=True)
        logger.info(f"Exported {len(articles)} articles to Excel")
    else:
        logger.warning("No articles found")

if __name__ == "__main__":
    main() 