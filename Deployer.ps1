<#
.INFOS
    Script Name: Deployer.ps1
    Description: Automatic Azure infrastructure deployer
    
.NOTES
    File Name      : Deployer.ps1
    Author         : MarcoColomb0
    Prerequisite   : PowerShell, Az module and an Azure subscription :)  
#>

# First Checks
# Check if the script is running with administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "[INFO] Script is being run as administrator."
} else {
    Write-Host "[ERROR] Please run this script with administrator privileges." -ForegroundColor Red
    exit
}

# Check if the Az module is installed
$azModuleInstalled = Get-Module -Name Az* -ListAvailable

if ($azModuleInstalled) {
    Write-Host "[INFO] Az module found."
} else {
    Write-Host "[ERROR] Azure PowerShell Az module is not installed." -ForegroundColor Red

    # Ask the user if they want to install the Az module
    $installAzModule = Read-Host "Do you want to install the Az module now? (Y/N)"

    if ($installAzModule -eq 'Y' -or $installAzModule -eq 'Yes') {
        # Install the Az module
        Write-Host "[INFO] Az module is installing..."
        Install-Module -Name Az -AllowClobber -Scope CurrentUser
        Write-Host "[INFO] Az module installed successfully."
    } else {
        Write-Host "[INFO] Az module not installed. Exiting script."
        exit
    }
}
