#!/bin/bash
# Build Lambda deployment package with dependencies for MSA generator

set -e

echo "Building Lambda deployment package for MSA generator..."

# Clean previous build
rm -rf package
rm -f msa_generator.zip

# Create package directory
mkdir -p package

# Install dependencies
echo "Installing dependencies..."
pip3 install \
  --target ./package \
  --platform manylinux2014_x86_64 \
  --python-version 3.12 \
  --only-binary=:all: \
  python-docx==1.1.2 \
  requests==2.31.0 \
  lxml==5.3.0

# Copy Lambda function code
echo "Copying Lambda function code..."
cp msa_generator.py package/
cp companies_house.py package/

# Create deployment package
echo "Creating deployment package..."
cd package
zip -r ../msa_generator.zip . -x "*.pyc" -x "*__pycache__*"
cd ..

# Move to terraform directory
mv msa_generator.zip ../terraform/

echo "✓ Lambda deployment package created: ../terraform/msa_generator.zip"
echo "✓ Package includes dependencies: python-docx, requests, lxml"

# Clean up
rm -rf package

echo ""
echo "Next step: Run 'terraform apply' to deploy the updated Lambda function"
