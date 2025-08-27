# AGENTS.md - Development Guidelines for Home Assistant Add-ons

## Build/Lint/Test Commands
```bash
# Lint Python code (from root)
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
- Use Black formatter with 88 character line limit
- Follow PEP 8 naming: snake_case for functions/variables, UPPER_CASE for constants  
- Type hints recommended but not required
- Use f-strings for formatting, avoid % or .format()
- Import order: stdlib, third-party, local modules
- Security: Use #nosec comments for justified Bandit warnings only

### Error Handling
- Return JSON responses with success/error fields
- Use try/except blocks for external commands (subprocess)
- Log errors with timestamps using structured format
- Validate user inputs before processing

### Configuration
- Use Home Assistant config schema in config.yaml
- Read options from /data/options.json in containers
- Provide sensible defaults for all optional parameters