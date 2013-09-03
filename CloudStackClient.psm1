<#
.SYNOPSIS
   A CloudStack/CloudPlatform API client.
.DESCRIPTION
   A feature-rich Apache CloudStack/Citrix CloudPlatform API client for issuing commands to the Cloud Management system.
.PARAMETER command
   The command parameter is MANDATORY and specifies which command you are wanting to run against the API.
.PARAMETER options
   Optional command options that can be passed in to commands.

#>
# Writen by Jeff Moody (fifthecho@gmail.com)
# Based off code written by Takashi Kanai (anikundesu@gmail.com)
#
# 2011/9/16  v1.0 created
# 2013/5/13  v1.1 created to work with CloudPlatform 3.0.6 and migrated to entirely new codebase for maintainability and readability.
# 2013/5/17  v2.0 created to modularize everything.
# 2013/6/20  v2.1 created to add Powershell 2 support
# 2013/9/03  v2.5 created to add better error handling

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
            $Response = Invoke-RestMethod -Uri $URL -Method Get -ErrorAction Stop -ErrorVariable ErrorOut
            Write-Debug $Response
        }
        else {
            $httpWebRequest = [System.Net.WebRequest]::Create($URL);
            $httpWebRequest.Method = "GET";  
            $httpWebRequest.Headers.Add("Accept-Language: en-US");
            try {
                $httpWebResponse = $httpWebRequest.GetResponse();
            }
            catch [System.Net.WebException] {
                $ErrorOut = $_.Exception.Response
            }
            $responseStream = $httpWebResponse.GetResponseStream();
            $streamReader = New-Object System.IO.StreamReader($responseStream);
            $temp = $streamReader.ReadToEnd();
            $Response = [xml]$temp

            $responseStream.Close();
            $streamReader.Close();
            $httpWebResponse.Close(); 
            Write-Debug $Response
        }
    }
    catch{
        Write-Error "ERROR!"
        $errorType = $ErrorOut.GetType()
        if ($errorType.Name -eq "ArrayList") {
            Write-Error $ErrorOut[0]
        }
        else {
            Write-Error $ErrorOut
        }
        Write-Error "If this is unclear, please go to $URL in a browser for the API response."
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
        Write-Output "[general]`n" | Out-File $ChkFile
        Add-Content $ChkFile "Address=http://(your URL):8080/client/api`n"
        Add-Content $ChkFile "ApiKey=(Your API Key)`n"
        Add-Content $ChkFile "SecretKey=(Your Secret Key)"
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

function Get-CloudStackUserData{
    Param(
    [Parameter(Mandatory=$true)]
        [String]
        $userdata
    )
    Write-Debug "User Data: $userdata"
    $userdatab64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userdata))
    Write-Debug "Base64 Encoded User Data: $userdatab64"
    $encodeduserdata = [System.Web.HttpUtility]::UrlEncode($userdatab64)
    return $encodeduserdata
}
Export-ModuleMember -Function Get-CloudStackUserData
# SIG # Begin signature block
# MIIRpQYJKoZIhvcNAQcCoIIRljCCEZICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPcjDg3UGE3jVF/oqG+qklaq8
# Tv+ggg3aMIIGcDCCBFigAwIBAgIBJDANBgkqhkiG9w0BAQUFADB9MQswCQYDVQQG
# EwJJTDEWMBQGA1UEChMNU3RhcnRDb20gTHRkLjErMCkGA1UECxMiU2VjdXJlIERp
# Z2l0YWwgQ2VydGlmaWNhdGUgU2lnbmluZzEpMCcGA1UEAxMgU3RhcnRDb20gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMDcxMDI0MjIwMTQ2WhcNMTcxMDI0MjIw
# MTQ2WjCBjDELMAkGA1UEBhMCSUwxFjAUBgNVBAoTDVN0YXJ0Q29tIEx0ZC4xKzAp
# BgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmljYXRlIFNpZ25pbmcxODA2BgNV
# BAMTL1N0YXJ0Q29tIENsYXNzIDIgUHJpbWFyeSBJbnRlcm1lZGlhdGUgT2JqZWN0
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyiOLIjUemqAbPJ1J
# 0D8MlzgWKbr4fYlbRVjvhHDtfhFN6RQxq0PjTQxRgWzwFQNKJCdU5ftKoM5N4YSj
# Id6ZNavcSa6/McVnhDAQm+8H3HWoD030NVOxbjgD/Ih3HaV3/z9159nnvyxQEckR
# ZfpJB2Kfk6aHqW3JnSvRe+XVZSufDVCe/vtxGSEwKCaNrsLc9pboUoYIC3oyzWoU
# TZ65+c0H4paR8c8eK/mC914mBo6N0dQ512/bkSdaeY9YaQpGtW/h/W/FkbQRT3sC
# pttLVlIjnkuY4r9+zvqhToPjxcfDYEf+XD8VGkAqle8Aa8hQ+M1qGdQjAye8OzbV
# uUOw7wIDAQABo4IB6TCCAeUwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC
# AQYwHQYDVR0OBBYEFNBOD0CZbLhLGW87KLjg44gHNKq3MB8GA1UdIwQYMBaAFE4L
# 7xqkQFulF2mHMMo0aEPQQa7yMD0GCCsGAQUFBwEBBDEwLzAtBggrBgEFBQcwAoYh
# aHR0cDovL3d3dy5zdGFydHNzbC5jb20vc2ZzY2EuY3J0MFsGA1UdHwRUMFIwJ6Al
# oCOGIWh0dHA6Ly93d3cuc3RhcnRzc2wuY29tL3Nmc2NhLmNybDAnoCWgI4YhaHR0
# cDovL2NybC5zdGFydHNzbC5jb20vc2ZzY2EuY3JsMIGABgNVHSAEeTB3MHUGCysG
# AQQBgbU3AQIBMGYwLgYIKwYBBQUHAgEWImh0dHA6Ly93d3cuc3RhcnRzc2wuY29t
# L3BvbGljeS5wZGYwNAYIKwYBBQUHAgEWKGh0dHA6Ly93d3cuc3RhcnRzc2wuY29t
# L2ludGVybWVkaWF0ZS5wZGYwEQYJYIZIAYb4QgEBBAQDAgABMFAGCWCGSAGG+EIB
# DQRDFkFTdGFydENvbSBDbGFzcyAyIFByaW1hcnkgSW50ZXJtZWRpYXRlIE9iamVj
# dCBTaWduaW5nIENlcnRpZmljYXRlczANBgkqhkiG9w0BAQUFAAOCAgEAcnMLA3Va
# N4OIE9l4QT5OEtZy5PByBit3oHiqQpgVEQo7DHRsjXD5H/IyTivpMikaaeRxIv95
# baRd4hoUcMwDj4JIjC3WA9FoNFV31SMljEZa66G8RQECdMSSufgfDYu1XQ+cUKxh
# D3EtLGGcFGjjML7EQv2Iol741rEsycXwIXcryxeiMbU2TPi7X3elbwQMc4JFlJ4B
# y9FhBzuZB1DV2sN2irGVbC3G/1+S2doPDjL1CaElwRa/T0qkq2vvPxUgryAoCppU
# FKViw5yoGYC+z1GaesWWiP1eFKAL0wI7IgSvLzU3y1Vp7vsYaxOVBqZtebFTWRHt
# XjCsFrrQBngt0d33QbQRI5mwgzEp7XJ9xu5d6RVWM4TPRUsd+DDZpBHm9mszvi9g
# VFb2ZG7qRRXCSqys4+u/NLBPbXi/m/lU00cODQTlC/euwjk9HQtRrXQ/zqsBJS6U
# J+eLGw1qOfj+HVBl/ZQpfoLk7IoWlRQvRL1s7oirEaqPZUIWY/grXq9r6jDKAp3L
# ZdKQpPOnnogtqlU4f7/kLjEJhrrc98mrOWmVMK/BuFRAfQ5oDUMnVmCzAzLMjKfG
# cVW/iMew41yfhgKbwpfzm3LBr1Zv+pEBgcgW6onRLSAn3XHM0eNtz+AkxH6rRf6B
# 2mYhLEEGLapH8R1AMAo4BbVFOZR5kXcMCwowggdiMIIGSqADAgECAgIKdjANBgkq
# hkiG9w0BAQUFADCBjDELMAkGA1UEBhMCSUwxFjAUBgNVBAoTDVN0YXJ0Q29tIEx0
# ZC4xKzApBgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmljYXRlIFNpZ25pbmcx
# ODA2BgNVBAMTL1N0YXJ0Q29tIENsYXNzIDIgUHJpbWFyeSBJbnRlcm1lZGlhdGUg
# T2JqZWN0IENBMB4XDTEzMDcxNzIyMzE1NloXDTE1MDcxODE2MDgzN1owgY4xGTAX
# BgNVBA0TEHE3cWM5c0FUQ3l5eXJyMzMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpO
# ZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEVMBMGA1UEAxMMUm9iZXJ0
# IE1vb2R5MSIwIAYJKoZIhvcNAQkBFhNmaWZ0aGVjaG9AZ21haWwuY29tMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAwVK+tPtCqiB8S9diZaP6N3PeSw8M
# LE+/xTVl3zo5XsUkou7EDsOO9GduH9wtKuDRwnhgbVKi9Rn+SS7WaYpIAel0UCye
# 3iIilkx02bWfjwi/MIdHKUjEJDHj/D3Js4tT2lz4pUO/YTM3e2mtjqAJ12f0wZnc
# Q0R65gHaPLsMMhj3mOZ7K9HHZAHvCKjrh5ZWDm6ma8zm+SMx8f22i/cxbIis5j7A
# 8EBu0AOvxiDCCj0ed7cF5N2aRpq9xFuqLXEGeGh0rCjt1CExKWXBdY8jXdg9YYWU
# Zo7kc/ZlekZVrSw3i1FG0rCDQKtACb8ZtEpf+qUZeNkIRbn1bZL1fWxWbZSu1j9S
# QVS2ppfUIZCiK8SE9RfKr0onUtTjSNG7QsPZbKFsbOU3zNFwpTsxiFRz+G9Lo3IK
# 01Cv2K2bBmaY0+uOGI8C00jd6dsSdctuEm1pdxVhhQTeoZlMVjTSP9AFeCWZmwh0
# to2DVLoZM5FwTRLmp3BR49URgHxbaOdZ7V0XQdAGzt2CT2ajAAO89lA0ThAU+eTt
# cSMVrCbnHN/92UgDD7ducn/VfoviKue3ni6zIF3a+V9EabhEVrpfgb9cksLSSPlI
# m16X/xkZS7aM0lM7pP+hJl7WbXhuQ8FZYP2O+ojYHluZxOFMOdFgktpbcJ5mZmsK
# YAsB9pZxbMaRjaECAwEAAaOCAsgwggLEMAkGA1UdEwQCMAAwDgYDVR0PAQH/BAQD
# AgeAMC4GA1UdJQEB/wQkMCIGCCsGAQUFBwMDBgorBgEEAYI3AgEVBgorBgEEAYI3
# CgMNMB0GA1UdDgQWBBTufJ1HUVFvYEYOZO4GqloTYH3huzAfBgNVHSMEGDAWgBTQ
# Tg9AmWy4SxlvOyi44OOIBzSqtzCCAUwGA1UdIASCAUMwggE/MIIBOwYLKwYBBAGB
# tTcBAgMwggEqMC4GCCsGAQUFBwIBFiJodHRwOi8vd3d3LnN0YXJ0c3NsLmNvbS9w
# b2xpY3kucGRmMIH3BggrBgEFBQcCAjCB6jAnFiBTdGFydENvbSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eTADAgEBGoG+VGhpcyBjZXJ0aWZpY2F0ZSB3YXMgaXNzdWVk
# IGFjY29yZGluZyB0byB0aGUgQ2xhc3MgMiBWYWxpZGF0aW9uIHJlcXVpcmVtZW50
# cyBvZiB0aGUgU3RhcnRDb20gQ0EgcG9saWN5LCByZWxpYW5jZSBvbmx5IGZvciB0
# aGUgaW50ZW5kZWQgcHVycG9zZSBpbiBjb21wbGlhbmNlIG9mIHRoZSByZWx5aW5n
# IHBhcnR5IG9ibGlnYXRpb25zLjA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vY3Js
# LnN0YXJ0c3NsLmNvbS9jcnRjMi1jcmwuY3JsMIGJBggrBgEFBQcBAQR9MHswNwYI
# KwYBBQUHMAGGK2h0dHA6Ly9vY3NwLnN0YXJ0c3NsLmNvbS9zdWIvY2xhc3MyL2Nv
# ZGUvY2EwQAYIKwYBBQUHMAKGNGh0dHA6Ly9haWEuc3RhcnRzc2wuY29tL2NlcnRz
# L3N1Yi5jbGFzczIuY29kZS5jYS5jcnQwIwYDVR0SBBwwGoYYaHR0cDovL3d3dy5z
# dGFydHNzbC5jb20vMA0GCSqGSIb3DQEBBQUAA4IBAQBlwx5+nm+gS06O8axJTEyU
# 6oeUrrB1RhN8YrJPnXDIM7GwP0B1YoxXYqQdU+k/PHpLxHKSs7wF3GxeOCsfhJfQ
# GzGqrsQ5AQz4WbHl9kdpJG5678aDv5yWyuJrhwMIQJQKxgGZRaM/I0rzeOSUAO6E
# ePjxQMhWDtaHay9ZwQ7T226bFhhZa4Tplyv4okT16QLfqWiXtNDQM9CHapKw8c6s
# IVrEkglhB2/A3JbNrStIeB4H002jSsW5uZqQlWE80oUl5ViaroCd5J+NeXLrta1y
# ZYel/EOVw7uObqw9Bvl1w05jRhEd3+ujmvOPBK/fKXUeWhI41xGbHueUdVjn9Iqq
# MYIDNTCCAzECAQEwgZMwgYwxCzAJBgNVBAYTAklMMRYwFAYDVQQKEw1TdGFydENv
# bSBMdGQuMSswKQYDVQQLEyJTZWN1cmUgRGlnaXRhbCBDZXJ0aWZpY2F0ZSBTaWdu
# aW5nMTgwNgYDVQQDEy9TdGFydENvbSBDbGFzcyAyIFByaW1hcnkgSW50ZXJtZWRp
# YXRlIE9iamVjdCBDQQICCnYwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAI
# oAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIB
# CzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFAFtr3kv2I/tFMpABPaw
# NqaH1ZbgMA0GCSqGSIb3DQEBAQUABIICAJvuWaDQeUqDCMXKKnD0JmGc/oHP+byV
# 65rnNNAczPlxlnP5HOu1Su2qbkd+G4B0IexWSEQbHHqQa7lT1APmImiuLcxTtsQz
# 2PnNizvA7HzgA8aa8Iayok1AApYmSEHuAAJXEf7qp4IOkzHYS8ThrOWUXGIhJQVT
# 4uHxD2CZLwEbpmd1h3yWmt487ApBfDP0SmDSmp0VmnlToKhlrXbO2fD9OpV/75AN
# D+VcdVwUpfMGbujYxw8tiyHPAESj8c579P4yBmbezvSf6Ld5KdINEL2VJiklH2Gv
# +52pY7kyzIYdy01AiphqoJrvkYV+g9VCohl0/OvxAaXZB1vWITrricn3yyJNzs3g
# Phy+Mbi/WhfsJkyxGVVUY0rpGtDYlKf2MB8SjICF0CUS2fFhalNwsSGGkaIx4pel
# r4PNGAEgHpwgzyWDZ41SlOzucjqmvLPXEWzWmQwhugDajrvwGb7LaxlkfCfAJXaY
# nzoQoCCaeF8L35+7bo9nyVsI/fESCnTbDoWf9LH4QbYOLgWOkQLooCODVlxYLbRo
# WsfX5l6rePcCtLBoOLGTrNLhAHPqLoR0wQ7eSEf07XcwOuwpo/bmLfo6WfqJAmOz
# /saCE2yWxZeTRRlcUWyYc7TDBHD82uBkvW100RjI3O+y39kPM0tE4pnsW9br8JsG
# QnhcrnyGdQwB
# SIG # End signature block
