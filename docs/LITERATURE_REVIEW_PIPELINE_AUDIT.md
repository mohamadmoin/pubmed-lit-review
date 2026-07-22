# LitReview Literature Review Pipeline — Audit Report

**Date:** 2026-07-22  
**Scope:** End-to-end document generation pipeline (backend), with empirical checks against generated artifacts in `data/text_storage/`.  
**Method:** Code review, step I/O tracing, first-principles evaluation, and inspection of two completed runs (fever review `6bb79b6a…`, common-cold review `80e5c7ec…`).  
**Note:** This document reports findings and suggested fixes only — no code changes were made.

---

## Executive summary

The pipeline **does run end-to-end** and can produce readable multi-section documents with numbered references, but it behaves more like an **LLM-assisted narrative synthesizer over loosely filtered PubMed hits** than a rigorous systematic literature review.

**What works reasonably well**

- Clear staged orchestration (structure → search → select → full text → summarize → write → cite → export).
- Per-section PubMed search with parallel term execution.
- TF-IDF pre-filtering (conceptually sound, but misconfigured).
- LLM paper selection and summarization when the local model returns parseable output.
- Global PMID deduplication in the reference list.
- Process logging to Neo4j for UI progress tracking.

**What works poorly (matches your observation about unrelated references)**

- Retrieval relevance is weak; many selected papers are only tangentially related to the section topic.
- The LLM is explicitly allowed to **stretch** off-topic papers to fit the section narrative.
- Final section text often includes **chain-of-thought planning** from the model (not stripped).
- References are a **single global bibliography** for the whole document; papers cited in one weak section appear alongside strong ones.
- Several implementation bugs undermine filtering, ranking, and citation integrity.

**Empirical spot-check (your generated documents)**

| Document | References | Clearly off-topic or weakly related |
|----------|-------------|-------------------------------------|
| Fever review (`6bb79b6a…`) | 10 | ~3–4 (radiation mtDNA/tumor microenvironment; rectal cancer microbiome; possibly AHEI mimicry unless framed as fever differential) |
| Common cold review (`80e5c7ec…`) | 6 | ~4–5 (venous ulcers, IV hydration spas, ultramarathon heat, cold urticaria vs rhinovirus cold) |

The common-cold run is especially telling: the pathophysiology section **acknowledges in its own generated text** that the papers are about fungal virome diversity and COVID-19 biomarkers, then proceeds to cite them anyway as evidence for “common cold pathophysiology.”

---

## Pipeline overview

```
User input (subject, description, word_count)
        │
        ▼
[1] Document structure (LLM JSON)
        │
        ▼
[2] PubMed search + TF-IDF filter (PyMed, per search term)
        │
        ▼
[3] Paper selection (LLM indices, max ~5/section)
        │
        ▼
[4] Full-text retrieval (Entrez → PMC, open access only)
        │
        ▼
[5] Summarize papers (LLM) → Generate sections (LLM, [PMID:X] cites)
        │
        ▼
[6] Citation formatting ([PMID:X] → [1], build references.txt)
        │
        ▼
[7] Word export + Neo4j persistence
```

**Primary code locations**

| Step | Files |
|------|--------|
| Orchestration | `backend/documents/tasks.py`, `document_generator.py` |
| Core logic | `backend/documents/python_document_generated_graph/ai_pubmed_search.py` |
| PMC / Entrez | `pubmed_structured_retrieval.py`, `engine/entrez_client.py` |
| Graph storage | `backend/documents/neo4j_client.py` |
| Token limits | `text_budget.py` |

---

## Step-by-step evaluation

### Step 1 — Document structure planning

**Built to do:** Turn user subject/description/word count into 2–4 sections, each with PubMed search terms and filter keywords.

**Inputs:** `subject`, `description`, `num_words`, LLM client.

**Outputs:** `DocumentStructure` — `title`, `description`, `citation_style`, `sections[]` with `title`, `description`, `search_terms` (3–5), `filter_keywords` (2–3).

