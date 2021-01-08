<#
	.SYNOPSIS
		Download CAB file by model, operating system, architecture
	
	.DESCRIPTION
		Download CAB file by model, operating system, architecture
	
	.PARAMETER DriverCatalog
		Driver Pack Catalog download address
	
	.PARAMETER DownloadFolder
		path to the CAB file download folder
	
	.PARAMETER MonthsBack
		download drivers pack newer than  X month. 0 equal no time limit
	
	.PARAMETER UpdateMDTDrivers
		A description of the UpdateMDTDrivers parameter.
	
	.PARAMETER Module
		A description of the Module parameter.
	
	.PARAMETER DeploymentShare
		A description of the DeploymentShare parameter.
	
	.PARAMETER DriversPath
		A description of the DriversPath parameter.
	
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.155
		Created on:   	12/10/2018 10:42
		Created by:   	Brice SARRAZIN
		Organization:
		Filename:     	Get-DriversPackFromDell
		===========================================================================
#>
[CmdletBinding(DefaultParameterSetName = 'UpdateMDT')]
param
(
	[Parameter(HelpMessage = 'Driver Pack Catalog download address')]
	[string]$DriverCatalog = 'http://downloads.dell.com/catalog/DriverPackCatalog.cab',
	[Parameter(HelpMessage = 'path to the CAB file download folder')]
<<<<<<< HEAD
	[string]$DownloadFolder = '\\nas-seg\master_dell\CAB',
=======
	[string]$downloadFolder = (Join-Path $env:USERPROFILE 'Downloads'),
>>>>>>> 1326bc7fdb7b43f78f7fe2dc6b8bc7e64492cd45
	[Parameter(HelpMessage = 'download drivers pack newer than  X month. 0 equal no time limit')]
	[int]$MonthsBack = 0,
	[Parameter(ParameterSetName = 'UpdateMDT', Mandatory)]
	[switch]$UpdateMDTDrivers,
	[Parameter(ParameterSetName = 'UpdateMDT')]
	[string]$Module = "$env:ProgramFiles\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1",
	[Parameter(ParameterSetName = 'UpdateMDT', Mandatory)]
	[string]$DeploymentShare,
	[Parameter(ParameterSetName = 'UpdateMDT')]
	[string]$DriversPath = "Out-of-Box Drivers"
)

DynamicParam
{
	$ParametersName = 'models', 'operatingSystems', 'architectures'
	$RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	
	foreach ($ParameterName in $ParametersName)
	{
		$AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		$ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$AttributeCollection.Add($ParameterAttribute)
		if (Test-Path ".\$ParameterName.txt")
		{
			$ArrSet = Get-Content -Path ".\$ParameterName.txt"
		}
		else
		{
			$ArrSet = ""
		}
		$ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($ArrSet)
		$AttributeCollection.Add($ValidateSetAttribute)
		$RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [array], $AttributeCollection)
		$PSBoundParameters[$ParameterName] = "*"
		
		$RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
	}
	return $RuntimeParameterDictionary
}

