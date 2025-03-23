#!/bin/bash
set -e

# Get the version from arguments or SSM parameter
VERSION=$1
if [ -z "$VERSION" ]; then
  VERSION=$(aws ssm get-parameter --name "/myapp/deployment/version" --query "Parameter.Value" --output text)
fi

echo "Starting deployment of version: $VERSION"

# Pull the Docker image
ECR_REPOSITORY="my-app-repo"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

echo "Pulling image: $ECR_REGISTRY/$ECR_REPOSITORY:$VERSION"
docker pull $ECR_REGISTRY/$ECR_REPOSITORY:$VERSION

# Stop the running container(s)
echo "Stopping existing containers..."
docker-compose -f /opt/deployment/docker-compose.yml down || true

# Update the docker-compose file with the new version
echo "Updating docker-compose configuration..."
sed -i "s|image: .*|image: $ECR_REGISTRY/$ECR_REPOSITORY:$VERSION|g" /opt/deployment/docker-compose.yml

# Start the updated container
echo "Starting new containers..."
docker-compose -f /opt/deployment/docker-compose.yml up -d

# Clean up old images
echo "Cleaning up old images..."
docker image prune -af

echo "Deployment completed successfully!"
