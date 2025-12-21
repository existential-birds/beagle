# Ensure Documentation Coverage

Verify code documentation coverage across a codebase, report gaps, and interactively generate missing documentation using parallel language-specific agents.

## Arguments

- `Path`: Target directory (default: current working directory)
- `--report-only`: Skip interactive generation, just output findings

## Workflow Overview

1. **Detect** languages present in the codebase
2. **Spawn** parallel verification agents per language
3. **Merge** and present consolidated findings
4. **Offer** interactive generation choices
5. **Generate** missing docs if requested
6. **Verify** with language linters

## Phase 1: Language Detection

Detect which languages are present in the codebase:

```bash
# Python detection
PYTHON_FILES=$(find . -type f -name "*.py" ! -path "./.*" ! -path "./venv/*" ! -path "./.venv/*" | head -100)
PYTHON_COUNT=$(echo "$PYTHON_FILES" | grep -c . || echo 0)

# TypeScript/JavaScript detection
TS_FILES=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) ! -path "./node_modules/*" ! -path "./.*" | head -100)
TS_COUNT=$(echo "$TS_FILES" | grep -c . || echo 0)

# Go detection
GO_FILES=$(find . -type f -name "*.go" ! -path "./vendor/*" ! -path "./.*" | head -100)
GO_COUNT=$(echo "$GO_FILES" | grep -c . || echo 0)
```

### Framework Detection

```bash
# FastAPI detection (affects OpenAPI handling)
grep -r "from fastapi\|FastAPI\|@app\.\|@router\." --include="*.py" -l 2>/dev/null | head -1

# Check existing OpenAPI specs
ls -la openapi.yaml swagger.json api.yaml 2>/dev/null
```

### Detection Output

Report detected languages:

| Language | Files Found | Standard |
|----------|-------------|----------|
| Python | $PYTHON_COUNT | Google docstrings |
| TypeScript/JS | $TS_COUNT | JSDoc |
| Go | $GO_COUNT | GoDoc |

Proceed only with languages that have at least 1 file detected.

## Language Standards

### Python (Google Docstrings)

**What to check:**
- All public functions (not starting with `_`)
- All classes
- All modules (top-of-file docstring)

**Required docstring elements:**
- Description (first line, imperative mood)
- Args: Parameter name, type, and description
- Returns: Return type and description
- Raises: Exception types and when raised

**Example of compliant docstring:**

```python
def process_request(data: dict, timeout: int = 30) -> Response:
    """Process an incoming API request.

    Args:
        data: The request payload as a dictionary.
        timeout: Maximum seconds to wait for processing.

    Returns:
        Response object containing status and result.

    Raises:
        ValidationError: If data fails schema validation.
        TimeoutError: If processing exceeds timeout.
    """
```

