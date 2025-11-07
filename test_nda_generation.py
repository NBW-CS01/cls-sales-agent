#!/usr/bin/env python3
"""
Test NDA Generation for Ravens of Ingatestone Limited
Invokes Jamie 2.0 Bedrock Agent to generate an NDA
"""

import boto3
import json
import sys

# Configuration
AGENT_ID = "LUZWQYYBP4"
AGENT_ALIAS_ID = "TSTALIASID"  # Use DRAFT version with updated instructions
AWS_PROFILE = "AdministratorAccess-380414079195"
AWS_REGION = "eu-west-2"

print("=" * 70)
print("Testing NDA Generation for Ravens of Ingatestone Limited")
print("=" * 70)
print()
print(f"Agent ID: {AGENT_ID}")
print(f"Agent Alias: {AGENT_ALIAS_ID}")
print()

# Create boto3 session
session = boto3.Session(
    profile_name=AWS_PROFILE,
    region_name=AWS_REGION
)

# Create Bedrock Agent Runtime client
client = session.client('bedrock-agent-runtime')

# Test input
input_text = "I need an NDA for Ravens of Ingatestone Limited, signatory John Smith, Managing Director"

print(f"Prompt: {input_text}")
print()
print("Sending request to Jamie 2.0...")
print()

try:
    # Invoke the agent
    response = client.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=AGENT_ALIAS_ID,
        sessionId='test-session-ravens',
        inputText=input_text,
        enableTrace=True
    )

    print("=" * 70)
    print("Response from Jamie 2.0:")
    print("=" * 70)
    print()

    # Process the streaming response
    event_stream = response['completion']

    full_response = ""
    traces = []

    for event in event_stream:
        if 'chunk' in event:
            chunk = event['chunk']
            if 'bytes' in chunk:
                chunk_text = chunk['bytes'].decode('utf-8')
                full_response += chunk_text
                print(chunk_text, end='', flush=True)

        elif 'trace' in event:
            trace = event['trace']
            traces.append(trace)

            # Print trace info for debugging
            if 'trace' in trace:
                trace_data = trace['trace']
                if 'orchestrationTrace' in trace_data:
                    orch_trace = trace_data['orchestrationTrace']
                    if 'invocationInput' in orch_trace:
                        inv_input = orch_trace['invocationInput']
                        if 'actionGroupInvocationInput' in inv_input:
                            action_input = inv_input['actionGroupInvocationInput']
                            print(f"\n\n[Calling action: {action_input.get('actionGroupName', 'unknown')}]")
                            print(f"[Function: {action_input.get('function', 'unknown')}]")

    print()
    print()
    print("=" * 70)
    print("Test Complete!")
    print("=" * 70)
    print()

    # If traces contain NDA generation result, extract download URL
    print("Looking for NDA download link...")
    for trace in traces:
        # Convert trace to string without JSON serialization (to avoid datetime issues)
        trace_str = str(trace)
        if 'download_url' in trace_str or 's3_key' in trace_str or 's3://' in trace_str:
            print("\nNDA Generation Details:")
            print(trace_str)

except Exception as e:
    print(f"\n❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
