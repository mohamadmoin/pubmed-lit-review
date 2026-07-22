import uuid
import os
from django.shortcuts import render
from django.http import FileResponse
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.request import Request
from rest_framework.views import APIView
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from .models import AIGeneratedDocument, DocumentManager, DocumentGenerationRequest
from .serializers import AIGeneratedDocumentSerializer, DocumentGenerationRequestSerializer
from .document_generator import DocumentGenerator
from .neo4j_client import Neo4jClient
import logging
from django.utils import timezone
from django.conf import settings
from typing import Dict, Any, Optional
from .tasks import generate_document_task
from litreview.llm_client import get_llm_client

logger = logging.getLogger(__name__)

# Create your views here.

class AIGeneratedDocumentViewSet(viewsets.ViewSet):
    """
    ViewSet for AI-Generated Documents from Neo4j.
    
    This ViewSet provides APIs to retrieve and interact with AI-generated 
    documents stored in Neo4j database. It uses the DocumentGenerator class
    for all document operations.
    """
    basename = 'document'
    permission_classes = [permissions.IsAuthenticated]  # Add authentication requirement
    
    def __init__(self, *args, **kwargs):
        """Initialize ViewSet with Neo4jClient and DocumentGenerator."""
        super().__init__(*args, **kwargs)
        self.neo4j_client = Neo4jClient(
            uri=settings.NEO4J_URI,
            user=settings.NEO4J_USER,
            password=settings.NEO4J_PASSWORD
        )
        self.document_generator = DocumentGenerator(neo4j_client=self.neo4j_client)
    
    def __del__(self):
        """Clean up Neo4j connection."""
        if hasattr(self, 'document_generator'):
            self.document_generator.close()
    
    def list(self, request: Request) -> Response:
        """
        List all documents from Neo4j.
        
        Returns a paginated list of all available documents with their
        basic metadata. This endpoint does not include the full document
        content or sections to reduce response size.
        
        Returns:
            Response: JSON response with document list
        """
        try:
            # Get all documents from Neo4j, filtered by user if authenticated
            user_id = request.user.id if request.user.is_authenticated else None
            documents = self.neo4j_client.get_all_documents(user_id=user_id)
            
            # Convert Neo4j DateTime objects to ISO format strings
            for doc in documents:
                if 'created_at' in doc and hasattr(doc['created_at'], 'iso_format'):
                    doc['created_at'] = doc['created_at'].iso_format()
                if 'updated_at' in doc and hasattr(doc['updated_at'], 'iso_format'):
                    doc['updated_at'] = doc['updated_at'].iso_format()
                if 'completed_at' in doc and hasattr(doc['completed_at'], 'iso_format'):
                    doc['completed_at'] = doc['completed_at'].iso_format()
            
            return Response({
                'count': len(documents),
                'results': documents
            })
        except Exception as e:
            logger.error(f"Error fetching documents from Neo4j: {e}")
            return Response(
                {"error": "Could not retrieve documents", "details": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def retrieve(self, request: Request, pk: str = None) -> Response:
        """
        Get a specific document from Neo4j by ID.
        
        Args:
            request: The HTTP request
            pk: Primary key (document ID) to retrieve
            
        Returns:
            Response: JSON response with document data or error
        """
        try:
            # Get user ID if authenticated
            user_id = request.user.id if request.user.is_authenticated else None
            document = self.document_generator.get_document(pk, user_id=user_id)
            if document:
                return Response(document)
            return Response({"error": "Document not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error fetching document {pk} from Neo4j: {e}")
            return Response(
                {"error": f"Could not retrieve document {pk}", "details": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['get'], url_path=r'papers/(?P<pmid>[^/.]+)/full_text')
    def paper_full_text(self, request: Request, pk: str = None, pmid: str = None) -> Response:
        """Return the full stored text for a paper linked to this document."""
        try:
            user_id = request.user.id if request.user.is_authenticated else None
            document = self.document_generator.get_document(pk, user_id=user_id)
            if not document:
                return Response({"error": "Document not found"}, status=status.HTTP_404_NOT_FOUND)

            text = self.neo4j_client.get_paper_full_text_for_document(pk, pmid)
            if not text:
                return Response(
                    {"error": "Full text not available for this paper"},
                    status=status.HTTP_404_NOT_FOUND,
                )
            return Response({"pmid": pmid, "full_text": text})
        except Exception as e:
            logger.error(f"Error fetching full text for paper {pmid} in document {pk}: {e}")
            return Response(
                {"error": "Could not retrieve full text", "details": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @action(detail=True, methods=['get'])
    def download(self, request: Request, pk: str = None) -> Response:
        """
        Download the generated Word document (.docx) for a document.
        """
        try:
            user_id = request.user.id if request.user.is_authenticated else None
            document = self.document_generator.get_document(pk, user_id=user_id)
            if not document:
                return Response({"error": "Document not found"}, status=status.HTTP_404_NOT_FOUND)

            file_path = document.get('file_path')
            if not file_path:
                return Response(
                    {"error": "No export file available for this document"},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if not os.path.isabs(file_path):
                candidates = self.neo4j_client._get_possible_file_paths(file_path)
            else:
                candidates = [file_path]

            resolved_path = next((p for p in candidates if os.path.exists(p)), None)
            if not resolved_path:
                return Response(
                    {"error": "Export file not found on server"},
                    status=status.HTTP_404_NOT_FOUND,
                )

            filename = os.path.basename(resolved_path)
            return FileResponse(
                open(resolved_path, 'rb'),
                as_attachment=True,
                filename=filename,
                content_type='application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            )
        except Exception as e:
            logger.error(f"Error downloading document {pk}: {e}")
            return Response(
                {"error": f"Could not download document {pk}", "details": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
    
    @action(detail=False, methods=['get'])
    def status(self, request: Request) -> Response:
        """
        API status endpoint to check connectivity to Neo4j.
        
        This endpoint is useful for monitoring tools and health checks.
        It verifies that the API is running and can connect to Neo4j.
        
        Returns:
            Response: Status information with Neo4j connection state
        """
        try:
            # Test Neo4j connection by getting document count
            documents = self.neo4j_client.get_all_documents()
            document_count = len(documents)
            
            return Response({
                'status': 'ok',
                'message': 'LitReview API is running',
                'neo4j_connection': 'ok',
                'document_count': document_count
            })
        except Exception as e:
            logger.error(f"API status check failed: {e}")
            return Response({
                'status': 'error',
                'message': 'Research Platform API is running but Neo4j connection failed',
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['get'])
    def content(self, request: Request, pk: str = None) -> Response:
        """
        Get document content with sections, references, and process logs.
        
        This endpoint returns the complete document including all sections,
        references, and generation process logs. It's useful for detailed
        document viewing.
        
        Args:
            request: The HTTP request
            pk: Primary key (document ID) to retrieve
            
        Returns:
            Response: Complete document data or error
        """
        try:
            # Get user ID if authenticated
            user_id = request.user.id if request.user.is_authenticated else None
            document = self.document_generator.get_document(pk, user_id=user_id)
            if not document:
                return Response({"error": "Document not found"}, status=status.HTTP_404_NOT_FOUND)
            
            return Response(document)
        except Exception as e:
            logger.error(f"Error fetching document content for {pk} from Neo4j: {e}")
            return Response(
                {"error": f"Could not retrieve document content for {pk}", "details": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=True, methods=['post'])
    def edit_section(self, request: Request, pk: str = None) -> Response:
        """
        Edit a section's content and track the change.
        
        Args:
            request: The HTTP request containing section_id and new_content
            pk: Document ID
            
        Returns:
            Response: Updated section data or error
        """
        try:
            section_id = request.data.get('section_id')
            new_content = request.data.get('content')
            user_id = str(request.user.id) if request.user.is_authenticated else None
            
            if not section_id or not new_content:
                return Response(
                    {"error": "section_id and content are required"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            result = self.document_generator.edit_section(
                document_id=pk,
                section_id=section_id,
                new_content=new_content,
                user_id=user_id
            )
            
            return Response(result)
        except Exception as e:
            logger.error(f"Error editing section in document {pk}: {e}")
            return Response(
                {"error": f"Could not edit section", "details": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=True, methods=['post'])
    def regenerate_section(self, request: Request, pk: str = None) -> Response:
        """
        Regenerate content for a specific section.
        
        Args:
            request: The HTTP request containing section_id
            pk: Document ID
            
        Returns:
            Response: Updated document data or error
        """
        try:
            section_id = request.data.get('section_id')
            
            if not section_id:
                return Response(
                    {"error": "section_id is required"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            result = self.document_generator.regenerate_from_section(
                document_id=pk,
                section_id=section_id,
                openai_client=get_llm_client(),
                entrez_client=settings.ENTREZ_CLIENT
            )
            
            return Response(result)
        except Exception as e:
            logger.error(f"Error regenerating section in document {pk}: {e}")
            return Response(
                {"error": f"Could not regenerate section", "details": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=['post'])
    def generatedocument(self, request: Request) -> Response:
        """
        Create a new document generation request.
        
        This endpoint validates the request data, creates a DocumentGenerationRequest
        record in the database, and starts an asynchronous Celery task to generate
        the document. The document generation process involves AI-powered research,
        PubMed searches, and text generation.
        
        Args:
            request: HTTP request with document generation parameters
            
        Returns:
            Response: Creation acknowledgment with request ID
        """
        try:
            logger.info(f"Received document generation request with data: {request.data}")
            
            serializer = DocumentGenerationRequestSerializer(data=request.data)
            if not serializer.is_valid():
                logger.error(f"Serializer validation errors: {serializer.errors}")
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            document_id = str(uuid.uuid4())
            # Create the request record with the authenticated user
            doc_request = serializer.save(
                status='pending',
                document_id = document_id,
                user=request.user
            )
            logger.info(f"Created document generation request with ID: {doc_request.id}")
            
            # Start the celery task for document generation
            generate_document_task.delay(doc_request.id, document_id, request.user.id)
            logger.info(f"Started celery task for document generation request: {doc_request.id}")
            
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        except Exception as e:
            logger.error(f"Error creating document generation request: {e}", exc_info=True)
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['get'])
    def process_logs(self, request: Request, pk: str = None) -> Response:
        """
        Get the process logs for a specific document generation.
        
        This endpoint returns the generation process logs in chronological order,
        allowing the frontend to track the document generation progress.
        
        Args:
            request: The HTTP request
            pk: Document ID to get logs for
            
        Returns:
            Response: JSON response with process logs or error
        """
        try:
            # Get document to verify it exists
            document = self.document_generator.get_document(pk)
            if not document:
                return Response(
                    {"error": "Document not found"}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Extract and format process logs
            process_logs = document.get('processLogs', [])
            
            # Sort logs by timestamp
            process_logs.sort(key=lambda x: x['timestamp'])
            
            # Format response
            response_data = {
                'document_id': pk,
                'status': document.get('status', 'unknown'),
                'logs': process_logs,
                'total_steps': len(process_logs),
                'current_step': next(
                    (log for log in reversed(process_logs) if log['level'] == 'INFO'),
                    None
                )
            }
            
            return Response(response_data)
            
        except Exception as e:
            logger.error(f"Error fetching process logs for document {pk}: {e}")
            return Response(
                {
                    "error": f"Could not retrieve process logs for document {pk}",
                    "details": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
