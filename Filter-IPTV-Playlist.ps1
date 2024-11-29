# Function to resolve absolute or relative paths
function Resolve-ConfigPath {
    param (
        [string]$basePath,
        [string]$path
    )
    if (-not $path) {
        throw "Configuration contains an empty or null path. Please check your configuration file."
    }
    if ([IO.Path]::IsPathRooted($path)) {
        # For absolute paths, return as-is
        return $path
    } else {
        # For relative paths, join with the base path
        return Join-Path -Path $basePath -ChildPath $path
    }
}

# Function to create a sample config.json file
function Create-SampleConfig {
    param (
        [string]$configPath
    )
    $sampleConfig = @{
        BaseUrl                 = "http://example.com"
        EnableEPG              = $true
        Username               = "sampleUsername"
        Password               = "samplePassword"
        Type                   = "m3u_plus"
        Output                 = "ts"
        OriginalPlaylist       = "original_playlist.m3u"
        FilteredPlaylist       = "filtered_playlist.m3u"
        GroupsFile             = "groups.txt"
        ExtractGroups          = $true
        ExcludeFilter          = @("###", "Sample Group 1", "Sample Group 2")
        PlaylistAgeThresholdDays = 3
        DebugMode              = $true
        LogFile                = "script_log.txt"
    }

    $sampleConfig | ConvertTo-Json -Depth 2 | Set-Content -Path $configPath -Encoding UTF8
    Write-Host "Sample configuration file created at '$configPath'. Please update it with your settings and rerun the script."
}

# Function to build a URL with dynamic endpoints
function Build-Url {
    param (
        [string]$baseUrl,
        [string]$endpoint
    )
    if ($baseUrl.EndsWith("/")) {
        return "$baseUrl$endpoint"
    } else {
        return "$baseUrl/$endpoint"
    }
}

