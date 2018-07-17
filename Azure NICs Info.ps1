$FilePath = Read-Host "Please specify a path for the generated report"
Get-AzureRmNetworkInterface | Select Name, ResourceGroupName, Location,`
 @{Name="VMName";Expression = {$_.VirtualMachine.Id.tostring().substring($_.VirtualMachine.Id.tostring().lastindexof('/')+1)}},`
 @{Name="NSG";Expression = {$_.NetworkSecurityGroup.Id.tostring().substring($_.NetworkSecurityGroup.Id.tostring().lastindexof('/')+1)}},`
 @{Name="SubnetName";Expression = {$_.IpConfigurations.subnet.id.tostring().substring($_.IpConfigurations.subnet.id.tostring().lastindexof('/')+1)}}`
 | Export-Csv "$FilePath\NICs Properties.csv"