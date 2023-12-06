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
$ComputerName = 'AzurePSD-vm'
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
$NSGRuleName = 'apsdRDPRule'
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

function PasswordComplexityCheck {
    # Password conditions
    $LengthRequirement = ($Password.Length -ge 8 -and $Password.Length -le 123)
    $UppercaseRequirement = $Password -cmatch "[A-Z]"
    $LowercaseRequirement = $Password -cmatch "[a-z]"
    $NumericDigitRequirement = $Password -cmatch "\d"
    $SpecialCharacterRequirement = $Password -cmatch "[^A-Za-z0-9]"

    # Check if at least 3 requirements are met
    $ComplexityRequirementsMet = @(
        $UppercaseRequirement,
        $LowercaseRequirement,
        $NumericDigitRequirement,
        $SpecialCharacterRequirement
    ) | Where-Object { $_ } | Measure-Object | Where-Object { $_.Count -ge 3 }

    # Check all conditions
    return ($LengthRequirement -and $ComplexityRequirementsMet)
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
    try {
        $CheckRG = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    }
    catch {
        Write-Host "[INFO] The resource group was not found and it's being created."
        New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName | Out-Null
    }
    if ($CheckRG) {
        Write-Host "[WARNING] Resource group $($ResourceGroupName) was already created, skipping the creation part." -ForegroundColor Yellow
    } else {
        Write-Host "[SUCCESS] $($ResourceGroupName) resource group is now available." -ForegroundColor Green
    }
}

function CreateVNetAndSubnet {
    $CheckVNet = Get-AzVirtualNetwork -Name $VNetName
    if ($CheckVNet) { 
        Write-Host "[WARNING] Virtual network $($VNetName) was already created, skipping the creation part." -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] The virtual network and the subnet were not found and are being created."
        $CreatedSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
        New-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VNetAddressPrefix -Subnet $CreatedSubnet | Out-Null
        Write-Host "[SUCCESS] $($VNetName) virtual network and $($SubnetName) subnet are now available." -ForegroundColor Green
    } 
}

function CreatePIP {
    $CheckPIP = Get-AzPublicIpAddress -Name $PublicIPAddressName
    if ($CheckPIP) {
        Write-Host "[WARNING] Public IP address $($PublicIPAddressName) was already created, skipping the creation part." -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] The public IP address was not found and is begin created."
        New-AzPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Static | Out-Null
        Write-Host "[SUCCESS] $($PublicIPAddressName) public IP address is now available." -ForegroundColor Green
    }
}

function CreateNSG {
    $CheckNSG = Get-AzNetworkSecurityGroup -Name $NSGName
    if ($CheckNSG) {
        Write-Host "[WARNING] Network security group $($NSGName) was already created, skipping the creation part." -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] The network security group was not found and is being created."
        $NSGRuleRDP = New-AzNetworkSecurityRuleConfig -Name $NSGRuleName -Description "Deployed with AzurePSDeployer" -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
        New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -name $NSGname -SecurityRules $NSGRuleRDP| Out-Null
        Write-Host "[SUCCESS] $($NSGName) network security group is now available." -ForegroundColor Green
    }
}

function CreateNIC {
    $VNetID = Get-AzVirtualNetwork -Name $VNetName
    $PIPID = Get-AzPublicIpAddress -Name $PublicIPAddressName
    $NSGID = Get-AzNetworkSecurityGroup -Name $NSGName

    $CheckNIC = Get-AzNetworkInterface -Name $NICName

    if ($CheckNIC) {
        Write-Host "[WARNING] Network interface card $($NICName) was already created, skipping the creation part." -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] The network interface card was not found and is being created."
        New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $VNetID.Subnets[0].Id -PublicIpAddressId $PIPID[0].Id -NetworkSecurityGroupId $NSGID[0].Id | Out-Null
        Write-Host "[SUCCESS] $($NICName) network interface card is now available." -ForegroundColor Green
    }
}

function CreateVM {
    $NICID = Get-AzNetworkInterface -Name $NICName
    $CheckVM = Get-AzVM -Name $VMName

    if ($CheckVM) {
        Write-Host "[WARNING] Virtual machine $($VMName) was already created, skipping the creation part." -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] The virtual machine was not found and it's going to be created."
        
        do {
            # Prompt the user for credentials
            $Credentials = Get-Credential -UserName $UsernamePrompt -Message "Enter the credentials for VM remote access"
            
            # Check if the password is valid
            $PasswordValid = PasswordComplexityCheck -Password $Credentials.GetNetworkCredential().Password
            
            if (-not $PasswordValid) {
                Write-Host "Password is not valid. Please ensure it meets the specified requirements."
            }
        } while (-not $PasswordValid)

        Write-Host "[INFO] Virtual machine $($VMName) is being created."
        
        $VMBaseConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize
        $VMBaseConfig = Set-AzVMOperatingSystem -VM $VMBaseConfig -Windows -ComputerName $ComputerName -Credential $Credentials -ProvisionVMAgent -EnableAutoUpdate
        $VMBaseConfig = Add-AzVMNetworkInterface -VM $VMBaseConfig -Id $NICID.Id
        $VMBaseConfig = Set-AzVMSourceImage -VM $VMBaseConfig -PublisherName $ImagePublisher -Offer $ImageOffer -Skus $ImageSKU -Version latest
        New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VMBaseConfig | Out-Null
        # Set-AzScheduledAutoshutdown -ResourceGroupName $ResourceGroupName -VmName $VMName -ShutdownDaily -ShutdownTime $ShutdownTime -TimeZone $Timezone
        Write-Host "[SUCCESS] Virtual machine $($VMName) is now available." -ForegroundColor Green
    }
}

AdministratorCheck
AzModuleCheck
AccountCheck
SubscriptionCheck
CreateResourceGroup
CreateVNetAndSubnet
CreatePIP
CreateNSG
CreateNIC
CreateVM
#InfrastructureSummary
#ConnectWizard