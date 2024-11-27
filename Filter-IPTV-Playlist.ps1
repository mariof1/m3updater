# Function to resolve absolute or relative paths
function Resolve-ConfigPath {
    param (
        [string]$basePath,
        [string]$path
    )
    if ([IO.Path]::IsPathRooted($path)) {
        # If the path is absolute, return as is
        return $path
    } else {
        # Otherwise, resolve it relative to the base path
        return Join-Path -Path $basePath -ChildPath $path
    }
}

# Load the configuration file dynamically
if ($args.Count -eq 0) {
    # Default config file if no argument is passed
    $scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $configFile = Join-Path -Path $scriptPath -ChildPath "config.json"
    Write-Host "No configuration file provided. Using default: $configFile"
} else {
    # Use the first argument as the config file path
    $configFile = $args[0]
    Write-Host "Using configuration file: $configFile"
}

if (-Not (Test-Path $configFile)) {
    Write-Error "Config file '$configFile' not found. Exiting."
    exit
}

$config = Get-Content -Path $configFile -Raw | ConvertFrom-Json

# Base path for resolving relative paths in the config
$configBasePath = Split-Path -Path $configFile -Parent

# Resolve paths using the Resolve-ConfigPath function
$originalFile = Resolve-ConfigPath -basePath $configBasePath -path $config.OriginalPlaylist
$filteredFile = Resolve-ConfigPath -basePath $configBasePath -path $config.FilteredPlaylist
$groupsFile = Resolve-ConfigPath -basePath $configBasePath -path $config.GroupsFile
$logFile = Resolve-ConfigPath -basePath $configBasePath -path $config.LogFile

# Retrieve debug settings
$debugMode = $config.DebugMode

# Ensure log file exists
if ($debugMode -and $logFile) {
    New-Item -ItemType File -Force -Path $logFile | Out-Null
}

# Log function
function Log {
    param($message)
    if ($debugMode) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $message"
        Write-Host $logMessage -ForegroundColor Yellow
        if ($logFile) {
            Add-Content -Path $logFile -Value $logMessage
        }
    }
}

# Define other functions (no changes to logic)

function Extract-Groups {
    Log "Extracting groups from the original playlist..."

    if (-Not (Test-Path $originalFile)) {
        Write-Error "Original playlist file not found. Cannot extract groups."
        exit
    }

    # Read existing groups from groups.txt
    $existingGroups = @{ }
    $commentedGroups = @{ }
    if (Test-Path $groupsFile) {
        Get-Content -Path $groupsFile -Encoding UTF8 | ForEach-Object {
            if ($_ -like "//*") {
                $groupName = $_.TrimStart("/").Trim()
                if ($groupName -ne "") {
                    $commentedGroups[$groupName] = $true
                }
            } elseif ($_.Trim() -ne "") {
                $existingGroups[$_.Trim()] = $true
            }
        }
    }

    # Extract groups from the playlist
    $newGroups = @{ }
    Get-Content -Path $originalFile -Encoding UTF8 | ForEach-Object {
        if ($_ -like "#EXTINF:*") {
            $groupMatch = [Regex]::Match($_, 'group-title="([^"]*)"')
            if ($groupMatch.Success) {
                $newGroups[$groupMatch.Groups[1].Value] = $true
            }
        }
    }

    # Combine groups
    $finalGroups = @{}
    foreach ($group in $newGroups.Keys) {
        if ($existingGroups.ContainsKey($group)) {
            $finalGroups[$group] = "active"
        } elseif ($commentedGroups.ContainsKey($group)) {
            $finalGroups[$group] = "commented"
        } else {
            $finalGroups[$group] = "commented"
        }
    }

    foreach ($group in $existingGroups.Keys + $commentedGroups.Keys) {
        if (-not $finalGroups.ContainsKey($group)) {
            $finalGroups[$group] = "commented"
        }
    }

    # Write to groups file
    $finalGroups.GetEnumerator() | Sort-Object -Property Name | ForEach-Object {
        if ($_.Value -eq "commented") {
            "// $($_.Key)"
        } else {
            $_.Key
        }
    } | Set-Content -Path $groupsFile -Encoding UTF8

    Log "Groups have been extracted and saved to '$groupsFile'."
}

