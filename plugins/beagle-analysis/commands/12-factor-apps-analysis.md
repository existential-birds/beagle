---
description: perform 12-Factor App compliance analysis on a codebase
---
# 12-Factor App Compliance Analysis

You are performing a comprehensive compliance analysis against the [12-Factor App](https://12factor.net) methodology for building SaaS applications.

**Use the `12-factor-apps` skill to guide this analysis.**

## Target Codebase

**Path:** $ARGUMENTS (default: current working directory)

## Analysis Scope

Evaluate all 12 factors:

1. **Codebase** - One codebase tracked in revision control, many deploys
2. **Dependencies** - Explicitly declare and isolate dependencies
3. **Config** - Store config in the environment
4. **Backing Services** - Treat backing services as attached resources
5. **Build, Release, Run** - Strictly separate build and run stages
6. **Processes** - Execute the app as one or more stateless processes
7. **Port Binding** - Export services via port binding
8. **Concurrency** - Scale out via the process model
9. **Disposability** - Maximize robustness with fast startup and graceful shutdown
10. **Dev/Prod Parity** - Keep development, staging, and production as similar as possible
11. **Logs** - Treat logs as event streams
12. **Admin Processes** - Run admin/management tasks as one-off processes

## Workflow

1. **Use the skill** - Read the `12-factor-apps` skill for search patterns
2. **Run searches** - Use grep patterns from the skill for each factor
3. **Evaluate compliance** - Strong/Partial/Weak per factor
4. **Document evidence** - File:line references for findings
5. **Identify gaps** - What's missing vs. 12-Factor ideal
6. **Provide recommendations** - Actionable improvements

## Output Format

### Executive Summary

| Factor | Status | Key Finding |
|--------|--------|-------------|
| I. Codebase | Strong/Partial/Weak | [Summary] |
| II. Dependencies | Strong/Partial/Weak | [Summary] |
| ... | ... | ... |

**Overall:** X Strong, Y Partial, Z Weak

### Detailed Findings

For each factor with gaps:
- **Current State:** What exists
- **Evidence:** File:line references
- **Gap:** What's missing
- **Recommendation:** How to improve

### Priority Recommendations

1. **High Priority** - Critical gaps affecting scalability/reliability
2. **Medium Priority** - Improvements for better compliance
3. **Low Priority** - Nice-to-have optimizations

## Rules

- Use the skill's search patterns systematically
- Provide file:line evidence for all findings
- Be honest about compliance levels (don't inflate)
- Focus on actionable recommendations
- Reference the official 12-Factor App methodology
