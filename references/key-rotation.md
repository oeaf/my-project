# Key rotation design

Implemented in `bin/pi-run.sh` (copy it to a persistent location, `chmod +x`).

## How it works

- **Key pool**: `~/.pi/agent/.keys.env` (`chmod 600`, never under the workspace):
  `KEY_1='sk-...'`, `KEY_2='sk-...'`, … — as many as the user provides.
- **Order**: for each key in order, try the primary model. Quota-exhausted
  keys are skipped (stderr match on `quota|insufficient|billing|rate limit
  exceeded`, case-insensitive). Only after the primary model failed on ALL
  keys is the free fallback model tried once (with `KEY_1`).
- **Exits**: `0` success; `1` everything failed; `2` config problem
  (missing pool file / no keys); `3` all keys exhausted → ask the user
  for fresh keys.
- **Overrides**: `PI_KEYS_FILE`, `PI_PROVIDER`, `PI_PRIMARY_MODEL`,
  `PI_FALLBACK_MODEL`.
- `models.json` keeps `"apiKey": "$INTERN_API_KEY"`; the script exports
  `INTERN_API_KEY` per key before each Pi invocation, so rotation needs
  no config change.

## Limits

- Only **hard failures** are detected (nonzero exit, timeout, empty
  output). A plausible-but-wrong answer is a soft failure — the
  delegating agent must sanity-check important results itself.
- `pi --print` blocks on stdin; the script always redirects `< /dev/null`.
- Reasoning models need generous `maxTokens` (≥16384) or they return
  empty content.
