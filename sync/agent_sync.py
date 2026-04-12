#!/usr/bin/env python3
"""
agent-sync: Sync agent definitions from a canonical source repo to target repositories.

Usage:
    python agent_sync.py [--config sync/config.yaml] [--dry-run] [--verbose]
    python agent_sync.py --list
    python agent_sync.py --diff <repo>
    python agent_sync.py --target <repo>

Requires:
    - GITHUB_TOKEN environment variable with repo access
    - PyYAML (pip install pyyaml)

The utility reads agent definition files from the local agents/ directory,
compares them against what's deployed in each target repository, and pushes
updates via the GitHub API (Contents API for file create/update).
"""

import argparse
import base64
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# GitHub API helpers
# ---------------------------------------------------------------------------

API_BASE = "https://api.github.com"


def github_headers(token: str) -> dict:
    return {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "agent-sync/1.0",
    }


def github_get(url: str, token: str):
    """GET request to GitHub API. Returns parsed JSON or None on 404."""
    req = urllib.request.Request(url, headers=github_headers(token))
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise


def github_put(url: str, token: str, payload: dict):
    """PUT request to GitHub API (for creating/updating file contents)."""
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers=github_headers(token), method="PUT")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_config(config_path: str) -> dict:
    with open(config_path, "r") as fh:
        return yaml.safe_load(fh)


def resolve_defaults(config: dict) -> dict:
    """Merge per-target settings with defaults."""
    defaults = config.get("defaults", {})
    for target in config.get("targets", []):
        for key in ("target_path", "branch", "strategy", "commit_message_prefix"):
            if key not in target:
                target[key] = defaults.get(key, {
                    "target_path": ".github/agents/",
                    "branch": "main",
                    "strategy": "overwrite",
                    "commit_message_prefix": "[agent-sync]",
                }[key])
    return config


# ---------------------------------------------------------------------------
# Agent file reading
# ---------------------------------------------------------------------------

def read_agent_file(agents_dir: str, filename: str) -> str:
    path = Path(agents_dir) / filename
    if not path.is_file():
        raise FileNotFoundError(f"Agent file not found: {path}")
    return path.read_text(encoding="utf-8")


def content_sha(text: str) -> str:
    """Compute the git blob SHA for content (same as GitHub uses)."""
    blob = f"blob {len(text.encode())}\0{text}".encode()
    return hashlib.sha1(blob).hexdigest()


# ---------------------------------------------------------------------------
# Sync logic
# ---------------------------------------------------------------------------

class SyncResult:
    def __init__(self, repo: str, agent: str):
        self.repo = repo
        self.agent = agent
        self.action = "skipped"  # created | updated | skipped | error
        self.message = ""

    def __repr__(self):
        return f"{self.repo}: {self.agent} -> {self.action} ({self.message})"


def sync_agent_to_repo(
    token: str,
    agent_filename: str,
    agent_content: str,
    target_repo: str,
    target_path: str,
    branch: str,
    strategy: str,
    commit_prefix: str,
    dry_run: bool = False,
    verbose: bool = False,
) -> SyncResult:
    result = SyncResult(target_repo, agent_filename)
    file_path = target_path.rstrip("/") + "/" + agent_filename
    url = f"{API_BASE}/repos/{target_repo}/contents/{file_path}?ref={branch}"

    if verbose:
        print(f"  Checking {target_repo}:{file_path} on branch {branch}")

    existing = github_get(url, token)

    if existing is not None:
        # File exists — compare content
        existing_content = base64.b64decode(existing["content"]).decode("utf-8")
        if existing_content == agent_content:
            result.action = "skipped"
            result.message = "already up to date"
            return result

        if strategy == "skip":
            result.action = "skipped"
            result.message = "file exists, strategy=skip"
            return result

        # Update
        if dry_run:
            result.action = "would update"
            result.message = "content differs"
            return result

        payload = {
            "message": f"{commit_prefix} Update {agent_filename}",
            "content": base64.b64encode(agent_content.encode()).decode(),
            "sha": existing["sha"],
            "branch": branch,
        }
        github_put(
            f"{API_BASE}/repos/{target_repo}/contents/{file_path}",
            token,
            payload,
        )
        result.action = "updated"
        result.message = "content updated"
    else:
        # File does not exist — create
        if dry_run:
            result.action = "would create"
            result.message = "file does not exist"
            return result

        payload = {
            "message": f"{commit_prefix} Add {agent_filename}",
            "content": base64.b64encode(agent_content.encode()).decode(),
            "branch": branch,
        }
        github_put(
            f"{API_BASE}/repos/{target_repo}/contents/{file_path}",
            token,
            payload,
        )
        result.action = "created"
        result.message = "file created"

    return result


