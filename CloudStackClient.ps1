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
   <An example of using the script>
#>

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
	echo "[general]" >> "$env:userprofile\cloud-settings.txt"
	echo "Address=http://(your URL):8080/client/api?" >> "$env:userprofile\cloud-settings.txt"
	echo "ApiKey=(Your API Key)" >> "$env:userprofile\cloud-settings.txt"
	echo "SecretKey=(Your Secret Key)" >> "$env:userprofile\cloud-settings.txt"
	echo "Format=(JSON/XML)" >> "$env:userprofile\cloud-settings.txt"
	Return 1
}
ElseIf ($FileExists)
{
	Get-Content "$env:userprofile\cloud-settings.txt" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }

	$ADDRESS=$h.Get_Item("Address")
	$API_KEY=$h.Get_Item("ApiKey")
	$SECRET_KEY=$h.Get_Item("SecretKey")
	$FORMAT=$h.Get_Item("Format")
    #$formatString = "response=" + $FORMAT.ToLower()
    #$options += $formatString
	echo "Address: "$ADDRESS
	echo "API Key: "$API_KEY
	echo "Secret Key: "$SECRET_KEY
	echo "Format: "$FORMAT
    echo "Command: "$command
    echo "Options: "$options
}
### URL Encoding $COMMAND variable
$URL=$ADDRESS+"?apikey="+($API_KEY)+"&"+"command="+$command
# echo "URL: "$URL
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
echo "String to calculate hash off of is: "$hashString

### Signing Encoded URL with $SECRET_KEY
$HMAC_SHA1 = New-Object System.Security.Cryptography.HMACSHA1
$HMAC_SHA1.key = [Text.Encoding]::ASCII.GetBytes($SECRET_KEY)
$encodedHashString = [System.Web.HttpUtility]::UrlEncode($hashString)
$Digest = $HMAC_SHA1.ComputeHash([Text.Encoding]::ASCII.GetBytes($encodedHashString))
$Base64Digest = [System.Convert]::ToBase64String($Digest)  
$signature = [System.Web.HttpUtility]::UrlEncode($Base64Digest)
$URL += "&signature="+$signature

echo "Base64Digest: " $Base64Digest
echo "Signature: "$signature
echo "Final URL: "$URL