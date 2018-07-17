$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters\"
New-ItemProperty -Path $RegPath -Name AllowEncryptionOracle -Value 2 -PropertyType DWORD -Force