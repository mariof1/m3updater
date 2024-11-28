
# m3updater

`m3updater` is a PowerShell script designed to manage IPTV playlists. It filters, organizes, and updates playlists dynamically based on user-defined configuration files.

## Features

- **Dynamic Playlist Management**: Download, filter, and save IPTV playlists.
- **Custom Group Extraction**: Extract and manage groups from playlists.
- **Configurable Exclusion Filters**: Exclude specific groups or entries based on keywords.
- **Robust Logging**: Logs operations for debugging and monitoring.
- **Dynamic Base URL Handling**: Automatically appends `get.php` or `xmltv.php` to the configured `BaseUrl` when required.

---

## Requirements

- PowerShell (v7.0 or later)
- Access to an IPTV playlist server (with a valid base URL, username, and password)

---

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mariof1/m3updater.git
   cd m3updater
   ```

2. Ensure PowerShell is installed:
   - [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) if not already available.

---

## Usage

### Running the Script

#### First Run
If no configuration file is provided, the script will generate a sample configuration file (e.g., `config.json`) in the script's directory:
```bash
pwsh ./Filter-IPTV-Playlist.ps1
```
After this, edit the configuration file (`config.json`) to include your IPTV server details, such as `BaseUrl`, `Username`, and `Password`.

#### Subsequent Runs
Once the configuration file is updated, run the script with the default or specified configuration file:
```bash
pwsh ./Filter-IPTV-Playlist.ps1 config.json
```

---

## Configuration File Format

Below is an example of the generated configuration file:

```json
{
    "OriginalPlaylist": "original_playlist.m3u",
    "FilteredPlaylist": "filtered_playlist.m3u",
    "GroupsFile": "groups.txt",
    "ExcludeFilter": ["###", "US|", "RADIO", "HBO", "SPORTS", "ADULT", "PPV"],
    "PlaylistAgeThresholdDays": 1,
    "DebugMode": true,
    "LogFile": "script_log.txt",
    "BaseUrl": "http://example.com",
    "Username": "your_username",
    "Password": "your_password",
    "Type": "m3u_plus",
    "Output": "ts",
    "ExtractGroups": true,
    "EnableEPG": false
}
```

### Configuration Fields
| Field                   | Description                                                                                      |
|-------------------------|--------------------------------------------------------------------------------------------------|
| `OriginalPlaylist`      | Path to save the original downloaded playlist (relative or absolute).                           |
| `FilteredPlaylist`      | Path to save the filtered playlist.                                                             |
| `GroupsFile`            | Path to the file storing extracted groups.                                                      |
| `ExcludeFilter`         | List of keywords to exclude specific groups or entries from the playlist.                       |
| `PlaylistAgeThresholdDays` | Maximum age of a playlist before re-downloading (in days).                                     |
| `DebugMode`             | Enables or disables debug logging (`true` or `false`).                                          |
| `LogFile`               | Path to save the debug log file.                                                                |
| `BaseUrl`               | The base URL of the IPTV playlist server (without `/get.php` or `/xmltv.php`).                  |
| `Username`              | Username for accessing the IPTV server.                                                        |
| `Password`              | Password for accessing the IPTV server.                                                        |
| `Type`                  | The type of playlist (e.g., `m3u_plus`).                                                        |
| `Output`                | Output format (e.g., `ts`).                                                                     |
| `ExtractGroups`         | Boolean value to enable or disable group extraction.                                            |
| `EnableEPG`             | Boolean value to enable or disable EPG processing.                                              |

---

## Example Workflow

### Running the Script
1. Run the script for the first time:
   ```bash
   pwsh ./Filter-IPTV-Playlist.ps1
   ```
   - This will create a sample configuration file (`config.json`).

2. Edit the configuration file to include your IPTV server details.

3. Run the script again:
   ```bash
   pwsh ./Filter-IPTV-Playlist.ps1 config.json
   ```

---

## Excluding Files from Git
To ensure sensitive or environment-specific files (e.g., `config.json`) are not uploaded to GitHub, include the following in your `.gitignore`:

```gitignore
# Ignore all config files
config*.json
```

---

## Logging
The script logs operations to the specified `LogFile`. Enable logging by setting `DebugMode` to `true` in your configuration file.

---

## Dynamic URL Handling
Starting from this version, `BaseUrl` should only include the server's root URL (e.g., `http://line.example.org`). The script automatically appends:
- `get.php` for playlist downloads.
- `xmltv.php` for EPG data.

This simplifies configuration and ensures flexibility for different server setups.

---

## Contributing
1. Fork the repository.
2. Create a feature branch: `git checkout -b feature-name`.
3. Commit your changes: `git commit -m "Add feature name"`.
4. Push to the branch: `git push origin feature-name`.
5. Open a pull request.

---

## License
This project is licensed under the MIT License. See the `LICENSE` file for details.

---

### Summary of Changes
- **First-Run Configuration**: The script creates a sample `config.json` file if no configuration file is provided during the first run.
- **Removed Manual Sample Configuration**: No need to manually create or copy configuration files.
- **Dynamic URL Handling**: Automatically appends `get.php` or `xmltv.php` to the `BaseUrl`.
