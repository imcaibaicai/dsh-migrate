<#
.SYNOPSIS
    DeepSeek Harness (DSH) Cross-Machine Migration & Backup Engine
    DeepSeek Harness Cross-Machine Migration & Backup Core Engine

.DESCRIPTION
    A zero-dependency PowerShell automation utility designed to export and restore
    DeepSeek Harness complete state across Windows machines.
    Supports core program mods (app.asar & office-skills), user brains (.dsh),
    workspace path remapping, and sensitive credential isolation.

.PARAMETER Command
    The action to execute: 'export', 'restore', 'doctor', or 'help'.

.PARAMETER BundlePath
    The target/source zip archive path. Default: ".\dsh-bundle.zip".

.PARAMETER Mode
    Export security mode: 'Private' (full backup with credentials & sessions)
    or 'Sanitize' (clean template: skills, agents, configs only; strips API keys).

.PARAMETER DryRun
    Simulate the migration without modifying files or creating archives.

.PARAMETER Force
    Suppress confirmation prompts and automatically stop conflicting processes.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
    [ValidateSet("export", "restore", "doctor", "help")]
    [string]$Command = "help",

    [Parameter(Position=1, Mandatory=$false)]
    [string]$BundlePath = ".\dsh-bundle.zip",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Private", "Sanitize")]
    [string]$Mode = "Private",

    [Parameter(Mandatory=$false)]
    [string]$DshHome = "",

    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "",

    [Parameter(Mandatory=$false)]
    [string]$TargetWorkspaceDir = "",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ==============================================================================
