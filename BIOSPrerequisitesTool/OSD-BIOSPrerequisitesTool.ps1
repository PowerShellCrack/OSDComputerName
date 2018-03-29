#========================================================================
#
#    Created:   2016-04-22
#     Author:   Richard tracy
#  Idea From:	Nickolaj Andersen
#
#========================================================================
[void][Reflection.Assembly]::LoadWithPartialName("System.Security")
## Variables: Script Name and Script Paths
[string]$scriptPath = $MyInvocation.MyCommand.Definition
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptFileName = Split-Path -Path $scriptPath -Leaf
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent
[string]$invokingScript = (Get-Variable -Name 'MyInvocation').Value.ScriptName

#include additional extensions
If (Test-Path -Path ($scriptRoot + '.\PowershellModules\functions.ps1')){
. ($scriptRoot + '.\PowershellModules\functions.ps1')
}
#  Get the invoking script directory
If ($invokingScript) {
	#  If this script was invoked by another script
	[string]$scriptParentPath = Split-Path -Path $invokingScript -Parent
}
Else {
	#  If this script was not invoked by another script, fall back to the directory one level above this script
	[string]$scriptParentPath = (Get-Item -LiteralPath $scriptRoot).Parent.FullName
}

##*=============================================
##* READ CONFIG.XML FILE
##*=============================================
[string]$ConfigFile = Join-Path -Path $scriptRoot -ChildPath 'OSD-BIOSConfig.xml'
[xml]$XmlConfigFile = Get-Content $ConfigFile
$UseRemoteInstead = $XmlConfigFile.app.configs.useRemote.remote
If ($UseRemoteInstead -eq $true){
    $remoteConfig = $XmlConfigFile.app.configs.useRemote.path
    If (Test-Path $remoteConfig){
        [xml]$XmlConfigFile = Get-Content $remoteConfig
    }
}
$apptitle = $XmlConfigFile.app.title
$appversion = $XmlConfigFile.app.version
$TabPageConfigs = $XmlConfigFile.app.configs.pagetabs.tab

$SupportedOperatingSystems = $XmlConfigFile.app.supported.OSbuilds.OS
$MinimumOS = $SupportedOperatingSystems | Where-Object id -eq "minimum"
[int]$MinimumOSversion = $MinimumOS.version 

$SupportedSystems = $XmlConfigFile.app.supported.hardwarePlatforms.system
$SupportedManufacturers = $SupportedSystems.manufacturer | sort -Unique
$SupportedModels = $SupportedSystems.model

[Xml.XmlElement]$XMLAdditionalProviders = $XmlConfigFile.app.configs.additionalProviders
[array]$DellProviders = $XMLAdditionalProviders.provider | Where-Object {$_.platformsupport -eq "Dell Inc."}
Foreach ($provider in $DellProviders){
    #write-host $provider.name
    #write-host $provider.enabled
    If ($provider.name -eq "Dell Command | Configure Toolkit"){
        If ($provider.enabled -eq "true") {
            $UseDellCCTK = $true
        }Else {
            $UseDellCCTK = $false
        }
        
        [string]$DellCCTKPath = $provider.path_x64
        [string]$DellCCTKPathx86 = $provider.path_x86

    }
    If ($provider.name -eq "DellBIOSPowershell"){
        If ($provider.enabled -eq "true") {
            $UseDellPSProvider = $true
        }Else {
            $UseDellPSProvider = $false
        }
        [string]$DellPSProviderPath = $provider.path_x64
        [string]$DellPSProviderPathX86 = $provider.path_x86
    }

}


#[array]$BIOSKnownUsedpwd = @($XmlConfigFile.app.configs.knownBIOSPasswords.password)
[array]$BIOSKnownUsedpwd = @($XmlConfigFile.app.configs.knownBIOSPasswords.cryptpassword)
#to encrypt load Encrypt-String and then run it, copy the results in config file 
#Encrypt-String -String <password> -Passphrase "<Passphrase>"

If ($XmlConfigFile.app.configs.debugmode -eq 'true'){
    [Boolean]$Global:LogDebugMode = $True 
} Else {
    [Boolean]$Global:LogDebugMode = $False
}

If ($XmlConfigFile.app.configs.alwaysCheckBIOS -eq 'true'){
    [Boolean]$Global:IgnorePrereqs = $true 
} Else {
    [Boolean]$Global:IgnorePrereqs = $false
}
##*=============================================
##* VARIABLE DECLARATION
##*=============================================

$Global:SMCSharedData = 0
$ComputerName = $env:COMPUTERNAME
$ComputerSystem = Get-WmiObject -Namespace "root\cimv2" -Class Win32_ComputerSystem
[string]$Manufacturer = $ComputerSystem.Manufacturer
[string]$Model = $ComputerSystem.Model
[int]$OSProductType = Get-WmiObject -Namespace "root\cimv2" -Class Win32_OperatingSystem | Select-Object -ExpandProperty ProductType
[string]$OSCaption = Get-WmiObject -Namespace "root\cimv2" -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption
[int]$OSMajor = ([System.Environment]::OSVersion.Version).Major
[int]$OSBuildNumber = ([System.Environment]::OSVersion.Version).Build


[boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' } Else { [string]$envOSArchitecture = '32-bit' }


##*=============================================
##* FUNCTIONS
##*=============================================
function Load-Form {
    $Form.Controls.Add($TabControl)
    $TabControl.Controls.AddRange(@(
        $TabSHBPage,
        $TabLoggingPage
    ))
    $TabSHBPage.Controls.AddRange(@(
        $ProgressBar, 
        $LabelHeader, 
		$LabelSupportedModel,
        $LabelSupportedOS, 
        #$LabelPowerShell, 
        $LabelUEFI,
        $OutputBoxSysInfo,

        $LabelBIOSRevision,
        $LabelBIOSPassword,
		$LabelBIOSTPM,
		$LabelBIOSTPMEnabled,
		$LabelBIOSTPMActive,
		$LabelBIOSVT,
		$LabelBIOSVTTE,
		$LabelBIOSVTDirectIO,
        $LabelLegacyROM,
		$LabelSecureBoot,

		#$PBReboot,		
		$PBModel,
        $PBOS,
        #$PBPS,
        $PBUEFI,

        #$GBReboot,
		$GBModel,
        $GBOS,
        #$GBPS,      
        $GBUEFI,
        
        $PBBIOSRevision,
        $PBBIOSPassword,
        $PBBIOSTPM,
        $PBBIOSTPMON,
        $PBBIOSTPMACT,
        $PBBIOSVT,
        $PBBIOSVTDirectIO,
		$PBBIOSVTTE,
        $PBLEGACYOROM,
        $PBSECUREBOOT,

		$LBOSVersions,
        $GBOSVersion,
		$GBSystemModel,
	
        $GBBIOSRevision,
        $GBBIOSPassword,
		$GBBIOSTPM,
		$GBBIOSTPMON,
		$GBBIOSTPMACT,       
        $GBBIOSVT,
		$GBBIOSVTDirectIO,
        $GBBIOSVTTE,
		$GBLEGACYROM,
        $GBSECUREBOOT,		
        
        $GBBIOSInfo,
        $GBTPMSettings,
        $GBVTSettings,
        $GBBootSettings,

        $CBPrerequisitesOverride,
		$GBSystemValidation,

        #$CBContinueOverride,
        $ButtonContinueExit
    ))
    $Form.Add_Shown({Retrieve-SystemInfo -DisplayType "Basic" -DisplayOutbox -IgnorePing})
    $Form.Add_Shown({Validate-RunChecks})
	$Form.Add_Shown({Validate-BIOSChecks})
	$Form.Add_Shown({$Form.Activate()})
	[void]$Form.ShowDialog()	
}

function Load-LoggingPage {
    if (-not(($TabLoggingPage.Controls | Measure-Object).Count -ge 1)) {
        $TabLoggingPage.Controls.Clear()
        $TabLoggingPage.Controls.AddRange(@(
            $OutputBoxLogging,
            $ButtonExportLogging
        ))
    }
    if ($ButtonExportLogging.Enabled -eq $false) {
		$ButtonExportLogging.Enabled = $true
	}
}

function Interactive-TabPages {
    param(
    [parameter(Mandatory=$true)]
    [ValidateSet("Enable","Disable")]
    $Mode
    )
    Begin {
        $CurrentTabPage = $TabControl.SelectedTab.Name
        switch ($Mode) {
            "Enable" { $TabPageMode = $true }
            "Disable" { $TabPageMode = $false }
        }
        $TabNameArrayList = New-Object -TypeName System.Collections.ArrayList
        foreach ($TabNameArrayListObject in (($TabControl.TabPages.Name))) {
            $TabNameArrayList.Add($TabNameArrayListObject)
        }
    }
    Process {
        foreach ($TabPageObject in $TabNameArrayList) {
            if ($Mode -like "Disable") {
                if ($CurrentTabPage -like "SHB") {
                    $TabLoggingPage.Enabled = $TabPageMode
                }
            }
            else {
                $TabSHBPage.Enabled = $TabPageMode
                $TabLoggingPage.Enabled = $TabPageMode
            }
        }
    }
}

function Interactive-Buttons {
    param(
    [parameter(Mandatory=$true)]
    [ValidateSet("Enable","Disable")]
    $Mode,
    [parameter(Mandatory=$true)]
    [ValidateSet("Prerequisites","Validation")]
    $Module
    )
    Begin {
        switch ($Mode) {
            "Enable" { $TabPageButtonMode = $true }
            "Disable" { $TabPageButtonMode = $false }
        }
    }
    Process {
        if ($Module -eq "Validation") {
            foreach ($Control in $TabPageSiteRoles.Controls) {
                if ($Control.GetType().ToString() -eq "System.Windows.Forms.ComboBox") {
                    $Control.Enabled = $TabPageButtonMode
                }
            }
        }
        if ($Module -eq "Prerequisites") {
            foreach ($Control in $TabPageOther.Controls) {
                if ($Control.GetType().ToString() -eq "System.Windows.Forms.CheckBox") {
                    $Control.Enabled = $TabPageRadioButtonMode
                }
                
            }
        }
    }
}

function Validate-RunChecks {
    $ValidateCounter = 0
    <#if (Validate-PendingReboot) {
        $ValidateCounter++
    }#>
	if (Validate-System) {
        $ValidateCounter++
    }
    if (Validate-OSBuild) {
        $ValidateCounter++
    }
    <#if (Validate-PowerShellVer) {
        $ValidateCounter++
    }
    if (Validate-Elevated) {
        $ValidateCounter++
    }#>
    if (Validate-UEFICheck) {
        $ValidateCounter++
    }
    if ($ValidateCounter -ge 3) {
        Interactive-TabPages -Mode Enable
        Write-OutputBox -OutputBoxMessage "All validation checks passed successfully" -Type "INFO: " -Object Logging
        $CBPrerequisitesOverride.Enabled = $false
    }
    else {
        Interactive-TabPages -Mode Disable
        Write-OutputBox -OutputBoxMessage "All validation checks did not pass successfully, remediate the errors and re-launch the tool or check the override checkbox to use the tool anyway" -Type "ERROR: " -Object Logging
    }
    If ($IgnorePrereqs){
        return $global:PreValidation = $true
    } Else {
        return $global:PreValidation = $ValidateCounter
    }
}

function Validate-BIOSChecks {
    $ProgressBar.Value = 0
    $ProgressBar.Maximum = 11
    $ValidateCounter = 0
    $ProgressBar.PerformStep()
    if (Load-SystemProvider) {
        $ValidateCounter++ 
    }
    $ProgressBar.PerformStep()
    if (Validate-BIOSRevision) {
        $ValidateCounter++
    }
    $ProgressBar.PerformStep()
    if (Validate-BIOSPassword) {
        $ValidateCounter++  
    }
    $ProgressBar.PerformStep()
    if (Validate-LegacyROM) {
        $ValidateCounter++  
    }
    $ProgressBar.PerformStep()
	if (Validate-SecureBoot) {
        $ValidateCounter++        
    }
    $ProgressBar.PerformStep()
    if (Validate-TPMModule) {
        $ValidateCounter++
    }
    $ProgressBar.PerformStep()
    if (Validate-TPMEnabled) {
        $ValidateCounter++ 
    }
    $ProgressBar.PerformStep()
    if (Validate-TPMActivated) {
        $ValidateCounter++
    }
    $ProgressBar.PerformStep()
    if (Validate-VTFeature) {
        $ValidateCounter++ 
    }
    $ProgressBar.PerformStep()
    if (Validate-VTDirectIO) {
        $ValidateCounter++ 
    }
    $ProgressBar.PerformStep()
    if (Validate-VTTrustedExecution) {
        $ValidateCounter++
    }
    if ($ValidateCounter -ge 11) {
       	#Interactive-TabPages -Mode Enable
        Write-OutputBox -OutputBoxMessage "BIOS checks passed successfully" -Type "INFO: " -Object Logging
        $CBContinueOverride.Enabled = $false
    }
    else {
        #Interactive-TabPages -Mode Disable
        Write-OutputBox -OutputBoxMessage "BIOS checks did not pass successfully, system may not be compatible for Secure Host Baseline." -Type "ERROR: " -Object Logging
    }
}

