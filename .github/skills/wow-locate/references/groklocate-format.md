# GrokLocate data format

## SavedVariables

Path:

`WTF\Account\<ACCOUNT>\SavedVariables\GrokLocate.lua`

Important fields on `GrokLocateDB.last`:

- `ts` — ISO-like local time
- `player`, `realm`, `faction`, `level`, `class`
- `zone`, `subzone`, `minimapZone`
- `mapID`
- `x`, `y` — 0–1 map position
- `xPct`, `yPct` — 0–100 style (one decimal)
- `instanceType` — none / party / raid / …
- `reason` — event or slash that triggered snapshot

## Chat / print line

```
GRLOC|ts=...|player=...|realm=...|faction=...|level=...|class=...|zone=...|subzone=...|mapID=...|x=...|y=...|xPct=...|yPct=...|instance=...|reason=...
```

Enable with `/chatlog` so lines land under `Logs\`.
