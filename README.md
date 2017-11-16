# OSD
Powershell scripts is designed to validate and change Dell BIOS security features:
  - Supported Model check (XML configurable)
  - BIOS revision check (XML configurable)
  - Operating System Check (PE supported)
  - UEFI Check
  - BIOS Password Known (XML Configurable - encrypted)
  - TPM exists
  - TPM enabled
  - TPM Activated
  - Virtualization Support
  - Virtualization Direct I/O
  - Virtualizations Execution
  - Legacy ROM disabled
  - Secure Boot Enabled

Powershell present a Windows Form UI with logging. Script was designed to be ran on WinPE bootup before the OSD TaskSequence, but could also be ran on the desktop.

Requires powershell feature added to WinPE. 
