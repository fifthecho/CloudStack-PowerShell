<#
.SYNOPSIS
   A CloudStack/CloudPlatform Volume Snapshot History Manager.
.DESCRIPTION
   A feature-rich Apache CloudStack/Citrix CloudPlatform API client for issuing commands to the Cloud Management system.
.PARAMETER volume
   The volume parameter is MANDATORY and specifies which volume you are wanting to manage the snapshots of.
.PARAMETER days
   The number of days prior to today that you want to keep snapshots for.
.EXAMPLE
   CloudStackSnapshotHistoryManager.ps1 -volume da0018ed-ce52-4d37-a5fb-6f121eb503c3 -days 7
#>
# Writen by Jeff Moody (fifthecho@gmail.com)
#
# 2011/5/15  v1.0 created


Param(
	[Parameter(Mandatory=$true)]
	[String]
    $volume
,
    [Parameter(Mandatory=$true)]
    [Int]
    $days
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
        $Response
        return
}

$job = CloudStackClient -command listSnapshots -options volumeid=$volume

$snapshots = $job.listsnapshotsresponse.snapshot
$days = 0 - $days

$purgeDate = [DateTime]::Today.AddDays($days).DayOfYear

foreach($snap in $snapshots){
    Write-Debug $snap
    if ([DateTime]::Parse($snap.created).DayOfYear -lt $purgeDate){
        $snapDate = [DateTime]::Parse($snap.created).ToShortDateString()
        $snapID = $snap.id
        Write-Host "Deleting Snapshot $snapID from $snapDate."
        $deleteJob = CloudStackClient -command deleteSnapshot -options id=$snapID
        Write-Debug "Delete job: $deleteJob"
        }
    
}
