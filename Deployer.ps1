<#
.INFO
    Script Name: Deployer.ps1
    Description: Automatic Azure infrastructure deployer
    
.NOTES
    File Name      : Deployer.ps1
    Author         : MarcoColomb0
    Prerequisite   : PowerShell, Az module and an Azure subscription :)  
#>

## Infrastructure parameters
# Generic parameters
$LocationName = 'westeurope'

# Resource group
$ResourceGroupName = 'AzurePSDeployer-rg'

# Virtual machine
$VMName = 'AzurePSDeployer-vm'
$ComputerName = 'AzurePSDeployer-vm'
$VMSize = 'Standard_B2ms'
$ShutdownTime = '14:15'
$Timezone = 'Central European Time'
$ImagePublisher = 'MicrosoftWindowsDesktop'
$ImageOffer = 'Windows-11'
$ImageSKU = 'win11-23h2-pro'

# Network
$VNetName = 'AzurePSDeployer-vnet'
$NICName = 'AzurePSDeployer-nic'
$SubnetName = 'AzurePSDeployer-snet'
$NSGName = 'AzurePSDeployer-nsg'
$PublicIPAddressName = 'AzurePSDeployer-pip'
$SubnetAddressPrefix = '192.168.77.0/24'
$VNetAddressPrefix = '192.168.0.0/16'
$DNSNameLabel = 'apsdvm'

function AdministratorCheck {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Host "[INFO] Script is being run as administrator."
    }
    else {
        Write-Host "[ERROR] Please run this script with administrator privileges but do not blindly trust!" -ForegroundColor Red 
        Write-Host "The source code is available at https://github.com/MarcoColomb0/AzurePSDeployer" -ForegroundColor Red
        exit
    } 
}

function AzModuleCheck {
    $azModuleInstalled = Get-Module -Name Az* -ListAvailable
    if ($azModuleInstalled) {
        Write-Host "[INFO] Az module found."
    }
    else {
        Write-Host "[ERROR] Azure PowerShell Az module is not installed." -ForegroundColor Red
    
        $installAzModule = Read-Host "[PROMPT] Do you want to install the Az module now? (Y/N)"
    
        if ($installAzModule -eq 'Y' -or $installAzModule -eq 'Yes') {
            Write-Host "[INFO] Az module is installing..."
                
            Write-Host "[INFO] Az module installed successfully."
        }
        else {
            Write-Host "[INFO] Az module not installed. Exiting script."
            exit
        }
    }
}

function AccountCheck {
    $azLoginCheck = Get-AzContext
    if ($azLoginCheck) {
        Write-Host "[INFO] Az module is logged in to $($azLoginCheck.Account)"
    
        $PromptForAccount = Read-Host "[PROMPT] Do you want to keep using this account? (Y/N)"
    
        if ($PromptForAccount -eq 'Y' -or $PromptForAccount -eq 'Yes') {
            Write-Host "[INFO] Current account: $($azLoginCheck.Account)"
        }
        else {
            Write-Host "[WARNING] You will connect another Azure account to PowerShell." -ForegroundColor Yellow
    
            $PromptForAnotherAccount = Read-Host "[PROMPT] Do you want to continue? (Y/N)"
            if ($PromptForAnotherAccount -eq 'Y' -or $PromptForAnotherAccount -eq 'Yes') {
                try {
                    Write-Host "[INFO] Connecting to another account..."
                    Connect-AzAccount | Out-Null
                }
                catch {
                    Write-Host "[ERROR] An error occurred while connecting to another Azure account: $_" -ForegroundColor Red
                    exit
                }
            }
            else {
                Write-Host "[WARNING] Aborting, going back to the Azure Account Login Check."
                AccountCheck
            }
        }
    }
    else {
        Write-Host "[WARNING] Az module is not logged in"
        Write-Host "[WARNING] You will connect another Azure account to PowerShell." -ForegroundColor Yellow
    
        $PromptForAnotherAccount = Read-Host "[PROMPT] Do you want to continue? (Y/N)"
        if ($PromptForAnotherAccount -eq 'Y' -or $PromptForAnotherAccount -eq 'Yes') {
            try {
                Write-Host "[INFO] Connecting to another account..."
                Connect-AzAccount
            }
            catch {
                Write-Host "[ERROR] An error occurred while connecting to another Azure account: $_" -ForegroundColor Red
                exit
            }
        }
        else {
            Write-Host "[WARNING] Aborting, going back to the Azure Account Login Check."
            AccountCheck
        }
    }
}

function SubscriptionCheck {
    $azSubCheck = Get-AzContext
    $azSubName = $azSubCheck.Subscription.Name
    $azSubList = Get-AzSubscription

    if ($azSubCheck) {
        Write-Host "[INFO] The $($azSubName) subscription is currently selected on the Az module."

        $PromptForSubscription = Read-Host "[PROMPT] Do you want to keep using this subscription? (Y/N)"
    
        if ($PromptForSubscription -eq 'Y' -or $PromptForSubscription -eq 'Yes') {
            Write-Host "[INFO] Current subscription: $($azSubName)"
        }
        else {
            Write-Host "[WARNING] You will switch your current subscription to another." -ForegroundColor Yellow
            Write-Host "[INFO] The subscription selection window is likely in the background. Please ensure to check your taskbar in order to proceed."
            $SelectedSubscription = $azSubList | Out-GridView -PassThru -Title "Subscriptions List"
            
            if ($SelectedSubscription) {
                Write-Host "[INFO] Loading the selected subscription: $($SelectedSubscription.Name)"
                Set-AzContext -Subscription $SelectedSubscription | Out-Null
            }
            else {
                Write-Host "[ERROR] No subscription selected. Exiting..."
                exit
            }
        }
    }
    else {
        Write-Host "[WARNING] There is no subscription selected in the Az module. This is unusual, as Az automatically assigns a random subscription available in your tenant."
        $PromptForSubscriptionNotFound = Read-Host "[PROMPT] Would you like to check the available subscriptions anyway? (Y/N)"
        if ($PromptForSubscriptionNotFound -eq 'Y' -or $PromptForSubscriptionNotFound -eq 'Yes') {
            Write-Host "[WARNING] You will switch your current subscription to another." -ForegroundColor Yellow
            Write-Host "[INFO] The subscription selection window is likely in the background. Please ensure to check your taskbar in order to proceed."
            $SelectedSubscription = $azSubList | Out-GridView -PassThru -Title "Subscriptions List"
            
            if ($SelectedSubscription) {
                Write-Host "[INFO] Loading the selected subscription: $($SelectedSubscription.Name)"
                Set-AzContext -Subscription $SelectedSubscription | Out-Null
            }
            else {
                Write-Host "[ERROR] No subscription selected. Exiting..."
                exit
            }
        }
    } 
}

function CreateResourceGroup {
    # Fix error
    $CheckRG = Get-AzResourceGroup -Name $ResourceGroupName -ProgressAction SilentlyContinue
    if ($CheckRG) {
        Write-Host "[WARNING] Resource group $($ResourceGroupName) was already created, skipping the creation part." -ForegroundColor Yellow
    }
    else {
        New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
    }
}

AdministratorCheck
AzModuleCheck
AccountCheck
SubscriptionCheck
CreateResourceGroup