#My FUT 19 Autobuyer :)
#TODO :add check if session expired so convert-fromjson wont make an error 
#TODO: add debug flag, and shout out tons of debug messages if activated
#TODO: add an optional sell-price paramater to start-futsniper, in order to allow fully automated sell of players (in addition to making sell-player work)
#TODO: Make Sell-Player work
#TODO: Get PlayerIds dynamically
#TODO: add GUI
#TODO: add more functions that read local storage (like identity PID and security token etc')
#TODO: build classes for trades, players etc with methods for better code usage and readability (real OOP)


#another PersonalID but its not saved in the local storage. need to check if it can be replaced by the PID that is saved there
#its constant for each user, so its possible to locate it and set it here
Set-Variable -Value "" -Name "NucleasPersonalID" -Scope global


#HT of players and their ID, for easy use of the start-sniper function
$Players = @{
    "Arnautovic" = "184200";
    "Mccarthy"   = "188253";
    "Hayden"     = "206115";
    "Vardy"      = "208830";
    "Kovacic"    = "207410";
    "Herrera"    = "191740";
    "Matic"      = "191202";
    "Anderson"   = "201995";
    "Sokratis"   = "172879";
    "Bailly"     = "225508";
    "Lucas"      = "200949";
    "Zaha"       = "198717";
    "Garcia"     = "216194";
    "Rodri"      = "231866";
    "Son"        = "200104";
    "Valencia"   = "167905";
    "Walker"     = "188377";
    "Rashford"   = "231677";
    "Fred"       = "209297";
    "Mendy"      = "204884";
    "Martial"    = "211300";
}

#a class which contains all of the session identifiers used by FUT Web App while making web requests
#has the ability to renew the SID (the session identifier which is sent in almost every request, and expires after about 1 minute of repeting requests)
class FUTIdentity {

    [string]$AccessToken
    [string]$SID

    FUTIdentity(
        [string]$AT,
        [string]$SID
    ) {
        $this.AccessToken = $AT
        $this.SID = $SID
    }
    [void]RecycleIdentity() {
        #in order to recycle the identity, we need to invoke 2 web requests, the first to get a new security token (the names are confusing......)
        #which is also saved on the chrome local storage
        $uri = "https://accounts.ea.com/connect/auth?client_id=FOS-SERVER&redirect_uri=nucleus:rest&response_type=code&access_token=" + $this.AccessToken + "&release_type=prod" 
        $Headers = @{"Referer" = "https://www.easports.com/fifa/ultimate-team/web-app/"; "Origin" = "https://www.easports.com"; "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"} 
        $res = Invoke-WebRequest -Uri $uri -ContentType "application/json" -Headers $Headers
        $token = $res.RawContent.Split('"')[-2]
        #the 2nd is to get the new sid
        $H = @{"Cache-Control" = "no-cache"; "Origin" = "https://www.easports.com"; "Referer" = "https://www.easports.com/fifa/ultimate-team/web-app/"; "X-UT-PHISHING-TOKEN" = "1"; "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"}
        #getting rand phshing token
        $H["X-UT-PHISHING-TOKEN"] = Get-Random -Minimum 1000000000000000000 -Maximum 8988887888888888888
        $B = "{`"isReadOnly`":false,`"sku`":`"FUT19WEB`",`"clientVersion`":1,`"locale`":`"en-US`",`"method`":`"authcode`",`"priorityLevel`":4,`"identification`":{`"authCode`":`"$token`",`"redirectUrl`":`"nucleus:rest`"},`"nucleusPersonaId`":$global:NucleasPersonalID,`"gameSku`":`"FFA19PS4`"}"
        $res = Invoke-WebRequest -Uri "https://utas.external.s2.fut.ea.com/ut/auth" -Method "POST" -Headers $H -ContentType "application/json" -Body $B
        $converted = ConvertFrom-Json $res.Content
        #the new SID is saved to the local identity object
        $this.SID = $converted.sid
        Write-Host "Session Recycled"

    }

}


function get-FUTAccessToken {
    #Another identifier
    #Its extracted form chrome local storage, which will only be there after accessing the web app from Chrome
    #Acessing chrome app data of the user which run the function
    [string]$StorageLocation = Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'Google\Chrome\User Data\Default\Local Storage\leveldb\'

    #finds the file which ends in .log (which has a lot of the local storage properties saved as plain text)
    $logFile = Get-childitem $StorageLocation -Filter '*.log'
    $logContent = Get-Content -Path ($logFile.FullName)
    #finds the below string, which is the name of the property as its saved by chrome
    $last = $logContent | Select-String -Pattern "_eadp.identity.access_tokenT"
    $last = $last[$last.Matches.Count - 1]
    $almostString = $last.ToString()
    $Token = $almostString.Substring($almostString.IndexOf("access_tokenT") + "access_tokenT".Length + 1, 83)
    return $Token

}

