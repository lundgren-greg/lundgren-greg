# Custom Persistent Macros
# Drop this in your PowerShell 7 $PROFILE.
#
# Sticky slots for commands that aren't worth an alias, but are worth
# keeping around for a day or a week. Run the command, then smN.
#
#   dotnet test .\tests\Foo.Tests --filter "FullyQualifiedName~Portage" -v n
#   sm1        # save the last command into slot 1
#   wm1        # peek at slot 1 without running it
#   rm1        # replay slot 1 (survives new sessions)
#
# Slots are 1-9. Change $macroFile if you want them stored somewhere else.

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