**Implementation:** `get_document_structure()` in `ai_pubmed_search.py` (~264–325). JSON from LLM, normalized by `_normalize_document_structure()`.

**First-principles assessment:** ✅ Sound. A structured outline with section-scoped search terms is the right foundation for a literature review.

**Issues observed**

1. **Duplicate Neo4j structure creation** — `create_document_structure()` is called in `generate_document()` (with `user_id`) and again inside `_generate_structure()` (without `user_id`). Risk of duplicate or inconsistent graph nodes.
2. **`filter_keywords` are never used downstream** — generated at this step but not applied in search or filtering (dead field).
3. **Section count is fixed at 2–4** regardless of `word_count`; a 500-word vs 5000-word review gets the same structural granularity.
4. **Search terms are LLM-generated PubMed strings** with no validation (MeSH awareness, specificity, date filters, study type filters).

**Root causes:** Schema/design drift (`filter_keywords` planned but not wired); orchestration redundancy; no PubMed query linting.

**Suggested fixes (not implemented)**

- Call `create_document_structure()` once.
- Either wire `filter_keywords` into TF-IDF/LLM selection or remove from schema/prompt.
- Scale section count and papers-per-section with target word count.
- Add optional PubMed query constraints (date range, humans, English, review/article types).

---

### Step 2 — PubMed search and NLP filtering

**Built to do:** For each section × search term, fetch PubMed results and keep the most textually similar papers.

**Inputs:** `DocumentStructure.sections[].search_terms`.

**Outputs:** Two lists of `SearchResult`: post-filter (`final_results`) and pre-filter snapshot (`final_results_pre_filtered`).

**Implementation:** `search_pubmed_with_filtering()` (~328–474).

Per term:

1. PyMed query, **`max_results=20`** (hardcoded).
2. Build `SearchResult` (title, abstract, authors, PMID, `section_title`, `search_term`).
3. If `use_enhanced_filtering=True`: TF-IDF cosine similarity between **the search term string** and title+abstract; keep score **> 0.05**; top **10** per term.

**First-principles assessment:** ⚠️ Partially sound. TF-IDF on title+abstract vs a relevance query is a reasonable cheap filter, but:

- Similarity should be vs **section description + filter keywords**, not the PubMed query alone.
- Threshold 0.05 is extremely permissive for short query strings.
- 20 results/term is a small pool; generic terms yield noisy neighbors.

**Issues observed (code)**

| Issue | Location | Effect |
|-------|----------|--------|
| PyMed uses hardcoded `email="my@email.address"` | `ai_pubmed_search.py` ~354 | Ignores `PUBMED_EMAIL`; NCBI policy/compliance risk |
| `relevance_score` on `SearchResult` never set from TF-IDF | ~462–466 | Stored in `section_relevance` dict only; ranking broken later |
| `filter_keywords` unused | — | No secondary topical gate |
| Same PMID duplicated across terms/sections | ~425–472 | Inflates candidate lists before dedup at selection |
| `pubmed_structured_retrieval.search_pubmed()` unused in pipeline | — | Better Entrez path exists but main flow uses PyMed |

**Empirical evidence (common cold)**

Search terms likely broad (“respiratory infection”, “viral pathogenesis”, etc.) plausibly returned fungal virome, COVID miRNA, venous ulcer, and hydration-spa papers that share weak lexical overlap with the query string.

**Root causes:** Wrong similarity target, ultra-low threshold, no keyword gate, broken relevance propagation, small noisy retrieval pool.

**Suggested fixes**

- Score against `section.description + filter_keywords + search_term`.
- Raise threshold (e.g. 0.15–0.25) and/or use percentile cutoff per section.
- Copy TF-IDF score → `SearchResult.relevance_score`.
- Use configured Entrez client + `PUBMED_EMAIL` consistently.
- Deduplicate by PMID before selection; optionally cap total candidates per section.
- Add MeSH/date/study-type filters to queries.

---

### Step 3 — Paper selection (LLM)

**Built to do:** Choose up to 5 papers per section from filtered candidates.

