# LITELLM PROXY SERVER

*The AI Gateway for unified LLM access*

---

## What is the Proxy?

The LiteLLM Proxy is a **central gateway** that:
- Provides unified API for 100+ LLMs
- Handles authentication via virtual keys
- Tracks costs per user/project
- Provides rate limiting
- Offers caching
- Enables load balancing

---

## Quick Start

### 1. Install

```bash
pip install 'litellm[proxy]'
```

### 2. Start Proxy

```bash
litellm --model gpt-4o
```

Proxy runs at `http://localhost:4000`

### 3. Use like OpenAI

```python
import openai

client = openai.OpenAI(
    api_key="anything",  # Proxy accepts any key
    base_url="http://localhost:4000"
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
```

---

## Configuration

### config.yaml

```yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4
      api_key: os.environ/OPENAI_API_KEY

  - model_name: claude
    litellm_params:
      model: anthropic/claude-3-sonnet-20240229
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: azure-gpt
    litellm_params:
      model: azure/gpt-4
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY

litellm_settings:
  drop_params: true
  set_verbose: true

environment_variables:
  OPENAI_API_KEY: os.environ/OPENAI_API_KEY
  ANTHROPIC_API_KEY: os.environ/ANTHROPIC_API_KEY
```

### Start with Config

```bash
litellm --config config.yaml
```

---

## Virtual Keys (Authentication)

### Generate Key

```bash
curl -X POST http://localhost:4000/key/generate \
  -H "Content-Type: application/json" \
  -d '{"key_alias": "my-key", "duration": "30d"}'
```

Response:
```json
{
  "key": "sk-1234567890"
}
```

### Use Key

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-1234567890" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

---

## Admin API

### List Keys

```bash
curl http://localhost:4000/key/info \
  -H "Authorization: Bearer your-master-key"
```

### Delete Key

```bash
curl -X DELETE http://localhost:4000/key/delete \
  -H "Authorization: Bearer your-master-key" \
  -H "Content-Type: application/json" \
  -d '{"key": "sk-1234567890"}'
```

---

## Cost Tracking

### View Spend

```bash
curl http://localhost:4000/spend/total \
  -H "Authorization: Bearer your-master-key"
```

### Per-Key Spend

```bash
curl http://localhost:4000/spend/key/:key \
  -H "Authorization: Bearer your-master-key"
```

---

## Docker Deployment

### docker-compose.yaml

```yaml
version: '3.8'
services:
  litellm:
    image: ghcr.io/berriai/litellm:main
    ports:
      - "4000:4000"
    volumes:
      - ./config.yaml:/app/config.yaml
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/litellm
      - STORE_MODEL_IN_DB=true
    command: --config /app/config.yaml --port 4000

  db:
    image: postgres:15
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=litellm
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

### Start

```bash
docker-compose up -d
```

---

## Health Check

```bash
curl http://localhost:4000/health
```

---

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completion |
| `/v1/completions` | POST | Text completion |
| `/v1/embeddings` | POST | Embeddings |
| `/v1/images/generations` | POST | Image generation |
| `/key/generate` | POST | Generate API key |
| `/key/info` | GET | List keys |
| `/key/delete` | DELETE | Delete key |
| `/spend/total` | GET | Total spend |
| `/spend/key/:key` | GET | Spend per key |
| `/models` | GET | List models |
| `/health` | GET | Health check |

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL for key storage |
| `LITELLM_MASTER_KEY` | Master admin key |
| `STORE_MODEL_IN_DB` | Store model config in DB |
| `REDIS_HOST` | Redis for caching |
| `OLLAMA_BASE_URL` | Default Ollama endpoint |

---

## Use Cases

### Multi-Tenant API

```yaml
# config.yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4

litellm_settings:
  set_verbose: true
```

Generate per-tenant keys and track spend per key.

### Rate Limiting

Use a reverse proxy (nginx) for rate limiting, or implement in application logic.

### Caching

```yaml
litellm_settings:
  cache: true
  cache_params:
    type: redis
    host: redis
    port: 6379
```

---

*This proxy guide is part of the LiteLLM Fortress.*