def run_sync(config: dict, token: str, dry_run: bool = False, verbose: bool = False, target_filter: str | None = None):
    source_dir = config.get("source", {}).get("agents_dir", "agents/")
    targets = config.get("targets", [])
    results: list[SyncResult] = []

    if not targets:
        print("No targets configured in sync/config.yaml. Add target repos to get started.")
        return results

    for target in targets:
        repo = target["repo"]
        if target_filter and repo != target_filter:
            continue

        agents = target.get("agents", [])
        if not agents:
            print(f"  WARN: No agents listed for {repo}, skipping")
            continue

        print(f"\nSyncing to {repo}:")
        for agent_file in agents:
            try:
                agent_content = read_agent_file(source_dir, agent_file)
                result = sync_agent_to_repo(
                    token=token,
                    agent_filename=agent_file,
                    agent_content=agent_content,
                    target_repo=repo,
                    target_path=target["target_path"],
                    branch=target["branch"],
                    strategy=target["strategy"],
                    commit_prefix=target["commit_message_prefix"],
                    dry_run=dry_run,
                    verbose=verbose,
                )
                results.append(result)
                status_icon = {
                    "created": "✅",
                    "updated": "🔄",
                    "skipped": "⏭️",
                    "would create": "🆕",
                    "would update": "📝",
                    "error": "❌",
                }.get(result.action, "?")
                print(f"  {status_icon} {result}")
            except Exception as exc:
                r = SyncResult(repo, agent_file)
                r.action = "error"
                r.message = str(exc)
                results.append(r)
                print(f"  ❌ {r}")

    return results


def list_agents(config: dict):
    source_dir = config.get("source", {}).get("agents_dir", "agents/")
    agents_path = Path(source_dir)
    if not agents_path.is_dir():
        print(f"Agents directory not found: {source_dir}")
        return
    print("Canonical agent definitions:\n")
    for f in sorted(agents_path.glob("*.md")):
        if f.name == "README.md":
            continue
        content = f.read_text()
        # Extract name from frontmatter
        name = f.stem
        version = "?"
        if content.startswith("---"):
            try:
                fm = yaml.safe_load(content.split("---")[1])
                name = fm.get("name", name)
                version = fm.get("version", version)
            except Exception:
                pass
        print(f"  {name} (v{version}) — {f.name}")

    print("\nTarget repositories:\n")
    targets = config.get("targets", [])
    if not targets:
        print("  (none configured — edit sync/config.yaml)")
    else:
        for t in targets:
            agents_str = ", ".join(t.get("agents", []))
            print(f"  {t['repo']}: {agents_str}")


def show_diff(config: dict, token: str, target_repo: str):
    source_dir = config.get("source", {}).get("agents_dir", "agents/")
    targets = config.get("targets", [])
    target = next((t for t in targets if t["repo"] == target_repo), None)
    if target is None:
        print(f"Repository {target_repo} not found in config targets.")
        return

    print(f"Comparing agents with {target_repo}:\n")
    for agent_file in target.get("agents", []):
        local_content = read_agent_file(source_dir, agent_file)
        file_path = target["target_path"].rstrip("/") + "/" + agent_file
        url = f"{API_BASE}/repos/{target_repo}/contents/{file_path}?ref={target['branch']}"
        remote = github_get(url, token)

        if remote is None:
            print(f"  {agent_file}: NOT PRESENT in target (would be created)")
        else:
            remote_content = base64.b64decode(remote["content"]).decode("utf-8")
            if remote_content == local_content:
                print(f"  {agent_file}: ✅ In sync")
            else:
                print(f"  {agent_file}: ⚠️  DIFFERS — local has changes not yet synced")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Sync agent definitions to target repositories via GitHub API.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python sync/agent_sync.py --list                     # List agents and targets
  python sync/agent_sync.py --dry-run                  # Preview what would change
  python sync/agent_sync.py                             # Sync all targets
  python sync/agent_sync.py --target owner/repo         # Sync a single target
  python sync/agent_sync.py --diff owner/repo           # Compare local vs remote
        """,
    )
    parser.add_argument("--config", default="sync/config.yaml", help="Path to sync config (default: sync/config.yaml)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change without making changes")
    parser.add_argument("--verbose", action="store_true", help="Show detailed output")
    parser.add_argument("--list", action="store_true", help="List all agents and target repos")
    parser.add_argument("--diff", metavar="REPO", help="Show diff between local and remote for a target repo")
    parser.add_argument("--target", metavar="REPO", help="Only sync to a specific target repo")

    args = parser.parse_args()

    config = load_config(args.config)
    config = resolve_defaults(config)

    if args.list:
        list_agents(config)
        return

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("ERROR: GITHUB_TOKEN environment variable is required.", file=sys.stderr)
        print("Create a fine-grained PAT with 'Contents: Read and write' for target repos.", file=sys.stderr)
        sys.exit(1)

    if args.diff:
        show_diff(config, token, args.diff)
        return

    results = run_sync(config, token, dry_run=args.dry_run, verbose=args.verbose, target_filter=args.target)

    # Summary
    if results:
        print("\n--- Summary ---")
        for r in results:
            print(f"  {r}")
        errors = [r for r in results if r.action == "error"]
        if errors:
            sys.exit(1)


if __name__ == "__main__":
    main()
