# LITELLM PYTHON SDK

*Complete reference for LiteLLM SDK*

---

## Installation

```bash
pip install litellm

# With extras
pip install 'litellm[proxy]'
pip install 'litellm[all]'
```

---

## Basic Completion

### Simple Request

```python
from litellm import completion

response = completion(
    model="openai/gpt-4o",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)
```

### With System Message

```python
from litellm import completion

response = completion(
    model="openai/gpt-4o",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"}
    ]
)
```

### Streaming Response

```python
from litellm import completion

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Count to 5"}],
    stream=True
)

for chunk in response:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

---

## Async Completion

```python
import asyncio
from litellm import acompletion

async def main():
    response = await acompletion(
        model="openai/gpt-4o",
        messages=[{"role": "user", "content": "Hello!"}]
    )
    print(response.choices[0].message.content)

asyncio.run(main())
```

---

## Router (Load Balancing & Failover)

### Basic Router

```python
from litellm import Router

router = Router(
    model_list=[
        {
            "model_name": "gpt-4",
            "litellm_params": {
                "model": "openai/gpt-4"
            }
        },
        {
            "model_name": "gpt-4", 
            "litellm_params": {
                "model": "azure/gpt-4"
            }
        }
    ]
)

response = router.completion(
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### Router with Fallback

```python
from litellm import Router

router = Router(
    model_list=[
        {
            "model_name": "primary",
            "litellm_params": {
                "model": "openai/gpt-4o",
                "api_key": os.getenv("OPENAI_API_KEY")
            }
        },
        {
            "model_name": "fallback",
            "litellm_params": {
                "model": "anthropic/claude-3-sonnet-20240229",
                "api_key": os.getenv("ANTHROPIC_API_KEY")
            }
        }
    ]
)

# Automatically falls back if primary fails
response = router.completion(
    model="primary",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### Router with Caching

```python
from litellm import Router

router = Router(
    model_list=[...],
    cache=True,  # Enable caching
    cache_params={
        "type": "redis",
        "host": "localhost",
        "port": 6379
    }
)
```

---

## Cost Tracking

### Per-Request Cost

```python
def cost_tracker(response, response_object, timeout=5):
    # Get cost from _hidden_params
    cost = response._response_msgs[0]._hidden_params.get('cost', 0)
    print(f"Cost: ${cost}")

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello"}],
    callbacks=[cost_tracker]
)
```

---

## Function Calling

```python
from litellm import completion

tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get weather for a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string", "description": "City name"}
                },
                "required": ["location"]
            }
        }
    }
]

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "What's the weather in Tokyo?"}],
    tools=tools
)

# Check if function was called
if response.choices[0].message.tool_calls:
    for tool_call in response.choices[0].message.tool_calls:
        print(f"Function: {tool_call.function.name}")
        print(f"Arguments: {tool_call.function.arguments}")
```

---

## Image Generation

```python
from litellm import image_generation

response = image_generation(
    model="openai/dall-e-3",
    prompt="A cute cat sitting on a chair",
    size="1024x1024"
)

print(response.data[0].url)
```

---

## Embeddings

```python
from litellm import embedding

response = embedding(
    model="openai/text-embedding-3-small",
    input="The quick brown fox"
)

print(response.data[0].embedding)
```

---

## Configuration File

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

litellm_settings:
  drop_params: true
  set_verbose: true
```

### Load Config

```python
from litellm import completion

completion(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello"}],
    config_path="./config.yaml"
)
```

---

## Error Handling

```python
from litellm import completion
from litellm.exceptions import (
    RateLimitError,
    AuthenticationError,
    BadRequestError
)

try:
    response = completion(
        model="openai/gpt-4o",
        messages=[{"role": "user", "content": "Hello"}]
    )
except RateLimitError:
    print("Rate limited - use fallback!")
except AuthenticationError:
    print("Check your API key!")
except BadRequestError as e:
    print(f"Bad request: {e}")
```

---

## Common Providers

### OpenAI

```python
import os
os.environ["OPENAI_API_KEY"] = "sk-..."

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### Anthropic

```python
import os
os.environ["ANTHROPIC_API_KEY"] = "sk-ant-..."

response = completion(
    model="anthropic/claude-3-sonnet-20240229",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### Azure OpenAI

```python
import os
os.environ["AZURE_API_KEY"] = "..."
os.environ["AZURE_API_BASE"] = "https://your-resource.openai.azure.com/"
os.environ["AZURE_API_VERSION"] = "2024-02-15-preview"

response = completion(
    model="azure/gpt-4",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### Ollama (Local)

```python
response = completion(
    model="ollama/llama2",
    messages=[{"role": "user", "content": "Hello"}],
    api_base="http://localhost:11434"
)
```

---

*This SDK reference is part of the LiteLLM Fortress.*
