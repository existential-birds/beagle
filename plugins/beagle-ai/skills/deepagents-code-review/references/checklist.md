# Code Review Checklist

Use after working through the **Review gates** and the numbered issue catalogue in `../SKILL.md`. Each box ties back to a specific issue (see the `SKILL.md` anchors).

## Configuration
- [ ] Checkpointer provided if using `interrupt_on`
- [ ] Store provided if using `StoreBackend`
- [ ] Thread ID provided in config when using checkpointer
- [ ] Backend appropriate for use case (ephemeral vs persistent)

## Backends
- [ ] FilesystemBackend scoped to safe `root_dir`
- [ ] StoreBackend has corresponding `store` parameter
- [ ] CompositeBackend routes don't shadow each other unintentionally
- [ ] Not expecting persistence from StateBackend across threads

## Subagents
- [ ] All required fields present (name, description, system_prompt, tools)
- [ ] Unique subagent names
- [ ] CompiledSubAgent has compatible state schema
- [ ] Subagents used for complex tasks, not trivial operations

## Middleware
- [ ] Custom middleware added after built-in stack (expected behavior)
- [ ] Tools have descriptive docstrings
- [ ] Not mutating request/response objects

## System Prompt
- [ ] Not duplicating built-in tool instructions
- [ ] Not contradicting framework defaults
- [ ] Stopping criteria defined for open-ended tasks
- [ ] Parallelization guidance for independent tasks

## Performance
- [ ] Large files routed to appropriate backend
- [ ] Production uses persistent checkpointer
- [ ] Recursion/iteration limits considered
- [ ] Independent subagents parallelized
