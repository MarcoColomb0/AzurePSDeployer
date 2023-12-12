<#
.INFO
    Script Name: ws-2022.ps1
    Description: Automatic Azure infrastructure deployer (Windows Server)
    
.NOTES
    File Name      : ws-2022.ps1
    Author         : MarcoColomb0
    Prerequisite   : PowerShell, Az module and an Azure subscription :)  
#>

## Infrastructure parameters
# Generic parameters
$GenericName = Read-Host "[PROMPT] Choose a generic name for the resources (for example: APSD-Infra)"
$LocationName = 'westeurope' # Get-AzLocation | ft

# Resource group
$ResourceGroupName = "$($GenericName)-rg"

# Windows Client virtual machine
$VMName = "$($GenericName)-vm"
$CleanedCN = $GenericName -replace '[^a-z]'
$ComputerName = $CleanedCN.Substring(0, [System.Math]::Min(15, $CleanedCN.Length))
$VMSize = 'Standard_B2ms' # Get-AzVMSize -Location (location) | ft
$ImagePublisher = 'MicrosoftWindowsServer' # Get-AzImagePublisher
$ImageOffer = 'WindowsServer' # Get-AzVMImageOffer
$ImageSKU = '2022-datacenter' # Get-AzVMImageSku

# Network
$VNetName = "$($GenericName)-vnet"
$NICName = "$($GenericName)-nic"
$SubnetName = "$($GenericName)-snet"
$NSGName = "$($GenericName)-nsg"
$NSGRuleName = 'apsdRDPRule'
$PublicIPAddressName = "$($GenericName)-pip"
$SubnetAddressPrefix = '192.168.77.0/24'
$VNetAddressPrefix = '192.168.0.0/16'

# Generate DNS name
# Parse it and make it lowercase
$LowercaseDNS = $GenericName.ToLower()
$CleanedDNS = $LowercaseDNS -replace '[^a-z]'

# Assign the string to the variable and limit to 14 chars
$DNSNameLabel = $CleanedDNS.Substring(0, [System.Math]::Min(14, $CleanedDNS.Length))

# Logs
$LogsDate = Get-Date -format dd-MM-yyyy
$LogsPath = "$ENV:TEMP\$VMName-$LogsDate.log"
Start-Transcript $LogsPath -Append | Out-Null

# Checks for the presence of the Az module on the local machine; if not found, prompts for installation
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
            Install-Module -Name Az -Repository PSGallery -Force | Out-Null     
            Write-Host "[INFO] Az module installed successfully."
        }
        else {
            Write-Host "[INFO] Az module not installed. Exiting script."
            exit
        }
    }
}

# Checks for already linked Azure accounts to the Az module and if not present runs "Connect-AzAccount"
function AccountCheck {
    $global:azLoginCheck = Get-AzContext
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

# Checks for subscriptions linked to the account. If no subscriptions are available, the process terminates. If multiple subscriptions are linked to the account in use, prompts the user to choose one.
function SubscriptionCheck {
    $global:azSubCheck = Get-AzContext
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

# Checks for a Resource Group with matching name and if not present it creates it
function CreateResourceGroup {
    if ($CheckRG) {
        Write-Host "[WARNING] Resource group $($ResourceGroupName) was already created, skipping the creation part." -ForegroundColor Yellow 
    }
    else {
        try {
            $CheckRG = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        }
        catch {
            Write-Host "[INFO] The resource group was not found and it's being created."
            New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName | Out-Null
        }
        Write-Host "[INFO] Checking if the RG is ready..."
        $Timeout = 90  # Maximum time to wait in seconds
        $StartTime = Get-Date

        while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
            $CheckRG = Get-AzResourceGroup -Name $ResourceGroupName
            if ($CheckRG.ProvisioningState -eq "Succeeded") {
                Write-Host "[SUCCESS] RG $($ResourceGroupName) is now available." -ForegroundColor Green
                return
            }
            elseif ($CheckVM.ProvisioningState -eq "Failed") {
                Write-Host "[ERROR] RG $($ResourceGroupName)) creation failed." -ForegroundColor Red
                return
            }

            Start-Sleep -Seconds 5
        }

        Write-Host "[ERROR] Maximum time exceeded. RG $($ResourceGroupName) creation check timed out." -ForegroundColor Red
    }
}

# Checks for VNet or Subnet with matching names and if not present it creates them
function CreateVNetAndSubnet {
    $CheckVNet = Get-AzVirtualNetwork -Name $VNetName
    if ($CheckVNet) { 
        Write-Host "[WARNING] Virtual network $($VNetName) was already created, skipping the creation part." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] The virtual network and the subnet were not found and are being created."
        $CreatedSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
        New-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VNetAddressPrefix -Subnet $CreatedSubnet | Out-Null
        Write-Host "[INFO] Checking if the VNet is ready..."
        $Timeout = 90  # Maximum time to wait in seconds
        $StartTime = Get-Date

        while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
            $CheckVNet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName
            if ($CheckVNet.ProvisioningState -eq "Succeeded") {
                Write-Host "[SUCCESS] VNet $($VNetName) and $($SubnetName) are now available." -ForegroundColor Green
                return
            }
            elseif ($CheckVNet.ProvisioningState -eq "Failed") {
                Write-Host "[ERROR] VNet $($VNetName)) creation failed." -ForegroundColor Red
                return
            }

            Start-Sleep -Seconds 5
        }

        Write-Host "[ERROR] Maximum time exceeded. VNet $($VNetName) creation check timed out." -ForegroundColor Red
    } 
}

