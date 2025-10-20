#!/usr/bin/env python3
"""
Jamie 2.0 CLI - Generate Sales Proposals Locally

Usage:
    python3 jamie-cli.py "Your prompt here"
    python3 jamie-cli.py --file prompt.txt
    python3 jamie-cli.py --interactive
    python3 jamie-cli.py "Your prompt" --format pptx -o output.pptx
"""

import boto3
import json
import sys
import argparse
import subprocess
import os
from datetime import datetime

# Configuration
AWS_PROFILE = 'AdministratorAccess-380414079195'
AWS_REGION = 'eu-west-2'
AGENT_ID = 'LUZWQYYBP4'
AGENT_ALIAS_ID = '65PC3XRFMX'  # Note: Update if you changed the alias in console


def invoke_jamie(prompt: str, output_file: str = None, verbose: bool = False):
    """Invoke Jamie 2.0 with a prompt"""

    # Initialize client
    session = boto3.Session(profile_name=AWS_PROFILE, region_name=AWS_REGION)
    client = session.client('bedrock-agent-runtime')

    session_id = f'jamie-{int(datetime.now().timestamp())}'

    if verbose:
        print(f"🤖 Invoking Jamie 2.0...")
        print(f"📝 Session ID: {session_id}")
        print("=" * 80)

    try:
        # Invoke the agent
        response = client.invoke_agent(
            agentId=AGENT_ID,
            agentAliasId=AGENT_ALIAS_ID,
            sessionId=session_id,
            inputText=prompt
        )

        # Process streaming response
        event_stream = response['completion']
        full_response = ""

        for event in event_stream:
            if 'chunk' in event:
                chunk = event['chunk']
                if 'bytes' in chunk:
                    text = chunk['bytes'].decode('utf-8')
                    full_response += text
                    if verbose:
                        print(text, end='', flush=True)
            elif 'trace' in event and verbose:
                trace = event['trace']['trace']
                if 'orchestrationTrace' in trace:
                    orch = trace['orchestrationTrace']
                    if 'observation' in orch:
                        print(f"\n\n[🔍 Jamie is searching proposals...]\n", flush=True)

        if verbose:
            print("\n" + "=" * 80)

        # Save to file if specified
        if output_file:
            with open(output_file, 'w') as f:
                f.write(full_response)
            if verbose:
                print(f"✅ Saved to: {output_file}")

        return full_response

    except Exception as e:
        print(f"❌ Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


def interactive_mode():
    """Run Jamie in interactive mode"""
    print("🤖 Jamie 2.0 Interactive Mode")
    print("=" * 80)
    print("Type your prompts below. Type 'exit' or 'quit' to exit.")
    print("Type 'save' to save the last response to a file.")
    print("=" * 80)

    last_response = None

    while True:
        try:
            prompt = input("\n💬 You: ").strip()

            if prompt.lower() in ['exit', 'quit']:
                print("👋 Goodbye!")
                break

            if prompt.lower() == 'save' and last_response:
                filename = input("📁 Filename: ").strip()
                with open(filename, 'w') as f:
                    f.write(last_response)
                print(f"✅ Saved to: {filename}")
                continue

            if not prompt:
                continue

            print("\n🤖 Jamie:")
            last_response = invoke_jamie(prompt, verbose=True)

        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break
        except EOFError:
            break


def main():
    parser = argparse.ArgumentParser(
        description='Jamie 2.0 - AI Sales Proposal Generator',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Direct prompt
  python3 jamie-cli.py "Create a proposal for Acme Corp cloud migration"

  # From file
  python3 jamie-cli.py --file requirements.txt --output proposal.txt

  # Interactive mode
  python3 jamie-cli.py --interactive
        """
    )

    parser.add_argument('prompt', nargs='?', help='Prompt for Jamie')
    parser.add_argument('-f', '--file', help='Read prompt from file')
    parser.add_argument('-o', '--output', help='Output file for response')
    parser.add_argument('-i', '--interactive', action='store_true', help='Interactive mode')
    parser.add_argument('-q', '--quiet', action='store_true', help='Quiet mode (no verbose output)')
    parser.add_argument('--format', choices=['txt', 'pptx'], default='txt', help='Output format (txt or pptx)')

    args = parser.parse_args()

    # Interactive mode
    if args.interactive:
        interactive_mode()
        return

    # Get prompt
    if args.file:
        with open(args.file, 'r') as f:
            prompt = f.read()
    elif args.prompt:
        prompt = args.prompt
    else:
        parser.print_help()
        sys.exit(1)

    # Check if output ends with .pptx (PowerPoint requested)
    if args.output and args.output.endswith('.pptx'):
        # Add instruction to Jamie's prompt to create presentation
        enhanced_prompt = f"{prompt}\n\nIMPORTANT: Create this as a PowerPoint presentation following the template structure."

        # Generate to temp text file first
        temp_output = args.output.replace('.pptx', '.txt')
        response = invoke_jamie(enhanced_prompt, temp_output, verbose=not args.quiet)

        # Convert to PowerPoint
        converter_script = os.path.join(os.path.dirname(__file__), 'proposal-to-pptx.py')

        if not args.quiet:
            print(f"\n🎨 Converting to PowerPoint...")

        subprocess.run([sys.executable, converter_script, temp_output, args.output], check=True)

        # Clean up temp file
        if os.path.exists(temp_output):
            os.remove(temp_output)
    else:
        # Regular text output
        response = invoke_jamie(prompt, args.output, verbose=not args.quiet)

        # Print response if not saved to file
        if not args.output and not args.quiet:
            print(response)


if __name__ == '__main__':
    main()
