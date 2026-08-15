---
name: wow-logs
description: >
  Locate and analyze World of Warcraft client logs (MoP Classic, Anniversary,
  Era, Retail). Builds session timelines, extracts errors/disconnects, maps
  zone IDs, lists characters from WTF, and correlates GPU/Windows lock events
  with gx.log. Use when the user asks to read WoW logs, debug disconnects,
  check client logs, diagnose lock/freeze during WoW, "/wow-logs", or
  "/read-wow-logs". Not for Warcraft Logs raid parses unless a URL is given.
metadata:
  short-description: "Read and diagnose WoW client logs"
---

# /wow-logs — Read WoW Client Logs

Analyze local World of Warcraft **client** logs on this machine. Default to the
product the user is playing (often MoP Classic `_classic_`).

## Usage

`/wow-logs [focus]`

Optional focus examples: `disconnects`, `gpu/lock`, `session`, `addons`, `outland`,
`errors`, or a character/realm name.

## Steps

### 1. Find installs

Run the helper (preferred) or discover paths manually:

```powershell
powershell -NoProfile -File "$env:USERPROFILE\.grok\skills\wow-logs\scripts\Find-WowLogs.ps1"
```

Common roots (Windows):

- `C:\Program Files\Battlenet\World of Warcraft`
- `D:\BattlenetLibrary\World of Warcraft`
- Other Battle.net library folders

Client folders:

| Folder | Product |
|--------|---------|
| `_classic_` | Progressive Classic (Cata/MoP) |
| `_classic_era_` | Classic Era |
| `_anniversary_` | Anniversary (TBC, etc.) |
| `_retail_` | Retail |

Read `.build.info` under each install for `Product` / `Version` lines.

Prefer the install whose `Logs\` files are **most recently written**.

### 2. Inventory log files

Under `<client>\Logs\`, prioritize:

| File | Use for |
|------|---------|
| `Client.log` | Map load, login/logout, loading screens |
| `General.log` | CVars, Lua screen switches, net client, errors |
| `Connection.log` / `WowConnection.log` | Login, realm join, disconnects |
| `gx.log` | GPU, present, background/foreground, re-enum |
| `Hotfix.log` | Hotfix apply (noise; note INVALID only if user asks) |
| `AccountData.log` | Account settings noise; `scriptErrors` |
| `FrameXML.log` | UI/XML load failures (if non-empty) |
| `Sound.log` / `Aurora.log` | Secondary |

Also check:

- `<client>\WTF\Account\*\**` — characters, realms, SavedVariables
- Combat logs: `Logs\WoWCombatLog*.txt` or root (only if Advanced Combat Logging was on)
- Do **not** invent combat/raid parse data if no combat log / no WCL URL

### 3. Build a session timeline

From `Client.log` + `Connection.log` + `General.log`:

1. Process start / glue login / realm join times
2. Character login (`Character Login SEND`, `Active Player Created`)
3. Map IDs from `Load Map Begin : <id>` — resolve via `references/map-ids.md`
4. Disconnect / `Handle Disconnect` / `Client Destroy` times
5. Duration in world

Present as a short table (time → event).

### 4. Extract real problems

Scan logs for actionable signals (not routine CVar noise):

```text
[E]   FATAL   ERROR   failed   exception   crash   assert
Handle Disconnect   KillConnection   VALIDATION_RESULT_INVALID (only if many/weird)
Gpu state has changed   App is background   Detected SwapChain
```

**Ignore as normal** unless the user is debugging settings:

- `CVar '…' failed validation for its initial value`
- Bulk Hotfix `VALIDATION_RESULT_*` spam
- `LimitedLuaResources` capacity lines

### 5. Correlate locks / freezes (when relevant)

If the user mentioned lock, freeze, black screen, or alt-tab issues:

1. Note Windows lock time if available (Security log 4800/4801) — optional
2. Align with `gx.log`: `App is background`, `Gpu state has changed. re-enumerating`
3. Explain: session lock / focus loss often triggers GPU re-enum; that is not necessarily a crash
4. Report GPU name, driver, VRAM budget lines from `gx.log` if present

### 6. Characters and realms

From `WTF\Account\<account>\`:

- List realm folders and character folders
- Note if both a dead realm (e.g. Benediction) and mega realm (e.g. Ra-den) exist
- Do not dump full SavedVariables

### 7. Report format

Keep the user-facing report tight:

1. **Which client** (path, product, version, last log time)
2. **Session timeline** table
3. **Where they were** (map ID → zone name)
4. **Issues found** (or “no crash-level errors”)
5. **Hardware/GPU note** only if relevant
6. **What’s missing** (no combat log, no Lua error dump, etc.)
7. **Next step** if debugging continues (enable combat log, BugGrabber, etc.)

### 8. Optional helper deep-dive

For a structured dump of the active client:

```powershell
powershell -NoProfile -File "$env:USERPROFILE\.grok\skills\wow-logs\scripts\Find-WowLogs.ps1" -Summarize
```

Read the script output, then open specific log files with the file-read tool for detail.

## Focus modes

| Focus | Emphasize |
|-------|-----------|
| `disconnects` | Connection.log, KillConnection, Handle Disconnect |
| `gpu` / `lock` | gx.log + Windows 4800/4801 if needed |
| `session` | Client.log map/login timeline |
| `addons` | FrameXML.log, script errors, WTF SavedVariables names only |
| `errors` | All `[E]` / ERROR lines across Logs |

## Warcraft Logs (web)

Only if the user pastes a **Warcraft Logs** (or similar) URL: fetch/analyze that report.
Do not claim to have raid parses from client `Logs\` alone.

## Safety

- Do not upload logs externally unless the user asks
- Do not modify WTF/config unless asked to fix something
- Redact emails/tokens if any appear in logs (rare)
