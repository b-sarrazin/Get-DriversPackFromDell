<#
	.SYNOPSIS
		Download CAB file by model, operating system, architecture
	
	.DESCRIPTION
		Download CAB file by model, operating system, architecture
	
	.PARAMETER driverCatalog
		Driver Pack Catalog download address
	
	.PARAMETER downloadFolder
		path to the CAB file download folder
	
	.PARAMETER monthsBack
		download drivers pack newer than  X month. 0 equal no time limit
	
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.155
		Created on:   	12/10/2018 10:42
		Created by:   	Brice SARRAZIN
		Organization: 	
		Filename:     	Get-DriversPackFromDell
		===========================================================================
#>

[CmdletBinding()]
param
(
	[Parameter(HelpMessage = 'Driver Pack Catalog download address')]
	[string]$driverCatalog = 'http://downloads.dell.com/catalog/DriverPackCatalog.cab',
	[Parameter(HelpMessage = 'path to the CAB file download folder')]
	[string]$downloadFolder = (Join-Path $env:USERPROFILE 'Downloads'),
	[Parameter(HelpMessage = 'download drivers pack newer than  X month. 0 equal no time limit')]
	[int]$monthsBack = 0
)

DynamicParam
{
	$parametersName = 'models', 'operatingSystems', 'architectures'
	$runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	
	foreach ($parameterName in $parametersName)
	{
		$attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		$parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$attributeCollection.Add($parameterAttribute)
		if (Test-Path ".\$parameterName.txt")
		{
			$arrSet = Get-Content -Path ".\$parameterName.txt"
		}
		else
		{
			$arrSet = ""
		}
		$validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
		$attributeCollection.Add($validateSetAttribute)
		$runtimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($parameterName, [array], $attributeCollection)
		$PSBoundParameters[$parameterName] = "*"
		
		$runtimeParameterDictionary.Add($parameterName, $runtimeParameter)
	}
	return $runtimeParameterDictionary
}