#works on the same concept as get-futaccesstoken
function get-NucleusID {
    #opens local user chrome appdata
    [string]$StorageLocation = Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'Google\Chrome\User Data\Default\Local Storage\leveldb\'
    #finds log file
    $logFile = Get-childitem $StorageLocation -Filter '*.log'
    $logContent = Get-Content -Path ($logFile.FullName)
    #looks for PIDID on the file
    $last = $logContent | Select-String -Pattern "_eadp.identity.pidId"
    $last = $last[$last.Matches.Count - 1]
    $almostString = $last.ToString()
    $Token = $almostString.Substring($almostString.IndexOf("identity.pidId") + "identity.pidId".Length + 2, 10)
    return $Token

}


#get player runs a search based on a player id and max buy now (which is called wanted price), the minPrice is used to refresh the results
#since if you make the exact same search within a small interbal, the search wont really happen and youll just get the same results you got form the last search
function Get-Player {
    param (
        [string] $SID,
        [string] $PlayerID,
        [int] $WantedPrice,
        [int] $minPrice
    )
    $URI = "https://utas.external.s2.fut.ea.com/ut/game/fifa19/transfermarket?start=0&num=21&type=player&maskedDefId=" + $PlayerID + "&micr=" + $minPrice.ToString() + "&maxb=" + $WantedPrice.ToString() #+ $_Identifer - not needed
    $Headers = @{"Accept" = "text/plain, */*; q=0.01"; "X-UT-SID" = "6"; "Easw-Session-Data-Nucleus-Id" = "1234"; "Origin" = "https://www.easports.com"; "Referer" = "https://www.easports.com/fifa/ultimate-team/web-app/"; "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"}
    $Headers["X-UT-SID"] = $SID
    #not the most efficient line since get-nucleusid is probably a bit more cpu intensive then getting it once and sending it as a paramater, should change it
    $Headers["Easw-Session-Data-Nucleus-Id"] = (get-NucleusID)
    #powershell web requests codes 5xx, on invoke-webrequest, are delt with like errors (red letter and no return value) hence, we need to use try catch 
    try {$res = Invoke-WebRequest -Uri $URI -Headers $Headers -ContentType "application/json"}
    catch {
        $ex = $_.Exception.Response.StatusCode.value__
        #the following errors are returned when too many requests have been sent, so we need to slow it down a bit
        if ($ex -eq "512" -or $ex -eq "521") {
            Write-Host "Too many requests, waiting...."
            #this is how we slow it down
            Start-Sleep -Seconds 20
            return " "
        }
        #401 is returned when the SID has expired, ususally takes about a minute or two, it returnes the string Expired, to let the program know
        #it needs to recycle the SID
        elseif ($ex -eq "401") {return "Expired"}
        #elseif($_.Exception.Response}
    }
    #returns the content of the response if no errors occured (or SID expired)
    return $res.content
}

