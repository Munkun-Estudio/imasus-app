---
name: rails-security-review
description: >
  Performs security audits and vulnerability assessments on Ruby on Rails application
  code. Use when reviewing Rails code for security risks, assessing authentication or
  authorization, auditing parameter handling, redirects, file uploads, secrets management,
  or checking for XSS, CSRF, SSRF, SQL injection, and other common vulnerabilities.
---

# Rails Security Review

Use this skill when the task is to review or harden Rails code from a security perspective.

**Core principle:** Prioritise exploitable issues over style. Assume any untrusted input can be abused.

## Quick Reference

| Area | Key Checks |
|------|------------|
| Auth | Permissions enforced on every sensitive action |
| Params | No `permit!`; whitelist only safe attributes |
| Queries | Parameterised — no string interpolation in SQL |
| Redirects | Constrained to relative paths or an allowlist |
| Output | No `html_safe` / `raw` on user content |
| Secrets | Encrypted credentials, never in code or logs |
| Files | Validate filename, content type, destination (Active Storage direct uploads included) |

## Review Order

1. Check authentication and authorisation boundaries.
2. Check parameter handling and sensitive attribute assignment.
3. Check redirects, rendering, and output encoding.
4. Check file handling, network calls, and background job inputs.
5. Check secrets, logging, and operational exposure.
6. **Verify each finding:** confirm it is exploitable with a concrete attack scenario before reporting. Exclude false positives (e.g., `html_safe` on a developer-defined constant, not user input).

## Severity Levels

### High

- Missing or bypassable authorisation checks
- SQL, shell, YAML, or constantisation injection paths
- Unsafe redirects or SSRF-capable outbound requests
- File upload handling that trusts filename, content type, or destination blindly
- Secrets or tokens stored in code, logs, or unsafe config

### Medium

- Unscoped mass assignment through weak parameter filtering
- User-controlled HTML rendered without clear sanitisation
- Sensitive data logged in plaintext
- Security-relevant behaviour hidden in callbacks or background jobs without guardrails
- Brittle custom auth logic where framework primitives would be safer

## Review Checklist

- Are permissions enforced on every sensitive action?
- Are untrusted inputs validated before database, filesystem, or network use?
- Are redirects and URLs constrained?
- Are secrets stored and logged safely?
- Are security assumptions explicit and testable?

## Examples

**High-severity (unscoped redirect):**

```ruby
# Bad: user-controlled redirect — open redirect / phishing risk
redirect_to params[:return_to]

# Good: relative path only
redirect_to root_path
# Good: allowlist
SAFE_PATHS = %w[/materials /training /glossary].freeze
redirect_to(SAFE_PATHS.include?(params[:return_to]) ? params[:return_to] : root_path)
```

**Medium-severity (mass assignment):**

```ruby
# Bad: privilege escalation risk
params.require(:user).permit!

# Good: explicit whitelist — never include role, admin, or privilege fields
params.require(:user).permit(:name, :email)
```

**Medium-severity (raw rendering of user markdown):**

Training modules in this project render markdown from disk (trusted), but any feature that renders markdown **authored by a user** (log entries, prototype descriptions) must use a sanitising renderer and must not pass through `raw` / `html_safe`.

## Critical Anti-Patterns

- `permit!` on any parameter set
- `html_safe` or `raw` on user-provided content
- SQL string interpolation with user input
- Secrets in committed files (use Rails encrypted credentials or env)
- Signed/verified assumptions stored in plaintext session or cookies

## Output Style

Write findings first. **Order findings by review area — auth/authz always first:**

1. Authentication and authorisation findings
2. SQL / injection and parameter findings
3. Secrets, logging, and output findings

Do not reorder based on which issue looks most obvious. Even if SQL injection is more apparent, authorisation findings lead the report.

For each finding include:
- **Severity:** label it **High** or **Medium** (not "High-Severity" or "Critical")
- Attack path or failure mode
- Affected file (name it, e.g. `app/controllers/materials_controller.rb`)
- Smallest credible mitigation

## Integration

| Skill | When to chain |
|-------|---------------|
| `rails-code-review` | For full code review including non-security concerns |
| `rails-architecture-review` | When security issues stem from architectural problems |
| `rails-migration-safety` | When reviewing migration security (data exposure, constraints) |