function Get-Active-Groups {
    Log "Loading active groups from '$groupsFile'..."
    if (-Not (Test-Path $groupsFile)) {
        Write-Error "Groups file '$groupsFile' not found. Cannot filter playlist."
        exit
    }

    $activeGroups = Get-Content -Path $groupsFile -Encoding UTF8 | Where-Object { -Not ($_ -like "//*") }
    return $activeGroups
}

function Download-Playlist {
    Log "Downloading a new playlist..."
    $playlistUrl = "$($config.BaseUrl)?username=$($config.Username)&password=$($config.Password)&type=$($config.Type)&output=$($config.Output)"

    try {
        $httpClient = New-Object System.Net.Http.HttpClient
        $response = $httpClient.GetAsync($playlistUrl, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result

        if (-not $response.IsSuccessStatusCode) {
            Write-Error "Failed to download playlist. HTTP Status: $($response.StatusCode)"
            exit
        }

        $stream = $response.Content.ReadAsStream()
        try {
            $fileStream = [System.IO.File]::Open($originalFile, [System.IO.FileMode]::Create)
            try {
                $stream.CopyTo($fileStream)
                Log "Original playlist downloaded and saved to '$originalFile'."
            } finally {
                $fileStream.Close()
            }
        } finally {
            $stream.Close()
        }

        $httpClient.Dispose()
    } catch {
        Write-Error "Failed to download playlist or write to file: $_"
        exit
    }
}

# Main Execution

# Ensure ExcludeFilter is defined and valid
$excludeFilter = @()
if ($null -ne $config.ExcludeFilter) {
    $excludeFilter = $config.ExcludeFilter | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLower() }
}

$playlistAgeThresholdDays = $config.PlaylistAgeThresholdDays
if (-Not $playlistAgeThresholdDays) {
    Write-Warning "PlaylistAgeThresholdDays not defined in config. Defaulting to 1 day."
    $playlistAgeThresholdDays = 1
}

if (Test-Path $originalFile) {
    $fileAge = (Get-Date) - (Get-Item $originalFile).LastWriteTime
    if ($fileAge.TotalDays -gt $playlistAgeThresholdDays) {
        Log "Existing playlist is older than $playlistAgeThresholdDays day(s). Downloading a new playlist..."
        Download-Playlist
    } else {
        Log "Using existing playlist '$originalFile' (Last modified: $((Get-Item $originalFile).LastWriteTime))."
    }
} else {
    Log "Playlist file does not exist. Downloading a new playlist..."
    Download-Playlist
}

if ($config.ExtractGroups -eq $true) {
    Extract-Groups
}

$activeGroups = Get-Active-Groups
Log "Active groups for filtering: $($activeGroups -join ', ')"

# Filtering logic
Write-Host "Filtering playlist by groups has started..."
$filteredLines = @("#EXTM3U")
$includeLine = $false

Get-Content -Path $originalFile -Encoding UTF8 | ForEach-Object {
    if ($_ -like "#EXTINF:*") {
        $groupTitleMatch = [Regex]::Match($_, 'group-title="([^"]*)"')

        if ($groupTitleMatch.Success -and ($activeGroups -contains $groupTitleMatch.Groups[1].Value)) {
            $lineLower = $_.ToLower()
            $excludeMatch = $excludeFilter | Where-Object { $lineLower -like "*$_*" }

            if (-not $excludeMatch) {
                $filteredLines += $_
                $includeLine = $true
            } else {
                $includeLine = $false
            }
        } else {
            $includeLine = $false
        }
    } elseif ($includeLine) {
        $filteredLines += $_
        $includeLine = $false
    }
}

$filteredLines | Set-Content -Path $filteredFile -Encoding UTF8
Log "Filtered playlist has been saved to '$filteredFile'."
Write-Host "Filtered playlist has been saved to '$filteredFile'."
