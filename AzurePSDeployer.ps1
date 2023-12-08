<#
.INFO
    Script Name: windowsclient.ps1
    Description: Automatic Azure infrastructure deployer
    
.NOTES
    File Name      : windowsclient.ps1
    Author         : MarcoColomb0
    Prerequisite   : PowerShell, Az module and an Azure subscription :)  
#>


Write-Host = "You are currently able to deploy these services:"
Write-Host = ""
$DeploymentPrompt = Read-Host "What service would you like to automatically deploy?"
switch ($DeploymentPrompt){
    "WindowsClient" {
        
    }
}

$ScriptURL = https://github.com/MarcoColomb0/AzurePSDeployer/raw/main/deployments/$DeploymentType