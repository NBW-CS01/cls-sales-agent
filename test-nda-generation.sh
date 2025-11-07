#!/bin/bash
# Quick NDA generation test script

set -e

AGENT_ID="LUZWQYYBP4"
AGENT_ALIAS_ID="TSTALIASID"
AWS_PROFILE="AdministratorAccess-380414079195"
AWS_REGION="eu-west-2"

echo "======================================================================"
echo "Testing Jamie 2.0 NDA Generation"
echo "======================================================================"
echo ""

# Get company name from user
if [ -z "$1" ]; then
  echo "Usage: ./test-nda-generation.sh \"Company Name\" \"Signatory Name\" \"Signatory Title\""
  echo ""
  echo "Example: ./test-nda-generation.sh \"Ravens of Ingatestone Limited\" \"John Smith\" \"Managing Director\""
  exit 1
fi

COMPANY="$1"
SIGNATORY_NAME="${2:-John Smith}"
SIGNATORY_TITLE="${3:-Director}"

echo "Company: $COMPANY"
echo "Signatory: $SIGNATORY_NAME ($SIGNATORY_TITLE)"
echo ""

python3 test_nda_generation.py
