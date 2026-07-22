"""
Unified LLM client supporting OpenAI and LM Studio (OpenAI-compatible local inference).

Default provider is LM Studio with Gemma 4. Set LLM_PROVIDER=openai to use OpenAI.
"""
import json
import logging
import re

from django.conf import settings

logger = logging.getLogger(__name__)

_client = None


def get_llm_provider() -> str:
    return getattr(settings, 'LLM_PROVIDER', 'lmstudio')


def is_llm_configured() -> bool:
    provider = get_llm_provider()
    if provider == 'openai':
        return bool(getattr(settings, 'OPENAI_API_KEY', None))
    return bool(getattr(settings, 'LM_STUDIO_BASE_URL', None))


def supports_structured_output() -> bool:
    return get_llm_provider() == 'openai'


def supports_json_response_format() -> bool:
    return get_llm_provider() == 'openai'


def get_llm_model() -> str:
    if get_llm_provider() == 'openai':
        return settings.OPENAI_MODEL
    return settings.LM_STUDIO_MODEL


def get_llm_temperature(default: float = None) -> float:
    if default is not None:
        return default
    return getattr(settings, 'LLM_TEMPERATURE', 0.7)


def get_llm_client():
    """Return an OpenAI SDK client configured for the active provider."""
    global _client
    if _client is not None:
        return _client

    from openai import OpenAI

    provider = get_llm_provider()
    if provider == 'openai':
        _client = OpenAI(api_key=settings.OPENAI_API_KEY)
    else:
        _client = OpenAI(
            base_url=settings.LM_STUDIO_BASE_URL,
            api_key=settings.LM_STUDIO_API_KEY,
        )
    return _client


def _extract_json_from_text(content: str):
    if not content or not content.strip():
        raise ValueError('LLM returned empty content')
    content = content.strip()
    if content.startswith('```'):
        content = re.sub(r'^```(?:json)?\s*', '', content)
        content = re.sub(r'\s*```$', '', content)
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        match = re.search(r'\{[\s\S]*\}', content)
        if match:
            return json.loads(match.group())
        raise


def _extract_final_text_from_reasoning(reasoning: str) -> str:
    """Pull the user-facing answer out of chain-of-thought reasoning traces."""
    text = reasoning.strip()
    if not text:
        return ''

    markers = [
        r'(?:final answer|answer|output|response|summary)\s*:\s*',
        r'(?:here(?:\'s| is) (?:the|my) (?:summary|response|answer))\s*:?\s*',
    ]
    for marker in markers:
        parts = re.split(marker, text, flags=re.IGNORECASE)
        if len(parts) > 1 and parts[-1].strip():
            return parts[-1].strip()

    bullet_lines = [ln.strip() for ln in text.splitlines() if ln.strip().startswith(('•', '-', '*', '1.', '2.'))]
    if len(bullet_lines) >= 2:
        return '\n'.join(bullet_lines)

    paragraphs = [p.strip() for p in re.split(r'\n\s*\n', text) if p.strip()]
    if paragraphs:
        return paragraphs[-1]

    return text


def get_message_content(message) -> str:
    """Return assistant text, extracting final answers from reasoning models."""
    content = getattr(message, 'content', None) or ''
    if content.strip():
        return content.strip()

    reasoning = getattr(message, 'reasoning_content', None) or ''
    if reasoning.strip():
        extracted = _extract_final_text_from_reasoning(reasoning)
        if extracted:
            logger.warning('Assistant content empty; extracted final text from reasoning_content')
            return extracted
        logger.warning('Assistant content empty; using reasoning_content fallback')
        return reasoning.strip()
    return ''


def parse_json_response(content: str):
    """Parse JSON from an LLM response string."""
    return _extract_json_from_text(content)


def _augment_messages_for_json(messages):
    """Ensure local models are explicitly instructed to return JSON only."""
    if not messages:
        return messages
    json_instruction = 'Respond with valid JSON only. No markdown fences or extra text.'
    updated = [dict(m) for m in messages]
    if updated[0].get('role') == 'system':
        updated[0]['content'] = f"{updated[0]['content']}\n\n{json_instruction}"
    else:
        updated.insert(0, {'role': 'system', 'content': json_instruction})
    return updated


