    <#
    .SYNOPSIS
        Monitors endpoint services (ports) and alerts if services are down or unresponsive.

        File Name      : PoSh-PortMonitor.ps1
        Version        : v1.0
        Created        : 11 Nov 2019
        Updated        : 24 May 2020

        Author         : Dan Komnick (high101bro)
        Email          : high101bro@gmail.com
        Website        : https://github.com/high101bro/PoSh-PortMonitor

    .Description
        This script imports endpoints from a csv file and sends connection attempts to associated ports to determine if the port is open. This is useful to monitor if a service is up.

        While the script is running, you can modify the csv file and it update the script upon it next port check. You can add or remove endpoints, change the port number, and the description.
    
    .PARAMETER CsvInput
        This parameter is used to import endpoint data from a file, default is csv filename is 'HostAndPortInfo.csv'.
        The headers are: Status, Endpoint, Port, Description

    .PARAMETER RefreshRate
        This parameter is used to change the default fresh rate from 15 seconds to whatever amount of time in seconds specificied.

    .PARAMETER Timeout_ms
        This parameter is used to change the default connection timeout from 500 milliseconds to whatever amoutn of time in milliseconds specified. This should be increased if there are network segments with significant lag times.

    .PARAMETER NoAudioMessage
        This parameter switch toggles off the audio message that is announced when endpoints are down or unresponsive.

    .EXAMPLE
        This will run PoSh-PortMonitor.ps1 and provide prompts that will tailor your collection.

             PowerShell.exe -ExecutionPolicy ByPass -NoProfile -File .\PoSh-PortMonitor.ps1 -CsvInput

             PowerShell.exe -ExecutionPolicy ByPass -NoProfile -File .\PoSh-PortMonitor.ps1 -CsvInput .\HostAndPortInfo.csv

             PowerShell.exe -ExecutionPolicy ByPass -NoProfile -File .\PoSh-PortMonitor.ps1 -RefreshRate 600

    .Link
        https://github.com/high101bro/PoSh-PortMonitor

    .NOTES  
        This script is packaged with PoSh-PortMonitor, and assists with the monitoring of endpoint services.

#>
param (
    $CsvInput = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)\HostAndPortInfo.csv",
    $RefreshRate = 5,
    $Timeout_ms = 500,
    $FormScale = 2,
    [switch]$NoAudioMessage
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

