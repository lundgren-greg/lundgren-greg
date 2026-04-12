# Features

## Agent Sync Utility

- [x] Canonical agent definition storage (`agents/` directory)
- [x] GreatAgent — development execution agent with progress tracking (v1.0.0)
- [x] YAML-based sync configuration (`sync/config.yaml`)
- [x] Python sync script using GitHub Contents API (`sync/agent_sync.py`)
  - [x] `--list` — show all agents and configured targets
  - [x] `--dry-run` — preview changes without writing
  - [x] `--diff <repo>` — compare local vs deployed state
  - [x] `--target <repo>` — sync a single target repo
  - [x] `--verbose` — detailed output
  - [x] Create / update / skip strategies
- [x] GitHub Actions workflow for automated sync on push
  - [x] Triggered on changes to `agents/` or `sync/config.yaml`
  - [x] Manual dispatch with dry-run and target options

## Planned

- [ ] Agent versioning — detect version bumps and generate changelogs
- [ ] Multi-agent composition — allow agents to reference other agents
- [ ] Pull-based sync — target repos can pull latest agent from source
- [ ] Agent diff viewer — side-by-side comparison in CLI output
- [ ] Support for non-markdown agent formats (YAML-only, JSON)
