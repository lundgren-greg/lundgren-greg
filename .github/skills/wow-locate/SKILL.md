---
name: wow-locate
description: >
  Find the player's last known in-game location via the GrokLocate addon
  (SavedVariables + optional chat log). Reports character, realm, zone, map ID,
  and coordinates. Use when the user asks where they are, "locate me", player
  position, current zone, "/wow-locate", "/locate", or when navigation help
  needs a live/last position. Requires GrokLocate installed in the WoW client.
metadata:
  short-description: "Locate player from GrokLocate addon data"
---

# /wow-locate — Where is the player?

Read the **GrokLocate** addon output from disk and report the last known
position (zone, map, coords, character, realm).

## Usage

`/wow-locate`  
`/locate`  
Or natural language: “where am I”, “locate my character”, “what zone am I in”.

## Prerequisites

Addon path (MoP example):

`…\World of Warcraft\_classic_\Interface\AddOns\GrokLocate\`

In-game:

1. Enable **GrokLocate** on the character select AddOns list.
2. Log in — it snapshots on login and every zone change.
3. Optional but recommended: type **`/chatlog`** once (logs chat to `Logs\WoWChatLog*.txt` so position lines can appear without reload).
4. To force a disk flush of SavedVariables: **`/gloc`** then **`/reload`** (or logout).

Slash commands (addon):

| Command | Effect |
|---------|--------|
| `/gloc` | Snapshot now + print parseable `GRLOC|…` line |
| `/gloc status` | Show last snapshot |
| `/gloc quiet` | Toggle zone-change chat announces |
| `/gloc pulse on` | Background snapshot every ~60s (SavedVariables; still needs reload to flush) |

## Steps

### 1. Run the locator script

```powershell
powershell -NoProfile -File "$env:USERPROFILE\.grok\skills\wow-locate\scripts\Get-WowPlayerLocation.ps1"
```

Optional:

```powershell
powershell -NoProfile -File "$env:USERPROFILE\.grok\skills\wow-locate\scripts\Get-WowPlayerLocation.ps1" -Client classic
powershell -NoProfile -File "$env:USERPROFILE\.grok\skills\wow-locate\scripts\Get-WowPlayerLocation.ps1" -Json
```

### 2. If script finds nothing

1. Confirm client: prefer `_classic_` for MoP (newest `Logs\` / WTF activity).
2. Confirm folder exists: `Interface\AddOns\GrokLocate\GrokLocate.toc`
3. Confirm SV path after at least one `/reload` or logout:

   `WTF\Account\<ACCOUNT>\SavedVariables\GrokLocate.lua`

4. Ask user to run **`/gloc`** then **`/reload`** in-game, then re-run the script.

### 3. Also check chat log (live-ish)

If `/chatlog` is on, grep client logs for `GRLOC|`:

- `<client>\Logs\WoWChatLog*.txt`
- or `Logs\*Chat*`

Prefer the **newest** line.

### 4. Report format

Keep it short:

| Field | Example |
|-------|---------|
| Character | Spyderbro-Ra-den |
| Faction / level / class | Alliance 90 WARRIOR |
| Zone / subzone | Shattrath City / Terrace of Light |
| Map ID | 530 |
| Coords | 54.2, 44.8 (percent) |
| Instance | none / party / raid |
| As of | timestamp + source file mtime |
| Staleness | warn if SV file is old (>30–60 min) while they claim to be playing |

### 5. Use the position

When helping with navigation (portals, hubs, quests):

- **Map 530** → Outland (Shattrath, etc.)
- **Map 870** → Pandaria
- **Map 0 / 1** → EK / Kalimdor
- Combine with `wow-logs` skill if they also have disconnects / wrong portal issues
- Do **not** invent a more precise location than coords/zone provide

## Data sources (priority)

1. **`GrokLocate.lua` SavedVariables** `last` / `lastLine` (newest mtime across accounts)
2. **Chat log** lines starting with `GRLOC|`
3. Fallback only: `Client.log` map id from `Load Map Begin` (zone name unknown) via `wow-logs`

## Install / repair addon

If missing, recreate under the active client’s `Interface\AddOns\GrokLocate\`:

- `GrokLocate.toc` — `## Interface: 50504` (MoP), `## SavedVariables: GrokLocateDB`
- `GrokLocate.lua` — from the installed copy next to this skill if present, or the MoP AddOns tree

Canonical install used on this machine:

`C:\Program Files\Battlenet\World of Warcraft\_classic_\Interface\AddOns\GrokLocate\`

## Safety

- Read-only for locate operations (do not edit WTF unless fixing corruption)
- Do not upload location data externally unless the user asks
