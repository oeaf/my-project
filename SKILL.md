---
name: "pi_install"
description: "Install the Pi coding agent (pi.dev), configure the intern discovery-api provider with a rotating key pool (1 or more keys), and verify it works end to end. Use when the user asks to set up Pi as a delegated worker for repetitive tasks."
---

# Pi Install

## Purpose
Install Pi coding agent from pi.dev, wire it to the intern discovery-api provider with a key pool, and prove it works. The result is a delegated "粗活 assistant": the agent keeps judgment-heavy work for itself and sends repetitive work to `bin/pi-run.sh`, which rotates keys and escalates models automatically.

## Workflow
1. Check Node.js: `node --version` must be >= v22.19. If missing or too old, install Node 22+ first.
2. Install Pi:
   ```bash
   curl -fsSL https://pi.dev/install.sh -o /tmp/pi-install.sh
   sh /tmp/pi-install.sh
   export PATH="$HOME/.pi/agent/bin:$PATH"
   ```
   Verify with `pi --version`. (Optionally persist the PATH export in the shell profile.)
3. Confirm configuration with the user BEFORE writing anything. Values below are defaults, not constants — endpoints and model lineups change:
   - API base URL (OpenAI-compatible): `https://discovery-api.intern-ai.org.cn/v1`
   - Primary worker model: `deepseek-v4-flash-0731`
   - Fallback model: `Atria-Dawn-Preview` (free)
   - Number of API keys for the pool: **ask the user** (1 or more)
4. Write `~/.pi/agent/models.json` with the confirmed values (create parent dirs as needed). **Do NOT put real API keys in this file** — Pi interpolates `$INTERN_API_KEY` from the environment at request time:
   ```json
   {
     "providers": {
       "intern": {
         "baseUrl": "<confirmed base URL>",
         "api": "openai-completions",
         "apiKey": "$INTERN_API_KEY",
         "models": [
           {"id": "<primary model>", "name": "<primary model>", "contextWindow": 1048576, "maxTokens": 16384, "input": ["text"]},
           {"id": "<fallback model>", "name": "<fallback model> (free fallback)", "contextWindow": 524288, "maxTokens": 16384, "input": ["text"]}
         ]
       }
     }
   }
   ```
   Adjust `contextWindow` to each model's real value when known; when unknown, omit it (Pi defaults to 128000).
5. Create the key pool at `~/.pi/agent/.keys.env`, `chmod 600`. **Never** under the workspace or any shared/synced directory:
   ```
   KEY_1='sk-...'
   KEY_2='sk-...'
   ```
   Ask the user for keys **one at a time**. Validate each key before storing (lightweight, burns no quota):
   ```bash
   curl -s --max-time 30 "<baseUrl>/models" -H "Authorization: Bearer $KEY" | head -c 200
   ```
   Expect a JSON model list. Never print or log key values — identify keys by last-4 only.
6. Copy `bin/pi-run.sh` from this skill to a persistent location (e.g. `~/workspace/pi-tasks/pi-run.sh`), `chmod +x`. Usage: `pi-run.sh "task prompt" [workdir]`. It tries the primary model on each key in order, skips quota-exhausted keys, and only after all keys fail tries the free fallback once. See [references/key-rotation.md](references/key-rotation.md) for the design.
7. Verify end to end (keys come from the pool file; nothing on the command line):
   - Smoke: `pi-run.sh "用一句话介绍你自己，不超过20个字" /tmp` → expect a reply, exit 0.
   - Rotation (recommended): `PI_KEYS_FILE=/tmp/t.env` with a bogus `KEY_1` and real `KEY_2` → expect automatic move to KEY_2 and success; delete the test file afterwards.
   - Tool loop: `pi-run.sh "统计 /tmp/piwork 下所有 .txt 文件的总行数，只回答数字" /tmp` (prepare /tmp/piwork with test files first) → expect the correct number.
8. Report success to the user.

## Output Contract
Tell the user: Pi version installed, confirmed provider base URL, primary + fallback models, number of keys in the pool (last-4 only, never full keys), all test results, and confirmation that keys live only in the 600-perm pool file. If any step fails, report which step and the exact error output instead of guessing.

## Operating Rules
1. Never hardcode, print, log, or persist API keys outside the pool file. The pool file is the ONLY exception to the never-persist-keys rule, and only with the user's explicit approval for this setup.
2. API base URL, models, and key count are confirm-with-user values, not constants.
3. `pi --print` blocks forever on stdin — always redirect `< /dev/null` (the wrapper does this).
4. Allow generous timeouts (120s+); first runs and reasoning models are slow.
5. Keep the worker minimal — no extra Pi extensions or packages unless the user asks.
6. Reasoning models return empty content unless maxTokens is generous — keep it at 16384 or higher.
7. Soft failures (plausible-but-wrong answers) cannot be detected by the wrapper; the delegating agent must sanity-check important results.