Function Retrieve-SystemInfo
    <#
    .SYNOPSIS
    Get Complete details of any server Local or remote
    .DESCRIPTION
    This function uses WMI class to connect to remote machine and get all related details
    .PARAMETER COMPUTERNAMES
    Just Pass computer name as Its parameter
    .EXAMPLE 
    Retrieve-SystemInfo
    .EXAMPLE 
    Retrieve-SystemInfo -ComputerName HQSPDBSP01
    .NOTES
    To get help:
    Get-Help Retrieve-SystemInfo
    .LINK
    http://sqlpowershell.wordpress.com
    #>

    {
    param(
        [ValidateSet("Detail","Basic","NetInfo")]
	    [string]$DisplayType = "Detail",
        [switch] $DisplayForm = $false,
        [switch] $DisplayOutbox = $false,
        [switch] $IgnorePing
         )

    # Declare main data hash to be populated later
    $data = @{}
    $data.' Computer Name:' = $env:ComputerName
    
    If($DisplayType -eq "Detail"){
        # Do a DNS lookup with a .NET class method. Suppress error messages.
        $ErrorActionPreference = 'SilentlyContinue'
        if ( $ips = [System.Net.Dns]::GetHostAddresses($env:ComputerName) | foreach { $_.IPAddressToString } ) {
            $data.'IP Address(es) from DNS' = ($ips -join ', ')
        }
        else {
            $data.'IP Address from DNS' = 'Could not resolve'
        }
        # Make errors visible again
        $ErrorActionPreference = 'Continue'
    
        # We'll assume no ping reply means it's dead. Try this anyway if -IgnorePing is specified
        if ($ping -or $ignorePing) {
            $data.'WMI Data Collection Attempt' = 'Yes (ping reply or -IgnorePing)'
    
            # Get various info from the ComputerSystem WMI class
            if ($wmi = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue) {
                $data.'Computer Hardware Manufacturer' = $wmi.Manufacturer
                $data.'Computer Hardware Model'        = $wmi.Model
                $data.'Memory Physical in MB'          = ($wmi.TotalPhysicalMemory/1MB).ToString('N')
                $data.'Logged On User'                 = $wmi.Username
            }
            $wmi = $null
    
            # Get the free/total disk space from local disks (DriveType 3)
            if ($wmi = Get-WmiObject -Class Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue) { 
                $wmi | Select 'DeviceID', 'Size', 'FreeSpace' | Foreach { 
                    $data."Local disk $($_.DeviceID)" = ('' + ($_.FreeSpace/1MB).ToString('N') + ' MB free of ' + ($_.Size/1MB).ToString('N') + ' MB total space with ' + ($_.Size/1MB - $_.FreeSpace/1MB).ToString('N') +' MB Used Space')
                }
            }
            $wmi = $null
    
            # Get IP addresses from all local network adapters through WMI
            if ($wmi = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue) {
                $Ips = @{}
                $wmi | Where { $_.IPAddress -match '\S+' } | Foreach { $Ips.$($_.IPAddress -join ', ') = $_.MACAddress }
                $counter = 0
                $Ips.GetEnumerator() | Foreach {
                    $counter++; $data."IP Address $counter" = '' + $_.Name + ' (MAC: ' + $_.Value + ')'
                }
            }
            $wmi = $null
	
            # Get CPU information with WMI
            if ($wmi = Get-WmiObject -Class Win32_Processor -ErrorAction SilentlyContinue) {
                $wmi | Foreach {
                    $maxClockSpeed     =  $_.MaxClockSpeed
                    $numberOfCores     += $_.NumberOfCores
                    $description       =  $_.Description
                    $numberOfLogProc   += $_.NumberOfLogicalProcessors
                    $socketDesignation =  $_.SocketDesignation
                    $status            =  $_.Status
                    $manufacturer      =  $_.Manufacturer
                    $name              =  $_.Name
                }
                $data.'CPU Clock Speed'        = $maxClockSpeed
                $data.'CPU Cores'              = $numberOfCores
                $data.'CPU Description'        = $description
                $data.'CPU Logical Processors' = $numberOfLogProc
                $data.'CPU Socket'             = $socketDesignation
                $data.'CPU Status'             = $status
                $data.'CPU Manufacturer'       = $manufacturer
                $data.'CPU Name'               = $name -replace '\s+', ' '
            }
            $wmi = $null
	    
            # Get BIOS info from WMI
            if ($wmi = Get-WmiObject -Class Win32_Bios -ErrorAction SilentlyContinue) {
                $data.'BIOS Manufacturer' = $wmi.Manufacturer
                $data.'BIOS Name'         = $wmi.Name
                $data.'BIOS Version'      = $wmi.Version
                $data.'BIOS SM Version:'    = $wmi.SMBIOSBIOSVersion
            }
            $wmi = $null
	
            # Get operating system info from WMI
            if ($wmi = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue) {  
                $data.'OS Boot Time'     = $wmi.ConvertToDateTime($wmi.LastBootUpTime)
                $data.'OS System Drive'  = $wmi.SystemDrive
                $data.'OS System Device' = $wmi.SystemDevice
                $data.'OS Language     ' = $wmi.OSLanguage
                $data.'OS Version'       = $wmi.Version
                $data.'OS Windows dir'   = $wmi.WindowsDirectory
                $data.'OS Name'          = $wmi.Caption
                $data.'OS Install Date'  = $wmi.ConvertToDateTime($wmi.InstallDate)
                $data.'OS Service Pack'  = [string]$wmi.ServicePackMajorVersion + '.' + $wmi.ServicePackMinorVersion
            }
            # Scan for open ports
            $ports = @{ 
                        'File shares/RPC' = '139' ;
                        'File shares'     = '445' ;
                        'RDP'             = '3389';
                        #'Zenworks'        = '1761';
                      }
            foreach ($service in $ports.Keys) {
                $socket = New-Object Net.Sockets.TcpClient
                # Suppress error messages
                $ErrorActionPreference = 'SilentlyContinue'
                # Try to connect
                $socket.Connect($env:ComputerName, $ports.$service)
                # Make error messages visible again
                $ErrorActionPreference = 'Continue'
                if ($socket.Connected) {  
                    $data."Port $($ports.$service) ($service)" = 'Open'
                    $socket.Close()
                }
                else {  
                    $data."Port $($ports.$service) ($service)" = 'Closed or filtered'
                }
                $socket = $null   
            }
        }
        else { 
            $data.'WMI Data Collected' = 'No (no ping reply and -IgnorePing not specified)'
        }
        $wmi = $null

        if ($wmi = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue| Select-Object Name, TotalVisibleMemorySize, FreePhysicalMemory,TotalVirtualMemorySize,FreeVirtualMemory,FreeSpaceInPagingFiles,NumberofProcesses,NumberOfUsers ) {
                $wmi | Foreach {   
                    $TotalRAM     =  $_.TotalVisibleMemorySize/1MB
                    $FreeRAM     = $_.FreePhysicalMemory/1MB
                    $UsedRAM       =  $_.TotalVisibleMemorySize/1MB - $_.FreePhysicalMemory/1MB
                    $TotalRAM = [Math]::Round($TotalRAM, 2)
                    $FreeRAM = [Math]::Round($FreeRAM, 2)
                    $UsedRAM = [Math]::Round($UsedRAM, 2)
                    $RAMPercentFree = ($FreeRAM / $TotalRAM) * 100
                    $RAMPercentFree = [Math]::Round($RAMPercentFree, 2)
                    $TotalVirtualMemorySize  = [Math]::Round($_.TotalVirtualMemorySize/1MB, 3)
                    $FreeVirtualMemory =  [Math]::Round($_.FreeVirtualMemory/1MB, 3)
                    $FreeSpaceInPagingFiles            =  [Math]::Round($_.FreeSpaceInPagingFiles/1MB, 3)
                    $NumberofProcesses      =  $_.NumberofProcesses
                    $NumberOfUsers              =  $_.NumberOfUsers
                }
                $data.'Memory - Total RAM GB '  = $TotalRAM
                $data.'Memory - RAM Free GB'    = $FreeRAM
                $data.'Memory - RAM Used GB'    = $UsedRAM
                $data.'Memory - Percentage Free'= $RAMPercentFree
                $data.'Memory - TotalVirtualMemorySize' = $TotalVirtualMemorySize
                $data.'Memory - FreeVirtualMemory' = $FreeVirtualMemory
                $data.'Memory - FreeSpaceInPagingFiles' = $FreeSpaceInPagingFiles
                $data.'NumberofProcesses'= $NumberofProcesses
                $data.'NumberOfUsers'    = $NumberOfUsers -replace '\s+', ' '
            }
        # Output data
        "#"*80
        "OS Complete Information"
        "Generated $(get-date)"
        "Generated from $(gc env:computername)"
        "#"*80
        
    } ElseIf ($DisplayType -eq "NetInfo"){

    } Else {
        # Get operating system info from WMI
        if ($wmi = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue) { 
            If(!$wmi.Caption){$Caption="WinPE"; $Name = "PE:"}Else{$Caption=$wmi.Caption; $Name = "OS:"}
            $data." $Name"          = "$Caption ("+$wmi.Version+")"
        }

        # Get BIOS info from WMI
        if ($wmi = Get-WmiObject -Class Win32_Bios -ErrorAction SilentlyContinue) {
            $data.'BIOS Version:' = $wmi.SMBIOSBIOSVersion
        }
        $wmi = $null

        if ($wmi = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue) {
            $data.'Manufacturer:' = $wmi.Manufacturer
            $data.'Model:' = $wmi.Model
        }
        $wmi = $null

        # Get IP addresses from all local network adapters through WMI
        if ($wmi = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue) {
            $Ips = @{}
            $wmi | Where { $_.IPAddress -match '\S+' } | Foreach { $Ips.$($_.IPAddress -join ', ' ) = $_.MACAddress }
            $counter = 0
            $Ips.GetEnumerator() | Foreach {
                $counter++; $data.("Net Address["+$counter+"]:") = '' + $_.Name + ' MAC['+$counter+']:' + $_.Value + ''
            }
        }
        $wmi = $null
    }

    $EnumeratedData = [system.String]::Join("`n", ($data.GetEnumerator()| Sort-Object 'Name' | Format-Table -HideTableHeaders -AutoSize | out-string))
    #$EnumeratedData = ($data.GetEnumerator()| Sort-Object 'Name' | format-table -HideTableHeaders | out-string)
    If($DisplayOutbox){
        Write-OutputBox -OutputBoxMessage $EnumeratedData -Type " " -Object SysInfo
    } Else{
        $data.GetEnumerator() | Sort-Object 'Name' | Format-Table -AutoSize
    }
    If($DisplayForm){$data.GetEnumerator() | Sort-Object 'Name' | Out-GridView -Title "$env:ComputerName Information"}
}

function Load-SystemProvider {
    If ($Manufacturer -eq "Dell Inc."){
        If ($UseDellCCTK -eq $true){
            If ($Is64Bit -and (Test-Path $DellCCTKPath)){
                $HAPI = "hapint64.exe"
                Write-OutputBox -OutputBoxMessage "Dell Command | Configure Tool Kit loading driver: $HAPI" -Type "INFO: " -Object Logging
            }ElseIf(Test-Path $DellCCTKPathX86) {
                $HAPI = "hapint.exe"
                Write-OutputBox -OutputBoxMessage "Dell Command | Configure Tool Kit loaded driver: $HAPI" -Type "INFO: " -Object Logging
            }Else {
                Write-OutputBox -OutputBoxMessage "Unable to find Dell Command | Configure Tool Kit HAPI driver" -Type "ERROR: " -Object Logging
            }

            $private:returnCode = $null
            $callexe = New-Object System.Diagnostics.ProcessStartInfo
            $callexe.FileName = "$DellCCTKPath\HAPI\$HAPI"
            $callexe.RedirectStandardError = $true
            $callexe.RedirectStandardOutput = $true
            $callexe.UseShellExecute = $false
            $callexe.Arguments = "-i -k C-C-T-K -p ""$HAPI"" -q"
            $callexe.WindowStyle = 'Minimized'
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $callexe
            $process.Start() | Out-Null
            $process.WaitForExit()
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            Write-OutputBox -OutputBoxMessage ("Running: " + $callexe.FileName + " " + $callexe.Arguments) -Type "INFO: " -Object Logging
            If ($process.ExitCode -eq 0){
                Write-OutputBox -OutputBoxMessage "Successfully installed CCTK HAPI drivers" -Type "INFO: " -Object Logging
            }Else{
                Write-OutputBox -OutputBoxMessage ("Unable to install the CCTK HAPI drivers with errorcode: " + $process.ExitCode) -Type "ERROR: " -Object Logging
            }
        }
        
        If ($UseDellPSProvider -eq $true){
            If ($Is64Bit -and (Test-Path $DellPSProviderPath)){
                Import-Module "$DellPSProviderPath\DellBIOSProvider.PSM1"
                Write-OutputBox -OutputBoxMessage "Dell Powershell Provider loaded" -Type "INFO: " -Object Logging
            }ElseIf(Test-Path $DellPSProviderPathX86) {
                Import-Module "$DellPSProviderPathX86\DellBIOSProvider.PSM1"
                Write-OutputBox -OutputBoxMessage "Dell Powershell Provider loaded" -Type "INFO: " -Object Logging
            }Else{
                Write-OutputBox -OutputBoxMessage "Unable to find Dell Powershell Provider" -Type "ERROR: " -Object Logging
            }
        } 

    } ElseIf ($Manufacturer -eq "Hewlett Packard"){
        Write-OutputBox -OutputBoxMessage "Unable to load a system Provider, nothing provided" -Type "WARNING: " -Object Logging
    } ElseIf ($Manufacturer -eq "System manufacturer"){ 
        Write-OutputBox -OutputBoxMessage "Unable to load a system Provider, nothing provided" -Type "WARNING: " -Object Logging   
    } Else {
        Write-OutputBox -OutputBoxMessage "Unable to load a system Provider, unsupported hardware" -Type "ERROR: " -Object Logging
    }
}