**Inputs:** Filtered `SearchResult[]`, section title/description.

**Outputs:** `Dict[section_title → List[SearchResult]]`.

**Implementation:** `select_relevant_papers()` (~529–631), `_extract_paper_indices()` (~477–526).

**First-principles assessment:** ✅ Using an LLM to judge abstract-level relevance is reasonable **if candidates are already tight**. With loose Step 2 output, the LLM becomes a weak last gate on a noisy pool.

**Issues observed**

1. **Pre-sort by `relevance_score` is a no-op** (always 0.0) → candidates presented in arbitrary order.
2. **Selection prompt shows `relevance 0.00`** for every paper (`format_paper_for_selection`) → model lacks ranking signal.
3. **Fallback = first 5 papers** when JSON parse fails (~618–620, ~628–629).
4. **`_extract_paper_indices` last-resort** parses any small integers in prose (~521–524) → can select wrong papers from reasoning text.
5. **No exclusion criteria** (case reports, letters, wrong population, wrong condition) in prompt.
6. **No cross-section dedup** — same PMID can be selected in multiple sections.

**Empirical evidence**

- Common cold OTC section cites **venous ulcer compression** (`PMID:42073395`) — classic symptom of weak selection / stretch writing.
- Cold urticaria (`PMID:42311360`) selected for OTC cold relief — keyword collision on “cold.”

**Root causes:** Upstream noise + no ranking + aggressive fallbacks + ambiguous prompts for local models.

**Suggested fixes**

- Fix relevance scores before selection; show scores in prompt.
- Require minimum relevance score to enter LLM pool.
- Structured output with paper PMIDs (not indices) + mandatory one-line justification per pick.
- Hard reject papers whose title/abstract lacks section keyword overlap.
- Dedupe selected PMIDs globally across sections.
- Log and surface selection failures in UI instead of silent fallback.

---

### Step 4 — Full-text retrieval

**Built to do:** Resolve PMC IDs and fetch open-access full text for selected papers.

**Inputs:** Selected papers by section, `EntrezClient`.

**Outputs:** Same structure; papers may gain `pmc_id`, `full_text` (raw body text).

**Implementation:** `retrieve_full_text()` (~633+), uses `lookup_pmc_ids_for_pmids`, `fetch_full_text`, `parse_pmc_xml`.

**First-principles assessment:** ✅ Appropriate for open-source setup. Limitation is inherent: **most PubMed papers are abstract-only**.

**Issues observed**

1. Structured full-text sections (intro/methods/results) are parsed but **only `raw_text` is used** downstream.
2. **`Paper` nodes MERGE on full property set** in Neo4j (~240–247) — same PMID can exist as multiple nodes; relationships may attach unpredictably.
3. Global PMID-level storage can **overwrite** summary/full-text paths across documents.

**Root causes:** Graph model design; under-use of structured full text.

**Suggested fixes**

- MERGE `Paper` by PMID only.
- Namespace per-document paper metadata vs shared bibliographic cache.
- Prefer abstract+structured sections when raw text is huge/noisy.

---

### Step 5 — Summarization and content generation

**Built to do:** Summarize each unique paper; write each section citing `[PMID:X]`; extract citation metadata.

**Inputs:** Selected papers, summaries, section descriptions.

**Outputs:** `ContentSection[]` with `content`, `citations[]` (PMID tuples).

**Implementation:** `generate_content()`, `summarize_paper()`, `_generate_section_content_chunk()` (~875–918, ~972+).

**First-principles assessment:** ⚠️ Conceptually right (summarize then synthesize), but prompts and post-processing violate literature review norms.

**Critical issues**

