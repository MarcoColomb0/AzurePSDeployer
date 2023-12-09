<#
.INFO
    Script Name: AzurePSDeployer.ps1
    Description: Automatic Azure infrastructure deployer
    
.NOTES
    File Name      : AzurePSDeployer.ps1
    Author         : MarcoColomb0
    Repository     : https://github.com/MarcoColomb0/AzurePSDeployer
    Prerequisite   : PowerShell, Az module, and an Azure subscription :)
    Description    : A script that functions as a "launcher" for the deployments stored in the GitHub repository at /deployments 
#>

# Display available services and prompt for user input
Write-Host "You are currently able to deploy these services"
Write-Host "1. WindowsClient"
Write-Host "2. UbuntuServer"
Write-Host "3. WindowsServer"

$DeploymentPrompt = Read-Host "Enter the number corresponding to the service you want to deploy."

# Process user input and deploy the selected service
switch ($DeploymentPrompt) {
    "1" {
        $DeploymentType = "WindowsClient"
    }
    "2" {
        $DeploymentType = "UbuntuServer"
    }
    "3" {
        $DeploymentType = "WindowsServer"
    }
    default {
        Write-Host "Invalid selection. Exiting script."
        exit
    }
}

# Build the script URL and deploy the selected service
$ScriptURL = "https://github.com/MarcoColomb0/AzurePSDeployer/raw/main/deployments/$DeploymentType"
Invoke-WebRequest -Uri $ScriptURL | Invoke-Expression
