# Agent Sync Utility

Syncs canonical agent definitions from this repository to target repositories using the GitHub API.

## Quick Start

```bash
# List all agents and configured targets
python sync/agent_sync.py --list

# Preview what would change (no writes)
python sync/agent_sync.py --dry-run

# Sync all targets
GITHUB_TOKEN=ghp_xxx python sync/agent_sync.py

# Sync a single target
GITHUB_TOKEN=ghp_xxx python sync/agent_sync.py --target lundgren-greg/quake2-server

# Compare local vs what's deployed
GITHUB_TOKEN=ghp_xxx python sync/agent_sync.py --diff lundgren-greg/quake2-server
```

## Requirements

- Python 3.10+
- `pyyaml` (`pip install pyyaml`)
- A GitHub fine-grained PAT with **Contents: Read and write** permission on target repos

## How It Works

1. Reads agent definitions from `agents/*.md` (YAML frontmatter + markdown body)
2. Reads `sync/config.yaml` to determine which agents go to which repos
3. Uses the [GitHub Contents API](https://docs.github.com/en/rest/repos/contents) to compare and update files
4. Creates or updates agent files in target repos, committing directly to the configured branch

```
lundgren-greg/lundgren-greg (this repo)
  agents/
    great-agent.md          ← canonical source of truth
  sync/
    config.yaml             ← maps agents → target repos
    agent_sync.py           ← the sync utility

        ┌──── GitHub API ────┐
        ▼                    ▼
lundgren-greg/quake2-server  lundgren-greg/another-project
  .github/agents/              .copilot/agents/
    great-agent.md               great-agent.md
```

## Configuration

Edit `sync/config.yaml`:

```yaml
defaults:
  target_path: ".github/agents/"
  branch: "main"
  strategy: "overwrite"        # "overwrite" or "skip"
  commit_message_prefix: "[agent-sync]"

targets:
  - repo: "lundgren-greg/quake2-server"
    agents:
      - great-agent.md
    # target_path, branch, strategy inherit from defaults unless overridden
```

### Per-Target Overrides

```yaml
targets:
  - repo: "lundgren-greg/special-project"
    agents:
      - great-agent.md
    target_path: ".copilot/agents/"   # custom destination path
    branch: "develop"                  # target a different branch
    strategy: "skip"                   # don't overwrite if file already exists
```

## Automated Sync (GitHub Actions)

The workflow at `.github/workflows/agent-sync.yml` runs automatically when agent definitions change. It can also be triggered manually from the Actions tab.

## Adding a New Agent

1. Create `agents/my-new-agent.md` with YAML frontmatter:
   ```yaml
   ---
   name: "MyAgent"
   description: "What this agent does"
   tools: [read, edit, search]
   version: "1.0.0"
   source: "lundgren-greg/lundgren-greg"
   ---
   ```
2. Write agent instructions in the markdown body
3. Add to `sync/config.yaml` targets
4. Push — the workflow syncs automatically
