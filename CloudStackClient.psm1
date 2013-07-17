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
# SIG # Begin signature block
# MIIM5AYJKoZIhvcNAQcCoIIM1TCCDNECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7fSJYOUBKUMZ9MkBARniCGar
# 4wSgggogMIIENjCCAx6gAwIBAgIDBHpTMA0GCSqGSIb3DQEBBQUAMD4xCzAJBgNV
# BAYTAlBMMRswGQYDVQQKExJVbml6ZXRvIFNwLiB6IG8uby4xEjAQBgNVBAMTCUNl
# cnR1bSBDQTAeFw0wOTAzMDMxMjUzNTZaFw0yNDAzMDMxMjUzNTZaMHgxCzAJBgNV
# BAYTAlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYD
# VQQLEx5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxHDAaBgNVBAMTE0Nl
# cnR1bSBMZXZlbCBJSUkgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCfUZZcS3wuSUcINT8L7UkdKmpeWGhNCNc/eJdyMUTcYZT1lOnTzZ0drfHk+QeR
# +f6kCZz7x54x4xsD3Pz1xUsiqa26p+GVZWOsK+KA/WF2Z+jEpDz+dOh2eB5JpRR5
# 3HSmn7YSiq4NWfxagCWYwEic28sPd+eG9bLH1k67h1AGTnb1t4wof1/i2uowieRE
# hu5V95V57wyIyn//XyUS7ymkw9/IUZ6LEJVX+urdN71Kpl9qlUXXvPOVUrMU8w6J
# OhO7gEA8y6D6jtKmRHLcN/4Ug+0Ag/GQEfwO8UPsbfBzA8sMfteClhw3zufuKGSr
# tW8GWqAESrYNe1Wce2sYwlrHAgMBAAGjggEBMIH+MA8GA1UdEwEB/wQFMAMBAf8w
# DgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBQEydqa3EpJd68wAwRmLsfO8vgXfTBS
# BgNVHSMESzBJoUKkQDA+MQswCQYDVQQGEwJQTDEbMBkGA1UEChMSVW5pemV0byBT
# cC4geiBvLm8uMRIwEAYDVQQDEwlDZXJ0dW0gQ0GCAwEAIDAsBgNVHR8EJTAjMCGg
# H6AdhhtodHRwOi8vY3JsLmNlcnR1bS5wbC9jYS5jcmwwOgYDVR0gBDMwMTAvBgRV
# HSAAMCcwJQYIKwYBBQUHAgEWGWh0dHBzOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJ
# KoZIhvcNAQEFBQADggEBAIvCzDjOR2ApbA5IvG47OAoN4BefeTwRspwdkMm9vwOi
# WfKwVOI7kh+pb2MiF5xYpEEdYeuZJCjwcMcqzOgZ4CiQXOQ0kdFQaPxuxX9kijCP
# hm0sWVRimGGiXSs7KLBx/vRcaFjm/NNhlwQ6z+yx3XIfc26Zc8hqpF993Z2ei4x7
# 6sXsd/dkDu3u5a1GzBplTq9EHW5nZENquQxv1gQfX+Ua4Dmp9a/9tchmbDMPc+VD
# IaT99SO1cfHS7OyzUX0Ew7mZfEyeRo3N9GP8To60q8eCyJNuBEySttNcHmGKKiM2
# bjjSPqSvHnXaJTMwWP7o0/krJu183xKbIVOaDLEafn4wggXiMIIEyqADAgECAhAv
# /YSKXmZoxaRNWZNPXdP9MA0GCSqGSIb3DQEBBQUAMHgxCzAJBgNVBAYTAlBMMSIw
# IAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0
# dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxHDAaBgNVBAMTE0NlcnR1bSBMZXZl
# bCBJSUkgQ0EwHhcNMTMwNzE3MTI1NzI1WhcNMTQwNzE3MTI1NzI1WjCBiDELMAkG
# A1UEBhMCVVMxEzARBgNVBAoMCkplZmYgTU9PRFkxFDASBgNVBAsMC0RldmVsb3Bt
# ZW50MSowKAYDVQQDDCFPcGVuIFNvdXJjZSBEZXZlbG9wZXIsIEplZmYgTW9vZHkx
# IjAgBgkqhkiG9w0BCQEWE2ZpZnRoZWNob0BnbWFpbC5jb20wggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQC5dl5NODAQfPntbEWCLrd4ctcx4Qb0oM2MF/y7
# mEByQEf7R8z4PND9aRA2pIUquACcIWToOQJZk775bctKevcvCLjwGs9MrU4xUO7T
# iUYFgEdBTaGBJ6u4Y5DvvOjCSyykwk/h5CMF7xHi/qxpHWGuJw1Vf74f3ud+kebr
# Z1S1lBuJVppsAPB5UJx12mkingVx/A/rUiJBHvrXOV3ytb5BNLXzSLosc/lL4wqe
# XylQgDFHIV/0AKat/tNel51NyGCblmsfj9mfmvBcYMvkVmGfr0g7RukpBbaPtsOC
# cuKOR9CZxsiPOWtA/zhg8vSrHjza6Thp02iUDM8p2dOg7bY1AgMBAAGjggJVMIIC
# UTAMBgNVHRMBAf8EAjAAMCwGA1UdHwQlMCMwIaAfoB2GG2h0dHA6Ly9jcmwuY2Vy
# dHVtLnBsL2wzLmNybDBaBggrBgEFBQcBAQROMEwwIQYIKwYBBQUHMAGGFWh0dHA6
# Ly9vY3NwLmNlcnR1bS5wbDAnBggrBgEFBQcwAoYbaHR0cDovL3d3dy5jZXJ0dW0u
# cGwvbDMuY2VyMB8GA1UdIwQYMBaAFATJ2prcSkl3rzADBGYux87y+Bd9MB0GA1Ud
# DgQWBBRS8nBI0vu37LFwwFEDyuRjzaorXjAOBgNVHQ8BAf8EBAMCB4AwggE9BgNV
# HSAEggE0MIIBMDCCASwGCiqEaAGG9ncCAgMwggEcMCUGCCsGAQUFBwIBFhlodHRw
# czovL3d3dy5jZXJ0dW0ucGwvQ1BTMIHyBggrBgEFBQcCAjCB5TAgFhlVbml6ZXRv
# IFRlY2hub2xvZ2llcyBTLkEuMAMCAQcagcBVc2FnZSBvZiB0aGlzIGNlcnRpZmlj
# YXRlIGlzIHN0cmljdGx5IHN1YmplY3RlZCB0byB0aGUgQ0VSVFVNIENlcnRpZmlj
# YXRpb24gUHJhY3RpY2UgU3RhdGVtZW50IChDUFMpIGluY29ycG9yYXRlZCBieSBy
# ZWZlcmVuY2UgaGVyZWluIGFuZCBpbiB0aGUgcmVwb3NpdG9yeSBhdCBodHRwczov
# L3d3dy5jZXJ0dW0ucGwvcmVwb3NpdG9yeS4wEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# EQYJYIZIAYb4QgEBBAQDAgQQMA0GCSqGSIb3DQEBBQUAA4IBAQCbRoh80RxN9lUP
# MZJezyTvx9aQmjrwM5MqOlwkx17oj0pqSC3V6YF3E9EAvuo2oTg6pv1mQpnWBhb9
# xUn49kkCGNX10pIH5WS3kRxM7s5VU2cpbPHyCm2t4WDTkPA4Kjkr1B/RTljExH4n
# id/3tksQTUdTtiWZLthqWDYJki0GjKeH9ouBR6VcbOCa6Pm657OqMARzfU82SXJE
# tsJPQdAuNGcn5AYLIdIeZz+axJC68SqTU9NmL7bplBPOwzOay+Si0vhxL5ZOtlpe
# TsRSqj57Gpf1Bt8xoFex7z4ub+qIfULM6cIgqVfK5+Ef6nLljD7/K4byCrdRzolL
# rvNE8ltmMYICLjCCAioCAQEwgYwweDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVu
# aXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eTEcMBoGA1UEAxMTQ2VydHVtIExldmVsIElJSSBDQQIQ
# L/2Eil5maMWkTVmTT13T/TAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU385nsCdxFHGJRoBQt/Ip
# dOf10MIwDQYJKoZIhvcNAQEBBQAEggEAuSVlfDPtS6dyIYXPtlo9bDJqYttCRndj
# k8BhVQ5mohu9+z5E3IFL6q9NBeQZiE718sXwCWQJzvkrbJnZ23kFxhTJa0EpqOCo
# E9TxDl+V5JlL6MMhD/XLtVbEtteCMzB1e4WuCbDyL/WWUaybWyx04PG8ypaPVxzO
# 5CKmR/NE2D+SNdDKLFlYfZ0iRexwhSoa7bMnpu1UblodZJ4woHuL7uWGbiREhss+
# ImsIAfzOr6DU+b185KSi02rcvm+it+p9T9CYN9l4UbaLfIUQGp4mYJvQmK9qb6CJ
# xNI1itDAM3boHuoAXCmzjcBlH3SA8z7SZqESUOthkuED8l9RsNeMaA==
# SIG # End signature block