1. **Chain-of-thought not stripped** — Stored section files contain planning text (“As a research content generation expert…”, “Here is the plan:”, checklists). Example: all sections in both audited documents.
2. **Prompt allows `[AI_GENERATED]` outside evidence** (~905–907) — encourages filler when papers don’t fit.
3. **No instruction to refuse weak papers** — model is nudged to “synthesize coherently” even when inputs mismatch (common cold pathophysiology explicitly does this).
4. **Citation extraction regex** `\[PMID:(\d+)\]` (~1049) is stricter than formatting regex — spaced variants may be missed.
5. **Hallucinated PMIDs possible** — fever pathophysiology cites `[PMID:3934]` (invalid/short); pharmacology cites PMIDs that may not match selected set if model invents IDs.
6. **Chunk merge** can duplicate reasoning blocks and citations.
7. **Persisted Neo4j content is pre-numbering** (`store_section_content` before `format_citations`) — API serves `[PMID:X]` while Word doc gets `[1]`; frontend/parser inconsistency.

**Empirical examples**

| Section | Problem |
|---------|---------|
| Common cold pathophysiology | Uses fungal virome + COVID miRNA as cold evidence |
| Common cold OTC | Venous ulcer compression + cold urticaria |
| Common cold home care | IV hydration spas + ultramarathon heat |
| Fever pathophysiology | Radiation mtDNA tumor microenvironment + rectal cancer microbiome |
| Fever pharmacology | Reasoning preamble + possible hallucinated PMIDs |

**Root causes:** Local LLM reasoning style not post-processed; permissive prompt; no relevance guard at generation; no validation that cited PMIDs ⊆ selected PMIDs for that section.

**Suggested fixes**

- Strip preambles / require “final section only” output; regex or secondary LLM pass to extract body after `##`.
- Forbid citing papers whose summary doesn’t mention section topic keywords.
- Reject citations where PMID ∉ selected set; fail section or regenerate.
- Disallow `[AI_GENERATED]` in citation-bearing sentences or cap its proportion.
- Persist **post-`format_citations`** content to Neo4j/API.
- Add PMID validation layer before storage.

---

### Step 6 — Citation formatting and references list

**Built to do:** Convert `[PMID:X]` → `[1]`, build numbered bibliography in chosen style.

**Inputs:** `ContentSection[]`, `citation_style`.

**Outputs:** Updated sections (in memory), `references.txt` string.

**Implementation:** `format_citations()` (~759–814).

**First-principles assessment:** ✅ Numbered Vancouver-style list in first-appearance order is acceptable for a review **if every entry is cited and on-topic**.

**Issues observed**

1. **Fallback numbering (~787–790):** PMIDs in `section.citations` metadata get a reference number even if not found in body scan → reference without visible in-text marker (edge case).
2. **Global bibliography across all sections** — user sees venous ulcer paper in full reference list because OTC section cited it, even when reading pathophysiology.
3. **References omit PMIDs** in formatted strings → frontend cannot link bibliography entries back to papers (`document_service.dart` PMID parse fails).
4. **`format_citation()` author-year styles unused** — only numeric refs in body.
5. **Edit/regenerate paths** don’t rebuild references or `CITES` edges consistently.

**Root causes:** Global ref aggregation without section scoping; missing PMID in bibliography; stale graph on edits.

**Suggested fixes**

- Include `PMID: ########` in every reference line.
- Optional per-section reference appendix or tag refs with section IDs in API.
- Remove fallback numbering unless PMID appears in text.
- Re-run `format_citations` after edits/regeneration.
- Sync `CITES` edges with extracted citations atomically.

---

### Step 7 — Word document and persistence

**Built to do:** Export `.docx`, mark document complete in Neo4j.

**Implementation:** `create_word_document()` (~1112+), `document_generator._create_document()`.

**First-principles assessment:** ✅ Useful deliverable.

**Issues observed**

- Word doc uses cleaned numbered citations; **API/Neo4j text files retain reasoning + `[PMID:X]`** → preview/UI differs from download.
- References appended as one paragraph block — formatting only, not a structural issue.

---

## Cross-cutting issues

### A. “Literature review” vs what the system actually optimizes

