# AGENTS.md - Development Guidelines for Home Assistant Add-ons

## CRITICAL: Always Run Linters Before Committing

**MANDATORY REQUIREMENT**: Before every commit, you MUST run Black formatter to ensure code style compliance. CI/CD will fail if code is not properly formatted.

## Build/Lint/Test Commands
```bash
# Lint Python code (from root) - RUN THESE BEFORE EVERY COMMIT
black --check --diff ha-joplin-bridge/api_server.py
flake8 ha-joplin-bridge/api_server.py --max-line-length=88
bandit -r ha-joplin-bridge/api_server.py

# Validate config
python -c "import yaml; yaml.safe_load(open('ha-joplin-bridge/config.yaml'))"

# Build Docker image
docker build -t ha-joplin-bridge ./ha-joplin-bridge
```

## Code Style Guidelines

### Python (Flask API)
- **CRITICAL**: Always use double quotes `"` for strings, never single quotes `'`
- **CRITICAL**: Set literals must have trailing comma on last item across multiple lines
- **CRITICAL**: Dictionary comprehensions must be on single line if short
- Use Black formatter with 88 character line limit (run before every commit!)
- Follow PEP 8 naming: snake_case for functions/variables, UPPER_CASE for constants  
- Type hints recommended but not required
- Use f-strings for formatting, avoid % or .format()
- Import order: stdlib, third-party, local modules
- Security: Use #nosec comments for justified Bandit warnings only

### Black Formatter Rules (Examples)
```python
# CORRECT - Double quotes, trailing comma
excluded_headers = {
    "content-length",
    "transfer-encoding",
    "connection",
    "keep-alive",
    "server",
}

# WRONG - Single quotes, no trailing comma
excluded_headers = {
    'content-length', 'transfer-encoding', 'connection', 
    'keep-alive', 'server'
}

# CORRECT - Single line dict comprehension
safe_headers = {k: v for k, v in resp.headers.items() if k.lower() not in excluded}

# WRONG - Multi-line when not needed
safe_headers = {
    k: v for k, v in resp.headers.items() 
    if k.lower() not in excluded
}
```

### Error Handling
- Return JSON responses with success/error fields
- Use try/except blocks for external commands (subprocess)
- Log errors with timestamps using structured format
- Validate user inputs before processing

### Configuration
- Use Home Assistant config schema in config.yaml
- Read options from /data/options.json in containers
- Provide sensible defaults for all optional parameters