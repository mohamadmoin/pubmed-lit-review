"""Repair document section paths after storage-path migration."""

import os
import re

from django.core.management.base import BaseCommand
from django.conf import settings

from documents.neo4j_client import Neo4jClient


class Command(BaseCommand):
    help = 'Copy legacy section files to document-scoped paths and update Neo4j content_path'

    def add_arguments(self, parser):
        parser.add_argument('document_id', type=str)

    def handle(self, *args, **options):
        document_id = options['document_id']
        client = Neo4jClient()
        doc = client.get_document_by_id(document_id)
        if not doc:
            self.stderr.write(f'Document not found: {document_id}')
            return

        storage = settings.TEXT_STORAGE_PATH
        os.makedirs(storage, exist_ok=True)
        repaired = 0

        for section in doc.get('sections', []):
            title = section.get('title')
            old_path = section.get('content_path') or ''
            old_basename = os.path.basename(old_path) if old_path else ''
            legacy_name = f"section_{re.sub(r'[^a-z0-9]+', '_', (title or '').lower()).strip('_')}.txt"

            source = None
            candidates = []
            if old_path:
                candidates.append(old_path)
            if old_basename:
                candidates.append(os.path.join(storage, old_basename))
            candidates.append(os.path.join(storage, legacy_name))

            for candidate in candidates:
                if candidate and os.path.isfile(candidate):
                    source = candidate
                    break

            if not source:
                self.stdout.write(f'Skip (no source file): {title}')
                continue

            new_path = client._section_content_path(document_id, title)
            with open(source, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(new_path, 'w', encoding='utf-8') as f:
                f.write(content)

            client._run_query(
                """
                MATCH (d:Document {id: $document_id})-[:HAS_SECTION]->(s:Section)
                WHERE s.title = $section_title
                SET s.content_path = $content_path, s.updated_at = datetime()
                """,
                {
                    'document_id': document_id,
                    'section_title': title,
                    'content_path': new_path,
                },
            )
            repaired += 1
            self.stdout.write(f'Repaired: {title} -> {new_path} ({len(content)} chars)')

        self.stdout.write(self.style.SUCCESS(f'Repaired {repaired} section(s) for {document_id}'))
