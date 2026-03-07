# LITELLM AUTOMATION

*Scripts and examples for automating LiteLLM*

---

## Python Automation Scripts

### Simple Client

```python
#!/usr/bin/env python3
"""
LiteLLM Simple Client
A copy-paste ready client for AI agents
"""

import os
from typing import List, Dict, Optional
from litellm import completion, acompletion

class LiteLLMClient:
    def __init__(
        self,
        model: str = "openai/gpt-4o",
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        timeout: int = 60
    ):
        self.model = model
        self.timeout = timeout
        
        if api_key:
            os.environ["OPENAI_API_KEY"] = api_key
        if base_url:
            os.environ["OPENAI_BASE_URL"] = base_url
    
    def chat(self, message: str, system: Optional[str] = None) -> str:
        """Send a single message and get response"""
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": message})
        
        response = completion(
            model=self.model,
            messages=messages,
            timeout=self.timeout
        )
        
        return response.choices[0].message.content
    
    async def achat(self, message: str, system: Optional[str] = None) -> str:
        """Async version of chat"""
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": message})
        
        response = await acompletion(
            model=self.model,
            messages=messages,
            timeout=self.timeout
        )
        
        return response.choices[0].message.content
    
    def chat_stream(self, message: str):
        """Stream response"""
        response = completion(
            model=self.model,
            messages=[{"role": "user", "content": message}],
            stream=True
        )
        
        for chunk in response:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content


# Usage Examples
if __name__ == "__main__":
    # Simple usage
    client = LiteLLMClient(model="openai/gpt-4o")
    response = client.chat("Hello!")
    print(response)
    
    # With system prompt
    client = LiteLLMClient(
        model="openai/gpt-4o",
        system="You are a helpful coding assistant."
    )
    response = client.chat("How do I print in Python?")
    print(response)
    
    # Streaming
    for chunk in client.chat_stream("Count to 5"):
        print(chunk, end="")
```

---

### Multi-Provider Router

```python
#!/usr/bin/env python3
"""
LiteLLM Router with Fallback
Automatically switches providers on failure
"""

import os
from litellm import Router

# Configure providers
model_list = [
    {
        "model_name": "primary",
        "litellm_params": {
            "model": "openai/gpt-4o",
            "api_key": os.getenv("OPENAI_API_KEY")
        }
    },
    {
        "model_name": "fallback-anthropic",
        "litellm_params": {
            "model": "anthropic/claude-3-sonnet-20240229",
            "api_key": os.getenv("ANTHROPIC_API_KEY")
        }
    },
    {
        "model_name": "fallback-azure",
        "litellm_params": {
            "model": "azure/gpt-4",
            "api_base": os.getenv("AZURE_API_BASE"),
            "api_key": os.getenv("AZURE_API_KEY")
        }
    }
]

router = Router(
    model_list=model_list,
    retry_policy={
        "primary": {
            "num_retries": 3,
            "timeout": 30
        }
    }
)

def query_llm(prompt: str) -> str:
    """Query with automatic fallback"""
    try:
        response = router.completion(
            model="primary",
            messages=[{"role": "user", "content": prompt}]
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"All providers failed: {e}")
        raise

# Usage
if __name__ == "__main__":
    response = query_llm("Hello, world!")
    print(response)
```

---

### Cost Tracker

```python
#!/usr/bin/env python3
"""
LiteLLM Cost Tracker
Track spending across requests
"""

from typing import Dict, List
from litellm import completion

class CostTracker:
    def __init__(self):
        self.costs: List[Dict] = []
    
    def track(self, response, model: str):
        """Track cost of a response"""
        try:
            # LiteLLM stores cost in _hidden_params
            cost = response._response_msgs[0]._hidden_params.get('cost', 0)
            self.costs.append({
                "model": model,
                "cost": cost
            })
        except:
            pass
    
    def total(self) -> float:
        """Get total cost"""
        return sum(c["cost"] for c in self.costs)
    
    def report(self) -> Dict:
        """Get cost report"""
        by_model = {}
        for c in self.costs:
            model = c["model"]
            by_model[model] = by_model.get(model, 0) + c["cost"]
        
        return {
            "total": self.total(),
            "by_model": by_model
        }

# Usage
tracker = CostTracker()

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello"}],
    callbacks=[lambda resp: tracker.track(resp, "gpt-4o")]
)

print(f"Cost: ${tracker.total():.4f}")
print(f"Report: {tracker.report()}")
```

---

## Shell Scripts

### Quick Test

```bash
#!/bin/bash
# litellm-test.sh - Test LiteLLM installation

export OPENAI_API_KEY="${OPENAI_API_KEY:-test}"

python3 -c "
from litellm import completion
response = completion(
    model='gpt-4o',
    messages=[{'role': 'user', 'content': 'Say OK if you work'}]
)
print(response.choices[0].message.content)
"
```

---

## Kubernetes Deployment

### deployment.yaml

```yaml
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
        image: ghcr.io/berriai/litellm:main
        ports:
        - containerPort: 4000
        env:
        - name: DATABASE_URL
          value: "postgresql://postgres:password@postgres:5432/litellm"
        - name: LITELLM_MASTER_KEY
          value: "your-secure-key"
        - name: STORE_MODEL_IN_DB
          value: "true"
        volumeMounts:
        - name: config
          mountPath: /app/config.yaml
          subPath: config.yaml
      volumes:
      - name: config
        configMap:
          name: litellm-config
---
apiVersion: v1
kind: Service
metadata:
  name: litellm-proxy
spec:
  selector:
    app: litellm-proxy
  ports:
  - port: 80
    targetPort: 4000
```

---

*These automation examples are part of the LiteLLM Fortress.*