| Systematic review principle | Current behavior |
|----------------------------|------------------|
| Explicit research question | Implicit in user description only |
| Reproducible search strategy | LLM terms + undocumented PyMed fetch |
| Documented inclusion/exclusion | None (only TF-IDF > 0.05) |
| PRISMA-style flow | Partial UI funnel (pre-filter / filter / selected) but weak gates |
| Evidence tied to claims | Weak — LLM can stretch or `[AI_GENERATED]` |
| Traceable citations | PMIDs in body files; numbered refs without PMIDs |

### B. Local LLM (LM Studio / Gemma) interaction

- Reasoning models dump planning text into outputs → stored as section content.
- JSON/index selection fragile → fallbacks select arbitrary papers.
- JSON structure step works after recent parser fixes, but generation quality varies.

### C. Frontend display (secondary to pipeline, affects perceived quality)

- Markdown/`#`/`*` in content are model output; rendering is a presentation layer issue (recently improved in UI).
- Reference ↔ section linking broken in frontend because PMIDs aren’t parsed from bibliography strings.

---

## Reference integrity analysis (why “most OK, some unrelated”)

References in the final list are **exactly the set of PMIDs the LLM cited in section text** (plus rare fallback metadata cases), after global deduplication.

So unrelated references imply:

1. **Unrelated papers entered the candidate pool** (Step 2 — broad query + low threshold).
2. **They were selected anyway** (Step 3 — weak ranking/fallbacks).
3. **The LLM cited them** (Step 5 — prompt encourages synthesis; no hard relevance check).
4. **They appear in the global list** even if only one section mis-used them (Step 6 design).

Your “most okay, some unrelated” pattern is expected under this design: sections with good search terms (e.g. acetaminophen toxicity) produce good refs; sections with ambiguous terms (“cold”, “respiratory”, “supportive care”) pull in orthogonal clinical literature.

---

## Prioritized recommendations

### P0 — Citation quality and trust

1. **Post-process generated section text** — strip chain-of-thought; keep only content after first `##` heading or use a “final answer only” system prompt.
2. **Validate citations** — cited PMID must be in that section’s selected set; drop or regenerate on violation.
3. **Tighten retrieval** — score vs section description; raise TF-IDF threshold; wire `filter_keywords`.
4. **Fix `relevance_score` propagation** from TF-IDF into selection ranking.

### P1 — Selection and generation guardrails

5. Replace index-based selection with **PMID-based structured output** + relevance justification.
6. Remove or heavily restrict **`[AI_GENERATED]`** in medical review content.
7. Add **keyword overlap gate** (title/abstract vs section title) before LLM selection.
8. **Global PMID dedup** at selection time.

### P2 — Data model and API consistency

9. Persist **numbered citation content** to Neo4j after formatting.
10. Include **PMID in reference strings** for frontend linking.
11. Fix **duplicate `create_document_structure`** calls.
12. MERGE Neo4j `Paper` nodes by PMID only.

### P3 — Systematic review features (product direction)

13. Optional **PRISMA-style reporting** (counts at each funnel stage).
14. User-configurable **search filters** (years, study types).
15. **Section-scoped bibliographies** or tagged references.
16. **Human-in-the-loop** approve/reject papers before generation.

---

## Appendix — Audited artifact inventory

| Artifact | Document ID | Notes |
|----------|---------------|-------|
| `document_6bb79b6a…_references.txt` | Fever review | 10 refs; ~3–4 questionable for stated topics |
| `document_80e5c7ec…_references.txt` | Common cold | 6 refs; majority weakly related to common cold |
| Section `.txt` files | Both | Contain LLM planning preambles + `[PMID:X]` markers |
| `paper_*_full_text.txt` | Both | Full text fetched for subset of PMIDs |

---

## Conclusion

The pipeline architecture is **coherent and extensible**, but the **relevance funnel is too permissive** and the **generation step is too creative** for rigorous literature review. Unrelated references are not primarily a formatting bug — they are the predictable output of weak retrieval/selection combined with an LLM prompt that prioritizes narrative coherence over evidential fit.

Addressing root causes in **Steps 2, 3, and 5** will improve reference quality more than tuning citation formatting alone.