[System.Windows.MessageBox]::Show(@"
PoSh-PortMonitor is a simple GUI used to monitor endpoint ports/services. This is accomplished by making connection attempts to IPs/Ports listed in HostAndPortInfo.csv. This does not validate if a service necessarily up, but is useful to monitor if a port is open/listening/responding, to which one can assume the a correlating serivce is up.

Copyright (C) 2019  Daniel S Komnick 
https://www.github.com/high101bro/

This program is free software: you can redistribute it and/or modify it under the  terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

A copy of the GNU General Public License (GPLv3) is located at https://www.gnu.org/licenses/.
"@,'Copy Right / EULA')


$ErrorActionPreference = "SilentlyContinue"

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
$MonitorEndpointsForm = New-Object System.Windows.Forms.Form -Property @{
    Text          = "PoSh-PortMonitor"
    StartPosition = 'CenterScreen'
    Width  = $FormScale * 645
    Height = $FormScale * 400
    Font          = New-Object System.Drawing.Font("Courier New",($FormScale * 11),0,0,0)
    Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot/high101bro.ico")
    Topmost       = $true 
}

$MonitorEndpointList = Import-Csv -Path $CsvInput
$count = 0
Function Test-Endpoint {
    param(
        $IPAddress               = '127.0.0.1',
        [Int]$port               = 445,
        [Int]$Timeout_MilliSecs  = 500
    )
    $socket     = New-Object System.Net.Sockets.TcpClient
    $connect    = $socket.BeginConnect($IPAddress, $port, $null, $null)
    $tryconnect = Measure-Command { $success = $connect.AsyncWaitHandle.WaitOne($Timeout_MilliSecs, $true) } | % totalmilliseconds
    $tryconnect | Out-Null
    if ($socket.Connected) {
        $contime    = [math]::round($tryconnect,2)    
        $NetworkPortScanIPResponded = $IPAddress
        $socket.Close()
        $socket.Dispose()
        $socket = $null
        #Write-Host "$(Get-Date)  - [Response Time: $tryconnect ms] $IPAddress is listening on port $Port "
        return $true
    }
}

$MonitorEndpointLabel  = New-Object System.Windows.Forms.Label -Property @{
    Text      = "Monitor Endpoints"
    Location  = @{ X = 10
                  Y = 5 }
    Width  = $FormScale * 200
    Height = $FormScale * 25
    Font      = New-Object System.Drawing.Font("$Font",($FormScale * 12),1,2,1)
    ForeColor = 'Blue'
}
$MonitorEndpointsForm.Controls.Add($MonitorEndpointLabel)

$MonitorEndpointStartButton  = New-Object System.Windows.Forms.Button -Property @{
    Text     = "Start Monitoring"
    Location = @{ X = $MonitorEndpointLabel.Location.X
                  Y = $MonitorEndpointLabel.Location.Y + $MonitorEndpointLabel.Height }
    Width  = $FormScale * 206
    Height = $FormScale * 25
    Font     = New-Object System.Drawing.Font("$Font",($FormScale * 11),0,0,0)
}
CommonButtonSettings -Button $MonitorEndpointStartButton
$MonitorEndpointStartButton.Add_Click({    
    while ($true) {

        foreach ($second in $RefreshRate..0) {
            Sleep 1
            if ($Second -ne 0) { $MonitorEndpointStartButton.Text = "Checking In: $Second" }
            $MonitorEndpointsForm.Refresh()
        }
        $MonitorEndpointList = Import-Csv -Path $CsvInput
        $MonitorEndpointDownPosition = $MonitorEndpointStartButton.Location.Y + $MonitorEndpointStartButton.Height
        $count = 0
        foreach ($Endpoint in $MonitorEndpointList) {
            $MonitorEndpointDownPosition += 5
            $count += 1

            Invoke-Expression @"
            `$MonitorEndpointsForm.Controls.Remove(`$MonitorEndpointAddedStatus$($count)TextBox)
            `$MonitorEndpointAddedStatus$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
                Location  = @{ X = 10
                               Y = `$MonitorEndpointDownPosition}
                Width  = `$FormScale * 20
                Height = `$FormScale * 25
                ReadOnly  = `$true
                BackColor = "`$(`$Endpoint.Status)"
            }
            `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedStatus$($count)TextBox)                
"@
            Invoke-Expression @"
            `$MonitorEndpointsForm.Controls.Remove(`$MonitorEndpointAddedIPAddress$($count)TextBox)   
            `$MonitorEndpointAddedIPAddress$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
                Text      = "`$(`$Endpoint.Endpoint)"
                Location  = @{ X = `$MonitorEndpointAddedStatus$($count)TextBox.Location.X + `$MonitorEndpointAddedStatus$($count)TextBox.Width + 5
                               Y = `$MonitorEndpointAddedStatus$($count)TextBox.Location.Y }
                Width  = `$FormScale * 125
                Height = `$FormScale * 25
                ReadOnly  = `$true
                BackColor = 'White'
            }
            `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedIPAddress$($count)TextBox)                
"@
            Invoke-Expression @"
            `$MonitorEndpointsForm.Controls.Remove(`$MonitorEndpointAddedPort$($count)TextBox)  
            `$MonitorEndpointAddedPort$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
                Text      = "`$(`$Endpoint.Port)"
                Location  = @{ X = `$MonitorEndpointAddedIPAddress$($count)TextBox.Location.X + `$MonitorEndpointAddedIPAddress$($count)TextBox.Width + 5
                               Y = `$MonitorEndpointAddedIPAddress$($count)TextBox.Location.Y }
                Width  = `$FormScale * 50
                Height = `$FormScale * 25
                ReadOnly  = `$true
                BackColor = 'White'
            }
            `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedPort$($count)TextBox)                
"@
            Invoke-Expression @"
            `$MonitorEndpointsForm.Controls.Remove(`$MonitorEndpointAddedDescription$($count)TextBox)    
            `$MonitorEndpointAddedDescription$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
                Text      = "`$(`$Endpoint.Description)"
                Location  = @{ X = `$MonitorEndpointAddedPort$($count)TextBox.Location.X + `$MonitorEndpointAddedPort$($count)TextBox.Width + 5
                               Y = `$MonitorEndpointAddedPort$($count)TextBox.Location.Y }
                Width  = `$FormScale * 400
                Height = `$FormScale * 25
                ReadOnly  = `$true
                BackColor = 'White'
            }
            `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedDescription$($count)TextBox)                
"@

            Invoke-Expression @"
            `$MonitorEndpointDownPosition += `$MonitorEndpointAddedStatus$($count)TextBox.Height
