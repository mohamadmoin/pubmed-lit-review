from celery import shared_task
from django.utils import timezone
from django.conf import settings
import logging

from litreview.llm_client import get_llm_client
from .models import DocumentGenerationRequest
from .document_generator import DocumentGenerator
from .neo4j_client import Neo4jClient

logger = logging.getLogger(__name__)

@shared_task
def generate_document_task(request_id: int, document_id: str, user_id=None) -> dict:
    """
    Celery task to generate a research document based on a request.
    
    This task performs the following steps:
    1. Updates the request status to 'processing'
    2. Initializes DocumentGenerator with Neo4jClient
    3. Calls the document generation function with request parameters
    4. Updates the request status to 'completed' or 'failed'
    
    Args:
        request_id: ID of the DocumentGenerationRequest to process
        document_id: Unique ID for the document to be generated
        user_id: Optional user ID for document ownership
        
    Returns:
        dict: Summary of the task execution with status information
    """
    logger.info(f"Starting document generation for request ID: {request_id}")
    
    try:
        # Get the request object
        doc_request = DocumentGenerationRequest.objects.get(id=request_id)
        
        # Update status to processing
        doc_request.status = 'processing'
        doc_request.save()
        logger.info(f"Updated request {request_id} status to 'processing'")

        # Initialize Neo4jClient and DocumentGenerator
        neo4j_client = Neo4jClient(
            uri=settings.NEO4J_URI,
            user=settings.NEO4J_USER,
            password=settings.NEO4J_PASSWORD
        )
        document_generator = DocumentGenerator(neo4j_client=neo4j_client)

        try:
            # Run the document generation with parameters from the request
            logger.info(f"Running document generation with subject: {doc_request.subject}")
            result = document_generator.generate_document(
                subject=doc_request.subject,
                description=doc_request.description,
                num_words=doc_request.word_count,
                openai_client=get_llm_client(),
                document_id=document_id,
                entrez_client=settings.ENTREZ_CLIENT,  # Assuming this is configured in settings
                use_enhanced_filtering=True,
                user_id=user_id
            )

            # Update request to completed with timestamp and document ID
            doc_request.status = 'completed'
            doc_request.completed_at = timezone.now()
            doc_request.document_id = result['id']  # Store the generated document ID
            doc_request.save()
            logger.info(f"Document generation completed for request {request_id}")
            
            return {
                'status': 'completed',
                'request_id': request_id,
                'document_id': result['id']
            }
            
        finally:
            # Always close the Neo4j connection
            document_generator.close()
        
    except DocumentGenerationRequest.DoesNotExist:
        logger.error(f"Document generation request with ID {request_id} not found")
        return {'status': 'failed', 'error': f"Request {request_id} not found"}
        
    except Exception as e:
        logger.exception(f"Error during document generation for request {request_id}: {str(e)}")
        
        # Try to update the request status if possible
        try:
            doc_request = DocumentGenerationRequest.objects.get(id=request_id)
            doc_request.status = 'failed'
            doc_request.error_message = str(e)
            doc_request.save()
            logger.info(f"Updated request {request_id} status to 'failed'")
        except Exception as inner_e:
            logger.error(f"Could not update request status: {str(inner_e)}")
        
        return {
            'status': 'failed',
            'request_id': request_id,
            'error': str(e)
        } 