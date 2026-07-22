import requests
import logging
import time
from urllib.parse import urlencode
from xml.etree import ElementTree as ET
from requests import Request


# Configure logging: Change level to INFO or DEBUG as desired.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s - %(message)s'
)

class EntrezClientError(Exception):
    """Custom exception for EntrezClient-related errors."""
    pass

class EntrezClient:
    """
    A robust Python client for interacting with NCBI Entrez E-utilities.
    Features:
      - Auto spell-check and query suggestions (ESpell)
      - Efficient batch retrieval (exceed 10,000 records in smaller steps)
      - Rate-limiting to avoid IP blocking
      - Logging and error handling
    """

    BASE_EUTILS_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

    def __init__(self, tool: str, email: str, api_key: str = None, requests_per_second: float = 3.0):
        """
        Initialize the EntrezClient with user-specific information.

        :param tool: Arbitrary name of your application (no spaces).
        :param email: Valid email address for E-utilities usage.
        :param api_key: (Optional) NCBI API key for >3 requests/second. 
        :param requests_per_second: Throttle requests to avoid surpassing NCBI recommendations.
        """
        self.tool = tool
        self.email = email
        self.api_key = api_key
        self.requests_per_second = requests_per_second

        # Tracking for rate-limiting
        self._last_request_timestamp = 0
        self.logger = logging.getLogger(self.__class__.__name__)

    def _throttle(self):
        """
        Ensures we do not exceed requests_per_second.
        Wait if needed based on time since last request.
        """
        min_interval = 1.0 / self.requests_per_second
        now = time.time()
        elapsed = now - self._last_request_timestamp
        if elapsed < min_interval:
            sleep_time = min_interval - elapsed
            self.logger.debug(f"Rate limit in effect. Sleeping for {sleep_time:.3f}s.")
            time.sleep(sleep_time)
        self._last_request_timestamp = time.time()

    def _build_params(self, extra_params: dict) -> dict:
        """
        Build a dictionary of common E-utility parameters plus user extras.
        """
        params = {
            "tool": self.tool,
            "email": self.email,
        }
        if self.api_key:
            params["api_key"] = self.api_key
        # Merge user-provided parameters
        params.update(extra_params)
        return params

    # def _request_with_retries(self, url, params=None, data=None, method="GET", max_retries=3):
    #     """
    #     Makes a request, implements basic retry logic for 5xx and 429 errors.
    #     Rate-limiting is also enforced here.
    #     """
    #     attempt = 0
    #     while attempt < max_retries:
    #         self._throttle()
    #         try:
    #             if method == "GET":
    #                  # Prepare the request to log the full URL
    #                 req = Request('GET', url, params=params)
    #                 prepared = req.prepare()
    #                 print(f"Full URL: {prepared.url}")
    #                 resp = requests.get(url, params=params, timeout=30)
                    
    #                 # hardcoded_params example removed — use ENTREZ_CLIENT settings instead
                    
    #                 # req = Request('GET', hardcoded_url, params=hardcoded_params)
    #                 # prepared = req.prepare()
    #                 # print(f"Full URL: {prepared.url}")
    #                 resp = requests.get(url, params=params, timeout=30)
    #             else:
    #                 # For EPost
    #                 req = Request('POST', url, data=data)
    #                 prepared = req.prepare()
    #                 print(f"Full URL: {prepared.url}")
    #                 resp = requests.post(url, data=data, timeout=30)
    #             self.logger.debug(f"Request URL: {resp.url}")
    #             resp.raise_for_status()
    #             return resp
    #         except requests.exceptions.HTTPError as e:
    #             status_code = e.response.status_code
    #             self.logger.warning(f"HTTPError encountered: {status_code}")
    #             if status_code in (429, 500, 502, 503, 504):
    #                 # Exponential backoff
    #                 backoff = 2 ** attempt
    #                 self.logger.warning(f"Retrying in {backoff} seconds...")
    #                 time.sleep(backoff)
    #                 attempt += 1
    #             else:
    #                 raise EntrezClientError(
    #                     f"Non-retriable HTTP error {status_code}: {str(e)}"
    #                 ) from e
    #         except requests.exceptions.RequestException as e:
    #             # Network error / connection timeout, etc. 
    #             self.logger.warning(f"RequestException: {str(e)}. Retrying.")
    #             time.sleep(2 ** attempt)
    #             attempt += 1

    #     raise EntrezClientError(f"Failed after {max_retries} attempts.")



    def _request_with_retries(self, url, params=None, data=None, method="GET", max_retries=3):
        """
        Makes a request, implements basic retry logic for 5xx and 429 errors.
        Rate-limiting is also enforced here.
        """
        attempt = 0
        while attempt < max_retries:
            self._throttle()
            try:
                if method == "GET":
                    # Prepare the request to log the full URL
                    req = Request('GET', url, params=params)
                    prepared = req.prepare()
                    self.logger.debug(f"Full URL: {prepared.url}")
                    self.logger.debug(f"Request parameters: {params}")
                    resp = requests.get(url, params=params, timeout=30)
                else:
                    # For EPost
                    req = Request('POST', url, data=data)
                    prepared = req.prepare()
                    self.logger.debug(f"Full URL: {prepared.url}")
                    self.logger.debug(f"Request data: {data}")
                    resp = requests.post(url, data=data, timeout=30)

                self.logger.debug(f"Response status code: {resp.status_code}")
                self.logger.debug(f"Response content: {resp.text[:500]}")  # Log first 500 chars of response
                resp.raise_for_status()
                return resp
            except requests.exceptions.HTTPError as e:
                status_code = e.response.status_code
                self.logger.warning(f"HTTPError encountered: {status_code}")
                if status_code in (429, 500, 502, 503, 504):
                    # Exponential backoff
                    backoff = 2 ** attempt
                    self.logger.warning(f"Retrying in {backoff} seconds...")
                    time.sleep(backoff)
                    attempt += 1
                else:
                    raise EntrezClientError(
                        f"Non-retriable HTTP error {status_code}: {str(e)}"
                    ) from e
            except requests.exceptions.RequestException as e:
                # Network error / connection timeout, etc. 
                self.logger.warning(f"RequestException: {str(e)}. Retrying.")
                time.sleep(2 ** attempt)
                attempt += 1

        raise EntrezClientError(f"Failed after {max_retries} attempts.")

    ##############################
    # ESearch
    ##############################

    def esearch(
        self,
        db="pubmed",
        term="",
        retmode="xml",
        retmax=20,
        retstart=0,
        usehistory="n",
        field=None,
        sort=None,
        datetype=None,
        reldate=None,
        mindate=None,
        maxdate=None
    ):
        """
        Perform a text search in a specified Entrez database (default: pubmed).
        Returns the raw response content (XML or JSON).
        """
        if not term:
            raise EntrezClientError("ESearch requires a non-empty term.")

        url = f"{self.BASE_EUTILS_URL}/esearch.fcgi"
        params = {
            "db": db,
            "term": term,
            "retmode": retmode,
            "retmax": retmax,
            "retstart": retstart,
            "usehistory": usehistory
        }
        if field:
            params["field"] = field
        if sort:
            params["sort"] = sort
        if datetype:
            params["datetype"] = datetype
        if reldate is not None:
            params["reldate"] = reldate
        if mindate and maxdate:
            params["mindate"] = mindate
            params["maxdate"] = maxdate

        merged_params = self._build_params(params)
        resp = self._request_with_retries(url, params=merged_params, method="GET")
        return resp.text

    ##############################
    # Smart Search with Spell-check
    ##############################

    def smart_search(
        self,
        db="pubmed",
        term="",
        auto_correct=True,
        usehistory="y",
        retmax=20,
        retstart=0,
        **kwargs
    ):
        """
        A "smart" search that optionally checks for spelling via ESpell.
        If a spelling suggestion is found, and auto_correct=True, it re-queries with the corrected term.

        :param db: Database (e.g., 'pubmed').
        :param term: Search term (string).
        :param auto_correct: Whether to automatically re-run the search with suggested spelling.
        :param usehistory: Default to 'y' so results are posted to History server.
        :param retmax: Number of UIDs to retrieve (first page).
        :param retstart: Starting index.
        :param kwargs: Additional ESearch parameters (datetype, reldate, mindate, maxdate, etc.).
        :return: Tuple of (final_term, esearch_result_xml)
        """
        if not term:
            raise EntrezClientError("smart_search requires a non-empty term.")
        
        # 1) Check spelling with ESpell
        spell_suggestions = self.espell(db=db, term=term)
        corrected_query = self._parse_spelling_suggestion(spell_suggestions)
        self.logger.debug(f"Initial query: {term}; Suggestion: {corrected_query}")

        final_term = term
        # 2) If there's a suggestion and auto_correct is True, update the term
        if corrected_query and corrected_query.lower() != term.lower() and auto_correct:
            self.logger.info(f"Spelling suggestion found. Auto-correcting '{term}' to '{corrected_query}'")
            final_term = corrected_query

        # 3) Perform ESearch
        esearch_xml = self.esearch(
            db=db, 
            term=final_term, 
            usehistory=usehistory, 
            retmax=retmax, 
            retstart=retstart,
            **kwargs
        )

        return final_term, esearch_xml

    def _parse_spelling_suggestion(self, espell_xml: str):
        """
        Extract the first suggestion from ESpell XML, if any.
        Returns the suggestion string or None.
        """
        try:
            root = ET.fromstring(espell_xml)
            # <CorrectedQuery>some corrected text</CorrectedQuery>
            suggestion = root.find("CorrectedQuery")
            if suggestion is not None and suggestion.text:
                return suggestion.text.strip()
            return None
        except ET.ParseError:
            self.logger.warning("Could not parse ESpell XML.")
            return None

    def espell(self, db="pubmed", term=""):
        """
        Provides spelling suggestions for terms within a single text query in a given database.
        """
        url = f"{self.BASE_EUTILS_URL}/espell.fcgi"
        params = {
            "db": db,
            "term": term
        }
        merged_params = self._build_params(params)
        resp = self._request_with_retries(url, params=merged_params, method="GET")
        return resp.text

    ##############################
    # EFetch
    ##############################

    def efetch(
        self,
        db="pubmed",
        id_list=None,
        query_key=None,
        webenv=None,
        retmode="xml",
        rettype=None,
        retstart=0,
        retmax=20,
        strand=None,
        seq_start=None,
        seq_stop=None,
        complexity=None
    ):
        """
        Fetch data records from a specified Entrez database. 
        E.g., full text from PMC if available (db='pmc', retmode='text').
        """
        if not id_list and not (query_key and webenv):
            raise EntrezClientError("EFetch requires either an id_list or (query_key + webenv).")

        url = f"{self.BASE_EUTILS_URL}/efetch.fcgi"
        params = {
            "db": db,
            "retmode": retmode,
            "retstart": retstart,
            "retmax": retmax,
        }
        if rettype:
            params["rettype"] = rettype
        if query_key and webenv:
            params["query_key"] = query_key
            params["WebEnv"] = webenv
        elif id_list:
            params["id"] = ",".join(id_list)

        # Sequence-specific
        if strand:
            params["strand"] = strand
        if seq_start:
            params["seq_start"] = seq_start
        if seq_stop:
            params["seq_stop"] = seq_stop
        if complexity:
            params["complexity"] = complexity

        merged_params = self._build_params(params)
        print(merged_params)
        resp = self._request_with_retries(url, params=merged_params, method="GET")
        return resp.text

    def fetch_all(
        self,
        db="pubmed",
        query_key=None,
        webenv=None,
        rettype="abstract",
        retmode="text",
        batch_size=100,
        max_records=10000
    ):
        """
        Retrieve ALL records (up to max_records) from a query stored on the History server.
        This method chunks the retrieval in steps of 'batch_size'.

        :param db: The database.
        :param query_key: The query key from ESearch or EPost.
        :param webenv: The WebEnv from ESearch or EPost.
        :param rettype: E.g., 'abstract', 'medline', 'fasta'.
        :param retmode: 'text', 'xml', 'asn.1', etc.
        :param batch_size: Number of records per chunk (<=10,000).
        :param max_records: Maximum total records to fetch. 
        :return: Generator yielding each batch of raw data.
        """
        if not query_key or not webenv:
            raise EntrezClientError("fetch_all requires query_key and webenv for the History server.")

        retstart = 0
        total_fetched = 0

        while True:
            if total_fetched >= max_records:
                self.logger.info("Reached max_records limit.")
                break

            self.logger.info(f"Fetching batch: start={retstart}, size={batch_size}")
            data = self.efetch(
                db=db,
                query_key=query_key,
                webenv=webenv,
                retmode=retmode,
                rettype=rettype,
                retstart=retstart,
                retmax=batch_size
            )
            yield data

            # Check if data is empty or not enough to continue
            fetched_count = batch_size
            retstart += batch_size
            total_fetched += fetched_count
            # If fewer than batch_size might have been returned, we can attempt 
            # to detect it if necessary. As a simplification, we break if 
            # we've approached the typical PubMed limit (10,000) or 
            # if the user-specified max_records is reached. 
            # In a more advanced approach, you'd parse the data to see 
            # if it was truncated. For demonstration, we'll rely on the user 
            # to track total results from esearch.

            if retstart >= 10000 and db == "pubmed":
                self.logger.warning("PubMed does not reliably allow >10,000 records via EFetch. Stopping.")
                break

    ##############################
    # ESummary
    ##############################

    def esummary(
        self,
        db="pubmed",
        id_list=None,
        query_key=None,
        webenv=None,
        retstart=0,
        retmax=20,
        retmode="xml",
        version=None
    ):
        """
        Retrieve document summaries (DocSums) for UIDs or from the History server.
        """
        if not id_list and not (query_key and webenv):
            raise EntrezClientError("ESummary requires either an id_list or (query_key + webenv).")

        url = f"{self.BASE_EUTILS_URL}/esummary.fcgi"
        params = {
            "db": db,
            "retstart": retstart,
            "retmax": retmax,
            "retmode": retmode
        }
        if version:
            params["version"] = version
        if query_key and webenv:
            params["query_key"] = query_key
            params["WebEnv"] = webenv
        elif id_list:
            params["id"] = ",".join(id_list)

        merged_params = self._build_params(params)
        resp = self._request_with_retries(url, params=merged_params, method="GET")
        return resp.text

    ##############################
    # EPost
    ##############################

    def epost(
        self,
        db="pubmed",
        id_list=None,
        webenv=None
    ):
        """
        Post a list of UIDs to the Entrez History server.
        """
        if not id_list:
            raise EntrezClientError("EPost requires id_list to post UIDs.")

        url = f"{self.BASE_EUTILS_URL}/epost.fcgi"
        data = {
            "db": db,
            "id": ",".join(id_list),
        }
        if webenv:
            data["WebEnv"] = webenv

        merged_params = self._build_params({})
        data.update(merged_params)

        resp = self._request_with_retries(url, data=data, method="POST")
        return resp.text

    ##############################
    # ELink
    ##############################

    def elink(
        self,
        dbfrom="pubmed",
        db="pubmed",
        id_list=None,
        query_key=None,
        webenv=None,
        cmd="neighbor",
        linkname=None,
        term=None,
        holding=None,
        datetype=None,
        reldate=None,
        mindate=None,
        maxdate=None,
        retmode="xml"
    ):
        """
        Return UIDs linked to input UIDs or check LinkOuts, etc.
        """
        if not id_list and not (query_key and webenv):
            raise EntrezClientError("ELink requires either an id_list or (query_key + webenv).")

        url = f"{self.BASE_EUTILS_URL}/elink.fcgi"
        params = {
            "dbfrom": dbfrom,
            "db": db,
            "cmd": cmd,
            "retmode": retmode
        }

        if query_key and webenv:
            params["query_key"] = query_key
            params["WebEnv"] = webenv
        elif id_list:
            params["id"] = ",".join(id_list)

        if linkname:
            params["linkname"] = linkname
        if term:
            params["term"] = term
        if holding:
            params["holding"] = holding

        if datetype:
            params["datetype"] = datetype
        if reldate is not None:
            params["reldate"] = reldate
        if mindate and maxdate:
            params["mindate"] = mindate
            params["maxdate"] = maxdate

        merged_params = self._build_params(params)
        resp = self._request_with_retries(url, params=merged_params, method="GET")
        return resp.text

    ##############################
    # EGQuery
    ##############################

    def egquery(self, term):
        """
        Provides the number of records retrieved in all Entrez databases by a single text query.
        """
        if not term:
            raise EntrezClientError("EGQuery requires a search term.")

        url = f"{self.BASE_EUTILS_URL}/egquery.fcgi"
        params = {"term": term}
        merged_params = self._build_params(params)
        resp = self._request_with_retries(url, params=merged_params, method="GET")
        return resp.text

    ##############################
    # ECitMatch
    ##############################

    def ecitmatch(self, db="pubmed", citation_strings=None):
        """
        Retrieves PubMed IDs (PMIDs) corresponding to a set of input citation strings.
        
        :param db: The only supported database is 'pubmed'.
        :param citation_strings: 
          List of strings: "journal_title|year|volume|first_page|author_name|your_key|"
        """
        if not citation_strings:
            raise EntrezClientError("Must provide a list of citation strings.")

        url = f"{self.BASE_EUTILS_URL}/ecitmatch.cgi"
        processed_citations = []
        for cit in citation_strings:
            processed_citations.append(cit.replace(" ", "+"))
        bdata_value = "%0D".join(processed_citations)

        params = {
            "db": db,
            "retmode": "xml",
            "bdata": bdata_value
        }
        merged_params = self._build_params(params)
        resp = self._request_with_retries(url, params=merged_params, method="GET")
        return resp.text
