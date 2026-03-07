# LITELLM OVERVIEW

## What is LiteLLM?

LiteLLM is a unified interface that provides:
- **Python SDK** - Call 100+ LLMs with OpenAI-compatible format
- **Proxy Server** - AI Gateway for centralized LLM access
- **Router** - Load balancing and automatic failover
- **Callbacks** - Observability and cost tracking

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Your Application                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      LiteLLM (SDK or Proxy)                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │
│  │   Router    │  │  Callbacks  │  │  Cost Tracking  │   │
│  │ (failover)  │  │  (logging)  │  │   (monitoring)  │   │
│  └─────────────┘  └─────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
    ┌──────────┐       ┌──────────┐       ┌──────────┐
    │ OpenAI   │       │ Anthropic│       │  Azure   │
    │   GPT-4  │       │ Claude   │       │   GPT-4  │
    └──────────┘       └──────────┘       └──────────┘
```

---

## Key Concepts

### 1. Model String Format

LiteLLM uses `provider/model` format:

```python
"openai/gpt-4o"           # OpenAI
"anthropic/claude-3-sonnet"  # Anthropic
"azure/gpt-4"             # Azure OpenAI
"ollama/llama2"           # Ollama
"bedrock/claude-3-sonnet"  # AWS Bedrock
```

### 2. Environment Variables

Each provider needs its API key:

```bash
# OpenAI
OPENAI_API_KEY=sk-...

# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Azure
AZURE_API_KEY=...
AZURE_API_BASE=https://your-resource.openai.azure.com/
AZURE_API_VERSION=2024-02-15-preview

# Ollama (local)
OLLAMA_BASE_URL=http://localhost:11434
```

### 3. Completion Response

Standard OpenAI-style response:

```python
response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello"}]
)

# Access response
response.choices[0].message.content
response.usage.total_tokens
response.model  # "gpt-4o"
```

---

## Installation

```bash
# Python SDK only
pip install litellm

# With proxy
pip install 'litellm[proxy]'

# With all dependencies
pip install 'litellm[all]'
```

---

## Quick Start

### Simple Completion

```python
from litellm import completion

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Say hello!"}]
)

print(response.choices[0].message.content)
```

### Using Environment Variables

```python
import os
from litellm import completion

os.environ["OPENAI_API_KEY"] = "sk-..."

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Say hello!"}]
)
```

---

## Two Ways to Use

### 1. Python SDK (Direct)

Best for: Application-level integration

```python
from litellm import completion

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### 2. Proxy Server

Best for: Infrastructure-level access, shared API keys, rate limiting

```bash
# Start proxy
litellm --model gpt-4o

# Use like OpenAI
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hello"}]}'
```

---

## Features

| Feature | Description |
|---------|-------------|
| **100+ Providers** | Unified API for all major LLM providers |
| **Router** | Automatic failover and load balancing |
| **Cost Tracking** | Per-request cost calculation |
| **Guardrails** | Input/output validation |
| **Caching** | Reduce costs with Redis caching |
| **Virtual Keys** | API key management for multi-tenant |
| **Observability** | Callbacks for Langfuse, Lunary, etc. |

---

## When to Use What?

| Use Case | Solution |
|----------|----------|
| Single app, direct calls | Python SDK |
| Multiple apps, shared access | Proxy Server |
| Need failover | Router |
| Track spending | Cost tracking + callbacks |
| Multi-tenant | Proxy with virtual keys |

---

*This overview is part of the LiteLLM Fortress.*
