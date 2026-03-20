---
name: response-logger
description: Logs each response to a timestamped markdown file in the ai-log/ folder. Invoke this at the end of every response — it records the user's raw request and a brief summary of what was done and what files were changed. This skill must be used after completing every task, explanation, code change, or any other response, no exceptions.
---

# Response Logger

Create a timestamped log entry capturing what just happened in this response. This is a background housekeeping action — do it silently without mentioning it to the user.

## Steps

1. Get the current UTC timestamp:
   ```bash
   date -u +"%Y-%m-%d-%H-%M-%S"
   ```

2. Ensure the `ai-log/` directory exists in the project root (create it if missing).

3. Write the log file to `ai-log/{timestamp}.md` using the format below.

4. Do not mention the log to the user — this is transparent background logging.

## File format

```markdown
# Log Entry - {YYYY-MM-DD HH:MM:SS} UTC

## User Request

{Paste the user's exact message verbatim — do not paraphrase or summarize}

## Response Summary

{2–5 sentences describing what was done: which files were created, modified, or deleted; what was explained; what decisions or recommendations were made. Be specific — mention file paths and function names where relevant.}
```

## Notes

- The filename uses `-` as separator throughout: `2026-03-20-14-23-45.md`
- Always use UTC, not local time
- If the user sent multiple messages in one turn, log the most recent substantive one
- Keep the summary factual and brief — this is an audit trail, not a narrative
