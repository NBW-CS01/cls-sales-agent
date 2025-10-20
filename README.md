# Jamie 2.0 - AI Sales Proposal Assistant

## Overview
Jamie 2.0 is a Bedrock-powered AI assistant that generates sales proposals and statements of work in Jamie's writing style.

## Architecture

### Components
- **Amazon Bedrock Agent**: Claude LLM configured with Jamie's persona
- **Knowledge Base**: S3-backed vector store containing:
  - Historical proposals
  - Statements of Work (SOWs)
  - Company capabilities
  - Case studies
- **Input**: Pre-sales requirements from Patrick/Sharona/architects
- **Output**: Proposals written in Jamie's style

### Infrastructure
- Bedrock Agent with Claude 3.5 Sonnet
- S3 bucket for knowledge base documents
- Bedrock Knowledge Base (manages vector embeddings automatically)
- Lambda function for agent orchestration

## Knowledge Base Structure

```
s3://jamie-knowledge-base/
├── proposals/          # Past proposals Jamie has written
├── sows/              # Statements of work
├── capabilities/      # Company services and offerings
└── case-studies/      # Success stories and references
```

## Jamie's Writing Style

See `jamie-persona.md` for the detailed style guide that defines:
- Tone and voice
- Structure preferences
- Technical depth
- Language patterns
- Formatting conventions

## Usage Flow

1. Patrick/Sharona provides pre-sales context (customer needs, scope, requirements)
2. Jamie 2.0 searches knowledge base for relevant proposals/SOWs
3. Claude generates new proposal in Jamie's style
4. Output can be refined through iteration

## Future Enhancements
- Web UI for easy interaction
- Voice dictation input (Amazon Transcribe integration)
- Multi-language support
- Version control for proposals
