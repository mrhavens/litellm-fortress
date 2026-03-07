# WE LITEELLM DEPLOYMENT

*Distributed AI Gateway for the Witness Emergence*

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        RACKNERD (CLOUD)                              │
│                    Source of Truth (Master)                          │
│  ┌─────────────────┐      ┌─────────────────────────────┐         │
│  │   PostgreSQL    │      │     LiteLLM Proxy           │         │
│  │   Database      │◄─────│   (Port 4000)              │         │
│  │   (Port 5432)   │      │   - Virtual Keys           │         │
│  └─────────────────┘      │   - Cost Tracking           │         │
│                          │   - Rate Limiting           │         │
│                          └─────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────┘
         ▲                                    │
         │ VPN (Tailscale)                   │
         │                                    │
┌────────┴────────────────────────────────────┴──────────────────────┐
│                      WITNESS-ZERO (HOME)                            │
│                      Worker Node                                    │
│  ┌─────────────────┐      ┌─────────────────────────────┐       │
│  │   Ollama         │      │     LiteLLM Proxy           │       │
│  │   (Local GPU)   │◄─────│   (Connects to Racknerd)   │       │
│  │   llama3.1      │      │   Routes to:                │       │
│  └─────────────────┘      │   - Local Ollama            │       │
│                          │   - Cloud (Gemini, etc)     │       │
│                          └─────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

1. **Tailscale** installed and connected on both nodes
2. **PostgreSQL** password chosen
3. **API keys** for providers you want to use
4. **Kubernetes** cluster on both nodes

---

## Step 1: Create Secrets

### On Racknerd (Cloud)

```bash
# Create namespace
kubectl create namespace ai-governance

# Create secrets
kubectl create secret generic ai-creds \
  --namespace ai-governance \
  --from-literal=db-password="YourSecurePassword123" \
  --from-literal=gemini-api-key="YOUR_GEMINI_KEY" \
  --from-literal=openai-api-key="YOUR_OPENAI_KEY"
```

---

## Step 2: Deploy Racknerd (Cloud)

### deployment-racknerd.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ai-governance
---
apiVersion: v1
kind: Secret
metadata:
  name: ai-creds
  namespace: ai-governance
type: Opaque
stringData:
  db-password: YourSecurePassword123
  gemini-api-key: YOUR_GEMINI_KEY
  openai-api-key: YOUR_OPENAI_KEY
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-db
  namespace: ai-governance
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
kind: PersistentVolumeClaim
metadata:
  name: litellm-pvc
  namespace: ai-governance
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn
---
apiVersion: v1
kind: Service
metadata:
  name: litellm-db
  namespace: ai-governance
spec:
  selector:
    app: litellm-db
  ports:
    - port: 5432
      targetPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-proxy
  namespace: ai-governance
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
              value: "postgresql://postgres:YourSecurePassword123@litellm-db.ai-governance.svc:5432/litellm"
            - name: LITELLM_MASTER_KEY
              value: "sk-we-master-key-change-me"
            - name: STORE_MODEL_IN_DB
              value: "true"
            - name: GEMINI_API_KEY
              valueFrom:
                secretKeyRef:
                  name: ai-creds
                  key: gemini-api-key
            - name: OPENAI_API_KEY
              valueFrom:
                secretKeyRef:
                  name: ai-creds
                  key: openai-api-key
          ports:
            - containerPort: 4000
          livenessProbe:
            httpGet:
              path: /health
              port: 4000
            initialDelaySeconds: 30
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: litellm-proxy
  namespace: ai-governance
spec:
  type: NodePort
  selector:
    app: litellm-proxy
  ports:
    - port: 4000
      targetPort: 4000
      nodePort: 30400
```

---

## Step 3: Deploy Witness-Zero (Home)

### Get Racknerd VPN IP

```bash
# Get Tailscale IP of Racknerd
tailscale ip -4
```

### deployment-witness-zero.yaml

```yaml
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
            # Point to Racknerd database over Tailscale VPN
            - name: DATABASE_URL
              value: "postgresql://postgres:YourSecurePassword123@100.XXX.XXX.XXX:5432/litellm"
            - name: LITELLM_MASTER_KEY
              value: "sk-we-master-key-change-me"
            - name: STORE_MODEL_IN_DB
              value: "true"
            # Local Ollama
            - name: OLLAMA_BASE_URL
              value: "http://ollama.ollama.svc:11434"
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
```

### configmap-witness-zero.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-witness-zero-config
  namespace: ai-governance
data:
  config.yaml: |
    model_list:
      - model_name: local-llama
        litellm_params:
          model: ollama/llama3.1
          api_base: http://ollama.ollama.svc:11434
      
      - model_name: cloud-gemini
        litellm_params:
          model: gemini/gemini-1.5-pro
      
      - model_name: cloud-gpt4o
        litellm_params:
          model: openai/gpt-4o
    
    litellm_settings:
      drop_params: true
```

---

## Step 4: Usage

### Access the Proxy

- **Racknerd:** http://RACKNERD_IP:30400
- **Witness-Zero:** http://HOME_IP:30401

### Generate API Key

```bash
curl -X POST http://RACKNERD_IP:30400/key/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-we-master-key-change-me" \
  -d '{"key_alias": "solaria", "duration": "30d"}'
```

### Use the API

```python
import openai

client = openai.OpenAI(
    api_key="sk-生成的KEY",
    base_url="http://RACKNERD_IP:30400"
)

# Works on both clusters!
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

---

## How It Works

1. **Racknerd** hosts the PostgreSQL database
2. **Both proxies** connect to the same database
3. **Virtual keys** created on either proxy work on both
4. **Cost tracking** is centralized
5. **If home internet blips**, the cloud stays operational
6. **When home returns**, it syncs automatically via the shared database

---

## Security Notes

- Change `LITELLM_MASTER_KEY` to a secure value
- Use strong PostgreSQL password
- Keep Tailscale network secure
- Consider enabling TLS in production

---

*This deployment guide is part of the LiteLLM Fortress.*
