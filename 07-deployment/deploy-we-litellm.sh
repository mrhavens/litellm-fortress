#!/bin/bash
#
# WE LiteLLM Deployment Script
# Deploys distributed LiteLLM across Racknerd and Witness-Zero
#
# Usage:
#   ./deploy-we-litellm.sh [racknerd|home|key|status]
#

set -e

# Configuration
NAMESPACE="ai-governance"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-we-master-key-change-me}"
DB_PASSWORD="${DB_PASSWORD:-YourSecurePassword123}"
RACKNERD_VPN_IP="${RACKNERD_VPN_IP:-100.110.108.11}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get kubeconfig based on target
get_kubeconfig() {
    local target=$1
    if [[ "$target" == "racknerd" ]]; then
        echo "root@100.110.108.11"
    else
        echo "root@100.82.185.34"  # witness-zero
    fi
}

# Deploy to Racknerd (Cloud - Master)
deploy_racknerd() {
    log_info "Deploying LiteLLM to Racknerd (Cloud)..."
    
    local host=$(get_kubeconfig racknerd)
    
    # Create namespace
    sshpass -p '2lpa6WEYlqFLN018k2' ssh -o StrictHostKeyChecking=no root@100.110.108.11 \
        "kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -"
    
    # Create secrets
    sshpass -p '2lpa6WEYlqFLN018k2' ssh -o StrictHostKeyChecking=no root@100.110.108.11 << EOF
kubectl create secret generic ai-creds \
  --namespace $NAMESPACE \
  --from-literal=db-password="$DB_PASSWORD" \
  --from-literal=master-key="$MASTER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
EOF
    
    # Deploy PostgreSQL
    sshpass -p '2lpa6WEYlqFLN018k2' ssh -o StrictHostKeyChecking=no root@100.110.108.11 << 'EOF'
kubectl apply -f - << 'YAML' -n ai-governance
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: litellm-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: litellm-db
  template:
    metadata:
      labels:
        app: litellm-db
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ai-creds
                  key: db-password
            - name: POSTGRES_DB
              value: litellm
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: pgdata
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: pgdata
          persistentVolumeClaim:
            claimName: litellm-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: litellm-db
spec:
  selector:
    app: litellm-db
  ports:
    - port: 5432
      targetPort: 5432
YAML
EOF
    
    # Deploy LiteLLM Proxy
    sshpass -p '2lpa6WEYlqFLN018k2' ssh -o StrictHostKeyChecking=no root@100.110.108.11 << EOF
kubectl apply -f - << 'YAML' -n ai-governance
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: litellm-proxy
  template:
    metadata:
      labels:
        app: litellm-proxy
    spec:
      containers:
        - name: litellm
          image: ghcr.io/berriai/litellm:main-latest
          env:
            - name: DATABASE_URL
              value: "postgresql://postgres:$DB_PASSWORD@litellm-db.ai-governance.svc:5432/litellm"
            - name: LITELLM_MASTER_KEY
              value: "$MASTER_KEY"
            - name: STORE_MODEL_IN_DB
              value: "true"
          ports:
            - containerPort: 4000
---
apiVersion: v1
kind: Service
metadata:
  name: litellm-proxy
spec:
  type: NodePort
  selector:
    app: litellm-proxy
  ports:
    - port: 4000
      targetPort: 4000
      nodePort: 30400
YAML
EOF
    
    log_info "Racknerd deployment complete!"
    log_info "Access at: http://100.110.108.11:30400"
}

# Deploy to Witness-Zero (Home)
deploy_home() {
    log_info "Deploying LiteLLM to Witness-Zero (Home)..."
    
    if [[ -z "$RACKNERD_VPN_IP" ]]; then
        log_error "RACKNERD_VPN_IP not set!"
        exit 1
    fi
    
    # Deploy LiteLLM with connection to Racknerd DB
    kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-witness-zero
  namespace: ai-governance
spec:
  replicas: 1
  selector:
    matchLabels:
      app: litellm-witness-zero
  template:
    metadata:
      labels:
        app: litellm-witness-zero
    spec:
      containers:
        - name: litellm
          image: ghcr.io/berriai/litellm:main-latest
          env:
            - name: DATABASE_URL
              value: "postgresql://postgres:$DB_PASSWORD@$RACKNERD_VPN_IP:5432/litellm"
            - name: LITELLM_MASTER_KEY
              value: "$MASTER_KEY"
            - name: STORE_MODEL_IN_DB
              value: "true"
          ports:
            - containerPort: 4000
---
apiVersion: v1
kind: Service
metadata:
  name: litellm-witness-zero
  namespace: ai-governance
spec:
  type: NodePort
  selector:
    app: litellm-witness-zero
  ports:
    - port: 4000
      targetPort: 4000
      nodePort: 30401
EOF
    
    log_info "Witness-Zero deployment complete!"
    log_info "Access at: http://localhost:30401"
}

# Generate API Key
generate_key() {
    local target=${1:-racknerd}
    local host
    
    if [[ "$target" == "racknerd" ]]; then
        host="100.110.108.11"
    else
        host="localhost"
    fi
    
    log_info "Generating API key on $target..."
    
    curl -s -X POST "http://$host:30400/key/generate" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $MASTER_KEY" \
        -d '{
            "key_alias": "solaria",
            "duration": "30d",
            "models": ["gpt-4o", "gemini/gemini-1.5-pro", "ollama/llama3.1"]
        }' | python3 -m json.tool
    
    log_info "Key generated! Use it to access LiteLLM from anywhere."
}

# Check status
check_status() {
    log_info "Checking LiteLLM status..."
    
    echo ""
    echo "=== Racknerd (Cloud) ==="
    sshpass -p '2lpa6WEYlqFLN018k2' ssh -o StrictHostKeyChecking=no root@100.110.108.11 \
        "kubectl get pods,svc -n $NAMESPACE -l app=litellm-proxy" 2>/dev/null || echo "Not deployed"
    
    echo ""
    echo "=== Witness-Zero (Home) ==="
    kubectl get pods,svc -n $NAMESPACE -l app=litellm-witness-zero 2>/dev/null || echo "Not deployed"
    
    echo ""
    echo "=== Health Check ==="
    curl -s http://100.110.108.11:30400/health 2>/dev/null | python3 -m json.tool || echo "Not responding"
}

# Main
case "${1:-}" in
    racknerd)
        deploy_racknerd
        ;;
    home)
        deploy_home
        ;;
    key)
        generate_key "${2:-racknerd}"
        ;;
    status)
        check_status
        ;;
    all)
        deploy_racknerd
        sleep 10
        deploy_home
        sleep 5
        generate_key racknerd
        ;;
    *)
        echo "WE LiteLLM Deployment Script"
        echo ""
        echo "Usage: $0 [racknerd|home|key|status|all]"
        echo ""
        echo "Commands:"
        echo "  racknerd  - Deploy to Racknerd (cloud/master)"
        echo "  home      - Deploy to Witness-Zero (home/worker)"
        echo "  key       - Generate API key (default: racknerd)"
        echo "  status    - Check deployment status"
        echo "  all       - Deploy everything"
        echo ""
        echo "Environment Variables:"
        echo "  RACKNERD_VPN_IP  - VPN IP of Racknerd (for home deployment)"
        echo "  DB_PASSWORD      - PostgreSQL password"
        echo "  LITELLM_MASTER_KEY - Master API key"
        exit 1
        ;;
esac
