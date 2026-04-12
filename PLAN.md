# Plan

## Phase 1: Foundation (current) ✅

- [x] Create canonical agent definitions directory (`agents/`)
- [x] Define GreatAgent as first canonical agent
- [x] Build sync utility (`sync/agent_sync.py`) with GitHub API integration
- [x] Create configuration format (`sync/config.yaml`)
- [x] Add GitHub Actions workflow for automated sync
- [x] Document usage in sync/README.md

## Phase 2: Integration

- [ ] Add first real target repo to `sync/config.yaml`
- [ ] Create `AGENT_SYNC_TOKEN` secret in this repo's settings
- [ ] Run first live sync (manually via workflow dispatch)
- [ ] Verify agent file appears correctly in target repo

## Phase 3: Enhancements

- [ ] Add version comparison — skip sync if target is already at same version
- [ ] Add changelog generation on version bumps
- [ ] Support branch-based sync (e.g., sync to PR branches for review before merge)
- [ ] Add a `--init` command to scaffold agent files in a new repo

## Blockers / Notes

- Sync requires a fine-grained PAT (`AGENT_SYNC_TOKEN`) with Contents read/write on each target repo
- This repo must be the single source of truth — never edit agent files in target repos directly