"@
        }
        $MonitorEndpointsForm.Refresh()

        $MonitorEndpointStartButton.Text = 'Checking Endpoints...'          
        foreach ($Endpoint in $MonitorEndpointList) {
            if (Test-Endpoint -IPAddress $Endpoint.Endpoint -port $Endpoint.Port -Timeout_MilliSecs $Timeout_ms) {
                $Endpoint.Status = 'LightGreen'
            }
            else {
                $Endpoint.Status = 'Red'
            }
        }
        $count = 0
        foreach ($Endpoint in $MonitorEndpointList) {
            $MonitorEndpointDownPosition += 5
            $count += 1
            if ($Endpoint.Status -Match 'Green') {
                Invoke-Expression "`$MonitorEndpointAddedStatus$($count)TextBox.BackColor = 'LightGreen'"
                $MonitorEndpointsForm.Refresh()
            }
            else {
                Invoke-Expression "`$MonitorEndpointAddedStatus$($count)TextBox.BackColor = 'Red'"
                $MonitorEndpointList | Export-Csv -Path $CsvInput -NoTypeInformation
                if (-Not $NoAudioMessage) {
                    $MonitorEndpointsForm.Refresh()
                    [system.media.systemsounds]::Exclamation.play()
                    Add-Type -AssemblyName System.speech
                    $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
                    $speak.Speak("Alert: $($Endpoint.Endpoint) on port $($Endpoint.Port) is downn or not responding!")
                }
                Start-Sleep -Seconds 1
            }                
        }
        $MonitorEndpointsForm.Refresh()
    }
})
$MonitorEndpointsForm.Controls.Add($MonitorEndpointStartButton)
                        
$MonitorEndpointDownPosition = $MonitorEndpointStartButton.Location.Y + $MonitorEndpointStartButton.Height
$count = 0
foreach ($Endpoint in $MonitorEndpointList) {
    $MonitorEndpointDownPosition += 5
    $count += 1

    Invoke-Expression @"
    `$MonitorEndpointAddedStatus$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Location  = @{ X = 10
                       Y = `$MonitorEndpointDownPosition}
        Width  = `$FormScale * 20
        Height = `$FormScale * 25
        ReadOnly  = `$true
        BackColor = "`$(`$Endpoint.Status)"
    }
    `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedStatus$($count)TextBox)                
"@
    Invoke-Expression @"
    `$MonitorEndpointAddedIPAddress$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Text      = "`$(`$Endpoint.Endpoint)"
        Location  = @{ X = `$MonitorEndpointAddedStatus$($count)TextBox.Location.X + `$MonitorEndpointAddedStatus$($count)TextBox.Width + 5
                       Y = `$MonitorEndpointAddedStatus$($count)TextBox.Location.Y }
        Width  = `$FormScale * 125
        Height = `$FormScale * 25
        ReadOnly  = `$true
        BackColor = 'White'
    }
    `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedIPAddress$($count)TextBox)                
"@
    Invoke-Expression @"
    `$MonitorEndpointAddedPort$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Text      = "`$(`$Endpoint.Port)"
        Location  = @{ X = `$MonitorEndpointAddedIPAddress$($count)TextBox.Location.X + `$MonitorEndpointAddedIPAddress$($count)TextBox.Width + 5
                       Y = `$MonitorEndpointAddedIPAddress$($count)TextBox.Location.Y }
        Width  = `$FormScale * 50
        Height = `$FormScale * 25
        ReadOnly  = `$true
        BackColor = 'White'
    }
    `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedPort$($count)TextBox)                
"@
    Invoke-Expression @"
    `$MonitorEndpointAddedDescription$($count)TextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Text      = "`$(`$Endpoint.Description)"
        Location  = @{ X = `$MonitorEndpointAddedPort$($count)TextBox.Location.X + `$MonitorEndpointAddedPort$($count)TextBox.Width + 5
                       Y = `$MonitorEndpointAddedPort$($count)TextBox.Location.Y }
        Width  = `$FormScale * 400
        Height = `$FormScale * 25
        ReadOnly  = `$true
        BackColor = 'White'
    }
    `$MonitorEndpointsForm.Controls.Add(`$MonitorEndpointAddedDescription$($count)TextBox)                
"@

    Invoke-Expression @"
    `$MonitorEndpointDownPosition += `$MonitorEndpointAddedStatus$($count)TextBox.Height
"@
}

            
$MonitorEndpointsForm.Add_Shown({$MonitorEndpointsForm.Activate()})
$MonitorEndpointsForm.ShowDialog()