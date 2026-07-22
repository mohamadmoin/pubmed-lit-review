"""Token budgeting helpers for local LLM pipelines."""

from __future__ import annotations

import re
from typing import Optional

# Rough estimate: ~4 characters per token for English scientific text.
CHARS_PER_TOKEN = 4


def _context_token_limit() -> int:
    try:
        from django.conf import settings
        return int(getattr(settings, 'LM_STUDIO_CONTEXT_TOKENS', 16000))
    except Exception:
        return 16000


def _input_budget() -> int:
    # Reserve ~25% of context for model output and overhead.
    return int(_context_token_limit() * 0.75)


DEFAULT_INPUT_TOKEN_BUDGET = _input_budget()
SUMMARY_INPUT_TOKEN_BUDGET = min(3500, _input_budget() // 3)
SUMMARY_OUTPUT_MAX_TOKENS = 512
SELECTION_OUTPUT_MAX_TOKENS = 128
SECTION_CONTENT_OUTPUT_MAX_TOKENS = min(2048, _context_token_limit() // 6)
SELECTION_MAX_CANDIDATES = 8
ABSTRACT_MAX_WORDS = 80
SUMMARY_MAX_WORDS_FOR_SECTION = 250
SECTION_MAX_PAPERS_PER_CALL = 4

def estimate_tokens(text: str) -> int:
    if not text:
        return 0
    return max(1, len(text) // CHARS_PER_TOKEN)


def truncate_text(text: str, max_tokens: int) -> str:
    if not text:
        return ''
    max_chars = max_tokens * CHARS_PER_TOKEN
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rsplit(' ', 1)[0] + '…'


def truncate_words(text: str, max_words: int) -> str:
    if not text:
        return ''
    words = text.split()
    if len(words) <= max_words:
        return text
    return ' '.join(words[:max_words]) + '…'


def truncate_abstract(abstract: str, max_words: int = ABSTRACT_MAX_WORDS) -> str:
    return truncate_words(abstract or '', max_words)


def prepare_paper_content_for_summary(paper, max_input_tokens: int = SUMMARY_INPUT_TOKEN_BUDGET) -> str:
    """
    Build a compact paper payload for summarization.

    Prefers abstract + a bounded excerpt of full text rather than sending the
    entire PMC body into the model.
    """
    parts = []
    budget = max_input_tokens

    abstract = (getattr(paper, 'abstract', None) or '').strip()
    if abstract:
        abstract_block = truncate_text(abstract, min(800, budget // 2))
        parts.append(f"Abstract:\n{abstract_block}")
        budget -= estimate_tokens(abstract_block)

    full_text = (getattr(paper, 'full_text', None) or '').strip()
    if full_text and budget > 200:
        excerpt = _extract_high_value_excerpt(full_text, max_tokens=budget - 50)
        if excerpt:
            parts.append(f"Full text excerpt:\n{excerpt}")

    if parts:
        return '\n\n'.join(parts)

    title = getattr(paper, 'title', '') or 'Unknown paper'
    return f"Title only available:\n{title}"


def _extract_high_value_excerpt(full_text: str, max_tokens: int) -> str:
    """Pull introduction/results-like sections when present, else head+tail excerpt."""
    sections = []
    patterns = [
        r'(?i)(abstract[\s\S]{0,4000})',
        r'(?i)(introduction[\s\S]{0,3000})',
        r'(?i)(methods[\s\S]{0,2500})',
        r'(?i)(results[\s\S]{0,3500})',
        r'(?i)(discussion[\s\S]{0,2500})',
        r'(?i)(conclusion[\s\S]{0,1500})',
    ]
    seen = set()
    for pattern in patterns:
        match = re.search(pattern, full_text)
        if match:
            chunk = match.group(1).strip()
            key = chunk[:80]
            if key not in seen:
                seen.add(key)
                sections.append(chunk)

    if sections:
        combined = '\n\n'.join(sections)
        return truncate_text(combined, max_tokens)

    head = truncate_text(full_text, max_tokens // 2)
    tail = truncate_text(full_text[-max_tokens * CHARS_PER_TOKEN // 2 :], max_tokens // 2)
    return f"{head}\n\n[... middle omitted ...]\n\n{tail}"


def format_paper_for_selection(index: int, paper, max_abstract_words: int = ABSTRACT_MAX_WORDS) -> str:
    abstract = truncate_abstract(getattr(paper, 'abstract', '') or '', max_abstract_words)
    score = getattr(paper, 'relevance_score', 0) or 0
    return (
        f"{index}. {getattr(paper, 'title', 'Untitled')}\n"
        f"Relevance: {score:.2f}\n"
        f"Abstract: {abstract}\n"
    )


def truncate_summary_for_section(summary: Optional[str], max_words: int = SUMMARY_MAX_WORDS_FOR_SECTION) -> str:
    return truncate_words(summary or 'No summary available.', max_words)


def llm_worker_count(default: int = 4) -> int:
    try:
        from django.conf import settings
        if getattr(settings, 'LLM_PROVIDER', 'lmstudio') == 'lmstudio':
            return 2
    except Exception:
        pass
    return default