Function Execute-DellCCTK{
    [CmdletBinding()]
	Param (
        [Parameter(Mandatory=$true)]
		[Alias('Arguments')]
		[ValidateNotNullorEmpty()]
		[string[]]$Parameters,
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$WorkingDirectory,
        [Parameter(Mandatory=$false)]
		[switch]$PassThru = $false,
        [Parameter(Mandatory=$false)]
		[switch]$DebugLog = $Global:LogDebugMode
    )
    
	Begin {
        If ($Is64Bit -and (Test-Path $DellCCTKPath)){
            $Path = "$DellCCTKPath\cctk.exe"
            Write-OutputBox -OutputBoxMessage "Dell Command | Configure Tool Kit loaded: $Path" -Type "INFO: " -Object Logging
        }ElseIf(Test-Path $DellCCTKPathX86) {
            $Path = "$DellCCTKPathX86\cctk.exe"
            Write-OutputBox -OutputBoxMessage "Dell Command | Configure Tool Kit loaded: $Path" -Type "INFO: " -Object Logging
        }Else {
            Write-OutputBox -OutputBoxMessage "Unable to find Dell Command | Configure Tool Kit" -Type "ERROR: " -Object Logging
        }
	}
	Process {
		Try {
			$private:returnCode = $null
			## Validate and find the fully qualified path for the $Path variable.
			If (([IO.Path]::IsPathRooted($Path)) -and ([IO.Path]::HasExtension($Path))) {
                If ($DebugLog){Write-OutputBox -OutputBoxMessage "[$Path] is a valid fully qualified path" -Type "INFO: " -Object Logging}
				If (-not (Test-Path -LiteralPath $Path -PathType 'Leaf' -ErrorAction 'Stop')) {
					Throw "File [$Path] not found."
				}
			}
			Else {
				#  The first directory to search will be the 'Files' subdirectory of the script directory
				[string]$PathFolders = $Path
				#  Add the current location of the console (Windows always searches this location first)
				[string]$PathFolders = $PathFolders + ';' + (Get-Location -PSProvider 'FileSystem').Path
				#  Add the new path locations to the PATH environment variable
				$env:PATH = $PathFolders + ';' + $env:PATH
				
				#  Get the fully qualified path for the file. Get-Command searches PATH environment variable to find this value.
				[string]$FullyQualifiedPath = Get-Command -Name $Path -CommandType 'Application' -TotalCount 1 -Syntax -ErrorAction 'Stop'
				
				#  Revert the PATH environment variable to it's original value
				$env:PATH = $env:PATH -replace [regex]::Escape($PathFolders + ';'), ''
				
				If ($FullyQualifiedPath) {
                    Write-OutputBox -OutputBoxMessage "[$Path] successfully resolved to fully qualified path [$FullyQualifiedPath]." -Type "INFO: " -Object Logging
					$Path = $FullyQualifiedPath
				}
				Else {
					Throw "[$Path] contains an invalid path or file name."
				}
			}
			
			## Set the Working directory (if not specified)
			If (-not $WorkingDirectory) { $WorkingDirectory = Split-Path -Path $Path -Parent -ErrorAction 'Stop' }
			Try {
                

				## Disable Zone checking to prevent warnings when running executables
				$env:SEE_MASK_NOZONECHECKS = 1
				
				## Define process
				$CCTKStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ErrorAction 'Stop'
				$CCTKStartInfo.FileName = $Path
				$CCTKStartInfo.WorkingDirectory = $WorkingDirectory
				$CCTKStartInfo.UseShellExecute = $false
				$CCTKStartInfo.ErrorDialog = $false
				$CCTKStartInfo.RedirectStandardOutput = $true
				$CCTKStartInfo.RedirectStandardError = $true
				$CCTKStartInfo.CreateNoWindow = $false
				If ($Parameters) { $CCTKStartInfo.Arguments = $Parameters }
				$CCTKStartInfo.WindowStyle = 'Minimized'
				$process = New-Object -TypeName 'System.Diagnostics.Process' -ErrorAction 'Stop'
				$process.StartInfo = $CCTKStartInfo
				
				## Add event handler to capture process's standard output redirection
				[scriptblock]$processEventHandler = { If (-not [string]::IsNullOrEmpty($EventArgs.Data)) { $Event.MessageData.AppendLine($EventArgs.Data) } }
				$stdOutBuilder = New-Object -TypeName 'System.Text.StringBuilder' -ArgumentList ''
				$stdOutEvent = Register-ObjectEvent -InputObject $process -Action $processEventHandler -EventName 'OutputDataReceived' -MessageData $stdOutBuilder -ErrorAction 'Stop'
				
                ## Start Process
                If ($DebugLog){Write-OutputBox -OutputBoxMessage "Working Directory is [$WorkingDirectory]." -Type "INFO: " -Object Logging}
				If ($Parameters) {
					Write-OutputBox -OutputBoxMessage "Executing [$Path $Parameters]" -Type "INFO: " -Object Logging
				} Else {
					Write-OutputBox -OutputBoxMessage "Executing [$Path]" -Type "INFO: " -Object Logging
				}
				[boolean]$processStarted = $process.Start()
                
                $process.BeginOutputReadLine()
				$stdErr = $($process.StandardError.ReadToEnd()).ToString() -replace $null,''
					
				## Instructs the Process component to wait indefinitely for the associated process to exit.
				$process.WaitForExit()
					
				## HasExited indicates that the associated process has terminated, either normally or abnormally. Wait until HasExited returns $true.
				While (-not ($process.HasExited)) { $process.Refresh(); Start-Sleep -Seconds 1 }
					
				## Get the exit code for the process
				Try {
					[int32]$returnCode = $process.ExitCode
                    
				}
				Catch [System.Management.Automation.PSInvalidCastException] {
					#  Catch exit codes that are out of int32 range
					[int32]$returnCode = 136
				}
	
				## Unregister standard output event to retrieve process output
				If ($stdOutEvent) { Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop'; $stdOutEvent = $null }
				$stdOut = $stdOutBuilder.ToString() -replace $null,''
					
				If ($stdErr.Length -gt 0) {
					If ($DebugLog){Write-OutputBox -OutputBoxMessage "Standard error output from the process: $stdErr" -Type "WARNING: " -Object Logging}
				}
			}
			Finally {
				## Make sure the standard output event is unregistered
				If ($stdOutEvent) { Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop'}
				
				## Free resources associated with the process, this does not cause process to exit
				If ($process) { $process.Close() }
				
				## Re-enable Zone checking
				Remove-Item -LiteralPath 'env:SEE_MASK_NOZONECHECKS' -ErrorAction 'SilentlyContinue'
			}
			
				
			## If the passthru switch is specified, return the exit code and any output from process
			If ($PassThru) {
				If ($DebugLog){Write-OutputBox -OutputBoxMessage "cctk completed with exit code [$returnCode]." -Type "INFO: " -Object Logging}
				[psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = $stdOut; StdErr = $stdErr }
				Write-Output -InputObject $ExecutionResults
			} Else {
                If ($DebugLog){Write-Host "cctk completed with exit code [$returnCode]."}
                $returnCode
			}
		}
		Catch {
			If ([string]::IsNullOrEmpty([string]$returnCode)) {
				[int32]$returnCode = 136
			}Else {
				If ($DebugLog){Write-OutputBox -OutputBoxMessage "cctk completed with exit code [$returnCode]. Function failed." -Type "ERROR: " -Object Logging}
			}
			
            If ($PassThru) {
				[psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = If ($stdOut) { $stdOut } Else { '' }; StdErr = If ($stdErr) { $stdErr } Else { '' } }
				Write-Output -InputObject $ExecutionResults
			}Else {
                If ($DebugLog){Write-Host "cctk completed with exit code [$returnCode]. Function failed."}
                $returnCode
			}
		}
	}
}

Function Test-DellCCTK {
    [CmdletBinding()]
	Param (
        [Parameter(Mandatory=$false)]
		[Alias('FilePath')]
        [ValidateNotNullorEmpty()]
		[string]$Path = $CCTK,
        [Parameter(Mandatory=$true)]
		[Alias('Arguments')]
		[ValidateNotNullorEmpty()]
		[string[]]$Parameters,
        [Parameter(Mandatory=$false)]
		[switch]$PassThru = $false
    )
    $result = Execute-DellCCTK -Parameters "--Asset=TestCCTK" -PassThru
    If ($DebugLog){Write-Host "[cctk --Asset=TestCCTK] exitcode: " $result.StdOut}
    If ($result.ExitCode -eq 0){
        
    }
    Execute-DellCCTK -Parameters ($parameters + " --valsetuppwd=$BIOSpwd") -PassThru

    Execute-DellCCTK -Parameters "--setuppwd='' --valsetuppwd=$BIOSpwd"
    If ($DebugLog){Write-Host "Cleared BIOS Password"}

}

function Run-DellPSProvider {
    cd DellSmbios:
    <# Examples
        Set-Item Dellsmbios:\PostBehaviour\NumLock Enabled
    
        #Set BIOS Admin Password
        Set-Item -Path Dellsmbios\Security\AdminPassword –Value dell123
 
        #Change BIOS Admin Password
        Set-Item -Path Dellsmbios\Security\AdminPassword –Value dell1234 –Password dell123
 
        #Clear BIOS Admin Password
        Set-Item -Path Dellsmbios\Security\AdminPassword –Value “” –Password dell123
 
        #Disable Chassis Intrusion alert
        Set-Item -Path Dellsmbios\Security\ChassisIntrusion -Value Disabled
 
        #Set Wake On Lancd
        Set-Item -Path Dellsmbios:\PowerManagement\WakeOnLANorWLAN -Value "LANorWLAN"
 
        #Change Asset Tag
        Set-Item –Path DellSmbios:\SystemInformation\AssetTag MyAssetTag -Password dell123
 
        #Set WWAN Connection AutoSense
        Set-Item -Path Dellsmbios:\PowerManagement\ControlWWANRadio -Value Enabled
 
        #Get Service Tag
        Get-ChildItem DellSmbios:\SystemInformation\ServiceTag
 
        #Get Boot Sequence
        Get-ChildItem DellSmbios:\BootSequence\Bootsequence
    
        #Enable PXE boot
        Set-Item -Path Dellsmbios:\SystemConfiguration\"Integrated NIC" -Value "Enabled w PXE"

    #>

}


function Validate-Elevated {
    $UserIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $UserWP = New-Object Security.Principal.WindowsPrincipal($UserIdentity)
    $ErrorActionPreference = "Stop"
    try {
        if ($UserWP.IsInRole("S-1-5-32-544")) {
            $PBUEFI.Image = $ValidatedImage
		    $LabelUEFI.Visible = $true
            Write-OutputBox -OutputBoxMessage "User has local administrative rights, and the tool was launched elevated" -Type "INFO: " -Object Logging
            return $true
        }
        else {
            $PBUEFI.Image = $ErrorImage
		    $LabelUEFI.Visible = $true
            Write-OutputBox -OutputBoxMessage "The tool requires local administrative rights and was not launched elevated" -Type "ERROR: " -Object Logging
            return $false
        }
    }
    catch [System.Exception] {
        Write-OutputBox -OutputBoxMessage "An error occured when attempting to query for elevation, possible due to issues contacting the domain or the tool is launched in a sub-domain. If used in a sub-domain, check the override checkbox to enable this tool" -Type "WARNING: " -Object Logging
        $PBUEFI.Image = $ErrorImage
		$LabelUEFI.Visible = $true
        $ErrorActionPreference = "Continue"
    }
}


function Validate-System {
    param(
	    [parameter(Mandatory=$false)]
	    $OutPutBox = $true
	)
    Begin {
        $ModelsArrayList = New-Object System.Collections.ArrayList
        $ModelsArrayList.AddRange(@($SupportedModels))
        $ManufacturersArrayList = New-Object System.Collections.ArrayList
        $ManufacturersArrayList.AddRange(@($SupportedManufacturers))
    }
    Process {
        If ($ManufacturersArrayList -eq $ComputerSystem.Manufacturer) {
		    if ($ModelsArrayList -eq $ComputerSystem.Model) {
                If($OutPutBox){Write-OutputBox -OutputBoxMessage ("Supported model found (" + $ComputerSystem.Model + ")") -Type "INFO: " -Object Logging}
	            $PBModel.Image = $ValidatedImage
	            $LabelSupportedModel.Visible = $true
	            return $true
            } Else {
			    If($OutPutBox){Write-OutputBox -OutputBoxMessage "The detected model is not supported." -Type "ERROR: " -Object Logging}
                $PBModel.Image = $ErrorImage
                $LabelSupportedModel.Visible = $true
                return $false
		    }
        } Else {
            If($OutPutBox){Write-OutputBox -OutputBoxMessage ("The detected manufacturer (" + $ComputerSystem.Manufacturer + ") is not supported.") -Type "ERROR: " -Object Logging}
            $PBModel.Image = $ErrorImage
            $LabelSupportedModel.Visible = $true
            return $false
        }
	}
}

function Validate-BIOSPassword {
    If ($global:PreValidation -eq $false){return $false; break}
    $sTestVal = "TestAsset"
    #sPrevAssetTag = oEnvironment.Item("AssetTag")
    If ($UseDellCCTK){
        $result = Execute-DellCCTK -Parameters "--asset=" -PassThru
        If ($DebugLog){Write-Host "[cctk --asset=] exitcode:" $result.ExitCode}
        If ($DebugLog){Write-Host "[cctk --asset=] Error:" $result.StdErr}
        If ($DebugLog){Write-Host "[cctk --asset=] Output:" $result.StdOut}
        If ($result.ExitCode -eq 191 -or $result.ExitCode -eq 180){
            Write-OutputBox -OutputBoxMessage ("The BIOS password is set. Will try to guess password") -Type "ERROR: " -Object Logging
            Foreach ($password in $BIOSKnownUsedpwd){
                $PlainPassword = Decrypt-String -Encrypted $password -Passphrase "SecureHostBaseline"
                $result = Execute-DellCCTK -Parameters "--asset=$sTestVal --valsetuppwd=$PlainPassword" -PassThru
                If ($result.ExitCode -eq 0){
                    Write-OutputBox -OutputBoxMessage "Successfully able to access BIOS settings using a known BIOS password" -Type "INFO: " -Object Logging
                    $BIOSPasswordFound = $PlainPassword
                    Break
                } Else {
                    Write-OutputBox -OutputBoxMessage ("Tried $password, The BIOS password is invalid. Will try to guess password again") -Type "ERROR: " -Object Logging
                    $BIOSPasswordFound = $Null
                    Continue
                }
            }

        } Elseif($result.ExitCode -eq 0) {
            Write-OutputBox -OutputBoxMessage ("The BIOS password is blank. A password is required to be compliant.") -Type "WARNING: " -Object Logging
            Execute-DellCCTK -Parameters "--asset="
            $BIOSPasswordFound = $Null
            $PBBIOSPassword.Image = $WarningImage
            $LabelBIOSPassword.Visible = $true
            return $false 

        } Else {
            Write-OutputBox -OutputBoxMessage ("CCTK errored with exit code: " + $result.ExitCode) -Type "ERROR: " -Object Logging
            $BIOSPasswordFound = $Null
            $PBBIOSPassword.Image = $ErrorImage
            $LabelBIOSPassword.Visible = $true
            return $false
        }

    
        If ($BIOSPasswordFound){
            Write-OutputBox -OutputBoxMessage ("The BIOS password is has been fo") -Type "INFO: " -Object Logging
            Execute-DellCCTK -Parameters "--asset= --valsetuppwd=$BIOSPasswordFound"
            $PBBIOSPassword.Image = $ValidatedImage
            $LabelBIOSPassword.Visible = $true
            return $true

        }Else{
            Write-OutputBox -OutputBoxMessage ("The BIOS password is not known. BIOS configurations may have to be set manually") -Type "ERROR: " -Object Logging
            $PBBIOSPassword.Image = $ErrorImage
            $LabelBIOSPassword.Visible = $true
            return $false
        }
    }

    If ($UseDellPSProvider){
        Write-OutputBox -OutputBoxMessage ("The BIOS password is not known. BIOS configurations may have to be set manually") -Type "ERROR: " -Object Logging
        $BIOSPasswordFound = $Null
        $PBBIOSPassword.Image = $ErrorImage
        $LabelBIOSPassword.Visible = $true
        return $false
    }

    #Output current BIOS password
    $global:BIOSCurrentPassword = $BIOSPasswordFound
    If ($DebugLog){Write-Host "Current BIOS password is: $global:BIOSCurrentPassword"}
}

function Validate-BIOSRevision {
    Begin {
        $DetectedBIOS = Get-WmiObject -Namespace "root\cimv2" -Class Win32_BIOS | Select-Object -ExpandProperty SMBIOSBIOSVersion
    }
    Process {
        If (Validate-System -OutPutBox $false){
            foreach($system in $SupportedSystems){
                If ($Model -eq $system.model){
                    if (($DetectedBIOS -eq $system.biosrev -or $system.biosrev -eq "any")) {
                        Write-OutputBox -OutputBoxMessage ("Supported BIOS (" + $DetectedBIOS + ") found for model (" + $system.model + ")") -Type "INFO: " -Object Logging
                        $ModelBIOSMatchFound = $true	                
                        $PBBIOSRevision.Image = $ValidatedImage
	                    $LabelBIOSRevision.Visible = $true
	                    return $true
                    } Else {
			            Write-OutputBox -OutputBoxMessage ("The detected BIOS Revision (" + $DetectedBIOS + "). The supported BIOS revision is: " + $system.biosrev) -Type "ERROR: " -Object Logging
                        $ModelBIOSMatchFound = $false
                        $PBBIOSRevision.Image = $WarningImage
                        $LabelBIOSRevision.Visible = $true
                        return $true
		            }
                } Else{
                	Write-OutputBox -OutputBoxMessage ("The model (" + $system.model + ") and BIOS (" + $DetectedBIOS + ") is not supported for Secure Host Baseline.") -Type "ERROR: " -Object Logging
                    $ModelBIOSMatchFound = $false
                    $PBBIOSRevision.Image = $ErrorImage
                    $LabelBIOSRevision.Visible = $true
                    return $false
                }
            }
        } Else {
            Write-OutputBox -OutputBoxMessage ("The detected system is not supported with CredGuard.") -Type "ERROR: " -Object Logging
            $ModelBIOSMatchFound = $false
            $PBBIOSRevision.Image = $ErrorImage
            $LabelBIOSRevision.Visible = $true
            return $false
        }
	}End {
		
	}
}

function Validate-OSBuild {
	if (($OSProductType -eq 1) -and ($OSBuildNumber -ge $MinimumOSversion)) {
        $OSName = $SupportedOperatingSystems | Where-Object version -eq $OSBuildNumber       
        If(!$OSCaption){
            Write-OutputBox -OutputBoxMessage ("Supported WinPE version running (" + $OSBuildNumber + ")") -Type "INFO: " -Object Logging
        } Else {
            Write-OutputBox -OutputBoxMessage ("Supported operating system running (" + $OSCaption + ")") -Type "INFO: " -Object Logging
        }       
        $PBOS.Image = $ValidatedImage
        $LabelSupportedOS.Visible = $true
        return $true
	}
	else {
        if ($OSBuildNumber -lt $MinimumOSversion) {
		    Write-OutputBox -OutputBoxMessage "The detected operating system or WinPE is not supported. This tool is supported on Windows Server 2012 and above" -Type "ERROR: " -Object Logging
        }Elseif ($OSProductType -eq 2) {
		    Write-OutputBox -OutputBoxMessage "The detected system is a Domain Controller. This tool is not supported on this platform" -Type "ERROR: " -Object Logging 
        }Elseif ($OSProductType -eq 3) {
		    Write-OutputBox -OutputBoxMessage "The detected operating system is a Server OS. This tool is not supported on this platform" -Type "ERROR: " -Object Logging
        }
        $PBOS.Image = $ErrorImage
        $LabelSupportedOS.Visible = $true
        return $false
	}
}


function Validate-PowerShellVer {
    if ($host.Version -ge "3.0") {
        Write-OutputBox -OutputBoxMessage ("Supported version of PowerShell was detected (" + $host.Version + ")") -Type "INFO: " -Object Logging
        $PBPS.Image = $ValidatedImage
        $LabelPowerShell.Visible = $true
        return $true
    }
    else {
        Write-OutputBox -OutputBoxMessage ("Unsupported version of PowerShell detected (" + $host.Version + "). This tool requires PowerShell 3.0 and above") -Type "ERROR: " -Object Logging
        $PBPS.Image = $ErrorImage
        $LabelPowerShell.Visible = $true
        return $false
    }
}


Function IsUEFI {
	<#
	.Synopsis
	   Determines underlying firmware (BIOS) type and returns True for UEFI or False for legacy BIOS.
	.DESCRIPTION
	   This function uses a complied Win32 API call to determine the underlying system firmware type.
	.EXAMPLE
	   If (IsUEFI) { # System is running UEFI firmware... }
	.OUTPUTS
	   [Bool] True = UEFI Firmware; False = Legacy BIOS
	.FUNCTIONALITY
	   Determines underlying system firmware type
	#>

	[OutputType([Bool])]
	Param ()

	Add-Type -Language CSharp -TypeDefinition @'
    using System;
    using System.Runtime.InteropServices;
    public class GetUEFIMode
    {
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern UInt32 
        GetFirmwareEnvironmentVariableA(string lpName, string lpGuid, IntPtr pBuffer, UInt32 nSize);
        const int ERROR_INVALID_FUNCTION = 1; 
        public static bool IsUEFI()
        {
            // Try to call the GetFirmwareEnvironmentVariable API.  This is invalid on legacy BIOS.
            GetFirmwareEnvironmentVariableA("","{00000000-0000-0000-0000-000000000000}",IntPtr.Zero,0);
            if (Marshal.GetLastWin32Error() == ERROR_INVALID_FUNCTION)
                return false;     // API not supported; this is a legacy BIOS
            else
                return true;      // API error (expected) but call is supported.  This is UEFI.
        }
    }
'@ -ErrorAction SilentlyContinue
    [GetUEFIMode]::IsUEFI()
}

Function GetFirmwareType {
	<#
	.Synopsis
	   Determines underlying firmware (BIOS) type and returns an integer indicating UEFI, Legacy BIOS or Unknown.
	   Supported on Windows 8/Server 2012 or later
	.DESCRIPTION
	   This function uses a complied Win32 API call to determine the underlying system firmware type.
	.EXAMPLE
	   If (Get-BiosType -eq 1) { # System is running UEFI firmware... }
	.EXAMPLE
	    Switch (Get-BiosType) {
	        1       {"Legacy BIOS"}
	        2       {"UEFI"}
	        Default {"Unknown"}
	    }
	.OUTPUTS
	   Integer indicating firmware type (1 = Legacy BIOS, 2 = UEFI, Other = Unknown)
	.FUNCTIONALITY
	   Determines underlying system firmware type
	#>

	[OutputType([UInt32])]
	Param()

	Add-Type -Language CSharp -TypeDefinition @'
    using System;
    using System.Runtime.InteropServices;
    public class FirmwareType
    {
        [DllImport("kernel32.dll")]
        static extern bool GetFirmwareType(ref uint FirmwareType);
        public static uint GetFirmwareType()
        {
            uint firmwaretype = 0;
            if (GetFirmwareType(ref firmwaretype))
                return firmwaretype;
            else
                return 0;   // API call failed, just return 'unknown'
        }
    }
'@ -IgnoreWarnings
    [FirmwareType]::GetFirmwareType()
}

Function Validate-UEFICheck {
    Begin {	
        $ValidateUEFI = $false
        $ValidateUEFI = IsUEFI
    }
    Process {
	    if ($ValidateUEFI) {
            $PBUEFI.Image = $ValidatedImage
		    $LabelUEFI.Visible = $true
            Write-OutputBox -OutputBoxMessage "UEFI is enabled" -Type "INFO: " -Object Logging
            return $true  
	    }
	    else {
            $PBUEFI.Image = $ErrorImage
		    $LabelUEFI.Visible = $true
            Write-OutputBox -OutputBoxMessage "UEFI is not enabled, will try to enable" -Type "ERROR: " -Object Logging
            return $false
	    }
    }
}

Function Validate-LegacyROM {
    Begin {
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {
        $result = Execute-DellCCTK -Parameters "--legacyorom" -PassThru
        If ($DebugLog){Write-Host "[cctk --legacyorom] exitcode: " $result.ExitCode}
        If ($DebugLog){Write-Host "[cctk --legacyorom] output: " $result.StdOut}
    
        [string]$ResultOutput = ($result.StdOut).Trim()
        $Global:LROM = $ResultOutput.Split("=")[1]

        If ($ResultOutput -eq "legacyorom=disable"){
            Write-OutputBox -OutputBoxMessage "Legacy Option ROM is disable!" -Type "INFO: " -Object Logging
            $PBLEGACYOROM.Image = $ValidatedImage
            $LabelLegacyROM.Visible = $true
            return $true
        } 
        ElseIf ($result.ExitCode -eq 0){
            Write-OutputBox -OutputBoxMessage "Legacy Option ROM is an option, but not disabled" -Type "WARNING: " -Object Logging
            If ($BIOSCurrentPassword -ne $Null){
                $result = Execute-DellCCTK -Parameters "--legacyorom=disable --valsetuppwd=$BIOSCurrentPassword" -PassThru
                If ($DebugLog){Write-Host "[cctk --legacyorom=disable --valsetuppwd=$BIOSCurrentPassword] exitcode: " $result.ExitCode}
            } 
            Else {
                $result = Execute-DellCCTK -Parameters "--legacyorom=disable" -PassThru
                If ($DebugLog){Write-Host "[cctk --legacyorom=disable] exitcode: " $result.ExitCode}
            }

            If ($result.ExitCode -eq 0){
                Write-OutputBox -OutputBoxMessage "Sucessfully disabled Legacy Option ROM" -Type "INFO: " -Object Logging
                $PBLEGACYOROM.Image = $ValidatedImage
                $LabelLegacyROM.Visible = $true
                return $true             
            } 
            ElseIf($result.ExitCode -eq 192) {
                Write-OutputBox -OutputBoxMessage "Unable to disable Legacy Option ROM, the BIOS password is unknown." -Type "ERROR: " -Object Logging
                $PBLEGACYOROM.Image = $WarningImage
                $LabelLegacyROM.Visible = $true
                return $false
            } 
            Else {
                Write-OutputBox -OutputBoxMessage "Unable to disable Legacy Option ROM, setting must be disabled manually" -Type "ERROR: " -Object Logging
                $PBLEGACYOROM.Image = $WarningImage
                $LabelLegacyROM.Visible = $true
                return $false
            }
        
        } 
        Else {
            Write-OutputBox -OutputBoxMessage "Legacy Boot ROM is not an option." -Type "ERROR: " -Object Logging
            $PBLEGACYOROM.Image = $ErrorImage
            $LabelLegacyROM.Visible = $true
            return $false
        }
    }
}

Function Validate-SecureBoot {
    Begin {
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {
	    $result = Execute-DellCCTK -Parameters "--secureboot" -PassThru
        If ($DebugLog){Write-Host "[cctk --secureboot] exitcode: " $result.ExitCode}
        If ($DebugLog){Write-Host "[cctk --secureboot] output: " $result.StdOut}
    
        [string]$ResultOutput = ($result.StdOut).Trim()
        $Global:SB = $ResultOutput.Split("=")[1]
    
        If ($ResultOutput -eq "secureboot=enable"){
            Write-OutputBox -OutputBoxMessage "Secure Boot is already enabled!" -Type "INFO: " -Object Logging
            $PBSECUREBOOT.Image = $ValidatedImage
            $LabelLegacyROM.Visible = $true
            return $true
        } 
        ElseIf ($result.ExitCode -eq 257){
            Write-OutputBox -OutputBoxMessage "Secure Boot is an option, but not disabled" -Type "WARNING: " -Object Logging
            If ($BIOSCurrentPassword -ne $Null){
                $result2 = Execute-DellCCTK -Parameters "--secureboot=enable --valsetuppwd=$BIOSCurrentPassword" -PassThru
                If ($DebugLog){Write-Host "[cctk --secureboot=enable --valsetuppwd=$BIOSCurrentPassword] exitcode: " $result2.ExitCode}
            } 
            Else {
                $result2 = Execute-DellCCTK -Parameters "--secureboot=enable" -PassThru
                If ($DebugLog){Write-Host "[cctk --secureboot=enable] exitcode: " $result2.ExitCode}
            }

            If ($result2.ExitCode -eq 0){
                Write-OutputBox -OutputBoxMessage "Sucessfully enabled Secure Boot" -Type "INFO: " -Object Logging
                $PBSECUREBOOT.Image = $ValidatedImage
                $LabelLegacyROM.Visible = $true
                return $true             
            } 
            ElseIf($result2.ExitCode -eq 192) {
                Write-OutputBox -OutputBoxMessage "Unable to enable Secure Boot, the BIOS password is unknown." -Type "ERROR: " -Object Logging
                $PBSECUREBOOT.Image = $WarningImage
                $LabelLegacyROM.Visible = $true
                return $false
            } 
            Else {
                Write-OutputBox -OutputBoxMessage "Unable to enable Secure Boot, setting must be enabled manually" -Type "ERROR: " -Object Logging
                $PBSECUREBOOT.Image = $WarningImage
                $LabelLegacyROM.Visible = $true
                return $false
            }
        
        } 
        Else {
            Write-OutputBox -OutputBoxMessage "Secure Boot is not an option." -Type "ERROR: " -Object Logging
            $PBSECUREBOOT.Image = $ErrorImage
            $LabelLegacyROM.Visible = $true
            return $false
        }
    }
    End {
	}
}

Function Validate-TPMModule{
    Begin{
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {
        If($OSCaption){
            $TPMStatus = Get-Tpm | Select-Object -ExpandProperty TpmPresent -ErrorAction SilentlyContinue
        } 
        Else{
            $TPMStatus = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTPM" -Class Win32_TPM -ErrorAction SilentlyContinue
        }
        
	    if ($TPMStatus) {
            Write-OutputBox -OutputBoxMessage "TPM is present" -Type "INFO: " -Object Logging
	        $PBBIOSTPM.Image = $ValidatedImage
	        $LabelBIOSTPM.Visible = $true
            $Global:TPM = $true
	        return $true
        } 
        Else {
		    Write-OutputBox -OutputBoxMessage "TPM is not available for this system." -Type "ERROR: " -Object Logging
            $PBBIOSTPM.Image = $ErrorImage
            $LabelBIOSTPM.Visible = $true
            $Global:TPM = $false
            return $false
	    }
        

    }
    End {    
    }
 }   


Function Validate-TPMEnabled{
    Begin{
        If ($Global:TPM -eq $false){return $false; break}
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {
        If($OSCaption){
            Try {
                $TPMStatus = Get-Tpm | Select-Object -ExpandProperty TpmReady
                if ($TPMStatus) {
                    Write-OutputBox -OutputBoxMessage "TPM is ready" -Type "INFO: " -Object Logging
	                $PBBIOSTPMON.Image = $ValidatedImage
	                $LabelBIOSTPMEnabled.Visible = $true
	                return $true
                } Else {
                    $TPMPresent = Get-Tpm | Select-Object -ExpandProperty TpmPresent
                    if ($TPMPresent) {
                        Write-OutputBox -OutputBoxMessage "TPM is present, but not ready" -Type "WARNING: " -Object Logging
	                    $PBBIOSTPMON.Image = $ValidatedImage
	                    $LabelBIOSTPMEnabled.Visible = $true
	                    return $true
                    } Else {
			            Write-OutputBox -OutputBoxMessage "TPM is not available for this system." -Type "ERROR: " -Object Logging
                        $PBBIOSTPMON.Image = $ErrorImage
                        $LabelBIOSTPMEnabled.Visible = $true
                        return $false
		            }
		        }
            }
            Catch {
		        Write-OutputBox -OutputBoxMessage "TPM is not available for this system." -Type "ERROR: " -Object Logging
                $PBBIOSTPMON.Image = $ErrorImage
                $LabelBIOSTPMEnabled.Visible = $true
                return $false
	        }
        } Else{
            Write-OutputBox -OutputBoxMessage "WinPE detected, OS deployment process will enable TPM" -Type "IGNORE: " -Object Logging
            $PBBIOSTPMON.Image = $WarningImage
            $LabelBIOSTPMEnabled.Visible = $true
            return $true
        }
    }
    End {
    }
}


Function Validate-TPMActivated {
    Begin{
        If ($Global:TPM -eq $false){return $false; break}
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {
        If($OSCaption){
            $result = Execute-DellCCTK -Parameters "--tpmactivation" -PassThru
            If ($DebugLog){Write-Host "[cctk --tpmactivation] exitcode: "$result.ExitCode}
            If ($DebugLog){Write-Host "[cctk --tpmactivation] output: " $result.StdOut}
    
            [string]$ResultOutput = ($result.StdOut).Trim()
            $Global:TPMACT = $ResultOutput.Split("=")[1]

            If ($ResultOutput -eq "tpmactivation=activate"){
                Write-OutputBox -OutputBoxMessage "TPM is activated!" -Type "INFO: " -Object Logging
                $PBBIOSTPMACT.Image = $ValidateImage
                $LabelBIOSTPMActive.Visible = $true
                return $true
            } 
            ElseIf ($result.ExitCode -eq 0){
                Write-OutputBox -OutputBoxMessage "TPM is available for this system, but is not activated" -Type "WARNING: " -Object Logging
                If ($BIOSCurrentPassword -ne $Null){
                    $result2 = Execute-DellCCTK -Parameters "----tpmactivation=activate --valsetuppwd=$BIOSCurrentPassword" -PassThru
                    If ($DebugLog){Write-Host "[cctk --tpmactivation=activate --valsetuppwd=$BIOSCurrentPassword] exitcode: " $result2.ExitCode}
                } 
                Else {
                    $result2 = Execute-DellCCTK -Parameters "--tpmactivation=activate" -PassThru
                    If ($DebugLog){Write-Host "[cctk --tpmactivation=activate] exitcode: " $result2.ExitCode}
                }

                If ($result2.ExitCode -eq 0){
                    Write-OutputBox -OutputBoxMessage "Sucessfully activated the TPM Module" -Type "INFO: " -Object Logging
                    $PBBIOSTPMACT.Image = $ValidateImage
                    $LabelBIOSTPMActive.Visible = $true
                    return $true             
                } 
                ElseIf($result2.ExitCode -eq 192) {
                    Write-OutputBox -OutputBoxMessage "Unable to activate the TPM module, the BIOS password is unknown." -Type "ERROR: " -Object Logging
                    $PBBIOSTPMACT.Image = $WarningImage
                    $LabelBIOSTPMActive.Visible = $true
                    return $false
                } 
                Else {
                    Write-OutputBox -OutputBoxMessage "Unable to activate the TPM module, setting must activated manually" -Type "ERROR: " -Object Logging
                    $PBBIOSTPMACT.Image = $WarningImage
                    $LabelBIOSTPMActive.Visible = $true
                    return $false
                }
        
            } 
            Else {
                Write-OutputBox -OutputBoxMessage "A TPM module is not available for this system." -Type "ERROR: " -Object Logging
                $PBBIOSTPMACT.Image = $ErrorImage
                $LabelBIOSTPMActive.Visible = $true
                return $false
            }
        } 
        Else{
            Write-OutputBox -OutputBoxMessage "WinPE detected, OS deployment process will activate TPM" -Type "IGNORE: " -Object Logging
            $PBBIOSTPMACT.Image = $WarningImage
            $LabelBIOSTPMActive.Visible = $true
            return $true
        }
    }
}

Function Validate-VTFeature {
    Begin{
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {
        $result = Execute-DellCCTK -Parameters "--virtualization" -PassThru
        If ($DebugLog){Write-Host "[cctk --virtualization] exitcode: " $result.ExitCode}
        If ($DebugLog){Write-Host "[cctk --virtualization] output: " $result.StdOut}
    
        [string]$ResultOutput = ($result.StdOut).Trim()
        $Global:VT = $ResultOutput.Split("=")[1]

        If ($ResultOutput -eq "virtualization=enable"){
            Write-OutputBox -OutputBoxMessage "Virtualization Technology is available for this system and is enabled!" -Type "INFO: " -Object Logging
            $PBBIOSVT.Image = $ValidatedImage
            $LabelBIOSVT.Visible = $true
            return $true
        } 
        ElseIf ($result.ExitCode -eq 0){
            Write-OutputBox -OutputBoxMessage "Virtualization Technology is available for this system, but is not enabled" -Type "WARNING: " -Object Logging
            If ($BIOSCurrentPassword -ne $Null){
                $result2 = Execute-DellCCTK -Parameters "--virtualization=enable --valsetuppwd=$BIOSCurrentPassword" -PassThru
                If ($DebugLog){Write-Host "[cctk --virtualization=enable --valsetuppwd=$BIOSCurrentPassword] exitcode: " $result2.ExitCode}
            } 
            Else {
                $result2 = Execute-DellCCTK -Parameters "--virtualization=enable" -PassThru
                If ($DebugLog){Write-Host "[cctk --virtualization=enable] exitcode: " $result2.ExitCode}
            }

            If ($result2.ExitCode -eq 0){
                Write-OutputBox -OutputBoxMessage "Sucessfully enabled Virtualization Technology" -Type "INFO: " -Object Logging
                $PBBIOSVT.Image = $ValidatedImage
                $LabelBIOSVT.Visible = $true
                return $true             
            } 
            ElseIf($result2.ExitCode -eq 192) {
                Write-OutputBox -OutputBoxMessage "Unable to enable Virtualization Technology, the BIOS password is unknown." -Type "ERROR: " -Object Logging
                $PBBIOSVT.Image = $WarningImage
                $LabelBIOSVT.Visible = $true
                return $false
            } 
            Else {
                Write-OutputBox -OutputBoxMessage "Unable to enable Virtualization Technology, setting must be enabled manually" -Type "ERROR: " -Object Logging
                $PBBIOSVT.Image = $WarningImage
                $LabelBIOSVT.Visible = $true
                return $false
            }
        } 
        Else {
            Write-OutputBox -OutputBoxMessage "Virtualization Technology is not available for this system." -Type "ERROR: " -Object Logging
            $PBBIOSVT.Image = $ErrorImage
            $LabelBIOSVT.Visible = $true
            return $false
        }
    }
    End { 
    }
}

Function Validate-VTDirectIO {
    Begin {
        If (!$Global:VT){return $false; break}
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {
        $result = Execute-DellCCTK -Parameters "--vtfordirectio" -PassThru
        If ($DebugLog){Write-Host "[cctk --vtfordirectio] exitcode: " $result.ExitCode}
        If ($DebugLog){Write-Host "[cctk --vtfordirectio] output: " $result.StdOut}
    
        [string]$ResultOutput = ($result.StdOut).Trim()
        [string]$Global:VTDIO = $ResultOutput.Split("=")[1]

        If ($ResultOutput -eq "vtfordirectio=on"){
            Write-OutputBox -OutputBoxMessage "Virtualization Direct IO is available for this system and is enabled!" -Type "INFO: " -Object Logging
            $PBBIOSVTDirectIO.Image = $ValidatedImage
            $LabelBIOSVTDirectIO.Visible = $true
            return $true
        } 
        ElseIf ($result.ExitCode -eq 0){
            Write-OutputBox -OutputBoxMessage "Virtualization Direct IO is available for this system, but is not enabled" -Type "WARNING: " -Object Logging
            If ($BIOSCurrentPassword -ne $Null){
                $result2 = Execute-DellCCTK -Parameters "--vtfordirectio=on --valsetuppwd=$BIOSCurrentPassword" -PassThru
                If ($DebugLog){Write-Host "[cctk --vtfordirectio=on --valsetuppwd=$BIOSCurrentPassword] exitcode: " $result2.ExitCode}
            } 
            Else {
                $result2 = Execute-DellCCTK -Parameters "--vtfordirectio=on" -PassThru
                If ($DebugLog){Write-Host "[cctk vtfordirectio=on] exitcode: " $result2.ExitCode}
            }

            If ($result2.ExitCode -eq 0){
                Write-OutputBox -OutputBoxMessage "Sucessfully enabled Virtualization Direct IO" -Type "INFO: " -Object Logging
                $PBBIOSVTDirectIO.Image = $ValidatedImage
                $LabelBIOSVTDirectIO.Visible = $true
                return $true             
            } 
            ElseIf($result2.ExitCode -eq 192) {
                Write-OutputBox -OutputBoxMessage "Unable to enable Virtualization Direct IO, the BIOS password is unkown." -Type "ERROR: " -Object Logging
                $PBBIOSVTDirectIO.Image = $WarningImage
                $LabelBIOSVTDirectIO.Visible = $true
                return $false
            } 
            Else {
                Write-OutputBox -OutputBoxMessage "Unable to enable Virtualization Direct IO, setting must enabled manually" -Type "ERROR: " -Object Logging
                $PBBIOSVTDirectIO.Image = $WarningImage
                $LabelBIOSVTDirectIO.Visible = $true
                return $false
            }
        
        } 
        Else {
            Write-OutputBox -OutputBoxMessage "Virtualization Direct IO is not enabled or is not available for this system." -Type "ERROR: " -Object Logging
            $PBBIOSVTDirectIO.Image = $ErrorImage
            $LabelBIOSVTDirectIO.Visible = $true
            return $false
        }
    }
    End {	
	}
}

Function Validate-VTTrustedExecution {
    Begin {
        If (!$Global:VT){return $false; break}
        If ($global:PreValidation -eq $false){return $false; break}
    }
    Process {   
        $result = Execute-DellCCTK -Parameters "--trustexecution" -PassThru
        If ($DebugLog){Write-Host "[cctk --trustexecution] exitcode: " $result.ExitCode}
        If ($DebugLog){Write-Host "[cctk --trustexecution] output: " $result.StdOut}

        [string]$ResultOutput = ($result.StdOut).Trim()
        $Global:VTTE = $ResultOutput.Split("=")[1]
    
        If ($ResultOutput -eq "trustexecution=on"){
            Write-OutputBox -OutputBoxMessage "Virtualization Trusted Execution is available for this system and is enabled!" -Type "INFO: " -Object Logging
            $PBBIOSVTTE.Image = $ValidatedImage
            $LabelBIOSVTTE.Visible = $true
            return $true
        } 
        ElseIf ($result.ExitCode -eq 0){
            Write-OutputBox -OutputBoxMessage "Virtualization Trusted Execution is available for this system, but is not enabled" -Type "WARNING: " -Object Logging
            If ($BIOSCurrentPassword -ne $Null){
                $result2 = Execute-DellCCTK -Parameters "--trustexecution=on --valsetuppwd=$BIOSCurrentPassword" -PassThru
                If ($DebugLog){Write-Host "[cctk --trustexecution=on --valsetuppwd=$BIOSCurrentPassword] exitcode: " $result2.ExitCode}
            } 
            Else {
                $result2 = Execute-DellCCTK -Parameters "--vtfordirectio=on" -PassThru
                If ($DebugLog){Write-Host "[cctk trustexecution=on] exitcode: " $result2.ExitCode}
            }

            If ($result2.ExitCode -eq 0){
                Write-OutputBox -OutputBoxMessage "Sucessfully enabled Virtualization Trusted Execution" -Type "INFO: " -Object Logging
                $PBBIOSVTTE.Image = $ValidatedImage
                $LabelBIOSVTTE.Visible = $true
                return $true             
            } 
            ElseIf($result2.ExitCode -eq 192) {
                Write-OutputBox -OutputBoxMessage "Unable to enable Virtualization Trusted Execution, the BIOS password is unknown." -Type "ERROR: " -Object Logging
                $PBBIOSVTTE.Image = $WarningImage
                $LabelBIOSVTTE.Visible = $true
                return $false
            } 
            Else {
                Write-OutputBox -OutputBoxMessage "Unable to enable Virtualization Trusted Execution, setting must enabled manually" -Type "ERROR: " -Object Logging
                $PBBIOSVTTE.Image = $WarningImage
                $LabelBIOSVTTE.Visible = $true
                return $false
            }
        
        } 
        Else {
            Write-OutputBox -OutputBoxMessage "Virtualization Trusted Execution is not enabled or is not available for this system." -Type "ERROR: " -Object Logging
            $PBBIOSVTTE.Image = $ErrorImage
            $LabelBIOSVTTE.Visible = $true
            return $false
        }
    }
    End {
	}
}

function Encrypt-String($String, $Passphrase, $salt="SaltCrypto", $init="IV_Password", [switch]$arrayOutput)
{
	# Create a COM Object for RijndaelManaged Cryptography
	$r = new-Object System.Security.Cryptography.RijndaelManaged
	# Convert the Passphrase to UTF8 Bytes
	$pass = [Text.Encoding]::UTF8.GetBytes($Passphrase)
	# Convert the Salt to UTF Bytes
	$salt = [Text.Encoding]::UTF8.GetBytes($salt)

	# Create the Encryption Key using the passphrase, salt and SHA1 algorithm at 256 bits
	$r.Key = (new-Object Security.Cryptography.PasswordDeriveBytes $pass, $salt, "SHA1", 5).GetBytes(32) #256/8
	# Create the Intersecting Vector Cryptology Hash with the init
	$r.IV = (new-Object Security.Cryptography.SHA1Managed).ComputeHash( [Text.Encoding]::UTF8.GetBytes($init) )[0..15]
	
	# Starts the New Encryption using the Key and IV   
	$c = $r.CreateEncryptor()
	# Creates a MemoryStream to do the encryption in
	$ms = new-Object IO.MemoryStream
	# Creates the new Cryptology Stream --> Outputs to $MS or Memory Stream
	$cs = new-Object Security.Cryptography.CryptoStream $ms,$c,"Write"
	# Starts the new Cryptology Stream
	$sw = new-Object IO.StreamWriter $cs
	# Writes the string in the Cryptology Stream
	$sw.Write($String)
	# Stops the stream writer
	$sw.Close()
	# Stops the Cryptology Stream
	$cs.Close()
	# Stops writing to Memory
	$ms.Close()
	# Clears the IV and HASH from memory to prevent memory read attacks
	$r.Clear()
	# Takes the MemoryStream and puts it to an array
	[byte[]]$result = $ms.ToArray()
	# Converts the array from Base 64 to a string and returns
	return [Convert]::ToBase64String($result)
}

function Decrypt-String($Encrypted, $Passphrase, $salt="SaltCrypto", $init="IV_Password")
{
	# If the value in the Encrypted is a string, convert it to Base64
	if($Encrypted -is [string]){
		$Encrypted = [Convert]::FromBase64String($Encrypted)
   	}

	# Create a COM Object for RijndaelManaged Cryptography
	$r = new-Object System.Security.Cryptography.RijndaelManaged
	# Convert the Passphrase to UTF8 Bytes
	$pass = [Text.Encoding]::UTF8.GetBytes($Passphrase)
	# Convert the Salt to UTF Bytes
	$salt = [Text.Encoding]::UTF8.GetBytes($salt)

	# Create the Encryption Key using the passphrase, salt and SHA1 algorithm at 256 bits
	$r.Key = (new-Object Security.Cryptography.PasswordDeriveBytes $pass, $salt, "SHA1", 5).GetBytes(32) #256/8
	# Create the Intersecting Vector Cryptology Hash with the init
	$r.IV = (new-Object Security.Cryptography.SHA1Managed).ComputeHash( [Text.Encoding]::UTF8.GetBytes($init) )[0..15]


	# Create a new Decryptor
	$d = $r.CreateDecryptor()
	# Create a New memory stream with the encrypted value.
	$ms = new-Object IO.MemoryStream @(,$Encrypted)
	# Read the new memory stream and read it in the cryptology stream
	$cs = new-Object Security.Cryptography.CryptoStream $ms,$d,"Read"
	# Read the new decrypted stream
	$sr = new-Object IO.StreamReader $cs
	# Return from the function the stream
	Write-Output $sr.ReadToEnd()
	# Stops the stream	
	$sr.Close()
	# Stops the crypology stream
	$cs.Close()
	# Stops the memory stream
	$ms.Close()
	# Clears the RijndaelManaged Cryptology IV and Key
	$r.Clear()
}


function Clear-OutputBox {
	$OutputBox.ResetText()	
}

function Write-OutputBox {
	param(
	[parameter(Mandatory=$true)]
	[string]$OutputBoxMessage,
	[ValidateSet("WARNING: ","ERROR: ","INFO: ","IGNORE: "," ")]
	[string]$Type,
    [parameter(Mandatory=$true)]
    [ValidateSet("SHB","Logging","SysInfo")]
    [string]$Object
	)
	Process {
        if ($Object -like "SHB") {
		    if ($OutputBoxSHB.Text.Length -eq 0) {
			    $OutputBoxSHB.Text = "$($Type)$($OutputBoxMessage)"
			    [System.Windows.Forms.Application]::DoEvents()
                $OutputBoxSHB.ScrollToCaret()
		    }
		    else {
			    $OutputBoxSHB.AppendText("`n$($Type)$($OutputBoxMessage)")
			    [System.Windows.Forms.Application]::DoEvents()
                $OutputBoxSHB.ScrollToCaret()
		    }
        }
        if ($Object -like "Logging") {
		    if ($OutputBoxLogging.Text.Length -eq 0) {
			    $OutputBoxLogging.Text = "$($Type)$($OutputBoxMessage)"
			    [System.Windows.Forms.Application]::DoEvents()
                $OutputBoxLogging.ScrollToCaret()
		    }
		    else {
			    $OutputBoxLogging.AppendText("`n$($Type)$($OutputBoxMessage)")
			    [System.Windows.Forms.Application]::DoEvents()
                $OutputBoxLogging.ScrollToCaret()
		    }
        }
        if ($Object -like "SysInfo") {
		    if ($OutputBoxSysInfo.Text.Length -eq 0) {
			    $OutputBoxSysInfo.Text = "$($Type)$($OutputBoxMessage)"
			    [System.Windows.Forms.Application]::DoEvents()
                $OutputBoxSysInfo.ScrollToCaret()
		    }
		    else {
			    $OutputBoxSysInfo.AppendText("`n$($Type)$($OutputBoxMessage)")
			    [System.Windows.Forms.Application]::DoEvents()
                $OutputBoxSysInfo.ScrollToCaret()
		    }
        }
	}
}

##*=============================================
##* ASSEMBLIES
##*=============================================
Add-Type -AssemblyName "System.Drawing"
Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "System.DirectoryServices"

##*=============================================
##* FORM
##*=============================================
#Get Screen Resolution
$FormWidth = 805
$FormHeight = 530

<#$Image = [system.drawing.image]::FromFile("$($Env:Public)\Pictures\Sample Pictures\Oryx Antelope.jpg")
$Form.BackgroundImage = $Image
$Form.BackgroundImageLayout = "None"
    # None, Tile, Center, Stretch, Zoom
#>
$Form = New-Object System.Windows.Forms.Form 
$Form.Size = New-Object System.Drawing.Size($FormWidth,$FormHeight)  
$Form.MinimumSize = New-Object System.Drawing.Size($FormWidth,$FormHeight)
$Form.MaximumSize = New-Object System.Drawing.Size($FormWidth,$FormHeight)
$Form.MinimizeBox = $False
$Form.MaximizeBox = $False
#$Form.ControlBox = $false
$Form.ShowInTaskbar = $False
$Form.SizeGripStyle = "Hide"
$Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHome + "\powershell.exe")
$Form.Text = ($apptitle + " (" + $appversion + ")")
$Form.StartPosition = "CenterScreen"
#$Form.FormBorderStyle = "Fixed Single"

$Form.Topmost = $True  
    # CenterScreen, Manual, WindowsDefaultLocation, WindowsDefaultBounds, CenterParent
# Base64
$ValidatedBase64String = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAJMSURBVDhPlZJdSJNhFMcftFAjdSXdRBcFFlGRa6zUlm7pKrMuqpskKKQLK/pECppR
vYRzjpb7cDq3nO87ZLbRcG02nS4Soi6kQsG5wtgmkkPmxy5G1/8e7SU01rIfPDwX5zzP+f/POeS/
MJPtGZYMNtuaPZzP5bFbugsEfGQNmImAPo6eGzqNmx/qcJbe23q2DvPRf5NpyWQqfVLoJ5qh+Hwb
+pAae1yF4MPpWf98nVDA5ePZhBL1n+qWj+6Lin6wa20f5FDPt0auoHVSjasfL8AaMeLiu/Mo6t2r
5VP+zoaunFqRuwjclAn3g9fRHtZAGXwIoXtfVPRqP9/ENiIkJlJLOui9glx2o4B2O2GglVsjKmjC
DGzTHZD1SyD2CGW/stqIttC+Ayf75SjgNoF2+7cs6pu99L4GPTOdaI40oDdux7WRyzjkPbBCejtB
09gjaGmDWkJNWJKb1ZnFbrYJZLtf7oRrthvG7yq45mwwRjUo9oqipX3iFfM3ERjoSB6M3gEzfm/Z
64nBCtAlgfrrEzjiVrBxAzwLL1AVqMTh1wdX2STUt7bEI4b5mw7KkAJPJx/DEWPBBBXoW3Cia06P
N0kv7o7dwBFfMcO/Ws3Sekp9EtimOqANN0JF/XrnHbDPmzGQdIGNmVDmKxnl01OTx+WypwLH4Yxx
sMy0QB9rhDNhxWDSjTNvq3F0QPKH9BTQ3WZpJThnObgWOQz/8KFhvB6V/rLU0lNB15OtDsjhXXTC
PK2D3F+eXnoq6KiYcl9p4phfGq0aqkgjnZCf1ZM3pZ8/L2UAAAAASUVORK5CYII="
$ValidatedImageBytes = [Convert]::FromBase64String($ValidatedBase64String)
$ValidatedMemoryStream = New-Object -TypeName IO.MemoryStream($ValidatedImageBytes, 0, $ValidatedImageBytes.Length)
$ValidatedMemoryStream.Write($ValidatedImageBytes, 0, $ValidatedImageBytes.Length)
$ValidatedImage = [System.Drawing.Image]::FromStream($ValidatedMemoryStream, $true)

$WarningBase64String = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAOCAYAAAAmL5yKAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJ
bWFnZVJlYWR5ccllPAAAAyFpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdp
bj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6
eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNS1jMDE0IDc5LjE1
MTQ4MSwgMjAxMy8wMy8xMy0xMjowOToxNSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJo
dHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlw
dGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAv
IiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RS
ZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpD
cmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIChXaW5kb3dzKSIgeG1wTU06SW5zdGFuY2VJ
RD0ieG1wLmlpZDozRjc3RkMyQzEyMkUxMUU2QTkwQ0QyNTc2NzhGQjE0QyIgeG1wTU06RG9jdW1l
bnRJRD0ieG1wLmRpZDozRjc3RkMyRDEyMkUxMUU2QTkwQ0QyNTc2NzhGQjE0QyI+IDx4bXBNTTpE
ZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOjNGNzdGQzJBMTIyRTExRTZBOTBD
RDI1NzY3OEZCMTRDIiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjNGNzdGQzJCMTIyRTExRTZB
OTBDRDI1NzY3OEZCMTRDIi8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBt
ZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+qs7huQAAAh5JREFUeNqMkt9rUnEYxh93jm7Mgz/wB8s1
SiUWO5BDi2zBwLLVRTiKVoHDFSNz1G4GttqKXdTfEMQuSpCguy66r9ZFUHZR1KKLrlqbTl3+XGrH
8/adaSnM2Jfzgfd73vd54LznAdocQakUXgd8H9+Mn/6sUSo1zT2n0wkiqtHRziDoGLzmnuoXD4Xs
+6+K4nS7uW0NrFqdbXbCOwu3ETiqR/iiO2wXNPt2bDB/fHjB7LPovyX0+LoiwHTGoJ0fci3syGC4
x+KZPN8f+FQs4nGkjIcPJLzNlXH5wh6/x2A+8V8Djj13joj3MLKJUmUDqWQC+dwP/KIiMFrBbZf1
LhvjZba8xuGbDcZNPZPeUdUQ9ClYSpvIZpWQJAl9u34ChiyOneMP+5fUwZf5wv1YLFbTKBpiIzrM
L0bs78Qnxt3QqVGtdiEU4plBFYuLZfB8AcjmsOxLr3qW4q51ULzlE6538jfFSwUmTrFbChyXhE63
zkgy8da7DUCbwUCwYJnmMNeyCBEYXPWiRJKKZUPP6GVYKRq1UyRiY3Ufw8ToJqoqKH4SFQdw8K/B
IzWe0vNGuBQMVW04HhdobU1gdReDa4SP6BUoKuBZTXwW8Gev4F+ziQMO0IAIkrfp5adAY0AA7/di
hZbrjSpDrsPut8KgGzNNQrk+s1V/AX2w4TuflpFJzqBXlgFq2ouC/Z+57j914hTrUWuAOBaatITM
bwEGAF7CG6ZJhs9jAAAAAElFTkSuQmCC"
$WarningImageBytes = [Convert]::FromBase64String($WarningBase64String)
$WarningMemoryStream = New-Object -TypeName IO.MemoryStream($WarningImageBytes, 0, $WarningImageBytes.Length)
$WarningMemoryStream.Write($WarningImageBytes, 0, $WarningImageBytes.Length)
$WarningImage = [System.Drawing.Image]::FromStream($WarningMemoryStream, $true)

$ErrorBase64String = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
jwv8YQUAAAJ0SURBVDhPdZPNTxphEMb35DeCioAgYPhGFPzCjxiNJurBxGiC+g940Zsa/w+u3ji3
VdfWGlywWO3uIqb1pTWx1V5M2nhp00PTpMen865gsdhJ5rLwm2eemXmFYuSXluJnsZi4azYbCp/K
QmxpMZzOzYnK9HS88OkuLlZWErebm3g7P49UKMR2LZayIgWYfdrYgDw4iHQwmNB+4MoaHItBHR+H
MjoKKRBgHND+QLFjtRqyHF5fhxKNQu7p0TLl98cF3jZXLsLK8DDkoSFIPh/boSL38NoalN5eKF1d
93ng8YjCc/LM2y6F5f5+yH19OPB6WXZ2ll2trkIlRTUSgRoOI0speTxsm4prLXLPvO1SWCGAq3xc
Xka2u1uDTilznZ2Q3G62bbM9nBP3zNsuhbmiEghAbmuD4nRCpUwRvPUvXAzumbctk9Kx3Y5MfT1e
U54YDFCamnBgsbCt1tbHYR58YMrUFGMzM3hVV6fBbxoaoBqNyJlMSNls7Nn/CnB1meD84iIOCTwq
gc/MZryzWvHe4UDG4WBP7fZy//LkJMsvLCBNyhnKY71eaztH8LnNhg/k/9LlwpXXi2OX62+RIswI
lmprka6pwZFOp6lzz2lqmytfut347PfjJhTCF5qRQgN/4nAYBHliQjynQ0pWV0OqqsIhFeHekyaT
NjDuOeN0smufDzcdHbillX6ja/xO684Gg6JwNDAQ36+sRLKiAikqwoe339z8YFW83RNa31daKwd/
0sH9GhlBPhy+e1QvdLpEscBLo7H8SCh4EdXvZz/oIf0eG8N1NHr3mIqxp9fH9xobxfvzfCS451x7
u3gRiRSesyD8Adwnbx6z9nmyAAAAAElFTkSuQmCC"
$ErrorImageBytes = [Convert]::FromBase64String($ErrorBase64String)
$ErrorMemoryStream = New-Object -TypeName IO.MemoryStream($ErrorImageBytes, 0, $ErrorImageBytes.Length)
$ErrorMemoryStream.Write($ErrorImageBytes, 0, $ErrorImageBytes.Length)
$ErrorImage = [System.Drawing.Image]::FromStream($ErrorMemoryStream, $true)

# PictureBoxes
$PBReboot = New-Object -TypeName System.Windows.Forms.PictureBox
$PBReboot.Location = New-Object -TypeName System.Drawing.Size(203,50)
$PBReboot.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBModel = New-Object -TypeName System.Windows.Forms.PictureBox
$PBModel.Location = New-Object -TypeName System.Drawing.Size(203,50)
$PBModel.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBOS = New-Object -TypeName System.Windows.Forms.PictureBox
$PBOS.Location = New-Object -TypeName System.Drawing.Size(203,90)
$PBOS.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBPS = New-Object -TypeName System.Windows.Forms.PictureBox
$PBPS.Location = New-Object -TypeName System.Drawing.Size(203,130)
$PBPS.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBUEFI = New-Object -TypeName System.Windows.Forms.PictureBox
$PBUEFI.Location = New-Object -TypeName System.Drawing.Size(203,170)
$PBUEFI.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSRevision = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSRevision.Location = New-Object -TypeName System.Drawing.Size(444,72)
$PBBIOSRevision.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSPassword = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSPassword.Location = New-Object -TypeName System.Drawing.Size(444,112)
$PBBIOSPassword.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSTPM = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSTPM.Location = New-Object -TypeName System.Drawing.Size(444,192)
$PBBIOSTPM.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSTPMON = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSTPMON.Location = New-Object -TypeName System.Drawing.Size(444,232)
$PBBIOSTPMON.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSTPMACT = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSTPMACT.Location = New-Object -TypeName System.Drawing.Size(444,272)
$PBBIOSTPMACT.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSVT = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSVT.Location = New-Object -TypeName System.Drawing.Size(720,72)
$PBBIOSVT.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSVTDirectIO = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSVTDirectIO.Location = New-Object -TypeName System.Drawing.Size(720,112)
$PBBIOSVTDirectIO.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBBIOSVTTE = New-Object -TypeName System.Windows.Forms.PictureBox
$PBBIOSVTTE.Location = New-Object -TypeName System.Drawing.Size(720,152)
$PBBIOSVTTE.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBLEGACYOROM = New-Object -TypeName System.Windows.Forms.PictureBox
$PBLEGACYOROM.Location = New-Object -TypeName System.Drawing.Size(720,232)
$PBLEGACYOROM.Size = New-Object -TypeName System.Drawing.Size(16,16)

$PBSECUREBOOT = New-Object -TypeName System.Windows.Forms.PictureBox
$PBSECUREBOOT.Location = New-Object -TypeName System.Drawing.Size(720,272)
$PBSECUREBOOT.Size = New-Object -TypeName System.Drawing.Size(16,16)


# ListBoxes
$LBOSVersions = New-Object -TypeName System.Windows.Forms.ListBox
$LBOSVersions.Location = New-Object -TypeName System.Drawing.Size(30,390)
$LBOSVersions.Size = New-Object -TypeName System.Drawing.Size(200,56)
$LBOSVersions.SelectionMode = "None"
$LBOSVersions.Items.AddRange(@($SupportedOperatingSystems.name))

# TabPages
$TabSHBPage = New-Object System.Windows.Forms.TabPage
$TabSHBPage.Location = New-Object System.Drawing.Size(10,50)
$TabSHBPage.Size = New-Object System.Drawing.Size(300,300)
$TabSHBPage.Text = "SHB"
$TabSHBPage.Name = "SHB"
$TabSHBPage.Padding = "0,0,0,0"
$TabSHBPage.BackColor = "Control"

$TabLoggingPage = New-Object System.Windows.Forms.TabPage
$TabLoggingPage.Location = New-Object System.Drawing.Size(10,50)
$TabLoggingPage.Size = New-Object System.Drawing.Size(300,300)
$TabLoggingPage.Text = "Logging"
$TabLoggingPage.Name = "Logging"
$TabLoggingPage.Padding = "0,0,0,0"
$TabLoggingPage.BackColor = "Control"

$TabControl = New-Object System.Windows.Forms.TabControl
$TabControl.Location = New-Object System.Drawing.Size(0,0)
$TabControl.Size = New-Object System.Drawing.Size(805,530)
$TabControl.Anchor = "Top, Bottom, Left, Right"
$TabControl.Name = "Global"
$TabControl.SelectedIndex = 0
$TabControl.Add_Selected([System.Windows.Forms.TabControlEventHandler]{
    if ($TabControl.SelectedTab.Name -like "Logging") {
        Load-LoggingPage
        if ($TabControl.SelectedTab.Enabled -eq $true) {
            if (-not($OutputBoxLogging.Text.Length -ge 1)) {
                $OutputBoxLogging.ResetText()
                Write-OutputBox -OutputBoxMessage "Addtionally you can choose to output a log file to your desktop" -Type "INFO: " -Object SysInfo
            }
        }
    }
})

# ProgressBars
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Size(260,340)
$ProgressBar.Size = New-Object System.Drawing.Size(495,30)
$ProgressBar.Step = 1
$ProgressBar.Value = 0

# OutputBoxes
$OutputBoxSysInfo = New-Object System.Windows.Forms.RichTextBox 
$OutputBoxSysInfo.Location = New-Object System.Drawing.Size(30,250) 
$OutputBoxSysInfo.Size = New-Object System.Drawing.Size(200,115)
$OutputBoxSysInfo.BackColor = "white"
$OutputBoxSysInfo.ReadOnly = $true
$OutputBoxSysInfo.MultiLine = $True

$OutputBoxLogging = New-Object System.Windows.Forms.RichTextBox 
$OutputBoxLogging.Location = New-Object System.Drawing.Size(10,10) 
$OutputBoxLogging.Size = New-Object System.Drawing.Size(763,350)
$OutputBoxLogging.Font = "Courier New"
$OutputBoxLogging.BackColor = "white"
$OutputBoxLogging.ReadOnly = $true
$OutputBoxLogging.MultiLine = $True

# Buttons
$ButtonExportLogging = New-Object System.Windows.Forms.Button 
$ButtonExportLogging.Location = New-Object System.Drawing.Size(673,420) 
$ButtonExportLogging.Size = New-Object System.Drawing.Size(100,30) 
$ButtonExportLogging.Text = "Export"
$ButtonExportLogging.Name = "ExportBtn"
$ButtonExportLogging.TabIndex = "1"
$ButtonExportLogging.Add_Click({Get-SystemInfo})

$ButtonContinueExit = New-Object System.Windows.Forms.Button
$ButtonContinueExit.Location = New-Object System.Drawing.Size(655,420)
$ButtonContinueExit.Size = New-Object System.Drawing.Size(100,30)
$ButtonContinueExit.Text = "Continue"
$ButtonExportLogging.Name = "ContinueBtn"
$ButtonContinueExit.Add_Click(
    {$Looping=$False
    $Form.Close()
    #[environment]::exit(0)
    [System.Windows.Forms.Application]::Exit($null)
    })
$Form.Controls.Add($ButtonContinueExit)

# Labels
$LabelHeader = New-Object System.Windows.Forms.Label
$LabelHeader.Location = New-Object System.Drawing.Size(240,10)
$LabelHeader.Size = New-Object System.Drawing.Size(500,30)
$LabelHeader.Text = $apptitle
$LabelHeader.Font = New-Object System.Drawing.Font("Verdana",12,[System.Drawing.FontStyle]::Bold)
$LabelHeader.TextAlign = 'TopRight'

$LabelPendingRestart = New-Object System.Windows.Forms.Label
$LabelPendingRestart.Size = New-Object System.Drawing.Size(150,15)
$LabelPendingRestart.Location = New-Object System.Drawing.Size(38,52)
$LabelPendingRestart.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelPendingRestart.Text = "Reboot Required"

$LabelSupportedModel = New-Object System.Windows.Forms.Label
$LabelSupportedModel.Size = New-Object System.Drawing.Size(150,15)
$LabelSupportedModel.Location = New-Object System.Drawing.Size(38,52)
$LabelSupportedModel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelSupportedModel.Text = "Supported Model"

$LabelSupportedOS = New-Object System.Windows.Forms.Label
$LabelSupportedOS.Size = New-Object System.Drawing.Size(160,15)
$LabelSupportedOS.Location = New-Object System.Drawing.Size(38,92)
$LabelSupportedOS.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelSupportedOS.Text = "Operating System"

$LabelPowerShell = New-Object System.Windows.Forms.Label
$LabelPowerShell.Size = New-Object System.Drawing.Size(160,15)
$LabelPowerShell.Location = New-Object System.Drawing.Size(38,132)
$LabelPowerShell.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelPowerShell.Text = "PowerShell Version"

$LabelUEFI = New-Object System.Windows.Forms.Label
$LabelUEFI.Size = New-Object System.Drawing.Size(160,15)
$LabelUEFI.Location = New-Object System.Drawing.Size(38,172)
$LabelUEFI.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelUEFI.Text = "UEFI Enabled"

$LabelBIOSRevision = New-Object System.Windows.Forms.Label
$LabelBIOSRevision.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSRevision.Location = New-Object System.Drawing.Size(278,74)
$LabelBIOSRevision.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSRevision.Text = "Revision"

$LabelBIOSPassword = New-Object System.Windows.Forms.Label
$LabelBIOSPassword.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSPassword.Location = New-Object System.Drawing.Size(278,114)
$LabelBIOSPassword.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSPassword.Text = "Password Known"

$LabelBIOSTPM = New-Object System.Windows.Forms.Label
$LabelBIOSTPM.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSTPM.Location = New-Object System.Drawing.Size(278,194)
$LabelBIOSTPM.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSTPM.Text = "TPM Exist"

$LabelBIOSTPMEnabled = New-Object System.Windows.Forms.Label
$LabelBIOSTPMEnabled.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSTPMEnabled.Location = New-Object System.Drawing.Size(278,234)
$LabelBIOSTPMEnabled.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSTPMEnabled.Text = "TPM Enabled"

$LabelBIOSTPMActive = New-Object System.Windows.Forms.Label
$LabelBIOSTPMActive.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSTPMActive.Location = New-Object System.Drawing.Size(278,274)
$LabelBIOSTPMActive.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSTPMActive.Text = "TPM Activated"

$LabelBIOSVT = New-Object System.Windows.Forms.Label
$LabelBIOSVT.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSVT.Location = New-Object System.Drawing.Size(554,74)
$LabelBIOSVT.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSVT.Text = "Virtualization Support"

$LabelBIOSVTDirectIO = New-Object System.Windows.Forms.Label
$LabelBIOSVTDirectIO.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSVTDirectIO.Location = New-Object System.Drawing.Size(554,114)
$LabelBIOSVTDirectIO.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSVTDirectIO.Text = "Direct I/O"

$LabelBIOSVTTE = New-Object System.Windows.Forms.Label
$LabelBIOSVTTE.Size = New-Object System.Drawing.Size(150,15)
$LabelBIOSVTTE.Location = New-Object System.Drawing.Size(554,154)
$LabelBIOSVTTE.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelBIOSVTTE.Text = "Trusted Execution"

$LabelLegacyROM = New-Object System.Windows.Forms.Label
$LabelLegacyROM.Size = New-Object System.Drawing.Size(150,15)
$LabelLegacyROM.Location = New-Object System.Drawing.Size(554,234)
$LabelLegacyROM.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelLegacyROM.Text = "Legacy ROM Disabled"

$LabelSecureBoot = New-Object System.Windows.Forms.Label
$LabelSecureBoot.Size = New-Object System.Drawing.Size(150,15)
$LabelSecureBoot.Location = New-Object System.Drawing.Size(554,274)
$LabelSecureBoot.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$LabelSecureBoot.Text = "Secure Boot Enabled"

# CheckBoxes
$CBPrerequisitesOverride = New-Object System.Windows.Forms.CheckBox
$CBPrerequisitesOverride.Location = New-Object System.Drawing.Size(30,205)
$CBPrerequisitesOverride.Size = New-Object System.Drawing.Size(180,20)
$CBPrerequisitesOverride.Text = "Override Prerequisites"
$CBPrerequisitesOverride.Name = "PrerequisitesOverride"
$CBPrerequisitesOverride.Add_CheckedChanged({
    switch ($CBPrerequisitesOverride.Checked) {
        $true { Interactive-TabPages -Mode Enable }
        $false { Interactive-TabPages -Mode Disable }
    }
})

$CBContinueOverride = New-Object System.Windows.Forms.CheckBox
$CBContinueOverride.Location = New-Object System.Drawing.Size(455,426)
$CBContinueOverride.Size = New-Object System.Drawing.Size(180,20)
$CBContinueOverride.Text = "Override validation results"
$CBContinueOverride.Name = "validationOverride"
$CBContinueOverride.Add_CheckedChanged({
    switch ($CBContinueOverride.Checked) {
        $true { Interactive-Buttons -Mode Enable }
        $false { Interactive-Buttons -Mode Disable }
    }
})


# GroupBoxes
$GBSystemValidation = New-Object System.Windows.Forms.GroupBox
$GBSystemValidation.Location = New-Object System.Drawing.Size(20,20) 
$GBSystemValidation.Size = New-Object System.Drawing.Size(220,210)
$GBSystemValidation.Text = "Pre-Load Validation"

$GBSystemModel = New-Object System.Windows.Forms.GroupBox
$GBSystemModel.Location = New-Object System.Drawing.Size(20,234) 
$GBSystemModel.Size = New-Object System.Drawing.Size(220,138)
$GBSystemModel.Text = "System Information"

$GBOSVersion = New-Object System.Windows.Forms.GroupBox
$GBOSVersion.Location = New-Object System.Drawing.Size(20,375) 
$GBOSVersion.Size = New-Object System.Drawing.Size(220,78)
$GBOSVersion.Text = "Supported Operating Systems"

$GBBIOSInfo = New-Object System.Windows.Forms.GroupBox
$GBBIOSInfo.Location = New-Object System.Drawing.Size(260,45) 
$GBBIOSInfo.Size = New-Object System.Drawing.Size(220,106)
$GBBIOSInfo.Text = "BIOS Info"

$GBTPMSettings = New-Object System.Windows.Forms.GroupBox
$GBTPMSettings.Location = New-Object System.Drawing.Size(260,164) 
$GBTPMSettings.Size = New-Object System.Drawing.Size(220,146)
$GBTPMSettings.Text = "TPM Settings"

$GBVTSettings = New-Object System.Windows.Forms.GroupBox
$GBVTSettings.Location = New-Object System.Drawing.Size(535,45) 
$GBVTSettings.Size = New-Object System.Drawing.Size(220,146)
$GBVTSettings.Text = "Virtualization Settings"

$GBBootSettings = New-Object System.Windows.Forms.GroupBox
$GBBootSettings.Location = New-Object System.Drawing.Size(535,204) 
$GBBootSettings.Size = New-Object System.Drawing.Size(220,106)
$GBBootSettings.Text = "Boot Settings"

$GBModel = New-Object System.Windows.Forms.GroupBox
$GBModel.Location = New-Object System.Drawing.Size(30,35) 
$GBModel.Size = New-Object System.Drawing.Size(200,40) 

$GBOS = New-Object System.Windows.Forms.GroupBox
$GBOS.Location = New-Object System.Drawing.Size(30,75) 
$GBOS.Size = New-Object System.Drawing.Size(200,40)

$GBPS = New-Object System.Windows.Forms.GroupBox
$GBPS.Location = New-Object System.Drawing.Size(30,115) 
$GBPS.Size = New-Object System.Drawing.Size(200,40) 

$GBUEFI = New-Object System.Windows.Forms.GroupBox
$GBUEFI.Location = New-Object System.Drawing.Size(30,155) 
$GBUEFI.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSRevision = New-Object System.Windows.Forms.GroupBox
$GBBIOSRevision.Location = New-Object System.Drawing.Size(270,58) 
$GBBIOSRevision.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSPassword = New-Object System.Windows.Forms.GroupBox
$GBBIOSPassword.Location = New-Object System.Drawing.Size(270,98) 
$GBBIOSPassword.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSTPM = New-Object System.Windows.Forms.GroupBox
$GBBIOSTPM.Location = New-Object System.Drawing.Size(270,178) 
$GBBIOSTPM.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSTPMON = New-Object System.Windows.Forms.GroupBox
$GBBIOSTPMON.Location = New-Object System.Drawing.Size(270,218) 
$GBBIOSTPMON.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSTPMACT = New-Object System.Windows.Forms.GroupBox
$GBBIOSTPMACT.Location = New-Object System.Drawing.Size(270,258) 
$GBBIOSTPMACT.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSVT = New-Object System.Windows.Forms.GroupBox
$GBBIOSVT.Location = New-Object System.Drawing.Size(545,58) 
$GBBIOSVT.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSVTDirectIO = New-Object System.Windows.Forms.GroupBox
$GBBIOSVTDirectIO.Location = New-Object System.Drawing.Size(545,98) 
$GBBIOSVTDirectIO.Size = New-Object System.Drawing.Size(200,40) 

$GBBIOSVTTE = New-Object System.Windows.Forms.GroupBox
$GBBIOSVTTE.Location = New-Object System.Drawing.Size(545,138) 
$GBBIOSVTTE.Size = New-Object System.Drawing.Size(200,40) 

$GBLEGACYROM = New-Object System.Windows.Forms.GroupBox
$GBLEGACYROM.Location = New-Object System.Drawing.Size(545,218) 
$GBLEGACYROM.Size = New-Object System.Drawing.Size(200,40) 

$GBSECUREBOOT = New-Object System.Windows.Forms.GroupBox
$GBSECUREBOOT.Location = New-Object System.Drawing.Size(545,258) 
$GBSECUREBOOT.Size = New-Object System.Drawing.Size(200,40) 

$GBLogging = New-Object System.Windows.Forms.GroupBox
$GBLogging.Location = New-Object System.Drawing.Size(10,10) 
$GBLogging.Size = New-Object System.Drawing.Size(190,350) 
$GBLogging.Text = "Logging"
$GBLogging.Name = "Logging"


##*=============================================
##* MAIN
##*=============================================
Load-Form
