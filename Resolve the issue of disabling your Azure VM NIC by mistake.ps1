Login-AzureRmAccount
$RGName=Read-Host "Please Enter the Resource Group Name"
$Loc=Read-Host "Please Enter the Resources Location"
$VM=Read-Host "Please Enter the Virtual Machine Name"
$vNet=Read-Host "Please Enter the Virtual Network Name"
$Subnet=Read-Host "Please Enter the Subnet Name"
$NIC=Read-Host "Please Enter the New NIC Name"
$OldNIC=Read-Host "Please Enter the Old NIC Name"
$NSG=Read-Host "Please Enter the Network Security Group Name"
$OldPIP = Read-Host "Please Enter the Old Public IP Name"
$PIP=Read-Host "Please Enter the New Public IP Name"
$RGName=Get-AzureRmResourceGroup | ?{$_.ResourceGroupName -eq $RGName}
$VM=Get-AzureRmVM | ?{$_.Name -eq $VM}
$vnet=Get-AzureRmVirtualNetwork | ?{$_.Name -eq $vnet}
$subnet=$vnet.Subnets | ?{$_.Name -eq $Subnet}
$NIC= New-AzureRmNetworkInterface -ResourceGroupName $RGName.ResourceGroupName -Location $Loc -Name $NIC -SubnetId $Subnet.id
$NSG= Get-AzureRmNetworkSecurityGroup | ?{$_.Name -eq $NSG}
$NIC.NetworkSecurityGroup =$nsg
Set-AzureRmNetworkInterface -NetworkInterface $NIC
Stop-AzureRmVM -Name $vm.Name -ResourceGroupName $RGName.ResourceGroupName -Force
$OldNICID= (Get-AzureRmNetworkInterface | ?{$_.Name -eq $OldNIC}).Id
$NewNICID= Get-AzureRmNetworkInterface | ?{$_.Id -eq $NIC.Id}
Add-AzureRmVMNetworkInterface -VM $VM -Id $NewNICID.Id -Primary | Update-AzureRmVm -ResourceGroupName $RGName.ResourceGroupName
Remove-AzureRmVMNetworkInterface -VM $vm -NetworkInterfaceIDs $OldNICID | Update-AzureRmVm -ResourceGroupName $RGName.ResourceGroupName
$pip = New-AzureRmPublicIpAddress -Name $PIP -ResourceGroupName $RGName.ResourceGroupName -Location $Loc -AllocationMethod Dynamic -Force
$NIC.IpConfigurations[0].PublicIpAddress = $pip
Set-AzureRmNetworkInterface -NetworkInterface $NIC
Start-AzureRmVM -Name $vm.Name -ResourceGroupName $RGName.ResourceGroupName
Remove-AzureRmNetworkInterface -Name $OldNIC -ResourceGroupName $RGName.ResourceGroupName -Force
Remove-AzureRmPublicIpAddress -Name $OldPIP -ResourceGroupName $RGName.ResourceGroupName -Force
$NICInfo= Get-AzureRmNetworkInterface -Name $NIC.Name -ResourceGroupName $RGName.ResourceGroupName
$NICInfo.IpConfigurations | Format-Table Name,PrivateIPAddress,PublicIPAddress,Primary