
<#
    Chameleon - An automated bright / dark mode toggle
    service that follows the sun.


    Author:
        Simon Olofsson
        dotchetter@protonmail.ch
        https://github.com/dotchetter

    Date:
        2021-03-07

#>

Add-Type -AssemblyName System.Device

$INTERVAL_MINUTES = 1

function getLocationFromWindows10LocationApi()
<# 
    Returns a hashtable object containing
    coordinates obtained from the internal
    Windows 10 API, if enabled.
#>
{    
    Write-Host "[Chameleon] Verifying location data access: " -NoNewLine -ForeGroundColor Yellow
    
    $GeoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher
    $GeoWatcher.Start()

    while (($GeoWatcher.Status -ne 'Ready') -and ($GeoWatcher.Permission -ne 'Denied')) 
    {
        Start-Sleep -Milliseconds 100 
    }
    
    Write-Host "done." -ForeGroundColor Green
    
    while ($GeoWatcher.Permission -ne 'Granted')
    {
        Write-Warning  ("Chameleon requires Positioning to be turned
                        `ron to work propertly. Do you want to open
                        `rsettings and turn this feature on?") 

        $openSettings = Read-Host "Y/N"

        if ($openSettings.ToLower() -eq "y")
        {
            Write-Host "[Chameleon] Settings will open. Hit Enter when you're done"
            Start-Process ms-settings:privacy-location
            Read-Host "Waiting.."
        }
        else
        {
            Write-Host "bye." -ForeGroundColor Green
            exit       
        }
    } 
    return $GeoWatcher.Position.Location | Select-Object Latitude, Longitude
}


function getSunSetSunRiseDataFromPublicApi($locationData)
<#
    Obtains JSON structured data from external
    api based upon received location in 
    latitude and longitude. 
#>
{
    Write-Host "[Chameleon] Obtaining sunrise and sunset data from API: " -NoNewLine -ForeGroundColor Yellow
    $long = $locationData.Longitude
    $lat = $locationData.Latitude

    $request = "https://api.sunrise-sunset.org/json?lat=$lat&lng=$long"
    
    try
    {
        $err = $null
        $response = Invoke-WebRequest $request -ErrorVariable err
        $results = $response | ConvertFrom-Json | Select-Object results -ExpandProperty results
    }
    catch [Exception]
    {
        Write-Warning "[Chameleon] Chameleon could not connect to the server.`nErrormessage: $err"
        exit
    }        
    
    Write-Host "done." -ForeGroundColor Green
    return $results
}


function evaluateBrightOrDarkmode($sundata)
{
    $now = Get-Date

    if ($now -ge $sundata.sunset)
    {
        return "dark"
    }
    return "light"
}


function setRegistryValues($value)
{
    New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -Value $value -Type Dword -Force | Out-Null  
    New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value $value -Type Dword -Force | Out-Null 
}


function main()
{
    $location = getLocationFromWindows10LocationApi
    $sundata = getSunSetSunRiseDataFromPublicApi $location
    $previousCheck = Get-Date
    $sundataUpdatedTimestamp = Get-Date
    $previousValue = -1
    $colorValue = -1
    
    while (1)
    {
        if (($sundataUpdatedTimestamp - (Get-Date)).Days -ge 1)
        {
            $location = getLocationFromWindows10LocationApi
            $sundata = getSunSetSunRiseDataFromPublicApi $location
        }


        switch (evaluateBrightOrDarkmode)
        {
            "dark"
            {                
                $colorValue = 0
            }
            "light"
            {
                $colorValue = 1
            }
        }
     
        if ($previousValue -ne $colorValue)
        {
            Write-host "[Chameleon] Switching mode" -ForeGroundColor Yellow
            setRegistryValues $colorValue
            $previousValue = $colorValue
        }

        Start-Sleep -Seconds ($INTERVAL_MINUTES * 60)
    }    
}

Write-Host ("`nChameleon - Open source light / dark theme
            `rtoggle service for Windows 10 by Simon Olofsson
            `rhttps://github.com/dotchetter
            `r`n*******************************************
            `rChameleon is starting and will automatically switch
            `rfrom light to dark theme according to the sunset and
            `rsunrise at your location. 
            `rThe interval is set to $INTERVAL_MINUTES minute(s).
            `r")

main