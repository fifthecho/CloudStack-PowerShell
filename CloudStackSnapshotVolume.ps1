<#
.SYNOPSIS
   A CloudStack/CloudPlatform Volume Snapshot Agent.
.DESCRIPTION
   A feature-rich Apache CloudStack/Citrix CloudPlatform API client for issuing commands to the Cloud Management system.
.PARAMETER volume
   The volume parameter is MANDATORY and specifies which volume you are wanting to take a snapshot of.
.EXAMPLE
   CloudStackSnapshot.ps1 -volume da0018ed-ce52-4d37-a5fb-6f121eb503c3
#>
# Writen by Jeff Moody (fifthecho@gmail.com)
#
# 2011/9/16  v1.0 created
# 2013/5/13  v1.1 created to work with CloudPlatform 3.0.6 and migrated to entirely new codebase for maintainability and readability.

Param(
	[Parameter(Mandatory=$true)]
	[String]
    $volume
)

function CloudStackClient
{
            <#
        .SYNOPSIS
           A CloudStack/CloudPlatform API client.
        .DESCRIPTION
           A feature-rich Apache CloudStack/Citrix CloudPlatform API client for issuing commands to the Cloud Management system.
        .PARAMETER command
           The command parameter is MANDATORY and specifies which command you are wanting to run against the API.
        .PARAMETER options
           Optional command options that can be passed in to commands.
        .EXAMPLE
           CloudStackClient.ps1 -command listVirtualMachines -options zoneid=c3132929-9e55-443c-bce1-33b73faef801
        #>
        # Writen by Takashi Kanai (anikundesu@gmail.com), Jeff Moody (fifthecho@gmail.com)
        #
        # 2011/5/14  v1.0 created

        Param(
	        [Parameter(Mandatory=$true)]
	        [String]
            $command
          ,
	        [String[]]
            $options
        )

        [VOID][System.Reflection.Assembly]::Load("System.Web, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a");
        $WebClient = New-Object net.WebClient

        # Read configuration values for API Endpoint and keys
        $ChkFile = "$env:userprofile\cloud-settings.txt" 
        $FileExists = (Test-Path $ChkFile -PathType Leaf)

        If (!($FileExists)) 
        {
	        Write-Host "Config file does not exist. Writing a basic config that you now need to customize."
	        Write-Output "[general]" | Out-File "$env:userprofile\cloud-settings.txt"
	        Write-Output "Address=http://(your URL):8080/client/api?" | Out-File "$env:userprofile\cloud-settings.txt"
	        Write-Output "ApiKey=(Your API Key)" | Out-File "$env:userprofile\cloud-settings.txt"
	        Write-Output "SecretKey=(Your Secret Key)" | Out-File "$env:userprofile\cloud-settings.txt"
	        Write-Output "Format=(XML/JSON)" >> "$env:userprofile\cloud-settings.txt"
	        Return 1
        }
        ElseIf ($FileExists)
        {
	        Get-Content "$env:userprofile\cloud-settings.txt" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }

	        $ADDRESS=$h.Get_Item("Address")
	        $API_KEY=$h.Get_Item("ApiKey")
	        $SECRET_KEY=$h.Get_Item("SecretKey")
	        $FORMAT=$h.Get_Item("Format")
            $formatString = "response=json" 
            $options += $formatString
        
        }
        ### URL Encoding $COMMAND variable
        $URL=$ADDRESS+"?apikey="+($API_KEY)+"&"+"command="+$command
        Write-Debug "URL: $URL"
        $optionString=""
        foreach($o in $options){
            $o = $o -replace " ", "%20"
            $optionString += "&"+$o
        }
        $URL += $optionString

        $hashString = "apikey="+($API_KEY)+"&"+"command="+$command.ToLower()
        $hashOptions = $options|Sort-Object
        foreach($h in $hashOptions) {
            $h = $h -replace " ", "%20"
            $hashString += "&" + $h.ToLower()
        }

        $hashString = $hashString.ToLower()

        Write-Debug "String to calculate hash off of is: $hashString"


        ### Signing Encoded URL with $SECRET_KEY
        $HMAC_SHA1 = New-Object System.Security.Cryptography.HMACSHA1
        $HMAC_SHA1.key = [Text.Encoding]::ASCII.GetBytes($SECRET_KEY)
        $Digest = $HMAC_SHA1.ComputeHash([Text.Encoding]::ASCII.GetBytes($hashString))
        $Base64Digest = [System.Convert]::ToBase64String($Digest)  
        $signature = [System.Web.HttpUtility]::UrlEncode($Base64Digest)
        $URL += "&signature="+$signature

        Write-Debug "Base64Digest: $Base64Digest"
        Write-Debug "Signature: $signature"
        Write-Debug "Final URL: $URL"

        ### Execute API Access & get Response
        # $Response = $WebClient.DownloadString($URL)
        $Response = Invoke-RestMethod -Uri $URL -Method Get
        return $Response
}

$job = CloudStackClient -command createSnapshot -options volumeid=$volume
Write-Debug "Job: $job"
$jobid = $job.createsnapshotresponse.jobid
Write-Host "Started snapshot job $jobid"
do {
    Write-Host -NoNewline "."
    $jobStatus = CloudStackClient -command queryAsyncJobResult -options jobid=$jobid
    Start-Sleep -Seconds 5
    }
while ($jobStatus.queryasyncjobresultresponse.jobstatus -eq 0)
$statusCode = $jobStatus.queryasyncjobresultresponse.jobresultcode
if ($statusCode -ne 0) {
    Write-Error $jobStatus.queryasyncjobresultresponse.jobresult
}
if ($statusCode -ne 0) {
    return $statusCode
}
