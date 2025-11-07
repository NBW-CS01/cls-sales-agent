#!/bin/bash
# Build Lambda deployment package for NDA API Handler

set -e

echo "Building Lambda deployment package for NDA API Handler..."

cd "$(dirname "$0")"

# Clean previous build
rm -f nda_api_handler.zip

# Create deployment package (no dependencies needed - only boto3 which is built-in)
echo "Creating deployment package..."
zip nda_api_handler.zip nda_api_handler.py

# Move to terraform directory
mv nda_api_handler.zip ../terraform/

echo "✓ Lambda deployment package created: ../terraform/nda_api_handler.zip"
