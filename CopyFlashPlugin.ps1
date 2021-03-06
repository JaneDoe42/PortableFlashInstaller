
Add-Type -AssemblyName System.Windows.Forms # Needed for pop-up windows

if (!(Test-Path variable:INSTALLER_CONST_SET)) {
    Set-Variable INSTALLER_CONST_SET -Option Constant -Value $true

    Set-Variable FLASH_VER_FILE_URL -Option Constant -Value "https://fpdownload.macromedia.com/pub/flashplayer/masterversion/masterversion.xml"
    Set-Variable FLASH_INSTALLER -Option Constant -Value "install_flash_player.exe"
    Set-Variable FLASH_INSTALLER_URL -Option Constant -Value "https://fpdownload.macromedia.com/pub/flashplayer/latest/help/install_flash_player.exe"
    Set-Variable FLASH_UNINSTALLER -Option Constant -Value "uninstall_flash_player.exe"
    Set-Variable FLASH_UNINSTALLER_URL -Option Constant -Value "https://fpdownload.macromedia.com/get/flashplayer/current/support/uninstall_flash_player.exe"
    
    Set-Variable REVO_CMD -Option Constant -Value "RevoCmd.exe" # Specifies want full name & location of uninstaller
    Set-Variable REVO_CMD_ARGS -Option Constant -Value "/m ""*flash*npapi"" /u" # Specifies want full name & location of uninstaller
    Set-Variable REVO_UNINPROG -Option Constant -Value "RevoUninPro.exe" # Specifies unstall program name {0} at location {1} using advanced mode for 64
    Set-Variable REVO_UNINPROG_ARGS -Option Constant -Value "/mu ""{0}"" /path ""{1}"" /mode Advanced /64" # Specifies unstall program name {0} at location {1} using advanced mode for 64
}

# ************
# * This File is used to copy both the 64 & 32 bit versions of
# *   the Flash Plugin for Firefox to the Portable Firefox
# *   plugin directory. It first removes the old files, then 
# *   copies the newer versions.
# *   The files copied are:
# *     flashplayer.xpt
# *     FlashPlayerPlugin*.exe
# *     FlashUtil32*.exe
# *     FlashUtil64*.exe
# *     NPSWF32*.dll
# *     NPSWF64*.dll
# * 
# * NOTE: This file must be placed in the same directory with the
# *   PortableFlash.cfg file. A shortcut to this file can be placed any
# *   where on the computer. The PortableFlash.cfg contains the settings
# *   for the installation/updating of the Flash Plugin and removal.
# *
# * Local Variables
# *  portdir - set to the plugins directory for FireFox Portable
# *  isPortable - bool stating if this is a Portable install (true) or local install (false)
# *  plug32dir - set to the Flash sub-directory in the System32 directory
# *  plug64dir - set to the Flash sub-directory in the SysWOW64 directory
# *  plugdir - set to the directory holding Flash 32bit files
# *  Arch - set to the OS Achitecture (x86 or amd64).
# *  is64Bit - bool stating if 64bit system (true) or not (false). Note: false should be 32bit system
# *  isWin7 - bool stating if Windows 7 system (true) or not (false). Note: false should be Windows 8 or higher
# *  currDownloads - set to the directory where files are downloaded from the web
# *  bInstallerRan - bool stating if Flash installer ran (true) or not (false)
# *  numOfSteps - set to the total number of steps (sections) to run.
# *  currStep - set to 1 less than the currect step (section) running - zero based
# *
# *  RevoCmd - set to the RevoCmd.exe program location
# *  RevoCmdArg - set with the command line arguments to be passed to RevoCmd.exe
# *  RevoUninProg - set to the RevoUninstaller Pro (RevoUninPro.exe) program location
# *  RevoUninArg - set with the command line arguments to be passed to RevoUninPro.exe
# *
# *  webFlashVerFile - set to the URL for the flash version list (XML format)
# *    Default at: https://fpdownload.macromedia.com/pub/flashplayer/masterversion/masterversion.xml
# *  tempVerFile - set to the local file location of the downloaded flash version list (XML format)
# *  webFlashInstaller - set to the URL for the flash installer
# *    Default at: https://fpdownload.macromedia.com/pub/flashplayer/latest/help/install_flash_player.exe
# *  FlashInstaller - set to the local file location of the downloaded flash installer
# *  webFlashUninstaller - set to the URL for the flash uninstaller
# *    Default at: https://fpdownload.macromedia.com/get/flashplayer/current/support/uninstall_flash_player.exe
# *  FlashUninstaller - set to the local file location of the downloaded flash uninstaller
# *
# *** Neither of these 2 can be true at same time, but both should be false if local install
# *  bUseFlashUninstaller - bool stating if Flash Uninstaller is to be used (true) or not used (false)
# *  bUseRevoUninstaller - bool stating if Revo Uninstaller is to be used (true) or not used (false)
# ************

# *** ~~~ ToDo ~~~
# Figure out proper handling of following cases in code
# And should there be a change to XML config file?
# pY pN uF uR
# 1  0  1  0  - Portable, uninstall Flash
# 1  0  0  1  - Portable, uninstall Revo
# 1  0  0  0  - Portable, No Uninstaller
# 0  1  1  0  - Not Portable, ignore uninstall Flash
# 0  1  0  1  - Not Portable, ignore uninstall Revo
# 0  1  0  0  - Not Portable, No Uninstall
#
# If Portable, uninstaller required (either Flash, Revo, or other programmed in later)
# If Portable, but no uninstaller, error ??
# In not portable, ignore uninstaller settings


