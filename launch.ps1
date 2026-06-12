$ErrorActionPreference = "Stop"

# Minimal local-first Minecraft launcher.

if ($env:API) {
  $Api = $env:API
} elseif ($env:DEBUG -eq "1") {
  $Api = "http://localhost:3000/v1/plan.txt"
} else {
  $Api = "https://inlinemc.sammwy.com/v1/plan.txt"
}

$McHome = if ($env:MC_HOME) { $env:MC_HOME } else { Join-Path $env:APPDATA ".minecraft" }
$CacheDir = Join-Path $McHome "cache"
$PlanDir = Join-Path $CacheDir "inlineversions"
$LastUsernameFile = Join-Path $CacheDir "last_username"
$LastVersionFile = Join-Path $CacheDir "last_version"

$OsName = if ($env:OS_NAME) { $env:OS_NAME } else { "windows" }
$Arch = if ($env:ARCH) { $env:ARCH } else { "x64" }

$Uuid = if ($env:UUID) { $env:UUID } else { "00000000-0000-0000-0000-000000000000" }
$AccessToken = if ($env:ACCESS_TOKEN) { $env:ACCESS_TOKEN } else { "0" }
$UserType = if ($env:USER_TYPE) { $env:USER_TYPE } else { "legacy" }

function Read-CachedValue {
  param([string] $Path)

  if (Test-Path -LiteralPath $Path) {
    return (Get-Content -LiteralPath $Path -TotalCount 1)
  }

  return ""
}

function Prompt-Value {
  param(
    [string] $Label,
    [string] $Cached,
    [string] $Fallback
  )

  while ($true) {
    if ($Cached) {
      $InputValue = Read-Host "$Label [$Cached]"
      if (-not $InputValue) { $InputValue = $Cached }
    } elseif ($Fallback) {
      $InputValue = Read-Host "$Label [$Fallback]"
      if (-not $InputValue) { $InputValue = $Fallback }
    } else {
      $InputValue = Read-Host $Label
    }

    if ($InputValue) {
      return $InputValue
    }

    Write-Host "$Label is required."
  }
}

function Test-Sha1 {
  param(
    [string] $Path,
    [string] $Expected
  )

  if (-not $Expected) {
    return $true
  }

  $Actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.ToLowerInvariant()
  return $Actual -eq $Expected.ToLowerInvariant()
}

function Download-File {
  param(
    [string] $RelPath,
    [string] $Sha1,
    [string] $Url
  )

  $Out = Join-Path $McHome $RelPath

  if (Test-Path -LiteralPath $Out) {
    if (Test-Sha1 -Path $Out -Expected $Sha1) {
      return
    }

    Write-Host "Hash mismatch, redownloading: $RelPath"
    Remove-Item -LiteralPath $Out -Force
  }

  $Parent = Split-Path -Parent $Out
  New-Item -ItemType Directory -Force -Path $Parent | Out-Null

  Write-Host "Downloading $RelPath"
  Invoke-WebRequest -Uri $Url -OutFile $Out

  if (-not (Test-Sha1 -Path $Out -Expected $Sha1)) {
    throw "Failed SHA1 verification: $RelPath"
  }
}

function Normalize-RelPath {
  param(
    [string] $Kind,
    [string] $RelPath
  )

  if ($Kind -in @("LIBRARY", "NATIVE", "CLASSPATH") -and -not $RelPath.StartsWith("libraries/")) {
    return "libraries/$RelPath"
  }

  return $RelPath
}

function Expand-Native {
  param(
    [string] $RelPath,
    [string] $ExtractRel
  )

  $Src = Join-Path $McHome $RelPath
  $Dst = Join-Path $McHome $ExtractRel

  New-Item -ItemType Directory -Force -Path $Dst | Out-Null
  Expand-Archive -Force -LiteralPath $Src -DestinationPath $Dst
}

function Replace-Vars {
  param([string] $Value)

  $Result = $Value
  $Result = $Result.Replace('${natives_directory}', $script:NativesDir)
  $Result = $Result.Replace('${launcher_name}', 'inlinemc')
  $Result = $Result.Replace('${launcher_version}', '0.1')
  $Result = $Result.Replace('${classpath}', $script:Classpath)
  $Result = $Result.Replace('${auth_player_name}', $script:PlayerName)
  $Result = $Result.Replace('${version_name}', $script:Version)
  $Result = $Result.Replace('${game_directory}', $script:McHome)
  $Result = $Result.Replace('${assets_root}', (Join-Path $script:McHome 'assets'))
  $Result = $Result.Replace('${assets_index_name}', $script:AssetIndexId)
  $Result = $Result.Replace('${auth_uuid}', $script:Uuid)
  $Result = $Result.Replace('${auth_access_token}', $script:AccessToken)
  $Result = $Result.Replace('${user_type}', $script:UserType)
  $Result = $Result.Replace('${version_type}', $script:VersionType)

  return $Result
}

