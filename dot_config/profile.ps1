
#region functions

function Get-FileHash256 {
  <#
  .SYNOPSIS
    Compute the SHA-256 hash for a given file.
  .DESCRIPTION
    Wrapper function for Get-FileHash which defaulst the Algorithm parameter to
    SHA256 and copies the returned hash to the clipboard.
  .PARAMETER Path
    Fully qualified path to the file for which to obtain the SHA-256 hash.
  .EXAMPLE
    Get-FileHash256 -Path C:\Windows\System32\notepad.exe
  #>
  [CmdletBinding()]
  param (
    [System.IO.FileInfo]$Path
  )

  if (-not (Test-Path $Path)) {
    throw "File $Path not found, could not determine hash."
  }

  $sha_256_hash = (Get-FileHash -Algorithm SHA256 $Path).hash
  Write-Host "SHA-256 hash copied to clipboard for [$Path]: " -NoNewline
  Write-Host $sha_256_hash -ForegroundColor Green
  return $sha_256_hash | Set-Clipboard
}

function Edit-Profile {
  <#
  .SYNOPSIS
    Opens the $profile file an editor.
  .DESCRIPTION
    Opens the $profile.CurrentUserAllHosts file conditionally in one of the
    following programs:
    1. PowerShell ISE, if detected as the current host.
    2. VSCode, if detected as the current host.
    3. Notepad, if the current host is netiher of the above.
  .EXAMPLE
    Edit-Profile
  #>

  $PATH = $profile.CurrentUserAllHosts

  switch ((Get-Host).Name) {
    'Visual Studio Code Host' { Open-EditorFile $PATH }
    'Windows PowerShell ISE Host' { psedit $PATH }
    default { Start-Process "$env:windir\system32\notepad.exe" -ArgumentList @($PATH) }
  }
}

function Open-HistoryFile {
  <#
  .SYNOPSIS
    Opens the PowerShell history file.
  .DESCRIPTION
    Opens the (Get-PSReadLineOption).HistorySavePath file conditionally in one
    of the following programs:
    1. PowerShell ISE, if detected as the current host.
    2. VSCode, if detected as the current host.
    3. Notepad, if the current host is netiher of the above.
  .EXAMPLE
    Open-HistoryFile
  #>

  $HISTORY_PATH = (Get-PSReadLineOption).HistorySavePath

  switch ((Get-Host).Name) {
    'Visual Studio Code Host' { Open-EditorFile $HISTORY_PATH }
    'Windows PowerShell ISE Host' { psedit $HISTORY_PATH }
    default { Start-Process "$env:windir\system32\notepad.exe" -ArgumentList $HISTORY_PATH }
  }
}

#endregion

#region execution

################################################################################
# Update the console title with current PowerShell elevation and version       #
################################################################################
$Host.UI.RawUI.WindowTitle = "PS | v$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"

################################################################################
# PSReadLine and prompt options                                                #
################################################################################
if (-not (Get-Module PSReadline)) {
  Write-Warning 'Failed to locate PSReadLine module'
} else {
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
  Set-PSReadLineOption -ShowToolTips -BellStyle Visual -HistoryNoDuplicates
  Set-PSReadLineOption -PredictionSource History
  Set-PSReadLineOption -PredictionViewStyle ListView

  if ($env:STARSHIP_SHELL -eq 'powershell' -or 'pwsh') {
    # Set the prompt character to change color based on syntax errors
    # https://github.com/PowerShell/PSReadLine/issues/1541#issuecomment-631870062
    $esc = [char]0x1b # Escape Character
    $symbol = [char]0x276F  # ❯
    $fg = '0' # white foreground
    $bg = '8;2;78;213;93'  # 24-bit color code
    $err_bg = '1' # Error Background

    Set-PSReadLineOption -PromptText (
      " $esc[4$esc[4${fg};3${bg}m$symbol ",
      " $esc[4$esc[4${fg};3${err_bg}m$symbol "
    )
   $env:STARSHIP_LOG = 'error'
  }
}

# https://starship.rs/
Invoke-Expression (&starship init powershell)

################################################################################
# Windows/Linux differences                                                    #
################################################################################
if ($IsLinux -or $IsMacOs) {
  $TMP_DIR = '/tmp/'

  # PSDepend doesn't seem to work on PS7 on Linux, install modules here.
  Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
  $modules = @(
    'PowerShellGet',
    'PSReadLine',
    'Get-ChildItemColor',
    'PSWriteHTML'
  )

  foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
      Install-Module $module -AllowClobber -AllowPrerelease -Scope CurrentUser -Force
    }
  }

  function g4d {
    param (
      [System.IO.FileInfo]$Path
    )
    Set-Location -Path $(p4 g4d $Path)
  }
  function hgd {
    param (
      [System.IO.FileInfo]$Path
    )
    Set-Location -Path $(hg hgd $Path)
  }
  
} else {
  $TMP_DIR = $TMP_DIR = 'C:\Tmp'
  # Chezmoi edit command defaults to vi, which doesn't exist on Windows
  $env:EDITOR = 'code'

  # Fake sudo on Windows
  function sudo {
    Start-Process @args -Verb RunAs -Wait
  }
}

################################################################################
# Set common aliases                                                           #
################################################################################
Set-Alias -Name ll -Value Get-ChildItemColor -Scope Global -Option AllScope
Set-Alias -Name ls -Value Get-ChildItemColorFormatWide -Scope Global -Option AllScope
Set-Alias -Name History -Value Open-HistoryFile -Scope Global -Option AllScope

################################################################################
# Always start in the same directory                                           #
################################################################################

if (-not (Test-Path $TMP_DIR)) {
  New-Item -ItemType Directory -Path $TMP_DIR -Force
}
Set-Location $TMP_DIR

#endregion
