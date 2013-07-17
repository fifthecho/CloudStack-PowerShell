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
# 2013/5/15  v1.0 created
# 2013/5/17  v2.0 created to work with CloudStackClient module v 2.0.


Param(
	[Parameter(Mandatory=$true)]
	[String]
    $volume
,
    [Parameter(Mandatory=$true)]
    [Int]
    $days
)

Import-Module CloudStackClient
$parameters = Import-CloudStackConfig

if ($parameters -ne 1) {
	$cloud = New-CloudStack -apiEndpoint $parameters[0] -apiPublicKey $parameters[1] -apiSecretKey $parameters[2]
	$job = Get-CloudStack -cloudStack $cloud -command listSnapshots -options volumeid=$volume

	if($snapshots = $job.listsnapshotsresponse.snapshot){
    	$days = 0 - $days

    	$purgeDate = [DateTime]::Today.AddDays($days).DayOfYear

    	foreach($snap in $snapshots){
    	    Write-Debug $snap
    	    if ([DateTime]::Parse($snap.created).DayOfYear -lt $purgeDate){
    	        $snapDate = [DateTime]::Parse($snap.created).ToShortDateString()
    	        $snapID = $snap.id
    	        Write-Host "Deleting Snapshot $snapID from $snapDate."
    	        $deleteJob = Get-CloudStack -cloudStack $cloud -command deleteSnapshot -options id=$snapID
    	        Write-Debug "Delete job: $deleteJob"
    	        }
    	    
    	}
    }
    else{
        Write-Host "No snapshots for volume $volume to delete."
    }
}
else {
	Write-Error "Please configure the $env:userprofile\cloud-settings.txt file"
}	

# SIG # Begin signature block
# MIIM5AYJKoZIhvcNAQcCoIIM1TCCDNECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBlQKVTNgE92WNGWuT+rVK1Nq
# bH2gggogMIIENjCCAx6gAwIBAgIDBHpTMA0GCSqGSIb3DQEBBQUAMD4xCzAJBgNV
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUIgCMFv01sN3v7XW/lBzN
# WJO4R7YwDQYJKoZIhvcNAQEBBQAEggEAD6rJW3srXMiB4yZdrtk/oQQyj8qIAAjr
# GnTkJz6wSlnllbEGqoqShCdqgTNRrV87rvy6nVADdTguPD0ajJEfj3j9/nSPfWVy
# HOSJrrUHW+xyEFo8G+CYvg7Y0qu+0Nxme505cCeowwtqHRoUqYT1kUkdfLIxLAwR
# 8+KGjGsSXI6COpoLGJoEyQQ6r4pfjvPpRtntwPwIR3cF81X2rpQFaK3yctHUVWuJ
# 7S4JdtMXQUS7A3WjhSk3V4xKfa/2CzDrU5Vnyv4mYkX8k5QN6DPk0TwzxMzMDHyN
# kDcjZYqkJaG8NZFKG6jeJDt1cdDhq0pHmIz5BG7I0qmz54hbOaoSMw==
# SIG # End signature block
