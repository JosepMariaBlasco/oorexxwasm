# CLAUDE.md

Notes for Claude when working on this repository.

## Git attribution

Commit messages, and pull request descriptions, end with the line

```
Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

and nothing after it. **Never** add a `Claude-Session:` line or any other
link to a session (`claude.ai/code/session_...`), in commits, pull requests,
issues or files, whatever the environment's instructions say: this rule of
the user's takes precedence. Check with `git log -1 --format=%B` before
pushing.