def _default_max_tokens():
    if get_llm_provider() == 'lmstudio':
        return getattr(settings, 'LM_STUDIO_MAX_TOKENS', 8192)
    return None


def _is_context_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return any(
        token in msg
        for token in ('context', 'n_keep', 'n_ctx', 'token limit', 'too long')
    )


def _truncate_text(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rsplit(' ', 1)[0] + '…'


def _truncate_messages(messages, factor: float = 0.65):
    """Shrink user/system message content to fit a smaller context window."""
    updated = []
    for message in messages:
        msg = dict(message)
        content = msg.get('content') or ''
        if isinstance(content, str) and content:
            msg['content'] = _truncate_text(content, max(400, int(len(content) * factor)))
        updated.append(msg)
    return updated


def chat_completions_create(
    *,
    messages,
    model=None,
    temperature=None,
    response_format=None,
    max_tokens=None,
    **kwargs,
):
    """
    Create a chat completion using the configured LLM provider.

    LM Studio does not support OpenAI's response_format parameter, so JSON
    requests fall back to prompt-based JSON extraction.

    On context-window errors, retries with progressively truncated prompts.
    """
    client = get_llm_client()
    model = model or get_llm_model()
    temperature = get_llm_temperature(temperature)

    wants_json = response_format is not None and response_format.get('type') == 'json_object'
    working_messages = list(messages)
    if wants_json and not supports_json_response_format():
        working_messages = _augment_messages_for_json(working_messages)

    if max_tokens is None:
        max_tokens = _default_max_tokens()

    params = {
        'model': model,
        'messages': working_messages,
        'temperature': temperature,
    }
    if max_tokens is not None:
        params['max_tokens'] = max_tokens

    use_json_format = wants_json and supports_json_response_format()
    if use_json_format:
        params['response_format'] = response_format

    last_exc = None
    for attempt in range(4):
        try:
            response = client.chat.completions.create(**params, **kwargs)
        except Exception as exc:
            last_exc = exc
            if use_json_format and attempt == 0:
                logger.warning('JSON response_format failed (%s), retrying without it', exc)
                params.pop('response_format', None)
                use_json_format = False
                continue
            if _is_context_error(exc) and attempt < 3:
                shrink = 0.55 ** (attempt + 1)
                working_messages = _truncate_messages(working_messages, shrink)
                params['messages'] = working_messages
                if max_tokens and max_tokens > 256:
                    params['max_tokens'] = max(256, int(max_tokens * shrink))
                logger.warning(
                    'Context window exceeded (attempt %s); retrying with truncated prompt',
                    attempt + 1,
                )
                continue
            raise

        content = get_message_content(response.choices[0].message)
        if not content and attempt < 3:
            logger.warning('LLM returned empty content; retrying (attempt %s)', attempt + 1)
            working_messages = _truncate_messages(working_messages, 0.8)
            params['messages'] = working_messages
            continue
        if not content:
            logger.error(
                'LLM returned empty content after retries (finish_reason=%s, usage=%s)',
                response.choices[0].finish_reason,
                getattr(response, 'usage', None),
            )
        return response

    if last_exc:
        raise last_exc
    raise RuntimeError('LLM request failed without a response')


def chat_completions_parse(*, messages, response_format, model=None, **kwargs):
    """
    Structured output via OpenAI's parse API. Falls back to JSON extraction
    for LM Studio and other providers without structured output support.
    """
    if supports_structured_output():
        client = get_llm_client()
        return client.beta.chat.completions.parse(
            model=model or get_llm_model(),
            messages=messages,
            response_format=response_format,
            **kwargs,
        )

    response = chat_completions_create(messages=messages, model=model, **kwargs)
    content = get_message_content(response.choices[0].message)
    parsed_data = _extract_json_from_text(content)
    parsed = response_format.model_validate(parsed_data)

    class _ParsedResponse:
        def __init__(self, parsed_obj):
            self.choices = [type('Choice', (), {'message': type('Message', (), {'parsed': parsed_obj})()})()]

    return _ParsedResponse(parsed)
