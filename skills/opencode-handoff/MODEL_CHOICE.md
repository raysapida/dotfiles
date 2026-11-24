# opencode-handoff: choosing DeepSeek V4 Pro, GLM-5.3 or Inkling 2 Small per handoff

Changed 2026-11-22. Before this, every handoff ran on opencode's configured default
(`ollama-cloud/glm-5.3`) unless the user named a model. Now Claude asks which model to use
on each handoff and recommends one based on Ollama Cloud's peak hours.

## The three options

| Model | opencode id | Why it's an option |
| --- | --- | --- |
| DeepSeek V4 Pro | `ollama-cloud/deepseek-v4-pro` (unpinned, follows DeepSeek's latest V4 Pro) | Best of the open models on repo bug-fixing (DeepSWE 77.0% vs GLM 66.9%). Half price off-peak on Ollama Cloud ($0.66 / $1.98 per 1M; $1.32 / $3.96 at peak). |
| GLM-5.3 | `ollama-cloud/glm-5.3` | Leads on Terminal-Bench 3.0 and CyberGym. Same price at any hour ($1.40 / $4.40). Known to cut out on responses that stream ~3 min, so prompts ask for small writes. |
| Inkling 2 Small (on trial) | `ollama-cloud/inkling-2-small` | Cheapest at any hour ($0.30 / $1.00 per 1M, cached input $0.03; ~$0.48 blended at 3:1 input:output). Overall index 31, about GLM's level; DeepSWE 72.1% (vendor-reported). Open weights (Apache 2.0), 594B MoE / 17B active, up to 1M context. Always offered third, never the default, until a trial week shows how well it follows plans. |

Kimi K3.1 Pro scored highest overall (Artificial Analysis index 46 vs 33/32/31) but costs 2–8× more
($2 / $10 per 1M tokens), so it isn't offered.

## Ollama Cloud peak hours

- **Peak:** weekdays 12:00–18:00 UTC (7am–1pm EDT / 8am–2pm EST).
- **Off-peak:** the rest of each weekday, and all of Saturday and Sunday.
- Only some DeepSeek models have an off-peak rate (half price). GLM and Inkling don't.

Source: third-party summaries of ollama.com/pricing, checked 2026-11-22. Confirm on the pricing
page if the windows matter.

## Default rule

- Off-peak → recommend **DeepSeek V4 Pro** (half price and strong at coding).
- Peak → recommend **GLM-5.3** (DeepSeek at full price loses its cost edge).
- **Inkling 2 Small** is always listed third ("cheapest at any hour; on trial").

## What changed in the skill

- **New `scripts/pick_model.py`** (`[--json]`): prints the recommended model, the alternatives
  (GLM or DeepSeek, then Inkling), and why, from the current UTC time. Edit its `DEEPSEEK` / `GLM` /
  `INKLING` constants to offer other models.
- **SKILL.md step 3** is now "Choose the session and the model": run `sessions.py` and
  `pick_model.py`, then ask both questions in one AskUserQuestion call, with the recommendation
  listed first as "(Recommended)" and its reason in the description. The model question is skipped
  if the user already named a model.
- **Inkling trial:** after each Inkling run, record in `lessons/<project>.md` how it followed the
  plan: STOPs honoured, scope kept, report accuracy, stream cutoffs, retries.
- **SKILL.md step 5:** always pass `--model <chosen model>` to `launch.sh`; continuations keep the
  same model unless the user changes it.
- **Trigger description** now mentions DeepSeek and Inkling as well as GLM.
- **Session choice (step 3):** continue the project's existing session when the model is the same
  as last time (fresh sessions re-read AGENTS.md, the plan and the code; several fresh GLM-5.3
  sessions on one codebase burned tokens); start a new one when switching models or when the
  history passes roughly 150–200K tokens or got messy. `sessions.py` now shows each session's last
  handoff model, read from `launch.sh`'s logs, since opencode doesn't record it.
- **Plan check (step 2b, EXPERIMENTAL):** `scripts/plan_check.sh` has
  `ollama-cloud/deepseek-v4.1-flash` (~$0.30 / $1.20 per 1M) read the plan before launch with
  opencode's read-only `plan` agent in an archived session, and list ambiguous steps, stale
  file:line quotes, vague Verify output and missing STOPs. Findings are suggestions Claude checks;
  it never replaces Claude's review. A git-state guard exits 3 (`PLAN CHECK CHANGED THE REPO`) if
  the repo changed. `launch.sh` gained `--agent` and `--archived` for it. Smoke test 2026-11-24
  (opencode v2.3.2, scratch repo, plan with four planted flaws): it found all four plus three real
  gaps (missing `tests/` dir, Verify ignoring AGENTS.md's pytest command, an import-path trap) in
  ~13 s, and the repo stayed unchanged. The `plan` agent denies the edit tool, but its shell
  inherits the project's `"*": "allow"`, so a shell redirect could still write. When asked to
  write, the model refused on its own; the git guard (tested with a stub `opencode`) is the real
  backstop. Usefulness is recorded in lessons files to
  decide whether it stays.
- **SETUP.md** regenerated; `make_setup_doc.py` lists `pick_model.py` and `plan_check.sh`.

## Data handling (Ollama Cloud)

Ollama says cloud prompts are processed only long enough to answer, never logged or trained on,
and that its NVIDIA cloud hosting partners must keep zero data retention. Its Inkling 2 Small launch
post says "zero data retention". Inkling's weights are open, so Ollama hosts it without Thinking
Machines; no data-sharing deal between them was found. These are contractual promises, not technical
guarantees: prompts still leave the machine. Check client contracts before sending client code.

## Open questions

- The small-writes rule exists because of GLM's stream cutoff. Untested whether DeepSeek V4 Pro or
  Inkling 2 Small has the same problem; keep the rule in prompts until a run shows it isn't needed.
- Whether Ollama passes on cached-input discounts (Inkling's $0.03) under its credit pool is unknown.
- Resolved 2026-11-22: the account still has session usage limits (a test run got
  `provider.quota` 429 "reached your session usage limit"), despite one article saying Ollama moved
  to a monthly credit pool with no session caps.
- Other candidates from the Ollama Cloud catalogue (not yet offered): DeepSeek V4.1 Flash and
  MiniMax M3 as budget executors (claimed coding near or above V4 Pro at ~$0.30 / $1.20); a
  same-phase bake-off against Inkling would decide.
