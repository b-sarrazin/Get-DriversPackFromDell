<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2020 v5.7.172
	 Created on:   	05/02/2020 11:43
	 Created by:   	Brice SARRAZIN
	 Organization: 	NGE
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		A description of the file.
#>

$Architectures = "x64"
$OperatingSystems = "Windows10"
$Models = "Latitude 5500",
"Latitude 5590",
"Latitude 7300",
"Latitude 7370",
"Latitude 7400",
"Optiplex 3050",
"Optiplex 3060",
"Optiplex 3070",
"Precision 3540",
"Precision 3630 Tower",
"Precision 5520",
"Precision 5820 Tower",
"Precision 7540",
"Precision 7720",
"Precision 7730",
"Precision 7740"

.\Get-DriversPackFromDell.ps1 -operatingSystems winpe10x

.\Get-DriversPackFromDell.ps1 -architectures $Architectures `
							  -operatingSystems $OperatingSystems `
							  -models $Models