BEGIN
{
	Write-Host "Updating models, operating systems and architectures variables " -NoNewline
	$Models = $PSBoundParameters['Models']
	$OperatingSystems = $PSBoundParameters['OperatingSystems']
	$Architectures = $PSBoundParameters['Architectures']
	Write-Host "[OK]" -ForegroundColor Green
}
PROCESS
{
	Write-Host "Downloading Driver Pack Catalog (CAB) from $DriverCatalog " -NoNewline
	try
	{
		$Temp = "$env:TEMP\$([guid]::NewGuid())"
		New-Item -Path $Temp -ItemType Directory -ErrorAction Stop | Out-Null
		Start-BitsTransfer -DisplayName "Driver Pack Catalog (CAB)" -Description "$DriverCatalog" -Source $DriverCatalog -Destination $Temp -ErrorAction Stop
		Write-Host "[OK]" -ForegroundColor Green
	}
	catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Host "[KO]" -ForegroundColor Red
		Write-Host $ExceptionMessage
	}
	
	Write-Host "Expanding Driver Pack Catalog (CAB to XML) " -NoNewline
	try
	{
		$CabCatalog = Join-Path $Temp $DriverCatalog.Split("/")[-1]
		$OShell = New-Object -ComObject Shell.Application
		$SourceFile = $OShell.Namespace("$CabCatalog").items()
		$DestinationFolder = $OShell.Namespace("$Temp")
		$DestinationFolder.CopyHere($SourceFile)
		Write-Host "[OK]" -ForegroundColor Green
	}
	catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Host "[KO]" -ForegroundColor Red
		Write-Host $ExceptionMessage
	}
	
	Write-Debug "Moving Driver Pack Catalog "
	try
	{
		$XmlCatalog = Join-Path $Temp $($SourceFile | Select-Object -ExpandProperty Name)
		Move-Item -Path $XmlCatalog -Destination $DownloadFolder -Force -ErrorAction Stop
		$XmlCatalog = Join-Path $DownloadFolder $($SourceFile | Select-Object -ExpandProperty Name)
	}
	catch
	{
		$ExceptionMessage = $_.Exception.Message
		Write-Warning "Failed to move Driver Pack Catalog (ERROR : $ExceptionMessage)"
	}
	
	Write-Host "Loading Driver Pack Catalog (XML) " -NoNewline
	$Catalog = [xml](Get-Content $XmlCatalog)
	$UrlRoot = "http://" + $($Catalog.DriverPackManifest | Select-Object -ExpandProperty baseLocation)
	Write-Host "[OK]" -ForegroundColor Green
	
	#region Create/update attibute set for variables models, operatingSystems, architectures
	Write-Host "Updating models, operating systems and architectures files " -NoNewline
	[array]$SupportedModels = @()
	[array]$SupportedOS = @()
	[array]$SupportedArch = @()
	$Catalog.DriverPackManifest.DriverPackage | ForEach-Object {
		$SupportedModels += $_.SupportedSystems.Brand.Model | Select-Object -ExpandProperty name
		$SupportedOS += $_.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osCode
		$SupportedArch += $_.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osArch
	}
	$SupportedModels | Select-Object -Unique | Sort-Object | Set-Content .\models.txt
	$SupportedOS | Select-Object -Unique | Sort-Object | Set-Content .\operatingSystems.txt
	$SupportedArch | Select-Object -Unique | Sort-Object | Set-Content .\architectures.txt
	Write-Host "[OK]" -ForegroundColor Green
	#endregion	
	
	$Catalog.DriverPackManifest.DriverPackage | ForEach-Object {
		
		$DriversPack = $_
		
		if (($MonthsBack -eq 0) `
			-or ([datetime]$($DriversPack | Select-Object -ExpandProperty dateTime) -ge [datetime]::Today.AddMonths(- $MonthsBack)))
		{
			foreach ($Model in $Models)
			{
				[array]$SupportedModels = $DriversPack.SupportedSystems.Brand.Model | Select-Object -ExpandProperty name
				
				if (($Model -in $SupportedModels) -or ($Model -eq "*"))
				{
					Write-Debug "Matching model : $SupportedModels"
					
					foreach ($OS in $OperatingSystems)
					{
						[array]$SupportedOS = $DriversPack.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osCode
						
						if (($OS -in $SupportedOS) -or ($OS -eq "*"))
						{
							Write-Debug "Matching OS : $SupportedOS"
							
							foreach ($Arch in $Architectures)
							{
								[array]$SupportedArch = $DriversPack.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osArch
								
								if (($Arch -in $SupportedArch) -or ($Arch -eq "*"))
								{
									Write-Debug "Matching architecture : $SupportedArch"
									
									[array]$SupportedOSandArch = @()
									for ($i = 0; $i -lt $SupportedOS.Count; $i++)
									{
										if ($i -eq 0)
										{
											$SupportedOSandArch = $SupportedOS[$i].ToString().Trim() + " " + $SupportedArch[$i].ToString().Trim()
										}
										else
										{
											$SupportedOSandArch += " / " + $SupportedOS[$i].ToString().Trim() + " " + $SupportedArch[$i].ToString().Trim()
										}
									}
									$SupportedOSandArch[-1] = $SupportedOSandArch[-1].ToString().Trim()
									
									$AlreadyDownloaded = $false
									
									$DriversPackURL = "$UrlRoot/$($DriversPack | Select-Object -ExpandProperty path)"
									
									$Filter = $DriversPackURL.Split("/")[-1]
									$Filter = $Filter.Split('-')[0] + "-" + $Filter.Split('-')[1] + "-*-*"
									
									Get-Item $(Join-Path $DownloadFolder $Filter) | Select-Object -ExpandProperty Name |
									ForEach-Object {
										if ($DriversPackURL.Split("/")[-1] -eq $_) # already downloaded
										{
											$AlreadyDownloaded = $true
											Write-Host "Package $SupportedModels on $SupportedOSandArch already downloaded " -NoNewline
											Write-Host "[OK]" -ForegroundColor Green
											break
										}
									}
									
									if (-not $AlreadyDownloaded)
									{
										try
										{
											Write-Host "Downloading package for $SupportedModels - $SupportedOSandArch " -NoNewline
											Start-BitsTransfer -DisplayName $DriversPackURL.Split("/")[-1]  `
															   -Description "$SupportedModels - $SupportedOSandArch"  `
															   -Source $DriversPackURL  `
															   -Destination $DownloadFolder
											Write-Host "[OK]" -ForegroundColor Green
											
											#region MAJ MDT
											Write-Host "Expanding package $($DriversPackURL.Split("/")[-1]) for $SupportedModels - $SupportedOSandArch " -NoNewline
											Expand-Archive -LiteralPath $DownloadFolder\$DriversPackURL.Split("/")[-1] -DestinationPath $DownloadFolder
											Write-Host "[OK]" -ForegroundColor Green
											
											Write-Host "Updating MDT drivers for $SupportedModels - $SupportedOSandArch " -NoNewline
											$ThisDriversPath = Join-Path $DeploymentShare $DriversPath
											$ThisDriversPath = Join-Path $ThisDriversPath $($DriversPackURL.Split("/")[-1])
											Remove-Item -Path $ThisDriversPath
											#endregion MAJ MDT
										}
										catch
										{
											Write-Host "[KO]" -ForegroundColor Red
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
END
{
<<<<<<< HEAD
	Write-Debug "Clean"
	
	$Filter = "*.CAB"
	$LocalCABs = Get-Item $(Join-Path $DownloadFolder $Filter) | Sort-Object Name | Select-Object -ExpandProperty Name
	
	if ($LocalCABs)
	{
		foreach ($CurrentCAB in $LocalCABs)
		{
			
			$Filter = $CurrentCAB.Split('-')[0] + "-" + $CurrentCAB.Split('-')[1] + "-*-*"
			
			Get-Item $(Join-Path $DownloadFolder $Filter) | Select-Object -ExpandProperty Name |
			ForEach-Object {
				
				if ($CurrentCAB.Split('-')[2] -gt $_.Split('-')[2])
				{
					try
					{
						Write-Host "Removing old package : $_"
						Remove-Item -Path $(Join-Path $DownloadFolder $_) -Force -ErrorAction Stop | Out-Null
					}
					catch
					{
						Write-Warning "Failed to remove $(Join-Path $DownloadFolder $_) : "+$Error[0]
					}
				}
			}
		}
	}
=======

>>>>>>> 1326bc7fdb7b43f78f7fe2dc6b8bc7e64492cd45
}

# SIG # Begin signature block
# MIIXrAYJKoZIhvcNAQcCoIIXnTCCF5kCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA+2x7Pr/dh9h2L
# fid8EWrhp7/TvRyjbHlfVEkhfr2AjaCCEoAwggOxMIICmaADAgECAhAR2NBOxpET
# oUOECWDd+cNwMA0GCSqGSIb3DQEBCwUAMEwxEjAQBgoJkiaJk/IsZAEZFgJmcjEY
# MBYGCgmSJomT8ixkARkWCGludHJhbmV0MRwwGgYDVQQDExNpbnRyYW5ldC1EQy1T
# RUcxLUNBMB4XDTE4MDUyMjIxMTAxMloXDTIzMDUyMjIxMjAxMVowTDESMBAGCgmS
# JomT8ixkARkWAmZyMRgwFgYKCZImiZPyLGQBGRYIaW50cmFuZXQxHDAaBgNVBAMT
# E2ludHJhbmV0LURDLVNFRzEtQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQDNQ4A1gRqZt3jrn8Fo/oo41USq7Dn6DLLglKvGx1xDdySDDqkZsx5D98By
# 8tyU/KgDQApLAustkn5IbcYCVzKvhemWnqXo2QgD2xh9nPxLBiRQhNTLSfiG/hoa
# xUM8zOhknLw4sC0n4SIOyhsA7frsIRicyicQhMhyyI191G208qNkq8yB7xIuAkjj
# 44JyzZDlOqduDl5LDy8YI1YEdVMQ88L0NTy0ALj4532jBxglTwbpR5+oxVXdM0EK
# P+JtjznPaOwCMzXuhJP7Vt+TcUe+uuzdk9txccUmmWGXZkdQlfetQVyybTun6tKT
# nzFLhnI2EfYjJp6Ma1nVMkmV9PDzAgMBAAGjgY4wgYswEwYJKwYBBAGCNxQCBAYe
# BABDAEEwCwYDVR0PBAQDAgFGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFMh9
# ZsoqQDWF6P/vwTi5kCxzM2w6MBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGC
# NxUCBBYEFDTDFSOTdesS3YjkW7J0iJ4AX5mlMA0GCSqGSIb3DQEBCwUAA4IBAQAT
# twfPSn3Z1+fyvkeny7hibPYLfR9fVdlW+vIMRbNY9KokKYS7uwvTdPUT7/yqBlBW
# QWsIqZJ45TmT7P3cRN/wcNPRBPMIWz9I3vaJ3ZRf2jLwIGXXZApialt1mhbuyj+4
# K1a9AMr+kMg2lEaBoJcyw4YCa8ml6dfLJa5N6laLHieUto/LZxbnufR7P8lKSWmU
# a/JbmIAk8HCsR4pV0G4bXd1HG3quV0Cq21RZ5v+bgw5PkuJhVivud2i7IOyqO3nG
# KbVUs7Q9na2MZK8sxleQVNoLVuxyy9RyGIA+sm3k+oMZC1EE/TR7K1VOBmMAfD4r
# HzY7gAtLEGtk1WqA5I2fMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZI
# hvcNAQEFBQAwVzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYt
# c2ExEDAOBgNVBAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBD
# QTAeFw0xMTA0MTMxMDAwMDBaFw0yODAxMjgxMjAwMDBaMFIxCzAJBgNVBAYTAkJF
# MRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWdu
# IFRpbWVzdGFtcGluZyBDQSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAlO9l+LVXn6BTDTQG6wkft0cYasvwW+T/J6U00feJGr+esc0SQW5m1IGg
# hYtkWkYvmaCNd7HivFzdItdqZ9C76Mp03otPDbBS5ZBb60cO8eefnAuQZT4XljBF
# cm05oRc2yrmgjBtPCBn2gTGtYRakYua0QJ7D/PuV9vu1LpWBmODvxevYAll4d/eq
# 41JrUJEpxfz3zZNl0mBhIvIG+zLdFlH6Dv2KMPAXCae78wSuq5DnbN96qfTvxGIn
# X2+ZbTh0qhGL2t/HFEzphbLswn1KJo/nVrqm4M+SU4B09APsaLJgvIQgAIMboe60
# dAXBKY5i0Eex+vBTzBj5Ljv5cH60JQIDAQABo4HlMIHiMA4GA1UdDwEB/wQEAwIB
# BjASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBRG2D7/3OO+/4Pm9IWbsN1q
# 1hSpwTBHBgNVHSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93
# d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYi
# aHR0cDovL2NybC5nbG9iYWxzaWduLm5ldC9yb290LmNybDAfBgNVHSMEGDAWgBRg
# e2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEATl5WkB5GtNlJ
# MfO7FzkoG8IW3f1B3AkFBJtvsqKa1pkuQJkAVbXqP6UgdtOGNNQXzFU6x4Lu76i6
# vNgGnxVQ380We1I6AtcZGv2v8Hhc4EvFGN86JB7arLipWAQCBzDbsBJe/jG+8ARI
# 9PBw+DpeVoPPPfsNvPTF7ZedudTbpSeE4zibi6c1hkQgpDttpGoLoYP9KOva7yj2
# zIhd+wo7AKvgIeviLzVsD440RZfroveZMzV+y5qKu0VN5z+fwtmK+mWybsd+Zf/o
# kuEsMaL3sCc2SI8mbzvuTXYfecPlf5Y1vC0OzAGwjn//UYCAp5LUs0RGZIyHTxZj
# BzFLY7Df8zCCBJ8wggOHoAMCAQICEhEh1pmnZJc+8fhCfukZzFNBFDANBgkqhkiG
# 9w0BAQUFADBSMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1z
# YTEoMCYGA1UEAxMfR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBHMjAeFw0x
# NjA1MjQwMDAwMDBaFw0yNzA2MjQwMDAwMDBaMGAxCzAJBgNVBAYTAlNHMR8wHQYD
# VQQKExZHTU8gR2xvYmFsU2lnbiBQdGUgTHRkMTAwLgYDVQQDEydHbG9iYWxTaWdu
# IFRTQSBmb3IgTVMgQXV0aGVudGljb2RlIC0gRzIwggEiMA0GCSqGSIb3DQEBAQUA
# A4IBDwAwggEKAoIBAQCwF66i07YEMFYeWA+x7VWk1lTL2PZzOuxdXqsl/Tal+oTD
# YUDFRrVZUjtCoi5fE2IQqVvmc9aSJbF9I+MGs4c6DkPw1wCJU6IRMVIobl1Acjzy
# CXenSZKX1GyQoHan/bjcs53yB2AsT1iYAGvTFVTg+t3/gCxfGKaY/9Sr7KFFWbIu
# b2Jd4NkZrItXnKgmK9kXpRDSRwgacCwzi39ogCq1oV1r3Y0CAikDqnw3u7spTj1T
# k7Om+o/SWJMVTLktq4CjoyX7r/cIZLB6RA9cENdfYTeqTmvT0lMlnYJz+iz5crCp
# GTkqUPqp0Dw6yuhb7/VfUfT5CtmXNd5qheYjBEKvAgMBAAGjggFfMIIBWzAOBgNV
# HQ8BAf8EBAMCB4AwTAYDVR0gBEUwQzBBBgkrBgEEAaAyAR4wNDAyBggrBgEFBQcC
# ARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYDVR0T
# BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBCBgNVHR8EOzA5MDegNaAzhjFo
# dHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL2dzL2dzdGltZXN0YW1waW5nZzIuY3Js
# MFQGCCsGAQUFBwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3NlY3VyZS5nbG9i
# YWxzaWduLmNvbS9jYWNlcnQvZ3N0aW1lc3RhbXBpbmdnMi5jcnQwHQYDVR0OBBYE
# FNSihEo4Whh/uk8wUL2d1XqH1gn3MB8GA1UdIwQYMBaAFEbYPv/c477/g+b0hZuw
# 3WrWFKnBMA0GCSqGSIb3DQEBBQUAA4IBAQCPqRqRbQSmNyAOg5beI9Nrbh9u3WQ9
# aCEitfhHNmmO4aVFxySiIrcpCcxUWq7GvM1jjrM9UEjltMyuzZKNniiLE0oRqr2j
# 79OyNvy0oXK/bZdjeYxEvHAvfvO83YJTqxr26/ocl7y2N5ykHDC8q7wtRzbfkiAD
# 6HHGWPZ1BZo08AtZWoJENKqA5C+E9kddlsm2ysqdt6a65FDT1De4uiAO0NOSKlvE
# Wbuhbds8zkSdwTgqreONvc0JdxoQvmcKAjZkiLmzGybu555gxEaovGEzbM9OuZy5
# avCfN/61PU+a003/3iCOTpem/Z8JvE3KGHbJsE2FUPKA0h0G9VgEB7EYMIIGDDCC
# BPSgAwIBAgITMQAAQrjepQvSe44icQABAABCuDANBgkqhkiG9w0BAQsFADBMMRIw
# EAYKCZImiZPyLGQBGRYCZnIxGDAWBgoJkiaJk/IsZAEZFghpbnRyYW5ldDEcMBoG
# A1UEAxMTaW50cmFuZXQtREMtU0VHMS1DQTAeFw0xOTEwMTUxMjQwNTNaFw0yMDEw
# MTQxMjQwNTNaMFUxEjAQBgoJkiaJk/IsZAEZFgJmcjEYMBYGCgmSJomT8ixkARkW
# CGludHJhbmV0MQwwCgYDVQQLEwNTRUcxFzAVBgNVBAMTDkJyaWNlIFNBUlJBWklO
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0P12Agt4beCnnAq3uElX
# eRlEnJOFTTxTH4ELhVJPfaemn7UeF0XcPE2z3er3cccVKidb28K3XN34fAnPg7ot
# /hWp6HYFYfpJtxck4s0xPaa1IR/nJr/WNbZpVuTFB4oAvPCMqqXNFKyi6PK2kCIH
# ZeHNI4lZXr+eg07NnR1Vfeh5wQV4vm320S2iZWW06EesO7yZS5NCKwrr28uW8fXc
# qp5KBxfqghj98+DtwsDLFNw46eAz0vyyFDm3TdMRhXUDTLuEcMje68DEGsD0UzEP
# LYbeD1VAoYqDcKSHQPolOHKEIIga2WzSqloXOhc6+LWkOm8IMwBLFBW3liQVyw08
# MQIDAQABo4IC3DCCAtgwFQYJKwYBBAGCNxQCBAgeBgBFAEYAUzAVBgNVHSUEDjAM
# BgorBgEEAYI3CgMEMA4GA1UdDwEB/wQEAwIFIDBEBgkqhkiG9w0BCQ8ENzA1MA4G
# CCqGSIb3DQMCAgIAgDAOBggqhkiG9w0DBAICAIAwBwYFKw4DAgcwCgYIKoZIhvcN
# AwcwHQYDVR0OBBYEFOQlt4QsuMu5wBRlSjfRozgqzy2NMB8GA1UdIwQYMBaAFMh9
# ZsoqQDWF6P/vwTi5kCxzM2w6MIIBGwYDVR0fBIIBEjCCAQ4wggEKoIIBBqCCAQKG
# gb1sZGFwOi8vL0NOPWludHJhbmV0LURDLVNFRzEtQ0EoMSksQ049REMtU0VHMSxD
# Tj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049
# Q29uZmlndXJhdGlvbixEQz1pbnRyYW5ldCxEQz1mcj9jZXJ0aWZpY2F0ZVJldm9j
# YXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnSG
# QGh0dHA6Ly9EQy1TRUcxLmludHJhbmV0LmZyL0NlcnRFbnJvbGwvaW50cmFuZXQt
# REMtU0VHMS1DQSgxKS5jcmwwgcUGCCsGAQUFBwEBBIG4MIG1MIGyBggrBgEFBQcw
# AoaBpWxkYXA6Ly8vQ049aW50cmFuZXQtREMtU0VHMS1DQSxDTj1BSUEsQ049UHVi
# bGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlv
# bixEQz1pbnRyYW5ldCxEQz1mcj9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xh
# c3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTArBgNVHREEJDAioCAGCisGAQQBgjcU
# AgOgEgwQYnNhcnJhemluQG5nZS5mcjANBgkqhkiG9w0BAQsFAAOCAQEANd4b19J2
# Ezu81biGgXpbJ035H9eaRaVwAgw6wT7fylVx6Mf04xoG9zjmJVOOCR9biDFIbzym
# rATGeLdcYG85qPFlRQOfQTzmKxb9iLZQ2KLVz5TsfGZr9eP3jzThgwcINBrqxXG9
# Y/2nt2q6GTlm8j+/rwKsC6z8bHhY4UYw1a0QoxS9Ji5JQF5LgQv9D86kz+E1TGZZ
# 95u/vvw801q7PwnVF0O/t62WMWHdxMlOitDdXRfZ/P8pJCWS2o04S3OPLWisrSeQ
# d73F7HqVPdfXI+K0FPcvp1vU5cm4Rq1BCUq55njBlQwetIEaAZk9zhnE72zijVAh
# 7+4S0WsM8W+wxzGCBIIwggR+AgEBMGMwTDESMBAGCgmSJomT8ixkARkWAmZyMRgw
# FgYKCZImiZPyLGQBGRYIaW50cmFuZXQxHDAaBgNVBAMTE2ludHJhbmV0LURDLVNF
# RzEtQ0ECEzEAAEK43qUL0nuOInEAAQAAQrgwDQYJYIZIAWUDBAIBBQCgTDAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQglbosrGSgOyoi
# 9Zoz6Ac5TS1DdgJfpSEqNk0XTj00F0swDQYJKoZIhvcNAQEBBQAEggEAkjocjGP0
# AcTIDr1bMDMiM7f5pYP2+7kTf77UsjLdv/a0LUsF9VsaG3hOx/p86I4Nw2aMkXF8
# 4puVSzkPjePUuk1TbtWkOPmtkxs1nrM5ryQr60NurDilVNWISHO4b1YEAuDhtF8i
# MliNeQWjjpSUADnuWixZ9KEykO8jTZQdYPEzAIamEYpH9Df2G0qX0z+1PY9LMUVC
# 5bgRaOKwvTgcjqRr9MmHDMr8JKx7QuMNzbSfxvEwNFlk0K6GXLTA5dCLJr/UTQQH
# eCuRd2PvYoQCZmhpojhacEQcHV7f7kvjmz+lmWyAemblKfKIgnVnTymKObjrIqj6
# fIuqUJdQ0R6AnqGCAqIwggKeBgkqhkiG9w0BCQYxggKPMIICiwIBATBoMFIxCzAJ
# BgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9H
# bG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIEcyAhIRIdaZp2SXPvH4Qn7pGcxT
# QRQwCQYFKw4DAhoFAKCB/TAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqG
# SIb3DQEJBTEPFw0yMDA4MDYxMjMzNTZaMCMGCSqGSIb3DQEJBDEWBBRPDYVEnvr3
# kflGhUio5quT40LQUTCBnQYLKoZIhvcNAQkQAgwxgY0wgYowgYcwgYQEFGO4L6th
# 9YOQlpUFCwAknFApM+x5MGwwVqRUMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBH
# bG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFtcGlu
# ZyBDQSAtIEcyAhIRIdaZp2SXPvH4Qn7pGcxTQRQwDQYJKoZIhvcNAQEBBQAEggEA
# ZIBqTA/U7m0rooZRYT3oSdt30IkbOKKCOfpJqLxENIZhhwK+DyZWPX40PIxK4zDY
# 5TOP5iqcqdw8lMRrKPpg2YyVchYZwxHksKm/ogY+ppUGSHzruK7oTtyc6PMCByyW
# swRxc8CsE1q/nXutgscEGAXo1c/y5T20f4VRkz/BAi9lX2aTZv+sJptApGRiAGVI
# 6diqm3fZ+uoCtTd3f4RCeC61jSz+kJ3wD3AQ0vDo+OfS5yLUffcJOsXVSOX1kuUu
# rJZDW9o3g0inv4DLtEcXSG9ribvTtp5F2afKNaqbKdP7j8i9aTVarAaU71oL68CK
# AD1CQXABMvH2N7+pnCYftA==
# SIG # End signature block
