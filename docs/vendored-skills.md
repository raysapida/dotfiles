# Vendored skills

Copied from plugin installs and local skill directories so every agent and
machine can use them through `skills/` and `bin/link-skills`. To update, copy
the newer upstream `skills/<name>/` directory over the one here and update
the corresponding provenance entry below.

| Skill | Upstream | Version | Commit | License |
|-------|----------|---------|--------|---------|
| `learning-opportunities` | https://github.com/DrCatHicks/learning-opportunities (Dr. Cat Hicks) | 1.0.0 | `3862d2eb6e93427f1f163a54360d11ef943b88b7` | CC-BY-4.0 |
| `orient` | https://github.com/mcmullarkey/orient (Dr. Michael Mullarkey) | 1.0.0 | `053b93afc4c788a84612c123eb9d629206eb5d4d` | not stated |

`orient` still says to invoke it as `/orient:orient` (its plugin name); from
`skills/` it is `/orient`. It writes `orientation.md` into each project's own
`.claude/skills/`, not into this checkout.

## Imports from the raysapida Mac (2026-11-22)

Imported 29 additional skills from `~/.agents/skills/`, including all bundled
references, scripts and agent metadata. Existing repository skills were retained.
AWS copies in `~/.claude/skills/` matched the shared copies byte for byte.

| Skill | Local provenance | Installed version/hash |
|-------|------------------|------------------------|
| `amazon-bedrock` | AWS skill distribution; original `.aws-skill-metadata` retained | `v8` |
| `aws-ai-ml` | AWS skill distribution; original `.aws-skill-metadata` retained | `v6` |
| `aws-auth` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `aws-billing-and-cost-management` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `aws-blocks` | AWS skill distribution; original `.aws-skill-metadata` retained | `v2` |
| `aws-cdk` | AWS skill distribution; original `.aws-skill-metadata` retained | `v2` |
| `aws-cloudformation` | AWS skill distribution; original `.aws-skill-metadata` retained | `v3` |
| `aws-compute` | AWS skill distribution; original `.aws-skill-metadata` retained | `v2` |
| `aws-containers` | AWS skill distribution; original `.aws-skill-metadata` retained | `v6` |
| `aws-database` | AWS skill distribution; original `.aws-skill-metadata` retained | `v3` |
| `aws-deployment` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `aws-iam` | AWS skill distribution; original `.aws-skill-metadata` retained | `v3` |
| `aws-investigation` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `aws-messaging-and-streaming` | AWS skill distribution; original `.aws-skill-metadata` retained | `v4` |
| `aws-networking` | AWS skill distribution; original `.aws-skill-metadata` retained | `v2` |
| `aws-observability` | AWS skill distribution; original `.aws-skill-metadata` retained | `v11` |
| `aws-sdk-js-v3-usage` | AWS skill distribution; original `.aws-skill-metadata` retained | `v2` |
| `aws-sdk-python-usage` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `aws-sdk-swift-usage` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `aws-security` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `aws-serverless` | AWS skill distribution; original `.aws-skill-metadata` retained | `v6` |
| `aws-storage` | AWS skill distribution; original `.aws-skill-metadata` retained | `v2` |
| `aws-well-architected-review` | AWS skill distribution; original `.aws-skill-metadata` retained | `v2` |
| `launch-with-aws` | AWS skill distribution; original `.aws-skill-metadata` retained | `v5` |
| `signing-in-to-aws` | AWS skill distribution; original `.aws-skill-metadata` retained | `v1` |
| `claude-handoff` | `mattpocock/skills` / `skills/in-progress/claude-handoff/SKILL.md` | Folder hash `b312afac556f7229717dbd9b786d77bc160c8649` |
| `research` | `mattpocock/skills` / `skills/engineering/research/SKILL.md` | Folder hash `972a34cd8128b7952b7eb279b06715862db906a7` |
| `wayfinder` | `mattpocock/skills` / `skills/engineering/wayfinder/SKILL.md` | Folder hash `48c3a8b0a9705d6310d37f7f9b53bcb2c55955c7` |
| `docker-view` | Local custom skill from `~/.agents/skills/docker-view/` | Snapshot 2026-11-22 |

AWS versions above come from the installed metadata, not a fresh upstream check.
The Matt Pocock folder hashes come from the local skills installer lockfile.
No licenses were inferred or added for these local imports.

Only missing skill directories were imported. Existing variants of `branch-diff`,
`handoff`, `improve-codebase-architecture`, `prototype`, `tdd`, `codex-handoff`,
`opencode-handoff`, and `rails-expert` differed on this machine; `graphify` also
had a local version marker. The repository copies remain canonical, and running
`bin/link-skills --backup-existing` preserves the installed copies privately
before replacing their entries with links.

gstack and its generated skill wrappers remain installer-managed because they
depend on its full runtime. Synced skills and Codex system/plugin skills also
remain with their installers rather than being copied into this repository.
