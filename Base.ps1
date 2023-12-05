$Username='marcocolomb0'
#$Password='12wefojwef!!@' | ConvertTo-SecureString -Force -AsPlainText
$Credential=New-Object PSCredential($username,$password)

#Parametri VM

$LocationName='northeurope'
$ResourceGroupName='PS-MC-rg03'
$ComputerName='PS-MC-vm03'
$VMName='PS-MC-vm03'
$VMSize='Standard_B2ms'

New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName

#Parametri Network

$NetworkName='PS-MC-vnet03'
$NICName='PS-MC-full-nic03'
$SubnetName='PS-MC-subnet03'
$SubnetAddressPrefix='192.168.5.0/24'
$VNetAddressPrefix='192.168.0.0/16'
$PublicIPAddressName='PS-MC-pip03'
$DNSNameLabel='psmcvm03'
$NSGName='PS-MC-nsg03'


##Creazione Risorse Network

#Configurazione\Creazione Subnet
$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix

#Configurazione\Creazione VNET
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet

#Configurazione\Creazione IP Pubblico
$PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -DomainNameLabel $DNSNameLabel -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Static

#Configurazione\Creazione Regola NSG
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNetworkSecurityGroupRuleRDP -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

#Configurazione\Creazione NSG
$NSG = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $LocationName -name $NSGname -SecurityRules $nsgRuleRDP
 
#Configurazione\Creazione NIC
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP[0].Id -NetworkSecurityGroupId $NSG[0].Id

#Configurazione VM
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
 
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent –EnableAutoUpdate
 
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
 
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine –PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine


$PublicIPConnect=Get-AzPublicIpAddress -ResourceGroupName $resourcegroupname -Name $PublicIPAddressName

Write-Host "La macchina $($VMName) è stata creata con successo con l'IP $($PublicIPConnect.IpAddress)" -ForegroundColor Green
$IPString=$PublicIpConnect.IpAddress
Mstsc /v:$IPString
