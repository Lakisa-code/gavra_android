import os
import sys
import time
import random
import requests
from typing import Optional, Dict, Any

API_KEY = os.getenv("OPENAI_API_KEY")
if not API_KEY:
    print("ERROR: OPENAI_API_KEY environment variable not set")
    sys.exit(1)

BASE_URL = "https://api.openai.com/v1/chat/completions"
DEFAULT_MODEL = "gpt-4o-code"

def build_messages(prompt: str) -> list:
    return [
        {"role": "system", "content": "You are a helpful assistant that writes Python code snippets."},
        {"role": "user", "content": prompt},
    ]


def request_with_retries(session: requests.Session, url: str, headers: Dict[str, str], json_payload: Dict[str, Any],
                         max_attempts: int = 5, base_delay: float = 1.0, max_delay: float = 30.0,
                         timeout: float = 30.0) -> requests.Response:
    """Make a POST request with retries for 429 and 5xx responses using exponential backoff + jitter."""
    attempt = 0
    while True:
        attempt += 1
        try:
            resp = session.post(url, headers=headers, json=json_payload, timeout=timeout)
        except requests.exceptions.RequestException as e:
            # Network-level errors: retry
            if attempt >= max_attempts:
                raise
            delay = min(max_delay, base_delay * (2 ** (attempt - 1)))
            jitter = random.uniform(0, delay * 0.1)
            sleep_for = delay + jitter
            time.sleep(sleep_for)
            continue

        # If success, return
        if 200 <= resp.status_code < 300:
            return resp

        # For auth errors or bad requests, don't retry
        if resp.status_code in (401, 403, 400):
            resp.raise_for_status()

        # Retry on rate limit or server errors
        if resp.status_code == 429 or 500 <= resp.status_code < 600:
            if attempt >= max_attempts:
                resp.raise_for_status()
            delay = min(max_delay, base_delay * (2 ** (attempt - 1)))
            jitter = random.uniform(0, delay * 0.1)
            sleep_for = delay + jitter
            time.sleep(sleep_for)
            continue

        # Other statuses: raise
        resp.raise_for_status()


def generate_code(prompt: str, model: Optional[str] = None, max_tokens: int = 512, temperature: float = 0.0) -> str:
    model = model or DEFAULT_MODEL
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }

    messages = build_messages(prompt)
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
    }

    with requests.Session() as session:
        resp = request_with_retries(session, BASE_URL, headers, payload)
        data = resp.json()

    # Chat responses use choices[0].message.content
    if "choices" in data and len(data["choices"]) > 0:
        message = data["choices"][0].get("message", {})
        content = message.get("content") if isinstance(message, dict) else None
        if content:
            return content.strip()

    raise RuntimeError(f"No completion returned: {data}")


if __name__ == "__main__":
    prompt = """
# Write a Python function `reverse_string` that takes a single argument `s` (a string)
# and returns the string reversed. Include a short docstring and a simple example in a
# comment showing usage.

"""

    try:
        generated = generate_code(prompt)
        print("--- Generated code ---\n")
        print(generated)
    except Exception as e:
        print("Error while generating code:", str(e))
        sys.exit(1)