**Missing indicators:**
- No docstring at all
- Docstring with only description (missing Args/Returns)
- Mismatched parameters (docstring doesn't match signature)

### TypeScript/JavaScript (JSDoc)

**What to check:**
- All exported functions
- All exported classes
- All exported interfaces and types
- All exported constants with complex types

**Required JSDoc elements:**
- @description or first line description
- @param for each parameter with type and description
- @returns with type and description
- @throws for thrown exceptions

**Example of compliant JSDoc:**

```typescript
/**
 * Process an incoming API request.
 * @param data - The request payload
 * @param timeout - Maximum seconds to wait
 * @returns Response containing status and result
 * @throws {ValidationError} If data fails validation
 */
export function processRequest(data: RequestData, timeout = 30): Response {
```

**Missing indicators:**
- No JSDoc comment
- JSDoc with only description (missing @param/@returns)
- Mismatched parameters (JSDoc doesn't match signature)

### Go (GoDoc)

**What to check:**
- All exported functions (capitalized names)
- All exported types (structs, interfaces)
- Package comment in one file per package

**Required GoDoc elements:**
- Comment starting with the symbol name
- Description of purpose and behavior
- For complex functions: describe parameters inline

**Example of compliant GoDoc:**

```go
// ProcessRequest handles an incoming API request with the given data
// and timeout. It returns a Response or an error if processing fails.
// The timeout is specified in seconds; use 0 for no timeout.
func ProcessRequest(data map[string]any, timeout int) (*Response, error) {
```

**Missing indicators:**
- No comment above exported symbol
- Comment doesn't start with symbol name
- Comment is too terse (single generic sentence)

## Phase 2: Parallel Verification

Spawn verification agents in parallel for each detected language using the `Task` tool.

### Agent Prompt Template

For each detected language, spawn an agent with:

**Python Agent:**
```
You are a Python documentation verifier. Check all Python files for Google docstring compliance.

STANDARD:
[Embed Python standard from above]

TASK:
1. Find all .py files in the target directory (exclude venv, .venv, __pycache__, tests)
2. For each file, identify public functions (not _prefixed) and classes
3. Check each symbol for docstring presence and completeness
4. Return findings as JSON

OUTPUT FORMAT:
{
  "language": "python",
  "files_scanned": <count>,
  "findings": [
    {"file": "path/to/file.py", "line": 15, "symbol": "function_name", "type": "function", "issue": "missing_docstring"},
    {"file": "path/to/file.py", "line": 42, "symbol": "ClassName", "type": "class", "issue": "incomplete_docstring", "missing": ["Args", "Returns"]}
  ]
}
```

**TypeScript Agent:**
```
You are a TypeScript/JavaScript documentation verifier. Check all TS/JS files for JSDoc compliance.

STANDARD:
[Embed TypeScript standard from above]

TASK:
1. Find all .ts, .tsx, .js, .jsx files (exclude node_modules, dist, build)
2. For each file, identify exported functions, classes, interfaces, and types
3. Check each symbol for JSDoc presence and completeness
4. Return findings as JSON

OUTPUT FORMAT:
{
  "language": "typescript",
  "files_scanned": <count>,
  "findings": [
    {"file": "src/api.ts", "line": 10, "symbol": "processRequest", "type": "function", "issue": "missing_jsdoc"},
    {"file": "src/types.ts", "line": 5, "symbol": "UserData", "type": "interface", "issue": "incomplete_jsdoc", "missing": ["description for userId property"]}
  ]
}
```

**Go Agent:**
```
You are a Go documentation verifier. Check all Go files for GoDoc compliance.

STANDARD:
[Embed Go standard from above]

TASK:
1. Find all .go files (exclude vendor, _test.go for symbol docs)
2. For each file, identify exported functions and types (Capitalized names)
3. Check each symbol for comment presence and correct format
4. Return findings as JSON

OUTPUT FORMAT:
{
  "language": "go",
  "files_scanned": <count>,
  "findings": [
    {"file": "pkg/api/handler.go", "line": 25, "symbol": "ProcessRequest", "type": "function", "issue": "missing_comment"},
    {"file": "pkg/models/user.go", "line": 8, "symbol": "User", "type": "struct", "issue": "wrong_format", "detail": "Comment doesn't start with 'User'"}
  ]
}
```

### Spawning Agents

Use the `Task` tool to spawn agents in parallel:

1. For each detected language with files > 0
2. Spawn agent with subagent_type="general-purpose"
3. Include the language-specific prompt and standard
4. Set run_in_background=false to wait for results
5. Collect JSON output from each agent

## Phase 3: Consolidate Results

After all agents complete, merge their findings.

### Categorize by Severity

Group findings into:

| Severity | Issue Types | Priority |
|----------|-------------|----------|
| **Missing** | `missing_docstring`, `missing_jsdoc`, `missing_comment` | High |
| **Incomplete** | `incomplete_docstring`, `incomplete_jsdoc` (has doc but missing required elements) | Medium |
| **Wrong Format** | `wrong_format` (comment exists but doesn't follow standard) | Low |

### Summary Table

Generate a summary table:

```markdown
## Documentation Audit Results

| Language   | Files | Missing | Incomplete | Format Issues |
|------------|-------|---------|------------|---------------|
| Python     | 42    | 12      | 5          | 2             |
| TypeScript | 28    | 8       | 3          | 0             |
| Go         | 15    | 4       | 1          | 1             |
| **Total**  | 85    | 24      | 9          | 3             |
```

### Detailed Report Format

If `--report-only` flag is set OR user requests detailed report:

```markdown
## Detailed Findings

### Python (12 missing, 5 incomplete, 2 format issues)

#### Missing Documentation

1. **[src/api.py:15]** `process_request(data: dict) -> Response`
   - Type: function
   - Visibility: public

2. **[src/models.py:8]** `class User`
   - Type: class
   - Visibility: public

#### Incomplete Documentation

3. **[src/utils.py:42]** `validate_input(value, schema)`
   - Has: Description
   - Missing: Args, Returns, Raises

#### Format Issues

4. **[src/helpers.py:20]** `format_output(data)`
   - Issue: Docstring uses reST format instead of Google format

### TypeScript (8 missing, 3 incomplete)
...

### Go (4 missing, 1 incomplete, 1 format issue)
...
```

## Phase 4: Interactive Generation

If `--report-only` is NOT set, offer generation choices.

### User Choice

Use `AskUserQuestion` with these options:

**Question:** "Found {total} documentation gaps. What would you like to do?"

**Options:**
1. "Generate all missing docs" - Generate documentation for all findings
2. "Generate for specific language" - Choose which language(s) to generate for
3. "Show detailed report first" - Display full findings before deciding
4. "Skip generation" - Exit with report only

### Generation Agent Prompts

For each language needing generation, spawn a generation agent:

**Python Generation Agent:**
```
You are a Python documentation generator. Generate Google-format docstrings.

STANDARD:
[Embed Python standard]

SYMBOLS TO DOCUMENT:
[List of file:line:symbol from findings]

FOR EACH SYMBOL:
1. Read the function/class implementation
2. Understand parameters, return values, and exceptions
3. Generate a complete Google-format docstring
4. Apply the edit using the Edit tool

RULES:
- Match existing code style
- Use imperative mood for descriptions
- Include all Args, Returns, Raises
- Don't modify any code logic
```

**TypeScript Generation Agent:**
```
You are a TypeScript documentation generator. Generate JSDoc comments.

STANDARD:
[Embed TypeScript standard]

SYMBOLS TO DOCUMENT:
[List of file:line:symbol from findings]

FOR EACH SYMBOL:
1. Read the function/class/interface implementation
2. Understand parameters, return types, and exceptions
3. Generate a complete JSDoc comment
4. Apply the edit using the Edit tool

RULES:
- Match existing code style
- Include @param, @returns, @throws as needed
- Don't modify any code logic
```

**Go Generation Agent:**
```
You are a Go documentation generator. Generate GoDoc comments.

STANDARD:
[Embed Go standard]

SYMBOLS TO DOCUMENT:
[List of file:line:symbol from findings]

FOR EACH SYMBOL:
1. Read the function/type implementation
2. Understand purpose, parameters, and behavior
3. Generate a comment starting with the symbol name
4. Apply the edit using the Edit tool

RULES:
- Start comment with symbol name
- Be concise but complete
- Don't modify any code logic
```

## Phase 5: Post-Generation Verification

After generating documentation, offer to run language linters to verify.

### Verification Commands

**Python:**
```bash
# Check docstring formatting with ruff (requires convention="google" in pyproject.toml [tool.ruff.lint.pydocstyle])
ruff check . --select=D --output-format=concise

# Alternative: pydocstyle
pydocstyle --convention=google .
```

**TypeScript:**
```bash
# Check JSDoc with eslint (requires eslint-plugin-jsdoc)
npx eslint . --rule 'jsdoc/require-jsdoc: error' --rule 'jsdoc/require-param: error' --rule 'jsdoc/require-returns: error'
```

**Go:**
```bash
# Check with staticcheck (golint is deprecated, use golangci-lint for comprehensive linting)
staticcheck -checks "ST1000,ST1020,ST1021,ST1022" ./...
```

### Verification Flow

1. After generation completes, ask: "Run documentation linters to verify?"
2. If yes, run appropriate linter(s) based on languages that were modified
3. Report any remaining issues
4. Offer to fix linter-reported issues

## Rules

- Always detect languages before spawning agents
- Spawn agents in parallel for efficiency
- Present clear summary before offering generation
- Don't generate docs for test files (except test helpers)
- Respect `--report-only` flag
- Run verification after generation when linters are available
