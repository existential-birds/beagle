# Built-in Tools Reference

Every agent created with `create_deep_agent` has these tools:

## Task Management

| Tool | Description |
|------|-------------|
| `write_todos` | Create/update structured task lists |
| `read_todos` | Read current todo list state |

## Filesystem Operations

| Tool | Description |
|------|-------------|
| `ls` | List directory contents (requires absolute path) |
| `read_file` | Read file with optional offset/limit pagination |
| `write_file` | Create new file (fails if exists) |
| `edit_file` | String replacement in existing files |
| `glob` | Find files matching pattern (e.g., `**/*.py`) |
| `grep` | Search for text patterns in files |
| `execute`* | Run shell commands |

*`execute` only available with `FilesystemBackend` or backends implementing `SandboxBackendProtocol`.

## Subagent Delegation

| Tool | Description |
|------|-------------|
| `task` | Launch subagent for isolated task execution |

## Tool Path Requirements

All filesystem tools require absolute paths starting with `/`:

```python
# Correct
read_file(path="/workspace/main.py")
ls(path="/data")

# Incorrect - will fail
read_file(path="main.py")
read_file(path="./workspace/main.py")
```
