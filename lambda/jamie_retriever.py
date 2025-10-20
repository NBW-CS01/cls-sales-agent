"""
Jamie 2.0 Document Retriever
Lambda function to search S3 for similar proposals and SOWs
Uses simple keyword matching and document metadata
"""

import json
import boto3
import os
from typing import List, Dict
import re

s3 = boto3.client('s3')
bedrock_runtime = boto3.client('bedrock-runtime')

KNOWLEDGE_BASE_BUCKET = os.environ['KNOWLEDGE_BASE_BUCKET']
REGION = os.environ['REGION']


def lambda_handler(event, context):
    """
    Main handler for Bedrock Agent action group
    """
    print(f"Received event: {json.dumps(event)}")

    agent = event.get('agent')
    action_group = event.get('actionGroup')
    function = event.get('function')
    parameters = event.get('parameters', [])

    # Extract parameters
    query = None
    max_results = 5

    for param in parameters:
        if param['name'] == 'query':
            query = param['value']
        elif param['name'] == 'max_results':
            max_results = int(param['value'])

    if not query:
        return error_response("No search query provided")

    try:
        # Search for relevant documents
        results = search_documents(query, max_results)

        # Format response for Bedrock Agent
        response_body = {
            "TEXT": {
                "body": json.dumps({
                    "results": results,
                    "query": query,
                    "num_results": len(results)
                })
            }
        }

        action_response = {
            'actionGroup': action_group,
            'function': function,
            'functionResponse': {
                'responseBody': response_body
            }
        }

        return {
            'response': action_response,
            'messageVersion': event['messageVersion']
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(str(e))


def search_documents(query: str, max_results: int = 5) -> List[Dict]:
    """
    Search S3 bucket for documents matching the query
    Uses simple keyword matching and file metadata
    """
    matching_docs = []

    try:
        # List all objects in the knowledge base bucket
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=KNOWLEDGE_BASE_BUCKET)

        query_lower = query.lower()
        query_keywords = extract_keywords(query_lower)

        for page in pages:
            if 'Contents' not in page:
                continue

            for obj in page['Contents']:
                key = obj['Key']

                # Skip directories
                if key.endswith('/'):
                    continue

                # Calculate relevance score based on filename and path
                score = calculate_relevance(key, query_keywords)

                if score > 0:
                    # Get document metadata
                    try:
                        metadata = s3.head_object(Bucket=KNOWLEDGE_BASE_BUCKET, Key=key)

                        # Try to read document content for context
                        content_preview = get_document_preview(key)

                        matching_docs.append({
                            'key': key,
                            'score': score,
                            'size': obj['Size'],
                            'last_modified': obj['LastModified'].isoformat(),
                            'preview': content_preview,
                            'metadata': metadata.get('Metadata', {})
                        })
                    except Exception as e:
                        print(f"Error processing {key}: {str(e)}")
                        continue

        # Sort by relevance score
        matching_docs.sort(key=lambda x: x['score'], reverse=True)

        # Return top N results
        return matching_docs[:max_results]

    except Exception as e:
        print(f"Error searching documents: {str(e)}")
        raise


def extract_keywords(text: str) -> List[str]:
    """Extract meaningful keywords from search query"""
    # Remove common stop words
    stop_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'}

    # Split and clean
    words = re.findall(r'\b\w+\b', text.lower())
    keywords = [w for w in words if w not in stop_words and len(w) > 2]

    return keywords


def calculate_relevance(file_path: str, keywords: List[str]) -> float:
    """
    Calculate relevance score for a document based on keywords
    """
    score = 0.0
    file_path_lower = file_path.lower()

    # Check if keywords appear in file path/name
    for keyword in keywords:
        if keyword in file_path_lower:
            score += 1.0

    # Boost score for certain file types
    if file_path.endswith('.pdf'):
        score += 0.5
    elif file_path.endswith(('.docx', '.doc')):
        score += 0.5
    elif file_path.endswith('.txt'):
        score += 0.3

    # Boost score for files in certain directories
    if '/proposals/' in file_path_lower:
        score += 0.5
    elif '/sows/' in file_path_lower or '/sow/' in file_path_lower:
        score += 0.5

    return score


def get_document_preview(key: str, max_chars: int = 500) -> str:
    """
    Get a preview of the document content
    Only works for text-based files
    """
    try:
        # Only preview text files
        if not key.endswith(('.txt', '.md', '.json')):
            return f"[{key.split('.')[-1].upper()} file]"

        response = s3.get_object(Bucket=KNOWLEDGE_BASE_BUCKET, Key=key)
        content = response['Body'].read().decode('utf-8', errors='ignore')

        # Return first N characters
        preview = content[:max_chars]
        if len(content) > max_chars:
            preview += "..."

        return preview

    except Exception as e:
        print(f"Error reading preview for {key}: {str(e)}")
        return "[Preview unavailable]"


def error_response(error_message: str) -> Dict:
    """Format error response for Bedrock Agent"""
    return {
        'response': {
            'functionResponse': {
                'responseBody': {
                    'TEXT': {
                        'body': json.dumps({
                            'error': error_message
                        })
                    }
                }
            }
        }
    }
