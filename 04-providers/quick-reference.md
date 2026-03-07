# LITELLM PROVIDERS

*Quick reference for supported LLM providers*

---

## Model Name Format

LiteLLM uses `provider/model` format:

```python
"openai/gpt-4o"           # OpenAI
"anthropic/claude-3-sonnet"  # Anthropic
"azure/gpt-4"             # Azure OpenAI
"ollama/llama2"           # Ollama
"bedrock/anthropic.claude-3-sonnet"  # AWS Bedrock
```

---

## Quick Reference Table

| Provider | Model String | Env Vars |
|----------|--------------|----------|
| **OpenAI** | `openai/gpt-4o` | `OPENAI_API_KEY` |
| **Anthropic** | `anthropic/claude-3-sonnet` | `ANTHROPIC_API_KEY` |
| **Azure** | `azure/gpt-4` | `AZURE_API_KEY`, `AZURE_API_BASE` |
| **Ollama** | `ollama/llama2` | (local) |
| **Google Gemini** | `gemini/gemini-pro` | `GEMINI_API_KEY` |
| **Mistral** | `mistral/mistral-large-latest` | `MISTRAL_API_KEY` |
| **Cohere** | `cohere/command-r-plus` | `COHERE_API_KEY` |
| **AWS Bedrock** | `bedrock/anthropic.claude-3-sonnet` | AWS credentials |
| **Groq** | `groq/llama-3.1-70b-versatile` | `GROQ_API_KEY` |
| **DeepSeek** | `deepseek/deepseek-chat` | `DEEPSEEK_API_KEY` |

---

## OpenAI

```python
import os
os.environ["OPENAI_API_KEY"] = "sk-..."

from litellm import completion

response = completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## Anthropic

```python
import os
os.environ["ANTHROPIC_API_KEY"] = "sk-ant-..."

from litellm import completion

response = completion(
    model="anthropic/claude-3-sonnet-20240229",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### Model Names

- `anthropic/claude-3-opus-20240229`
- `anthropic/claude-3-sonnet-20240229`
- `anthropic/claude-3-haiku-20240307`
- `anthropic/claude-3-5-sonnet-20241022`

---

## Azure OpenAI

```python
import os
os.environ["AZURE_API_KEY"] = "your-azure-key"
os.environ["AZURE_API_BASE"] = "https://your-resource.openai.azure.com/"
os.environ["AZURE_API_VERSION"] = "2024-02-15-preview"

from litellm import completion

response = completion(
    model="azure/gpt-4",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## Ollama (Local)

```python
from litellm import completion

response = completion(
    model="ollama/llama2",
    messages=[{"role": "user", "content": "Hello"}],
    api_base="http://localhost:11434"
)
```

### Common Ollama Models

- `ollama/llama2`
- `ollama/llama3`
- `ollama/llama3.1`
- `ollama/mistral`
- `ollama/codellama`
- `ollama/phi3`

---

## AWS Bedrock

```python
import os
os.environ["AWS_ACCESS_KEY_ID"] = "..."
os.environ["AWS_SECRET_ACCESS_KEY"] = "..."
os.environ["AWS_REGION_NAME"] = "us-east-1"

from litellm import completion

response = completion(
    model="bedrock/anthropic.claude-3-sonnet-20240229-v1:0",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## Google Gemini

```python
import os
os.environ["GEMINI_API_KEY"] = "..."

from litellm import completion

response = completion(
    model="gemini/gemini-pro",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## Mistral

```python
import os
os.environ["MISTRAL_API_KEY"] = "..."

from litellm import completion

response = completion(
    model="mistral/mistral-large-latest",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## Cohere

```python
import os
os.environ["COHERE_API_KEY"] = "..."

from litellm import completion

response = completion(
    model="cohere/command-r-plus",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## Groq

```python
import os
os.environ["GROQ_API_KEY"] = "..."

from litellm import completion

response = completion(
    model="groq/llama-3.1-70b-versatile",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## DeepSeek

```python
import os
os.environ["DEEPSEEK_API_KEY"] = "..."

from litellm import completion

response = completion(
    model="deepseek/deepseek-chat",
    messages=[{"role": "user", "content": "Hello"}]
)
```

---

## All Supported Providers

LiteLLM supports 100+ providers. For complete list, see:
- [LiteLLM Docs - Providers](https://docs.litellm.ai/docs/providers)

---

*This provider reference is part of the LiteLLM Fortress.*
