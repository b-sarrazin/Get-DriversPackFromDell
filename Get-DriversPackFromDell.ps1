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
	[string]$DownloadFolder = (Join-Path $env:USERPROFILE 'Downloads'),
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
}
