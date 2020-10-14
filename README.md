# Get-DriversPackFromDell

A script to download CAB files from Dell

## Getting Started

The following variables can be modified:
* driverCatalog: URL to download CAB files
* downloadFolder: destination folder for CAB files
* monthsBack: download drivers pack newer than X month. 0 equal no time limit
* models: filter CAB files according to the requested models
* operatingSystems: filter CAB files according to the operating systems requested
* architectures: filter CAB files according to the requested architectures

The use of parameters is not mandatory.
However, for more convenience, it is advisable to modify the following variables directly in the code: $downloadFolder, $monthsBack

### Prerequisites

* Windows 7+ / Windows Server 2003+ / Linux / MAC
* PowerShell v1+

## Description

The script performs the following actions:
* download CAB files from Dell
* skip files already downloaded
* removes old packages when a new one is downloaded

It is possible to filter according to:
* computer models
* operating systems
* processor architecture
* age of CAB files

## Example

Download CAB files less than 12 months old
> .\Get-DriversPackFromDell.ps1 -monthsBack 12

Download CAB files less than 6 months old corresponding to x86 or x64 architectures and Windows 7 or 10 operating systems :
> .\Get-DriversPackFromDell.ps1 -architectures x86,x64 -operatingSystems Windows10,Windows7 -monthsBack 6

Download CAB files corresponding to models Latitude 7370 or Latitude 7490
> .\Get-DriversPackFromDell.ps1 -models 'Latitude 7370','Latitude 7490'

*Remember to take advantage of auto-completion, especially for computer models*
