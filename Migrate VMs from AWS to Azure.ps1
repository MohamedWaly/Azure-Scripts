##Download and Install AzureRM PowerShell Module"
Install-PackageProvider -Name NuGet -Force
Install-Module AzureRM -Force

#Login to your Azure Subscription
Login-AzureRmAccount

#The Resource Group within which the VM, Storage Account, VNet will be uploaded to
$RGName = Read-Host "Please Enter the Resource Group Name"
$RG = Get-AzureRmResourceGroup -Name $RGName

#The Path to which Disk2VHD tool will be downloaded to
$Path = Read-Host "Please Enter a Path to Download Disk2VHD to"
if (!(Test-Path -path $Path)) 
 { 
 New-Item $Path -type directory
 Write-Host "A New Directory with the following path has been created`
  $path" -ForegroundColor Green
 } 
$object = New-Object Net.WebClient 
$Disk2VHDURL = 'https://download.sysinternals.com/files/Disk2vhd.zip' 
$object.DownloadFile($Disk2VHDURL, "$Path\Disk2vhd.zip")
Write-Host "Disk2VHD tool has been downloaded to the following path`
$Path" -ForegroundColor Green

#Funtion to Unzip the Disk2VHD tool
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Unzip "$Path\Disk2vhd.zip" $Path
Write-Host "Disk2VHD has been unzipped" -ForegroundColor Green
cd $Path

#The Path of the converted VHD
$VHDPath = Read-Host "Please Enter the path to which the VM will be converted to VHD File"
if (!(Test-Path -path "$VHDPath")) 
 { 
 New-Item "$VHDPath" -type directory
 Write-Host "A New Directory with the following Path has been created to store the converted VMs`
 $VHDPath" -ForegroundColor Green
 }

 #The Drives you desire to convert
$Drives = Read-Host "Please Specify the drives to be converted in the following format:`
                     C: D: E: and so on"

#Starting the conversion
Write-Host "Disk2VHD is converting the following Drives $Drives" -ForegroundColor Green
$cmd  = @"
"$ScriptDir.\disk2vhd.exe" $Drives $VHDPath\$env:computername.vhd /accepteula
"@
& cmd.exe /c $cmd

#Specify Whether there is a Storage Account to Upload your VM to or not!
$a = new-object -comobject wscript.shell
$SAAnswer = $a.popup("Do you have a stroage account to upload the VM to?",0,"Storage Account Existence",4)

