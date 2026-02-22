# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Vauban, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email **contact@clement-avenel.com** with:

1. A description of the vulnerability
2. Steps to reproduce the issue
3. The potential impact
4. Any suggested fix (optional)

You should receive an acknowledgment within 48 hours. We will work with you to understand the issue and coordinate a fix and disclosure timeline.

## Security Practices

- **Dependencies**: We use `bundler-audit` in CI to check for known vulnerabilities in dependencies.
- **Code review**: All changes go through pull request review before merging.
- **Hashing**: Cache keys use SHA-256 for context hashing. No sensitive data is stored in cache keys.
- **No `eval`**: Vauban does not use `eval`, `send` on user input, or `constantize` on user-provided strings.
