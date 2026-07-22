from django.db import models
from django.contrib.auth import get_user_model
from .neo4j_client import Neo4jClient
from typing import List, Optional

User = get_user_model()

class AIGeneratedDocument(models.Model):
    """
    Proxy model for Neo4j documents.
    
    This model doesn't store the actual data in the Django database. Instead, 
    it serves as a facade to the Neo4j graph database, providing a Django-like 
    interface for the document data stored in Neo4j.
    
    The document structure includes sections, references, and process logs
    which are all stored in Neo4j and retrieved via the Neo4jClient.
    """
    id = models.CharField(max_length=100, primary_key=True)
    title = models.CharField(max_length=500)
    content = models.TextField()
    word_count = models.IntegerField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField(auto_now=True)
    
    # These fields are not stored in Django's DB but returned via to_dict()
    # They come from Neo4j
    _sections = []
    _references = []
    _process_logs = []
    
    class Meta:
        ordering = ['-created_at']
        managed = False  # Django won't create a database table for this model
    
    def __str__(self):
        return self.title
    
    @property
    def sections(self):
        """Get the sections of the document."""
        return self._sections
    
    @sections.setter
    def sections(self, value):
        """Set the sections of the document."""
        self._sections = value
    
    @property
    def references(self):
        """Get the references cited in the document."""
        return self._references
    
    @references.setter
    def references(self, value):
        """Set the references cited in the document."""
        self._references = value
    
    @property
    def process_logs(self):
        """Get the process logs for document generation."""
        return self._process_logs
    
    @process_logs.setter
    def process_logs(self, value):
        """Set the process logs for document generation."""
        self._process_logs = value
    
    def to_dict(self):
        """
        Convert document to dictionary for API responses.
        
        Returns:
            dict: Document data with all related entities.
        """
        return {
            'id': self.id,
            'title': self.title,
            'content': self.content,
            'word_count': self.word_count,
            'created_at': self.created_at.isoformat() if hasattr(self.created_at, 'isoformat') else self.created_at,
            'updated_at': self.updated_at.isoformat() if hasattr(self.updated_at, 'isoformat') else self.updated_at,
            'sections': self.sections,
            'references': self.references,
            'process_logs': self.process_logs,
        }
    
    @classmethod
    def from_neo4j_dict(cls, data):
        """
        Create model instance from Neo4j dictionary.
        
        Args:
            data (dict): Document data from Neo4j
            
        Returns:
            AIGeneratedDocument: Populated model instance or None if data is empty
        """
        if not data:
            return None
            
        instance = cls(
            id=data['id'],
            title=data['title'],
            content=data.get('content', ''),
            word_count=data.get('word_count', 0),
            created_at=data.get('created_at', '')
        )
        
        # Add relationships
        instance.sections = data.get('sections', [])
        instance.references = data.get('references', [])
        instance.process_logs = data.get('process_logs', [])
        
        return instance

# Document Manager to handle Neo4j operations
class DocumentManager:
    """
    Manager for working with AI-generated documents in Neo4j.
    
    This manager provides a higher-level interface for document operations,
    handling the communication with Neo4j through the Neo4jClient.
    """
    
    def __init__(self):
        """Initialize the document manager with a Neo4j client."""
        self.neo4j_client = Neo4jClient()
    
    def get_all_documents(self) -> List[AIGeneratedDocument]:
        """
        Get all documents from Neo4j.
        
        Returns:
            List[AIGeneratedDocument]: List of AIGeneratedDocument instances.
        """
        documents_data = self.neo4j_client.get_all_documents()
        return [AIGeneratedDocument.from_neo4j_dict(doc) for doc in documents_data]
    
    def get_document(self, document_id: str) -> Optional[AIGeneratedDocument]:
        """
        Get a specific document from Neo4j.
        
        Args:
            document_id (str): The ID of the document to retrieve.
            
        Returns:
            Optional[AIGeneratedDocument]: Document instance if found, None otherwise.
        """
        document_data = self.neo4j_client.get_document_by_id(document_id)
        return AIGeneratedDocument.from_neo4j_dict(document_data)
    
    def close(self):
        """Close Neo4j connection."""
        self.neo4j_client.close()

class DocumentGenerationRequest(models.Model):
    """
    Model for document generation requests.
    
    This model stores the information needed to generate a new document,
    as well as the status and results of the generation process.
    Unlike AIGeneratedDocument, this is a standard Django model
    stored in the relational database.
    """
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    )

    subject = models.CharField(max_length=500)
    description = models.TextField()
    word_count = models.IntegerField(default=2000)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    error_message = models.TextField(null=True, blank=True)
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='document_requests',
        default=1  # Setting default user ID to 1
    )
    document_id = models.CharField(max_length=100, null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        
    def __str__(self):
        """String representation of the document generation request."""
        return f"{self.subject} ({self.status})"
        
    @classmethod
    def get_user_documents(cls, user):
        """Get all document requests for a specific user."""
        return cls.objects.filter(user=user).order_by('-created_at')