# Load the configuration file dynamically
if ($args.Count -eq 0) {
    $scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $configFile = Join-Path -Path $scriptPath -ChildPath "config.json"
    if (-Not (Test-Path $configFile)) {
        Write-Host "No configuration file provided and none found in the script directory. Creating a sample configuration file..."
        Create-SampleConfig -configPath $configFile
        exit
    } else {
        Write-Host "Using default configuration file: $configFile"
    }
} else {
    $configFile = Resolve-ConfigPath -basePath (Get-Location).Path -path $args[0]
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
try {
    $originalFile = Resolve-ConfigPath -basePath $configBasePath -path $config.OriginalPlaylist
    $filteredFile = Resolve-ConfigPath -basePath $configBasePath -path $config.FilteredPlaylist
    $groupsFile = Resolve-ConfigPath -basePath $configBasePath -path $config.GroupsFile
    $logFile = Resolve-ConfigPath -basePath $configBasePath -path $config.LogFile
} catch {
    Write-Error "Error resolving paths: $_"
    exit
}

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

function Extract-Groups {
    Log "Extracting groups from the original playlist..."

    # Validate the original playlist file exists
    if (-Not (Test-Path $originalFile)) {
        Write-Error "Original playlist file not found. Cannot extract groups."
        exit
    }

    # Dictionaries to hold group states
    $existingGroups = @{ }
    $commentedGroups = @{ }

    # Read the current groups.txt file if it exists
    if (Test-Path $groupsFile) {
        Get-Content -Path $groupsFile -Encoding UTF8 | ForEach-Object {
            if ($_ -like "//*") {
                # Commented-out group
                $groupName = $_.TrimStart("/").Trim()
                if ($groupName -ne "") {
                    $commentedGroups[$groupName] = $true
                }
            } elseif ($_.Trim() -ne "") {
                # Active group
                $existingGroups[$_.Trim()] = $true
            }
        }
    }

    # Extract groups from the original playlist
    $newGroups = @{ }
    Get-Content -Path $originalFile -Encoding UTF8 | ForEach-Object {
        if ($_ -like "#EXTINF:*") {
            $groupMatch = [Regex]::Match($_, 'group-title="([^"]*)"')
            if ($groupMatch.Success) {
                $groupName = $groupMatch.Groups[1].Value.Trim()
                if ($groupName -ne "") {
                    $newGroups[$groupName] = $true
                }
            }
        }
    }

    # Merge all groups, prioritizing existing state
    $finalGroups = @{ }
    foreach ($group in $newGroups.Keys) {
        if ($existingGroups.ContainsKey($group)) {
            $finalGroups[$group] = "active"  # Keep as active
        } elseif ($commentedGroups.ContainsKey($group)) {
            $finalGroups[$group] = "commented"  # Keep as commented
        } else {
            $finalGroups[$group] = "commented"  # New group: default to commented
        }
    }

    # Include groups from groups.txt not in the new playlist
    foreach ($group in $existingGroups.Keys + $commentedGroups.Keys) {
        if (-not $finalGroups.ContainsKey($group)) {
            $finalGroups[$group] = "commented"  # Keep as commented if not found in playlist
        }
    }

    # Write the updated groups list to groups.txt
    Log "Attempting to save groups to '$groupsFile'..."
    $finalGroups.GetEnumerator() | Sort-Object -Property Name | ForEach-Object {
        if ($_.Value -eq "commented") {
            "// $($_.Key)"
        } else {
            $_.Key
        }
    } | Out-File -FilePath $groupsFile -Encoding UTF8

    if (Test-Path $groupsFile) {
        Log "Groups file successfully saved to '$groupsFile'."
    } else {
        Write-Error "Failed to save groups file to '$groupsFile'. Check permissions and path."
        exit
    }
}


# Load active groups from groups file
function Get-Active-Groups {
    Log "Loading active groups from '$groupsFile'..."
    if (-Not (Test-Path $groupsFile)) {
        Write-Error "Groups file '$groupsFile' not found. Cannot filter playlist."
        exit
    }

    $activeGroups = Get-Content -Path $groupsFile -Encoding UTF8 | Where-Object { -Not ($_ -like "//*") }
    return $activeGroups
}


# Download playlist
function Download-Playlist {
    Log "Downloading a new playlist..."
    $playlistUrl = Build-Url -baseUrl $config.BaseUrl -endpoint "get.php"
    $playlistUrl += "?username=$($config.Username)&password=$($config.Password)&type=$($config.Type)&output=$($config.Output)"

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

function Process-EPG {
    Log "Processing EPG data..."

    # Check if EPG processing is enabled in the configuration
    if (-not $config.EnableEPG) {
        Log "EPG processing is disabled in the configuration."
        return
    }

    # Construct EPG URL
    $epgUrl = Build-Url -baseUrl $config.BaseUrl -endpoint "xmltv.php"
    $epgUrl += "?username=$($config.Username)&password=$($config.Password)"
    $epgFile = [System.IO.Path]::ChangeExtension($filteredFile, ".xml") # Save EPG alongside filtered playlist with .xml extension

    try {
        Log "Downloading EPG from '$epgUrl' in chunks..."

        # Create HttpClient to stream the file
        $httpClient = [System.Net.Http.HttpClient]::new()
        $response = $httpClient.GetAsync($epgUrl, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result

        if (-not $response) {
            Log "No response received from the server. Exiting EPG processing."
            return
        }

        if (-not $response.IsSuccessStatusCode) {
            Log "Failed to download EPG. HTTP Status: $($response.StatusCode) - $($response.ReasonPhrase)"
            return
        }

        # Stream the content to a file
        $stream = $response.Content.ReadAsStream()
        try {
            $fileStream = [System.IO.File]::Open($epgFile, [System.IO.FileMode]::Create)
            try {
                $bufferSize = 8192 # 8 KB buffer
                $buffer = New-Object byte[] $bufferSize
                while (($bytesRead = $stream.Read($buffer, 0, $bufferSize)) -gt 0) {
                    $fileStream.Write($buffer, 0, $bytesRead)
                }
                Log "EPG data downloaded and saved to '$epgFile'."
            } finally {
                $fileStream.Dispose()
            }
        } finally {
            $stream.Dispose()
        }

    } catch {
        Log "Failed to download or process EPG: $_"
        return
    } finally {
        if ($httpClient) {
            $httpClient.Dispose()
        }
    }

    # Validate the downloaded EPG file
    if (-not (Test-Path $epgFile) -or (Get-Item $epgFile).Length -eq 0) {
        Log "Downloaded EPG file is empty or missing: '$epgFile'."
        return
    }

    # Filter EPG data based on tvg-id from the filtered playlist
    try {
        Log "Filtering EPG data based on tvg-id from the filtered playlist..."

        # Extract tvg-id values from the filtered playlist
        $filteredTvgIds = @{}
        Get-Content -Path $filteredFile -Encoding UTF8 | ForEach-Object {
            if ($_ -like "#EXTINF:*") {
                $tvgIdMatch = [Regex]::Match($_, 'tvg-id="([^"]*)"')
                if ($tvgIdMatch.Success) {
                    $filteredTvgIds[$tvgIdMatch.Groups[1].Value] = $true
                }
            }
        }

        if ($filteredTvgIds.Count -eq 0) {
            Log "No tvg-id values found in the filtered playlist. Skipping EPG filtering."
            return
        }

        # Load the downloaded EPG XML
        [xml]$epgXml = Get-Content -Path $epgFile

        # Remove channels and programmes that do not match the filtered tvg-ids
        $epgXml.tv.channel | Where-Object { -Not $filteredTvgIds.ContainsKey($_.id) } | ForEach-Object {
            $_.ParentNode.RemoveChild($_) | Out-Null
        }

        $epgXml.tv.programme | Where-Object { -Not $filteredTvgIds.ContainsKey($_.channel) } | ForEach-Object {
            $_.ParentNode.RemoveChild($_) | Out-Null
        }

        # Save the filtered EPG XML back to the file
        $epgXml.Save($epgFile)
        Log "Filtered EPG data saved to '$epgFile'."

    } catch {
        Log "Failed to filter the EPG file: $_"
        return
    }

    Log "EPG processing completed successfully."
}

# Main Execution
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

if ($config.EnableEPG -eq $true) {
    Process-EPG
}

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
