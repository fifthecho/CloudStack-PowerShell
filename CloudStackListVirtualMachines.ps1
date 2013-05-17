<#
.SYNOPSIS
   A CloudStack/CloudPlatform Virtual Machine Listing Scriptlet.
.DESCRIPTION
   List all virtual machines running within a CloudStack Cloud.
.PARAMETER zoneid
   The zone ID to list VMs from.
.EXAMPLE
   CloudStackListVirtualMachines.ps1 -zoneid e697daf1-a747-4152-a5ac-992bad096653
#>
# Writen by Jeff Moody (fifthecho@gmail.com)
#
# 2013/5/17  v1.0 created

Param(
	[String]
    $zoneid
)

Import-Module CloudStackClient
$parameters = Import-CloudStackConfig

if ($parameters -ne 1) {
	$cloud = New-CloudStack -apiEndpoint $parameters[0] -apiPublicKey $parameters[1] -apiSecretKey $parameters[2]
	if ($zoneid) {
		$job = Get-CloudStack -cloudStack $cloud -command listVirtualMachines -options zoneid=$zoneid
	}
	else {
		$job = Get-CloudStack -cloudStack $cloud -command listVirtualMachines 
	}
	$allVMs = $job.listvirtualmachinesresponse

	foreach ($VM in $allVMs.virtualmachine) {
        $VMID = $VM.id
        $VMNAME = $VM.name
        $VMDISPLAYNAME = $VM.displayname
        $VMZONENAME = $VM.zonename
        $VMTEMPLATE = $VM.templatedisplaytext
		Write-Host("Virtual Machine $VMDISPLAYNAME (ID: $VMID) is running '$VMTEMPLATE' in $VMZONENAME")
	}
}
else {
	Write-Error "Please configure the $env:userprofile\cloud-settings.txt file"
}
