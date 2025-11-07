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

        # Validate inputs
        if not company:
            return cors_response(400, {'error': 'Company name or number is required'})

        if not signatory_name:
            return cors_response(400, {'error': 'Signatory name is required'})

        if not signatory_title:
            return cors_response(400, {'error': 'Signatory title is required'})

        # Build prompt for Jamie 2.0
        prompt = f"I need an NDA for {company}, signatory {signatory_name}, {signatory_title}"

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
        nda_data = None

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

                # Extract NDA generation result from trace
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
                                            nda_data = json.loads(output['text'])
                                            print(f"Parsed NDA data successfully")
                                        except Exception as e:
                                            print(f"Failed to parse NDA data: {e}")

        # Return response
        if nda_data and nda_data.get('success'):
            return cors_response(200, {
                'success': True,
                'message': full_response,
                'company': nda_data.get('company_details', {}),
                'download_url': nda_data.get('download_url'),
                's3_key': nda_data.get('s3_key'),
                'expires_in': nda_data.get('expires_in', '1 hour')
            })
        else:
            # Even if we couldn't parse structured data, return the text response
            return cors_response(200, {
                'success': True,
                'message': full_response,
                'note': 'NDA generated but structured data not available. Check CloudWatch logs.'
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