# ***************
# *** Get-PSScriptRoot
# ***
# *** Gets the directory information for where the script started running from.
# ***
# *** Parameters
# ***  None
# ***
# *** Returns:
# ***  [string] of the directory this PS File is located at.
# ***************
Function Get-PSScriptRoot
{
    [string]$ScriptRoot = ""

    Try {
        $ScriptRoot = Get-Variable -Name PSScriptRoot -ValueOnly -ErrorAction Stop
    }
    Catch {
        $ScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
    }

    return $ScriptRoot
}


# ***************
# *** Load-ConfigFile
# ***
# *** Parameters
# ***  [string] configFile - Location of the Configuration File to load. If configFile not set, then default
# ***        value is the file "PortableFlash.cfg" in the current directory the script is stored in.
# ***  [switch] UseDefaults - If set, uses default values instead of the config file values
# ***
# *** If configFile not set, then default config file is the "PortableFlash.cfg" in the current directory
# ***  the script is stored in. If no config file is found or values are missing, then the user is asked if
# ***  they wish to use the default values for the missing items.
# ***
# *** Default Values.
# ***  currDownloads = ([System.IO.Path]::GetTempPath())
# ***  portdir = null, install as local
# ***  webFlashVerFile = https://fpdownload.macromedia.com/pub/flashplayer/masterversion/masterversion.xml
# ***  tempVerFile = ($currDownloads)\([System.IO.Path]::GetRandomFileName())
# ***  webFlashInstaller = https://fpdownload.macromedia.com/pub/flashplayer/latest/help/install_flash_player.exe
# ***  FlashInstaller = ($currDownloads)\install_flash_player.exe
# ***  webFlashUninstaller = https://fpdownload.macromedia.com/get/flashplayer/current/support/uninstall_flash_player.exe
# ***  FlashUninstaller = ($currDownloads)\uninstall_flash_player.exe
# ***  RevoCmd = ($env:ProgramW6432)\VS Revo Group\Revo Uninstaller Pro\RevoCmd.exe
# ***  RevoCmdArg = "/m ""*flash*npapi"" /u"
# ***  RevoUninProg = ($env:ProgramW6432)\VS Revo Group\Revo Uninstaller Pro\RevoUninPro.exe
# ***  RevoUninArg =  "/mu ""{0}"" /path ""{1}"" /mode Advanced /64"
# ***************
Function Load-ConfigFile {
    param (
        [Parameter (Mandatory=$false,Position=0)][string]$configFile,
        [Parameter (Mandatory=$false)][switch]$UseDefaults
    )
    # ****************
    # ***  STEP 1  ***
    # ****************

    $isMissingValues = $false
    $fillInMissingValues = $false
    $bContinue = $true
    [xml]$configFileData = $null
    $missingValueList = @()

    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Loading and setting configeration values" `
        -PercentComplete (($currStep/$numOfSteps)*100)

    # *** If defaults are not to be used, then try loading the config file and the values set in it.
    if (-not $UseDefaults ) {
        # *** If no config file set, use the default config file.
        if (($null -eq $configFile) -or ($configFile.Trim() -eq "")) {
            $configFile = Join-Path (Get-PSScriptRoot) "PortableFlash.cfg"
        }

        # *** If the cofig file is found, try loading and parsing the XML values.
        if (Test-Path -LiteralPath $configFile) {
            try{
                $configFileData = Get-Content $configFile -ErrorAction Stop
                
                $displayErrors = $configFileData.config.Prompts.Errors
                $displaySuccess = $configFileData.config.Prompts.Success
                $displayNoUpdate = $configFileData.config.Prompts.NoUpdate

                $currDownloads = $configFileData.config.TempDownloadDirectory
                $portdir = $configFileData.config.Portable.PortablePluginsDirectory
                $webFlashVerFile = $configFileData.config.Flash.FlashVerFile
                $webFlashInstaller = $configFileData.config.Flash.FlashInstaller
                $webFlashUninstaller = $configFileData.config.Uninstaller.FlashUninstaller
                $RevoCmd = $configFileData.config.Uninstaller.RevoCmd
                $RevoUninProg = $configFileData.config.Uninstaller.RevoUninstallProg

                # *** Verify that all the values loaded, and note which ones did not.
                if (($null -eq $displayErrors) -or ($displayErrors.Trim() -eq "") -or
                    ($displayErrors.Trim().StartsWith("Y")) -or
                    ($displayErrors.Trim().StartsWith("T")) -or
                    ($displayErrors.Trim().StartsWith("1"))) {
                    $displayErrors = $true
                }
                else {
                    $displayErrors = $False
                }

                if (($null -eq $displaySuccess) -or ($displaySuccess.Trim() -eq "") -or
                    ($displaySuccess.Trim().StartsWith("Y")) -or
                    ($displaySuccess.Trim().StartsWith("T")) -or
                    ($displaySuccess.Trim().StartsWith("1"))) {
                    $displaySuccess = $true
                }
                else {
                    $displaySuccess = $False
                }

                if (($null -eq $displayNoUpdate) -or ($displayNoUpdate.Trim() -eq "") -or
                    ($displayNoUpdate.Trim().StartsWith("Y")) -or
                    ($displayNoUpdate.Trim().StartsWith("T")) -or
                    ($displayNoUpdate.Trim().StartsWith("1"))) {
                    $displayNoUpdate = $true
                }
                else {
                    $displayNoUpdate = $False
                }


                if (($null -eq $currDownloads) -or ($currDownloads.Trim() -eq "") -or !(Test-Path -LiteralPath $currDownloads)) {
                    $currDownloads = $null
                    $missingValueList += "TempDownloadDirectory"
                    $isMissingValues = $true
                }
                if (($null -eq $portdir) -or ($portdir.Trim() -eq "")) {
                    $portdir = $null
                    $isPortable = $false
                }
                else {
                    $isPortable = $true
                }
                if (($null -eq $webFlashVerFile) -or ($webFlashVerFile.Trim() -eq "")) {
                    $webFlashVerFile = $null
                    $missingValueList += "Flash.FlashVerFile"
                    $isMissingValues = $true
                }
                if (($null -eq $webFlashInstaller) -or ($webFlashInstaller.Trim() -eq "")) {
                    $webFlashInstaller = $null
                    $missingValueList += "Flash.FlashInstaller"
                    $isMissingValues = $true
                }
                if ( ($isPortable) -and (($null -eq $webFlashUninstaller) -or ($webFlashUninstaller.Trim() -eq "")) -and
                     (($null -eq $RevoCmd) -or ($RevoCmd.Trim() -eq "")  -or !(Test-Path -LiteralPath $RevoCmd)) -and
                     (($null -eq $RevoUninProg) -or ($RevoUninProg.Trim() -eq "") -or !(Test-Path -LiteralPath $RevoUninProg)) ) {

                    $webFlashUninstaller = $null
                    $RevoCmd = $null
                    $RevoUninProg = $null
                    $missingValueList += @("Uninstaller.webFlashUninstaller", "Uninstaller.RevoCmd", "Uninstaller.RevoUninstallProg")
                    $isMissingValues = $true
                }
                elseif ( ($isPortable) -and (($null -eq $webFlashUninstaller) -or ($webFlashUninstaller.Trim() -eq "")) -and
                         (($null -eq $RevoCmd) -or ($RevoCmd.Trim() -eq "") -or !(Test-Path -LiteralPath $RevoCmd)) ) {
                    $webFlashUninstaller = $null
                    $RevoCmd = $null
                    $missingValueList += "Uninstaller.RevoCmd"
                    $isMissingValues = $true
                }
                elseif ( ($isPortable) -and (($null -eq $webFlashUninstaller) -or ($webFlashUninstaller.Trim() -eq "")) -and
                         (($null -eq $RevoUninProg) -or ($RevoUninProg.Trim() -eq "") -or !(Test-Path -LiteralPath $RevoUninProg)) ) {
                    $webFlashUninstaller = $null
                    $RevoUninProg = $null
                    $missingValueList += "Uninstaller.RevoUninstallProg"
                    $isMissingValues = $true
                }
                elseif (-not $isPortable) {
                    $webFlashUninstaller = $null
                    $RevoCmd = $null
                    $RevoUninProg = $null
                    $bUseFlashUninstaller = $false
                    $bUseRevoUninstaller = $false
                }
                
                if (($null -ne $webFlashUninstaller) -and ($webFlashUninstaller.Trim() -ne "")) {
                    $bUseFlashUninstaller = $true
                    $bUseRevoUninstaller = $false
                }
                elseif ((($null -ne $RevoCmd) -and ($RevoCmd.Trim() -ne "") -and (Test-Path -LiteralPath $RevoCmd)) -and
                         (($null -ne $RevoUninProg) -and ($RevoUninProg.Trim() -ne "") -and (Test-Path -LiteralPath $RevoUninProg)) ) {
                    $bUseFlashUninstaller = $false
                    $bUseRevoUninstaller = $true
                }
            }
            catch {
                # *** Let the user know if any errors occurs during the loading of the config file. Then note to exit program
                # *** Can't continue with faulty config file.
                $Message = "Error occured while loading the config file located at $configFile. Will exit out of program." + [System.Environment]::NewLine +
                    $_.Exception.Message
                $Title = "Config File error"
                $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
            
                $bContinue = $false
            }
            finally {
                # *** Cleanup memory
                Clear-Variable configFileData
            }
        }
        else {
            # *** No config file found, check if user wishes to use default values or exit program.
            $Message = "No config file found at $configFile" + [System.Environment]::NewLine +
                "Click 'OK' if you wish to use default values." + [System.Environment]::NewLine +
                "Click 'Cancel' to quit the program."
            $Title = "Config File Not Found"
            $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OKCancel)

            if(($PopUp_Status -eq "Yes") -or ($PopUp_Status -eq "OK")) {
                $fillInMissingValues = $true
            }
            else {
                $fillInMissingValues = $false
                $bContinue = $false
            }
        }
    }
    
    # *** If missing values and code to continue, then check if user wishes to use default values for missing items or exit program
    if ($bContinue -and $isMissingValues) {
        $Message = "The following config file values are missing or invalid:" + [System.Environment]::NewLine +
            "  $($missingValueList -join "$([System.Environment]::NewLine)  ")." + [System.Environment]::NewLine +
            "Click 'OK' if you wish to fill those in with the default values." + [System.Environment]::NewLine +
            "Click 'Cancel' to quit the program."
        $Title = "Config File Missing Values"
        $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OKCancel)

        if(($PopUp_Status -eq "Yes") -or ($PopUp_Status -eq "OK")) {
            $fillInMissingValues = $true
        }
        else {
            $fillInMissingValues = $false
            $bContinue = $false
        }
    }

    # *** Verify if to continue due to certain variables are dependant on config values.
    if ($bContinue) {
        # *** If missing values, or to use default value, update config variables.
        if ($fillInMissingValues -or $UseDefaults) {

            # *** If any value wasn't set or the default is to be used, then set with the default values.
            if ($UseDefaults -or ($null -eq $currDownloads)) {
                $currDownloads = [System.IO.Path]::GetTempPath()
            }

            if ($UseDefaults -or (-not $isPortable)) {
                $portdir = $null
            }

            if ($UseDefaults -or ($null -eq $webFlashVerFile)) {
                $webFlashVerFile = $FLASH_VER_FILE_URL
            }

            if ($UseDefaults -or ($null -eq $webFlashInstaller)) {
                $webFlashInstaller = $FLASH_INSTALLER_URL
            }

            # *** If not UseDefaults, and none set, then use FlashUninstaller, since
            # *** don't know if/where Revo is installed.
            # *** If not UseDefaults and either Revo item is set, then use the directory
            # *** structure of one to populate the other.
            # *** If UseDefaults set or it's not portable, these are not to be set since
            # *** they are used for a portable install and UseDefaults is a local install.
            if ((-not $UseDefaults) -and $isPortable -and
                (($null -eq $webFlashUninstaller) -and ($null -eq $RevoCmd) -and ($null -eq $RevoUninProg)) ) {
                $webFlashUninstaller = $FLASH_UNINSTALLER_URL
                $bUseFlashUninstaller = $true
                $bUseRevoUninstaller = $false
            }
            elseif ((-not $UseDefaults) -and $isPortable -and
                    ($null -eq $RevoCmd) -and ($null -ne $RevoUninProg)) {
                $RevoCmd = Join-Path ($RevoUninProg.Remove($RevoUninProg.LastIndexOf([System.IO.Path]::DirectorySeparatorChar)+1)) $REVO_CMD
                $bUseFlashUninstaller = $false
                $bUseRevoUninstaller = $true
            }
            elseif ((-not $UseDefaults) -and $isPortable -and
                    ($null -eq $RevoUninProg) -and ($null -ne $RevoCmd)) {
                $RevoUninProg = Join-Path ($RevoCmd.Remove($RevoCmd.LastIndexOf([System.IO.Path]::DirectorySeparatorChar)+1)) $REVO_UNINPROG
                $bUseFlashUninstaller = $false
                $bUseRevoUninstaller = $true
            }
            elseif ($UseDefaults -or (-not $isPortable)) {
                $webFlashUninstaller = $null
                $RevoCmd = $null
                $RevoUninProg = $null
                $bUseFlashUninstaller = $false
                $bUseRevoUninstaller = $false
            }
        }
        
        $Script:displayErrors = $displayErrors
        $Script:displaySuccess = $displaySuccess
        $Script:displayNoUpdate = $displayNoUpdate
        $Script:currDownloads = $currDownloads
        $Script:portdir = $portdir
        $Script:isPortable = $isPortable
        $Script:webFlashVerFile = $webFlashVerFile
        $Script:webFlashInstaller = $webFlashInstaller
        $Script:webFlashUninstaller = $webFlashUninstaller
        $Script:RevoCmd = $RevoCmd
        $Script:RevoUninProg = $RevoUninProg
#        $Script:tempVerFile = Join-Path $currDownloads ([System.IO.Path]::GetRandomFileName())
        $Script:FlashInstaller = Join-Path $currDownloads $FLASH_INSTALLER
        $Script:FlashUninstaller = Join-Path $currDownloads $FLASH_UNINSTALLER
        $Script:RevoCmdArg = $REVO_CMD_ARGS
        $Script:RevoUninArg =  $REVO_UNINPROG_ARGS
        $Script:bUseFlashUninstaller = $bUseFlashUninstaller
        $Script:bUseRevoUninstaller = $bUseRevoUninstaller
    }

    return $bContinue
} # *** end Load-ConfigFile

