- 👋 Hi, I’m Greg
- 👀 I’m interested in software engineering, dogs and video games.
- 🌱 I’m currently learning React and TypeScript
- 💞️ I’m looking to collaborate on ...
- 📫 How to reach me ...

## Something I particularly find useful

Nine numbered PowerShell macros that survive closing the terminal. After I run a command worth keeping, `sm3` saves it. `rm3` replays it in any later session. `wm3` shows what’s in the slot without running it.

This is for commands that are too specific to become a permanent alias, but too annoying to retype. `Ctrl+R` history is chronological and full of near-misses. These are nine sticky slots you choose.

The flow is: run the command, then `smN`. Slots are `1`–`9`. Bindings persist in `~/profile/macros.json`. Overwrite a slot by running a new command and `smN` again.

### Why it helps

A test filter you just got right. You don’t want that as a forever alias, and you don’t want to hunt it in history tomorrow.

```powershell
dotnet test .\tests\Foo.Tests --filter "FullyQualifiedName~Portage" -v n
sm1          # save the last command into slot 1
# close the terminal, come back next day
wm1          # peek first if you’re not sure what’s in the slot
rm1          # replay it
```

A one-liner for the repo you’re in this week.

```powershell
gh pr checks --watch
sm2
rm2          # later, same watch, no retyping
```

A long remote or container command.

```powershell
ssh user@build-box 'cd /srv/app && docker compose logs -f --tail 100 api'
sm3
```

| | Save last command | Replay | Peek |
| --- | --- | --- | --- |
| Slot 1 | `sm1` | `rm1` | `wm1` |
| Slot 2 | `sm2` | `rm2` | `wm2` |
| … | … | … | … |
| Slot 9 | `sm9` | `rm9` | `wm9` |

Drop this in your PowerShell 7 `$PROFILE`:

```powershell
# Custom Persistent Macros
$macroFile = Join-Path $HOME 'profile\macros.json'

if (Test-Path $macroFile) {
    $macros = Get-Content $macroFile -Raw | ConvertFrom-Json -AsHashtable
}
else {
    $macros = @{}
}

function Save-MacrosToDisk {
    # Convert keys to strings so JSON is happy
    $dir = Split-Path -Parent $macroFile
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $toSave = @{}
    $macros.GetEnumerator() | ForEach-Object { $toSave["$($_.Key)"] = $_.Value }
    $toSave | ConvertTo-Json | Set-Content $macroFile
}

1..9 | ForEach-Object {
    $n = "$_"   # string key
    Set-Item -Path "function:sm$n" -Value {
        $macros[$n] = (Get-History -Count 1).CommandLine
        Save-MacrosToDisk
    }.GetNewClosure()

    Set-Item -Path "function:rm$n" -Value {
        if ($macros[$n]) { Invoke-Expression $macros[$n] } else { "No macro $n" }
    }.GetNewClosure()

    Set-Item -Path "function:wm$n" -Value {
        if ($macros[$n]) { $macros[$n] } else { "No macro $n" }
    }.GetNewClosure()
}
```

Same snippet as a file: [`powershell/persistent-macros.ps1`](powershell/persistent-macros.ps1).

<!---
greg-lundgren/greg-lundgren is a ✨ special ✨ repository because its `README.md` (this file) appears on your GitHub profile.
You can click the Preview link to take a look at your changes.
--->
