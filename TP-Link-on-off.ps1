#On / off control for TP Link. Created using Model#: HS103P3. Will most likely work for other models.

function get-username{
    $username= read-host -prompt " "
    return $username
}

function get-password{
    $password= Read-Host -Prompt " "
    return $password
}

function generate-uuid{
    $letters= @("a","b","c","d","e","f")
    $numbers= 0..9
    
    $uuid= ""
    $uuid= $uuid + "$($numbers | get-random -count 5)" + "$($letters | get-random -Count 2)" + '-'
    $uuid= $uuid + "$($letters | get-random -Count 1)" + "$($numbers | get-random -Count 2)" + "$($letters | get-random -Count 1)" + '-'
    $uuid= $uuid + "$($numbers | Get-Random -Count 1)" + "$($letters | Get-Random -count 2)" + "$($numbers | Get-Random -Count 1)" + '-'
    $uuid= $uuid + "$($letters | get-random -Count 2)" + "$($numbers | Get-Random -count 2)" + '-'
    $uuid = $uuid + "$($numbers | Get-Random -count 3)" + "$($letters | get-random -Count 1)" + "$($numbers | Get-Random -count 1)" + "$($letters | Get-Random -count 4)" + "$($numbers | get-random -Count 1)" + "$($letters | get-random -Count 1)"
    $uuid= $uuid-replace(' ','')
    return $uuid
}

function get-token($uuid){
    clear-host
    write-host "Enter your login username/email for TP-Link cloud"

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
 "cloudPassword": "$password",
 "terminalUUID": "$uuid"
 }
}
"@

    $wr= Invoke-WebRequest -Uri "https://wap.tplinkcloud.com" -Method 'Post' -Body $body -Headers $header | ConvertTo-HTML

    $invalid= $wr | select-string "Incorrect email or password"
    
    if ($invalid){
        clear-host
        write-host "Login Failure. Check your username and password and try again."
        pause
        get-token
    }

    $token= $($($wr.split(';') | sls '-')[-1]).tostring()
    $token= $($($token.split(';') | sls '-')[-1]).tostring()-replace('&quot','')
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

    $wr= Invoke-WebRequest -uri "https://wap.tplinkcloud.com?token=$token" -Method Post -body $body -Headers $header | convertto-html
    $deviceid= $($wr.split(';') | select-string "&quot")
    $deviceid= $($($deviceid | select-string -Pattern "^[0-9]")-replace('&quot',''))[1].tostring()
    return $deviceid
}

function on{
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
 "state": 1
    }
   }      
  }
 }
}
"@      
    Invoke-WebRequest -uri "https://wap.tplinkcloud.com?token=$token" -Method Post -body $body -Headers $header
    clear-host
    write-host "DeviceID: $deviceid"
    Write-Host "UUID: $uuid"
    write-host "Token: $token"
    write-host "State: ON"
}

function off{
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
 "state": 0
    }
   }      
  }
 }
}
"@    
    Invoke-WebRequest -uri "https://wap.tplinkcloud.com?token=$token" -Method Post -body $body -Headers $header

    clear-host
    write-host "DeviceID: $deviceid"
    Write-Host "UUID: $uuid"
    write-host "Token: $token"
    write-host "State: OFF"
}

#if the required info hasnt been gathered, get it.
if (!$deviceid){
    New-Variable -name uuid -value $(generate-uuid) -force -ErrorAction SilentlyContinue
    new-variable -name token -value $(get-token $uuid) -force -ErrorAction SilentlyContinue -scope global
    New-Variable -name deviceid -value $(get-deviceid $token) -Force -ErrorAction SilentlyContinue -Scope global
}

#main
while ($true){
   #shedule
   #do whatever you want in here. Be creative :)
   on
   sleep 5
   off 
   sleep 5
}
