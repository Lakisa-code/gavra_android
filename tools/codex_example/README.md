Codex example

This folder contains a minimal example showing how to call OpenAI's Codex (legacy code model `code-davinci-002`) via the Completions API to generate code.

Files:

- `generate_code.py` - small Python script that sends a prompt to the Codex model and prints the generated snippet.
- `requirements.txt` - Python dependencies.

Setup & run (PowerShell):

```powershell
# Create and activate venv (Windows PowerShell)
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Set your OpenAI API key (temporary for the session)
$env:OPENAI_API_KEY = "sk-..."

# Run the example
python generate_code.py
```

Notes:

- The example uses the `code-davinci-002` model (Codex). If your account has different models or newer instructions, you can change the `model` field in `generate_code.py`.
- Keep your API key secret. Don't commit it to git.
- This is a minimal demo. For production use, add retries, error handling and rate-limit backoff.
