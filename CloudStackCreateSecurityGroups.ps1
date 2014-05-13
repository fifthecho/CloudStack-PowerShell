<#
.SYNOPSIS
   A CloudStack/CloudPlatform SecurityGroup Creating Scriptlet.
.DESCRIPTION
   create a security group of a CloudStack Cloud.
   This function return a ID matching to the securityGroup just created 
.EXAMPLE
   CloudStackCreateSecurityGroups.ps1
#>
# Writen by Jerome RIVIERE (www.jerome-riviere.re)
# Use CloudStackClientModule
# 2014/5/13  v1.0 created

Param(
[Parameter(Mandatory=$true)]
  [String]
  $name
,
[Parameter(Mandatory=$false)]
  [String]
  $description
)

Import-Module CloudStackClient
$parameters = Import-CloudStackConfig

if ($parameters -ne 1) {
	$cloud = New-CloudStack -apiEndpoint $parameters[0] -apiPublicKey $parameters[1] -apiSecretKey $parameters[2]
	
	$options = @("name=$name")
	
	if($description){
		$options += "description=$description"
	}
	
	$id = .\CloudStackListSecurityGroups.ps1 -name $name
	
	if($id -eq $null){
		$job = Get-CloudStack -cloudStack $cloud -command createSecurityGroup -options $options
		$securityGroup =  $job.createsecuritygroupresponse
		$securityGroupId = $securityGroup.SecurityGroup.ID
		$securityGroupName = $securityGroup.SecurityGroup.name
		
		write-host "Security Group $securityGroupName is associated with Security Group ID $securityGroupId"
		return $securityGroupId
	}else{
		Write-Host "The security Group with the name $name exist. the associate ID is $id"
		return $id
	}
}
else {
	Write-Error "Please configure the $env:userprofile\cloud-settings.txt file"
}