# Test-CurrentInstall
Function Test-CurrentInstalled {
    # ****************
    # ***  STEP 2  ***
    # ****************

    $isWebNewer = $false
    $installedDir = ""
    $flashUtilDll = "FlashUtil"

    # *** Check installed Flash version ***
    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Checking if installed version needs updating" `
        -PercentComplete (($currStep/$numOfSteps)*100)

    if ($Script:is64Bit) {
        # *** 64-bit Flash files are used ***
        $flashUtilDll += "64*.dll"

    } else {
        # *** 32-bit Flash files are used ***
        $flashUtilDll += "32*.dll"
    }

    if ((-not $Script:isPortable) -and ($Script:is64Bit)) {
        # *** Locally installed 64-bit Flash files are used ***
        $installedDir = Join-Path $Env:SystemRoot "SysWOW64"
    }
    elseif (-not $Script:isPortable) {
        # *** Locally installed 32-bit Flash files are used ***
        $installedDir = Join-Path $Env:SystemRoot "System32"
    }
    else {
        # *** Portable install Flash files are used ***
        $installedDir = $Script:portdir
    }

    if (Test-Path (Split-Path -Path $installedDir -Qualifier) ) {
        # *** Retrieve most current FlashUtil*.dll file in portable/local installed directory
        # *** and get the full file name to find out which version is installed.
        $installedVerFile = $(Join-Path $installedDir $flashUtilDll -ErrorAction SilentlyContinue |
                                Get-ChildItem -ErrorAction SilentlyContinue |
                                Sort-Object -Descending |
                                Select-Object -First 1).Name

        # *** If the installed version exists, find its version
        # *** then dl the current version list from Adobe and
        # *** compare if installed is current or needs updating
        if ($installedVerFile -ne $null) {
            $installedVer = $installedVerFile.Substring($installedVerFile.IndexOf("_")+1, ($installedVerFile.LastIndexOf("_") - $installedVerFile.IndexOf("_")) -1).Split("_")


<#
            # *** This method of retrieval stopped working Jan 2018.
            # *** Changed to Invoke-WebRequest with in-code XML conversion.

            $tempVerFile = $Script:tempVerFile

            Start-BitsTransfer $Script:webFlashVerFile $tempVerFile -TransferType Download `
                -Description "Downloading current Flash version list to compare to installer version" `
                -DisplayName "Downloading Curret Flash Version List" `
                -ErrorAction SilentlyContinue
        
            Get-BitsTransfer | Complete-BitsTransfer | Out-Null # Just to make sure it's cleaned up

            if (Test-Path -LiteralPath $tempVerFile) {
#>
            $tempResults = Invoke-WebRequest -Uri $Script:webFlashVerFile

            if ($tempResults.StatusCode -eq 200) {
                try {
#                    [xml]$webVerData = Get-Content $tempVerFile
                    [xml]$webVerData = $tempResults.Content
                    $webVer = $($webVerData.version.release.NPAPI_win.Attributes[0].'#text').Split(",")

                    # *** If any spot is greater, then webVer is newer
                    # *** If all spots are same, then webVer is same
                    # *** If any spot is lesser, then webVer is older - possible problem
                    for ($i=0; $i -lt $webVer.Length; $i++){
                        if ([int]$webVer[$i] -gt [int]$installedVer[$i]) { $isWebNewer = $true; break}
                        elseif ([int]$webVer[$i] -lt [int]$installedVer[$i]) { break }
                    }
                }
                catch {
                    # *** When version file not valid XML, play it safe.
                    # *** Inform user and exit out.
                    if ($Script:displayErrors) {
                        $Message = "The Flash Version file is corrupted or badly formed. Please verify the URL address and try again. Exiting out of program" + 
                            [System.Environment]::NewLine + "  URL: $($Script:webFlashVerFile)" + [System.Environment]::NewLine + 
                            [System.Environment]::NewLine + "  Exception:" + $_.Exception.Message
                        $Title = "Version File Error"
                        $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
                    }
                    $isWebNewer = $false
                }
                finally {
#                    Remove-Item $tempVerFile -Force -ErrorAction SilentlyContinue
                    Clear-Variable webVerData
                    Clear-Variable tempResults
                }
            }
            else {
                # ~~~ TODO ~~~
                # *** When version file not downloaded, play it safe.
                # *** Inform user and exit out.
                if ($Script:displayErrors) {
                    $Message = "The Flash Version file is not found. Please verify the download from and to location permissions. Exiting out of program" + 
                        [System.Environment]::NewLine + "  Download Status Code: $($tempResults.StatusCode)" + 
                        [System.Environment]::NewLine + "  Download location: $($Script:currDownloads)"
                    $Title = "Version File Error"
                    $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
                }
                $isWebNewer = $false
            }
        }
        else {
            # *** No installed version found
            # *** Web is newer and needs installing
            $isWebNewer = $true
        }
    
        if ((-not $isWebNewer) -and ($Script:displayNoUpdate)) {
            $Message = "The installed version is already the most recent version. Exiting out of program"
            $Title = "Installed is Up-to-date"
            $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
        }
    }
    else {
        $isWebNewer = $false
    
        if ($Script:displayErrors) {
            $Message = "The installed directory drive does not exist. Update check not performed" +
                        [System.Environment]::NewLine + "  Installed directory: $installedDir"
            $Title = "Drive Not Found Error"
            $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
        }
    }

    return $isWebNewer
} # *** end Test-CurrentInstalled


# Download-Installer
function Download-Installer {
    # ****************
    # *** STEP 3.1 ***
    # ****************

    $isDownloaded = $false
    $DLError = $null

    # *** If the web is newer, download latest installer
    # *** and then update the flash player for portable
    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Downloading newer version of Flash installer" `
        -PercentComplete ( ( $currStep/$numOfSteps )*100 )

    try {
        Start-BitsTransfer $Script:webFlashInstaller $Script:FlashInstaller -TransferType Download `
            -Description "Installed Flash is not up-to-date. Downloading new Flash installer to update plugin" `
            -DisplayName "Downloading Flash Installer" `
            -ErrorAction Stop
        $isDownloaded = $true
    }
    catch {
        if ($Script:displayErrors) {
            $Message = "Error occured during downloading of Flash installer. Please verify network connections." + [System.Environment]::NewLine + $_.Exception.Message
            $Title = "Download error"
            $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
        }
        $isDownloaded = $false
    }
    finally {
        Get-BitsTransfer | Complete-BitsTransfer | Out-Null # Just to make sure it's cleaned up
    }

    if ($Script:isPortable -and $Script:bUseFlashUninstaller) {
        $isDownloaded = Download-Uninstaller
    }

    return $isDownloaded
} # *** end Download-Installer

# Download-Uninstaller
function Download-Uninstaller {
    # ****************
    # *** STEP 3.2 ***
    # ****************

    $bContinue = $false
    $DLError = $null

    # *** If the web is newer, download latest uninstaller
    # *** for after installation occured.
    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Downloading Flash Uninstaller" `
        -PercentComplete ( ( ($currStep+0.5)/$numOfSteps )*100 )

    if ($Script:bUseFlashUninstaller) {
        try {
            Start-BitsTransfer $Script:webFlashUninstaller $Script:FlashUninstaller -TransferType Download `
                -Description "Installed Flash is not up-to-date. Downloading new Flash Uninstaller to remove files after updated" `
                -DisplayName "Downloading Flash Uninstaller" `
                -ErrorAction Stop
            $bContinue = $true
        }
        catch {
            if ($Script:displayErrors) {
                $Message = "Error occured during downloading of Flash Uninstaller. Please verify network connections." + [System.Environment]::NewLine + $_.Exception.Message
                $Title = "Download error"
                $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
            }
            $bContinue = $false
        }
        finally {
            Get-BitsTransfer | Complete-BitsTransfer | Out-Null # Just to make sure it's cleaned up
        }
    }
    else {
        $bContinue = $true
    }

    return $bContinue
} # *** end Download-Uninstaller


function Install-Flash {
    # ****************
    # ***  STEP 4  ***
    # ****************
    
    $bInstallerRan = $false
    $bContinue = $true

    # *** Check for Flash Installer        ***
    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Running Plugin Installer to retreive files" `
        -PercentComplete (($currStep/$numOfSteps)*100)

    $flashPlugin = $Script:FlashInstaller

    if ($flashPlugin -ne $null -and $flashPlugin.trim() -ne "") {
        # *** check if Firefox or it's clones  ***
        # ***   are running and ask to have    ***
        # ***   them stopped.                  ***
        $runningFF = Get-Process "firefox" -ErrorAction SilentlyContinue
        if ($runningFF -ne $null) {
            $Message = "Close all instances of FireFox (and it's clones, e.g. IceWeasle, TOR, etc.) before clicking 'OK'."
            $Title = "Close Browsers"
            $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OKCancel)
            if(($PopUp_Status -ine "Yes") -and ($PopUp_Status -ine "OK")) {
                $bContinue = $false
            }
        }

        if ($bContinue) {
            # *** Start the Flash plugin installer ***
            $diagProc = Start-Process $flashPlugin -PassThru -ArgumentList "-install" -ErrorAction SilentlyContinue
            $diagProc.WaitForExit()
            Clear-Variable diagProc

            Remove-Item $flashPlugin -Force

            $bInstallerRan = $true
        }
    }
    else {
        # *** Installer not found. let user    ***
        # ***   know about issue.              ***
        if ($Script:displayErrors) {
            $Message = "Flash installer not found. Verify installer dl'd to correct location ($flashPlugin) and is a valid installer."
            $Title = "Flash installer not found"
            $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
        }
        $bInstallerRan = $false
    }
    
    if (($bInstallerRan) -and (-not $Script:isPortable) -and ($Script:displaySuccess)) {
        $Message = "The Flash plugin finished installing the updated version."
        $Title = "Flash Installed"
        $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
    }

    return ($bInstallerRan -and $Script:isPortable)
} # *** end Install-Flash


function Remove-OldFiles {
    # ****************
    # ***  STEP 5  ***
    # ****************

    # *** Delete the old Flash Files from  ***
    # ***   Firefox portable directory     ***
    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Removing old Flash version files" `
        -PercentComplete (($currStep/$numOfSteps)*100)

    $RemoveFileList = @((Join-Path $Script:portdir "flashplayer.xpt"), `
                        (Join-Path $Script:portdir "FlashPlayerPlugin*"), `
                        (Join-Path $Script:portdir "FlashUtil*"), `
                        (Join-Path $Script:portdir "NPSWF*"))
    $RemoveFileList | ForEach-Object -Begin {$CurrentFile = 0} -Process {
        $CurrentFile++
        Remove-Item $_ -Force -ErrorAction SilentlyContinue
        Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
            -Status "Removing old Flash version files $CurrentFile of $($RemoveFileList.Count)" `
            -PercentComplete (( ( ($CurrentFile/$RemoveFileList.Count) + $currStep)/$numOfSteps) *100)
        Start-Sleep .25
    }
    return $true
} # *** end Remove-OldFiles


function Copy-NewFiles {
    # ****************
    # ***  STEP 6  ***
    # ****************

    # *** Test if 64 or 32 bit system      ***
    $AddFileList = @()

    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Copying new Flash version files" `
        -PercentComplete (($currStep/$numOfSteps)*100)

    if ($Script:is64Bit) {
        # *** Copying 64 bit Flash files from System32 directory ***

        # *** If 64, copy Flash 64 files from   ***
        # ***   System32 directory, also set    ***
        # ***   plugdir = plug64dir to copy 32  ***
        # ***   bit Flash Files from SysWOW64   ***
        $plugdir = $Script:plug64dir
        $AddFileList += @((Join-Path $Script:plug32dir "FlashUtil64*"), `
                          (Join-Path $Script:plug32dir "NPSWF64*"))

    } else {
        # *** 32-bit system ***

        # *** If 32, set plugdir = plug32dir to ***
        # ***   copy 32 bit Flash Files from    ***
        # ***   System32                        ***
        $plugdir = $Script:plug32dir
    }

    # *** Copy from SysWOW64 directory if 64-bit ***
    # *** Copy from System32 directory if 32-bit ***
    $AddFileList += @((Join-Path $plugdir "flashplayer.xpt"), `
                      (Join-Path $plugdir "FlashPlayerPlugin*"), `
                      (Join-Path $plugdir "FlashUtil32*"), `
                      (Join-Path $plugdir "NPSWF32*"))
    $AddFileList | ForEach-Object -Begin {$CurrentFile = 0} -Process {
        $CurrentFile++
        Copy-Item $_ -Destination $Script:portdir -Force -ErrorAction SilentlyContinue
        Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
            -Status "Copying new Flash version files $CurrentFile of $($AddFileList.Count)" `
            -PercentComplete (( ( ($CurrentFile/$AddFileList.Count) + $currStep)/$numOfSteps)*100)
        Start-Sleep .25
    }
    return $true
} # *** end Copy-NewFiles


function Uninstall-Flash {
    # ****************
    # ***  STEP 7  ***
    # ****************

    $bContinue = $true

    # *** If Installer ran successfully and user ***
    # ***   wished to continue, run Uninstaller  ***
    # ***   to romove extra f5les/entries        ***
    Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
        -Status "Running Plugin Uninstaller to remove files Step 1" `
        -PercentComplete (($currStep/$numOfSteps)*100)

    # *** check if Firefox or it's clones  ***
    # ***   are running and ask to have    ***
    # ***   them stopped.                  ***
    $runningFF = Get-Process "firefox" -ErrorAction SilentlyContinue
    if ($runningFF -ne $null) {
        $Message = "Close all instances of FireFox (and it's clones, e.g. IceWeasle, TOR, etc.) before clicking 'OK'."
        $Title = "Close Browsers"
        $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OKCancel)
        if(($PopUp_Status -ine "Yes") -and ($PopUp_Status -ine "OK")) {
            $bContinue = $false
        }
    }
    
    if ($bContinue) {
        if (-not $Script:bUseFlashUninstaller) {
            # *** Run RevoCmd to find Flash        ***
            # ***   Uninstaller Name & Location    ***
            $RevoProcStartInfo = New-Object System.Diagnostics.ProcessStartInfo($Script:RevoCmd, $Script:RevoCmdArg)
            $RevoProcStartInfo.RedirectStandardError = $true
            $RevoProcStartInfo.RedirectStandardOutput = $true
            $RevoProcStartInfo.CreateNoWindow = $true
            $RevoProcStartInfo.UseShellExecute = $false 

            $RevoProcess = New-Object System.Diagnostics.Process
            $RevoProcess.StartInfo = $RevoProcStartInfo 
            $RevoProcess.Start() | Out-Null 
            $RevoProcess.WaitForExit() 
            $ProcessStdOutput = $RevoProcess.StandardOutput.ReadToEnd()
            $ProcessErrOutput = $RevoProcess.StandardError.ReadToEnd()
        }
        else {
            $diagProc = Start-Process $Script:FlashUninstaller -PassThru -ArgumentList "-uninstall" -ErrorAction SilentlyContinue -WindowStyle Minimized
            $diagProc.WaitForExit()
            Clear-Variable diagProc
        }
    
        Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
            -Status "Running Plugin Uninstaller to remove files Step 2" `
            -PercentComplete ( ( ( (1/2)+$currStep )/$numOfSteps )*100 )

        if (-not $Script:bUseFlashUninstaller) {
            # *** Convert returned info to usable  ***
            # ***   String Array, then place in    ***
            # ***   Argument String.               ***
            # *** Replace consecutive NewLines with***
            # ***   temp character, then split the ***
            # ***   resulting string by the temp   ***
            # ***   character. 1st 2 items in array***
            # ***   are the Name & Location        ***
            $RevoCmdOut = [regex]::Replace($ProcessStdOutput,"($([System.Environment]::NewLine)*)","*").Trim("*").Split("*")
    
            # *** If String Array doesn't contain  ***
            # ***   at least 2 items, then program ***
            # ***   wasn't found. Don't continue   ***
            if ($RevoCmdOut.Count -ge 2) {
                $RevoUninArg = $Script:RevoUninArg -f $RevoCmdOut[0],$($RevoCmdOut[1].Substring(0,$RevoCmdOut[1].LastIndexOf("\")))

                # *** Run RevoUninstaller to uninstall ***
                # ***   Flash and remove the files,    ***
                # ***   directories, & registry entries***
                $diagProc = Start-Process $Script:RevoUninProg -PassThru -ArgumentList $RevoUninArg -ErrorAction SilentlyContinue -WindowStyle Minimized
                $diagProc.WaitForExit()
                Clear-Variable diagProc
            }
        }
        else {
            # ~~~ TODO ~~~
            # Figure out win 7 delets vs win 8+
            # Figure out what to delete no matter which uninstaller method used.
            $RemoveFileList = @()

            if (($Script:isWin7) -and ($Script:is64Bit)) {
                # Windows 7, 64bit system
                $RemoveFileList += @( (($Env:SystemRoot, "SysWOW64", "FlashPlayerApp.exe") -join [System.IO.Path]::DirectorySeparatorChar), `
                                      (($Env:SystemRoot, "SysWOW64", "FlashPlayerCPLApp.cpl") -join [System.IO.Path]::DirectorySeparatorChar), `
                                      $plug64dir)
            }
            elseif ($Script:is64Bit) {
                # Windows 8 or higher, 64 bit system
                $RemoveFileList += @( (Join-Path $plug64dir "flashplayer.xpt"), `
                                      (Join-Path $plug64dir "flashPlayerPlugin*.exe"), `
                                      (Join-Path $plug64dir "FlashUtil32*Plugin.dll"), `
                                      (Join-Path $plug64dir "FlashUtil32*Plugin.exe"), `
                                      (Join-Path $plug64dir "NPSWF32*.dll"), `
                                      (Join-Path $plug32dir "FlashUtil64*Plugin.dll"), `
                                      (Join-Path $plug32dir "FlashUtil64*Plugin.exe"), `
                                      (Join-Path $plug32dir "NPSWF64*.dll") )

            }
            elseif (-not $Script:isWin7) {
                # Windows 8 or higher, 32 bit system
                $RemoveFileList += @( (Join-Path $plug32dir "flashplayer.xpt"), `
                                      (Join-Path $plug32dir "flashPlayerPlugin*.exe"), `
                                      (Join-Path $plug32dir "FlashUtil32*Plugin.dll"), `
                                      (Join-Path $plug32dir "FlashUtil32*Plugin.exe"), `
                                      (Join-Path $plug32dir "NPSWF32*.dll") )
            }
            
            if ($Script:isWin7) {
                # Windows 7, 32bit & 64bit system
                $RemoveFileList += @( (($Env:SystemRoot, "System32", "FlashPlayerApp.exe") -join [System.IO.Path]::DirectorySeparatorChar), `
                                      (($Env:SystemRoot, "System32", "FlashPlayerCPLApp.cpl") -join [System.IO.Path]::DirectorySeparatorChar), `
                                      $plug32dir )
            }

            $RemoveFileList += @( (($env:APPDATA, "Adobe", "Flash Player") -join [System.IO.Path]::DirectorySeparatorChar), `
                                  (($env:APPDATA, "Macromedia", "Flash Player") -join [System.IO.Path]::DirectorySeparatorChar), `
                                  (($Env:SystemRoot, "Prefetch", "PLUGIN-CONTAINER*.pf") -join [System.IO.Path]::DirectorySeparatorChar), `
                                  (($Env:SystemRoot, "Prefetch", "flashpl*.pf") -join [System.IO.Path]::DirectorySeparatorChar), `
                                  (($Env:SystemRoot, "Prefetch", "firefox*.pf") -join [System.IO.Path]::DirectorySeparatorChar), `
                                  $Script:FlashUninstaller )

            $RemoveFileList | ForEach-Object -Begin {$CurrentFile = 0} -Process {
                $CurrentFile++
                Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
                Write-Progress -Id 100 -Activity "Updating Flash Pluging" `
                    -Status "Removing old Flash version files $CurrentFile of $($RemoveFileList.Count)" `
                    -PercentComplete (( ( ($CurrentFile/$RemoveFileList.Count) + $currStep)/$numOfSteps) *100)
                Start-Sleep .25
            }
        }
    }
    
    if ($Script:displaySuccess) {
        $Message = "The Flash plugin finished installing the updated version."
        $Title = "Flash Installed"
        $PopUp_Status = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK)
    }

    return $true
} # *** end Uninstall-Flash


# *** set local variables ***
$Arch = $Env:PROCESSOR_ARCHITECTURE # Based architecture system is using, 64-bt vs 32-bit
$is64Bit = ($Env:PROCESSOR_ARCHITECTURE -eq 'amd64') # Based architecture system is using, 64-bt vs 32-bit
$isWin7 = ([version](Get-WmiObject -Class Win32_OperatingSystem).version -eq [version]6.1)
$plug32dir = ($Env:SystemRoot, "System32", "Macromed", "Flash") -join [System.IO.Path]::DirectorySeparatorChar # Where 32-bit files are located
$plug64dir = ($Env:SystemRoot, "SysWOW64", "Macromed", "Flash") -join [System.IO.Path]::DirectorySeparatorChar # Where 64-bit files are located

$bInstallerRan = $false # States if the installer ran.


# *** pre-set variables loaded from Config FIle.

$displayErrors = $true
$displaySuccess = $true
$displayNoUpdate = $true

$portdir = "" # Directory the portable flash to be installed
$isPortable = $false # Specifies if current install is a portable install
$currDownloads = "" # Directory where to download the files.

$RevoCmd = "" # Location of the Revo Uninstaller RevoCMD.exe file (for checking if file is installed).
$RevoCmdArg = "" # Specifies want full name & location of uninstaller
$RevoUninProg = "" # Location of Revo Uninstaller Pro EXE (for uninstalling the program).
$RevoUninArg =  "" # Specifies unstall program name {0} at location {1} using advanced mode for 64

$webFlashVerFile = "" # Web URL for the Current Flash Verion file
# $tempVerFile = "" # Location to place copy of Flash Version File

$webFlashInstaller = "" # Web URL for the Current Flash Installer
$FlashInstaller = "" # Location to place copy of Flash Installer

$webFlashUninstaller = "" # Web URL for the Current Flash Uninstaller
$FlashUninstaller = "" # Location to place copy of Flash Uninstaller

# *** Neither of these can be true at same time, but both should be false if local install
$bUseFlashUninstaller = $false # Specifies if Flash Uninstaller is to be used
$bUseRevoUninstaller = $false # Specifies if Revo Uninstaller is to be used 

# *** Array of the functions to run, each must return true or false
# *** One is for functions used in both local & portable installs,
# *** the other is only functions used in portable installs
$localFuncArray = @( {Test-CurrentInstalled}; {Download-Installer}; {Install-Flash} )
$portableFuncArray = @( {Remove-OldFiles}; {Copy-NewFiles}; {Uninstall-Flash} )

$FuncArray = $localFuncArray
$numOfSteps = $FuncArray.Count + 1 # Number of total steps for the install process (Including Load-ConfigFile)
$currStep = 0 # Starting step number, 0-based, so pre-step is 0

# *** Load the config file data, use defaults if any error or item missing.
if (Load-ConfigFile (Join-Path (Get-PSScriptRoot) "PortableFlash.cfg")) {
    if($Script:isPortable) {
        # *** If this is a portable install, update the total number of 
        # *** functions called and append the portable functions to call
        $Script:numOfSteps += $Script:portableFuncArray.Count
        $FuncArray += $Script:portableFuncArray
    }
    # *** Loop through the functions, increasing the counter each time. If any return false, end the install process.
    $FuncArray | ForEach-Object -Begin { $Script:currStep = 0 } -Process { $Script:currStep++
        if (Invoke-Command $_) { return }
        else { break }
    }
}
# *** Done ***
Write-Progress -Id 100 -Activity "Updating Flash Plugin" `
        -Status "Completed" `
        -PercentComplete 100
Start-Sleep 1