# Terminal UI Helper
# ==============================================================================
function Write-Banner {
    Write-Host @"
================================================================
   ____   _____ _    _   __  __ _                  _       
  |  _ \ / ____| |  | | |  \/  (_)                | |      
  | | | | (___ | |__| | | \  / |_  __ _ _ __ __ _| |_ ___ 
  | | | |\___ \|  __  | | |\/| | |/ _` | '__/ _` | __/ _ \
  | |_| |____) | |  | | | |  | | | (_| | | | (_| | ||  __/
  |____/|_____/|_|  |_| |_|  |_|_|\__, |_|  \__,_|\__\___|
                                   __/ |                  
                                  |___/   v1.0.0          
  DeepSeek Harness Cross-Machine Migration & Backup Utility
================================================================
"@ -ForegroundColor Cyan
}

function Write-Info([string]$msg)    { Write-Host "[INFO] $msg" -ForegroundColor Gray }
function Write-Success([string]$msg) { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg)    { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg)     { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Step([string]$msg)    { Write-Host "`n--> $msg" -ForegroundColor Cyan }

# ==============================================================================
# Environment Detection Engine
# ==============================================================================
function Get-DshLocations {
    $resolvedDshHome = if ($DshHome) { $DshHome } else { Join-Path $env:USERPROFILE ".dsh" }
    
    # Locate install directory
    $resolvedInstallDir = $InstallDir
    if (-not $resolvedInstallDir) {
        $candidates = @(
            "D:\Program Files (x86)\DeepSeekHarness",
            "$env:ProgramFiles(x86)\DeepSeekHarness",
            "$env:ProgramFiles\DeepSeekHarness",
            "$env:LOCALAPPDATA\Programs\DeepSeekHarness"
        )
        foreach ($c in $candidates) {
            if ($c -and (Test-Path $c)) {
                $resolvedInstallDir = $c
                break
            }
        }
    }

    # Locate official updater installer
    $installerPath = ""
    $installerCandidates = @(
        "$env:LOCALAPPDATA\@deepseek-aidsh-desktop-updater\installer.exe",
        "$env:USERPROFILE\AppData\Local\@deepseek-aidsh-desktop-updater\installer.exe"
    )
    foreach ($cand in $installerCandidates) {
        if (Test-Path $cand) {
            $installerPath = $cand
            break
        }
    }

    # Desktop preferences
    $roamingSettings = Join-Path $env:APPDATA "DeepSeek Harness\settings.json"

    [PSCustomObject]@{
        DshHome          = $resolvedDshHome
        InstallDir       = $resolvedInstallDir
        InstallerPath    = $installerPath
        RoamingSettings  = $roamingSettings
    }
}

function Ensure-DshStopped {
    $processes = Get-Process -Name "*DeepSeek*", "*dsh*" -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Warn "Detected active DeepSeek Harness process(es):"
        $processes | ForEach-Object { Write-Host "   - Process ID: $($_.Id), Name: $($_.ProcessName)" -ForegroundColor Yellow }
        
        if ($Force -or ($DryRun)) {
            if (-not $DryRun) {
                Write-Info "Force-terminating DSH processes to release file locks..."
                $processes | Stop-Process -Force
                Start-Sleep -Seconds 1
                Write-Success "All conflicting processes terminated."
            } else {
                Write-Info "[DryRun] Would terminate conflicting processes."
            }
        } else {
            $choice = Read-Host "Stop these processes now to continue? (Y/N)"
            if ($choice -match "^[yY]") {
                $processes | Stop-Process -Force
                Start-Sleep -Seconds 1
                Write-Success "All conflicting processes terminated."
            } else {
                throw "Migration aborted: DeepSeek Harness processes must be closed."
            }
        }
    }
}

# ==============================================================================
# Command: EXPORT (Pack source machine state)
# ==============================================================================
function Invoke-Export {
    Write-Step "Starting Export Operation (Mode: $Mode)"
    $locs = Get-DshLocations

    if (-not (Test-Path $locs.DshHome)) {
        throw "DSH data directory (.dsh) not found at: $($locs.DshHome)"
    }

    Write-Info "Detected DSH Home     : $($locs.DshHome)"
    Write-Info "Detected Install Dir  : $(if ($locs.InstallDir) { $locs.InstallDir } else { '(Not found/Optional)' })"
    Write-Info "Detected Installer    : $(if ($locs.InstallerPath) { $locs.InstallerPath } else { '(Not found/Optional)' })"
    Write-Info "Target Bundle Output  : $(Resolve-Path -Path (Split-Path $BundlePath -Parent) -ErrorAction SilentlyContinue | Join-Path -ChildPath (Split-Path $BundlePath -Leaf))"

    if ($Mode -eq "Private") {
        Write-Host "`n----------------------------------------------------------------" -ForegroundColor Magenta
        Write-Warn "[SECURITY WARNING] Mode is 'Private'!"
        Write-Warn "The generated bundle will contain your plaintext API Keys (.credentials.yaml)"
        Write-Warn "and complete session histories. NEVER upload this bundle to GitHub or public hosts!"
        Write-Host "----------------------------------------------------------------`n" -ForegroundColor Magenta
    } else {
        Write-Success "Mode is 'Sanitize'. API credentials and session histories will be stripped."
    }

    if ($DryRun) {
        Write-Success "[DryRun] Export validation passed. No archive created."
        return
    }

    $tempDir = Join-Path $env:TEMP "dsh_export_$(Get-Random)"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    New-Item -ItemType Directory -Path "$tempDir\DotDsh", "$tempDir\ProgramFiles_DSH", "$tempDir\AppData_Roaming" -Force | Out-Null

    try {
        # 1. Package .dsh
        Write-Step "Packaging DSH user directory (.dsh)..."
        $excludeItems = @("logs", "video-cache", "sessions-quarantine-v0-20260930")
        if ($Mode -eq "Sanitize") {
            $excludeItems += @(".credentials.yaml", "sessions", "session-query", "session_projcache")
        }

        Get-ChildItem -Path $locs.DshHome -Force | Where-Object { $_.Name -notin $excludeItems } | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination "$tempDir\DotDsh\$($_.Name)" -Recurse -Force
        }

        # 2. Package Program Files mods
        if ($locs.InstallDir -and (Test-Path $locs.InstallDir)) {
            Write-Step "Packaging Core Program Files & Mods..."
            # Copy modified app.asar and custom skills
            $asarPath = Join-Path $locs.InstallDir "resources\app.asar"
            $skillsPath = Join-Path $locs.InstallDir "resources\runtime\office-skills"
            
            if (Test-Path $asarPath) {
                $targetAsarDir = Join-Path "$tempDir\ProgramFiles_DSH" "resources"
                New-Item -ItemType Directory -Path $targetAsarDir -Force | Out-Null
                Copy-Item -Path $asarPath -Destination "$targetAsarDir\app.asar" -Force
                Write-Info "Copied modified core: resources\app.asar"
            }
            if (Test-Path $skillsPath) {
                $targetSkillsDir = Join-Path "$tempDir\ProgramFiles_DSH" "resources\runtime\office-skills"
                New-Item -ItemType Directory -Path $targetSkillsDir -Force | Out-Null
                Copy-Item -Path "$skillsPath\*" -Destination $targetSkillsDir -Recurse -Force
                Write-Info "Copied custom runtime skills: $($skillsPath)"
            }
        }

        # 3. Package Installer (if exists)
        if ($locs.InstallerPath -and (Test-Path $locs.InstallerPath)) {
            Write-Step "Including official installer..."
            Copy-Item -Path $locs.InstallerPath -Destination "$tempDir\installer.exe" -Force
        }

        # 4. Package Roaming settings
        if (Test-Path $locs.RoamingSettings) {
            Copy-Item -Path $locs.RoamingSettings -Destination "$tempDir\AppData_Roaming\settings.json" -Force
        }

        # 5. Generate Manifest
        Write-Step "Generating bundle manifest..."
        $manifest = [PSCustomObject]@{
            Version       = "1.0.0"
            ExportDate    = (Get-Date).ToString("o")
            ExportMode    = $Mode
            SourceUser    = $env:USERNAME
            SourceProfile = $env:USERPROFILE
            SourceHost    = $env:COMPUTERNAME
            HasInstaller  = (Test-Path "$tempDir\installer.exe")
            HasCoreMods   = (Test-Path "$tempDir\ProgramFiles_DSH\resources\app.asar")
        }
        $manifest | ConvertTo-Json -Depth 4 | Set-Content -Path "$tempDir\bundle-manifest.json" -Encoding UTF8

        # 6. Compress
        Write-Step "Compressing into archive: $BundlePath ..."
        $parentZipDir = Split-Path $BundlePath -Parent
        if ($parentZipDir -and (-not (Test-Path $parentZipDir))) {
            New-Item -ItemType Directory -Path $parentZipDir -Force | Out-Null
        }
        if (Test-Path $BundlePath) { Remove-Item $BundlePath -Force }
        Compress-Archive -Path "$tempDir\*" -DestinationPath $BundlePath -CompressionLevel Optimal

        $zipSizeMb = [math]::Round((Get-Item $BundlePath).Length / 1MB, 2)
        Write-Success "Export completed successfully! Output: $BundlePath ($zipSizeMb MB)"
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ==============================================================================
# Command: RESTORE (Deploy onto target machine)
# ==============================================================================
function Invoke-Restore {
    Write-Step "Starting Restore Operation"
    if (-not (Test-Path $BundlePath)) {
        throw "Bundle archive not found at: $BundlePath"
    }

    Ensure-DshStopped

    $tempDir = Join-Path $env:TEMP "dsh_restore_$(Get-Random)"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        Write-Step "Extracting bundle archive..."
        Expand-Archive -Path $BundlePath -DestinationPath $tempDir -Force

        $manifestFile = Join-Path $tempDir "bundle-manifest.json"
        $manifest = if (Test-Path $manifestFile) { Get-Content $manifestFile -Raw | ConvertFrom-Json } else { $null }

        $sourceProfile = if ($manifest -and $manifest.SourceProfile) { $manifest.SourceProfile } else { "" }
        $sourceUser    = if ($manifest -and $manifest.SourceUser) { $manifest.SourceUser } else { "" }
        Write-Info "Source profile recorded in bundle: $sourceProfile (User: $sourceUser)"
        Write-Info "Target profile on current machine : $env:USERPROFILE (User: $env:USERNAME)"

        $locs = Get-DshLocations

        if ($DryRun) {
            Write-Success "[DryRun] Validation passed. Would restore to $($locs.DshHome)."
            return
        }

        # 1. Base Installation if needed
        $installer = Join-Path $tempDir "installer.exe"
        if (Test-Path $installer) {
            if (-not $locs.InstallDir) {
                Write-Step "Target install dir not detected. Running official installer initialization..."
                Start-Process -FilePath $installer -ArgumentList "/S" -Wait
                Start-Sleep -Seconds 3
                Ensure-DshStopped
                $locs = Get-DshLocations
            }
        }

        # 2. Restore .dsh
        Write-Step "Deploying DSH User Data to $($locs.DshHome)..."
        $srcDotDsh = Join-Path $tempDir "DotDsh"
        if (Test-Path $srcDotDsh) {
            if (-not (Test-Path $locs.DshHome)) {
                New-Item -ItemType Directory -Path $locs.DshHome -Force | Out-Null
            }
            Copy-Item -Path "$srcDotDsh\*" -Destination $locs.DshHome -Recurse -Force
            Write-Success "Data center (.dsh) deployed."
        }

        # 3. Restore Program Files Mods
        $srcMods = Join-Path $tempDir "ProgramFiles_DSH"
        if (Test-Path $srcMods) {
            if ($locs.InstallDir -and (Test-Path $locs.InstallDir)) {
                Write-Step "Injecting Core Mods & Custom Skills into $($locs.InstallDir)..."
                Copy-Item -Path "$srcMods\*" -Destination $locs.InstallDir -Recurse -Force
                Write-Success "Core mods & office-skills injected."
            } else {
                Write-Warn "Could not locate Program Files directory; skipping core mod injection."
            }
        }

        # 4. Restore Roaming Settings
        $srcSettings = Join-Path $tempDir "AppData_Roaming\settings.json"
        if (Test-Path $srcSettings) {
            $targetSettingsDir = Split-Path $locs.RoamingSettings -Parent
            if (-not (Test-Path $targetSettingsDir)) {
                New-Item -ItemType Directory -Path $targetSettingsDir -Force | Out-Null
            }
            Copy-Item -Path $srcSettings -Destination $locs.RoamingSettings -Force
            Write-Info "Desktop preferences restored."
        }

        # 5. Intelligent Path Remapping Engine
        Write-Step "Executing Path Remapping Engine..."
        $remapTargets = @(
            (Join-Path $locs.DshHome "storages\workspace.json"),
            (Join-Path $locs.DshHome "profiles\desktop\cordis.patch.yml"),
            (Join-Path $locs.DshHome "profiles\web\cordis.patch.yml")
        )

        $sessionProjCacheDir = Join-Path $locs.DshHome "storages\session_projcache\sessions"
        if (Test-Path $sessionProjCacheDir) {
            $remapTargets += (Get-ChildItem -Path $sessionProjCacheDir -Filter "*.json" | ForEach-Object { $_.FullName })
        }

        $oldProfileEscaped = [regex]::Escape($sourceProfile)
        $newProfileRaw = $env:USERPROFILE

        # Also remap known legacy patterns if any
        $legacyProfile = "D:\\Users\\c1732"
        $legacyProfileEscaped = [regex]::Escape($legacyProfile)

        foreach ($filePath in $remapTargets) {
            if ($filePath -and (Test-Path $filePath)) {
                try {
                    $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
                    $modified = $false

                    if ($content -match $oldProfileEscaped) {
                        $content = [regex]::Replace($content, $oldProfileEscaped, $newProfileRaw.Replace("\", "\\"))
                        $modified = $true
                    }
                    if ($content -match $legacyProfileEscaped) {
                        $content = [regex]::Replace($content, $legacyProfileEscaped, $newProfileRaw.Replace("\", "\\"))
                        $modified = $true
                    }

                    if ($modified) {
                        [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
                        Write-Info "Remapped paths in: $(Split-Path $filePath -Leaf)"
                    }
                }
                catch {
                    Write-Warn "Skipped path remapping on ${filePath} - $($_.Exception.Message)"
                }
            }
        }

        Write-Success "Path remapping completed for all configuration stores."
        Write-Step "Restore complete! Run '.\dsh-migrate.ps1 doctor' to verify system health."
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ==============================================================================
# Command: DOCTOR (Diagnostic & Verification)
# ==============================================================================
function Invoke-Doctor {
    Write-Step "Running DSH Environment Diagnostic & Verification"
    $locs = Get-DshLocations
    $allOk = $true

    # Check DshHome
    if (Test-Path $locs.DshHome) {
        Write-Success "DSH Home exists: $($locs.DshHome)"
    } else {
        Write-Err "DSH Home MISSING: $($locs.DshHome)"
        $allOk = $false
    }

    # Check credentials & rules
    $credFile = Join-Path $locs.DshHome ".credentials.yaml"
    $agentsFile = Join-Path $locs.DshHome "AGENTS.md"
    if (Test-Path $credFile) {
        Write-Success "Credentials store found: .credentials.yaml"
    } else {
        Write-Warn "Credentials store (.credentials.yaml) not found."
    }
    if (Test-Path $agentsFile) {
        Write-Success "Global agents prompt found: AGENTS.md"
    } else {
        Write-Warn "Global AGENTS.md not found."
    }

    # Check install dir & mods
    if ($locs.InstallDir -and (Test-Path $locs.InstallDir)) {
        Write-Success "Install directory exists: $($locs.InstallDir)"
        $asar = Join-Path $locs.InstallDir "resources\app.asar"
        if (Test-Path $asar) {
            Write-Success "Core application bundle found: resources\app.asar"
        }
    } else {
        Write-Warn "Install directory not detected."
    }

    # Check Web GUI port
    Write-Step "Checking Web GUI port (127.0.0.1:19387)..."
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:19387" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-Success "DSH Web GUI is active and responding (HTTP 200)."
        }
    }
    catch {
        Write-Info "DSH Web GUI is currently not active (Start the desktop app to inspect)."
    }

    if ($allOk) {
        Write-Success "All critical checks passed."
    }
}

# ==============================================================================
# Command: HELP
# ==============================================================================
function Show-Help {
    Write-Banner
    Write-Host @"
USAGE:
    powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 <Command> [Options]

COMMANDS:
    export      Pack source machine's DSH core mods, .dsh data, and settings.
    restore     Deploy migration bundle onto the current machine and remap paths.
    doctor      Inspect and verify local DSH environment integrity.
    help        Show this help message.

OPTIONS:
    -BundlePath <string>     Path to the migration bundle (default: .\dsh-bundle.zip)
    -Mode <Private|Sanitize> Export mode:
                             - Private (default): Complete backup with API Keys and chats.
                             - Sanitize: Clean template stripping credentials and chats.
    -DryRun                  Simulate the operation without modifying any files.
    -Force                   Bypass confirmation prompts and terminate conflicting processes.

EXAMPLES:
    # 1. Export private backup on source machine:
    .\dsh-migrate.ps1 export -BundlePath D:\DSH_Backup.zip

    # 2. Export clean template for community sharing:
    .\dsh-migrate.ps1 export -Mode Sanitize -BundlePath .\dsh-template.zip

    # 3. Restore bundle on target machine:
    .\dsh-migrate.ps1 restore -BundlePath .\dsh-bundle.zip -Force

    # 4. Verify system health:
    .\dsh-migrate.ps1 doctor
"@ -ForegroundColor Yellow
}

# ==============================================================================
# Main Dispatcher
# ==============================================================================
Write-Banner
switch ($Command.ToLower()) {
    "export"  { Invoke-Export }
    "restore" { Invoke-Restore }
    "doctor"  { Invoke-Doctor }
    default   { Show-Help }
}
