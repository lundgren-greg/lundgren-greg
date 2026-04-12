# Agent Definitions

This directory contains canonical agent definitions that are synced to other repositories using the **agent-sync** utility.

## How It Works

Each `.md` file in this directory defines an agent with:
- **YAML frontmatter** — metadata (name, description, tools, version, source repo)
- **Markdown body** — the full agent prompt/instructions

The sync utility reads these definitions and pushes them to configured target repositories, placing them at the correct path for each project (e.g., `.github/agents/`, `.github/copilot/`, or a custom path).

## Adding a New Agent

1. Create a new `.md` file in this directory (e.g., `my-agent.md`)
2. Include YAML frontmatter with at minimum: `name`, `description`, `version`
3. Write the agent instructions in the markdown body
4. Add target repository mappings in `sync/config.yaml`
5. Push — the GitHub Actions workflow will sync automatically

## Current Agents

| Agent | Description | Version |
|-------|-------------|---------|
| [GreatAgent](great-agent.md) | Development execution agent with progress tracking | 1.0.0 |
