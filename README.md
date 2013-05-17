CloudStack-PowerShell
=====================

A PowerShell Module for the Apache CloudStack / Citrix CloudPlatform API

This module provides Cmdlets for:
```	
	New-CloudStack
	Get-CloudStack
	Import-CloudStackConfig
```	

To install the module correctly, run the following in PowerShell:
```
	$PSModulePath = $Env:PSModulePath -split ";" | Select -Index ([int][bool]$Global)
	mkdir $PSModulePath\CloudStackClient
	Copy-Item .\CloudStackClient.psm1 $PSModulePath\CloudStackClient\CloudStackClient.psm1
```	

Once the module is installed, it can be loaded via "Import-Module CloudStackClient"

The CloudStackListVirtualMachines, CloudStackSnapshotVolume, and CloudStackSnapshotHistoryManager 
scripts shoud give you an idea of how to interact with the Module.