New-Item -ItemType Directory -Force -Path $McHome, $CacheDir, $PlanDir | Out-Null

$LastUsername = Read-CachedValue -Path $LastUsernameFile
$LastVersion = Read-CachedValue -Path $LastVersionFile

Write-Host "===================="
Write-Host "      InlineMC"
Write-Host "===================="

$script:PlayerName = Prompt-Value -Label "username" -Cached $LastUsername -Fallback ""
$RequestedVersion = Prompt-Value -Label "version" -Cached $LastVersion -Fallback "1.21.1"

Set-Content -LiteralPath $LastUsernameFile -Value $script:PlayerName
Set-Content -LiteralPath $LastVersionFile -Value $RequestedVersion

$script:Version = $RequestedVersion
$PlanFile = Join-Path $PlanDir "$RequestedVersion`_response.txt"

if (-not (Test-Path -LiteralPath $PlanFile)) {
  Write-Host "Downloading launch plan..."
  Invoke-WebRequest -Uri "${Api}?version=$RequestedVersion&os=$OsName&arch=$Arch" -OutFile $PlanFile
}

$MainClass = ""
$script:AssetIndexId = ""
$script:VersionType = "release"
$script:Classpath = ""
$JvmArgs = [System.Collections.Generic.List[string]]::new()
$GameArgs = [System.Collections.Generic.List[string]]::new()
$script:McHome = $McHome
$script:Uuid = $Uuid
$script:AccessToken = $AccessToken
$script:UserType = $UserType
$script:NativesDir = Join-Path $McHome "versions\$script:Version\natives"
$SkipNextGameArg = $false

foreach ($Line in Get-Content -LiteralPath $PlanFile) {
  if (-not $Line -or $Line.StartsWith("#")) {
    continue
  }

  $Parts = $Line.Split("|")
  $Kind = $Parts[0]
  $P1 = if ($Parts.Count -gt 1) { $Parts[1] } else { "" }
  $P2 = if ($Parts.Count -gt 2) { $Parts[2] } else { "" }
  $P3 = if ($Parts.Count -gt 3) { $Parts[3] } else { "" }
  $P5 = if ($Parts.Count -gt 5) { $Parts[5] } else { "" }

  switch ($Kind) {
    "VERSION" {
      $script:Version = $P1
      $script:NativesDir = Join-Path $McHome "versions\$script:Version\natives"
    }
    "VERSION_TYPE" {
      $script:VersionType = $P1
    }
    "MAIN_CLASS" {
      $MainClass = $P1
    }
    "ASSET_INDEX_ID" {
      $script:AssetIndexId = $P1
    }
    { $_ -in @("CLIENT", "LIBRARY", "ASSET_INDEX", "ASSET") } {
      $RelPath = Normalize-RelPath -Kind $Kind -RelPath $P1
      Download-File -RelPath $RelPath -Sha1 $P2 -Url $P3
    }
    "NATIVE" {
      $RelPath = Normalize-RelPath -Kind $Kind -RelPath $P1
      Download-File -RelPath $RelPath -Sha1 $P2 -Url $P3
      Expand-Native -RelPath $RelPath -ExtractRel $P5
    }
    "CLASSPATH" {
      $RelPath = Normalize-RelPath -Kind $Kind -RelPath $P1
      $Entry = Join-Path $McHome $RelPath
      if ($script:Classpath) {
        $script:Classpath = "$script:Classpath;$Entry"
      } else {
        $script:Classpath = $Entry
      }
    }
    "JVM_ARG" {
      if ($P1 -ne "-cp" -and $P1 -ne '${classpath}') {
        $JvmArgs.Add((Replace-Vars -Value $P1)) | Out-Null
      }
    }
    "GAME_ARG" {
      if ($SkipNextGameArg) {
        $SkipNextGameArg = $false
      } elseif ($P1 -eq "--demo") {
        continue
      } elseif ($P1 -in @("--width", "--height", "--quickPlayPath", "--quickPlaySingleplayer", "--quickPlayMultiplayer", "--quickPlayRealms")) {
        $SkipNextGameArg = $true
      } else {
        $GameArgs.Add((Replace-Vars -Value $P1)) | Out-Null
      }
    }
  }
}

if (-not $MainClass) {
  throw "Missing MAIN_CLASS."
}

if (-not $script:AssetIndexId) {
  throw "Missing ASSET_INDEX_ID."
}

Write-Host "Launching Minecraft $script:Version..."

$JavaArgs = @()
$JavaArgs += $JvmArgs.ToArray()
$JavaArgs += "-cp"
$JavaArgs += $script:Classpath
$JavaArgs += $MainClass
$JavaArgs += $GameArgs.ToArray()

& java @JavaArgs
