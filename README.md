# InlineMC

InlineMC is a small local-first Minecraft launcher and resolver. The resolver builds a launch plan from Mojang metadata, while `launch.sh`, `launch.ps1`, and `launch.bat` download the required files into the normal vanilla Minecraft home and start the client.

## Requirements

- Java installed and available as `java`
- `curl`
- Linux/macOS: `bash`, `unzip`, `sha1sum`
- Windows: PowerShell or CMD, plus `certutil` for CMD runs

## Run the Launcher

The launcher asks for a username and Minecraft version. Press Enter to reuse the cached value from the previous run.

Unix-like systems:

```sh
./launch.sh
```

Windows:

```bat
launch.bat
```

Windows PowerShell:

```powershell
.\launch.ps1
```

## One-Line Launch

These commands download and run the launcher script directly. By default, the downloaded launcher uses `https://inlinemc.sammwy.com/v1/plan.txt`.

Linux/macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.sh | bash
```

Linux/macOS with the local debug resolver:

```sh
curl -fsSL https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.sh | DEBUG=1 bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.ps1 | iex
```

Windows PowerShell with the local debug resolver:

```powershell
$env:DEBUG="1"; irm https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.ps1 | iex
```

Windows CMD:

```bat
curl -L -o "%TEMP%\inlinemc-launch.bat" https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.bat && "%TEMP%\inlinemc-launch.bat"
```

Windows CMD with the local debug resolver:

```bat
set DEBUG=1 && curl -L -o "%TEMP%\inlinemc-launch.bat" https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.bat && "%TEMP%\inlinemc-launch.bat"
```

If you host the files somewhere else, replace the `raw.githubusercontent.com/sammwyy/inlinemc/main` URL with your own raw file URL.

## Docker

Build and run the resolver:

```sh
docker build -t inlinemc .
docker run --rm -p 3000:3000 inlinemc
```

## Minecraft Home

InlineMC uses the same game directory as the vanilla launcher:

- Linux/macOS: `$HOME/.minecraft`
- Windows: `%APPDATA%\.minecraft`

The launcher stores its prompt cache in:

- `cache/last_username`
- `cache/last_version`
- `cache/inlineversions/`

inside the Minecraft home directory.

## Development

### Start the Resolver

Run this from the repository root:

```sh
cd server && npm install && npm start
```

Production launchers use `https://inlinemc.sammwy.com/v1/plan.txt` by default. For local development, run the resolver on `http://localhost:3000` and start the launcher with `DEBUG=1`.

The resolver listens on `http://localhost:3000` by default. To use another port:

```sh
cd server && PORT=3001 npm start
```

### Resolver Stats

Every `/v1/plan.txt` resolve is logged to stdout. The resolver keeps stats and pending log lines in memory, marks them dirty, and flushes them to disk once per second when there are changes.

Plan resolve lines are appended to:

```txt
server/logs/plan-resolves.log
```

Aggregated counters are stored in:

```txt
server/stats.json
```

The stats format is:

```json
{
  "plan": {
    "allTime": {
      "1.20.1": 50
    },
    "last24h": {
      "_timestamp": "2026-06-12T00:00:00.000Z",
      "1.20.1": 30
    }
  }
}
```

`allTime` counts every resolved plan by resolved Minecraft version. `last24h` is a 24-hour window that resets when the stored `_timestamp` is older than 24 hours.