# Checks for Public IP with matching name and if not present it creates it
function CreatePIP {
    $CheckPIP = Get-AzPublicIpAddress -Name $PublicIPAddressName
    if ($CheckPIP) {
        Write-Host "[WARNING] Public IP address $($PublicIPAddressName) was already created, skipping the creation part." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] The public IP address was not found and is being created."
        New-AzPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Static | Out-Null
        Write-Host "[INFO] Checking if the PIP is ready..."
        $Timeout = 90  # Maximum time to wait in seconds
        $StartTime = Get-Date

        while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
            $CheckPIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIPAddressName
            if ($CheckPIP.ProvisioningState -eq "Succeeded") {
                Write-Host "[SUCCESS] PIP $($PublicIPAddressName) is now available." -ForegroundColor Green
                return
            }
            elseif ($CheckPIP.ProvisioningState -eq "Failed") {
                Write-Host "[ERROR] PIP $($PublicIPAddressName)) creation failed." -ForegroundColor Red
                return
            }

            Start-Sleep -Seconds 5
        }

        Write-Host "[ERROR] Maximum time exceeded. PIP $($PublicIPAddressName) creation check timed out." -ForegroundColor Red
    }
}

# Checks for NSG with matching name and if not present it creates it and adds a rule
function CreateNSG {
    $CheckNSG = Get-AzNetworkSecurityGroup -Name $NSGName
    if ($CheckNSG) {
        Write-Host "[WARNING] Network security group $($NSGName) was already created, skipping the creation part." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] The network security group was not found and is being created."
        $NSGRuleRDP = New-AzNetworkSecurityRuleConfig -Name $NSGRuleName -Description "Deployed with AzurePSDeployer" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
        New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -name $NSGname -SecurityRules $NSGRuleRDP | Out-Null

        Write-Host "[INFO] Checking if the NSG is ready..."
        $Timeout = 90  # Maximum time to wait in seconds
        $StartTime = Get-Date

        while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
            $CheckNSG = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NSGName
            if ($CheckNSG.ProvisioningState -eq "Succeeded") {
                Write-Host "[SUCCESS] NSG $($NSGName) is now available." -ForegroundColor Green
                return
            }
            elseif ($CheckNSG.ProvisioningState -eq "Failed") {
                Write-Host "[ERROR] NSG $($NSGName) creation failed." -ForegroundColor Red
                return
            }

            Start-Sleep -Seconds 5
        }

        Write-Host "[ERROR] Maximum time exceeded. NSG $($NSGName) creation check timed out." -ForegroundColor Red
    }
}

# Checks for NIC with matching name and if not present it creates it
function CreateNIC {
    $VNetID = Get-AzVirtualNetwork -Name $VNetName
    $PIPID = Get-AzPublicIpAddress -Name $PublicIPAddressName
    $NSGID = Get-AzNetworkSecurityGroup -Name $NSGName

    $CheckNIC = Get-AzNetworkInterface -Name $NICName

    if ($CheckNIC) {
        Write-Host "[WARNING] Network interface card $($NICName) was already created, skipping the creation part." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] The network interface card was not found and is being created."
        New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $VNetID.Subnets[0].Id -PublicIpAddressId $PIPID[0].Id -NetworkSecurityGroupId $NSGID[0].Id | Out-Null

        Write-Host "[INFO] Checking if the NIC is ready..."
        $Timeout = 90  # Maximum time to wait in seconds
        $StartTime = Get-Date

        while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
            $CheckNIC = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NICName
            if ($CheckNIC.ProvisioningState -eq "Succeeded") {
                Write-Host "[SUCCESS] NIC $($NICName) is now available." -ForegroundColor Green
                return
            }
            elseif ($CheckNIC.ProvisioningState -eq "Failed") {
                Write-Host "[ERROR] NIC $($NICName) creation failed." -ForegroundColor Red
                return
            }

            Start-Sleep -Seconds 5
        }

        Write-Host "[ERROR] Maximum time exceeded. NIC $($NICName) creation check timed out." -ForegroundColor Red
    }
}

