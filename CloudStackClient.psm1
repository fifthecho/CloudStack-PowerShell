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
# Writen by Jeff Moody (fifthecho@gmail.com)
# Based off code written by Takashi Kanai (anikundesu@gmail.com)
#
# 2011/9/16  v1.0 created
# 2013/5/13  v1.1 created to work with CloudPlatform 3.0.6 and migrated to entirely new codebase for maintainability and readability.
# 2013/5/17  v2.0 created to modularize everything.
# 2013/6/20  v2.1 created to add Powershell 2 support

[VOID][System.Reflection.Assembly]::Load("System.Web, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a");
$WebClient = New-Object net.WebClient

function New-CloudStack{
	Param(
			[Parameter(Mandatory = $true)]
	        [String] $apiEndpoint
		,
			[Parameter(Mandatory = $true)]
	        [String] $apiPublicKey
		,
	        [Parameter(Mandatory = $true)]
	        [String] $apiSecretKey
		)
	$cloudStack = @()
	$cloudStack += $apiEndpoint
	$cloudStack += $apiPublicKey
	$cloudStack += $apiSecretKey
	return $cloudStack
}
Export-ModuleMember -Function New-CloudStack

function calculateSignature{
	Param(
		[Parameter(Mandatory=$true)]
		[String[]]
		$SECRET_KEY
	,
		[Parameter(Mandatory=$true)]
		[String]
	    $HASH_STRING
	)
	Write-Debug("Hash String:  $HASH_STRING")
	Write-Debug("Signature:    $SECRET_KEY")
	$HMAC_SHA1 = New-Object System.Security.Cryptography.HMACSHA1
	$HMAC_SHA1.key = [Text.Encoding]::ASCII.GetBytes($SECRET_KEY)
	$Digest = $HMAC_SHA1.ComputeHash([Text.Encoding]::ASCII.GetBytes($HASH_STRING))
	$Base64Digest = [System.Convert]::ToBase64String($Digest)  
	$signature = [System.Web.HttpUtility]::UrlEncode($Base64Digest)
	
	Write-Debug("Digest:       $Base64Digest")
	Write-Debug("Signature:    $signature")
	return $signature
}


function Get-CloudStack{
	Param(
		[Parameter(Mandatory=$true)]
		[String[]]
		$cloudStack
	,
		[Parameter(Mandatory=$true)]
		[String]
	    $command
	,
		[String[]]
	    $options
	)
	
	$ADDRESS = $cloudStack[0]
	$API_KEY = $cloudStack[1]
	$SECRET_KEY = $cloudStack[2]
	$URL=$ADDRESS+"?apikey="+($API_KEY)+"&"+"command="+$command
	$optionString="apikey="+($API_KEY)+"&"+"command="+$command
	$options += "response=xml"
    $options = $options | Sort-Object
	foreach($o in $options){
	    $o = $o -replace " ", "%20"
	    $optionString += "&"+$o
        $URL += "&"+$o
	}
    Write-Debug("Pre-signed URL: $URL")
    Write-Debug("Option String: $optionString")
	$signature = calculateSignature -SECRET_KEY $SECRET_KEY -HASH_STRING $optionString.ToLower()
	$URL += "&signature="+$signature
	Write-Debug("URL: $URL")
    $Response = ""
    try {
        if ($psversiontable.psversion.Major -ge 3) {
    	    $Response = Invoke-RestMethod -Uri $URL -Method Get
        }
        else {
            $httpWebRequest = [System.Net.WebRequest]::Create($URL);
            $httpWebRequest.Method = "GET";  
            $httpWebRequest.Headers.Add("Accept-Language: en-US");

            $httpWebResponse = $httpWebRequest.GetResponse();
            $responseStream = $httpWebResponse.GetResponseStream();
            $streamReader = New-Object System.IO.StreamReader($responseStream);
            $temp = $streamReader.ReadToEnd();
            $Response = [xml]$temp

            $responseStream.Close();
            $streamReader.Close();
            $httpWebResponse.Close(); 
        }
    }
    catch{
        Write-Host "ERROR!"
    }
    Write-Debug "Response: $Response"
	return $Response
	
}

Export-ModuleMember -Function Get-CloudStack

function Import-CloudStackConfig{
	# Read configuration values for API Endpoint and keys
	$ChkFile = "$env:userprofile\cloud-settings.txt" 
	$FileExists = (Test-Path $ChkFile -PathType Leaf)

	If (!($FileExists)) 
	{
		Write-Error "Config file does not exist. Writing a basic config that you now need to customize."
        Write-Output "[general]" | Out-File $ChkFile
        Add-Content $ChkFile "`nAddress=http://(your URL):8080/client/api"
        Add-Content $ChkFile "`nApiKey=(Your API Key)"
        Add-Content $ChkFile "`nSecretKey=(Your Secret Key)"
		Return 1
	}
	ElseIf ($FileExists)
	{
		Get-Content "$env:userprofile\cloud-settings.txt" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
		$ADDRESS=$h.Get_Item("Address")
		$API_KEY=$h.Get_Item("ApiKey")
		$SECRET_KEY=$h.Get_Item("SecretKey")
		Write-Debug "Address: $ADDRESS"
		Write-Debug "API Key: $API_KEY"
		Write-Debug "Secret Key: $SECRET_KEY"
		$config = @()
		$config += $ADDRESS
		$config += $API_KEY
		$config += $SECRET_KEY
		if (($ADDRESS -ne "http://(your URL:8080/client/api?") -and ($API_KEY -ne "(Your API Key)") -and ($SECRET_KEY -ne "(Your Secret Key)")) {
			return $config
		}
		else {
			Write-Error "Please configure the $env:userprofile\cloud-settings.txt file"
			return 1
		}
	}
}

Export-ModuleMember -Function Import-CloudstackConfig