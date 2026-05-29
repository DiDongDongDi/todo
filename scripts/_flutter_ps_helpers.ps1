# Shared helpers for check_*_env.ps1 (dot-source only)

function Initialize-ScriptConsoleUtf8 {
    try {
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [Console]::OutputEncoding = $utf8
        [Console]::InputEncoding = $utf8
        $global:OutputEncoding = $utf8
        chcp 65001 | Out-Null
    } catch {
        # Older hosts may reject chcp; checks still run
    }
}

function Get-FlutterLineText {
    param($Item)
    if ($Item -is [System.Management.Automation.ErrorRecord]) {
        return $Item.ToString()
    }
    return "$Item"
}

function Get-FlutterOutput {
    param([Parameter(Mandatory)][string[]]$FlutterArgs)
    $lines = [System.Collections.Generic.List[string]]::new()
    & flutter @FlutterArgs 2>&1 | ForEach-Object {
        $lines.Add((Get-FlutterLineText $_))
    }
    return $lines
}

function Write-FlutterOutput {
    param([Parameter(Mandatory)][string[]]$FlutterArgs)
    foreach ($line in (Get-FlutterOutput -FlutterArgs $FlutterArgs)) {
        if ($line -match 'Flutter assets will be downloaded from') {
            Write-Host "       $line" -ForegroundColor DarkGray
        } else {
            Write-Host $line
        }
    }
}
