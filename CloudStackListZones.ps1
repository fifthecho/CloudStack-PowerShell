<#
.SYNOPSIS
   A CloudStack/CloudPlatform Zone Listing Scriptlet.
.DESCRIPTION
   List all Zones of a CloudStack Cloud.
.EXAMPLE
   CloudStackListZones.ps1 
#>
# Writen by Jeff Moody (fifthecho@gmail.com)
#
# 2013/5/17  v1.0 created

Import-Module CloudStackClient
$parameters = Import-CloudStackConfig

if ($parameters -ne 1) {
	$cloud = New-CloudStack -apiEndpoint $parameters[0] -apiPublicKey $parameters[1] -apiSecretKey $parameters[2]
    $job = $zones = Get-CloudStack -cloudStack $cloud -command listZones
	$zones = $job.listzonesresponse

	foreach ($ZONE in $zones.zone) {
        $ZONEID = $ZONE.id
        $ZONENAME = $ZONE.name
		Write-Host("Zone `"$ZONENAME`" is associated with Zone ID $ZONEID")
	}
}
else {
	Write-Error "Please configure the $env:userprofile\cloud-settings.txt file"
}
