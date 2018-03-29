##*=============================================
##* VARIABLE DECLARATION
##*=============================================
$ComputerName = $env:COMPUTERNAME
$ComputerSystem = Get-WmiObject -Namespace "root\cimv2" -Class Win32_ComputerSystem
[string]$Manufacturer = $ComputerSystem.Manufacturer
[string]$Model = $ComputerSystem.Model
$BIOSInfo = get-wmiobject Win32_BIOS
[string]$SerialNumber = $BIOSInfo.SerialNumber

[boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' } Else { [string]$envOSArchitecture = '32-bit' }


Function Load-Form 
{
    $Form.Controls.AddRange(@(
        $LabelManufacturer,
        $LabelModel,
        $LabelSerial,
        
        $GBModel,
        $PBDELLCHASSIS,
        
        #$GBSystemInfo,
        #$OutputBoxSysInfo,

        $TBComputerName,
        $GBComputerName,
        $ButtonOK
    ))
    #$Form.Add_Shown({Retrieve-SystemInfo -DisplayType "Basic" -DisplayOutbox -IgnorePing})
    $Form.Add_Shown({Get-SystemImage})
    $Form.Add_Shown({$Form.Activate()})
    [void] $Form.ShowDialog()
    
}

Function Get-SystemImage{
    $system = Get-WMIObject -class Win32_systemenclosure
    $type = $system.chassistypes

    Switch ($Type)
        {
            "1" {$Type = "Other";$PBDELLCHASSIS.Image = $Null}
            "2" {$Type = "Virtual Machine";$PBDELLCHASSIS.Image = $VMImage}
            "3" {$Type = "Desktop";$PBDELLCHASSIS.Image = $DesktopImage}
            "4" {$type = "Low Profile Desktop";$PBDELLCHASSIS.Image = $DesktopImage}
            "5" {$type = "Pizza Box";$PBDELLCHASSIS.Image = $Null}
            "6" {$type = "Mini Tower";$PBDELLCHASSIS.Image = $DesktopImage}
            "7" {$type = "Tower";$PBDELLCHASSIS.Image = $DesktopImage}
            "8" {$type = "Portable";$PBDELLCHASSIS.Image = $Null}
            "9" {$type = "Laptop";$PBDELLCHASSIS.Image = $LaptopImage}
            "10" {$type = "Notebook";$PBDELLCHASSIS.Image = $LaptopImage}
            "11" {$type = "Handheld";$PBDELLCHASSIS.Image = $Null}
            "12" {$type = "Docking Station";$PBDELLCHASSIS.Image = $Null}
            "13" {$type = "All-in-One";$PBDELLCHASSIS.Image = $Null}
            "14" {$type = "Sub-Notebook";$PBDELLCHASSIS.Image = $Null}
            "15" {$type = "Space Saving";$PBDELLCHASSIS.Image = $Null}
            "16" {$type = "Lunch Box";$PBDELLCHASSIS.Image = $Null}
            "17" {$type = "Main System Chassis";$PBDELLCHASSIS.Image = $Null}
            "18" {$type = "Expansion Chassis";$PBDELLCHASSIS.Image = $Null}
            "19" {$type = "Sub-Chassis";$PBDELLCHASSIS.Image = $Null}
            "20" {$type = "Bus Expansion Chassis";$PBDELLCHASSIS.Image = $Null}
            "21" {$type = "Peripheral Chassis";$PBDELLCHASSIS.Image = $Null}
            "22" {$type = "Storage Chassis";$PBDELLCHASSIS.Image = $Null}
            "23" {$type = "Rack Mount Chassis";$PBDELLCHASSIS.Image = $Null}
            "24" {$type = "Sealed-Case PC";$PBDELLCHASSIS.Image = $Null}
            Default {$type = "Unknown";$PBDELLCHASSIS.Image = $Null}
         }
    $LabelModel.Visible = $true
}

Function Get-OSDComputerName{
    If ($ComputerName.StartsWith('MININT')) {
        If ($serialNumber.StartsWith('System')){
            return "[Unit]-[identifier]"
        }
        Else{
            return "[Unit]-" + $serialNumber
        }
    } 
    ElseIf ($ComputerName.StartsWith('MINWINPC')) {
        If ($serialNumber.StartsWith('System')){
            return "[Unit]-[identifier]"
        }
        Else{
            return "[Unit]-" + $serialNumber
        }
    } 
    Else {
        return $ComputerName
    }
}
Function Set-OSDComputerName 
{
    $ErrorProvider.Clear()
    $ErrorProvider.SetIconPadding($GBComputerName, 10)
    $ErrorProvider.SetIconAlignment($GBComputerName, "MiddleRight")

    if ($TBComputerName.Text.Length -eq 0) 
    {
        $ErrorProvider.SetError($GBComputerName, "Please enter a computer name.")
    }

    elseif ($TBComputerName.Text.Length -gt 15) 
    {
        $ErrorProvider.SetError($GBComputerName, "Computer name cannot be more than 15 characters.")
    }

    elseif ($TBComputerName.Text -eq $serialNumber) 
    {
        $ErrorProvider.SetError($GBComputerName, "Computer name cannot be just the serial number.")
    }

    #Validation Rule for computer names.
    elseif ($TBComputerName.Text -match "^[-_]|[^a-zA-Z0-9-_]")
    {
        $ErrorProvider.SetError($GBComputerName, "Computer name invalid, please correct the computer name.")
    }

    else 
    {
        $OSDComputerName = $TBComputerName.Text.ToUpper()
        $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        $TSEnv.Value("OSDComputerName") = "$($OSDComputerName)"
        $Form.Close()
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
            $data.'Serial Number:' = $wmi.SerialNumber
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

function Clear-OutputBox {
	$OutputBox.ResetText()	
}

function Write-OutputBox {
	param(
	[parameter(Mandatory=$true)]
	[string]$OutputBoxMessage,
	[ValidateSet(" ")]
	[string]$Type,
    [parameter(Mandatory=$true)]
    [ValidateSet("SysInfo")]
    [string]$Object
	)
	Process {
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
 
$Global:ErrorProvider = New-Object System.Windows.Forms.ErrorProvider


$FormWidth = 805
$FormHeight = 530

$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size($FormWidth,$FormHeight)  
$Form.MinimumSize = New-Object System.Drawing.Size($FormWidth,$FormHeight)
$Form.MaximumSize = New-Object System.Drawing.Size($FormWidth,$FormHeight)
$Form.StartPosition = "CenterScreen"
$Form.SizeGripStyle = "Hide"
$Form.Text = "Enter Computer Name"
$Form.ControlBox = $false
$Form.TopMost = $true

#Pictures
$DesktopBase64String = "iVBORw0KGgoAAAANSUhEUgAAANwAAAChCAYAAACs5tGeAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJ
bWFnZVJlYWR5ccllPAAAAw9pVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdp
bj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6
eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNS1jMDE0IDc5LjE1
MTQ4MSwgMjAxMy8wMy8xMy0xMjowOToxNSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJo
dHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlw
dGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEu
MC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVz
b3VyY2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1N
OkRvY3VtZW50SUQ9InhtcC5kaWQ6OEFEODc1QUMyMkVGMTFFNkE1Q0FGRjRCNEVGNTAyNzQiIHht
cE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6OEFEODc1QUIyMkVGMTFFNkE1Q0FGRjRCNEVGNTAyNzQi
IHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIFdpbmRvd3MiPiA8eG1wTU06RGVy
aXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0iQzdBNjM1Qjc3QUFBNEFGMUFDNjIyRkE0QURDNDFG
OEEiIHN0UmVmOmRvY3VtZW50SUQ9IkM3QTYzNUI3N0FBQTRBRjFBQzYyMkZBNEFEQzQxRjhBIi8+
IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5k
PSJyIj8+NL3INQAAVApJREFUeNrsnXd0Xdd15s9r6CDYADaAnQSrWERSJEX1ZstqsWXHju24yXHJ
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
YII="
$DesktopImageBytes = [Convert]::FromBase64String($DesktopBase64String)
$DesktopMemoryStream = New-Object -TypeName IO.MemoryStream($DesktopImageBytes, 0, $DesktopImageBytes.Length)
$DesktopMemoryStream.Write($DesktopImageBytes, 0, $DesktopImageBytes.Length)
$DesktopImage = [System.Drawing.Image]::FromStream($DesktopMemoryStream, $true)

$LaptopBase64String = "iVBORw0KGgoAAAANSUhEUgAAANwAAAChCAYAAACs5tGeAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJ
bWFnZVJlYWR5ccllPAAAAw9pVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdp
bj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6
eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNS1jMDE0IDc5LjE1
MTQ4MSwgMjAxMy8wMy8xMy0xMjowOToxNSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJo
dHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlw
dGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEu
MC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVz
b3VyY2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1N
OkRvY3VtZW50SUQ9InhtcC5kaWQ6QkQyRThEMjIyMkVGMTFFNjkyQzhBNEU5M0FERkFBODQiIHht
cE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6QkQyRThEMjEyMkVGMTFFNjkyQzhBNEU5M0FERkFBODQi
IHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIFdpbmRvd3MiPiA8eG1wTU06RGVy
aXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0iQzdBNjM1Qjc3QUFBNEFGMUFDNjIyRkE0QURDNDFG
OEEiIHN0UmVmOmRvY3VtZW50SUQ9IkM3QTYzNUI3N0FBQTRBRjFBQzYyMkZBNEFEQzQxRjhBIi8+
IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5k
PSJyIj8++J8qKwAAQGhJREFUeNrsfVmsJsd13qle/u3uy+z7whFlUrIpi9YW2ZbsxDKSGM5iyIAh
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"
$LaptopImageBytes = [Convert]::FromBase64String($LaptopBase64String)
$LaptopMemoryStream = New-Object -TypeName IO.MemoryStream($LaptopImageBytes, 0, $LaptopImageBytes.Length)
$LaptopMemoryStream.Write($LaptopImageBytes, 0, $LaptopImageBytes.Length)
$LaptopImage = [System.Drawing.Image]::FromStream($LaptopMemoryStream, $true)


$VMBase64String = "iVBORw0KGgoAAAANSUhEUgAAANwAAAChCAYAAACs5tGeAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJ
bWFnZVJlYWR5ccllPAAAAw9pVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdp
bj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6
eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNS1jMDE0IDc5LjE1
MTQ4MSwgMjAxMy8wMy8xMy0xMjowOToxNSAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJo
dHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlw
dGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEu
MC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVz
b3VyY2VSZWYjIiB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1N
OkRvY3VtZW50SUQ9InhtcC5kaWQ6MTREQzU1NjgyMkYwMTFFNkJBMjNEMEYxODJFREZCOTQiIHht
cE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6MTREQzU1NjcyMkYwMTFFNkJBMjNEMEYxODJFREZCOTQi
IHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIFdpbmRvd3MiPiA8eG1wTU06RGVy
aXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0iQzdBNjM1Qjc3QUFBNEFGMUFDNjIyRkE0QURDNDFG
OEEiIHN0UmVmOmRvY3VtZW50SUQ9IkM3QTYzNUI3N0FBQTRBRjFBQzYyMkZBNEFEQzQxRjhBIi8+
IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5k
PSJyIj8+LjFvdQAAF3hJREFUeNrsnVtsFFl6x7+y3W5jg425GDBgzHW4GZjhYs8soySwI8hESKNk
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"
$VMImageBytes = [Convert]::FromBase64String($VMBase64String)
$VMMemoryStream = New-Object -TypeName IO.MemoryStream($VMImageBytes, 0, $VMImageBytes.Length)
$VMMemoryStream.Write($VMImageBytes, 0, $VMImageBytes.Length)
$VMImage = [System.Drawing.Image]::FromStream($VMMemoryStream, $true)

# PictureBoxes
$PBDELLCHASSIS = New-Object -TypeName System.Windows.Forms.PictureBox
$PBDELLCHASSIS.Location = New-Object -TypeName System.Drawing.Size(38,20)
$PBDELLCHASSIS.Size = New-Object -TypeName System.Drawing.Size(220,160)

$LabelManufacturer = New-Object System.Windows.Forms.Label
$LabelManufacturer.Location = New-Object System.Drawing.Size(38,210)
$LabelManufacturer.Size = New-Object System.Drawing.Size(160,15)
$LabelManufacturer.Text = $Manufacturer

$LabelModel = New-Object System.Windows.Forms.Label
$LabelModel.Location = New-Object System.Drawing.Size(38,235)
$LabelModel.Size = New-Object System.Drawing.Size(160,15)
$LabelModel.Text = $Model

$LabelSerial = New-Object System.Windows.Forms.Label
$LabelSerial.Location = New-Object System.Drawing.Size(38,260)
$LabelSerial.Size = New-Object System.Drawing.Size(160,15)
$LabelSerial.Text = $SerialNumber

$GBModel = New-Object System.Windows.Forms.GroupBox
$GBModel.Location = New-Object System.Drawing.Size(20,180) 
$GBModel.Size = New-Object System.Drawing.Size(220,120)
$GBModel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$GBModel.Text = "Model"

$GBSystemInfo = New-Object System.Windows.Forms.GroupBox
$GBSystemInfo.Location = New-Object System.Drawing.Size(20,324) 
$GBSystemInfo.Size = New-Object System.Drawing.Size(220,138)
$GBSystemInfo.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","8.25",[System.Drawing.FontStyle]::Bold)
$GBSystemInfo.Text = "System Information"

$OutputBoxSysInfo = New-Object System.Windows.Forms.RichTextBox 
$OutputBoxSysInfo.Location = New-Object System.Drawing.Size(30,340) 
$OutputBoxSysInfo.Size = New-Object System.Drawing.Size(200,115)
$OutputBoxSysInfo.BackColor = "white"
$OutputBoxSysInfo.ReadOnly = $true
$OutputBoxSysInfo.MultiLine = $True

$TBComputerName = New-Object System.Windows.Forms.TextBox
$TBComputerName.Location = New-Object System.Drawing.Size(310,80)
$TBComputerName.Size = New-Object System.Drawing.Size(390,80)
$TBComputerName.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","18",[System.Drawing.FontStyle]::Bold)
$TBComputerName.TabIndex = "1"
$TBComputerName.Text = Get-OSDComputerName
 
$GBComputerName = New-Object System.Windows.Forms.GroupBox
$GBComputerName.Location = New-Object System.Drawing.Size(290,50)
$GBComputerName.Size = New-Object System.Drawing.Size(440,90)
$GBComputerName.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","10",[System.Drawing.FontStyle]::Bold)
$GBComputerName.Text = "Computer name:"
 
$ButtonOK = New-Object System.Windows.Forms.Button
$ButtonOK.Location = New-Object System.Drawing.Size(655,400)
$ButtonOK.Size = New-Object System.Drawing.Size(100,60)
$ButtonOK.Font = New-Object System.Drawing.Font("Microsoft Sans Serif","10",[System.Drawing.FontStyle]::Bold)
$ButtonOK.Text = "Set"
$ButtonOK.TabIndex = "2"
$ButtonOK.Add_Click({Set-OSDComputerName})

$Form.KeyPreview = $True
$Form.Add_KeyDown({if ($_.KeyCode -eq "Enter"){Set-OSDComputerName}})

Load-Form
