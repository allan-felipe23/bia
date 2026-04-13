#!/bin/bash
set -e

ECR_REGISTRY="038304770060.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="bia"
CLUSTER="cluster-bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
REGION="us-east-1"

COMMIT_HASH=$(git rev-parse --short HEAD)
IMAGE_URI="$ECR_REGISTRY/$ECR_REPO:$COMMIT_HASH"

echo "==> Commit: $COMMIT_HASH"
echo "==> Imagem: $IMAGE_URI"

# Login ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build e push
docker build -t $ECR_REPO .
docker tag $ECR_REPO:latest $IMAGE_URI
docker tag $ECR_REPO:latest $ECR_REGISTRY/$ECR_REPO:latest
docker push $IMAGE_URI
docker push $ECR_REGISTRY/$ECR_REPO:latest

# Nova task definition com a imagem versionada
NEW_TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION \
  --query 'taskDefinition' --output json | \
  jq --arg IMAGE "$IMAGE_URI" \
    'del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy) |
     .containerDefinitions[0].image = $IMAGE')

NEW_REVISION=$(aws ecs register-task-definition --region $REGION \
  --cli-input-json "$NEW_TASK_DEF" \
  --query 'taskDefinition.taskDefinitionArn' --output text)

echo "==> Nova task definition: $NEW_REVISION"

# Atualiza o service
aws ecs update-service --cluster $CLUSTER --service $SERVICE \
  --task-definition $NEW_REVISION --region $REGION > /dev/null

echo "==> Deploy iniciado com $COMMIT_HASH"
