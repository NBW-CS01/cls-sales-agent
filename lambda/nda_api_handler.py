"""
NDA API Gateway Handler
Invokes Jamie 2.0 Bedrock Agent to generate NDAs via HTTP API
"""

import json
import boto3
import os
from typing import Dict, Any
import uuid

# Environment variables
AGENT_ID = os.environ.get('AGENT_ID')
AGENT_ALIAS_ID = os.environ.get('AGENT_ALIAS_ID')

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')


def lambda_handler(event, context):
    """
    API Gateway HTTP API handler for NDA generation

    Expected request body:
    {
        "company": "Company Name or Number",
        "signatory_name": "John Smith",
        "signatory_title": "Director"
    }
    """
    print(f"Received event: {json.dumps(event)}")

    # Handle CORS preflight
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return cors_response(200, {'message': 'OK'})

    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))

        company = body.get('company')
        signatory_name = body.get('signatory_name')
        signatory_title = body.get('signatory_title')
        document_types = body.get('document_types', ['nda'])  # Default to NDA for backwards compatibility

        # Validate inputs
        if not company:
            return cors_response(400, {'error': 'Company name or number is required'})

        if not signatory_name:
            return cors_response(400, {'error': 'Signatory name is required'})

        if not signatory_title:
            return cors_response(400, {'error': 'Signatory title is required'})

        if not document_types or len(document_types) == 0:
            return cors_response(400, {'error': 'At least one document type must be specified'})

        # Build prompt for Jamie 2.0 based on document types
        doc_names = []
        if 'nda' in document_types:
            doc_names.append('NDA')
        if 'msa' in document_types:
            doc_names.append('MSA')

        if len(doc_names) > 1:
            prompt = f"I need both an {' and '.join(doc_names)} for {company}, signatory {signatory_name}, {signatory_title}"
        else:
            prompt = f"I need an {doc_names[0]} for {company}, signatory {signatory_name}, {signatory_title}"

        print(f"Invoking Bedrock Agent with prompt: {prompt}")

        # Invoke Bedrock Agent
        session_id = str(uuid.uuid4())
        response = bedrock_agent_runtime.invoke_agent(
            agentId=AGENT_ID,
            agentAliasId=AGENT_ALIAS_ID,
            sessionId=session_id,
            inputText=prompt,
            enableTrace=True  # Need traces to extract structured data
        )

        # Process streaming response
        event_stream = response['completion']
        full_response = ""
        documents = []  # Collect all documents (NDA and/or MSA)
        company_details = None
        expected_doc_count = len(document_types)  # How many documents we're expecting

        for event in event_stream:
            print(f"Event keys: {event.keys()}")

            if 'chunk' in event:
                chunk = event['chunk']
                if 'bytes' in chunk:
                    chunk_text = chunk['bytes'].decode('utf-8')
                    full_response += chunk_text
                    print(f"Chunk text: {chunk_text[:200]}")

            elif 'trace' in event:
                trace = event['trace']
                print(f"Trace keys: {trace.keys()}")

                # Extract document generation result from trace
                trace_str = str(trace)
                if 'download_url' in trace_str:
                    print("Found download_url in trace")
                    # Parse the trace to extract structured data
                    if 'trace' in trace:
                        print(f"Inner trace keys: {trace['trace'].keys()}")
                        if 'orchestrationTrace' in trace.get('trace', {}):
                            orch = trace['trace']['orchestrationTrace']
                            print(f"Orchestration trace keys: {orch.keys()}")
                            if 'observation' in orch:
                                obs = orch['observation']
                                print(f"Observation keys: {obs.keys()}")
                                if 'actionGroupInvocationOutput' in obs:
                                    output = obs['actionGroupInvocationOutput']
                                    print(f"Action output keys: {output.keys()}")
                                    if 'text' in output:
                                        print(f"Action output text: {output['text'][:500]}")
                                        try:
                                            doc_data = json.loads(output['text'])
                                            print(f"Parsed document data successfully")
                                            if doc_data.get('success'):
                                                # Determine document type from s3_key
                                                s3_key = doc_data.get('s3_key', '')
                                                doc_type = 'nda' if 'nda' in s3_key.lower() else 'msa'

                                                documents.append({
                                                    'type': doc_type,
                                                    'download_url': doc_data.get('download_url'),
                                                    's3_key': s3_key
                                                })
                                                print(f"Collected {len(documents)}/{expected_doc_count} documents")

                                                # Save company details from first document
                                                if not company_details:
                                                    company_details = doc_data.get('company_details', {})

                                                # Early exit: Return immediately once we have all expected documents
                                                # This prevents API Gateway 30-second timeout
                                                if len(documents) >= expected_doc_count:
                                                    print(f"All {expected_doc_count} documents collected, returning early")
                                                    response_data = {
                                                        'success': True,
                                                        'message': f"Successfully generated {len(documents)} document(s)",
                                                        'company': company_details or {},
                                                        'documents': documents,
                                                        'expires_in': '1 hour'
                                                    }
                                                    return cors_response(200, response_data)
                                        except Exception as e:
                                            print(f"Failed to parse document data: {e}")

        # Return response
        print(f"Documents collected: {len(documents)}")
        print(f"Documents: {documents}")
        if documents and len(documents) > 0:
            response_data = {
                'success': True,
                'message': full_response,
                'company': company_details or {},
                'documents': documents,
                'expires_in': '1 hour'
            }
            print(f"Returning success response with {len(documents)} documents")
            return cors_response(200, response_data)
        else:
            # Even if we couldn't parse structured data, return the text response
            print("No documents collected, returning fallback response")
            return cors_response(200, {
                'success': True,
                'message': full_response,
                'note': 'Documents generated but structured data not available. Check CloudWatch logs.'
            })

    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()

        return cors_response(500, {
            'error': str(e),
            'message': 'Failed to generate NDA'
        })


def cors_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Build response with CORS headers"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',  # Will restrict this to CloudFront domain later
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'POST,OPTIONS'
        },
        'body': json.dumps(body)
    }
