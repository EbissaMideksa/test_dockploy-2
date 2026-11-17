#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Blue/Green Deployment Script for test_dockploy-2
# Server: 10.117.66.20
# Blue: 3099 | Green: 3100
# Nginx: 80
# ============================================================

SERVER="10.117.66.20"
SSH_USER="root"
APP_NAME="test_dockploy-2"
PORT_BLUE="3099"
PORT_GREEN="3100"
REGISTRY="localhost:5000"
APP_DIR="/opt/${APP_NAME}"

# Determine which version is currently active
CURRENT_VERSION="blue"
if curl -sf "http://${SERVER}:80/healthz" | grep -q "green"; then
    CURRENT_VERSION="green"
fi

# Determine target version (switch to the other)
if [ "$CURRENT_VERSION" = "blue" ]; then
    TARGET_VERSION="green"
else
    TARGET_VERSION="blue"
fi

echo "=== Blue/Green Deployment ==="
echo "Current: ${CURRENT_VERSION}"
echo "Target:  ${TARGET_VERSION}"
echo "Server:  ${SERVER}"
echo "============================="

# 1. Build new image
echo "[1/6] Building Docker image..."
docker build -t ${APP_NAME}:${TARGET_VERSION}-latest .

# 2. Push to registry
echo "[2/6] Pushing to registry..."
docker tag ${APP_NAME}:${TARGET_VERSION}-latest ${REGISTRY}/${APP_NAME}:${TARGET_VERSION}-latest
docker push ${REGISTRY}/${APP_NAME}:${TARGET_VERSION}-latest

# 3. Copy files to remote server
echo "[3/6] Copying files to server..."
scp -r ./* ${SSH_USER}@${SERVER}:${APP_DIR}/

# 4. Deploy new version on remote server
echo "[4/6] Deploying ${TARGET_VERSION} version..."
ssh ${SSH_USER}@${SERVER} "bash -c '
    cd ${APP_DIR}
    
    # Pull latest image
    docker pull ${REGISTRY}/${APP_NAME}:${TARGET_VERSION}-latest
    
    # Stop existing target container if running
    if [ \"\$(docker ps -q -f name=${APP_NAME}-${TARGET_VERSION})\" ]; then
        docker stop ${APP_NAME}-${TARGET_VERSION}
        docker rm ${APP_NAME}-${TARGET_VERSION}
    fi
    
    # Start new version
    docker run -d --name ${APP_NAME}-${TARGET_VERSION} \\
        -p ${PORT_${TARGET_VERSION}}:3000 \\
        -e NODE_ENV=production \\
        -e PORT=3000 \\
        -e NEXT_PUBLIC_APP_URL=http://${SERVER}:${PORT_${TARGET_VERSION}} \\
        ${REGISTRY}/${APP_NAME}:${TARGET_VERSION}-latest
'"

# 5. Switch nginx traffic to new version
echo "[5/6] Switching nginx to ${TARGET_VERSION}..."
ssh ${SSH_USER}@${SERVER} "bash -c '
    # Update nginx config to point to target version
    sed -i \"s/proxy_pass http://blue;/proxy_pass http://${TARGET_VERSION};/g\" /opt/${APP_NAME}/nginx/nginx.conf
    sed -i \"s/upstream blue {/upstream ${TARGET_VERSION} {/g\" /opt/${APP_NAME}/nginx/nginx.conf
    sed -i \"s/server app-blue:3000;/server app-${TARGET_VERSION}:3000;/g\" /opt/${APP_NAME}/nginx/nginx.conf
    
    # Reload nginx
    docker kill -s HUP \$(cat /var/run/nginx.pid 2>/dev/null) 2>/dev/null || true
    docker restart ${APP_NAME}-nginx 2>/dev/null || true
'"

# 6. Verify deployment
echo "[6/6] Verifying deployment..."
sleep 3
if curl -sf "http://${SERVER}:80/healthz" > /dev/null; then
    echo "✅ Deployment successful!"
    echo "   ${TARGET_VERSION} version is now serving at http://${SERVER}:80"
else
    echo "❌ Health check failed"
    exit 1
fi

# Cleanup old version
echo "Cleaning up old ${CURRENT_VERSION} version..."
ssh ${SSH_USER}@${SERVER} "bash -c 'docker stop ${APP_NAME}-${CURRENT_VERSION} 2>/dev/null || true; docker rm ${APP_NAME}-${CURRENT_VERSION} 2>/dev/null || true'"

echo "=== Deployment complete ==="