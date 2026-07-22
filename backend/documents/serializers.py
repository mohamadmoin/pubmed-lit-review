from rest_framework import serializers
from .models import AIGeneratedDocument, DocumentGenerationRequest
from typing import Dict, Any, List

class AIGeneratedDocumentSerializer(serializers.Serializer):
    """
    Serializer for Neo4j AI-Generated documents.
    
    This serializer handles the JSON representation of AI-generated documents
    from Neo4j. Since the actual document is not stored in Django's database,
    this is a regular Serializer rather than a ModelSerializer.
    
    This serializer is primarily used for data validation and formatting
    document data for API responses.
    """
    id = serializers.CharField(help_text="Unique identifier for the document")
    title = serializers.CharField(help_text="Document title")
    content = serializers.CharField(help_text="Document content (abstract/summary)")
    word_count = serializers.IntegerField(help_text="Total word count of the document")
    created_at = serializers.CharField(help_text="Document creation timestamp")
    sections = serializers.ListField(help_text="List of document sections")
    references = serializers.ListField(help_text="List of references cited in the document")
    process_logs = serializers.ListField(help_text="List of document generation process logs")
    
    class Meta:
        model = AIGeneratedDocument
        fields = ['id', 'title', 'content', 'word_count', 'created_at', 
                  'sections', 'references', 'process_logs']
        read_only_fields = fields 
        
    def to_representation(self, instance: AIGeneratedDocument) -> Dict[str, Any]:
        """
        Convert AIGeneratedDocument instance to a dictionary for serialization.
        
        Args:
            instance: AIGeneratedDocument instance to serialize
            
        Returns:
            Dictionary representation of the document
        """
        # If it's already a dict, just return it
        if isinstance(instance, dict):
            return instance
            
        # Otherwise, convert the model instance to a dict
        return instance.to_dict()

class DocumentGenerationRequestSerializer(serializers.ModelSerializer):
    """
    Serializer for document generation requests.
    
    This serializer handles the validation and representation of document
    generation requests. It includes validation rules for required fields
    and defines which fields are read-only.
    """
    class Meta:
        model = DocumentGenerationRequest
        fields = '__all__'
        read_only_fields = ('status', 'created_at', 'completed_at', 'error_message', 'user', 'document_id')
        
    def validate_word_count(self, value: int) -> int:
        """
        Validate the word count for document generation.
        
        Args:
            value: The word count value to validate
            
        Returns:
            The validated word count
            
        Raises:
            serializers.ValidationError: If word count is out of valid range
        """
        if value < 500:
            raise serializers.ValidationError("Word count must be at least 500 words")
        if value > 10000:
            raise serializers.ValidationError("Word count cannot exceed 10,000 words")
        return value
        
    def validate_subject(self, value: str) -> str:
        """
        Validate the subject for document generation.
        
        Args:
            value: The subject value to validate
            
        Returns:
            The validated subject
            
        Raises:
            serializers.ValidationError: If subject is too short or too long
        """
        if len(value) < 5:
            raise serializers.ValidationError("Subject must be at least 5 characters long")
        if len(value) > 200:
            raise serializers.ValidationError("Subject cannot exceed 200 characters")
        return value 