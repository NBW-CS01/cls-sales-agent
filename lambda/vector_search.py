"""
Vector Search Lambda Function (ALICE-style)
Stores and searches vector embeddings in S3 using NumPy cosine similarity
Cost-effective alternative to OpenSearch Serverless (~$0.35/month vs $700/month)
"""

import json
import boto3
import os
from typing import List, Dict, Tuple
from datetime import datetime, timedelta
import io

# Import NumPy (will be in Lambda layer)
try:
    import numpy as np
except ImportError:
    print("Warning: NumPy not available. Install with: pip install numpy")

s3 = boto3.client('s3')
bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('REGION', 'eu-west-2'))

KNOWLEDGE_BASE_BUCKET = os.environ.get('KNOWLEDGE_BASE_BUCKET', '')
VECTORS_PREFIX = 'vectors/'
EMBEDDING_MODEL_ID = 'amazon.titan-embed-text-v2:0'


def lambda_handler(event, context):
    """
    Main handler for Bedrock Agent action group - Vector search
    """
    print(f"Received event: {json.dumps(event)}")

    action_group = event.get('actionGroup')
    function = event.get('function')
    parameters = event.get('parameters', [])

    # Extract parameters
    query = None
    max_results = 5
    similarity_threshold = 0.3

    for param in parameters:
        if param['name'] == 'query':
            query = param['value']
        elif param['name'] == 'max_results':
            max_results = int(param['value'])
        elif param['name'] == 'similarity_threshold':
            similarity_threshold = float(param['value'])

    if not query:
        return error_response("Search query is required")

    try:
        # Perform vector search
        results = vector_search(
            query=query,
            max_results=max_results,
            similarity_threshold=similarity_threshold
        )

        # Format response for Bedrock Agent
        response_body = {
            "TEXT": {
                "body": json.dumps({
                    "success": True,
                    "query": query,
                    "num_results": len(results),
                    "results": results
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
        import traceback
        traceback.print_exc()
        return error_response(str(e))


def vector_search(query: str, max_results: int = 5, similarity_threshold: float = 0.3) -> List[Dict]:
    """
    Search for documents using vector similarity (ALICE-style)

    Args:
        query: Search query text
        max_results: Maximum number of results to return
        similarity_threshold: Minimum similarity score (0.0 to 1.0)

    Returns:
        List of matching documents with similarity scores
    """
    print(f"Vector search for: {query}")

    # Step 1: Generate embedding for query
    query_embedding = generate_embedding(query)

    # Step 2: List all vector files in S3
    vector_files = list_vector_files()

    if not vector_files:
        print("No vector files found in S3")
        return []

    print(f"Found {len(vector_files)} vector files to search")

    # Step 3: Calculate similarities
    similarities = []

    for file_key in vector_files:
        try:
            # Download vector file
            vector_data = download_vector_file(file_key)

            if not vector_data or 'embedding' not in vector_data:
                continue

            # Calculate cosine similarity
            doc_embedding = vector_data['embedding']
            similarity = cosine_similarity(query_embedding, doc_embedding)

            # Only include if above threshold
            if similarity >= similarity_threshold:
                similarities.append({
                    'key': file_key,
                    'similarity': similarity,
                    'text': vector_data.get('text', ''),
                    'metadata': vector_data.get('metadata', {}),
                    'document': vector_data.get('document', ''),
                    'timestamp': vector_data.get('timestamp', '')
                })

        except Exception as e:
            print(f"Error processing {file_key}: {str(e)}")
            continue

    # Step 4: Sort by similarity (descending)
    similarities.sort(key=lambda x: x['similarity'], reverse=True)

    # Step 5: Return top N results
    results = similarities[:max_results]

    print(f"Returning {len(results)} results above threshold {similarity_threshold}")

    return results


def generate_embedding(text: str) -> List[float]:
    """
    Generate embedding vector using Amazon Titan Embed v2
    Same as ALICE's generate_embedding function
    """
    print(f"Generating embedding for text: {text[:100]}...")

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
    embedding = response_body['embedding']

    print(f"Generated embedding with {len(embedding)} dimensions")

    return embedding


def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    """
    Calculate cosine similarity between two vectors
    Same as ALICE's cosine_similarity function
    """
    v1 = np.array(vec1)
    v2 = np.array(vec2)

    # Cosine similarity = dot product / (norm1 * norm2)
    dot_product = np.dot(v1, v2)
    norm1 = np.linalg.norm(v1)
    norm2 = np.linalg.norm(v2)

    if norm1 == 0 or norm2 == 0:
        return 0.0

    similarity = dot_product / (norm1 * norm2)

    return float(similarity)


def list_vector_files() -> List[str]:
    """
    List all vector files in S3
    """
    vector_keys = []

    try:
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(
            Bucket=KNOWLEDGE_BASE_BUCKET,
            Prefix=VECTORS_PREFIX
        )

        for page in pages:
            if 'Contents' not in page:
                continue

            for obj in page['Contents']:
                key = obj['Key']

                # Only include .json files
                if key.endswith('.json'):
                    vector_keys.append(key)

        print(f"Found {len(vector_keys)} vector files")

    except Exception as e:
        print(f"Error listing vector files: {str(e)}")
        raise

    return vector_keys


def download_vector_file(key: str) -> Dict:
    """
    Download and parse a vector file from S3
    """
    try:
        response = s3.get_object(Bucket=KNOWLEDGE_BASE_BUCKET, Key=key)
        content = response['Body'].read().decode('utf-8')
        data = json.loads(content)
        return data

    except Exception as e:
        print(f"Error downloading {key}: {str(e)}")
        return {}


def store_document_embedding(document_text: str, document_id: str, metadata: Dict = None) -> str:
    """
    Generate and store embedding for a document
    Used during document ingestion

    Args:
        document_text: Text content to embed
        document_id: Unique identifier for the document
        metadata: Additional metadata to store

    Returns:
        S3 key where embedding was stored
    """
    print(f"Storing embedding for document: {document_id}")

    # Generate embedding
    embedding = generate_embedding(document_text)

    # Create vector data structure
    vector_data = {
        'document': document_id,
        'text': document_text[:1000],  # Store first 1000 chars as preview
        'embedding': embedding,
        'metadata': metadata or {},
        'timestamp': datetime.utcnow().isoformat(),
        'dimensions': len(embedding)
    }

    # Save to S3
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
    key = f"{VECTORS_PREFIX}{document_id}_{timestamp}.json"

    s3.put_object(
        Bucket=KNOWLEDGE_BASE_BUCKET,
        Key=key,
        Body=json.dumps(vector_data),
        ContentType='application/json',
        Metadata={
            'document_id': document_id,
            'timestamp': timestamp
        }
    )

    print(f"Stored embedding at: {key}")

    return key


def error_response(error_message: str) -> Dict:
    """Format error response for Bedrock Agent"""
    return {
        'response': {
            'functionResponse': {
                'responseBody': {
                    'TEXT': {
                        'body': json.dumps({
                            'success': False,
                            'error': error_message
                        })
                    }
                }
            }
        }
    }


# Testing
if __name__ == '__main__':
    # Test vector search locally
    test_event = {
        'agent': 'test',
        'actionGroup': 'VectorSearch',
        'function': 'searchDocuments',
        'parameters': [
            {'name': 'query', 'value': 'cloud migration proposal'},
            {'name': 'max_results', 'value': '5'}
        ],
        'messageVersion': '1.0'
    }

    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))