#this function is the one which actually performs the bidding (and buying) using BuyNow
function Buy-Player {
    param (
        [string]$PlayerSTRID,
        [int]$Bid,
        [string] $SID
    )

    $URI = "https://utas.external.s2.fut.ea.com/ut/game/fifa19/trade/" + $PlayerSTRID + "/bid"
    $Headers = @{"X-UT-SID" = "a"; "Referer" = "https://www.easports.com/fifa/ultimate-team/web-app/"; "Origin" = "https://www.easports.com"; "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"}
    #insert SID
    $Headers["X-UT-SID"] = $SID
    #set the bid
    $Body = "{`"bid`":" + $bid.ToString() + "}"
    $res = Invoke-WebRequest -Uri $URI -Method "PUT" -Headers $Headers -ContentType "application/json" -Body $Body -ErrorAction SilentlyContinue
    if ($res.StatusCode -eq "200") {return $true}
    Write-Host ("Missed it :( for " + $Bid.ToString())
    return $false    
}


#the "main" function, you choose the player and the wanted buynow price and let the magic happen
function Start-FUTSniper {
    param (
        [string] $PlayerID,
        [string] $Price
    )
    #Check paramters were sent
    if (!$PlayerID -or !$Price) {
        Write-Host "Unsufficient Paramaters. Enter the correct amount of paramaters" -ForegroundColor Red
        return
    }
    #checks if the string that was inserted is on the players array, if so, it replaces it with the PlayerID
    if ($Players.ContainsKey($PlayerID)) {
        $PlayerID = $Players[$PlayerID]
    }

    #Create the necessary FUTID object and fill all needed values
    $FID = [FUTIdentity]::new((get-FUTAccessToken), "")
    #recycles it, so it has a valid SID in it
    $FID.RecycleIdentity()
    #sets the start of minPrice, so it can adjust it while sending requests
    $minPriceChange = 150
    while ($true) {
        #gets a list of players using get-player
        $res = Get-Player -SID $FID.SID -PlayerID $PlayerID -WantedPrice $Price -minPrice $minPriceChange 
        #converts the reponse (which is a json from the reponse body)
        $converted = ConvertFrom-Json $res
        #add here if #converted -eq "expired"......
        $converted.auctionInfo.Count
        #checks if trades were returned, if so, the number will be greater than 0
        if ($converted.auctionInfo.Count -gt 0) {
            #gets the last trade (better when sniping against humans and if there is only 1 trade, it will get it since 1-1=0)
            $trade = $converted.auctionInfo[$converted.auctionInfo.Count - 1]
            #gets the tradeID of the relevant trade
            $idstr = $trade.tradeIdStr
            #gets the buy now price of the trade, since it only works if you bid the exact same price
            $bidPrice = $trade.buyNowPrice
            #buy the player using buy-player
            $success = Buy-Player -PlayerSTRID $idstr -Bid $bidPrice -SID $FID.SID
            #notify the user with the outcome of the bid
            if ($success) {
                #asks the user wether he wants to run the same sniper again (using the same paramaters)
                $HostContinue = read-host -Prompt ("Success! bought " + $Players[$PlayerID.ToString()] + " for " + $trade.buyNowPrice.ToString() + [Environment]::NewLine + "enter 1 to continue, 0 to exit, or a buy now price to list for sale")
                if ($HostContinue -eq "0") {
                    return
                }
                if ($HostContinue -ne "1" -and $HostContinue -ne "0") {
                    Sell-Player -SID $FID.SID -price $HostContinue -ItemID $trade.itemData.id 
                }
            }
        }
        else {
            #if get-player returns expired, the SID is recycled
            if ($res -eq "Expired") {
                $FID.RecycleIdentity()
            }
            Write-Host "found none waiting...."
        }
        #adjust minPrice, as mentioned, so we will get new results next time we run get-player
        if ($minPriceChange -eq 1000) {
            $minPriceChange = 150
        }
        else {
            $minPriceChange += 50
        }
        #wait between requests (of get-player), its configurable right down here
        $rand = get-random -Minimum 400 -Maximum 500
        Start-Sleep -Milliseconds $rand
    }
}
#when Sell-PLayer will work, just like we ask the user if he wants to continue, we can put his player up for sale in order to allow more fluent use
#in addition, it will be possible to add an optional flag to start-futsniper with sell prices, to make a fully automated buy-sell

# function Sell-Player{
#     param(
#         [string]$SID,
#         [string]$ItemID,
#         [string]$price
#     )
#move player to trade pile (from unassigned)
#put it for sale
#Invoke-WebRequest -Uri "https://utas.external.s2.fut.ea.com/ut/game/fifa19/auctionhouse" -Method "POST" -Headers @{"X-UT-SID"="1"; "Referer"="https://www.easports.com/fifa/ultimate-team/web-app/"; "Origin"="https://www.easports.com"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"} -ContentType "application/json" -Body "{`"itemData`":{`"id`":315446961460},`"startingBid`":4600,`"duration`":3600,`"buyNowPrice`":75000}"


#     $Headers=@{"X-UT-SID"="1"; "Referer"="https://www.easports.com/fifa/ultimate-team/web-app/"; "Origin"="https://www.easports.com"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"}
#     $Headers["X-UT-SID"]=$SID
#     Invoke-WebRequest -Uri ("https://utas.external.s2.fut.ea.com/ut/game/fifa19/marketdata/item/pricelimits?itemIdList="+$ItemID ) -Headers $Headers -ContentType "application/json"
#     $Headers["Easw-Session-Data-Nucleus-Id"]=get-NucleasID
#     $Headers["X-UT-SID"]=$SID
#     $Body="{`"itemData`":[{`"id`":" + $ItemID + ",`"pile`":`"trade`"}]}"
#     Invoke-WebRequest -Uri "https://utas.external.s2.fut.ea.com/ut/game/fifa19/item" -Method "PUT" -Headers $Headers -ContentType "application/json" -Body $Body

#     $Headers=@{"X-UT-SID"="1"; "Referer"="https://www.easports.com/fifa/ultimate-team/web-app/"; "Origin"="https://www.easports.com"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"}
#     $Headers["X-UT-SID"]=$SID
#     $Body="{`"itemData`":{`"id`":"+$ItemID +"},`"startingBid`":350,`"duration`":3600,`"buyNowPrice`":"+ $price +"}"
#     Invoke-WebRequest -Uri "https://utas.external.s2.fut.ea.com/ut/game/fifa19/auctionhouse" -Method "POST" -Headers $Headers -ContentType "application/json" -Body $Body 

# }

Export-ModuleMember -Function '*'
Export-ModuleMember -Variable 'Players'

