#!/usr/bin/env bash
set -euo pipefail

SERVER="10.117.66.20"
PORT="3200"
APP_NAME="test_dockploy-2"

echo "=== Deploying ${APP_NAME} to ${SERVER}:${PORT} ==="

# 1. Build image locally
echo "[1/4] Building Docker image..."
docker build -t ${APP_NAME}:latest .

# 2. Tag image for remote registry (optional)
# docker tag ${APP_NAME}:latest ${SERVER}:5000/${APP_NAME}:latest

# 3. Copy files to remote server
echo "[2/4] Copying deployment files to ${SERVER}..."
scp -r ./* root@${SERVER}:/opt/${APP_NAME}/ 2>/dev/null || \
    scp -r ./* ebissamideksa@${SERVER}:/home/ebissamideksa/${APP_NAME}/

# 4. Run deployment on remote server
echo "[3/4] Running deployment on ${SERVER}..."
ssh root@${SERVER} "cd /opt/${APP_NAME} && docker-compose down && docker-compose up -d --build" 2>/dev/null || \
    ssh ebissamideksa@${SERVER} "cd ~/${APP_NAME} && docker-compose down && docker-compose up -d --build"

# 5. Verify
echo "[4/4] Verifying deployment..."
curl -f http://${SERVER}:${PORT}/healthz && echo " - Deployment successful!" || echo " - Health check failed."

echo "=== Deployment complete: http://${SERVER}:${PORT} ==="