# Checks for VM with matching name and creates it with properties that were defined earlier
function CreateVM {
    $NICID = Get-AzNetworkInterface -Name $NICName
    $CheckVM = Get-AzVM -Name $VMName

    if ($CheckVM) {
        Write-Host "[WARNING] Virtual machine $($VMName) was already created, skipping the creation part." -ForegroundColor Yellow
    }
    else {
        # Disable unnecessary cost optimizations suggestions
        Update-AzConfig -DisplayRegionIdentified $false | Out-Null
        Write-Host "[INFO] The virtual machine was not found and it's going to be created."
        Write-Host "[INFO] The credentials selection window is likely in the background. Please ensure to check your taskbar in order to proceed."
        $global:Credentials = Get-Credential -Message "Enter the credentials for VM remote access"
        Write-Host "[INFO] Virtual machine $($VMName) is being created (this may take a while)."
        $VMBaseConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize
        $VMBaseConfig = Set-AzVMOperatingSystem -VM $VMBaseConfig -Windows -ComputerName $ComputerName -Credential $Credentials -ProvisionVMAgent -EnableAutoUpdate
        $VMBaseConfig = Add-AzVMNetworkInterface -VM $VMBaseConfig -Id $NICID.Id
        $VMBaseConfig = Set-AzVMSourceImage -VM $VMBaseConfig -PublisherName $ImagePublisher -Offer $ImageOffer -Skus $ImageSKU -Version latest
        # Disable Boot Diagnostics to prevent unnecessary storage account creation
        $VMBaseConfig = Set-AzVMBootDiagnostic -VM $VMBaseConfig -Disable
        New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VMBaseConfig | Out-Null

        Write-Host "[INFO] Checking if the VM is ready..."
        $Timeout = 90  # Maximum time to wait in seconds
        $StartTime = Get-Date

        while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
            $CheckVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
            if ($CheckVM.ProvisioningState -eq "Succeeded") {
                Write-Host "[SUCCESS] Virtual machine $($VMName) is now available." -ForegroundColor Green
                return
            }
            elseif ($CheckVM.ProvisioningState -eq "Failed") {
                Write-Host "[ERROR] Virtual machine $($VMName) creation failed." -ForegroundColor Red
                return
            }

            Start-Sleep -Seconds 5
        }

        Write-Host "[ERROR] Maximum time exceeded. Virtual machine $($VMName) creation check timed out." -ForegroundColor Red
    }
}

# Prints a summary of the provisioned resources and builds the DNS name (that is not obtainable in the same shell due to Az module limitations)
function InfrastructureSummary {
    Write-Host "[SUCCESS] The tool has finished setting up your Azure infrastructure" -ForegroundColor Green
    Write-Host "Final infrastructure summary" -ForegroundColor Green
    Write-Host "Account: $($global:azLoginCheck.Account)"
    Write-Host "Subscription: $($global:azSubCheck.Subscription.Name)"
    Write-Host "Location: $($LocationName)"
    Write-Host "Resource group: $($ResourceGroupName)"
    Write-Host "Virtual network: $($VNetName)"
    Write-Host "Public IP: $($PublicIPAddressName)"
    Write-Host "NSG: $($NSGName) with rule $($NSGRuleName)"
    Write-Host "NIC: $($NICName)"
    Write-Host "VM: $($VMName)"
    Write-Host "DNS name: $($DNSNameLabel).$($LocationName).cloudapp.azure.com"
}

# Prompts the user for connection and if the user accepts it builds an RDP file and execute it through "mstsc.exe"
function ConnectWizard {
    $RDPAddress = "$($DNSNameLabel).$($LocationName).cloudapp.azure.com"
    $RDPUsername = $global:Credentials.Username
    $PromptForConnection = Read-Host "[PROMPT] Do you want to connect via RDP to $($VMName)? (Y/N)"

    if ($PromptForConnection -eq 'Y' -or $PromptForConnection -eq 'Yes') {
        Write-Host "[INFO] Connection is preparing..."
    
        # RDP file content
        $RDPContent = @"
full address:s:$RDPAddress
username:s:$RDPUsername
"@
    
        # RDP file path (temp)
        $RDPPath = "$($ENV:TEMP)\$($VMName).rdp"
    
        # Scrivi il contenuto nel file RDP
        $RDPContent | Out-File -FilePath $RDPPath -Force
    
        # Apri il file RDP con il programma predefinito
        Start-Process -FilePath mstsc.exe $RDPPath
        Write-Host "[SUCCESS] RDP connection has been successfully established."
    } 
    Write-Host "Thank you for using this script!" -ForegroundColor Green
    Write-Host "Give the repository a star if you like the project at https://github.com/MarcoColomb0/AzurePSDeployer" -ForegroundColor Gray
    Write-Host "Report bugs at https://github.com/MarcoColomb0/AzurePSDeployer/issues" -ForegroundColor Gray
}



# Functions execution
AzModuleCheck
AccountCheck
SubscriptionCheck
CreateResourceGroup
CreateVNetAndSubnet
CreatePIP
CreateNSG
CreateNIC
CreateVM
InfrastructureSummary
ConnectWizard