#If you do not have a storage account, you will be asked to enter a name for the storage account and select the SKU of the storage account
If ($SAAnswer -ne 6) 
        {
            Do {
                $SAName = Read-Host "Please Enter a name tha achieves the following conditions:`
                                     1- The name must be unique across all the storage account names in Azure`
                                     2- It must be 3 to 24 characters long`
                                     3- It can only contains lower case charchters and number`
                                     "
                $SAAvail = (Get-AzureRmStorageAccountNameAvailability -Name $SAName).NameAvailable
                }
            Until ($SAAvail -eq "True")
                #A Menu to Select the Storage Account SKU from
                $Menu = [ordered]@{
                    1 = 'Premium_LRS'
                    2 = 'Standard_GRS'
                    3 = 'Standard_LRS'
                    4 = 'Standard_RAGRS'
                    5 = 'Standard_ZRS'
                }

                $Result = $Menu | Out-GridView -PassThru  -Title 'Select the Storage SKU'

                Switch ($Result)  {

                {$Result.Name -eq 1} {'Premium_LRS'}
                {$Result.Name -eq 2} {'Standard_GRS'}
                {$Result.Name -eq 3} {'Standard_LRS'}
                {$Result.Name -eq 3} {'Standard_RAGRS'}
                {$Result.Name -eq 3} {'Standard_ZRS'}      
                                   }
            $SA = New-AzureRmStorageAccount -ResourceGroupName $RG.ResourceGroupName -Name $SAName -SkuName $Result.Value -Location $RG.Location
            Write-Host "A new Storage Account named $SAName has been created" -ForegroundColor Green
        }

#If you have a storage account, you only have to enter its name
ElseIf ($SAAnswer -eq 6)
        {
                $SAName = Read-Host "Please Enter the Storage Account Name"
                $SA = Get-AzureRmStorageAccount -Name $SAName -ResourceGroupName $RG.ResourceGroupName       
        }

#Creating a Container to which the VHD will be uploaded to
$SAKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $RG.ResourceGroupName -Name $SA.StorageAccountName) | ? {$_.KeyName -eq "key1"}
$StorageContext = New-AzureStorageContext -StorageAccountName $SAName -StorageAccountKey $SAKey.Value
$ContainerName = "migartedvhds"
$ContainerName = New-AzureStorageContainer -Name $ContainerName -Permission Blob -Context $StorageContext
Write-Host "A New container called $ContainerName has been created to store the uploaded VHD" -ForegroundColor Green

#Upload the VHD to Azure
$urlOfUploadedImageVhd = ('https://' + $Sa.StorageAccountName + '.blob.core.windows.net/' + $ContainerName.Name + '/' + $env:computername)
$localpath = "$VHDPath\$env:computername.vhd"
Add-AzureRmVhd -ResourceGroupName $RG.ResourceGroupName -Destination $urlOfUploadedImageVhd -LocalFilePath $localpath
Write-Host " The VHD has been uploaded to Azure Storage with the following URL:`
              $urlOfUploadedImageVhd" -ForegroundColor Green

#Create OS Disk for the VM
Write-Host "Creating the OS disk" -ForegroundColor Green
$osDiskName = $env:computername
$osDisk = New-AzureRmDisk -DiskName $osDiskName -Disk (New-AzureRmDiskConfig -AccountType $Result.Value `
    -Location $RG.Location -CreateOption Import -SourceUri $urlOfUploadedImageVhd) -ResourceGroupName $RG.ResourceGroupName

#Specify Whether there is a Virtual Network and a Subnet to Upload your VM to or not!
$SubAnswer = $a.popup("Do you have a Virtual Network and a Subnet to assign the VM to?",0,"Networking",4)

#If you do not have a Virtual Network and a Subnet, you need to define a name and prefix for the virtual network and the subnet
If ($SubAnswer -ne 6) 
        {
            $subnetName = Read-Host "Please Enter a name for the subnet"
            $SubAddressPrefix = Read-Host "Please Enter an address prefix for the subnet"
            $Subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $SubAddressPrefix
            Write-Host "The $subnetName subnet has been created" -ForegroundColor Green
            $vnetName = Read-Host "Please Enter a name for the virtual network"
            $vnetPrefix = Read-Host "Please Enter an address prefix for the virtual network"
            $vnet = New-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $RG.ResourceGroupName -Location $RG.Location `
                    -AddressPrefix $vnetPrefix -Subnet $Subnet
            $Subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $VNet
            Write-Host "The $vnetName Virtual Network has been created" -ForegroundColor Green
            
        }

#If you have a Subnet and a Virtual Network, you need to enter their names
ElseIf ($SubAnswer -eq 6)
        {
            $vnetName = Read-Host "Please Enter a name for the virtual network"
            $subnetName = Read-Host "Please Enter a name of the subnet"
            $VNet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $RG.ResourceGroupName        
            $Subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $VNet
        }

#Create an NSG for the VM that allow RDP access
Write-Host "Creating a Network Security Group that enables RDP has been created for the VM" -ForegroundColor Green
$nsgName = "NSG"
$rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name RDPRule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
    -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RG.ResourceGroupName -Location $RG.Location `
   -Name $nsgName -SecurityRules $rdpRule


# Create a NIC with a Public IP for the VM
Write-Host "Creating a Network Interface Card for the VM" -ForegroundColor Green
$ipName = "PIP"
$pip = New-AzureRmPublicIpAddress -Name $ipName -ResourceGroupName $RG.ResourceGroupName -Location $RG.Location `
       -AllocationMethod Static

$nicName = "NIC"
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $RG.ResourceGroupName -Location $RG.Location -SubnetId $Subnet.Id `
   -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id


# A form to select the VM size from
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Select a VM Size'
$form.Size = New-Object System.Drawing.Size(300,200)
$form.StartPosition = 'CenterScreen'

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Point(10,135)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = 'OK'
$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $OKButton
$form.Controls.Add($OKButton)

$VMSize = New-Object System.Windows.Forms.Label   
    $VMSize.Text = "Azure VM Sizes:"; $VMSize.Top = 50; $VMSize.Left = 5; $VMSize.Autosize = $true  
    $form.Controls.Add($VMSize)  
    Write-Host "Building List of available Sizes" -ForegroundColor Green
    
    $VMSizeLB = New-Object System.Windows.Forms.ListBox  
        $VMSizeLB.Top = 50; $VMSizeLB.Left = 160; $VMSizeLB.Height = 120 
        $VMSizeLB.TabIndex = 1 
        
        $SizeArr = Get-AzureRmVMSize -Location $RG.Location 
        $i=0    
        foreach ($element in $SizeArr) { 
            [void] $VMSizeLB.Items.Add($element.Name) 
            $i ++ 
        } 
         
        $form.Controls.Add($VMSizeLB) #Add listbox to form 
        


$form.Topmost = $true

$VSResult = $form.ShowDialog()

if ($VSResult -eq [System.Windows.Forms.DialogResult]::OK)
{
    $x = $VMSizeLB.SelectedItem
    $x
}

#Create the VM
$vmConfig = New-AzureRmVMConfig -VMName $env:computername -VMSize $x
$vmName = "$env:computername"
$vm = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $nic.Id
$vm = Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $osDisk.Id -StorageAccountType $Result.Value `
    -DiskSizeInGB 128 -CreateOption Attach -Windows
Write-Host "Creating the VM..." -ForegroundColor Green
New-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Location $RG.Location -VM $vm