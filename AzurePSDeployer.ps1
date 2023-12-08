<#
.INFO
    Script Name: AzurePSDeployer.ps1
    Description: Automatic Azure infrastructure deployer (Main script)
    
.NOTES
    File Name      : windowsclient.ps1
    Author         : MarcoColomb0
    Prerequisite   : PowerShell, Az module and an Azure subscription :)
    Description    : This serves as the 'launcher' for all deployments located in the subdirectory '/deployments,' which can be initiated directly by cloning or downloading the source code.
#>

param (
    [string]$Deploy
)

function Invoke-DeploymentScript {
    param (
        [string]$ScriptName
    )

    $GitHubRepo = "https://github.com/MarcoColomb0/AzurePSDeployer"
    $ScriptPath = "deployments/$ScriptName.ps1"
    $ScriptURL = "$GitHubRepo/raw/main/$ScriptPath"

    $ScriptContent = Invoke-WebRequest -Uri $ScriptURL -UseBasicParsing

    if ($ScriptContent.StatusCode -eq 200) {
        Invoke-Expression $ScriptContent.Content
    } else {
        Write-Host "Unable to find $ScriptName on the GitHub repository."
    }
}

# List of arguments to execute a specific deployment type
switch ($Deploy) {
    "WindowsClient" { Invoke-DeploymentScript -ScriptName "WindowsClient" }
    "UbuntuServer" { Invoke-DeploymentScript -ScriptName "UbuntuServer" }
    "WindowsServer" { Invoke-DeploymentScript -ScriptName "WindowsServer" }
    default { Write-Host "Invalid option. Use -Deploy with WindowsClient, UbuntuServer, or WindowsServer." }
}
