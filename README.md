
# m3updater

`m3updater` is a PowerShell script designed to manage IPTV playlists. It filters, organizes, and updates playlists dynamically based on user-defined configuration files.

## Features

- **Dynamic Playlist Management**: Download, filter, and save IPTV playlists.
- **Custom Group Extraction**: Extract and manage groups from playlists.
- **Configurable Exclusion Filters**: Exclude specific groups or entries based on keywords.
- **Robust Logging**: Logs operations for debugging and monitoring.
- **Customizable Configuration**: Supports multiple configuration files for flexibility.

---

## Requirements

- PowerShell (v7.0 or later)
- Access to an IPTV playlist server (with a valid URL, username, and password)

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
To run the script with a specific configuration file:
```bash
pwsh ./Filter-IPTV-Playlist.ps1 ./config_us.json
```

### Supported Configuration Files
You can create and manage multiple configuration files for different use cases, such as:
- `config_us.json` for US playlists

---

## Configuration File Format

The script relies on a configuration file in JSON format. Below is an example of a configuration file for a US playlist:

```json
{
    "OriginalPlaylist": "./original_playlist.m3u",
    "FilteredPlaylist": "./filtered_playlist.m3u",
    "GroupsFile": "./groups.txt",
    "ExcludeFilter": ["###", "US|", "RADIO", "HBO", "SPORTS", "ADULT", "PPV"],
    "PlaylistAgeThresholdDays": 1,
    "DebugMode": true,
    "LogFile": "./script_log.txt",
    "BaseUrl": "http://example.com/get.php",
    "Username": "your_username",
    "Password": "your_password",
    "Type": "m3u_plus",
    "Output": "ts",
    "ExtractGroups": true
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
| `BaseUrl`               | The base URL of the IPTV playlist server.                                                       |
| `Username`              | Username for accessing the IPTV server.                                                        |
| `Password`              | Password for accessing the IPTV server.                                                        |
| `Type`                  | The type of playlist (e.g., `m3u_plus`).                                                        |
| `Output`                | Output format (e.g., `ts`).                                                                     |
| `ExtractGroups`         | Boolean value to enable or disable group extraction.                                            |

---

## Example Workflow

### US Playlist
Run the script with `config_us.json`:
```bash
pwsh ./Filter-IPTV-Playlist.ps1 ./config_us.json
```

---

## Excluding Files from Git
To ensure sensitive or environment-specific files (e.g., `config_us.json`) are not uploaded to GitHub, include the following in your `.gitignore`:

```gitignore
# Ignore all config files except the sample
config*.json
!config.json.sample
```

---

## Logging
The script logs operations to the specified `LogFile`. Enable logging by setting `DebugMode` to `true` in your configuration file.

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