BEGIN
{
	Write-Host "Updating variables models, operatingSystems, architectures"
	$models = $PSBoundParameters['models']
	$operatingSystems = $PSBoundParameters['operatingSystems']
	$architectures = $PSBoundParameters['architectures']
}
PROCESS
{
	Write-Host "Downloading Driver Pack Catalog (CAB)"
	Write-Host "URL : $driverCatalog"
	try
	{
		$temp = "$env:TEMP\$([guid]::NewGuid())"
		New-Item -Path $temp -ItemType Directory -ErrorAction Stop | Out-Null
		Start-BitsTransfer -DisplayName "Driver Pack Catalog (CAB)" -Description "$driverCatalog" -Source $driverCatalog -Destination $temp -ErrorAction Stop
	}
	catch
	{
		Write-Warning "Failed to download Driver Pack Catalog (ERROR : $($Error[0]))"
	}
	
	Write-Host "Expanding Driver Pack Catalog (CAB to XML)"
	try
	{
		$cabCatalog = Join-Path $temp $driverCatalog.Split("/")[-1]
		$oShell = New-Object -ComObject Shell.Application
		$sourceFile = $oShell.Namespace("$cabCatalog").items()
		$destinationFolder = $oShell.Namespace("$temp")
		$destinationFolder.CopyHere($sourceFile)
	}
	catch
	{
		Write-Warning "Failed to expand Driver Pack Catalog"
	}
	
	Write-Debug "Moving Driver Pack Catalog"
	try
	{
		$xmlCatalog = Join-Path $temp $($sourceFile | Select-Object -ExpandProperty Name)
		Move-Item -Path $xmlCatalog -Destination $downloadFolder -Force -ErrorAction Stop
		$xmlCatalog = Join-Path $downloadFolder $($sourceFile | Select-Object -ExpandProperty Name)
	}
	catch
	{
		Write-Warning "Failed to move Driver Pack Catalog (ERROR : $($Error[0])"
	}
	
	Write-Host "Loading Driver Pack Catalog (XML)"
	$catalog = [xml](Get-Content $xmlCatalog)
	$urlRoot = "http://" + $($catalog.DriverPackManifest | Select-Object -ExpandProperty baseLocation)
	
	#region Create/update attibute set for variables models, operatingSystems, architectures
	[array]$supportedModels = @()
	[array]$supportedOS = @()
	[array]$supportedArch = @()
	$catalog.DriverPackManifest.DriverPackage | ForEach-Object {
		$supportedModels += $_.SupportedSystems.Brand.Model | Select-Object -ExpandProperty name
		$supportedOS += $_.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osCode
		$supportedArch += $_.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osArch
	}
	$supportedModels | Select-Object -Unique | Sort-Object | Set-Content .\models.txt
	$supportedOS | Select-Object -Unique | Sort-Object | Set-Content .\operatingSystems.txt
	$supportedArch | Select-Object -Unique | Sort-Object | Set-Content .\architectures.txt
	#endregion	
	
	$catalog.DriverPackManifest.DriverPackage | ForEach-Object {
		
		$driversPack = $_
		
		if (($monthsBack -eq 0) `
			-or ([datetime]$($driversPack | Select-Object -ExpandProperty dateTime) -ge [datetime]::Today.AddMonths(- $monthsBack)))
		{
			foreach ($model in $models)
			{
				[array]$supportedModels = $driversPack.SupportedSystems.Brand.Model | Select-Object -ExpandProperty name
				
				if (($model -in $supportedModels) -or ($model -eq "*"))
				{
					Write-Debug "Matching model : $supportedModels"
					
					foreach ($OS in $operatingSystems)
					{
						[array]$supportedOS = $driversPack.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osCode
						
						if (($OS -in $supportedOS) -or ($OS -eq "*"))
						{
							Write-Debug "Matching OS : $supportedOS"
							
							foreach ($arch in $architectures)
							{
								[array]$supportedArch = $driversPack.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osArch
								
								if (($arch -in $supportedArch) -or ($arch -eq "*"))
								{
									Write-Debug "Matching architecture : $supportedArch"
									
									[array]$supportedOSandArch = @()
									for ($i = 0; $i -lt $supportedOS.Count; $i++)
									{
										if ($i -eq 0)
										{
											$supportedOSandArch = $supportedOS[$i].ToString().Trim() + " " + $supportedArch[$i].ToString().Trim()
										}
										else
										{
											$supportedOSandArch += " / " + $supportedOS[$i].ToString().Trim() + " " + $supportedArch[$i].ToString().Trim()
										}
									}
									$supportedOSandArch[-1] = $supportedOSandArch[-1].ToString().Trim()
									
									$alreadyDownloaded = $false
									
									$driversPackURL = "$urlRoot/$($driversPack | Select-Object -ExpandProperty path)"
									
									$filter = $driversPackURL.Split("/")[-1]
									$filter = $filter.Split('-')[0] + "-" + $filter.Split('-')[1] + "-*-*"
									
									Get-Item $(Join-Path $downloadFolder $filter) | Select-Object -ExpandProperty Name |
									ForEach-Object {
										if ($driversPackURL.Split("/")[-1] -eq $_) # already downloaded
										{
											$alreadyDownloaded = $true
											Write-Host "Package $supportedModels on $supportedOSandArch already downloaded" -ForegroundColor Green
											break
										}
									}
									
									if (-not $alreadyDownloaded)
									{
										try
										{
											Write-Host "Downloading package for $supportedModels - $supportedOSandArch" -ForegroundColor Yellow
											Start-BitsTransfer -DisplayName $driversPackURL.Split("/")[-1]  `
															   -Description "$supportedModels - $supportedOSandArch"  `
															   -Source $driversPackURL  `
															   -Destination $downloadFolder
											Write-Host "Package $($driversPackURL.Split("/")[-1]) downloaded for $supportedModels - $supportedOSandArch" -ForegroundColor Green
										}
										catch
										{
											Write-Warning "Failed to download package for $supportedModels - $supportedOSandArch"
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

}
