#!/usr/bin/env python3
"""
Document Embedding Script for Jamie 2.0
Processes documents from S3 knowledge folder and creates vector embeddings
Run this after uploading new proposals/SOWs/NDAs to make them searchable
"""

import boto3
import json
import os
import sys
from pathlib import Path
import argparse

# AWS clients
s3 = boto3.client('s3')
bedrock_runtime = boto3.client('bedrock-runtime', region_name='eu-west-2')

EMBEDDING_MODEL_ID = 'amazon.titan-embed-text-v2:0'


def generate_embedding(text: str) -> list:
    """Generate embedding using Amazon Titan"""
    request_body = json.dumps({
        "inputText": text,
        "dimensions": 1024,
        "normalize": True
    })

    response = bedrock_runtime.invoke_model(
        modelId=EMBEDDING_MODEL_ID,
        body=request_body,
        contentType='application/json',
        accept='application/json'
    )

    response_body = json.loads(response['body'].read())
    return response_body['embedding']


def extract_text_from_file(bucket: str, key: str) -> str:
    """
    Extract text from various file types
    Supports: .txt, .md, .pdf, .docx
    """
    print(f"  Extracting text from: {key}")

    # Get file extension
    ext = Path(key).suffix.lower()

    # Download file
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read()

    # Extract text based on file type
    if ext in ['.txt', '.md']:
        text = content.decode('utf-8', errors='ignore')

    elif ext == '.pdf':
        # For PDF, we'll store a reference and basic metadata
        # Full PDF text extraction would require PyPDF2 or similar
        text = f"PDF Document: {Path(key).name}\nLocation: s3://{bucket}/{key}"
        print(f"  Note: PDF text extraction not implemented. Storing metadata only.")

    elif ext == '.docx':
        # For DOCX, we'll store a reference
        # Full extraction would require python-docx
        text = f"Word Document: {Path(key).name}\nLocation: s3://{bucket}/{key}"
        print(f"  Note: DOCX text extraction not implemented. Storing metadata only.")

    else:
        text = f"Document: {Path(key).name}\nLocation: s3://{bucket}/{key}"
        print(f"  Warning: Unsupported file type {ext}. Storing metadata only.")

    # Limit text length to avoid embedding API limits
    max_chars = 8000
    if len(text) > max_chars:
        text = text[:max_chars] + "... (truncated)"

    return text


def embed_document(bucket: str, document_key: str, vectors_prefix: str = 'vectors/') -> str:
    """
    Generate and store embedding for a document
    """
    print(f"Processing: {document_key}")

    # Extract text
    try:
        text = extract_text_from_file(bucket, document_key)
    except Exception as e:
        print(f"  Error extracting text: {e}")
        return None

    if not text or len(text) < 10:
        print(f"  Skipping: No meaningful text extracted")
        return None

    # Generate embedding
    print(f"  Generating embedding...")
    try:
        embedding = generate_embedding(text)
    except Exception as e:
        print(f"  Error generating embedding: {e}")
        return None

    # Create vector data
    from datetime import datetime

    doc_name = Path(document_key).stem
    vector_data = {
        'document': document_key,
        'text': text[:1000],  # Store preview
        'embedding': embedding,
        'metadata': {
            'source_bucket': bucket,
            'source_key': document_key,
            'file_type': Path(document_key).suffix,
            'file_size': len(text)
        },
        'timestamp': datetime.utcnow().isoformat(),
        'dimensions': len(embedding)
    }

    # Save to S3 vectors folder
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
    vector_key = f"{vectors_prefix}{doc_name}_{timestamp}.json"

    print(f"  Storing embedding at: {vector_key}")
    s3.put_object(
        Bucket=bucket,
        Key=vector_key,
        Body=json.dumps(vector_data),
        ContentType='application/json',
        Metadata={
            'source_document': document_key,
            'timestamp': timestamp
        }
    )

    print(f"  ✓ Successfully embedded: {document_key}")
    return vector_key


def embed_all_documents(bucket: str, source_prefixes: list, vectors_prefix: str = 'vectors/'):
    """
    Process all documents in specified S3 prefixes
    """
    print(f"\nEmbedding documents from bucket: {bucket}")
    print(f"Source prefixes: {source_prefixes}")
    print(f"Vectors destination: {vectors_prefix}\n")

    total_processed = 0
    total_success = 0
    total_failed = 0

    for prefix in source_prefixes:
        print(f"\n{'='*60}")
        print(f"Processing folder: {prefix}")
        print(f"{'='*60}\n")

        # List all objects in prefix
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket, Prefix=prefix)

        for page in pages:
            if 'Contents' not in page:
                continue

            for obj in page['Contents']:
                key = obj['Key']

                # Skip directories and non-document files
                if key.endswith('/'):
                    continue

                # Skip if already a vector file
                if key.startswith(vectors_prefix):
                    continue

                # Skip hidden files
                if Path(key).name.startswith('.'):
                    continue

                total_processed += 1

                # Process document
                try:
                    result = embed_document(bucket, key, vectors_prefix)
                    if result:
                        total_success += 1
                    else:
                        total_failed += 1
                except Exception as e:
                    print(f"  ✗ Failed to process {key}: {e}")
                    total_failed += 1

                print()

    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"{'='*60}")
    print(f"Total documents processed: {total_processed}")
    print(f"Successfully embedded: {total_success}")
    print(f"Failed: {total_failed}")
    print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(
        description='Generate vector embeddings for Jamie 2.0 knowledge base documents'
    )
    parser.add_argument(
        '--bucket',
        required=True,
        help='S3 bucket name (e.g., jamie2-knowledge-base-xxxxx)'
    )
    parser.add_argument(
        '--prefixes',
        nargs='+',
        default=['knowledge/', 'proposals/', 'sows/'],
        help='S3 prefixes to process (default: knowledge/ proposals/ sows/)'
    )
    parser.add_argument(
        '--vectors-prefix',
        default='vectors/',
        help='S3 prefix for storing vector embeddings (default: vectors/)'
    )
    parser.add_argument(
        '--profile',
        default='AdministratorAccess-380414079195',
        help='AWS profile to use'
    )

    args = parser.parse_args()

    # Update AWS clients with profile
    if args.profile:
        session = boto3.Session(profile_name=args.profile)
        global s3, bedrock_runtime
        s3 = session.client('s3')
        bedrock_runtime = session.client('bedrock-runtime', region_name='eu-west-2')

    # Run embedding process
    embed_all_documents(
        bucket=args.bucket,
        source_prefixes=args.prefixes,
        vectors_prefix=args.vectors_prefix
    )


if __name__ == '__main__':
    main()
