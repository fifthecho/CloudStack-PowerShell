<#
.SYNOPSIS
   A CloudStack/CloudPlatform Volume Snapshot History Listing.
.DESCRIPTION
   Snapshot Counter will iterate through each volume and display a count of the number of snapshots per-volume.
.EXAMPLE
   CloudStackSnapshotCounter.ps1
#>
# Writen by Jeff Moody (fifthecho@gmail.com)
#
# 2013/7/12  v1.0 created


Import-Module CloudStackClient
$parameters = Import-CloudStackConfig

if ($parameters -ne 1) {
	$cloud = New-CloudStack -apiEndpoint $parameters[0] -apiPublicKey $parameters[1] -apiSecretKey $parameters[2]
    $volumeListJob = Get-CloudStack -cloudStack $cloud -command listVolumes
    $volumes = $volumeListJob.listvolumesresponse.volume
    foreach($v in $volumes){
        $volumeID = $v.id
        $snapshotListJob = Get-CloudStack -cloudStack $cloud -command listSnapshots -options volumeid=$volumeID
        $snaps = $snapshotListJob.listsnapshotresponse
        $count = 0
        if ($snapshotListJob.listsnapshotsresponse.count){
            $count = $snapshotListJob.listsnapshotsresponse.count
        }
        Write-Host " Volume $volumeID has $count snapshots"
    }
}
else {
	Write-Error "Please configure the $env:userprofile\cloud-settings.txt file"
}	