<#
.SYNOPSIS
    A CloudStack/CloudPlatform Virtual Machine Desployment Scriptlet
.DESCRIPTION
    Use this script to deploy a virtual machine in a CloudStack Cloud.
.PARAMETER templateid
    The template ID for the VM.
.PARAMETER zoneid
    The zone for the VM
.PARAMETER serviceofferingid
    The Service offering ID for the VM
.PARAMETER securitygroupids
    The Security Group IDs for the VM
.PARAMETER networkids
    The Security Group IDs for the VM
#>
# Writen by Jeff Moody (fifthecho@gmail.com)
#
# 2013/7/19  v1.0 created
# 2013/8/29  v1.1 added userdata, keypairs, and naming.

Param(
[Parameter(Mandatory=$true)]
  [String]
  $templateid
,
[Parameter(Mandatory=$true)]
  [String]
  $zoneid
,
[Parameter(Mandatory=$true)]
  [String]
  $serviceofferingid
,
[Parameter(Mandatory=$false)]
  [Array]
  $securitygroupids
,
[Parameter(Mandatory=$false)]
  [Array]
  $networkids
,
[Parameter(Mandatory=$false)]
  [String]
  $displayname
,
[Parameter(Mandatory=$false)]
  [String]
  $keypair
,
[Parameter(Mandatory=$false)]
  [String]
  $hostname
,
[Parameter(Mandatory=$false)]
  [String]
  $userdata
)

Import-Module CloudStackClient
$parameters = Import-CloudStackConfig
$okayToLaunch = $false
# $job = ""

if ($parameters -ne 1) {
  $cloud = New-CloudStack -apiEndpoint $parameters[0] -apiPublicKey $parameters[1] -apiSecretKey $parameters[2]
  $options = @("templateid=$templateid", "zoneid=$zoneid", "serviceofferingid=$serviceofferingid")
  
  if($keypair) {
    $options += "keypair=$keypair"
  }
  
  if($hostname) {
    $options += "name=$hostname"
  }
  
  if($displayname) {
    $options += "displayname=$displayname"
  }

  if($userdata) {
    $options += "userdata=$userdata"
  }
  
  if($securitygroupids) {
    $sids = $securitygroupids | Sort-Object
    $sids = $sids -join "%2c"
    $options += "securitygroupids=$sids"
    $okayToLaunch = $true
  }
  
  elseif($networkids) {
    $nids = $networkids | Sort-Object
    $nids = $nids -join "%2c"
    $options += "networkids=$nids"
    $okayToLaunch = $true
  }
  
  else {
    Write-Error "No network or security groups specified."
  }

  if ($okayToLaunch -eq $true) {
    $opsstring = $options -join ','
    Write-Debug $opsstring
    $job = Get-CloudStack -cloudStack $cloud -command deployVirtualMachine -options $options
  }

  if($job){
    $jobid = $job.deployvirtualmachineresponse.jobid
    do {
      Write-Host -NoNewline "."
      $jobStatus = Get-CloudStack -cloudStack $cloud -command queryAsyncJobResult -options jobid=$jobid
      Start-Sleep -Seconds 2
    }
    while ($jobStatus.queryasyncjobresultresponse.jobstatus -eq 0)
    $statusCode = $jobStatus.queryasyncjobresultresponse.jobresultcode
    if ($statusCode -ne 0) {
      Write-Error $jobStatus.queryasyncjobresultresponse.errortext
    }
    else {
      $vm = $jobStatus.queryasyncjobresultresponse.jobresult.virtualmachine
      $vmid = $vm.id
      $ip = $vm.nic.ipaddress
      $password = $vm.password
      Write-Host "`nVM $vmid deployed. VM IP Address is $ip and Administrator password is $password"
    }

  }
	
}
else {
	Write-Error "Please configure the $env:userprofile\cloud-settings.txt file"
}
