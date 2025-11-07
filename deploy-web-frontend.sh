#!/bin/bash
# Deploy Jamie NDA Web Frontend
# This script deploys the infrastructure and configures the web app

set -e

PROFILE="AdministratorAccess-380414079195"
REGION="eu-west-2"

echo "======================================================================="
echo "Deploying Jamie NDA Web Frontend"
echo "======================================================================="
echo ""

# Step 1: Build Lambda package
echo "📦 Building API Handler Lambda package..."
cd lambda
chmod +x build-api-handler.sh
./build-api-handler.sh
cd ..

# Step 2: Terraform apply
echo ""
echo "🏗️  Deploying infrastructure with Terraform..."
cd terraform

terraform plan -out=tfplan
echo ""
read -p "Review the plan above. Continue with deployment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 1
fi

terraform apply tfplan

# Step 3: Get outputs
echo ""
echo "📊 Retrieving deployment outputs..."
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_client_id)
API_ENDPOINT=$(terraform output -raw api_endpoint)
WEB_BUCKET=$(terraform output -raw web_bucket)
CLOUDFRONT_DOMAIN=$(terraform output -json web_app_url | jq -r | sed 's|https://||')
CLOUDFRONT_ID=$(aws cloudfront list-distributions \
    --profile $PROFILE \
    --region $REGION \
    --query "DistributionList.Items[?contains(Aliases.Items, '$CLOUDFRONT_DOMAIN') || contains(DomainName, '$CLOUDFRONT_DOMAIN')].Id | [0]" \
    --output text)

echo "User Pool ID: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo "API Endpoint: $API_ENDPOINT"
echo "Web Bucket: $WEB_BUCKET"
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"

# Step 4: Configure web app
echo ""
echo "⚙️  Configuring web application..."
cd ../web

# Create configured version
cp index.html index.html.configured

sed -i.bak "s|USER_POOL_ID_PLACEHOLDER|$USER_POOL_ID|g" index.html.configured
sed -i.bak "s|CLIENT_ID_PLACEHOLDER|$CLIENT_ID|g" index.html.configured
sed -i.bak "s|API_ENDPOINT_PLACEHOLDER|$API_ENDPOINT/generate-nda|g" index.html.configured

rm -f index.html.configured.bak

# Step 5: Upload to S3
echo ""
echo "☁️  Uploading web app to S3..."
aws s3 cp index.html.configured s3://$WEB_BUCKET/index.html \
    --profile $PROFILE \
    --region $REGION \
    --content-type "text/html"

# Step 6: Invalidate CloudFront cache
if [ -n "$CLOUDFRONT_ID" ] && [ "$CLOUDFRONT_ID" != "None" ]; then
    echo ""
    echo "🔄 Invalidating CloudFront cache..."
    aws cloudfront create-invalidation \
        --distribution-id $CLOUDFRONT_ID \
        --paths "/*" \
        --profile $PROFILE \
        --region $REGION
fi

# Clean up
rm index.html.configured

cd ..

echo ""
echo "======================================================================="
echo "✅ Deployment Complete!"
echo "======================================================================="
echo ""
echo "🌐 Web App URL: https://$CLOUDFRONT_DOMAIN"
echo ""
echo "Next steps:"
echo "1. Create users with the commands shown in terraform output"
echo "2. Test login and NDA generation"
echo ""
echo "To create Patrick's user:"
echo ""
echo "aws cognito-idp admin-create-user \\"
echo "  --user-pool-id $USER_POOL_ID \\"
echo "  --username patrick@cloudscaler.com \\"
echo "  --user-attributes Name=email,Value=patrick@cloudscaler.com Name=name,Value=\"Patrick Godden\" \\"
echo "  --profile $PROFILE"
echo ""
echo "Then set password:"
echo ""
echo "aws cognito-idp admin-set-user-password \\"
echo "  --user-pool-id $USER_POOL_ID \\"
echo "  --username patrick@cloudscaler.com \\"
echo "  --password \"YourSecurePassword123!\" \\"
echo "  --permanent \\"
echo "  --profile $PROFILE"
echo ""
