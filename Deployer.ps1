<#
.INFO
    Script Name: Deployer.ps1
    Description: Automatic Azure infrastructure deployer
    
.NOTES
    File Name      : Deployer.ps1
    Author         : MarcoColomb0 @ github.com/MarcoColomb0
    Prerequisite   : PowerShell and an Azure account (with an active subscription) :)  
#>

function AdministratorCheck {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Host "[INFO] Script is being run as administrator."
    }
    else {
        Write-Host "[ERROR] Please run this script with administrator privileges." -ForegroundColor Red
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
            Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
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
        Write-Host "[INFO] The $($azSubName) is currently selected on the Az module."

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


AdministratorCheck
AzModuleCheck
AccountCheck
SubscriptionCheck