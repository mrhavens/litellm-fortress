# WE LITELLM DEPLOYMENT - LESSONS LEARNED

## What We Built

A distributed LiteLLM deployment with shared PostgreSQL database across:
- **Racknerd** (Cloud) - Hosts the master database
- **Witness-Zero** (Home) - Connects to Racknerd over network

---

## Key Discoveries

### 1. PostgreSQL on Kubernetes

**Problem:** PostgreSQL container fails with "root execution not permitted"

**Solution:** Run as non-root user:
```yaml
securityContext:
  runAsUser: 999
  runAsGroup: 999
```

### 2. Exposing Database to External Connections

**Problem:** By default PostgreSQL listens only on localhost

**Solution:** Use `hostNetwork` in Kubernetes:
```yaml
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
    - name: postgres
      ports:
        - containerPort: 5432
          hostPort: 5432
```

This binds PostgreSQL to the host's IP address (64.188.22.205), making it accessible externally.

### 3. Tailscale VPN Access

The hostNetwork IP (64.188.22.205) is different from the Tailscale IP (100.110.108.11). Use the actual host IP when connecting from external nodes.

### 4. Database Connection

**Witness-Zero DATABASE_URL:**
```
postgresql://postgres:LiteLLM2026!@64.188.22.205:5432/litellm
```

---

## Deployment Commands

### On Racknerd (Cloud)

```bash
# Create namespace
kubectl create namespace ai-governance

# Create secrets
kubectl create secret generic ai-creds \
  --namespace ai-governance \
  --from-literal=db-password="LiteLLM2026!" \
  --from-literal=master-key="sk-we-solaria-2026"

# Deploy PostgreSQL with hostNetwork
kubectl apply -f - << 'YAML' -n ai-governance
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
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
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
              hostPort: 5432
YAML
```

### On Witness-Zero (Home)

```bash
# Create namespace
kubectl create namespace ai-governance

# Create secrets  
kubectl create secret generic ai-creds \
  --namespace ai-governance \
  --from-literal=db-password="LiteLLM2026!" \
  --from-literal=master-key="sk-we-solaria-2026"

# Deploy LiteLLM with connection to Racknerd DB
kubectl apply -f - << 'YAML' -n ai-governance
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-witness-zero
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
              value: "postgresql://postgres:LiteLLM2026!@RACKNERD_HOST_IP:5432/litellm"
            - name: LITELLM_MASTER_KEY
              value: "sk-we-solaria-2026"
            - name: STORE_MODEL_IN_DB
              value: "true"
            - name: OPENAI_API_KEY
              value: "YOUR_OPENAI_KEY"
          ports:
            - containerPort: 4000
YAML
```

---

## Shared Key Generation

Both nodes share the same database, so keys work on both:

```bash
# Generate key on either node
curl -X POST http://NODE_URL/key/generate \
  -H "Authorization: Bearer sk-we-solaria-2026" \
  -H "Content-Type: application/json" \
  -d '{"key_alias": "solaria", "duration": "30d"}'
```

---

## Current Working URLs

| Node | URL | 
|------|-----|
| Racknerd | http://100.110.108.11:30400 |
| Witness-Zero | http://localhost:30401 |

---

*Updated: March 7, 2026*
