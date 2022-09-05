<#
This script controls the ON/OFF Function of TPLINK Smart Plugs VIA crafted http POST Requests
Initial POST Authenticates with UUID, username and password
The distant server will then generate and return a token
The token is used in all follow-on requests rather than the username and password (ie. Getting device list and switching between on and off)

Unintended feature #1- If you have a tp-link camera, this script will include it in your device list. Attempting to toggle on/off on the camera will only crash the camera.
So don't do that....
#>

function get-username{
    $username= read-host -prompt " "
    return $username
}

function get-password{
    $creds= Get-Credential -UserName $username -Message "Enter Password"
    $SecurePassword= $creds.Password
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    return $unsecurepassword
}

function generate-uuid{
    $letters= @("a","b","c","d","e","f")
    $numbers= 0..9
    
    $uuid= ""
    $uuid= $uuid + "$($numbers | get-random -count 5)" + "$($letters | get-random -Count 2)" + '-'
    $uuid= $uuid + "$($letters | get-random -Count 1)" + "$($numbers | get-random -Count 2)" + "$($letters | get-random -Count 1)" + '-'
    $uuid= $uuid + "$($numbers | get-random -Count 1)" + "$($letters | get-random -count 2)" + "$($numbers | get-random -Count 1)" + '-'
    $uuid= $uuid + "$($letters | get-random -Count 2)" + "$($numbers | get-Random -count 2)" + '-'
    $uuid = $uuid + "$($numbers | get-random -count 3)" + "$($letters | get-random -Count 1)" + "$($numbers | get-random -count 1)" + "$($letters | get-random -count 4)" + "$($numbers | get-random -Count 1)" + "$($letters | get-random -Count 1)"
    $uuid= $uuid-replace(' ','')
    return $uuid
}

function get-token($uuid){
    Write-host "Enter your login username/email for TP-Link cloud"

    $username= get-username
    
    clear-host
    write-host "Enter your password for TP-Link cloud"
    $password= get-password
    clear-host

$header = @{
 "Accept"="application/json"
 "Content-Type"="application/json"
}
 
$body = @"
{"method": "login",
 "params": {
 "appType": "Kasa_Android",
 "cloudUserName": "$username",
 "cloudPassword": "$Password",
 "terminalUUID": "$uuid"
 }
}
"@

    $wr= invoke-webrequest -Uri "https://wap.tplinkcloud.com" -Method 'Post' -Body $body -Headers $header | ConvertTo-HTML

    $invalid= $wr | select-string "Incorrect email or password"
    
    if ($invalid){
        Cclear-host
        write-host "Login Failure. Check your username and password and try again."
        pause
        get-token
    }

    $token= $($($wr.split(';') | select-string '-')[-1]).tostring()
    $token= $($($token.split(';') | select-string '-')[-1]).tostring()-replace('&quot','')
    return $token
}

function get-deviceid($token){
$header = @{
 "Accept"="application/json"
 "Content-Type"="application/json"
}

$body = @'
{"method": "getDeviceList"
}
'@

    $wr= Invoke-WebRequest -uri "https://wap.tplinkcloud.com?token=$token" -Method Post -body $body -Headers $header
    $wr= $($wr.AllElements.innertext | convertto-json).split(',')
    $deviceobj= @()
    $deviceobj+= "Index,Alias,DeviceID"
    $devices= $($wr | select-string "alias" | sort -Unique)

    $x= 1
    foreach ($d in $devices){
        $alias= $($d.tostring().split('"') | where {$_ -ne ':\' -and $_ -ne '\' -and $_ -ne 'alias\'}) | sort -Unique
        $alias= $alias | where {$_}
        $alias= $alias.tostring().trimend('\')

        $config= $wr | select-string $alias -Context (5,5) 
        $deviceid= $($config | convertfrom-csv | select-string deviceId | sort -Unique | select-string '@').tostring()
        $deviceid= $deviceid.split(':')[-1]
        $deviceid= $deviceid.trimstart('\"').TrimEnd('\"}')

        $deviceobj+= "$x, $alias,$deviceid"
        $x++
    }
    $deviceobj= $deviceobj | convertfrom-csv
    $choice= $deviceobj | out-gridview -Title "Choose Device To Control" -PassThru
    $deviceid= $choice.deviceid
    new-variable -name alldevices -value $deviceobj -scope global -ErrorAction SilentlyContinue
    return $deviceid
}

function show-devices{
    $alldevices
}

function show-currentdevice{
    $alldevices | where {$_.deviceid -eq $deviceid}
}   

function change-state([string]$device,[switch]$on, [switch]$off){
    
    if ($off){
        $bin= "0"
        new-variable -name state -Value "off" -Scope global
    }

    if ($on){
        $bin= "1"
        new-variable -name state -Value "on" -Scope global
    }

    if ($on -and $off){
        break
    }

    if ($device){
        $deviceid= $($alldevices | where {$_.alias -eq "$device"}).deviceid
    }

    $header = @{
 "Accept"="application/json"
 "Content-Type"="application/json"
}

$body= @"
{"method": "passthrough",
 "params": {
 "deviceId": "$deviceid",
 "requestData": {
 "system": {
 "set_relay_state": {
 "state": $bin
    }
   }      
  }
 }
}
"@    
    invoke-webrequest -uri "https://wap.tplinkcloud.com?token=$token" -Method Post -body $body -Headers $header
    clear-host
}

#if the required info hasnt been gathered, get it.
if (!$token){
    new-Variable -name uuid -value $(generate-uuid) -force -ErrorAction SilentlyContinue
    new-variable -name token -value $(get-token $uuid) -force -ErrorAction SilentlyContinue -scope global
}

new-Variable -name deviceid -value $(get-deviceid $token) -Force -ErrorAction SilentlyContinue -Scope global


while ($true){
    clear-host
    $devices= show-devices
    $devicename= $($devices | where {$_.deviceid -eq "$deviceid"}).alias
    write-host "DeviceID: $deviceid"
    write-Host "UUID: $uuid"
    write-host "Token: $token"
    write-Output "Current Device: $devicename"
    write-Output "#######################################"
    write-output "1.) Turn device on"
    write-output "2.) Turn device off"
    write-output "3.) Change device"
    write-Output "4.) Quit interactive mdoe."
    $choice= read-host -prompt " "

    if ($choice -ne 1 -and $choice -ne 2 -and $choice -ne 3 -and $choice -ne 4){
        clear-host
        write-output "Invalid choice"
        sleep 1
        continue
    }
    if ($choice -eq 1){
        change-state -device $devicename -on
    }
    if ($choice -eq 2){
        change-state -device $devicename -off
    }
    if ($choice -eq 3){
        new-Variable -name deviceid -value $(get-deviceid $token) -Force -ErrorAction SilentlyContinue -Scope global
    }
    if ($choice -eq 4){
        clear-host
        write-output "You've quit interactive mode, but can still control the devices form this PowerShell window."
        write-output "Example commands:"
        write-output '>show-currentdevice'
        write-output '>change-state -off'
        write-output '>change-state -on'
        write-output '>show-devices'
        write-output '>chage-state -device "<insert_device_name>" -on'
        write-output '>change-state -device "<insert_device_name>" -off'
        write-output ""
        pause
        $host.enternestedprompt()
    }
}
