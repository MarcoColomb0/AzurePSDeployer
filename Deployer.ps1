<#
.INFO
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
function AdministratorCheck {
    if ($isAdmin) {
        Write-Host "[INFO] Script is being run as administrator."
    } else {
        Write-Host "[ERROR] Please run this script with administrator privileges." -ForegroundColor Red
        exit
    } 
}

# Check if the Az module is installed
$azModuleInstalled = Get-Module -Name Az* -ListAvailable
function AzModuleCheck {
    if ($azModuleInstalled) {
        Write-Host "[INFO] Az module found."
    } else {
        Write-Host "[ERROR] Azure PowerShell Az module is not installed." -ForegroundColor Red
    
        # Ask the user if they want to install the Az module
        $installAzModule = Read-Host "[PROMPT] Do you want to install the Az module now? (Y/N)"
    
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
}

# Check if user is logged in to Azure
$azSubCheck = Get-AzContext
function AccountChecks {
    if ($azSubCheck) {
        Write-Host "[INFO] Az module is logged in to $($azSubCheck.Account)"
    
        $PromptForAccount = Read-Host "[PROMPT] Do you want to keep using this account? (Y/N)"
    
        if ($PromptForAccount -eq 'Y' -or $PromptForAccount -eq 'Yes') {
            Write-Host "[INFO] Current account: $($azSubCheck.Account)"
        } else {
            Write-Host "[WARNING] You will connect another Azure account to PowerShell." -ForegroundColor Yellow
    
            $PromptForAnotherAccount = Read-Host "[PROMPT] Do you want to continue? (Y/N)"
            if ($PromptForAnotherAccount -eq 'Y' -or $PromptForAnotherAccount -eq 'Yes') {
                try {
                    Write-Host "[INFO] Connecting to another account..."
                    Connect-AzAccount
                } catch {
                    Write-Host "[ERROR] An error occurred while connecting to another Azure account: $_" -ForegroundColor Red
                    exit
                }
            } else {
                Write-Host "[WARNING] Aborting, going back to the Azure Account Login Check."
                AccountChecks
            }
        }
    } else {
        Write-Host "[WARNING] Az module is not logged in"
        Write-Host "[WARNING] You will connect another Azure account to PowerShell." -ForegroundColor Yellow
    
            $PromptForAnotherAccount = Read-Host "[PROMPT] Do you want to continue? (Y/N)"
            if ($PromptForAnotherAccount -eq 'Y' -or $PromptForAnotherAccount -eq 'Yes') {
                try {
                    Write-Host "[INFO] Connecting to another account..."
                    Connect-AzAccount
                } catch {
                    Write-Host "[ERROR] An error occurred while connecting to another Azure account: $_" -ForegroundColor Red
                    exit
                }
            } else {
                Write-Host "[WARNING] Aborting, going back to the Azure Account Login Check."
                AccountChecks
            }
    }
}


AdministratorCheck
AzModuleCheck
AccountChecks