# FUT19-Auto-Sniper

FUT19 sniper written in Powershell\
The main function is Start-FUTSniper, which does the actual sniping.\
More information is written as comments within the module.\
The module works only on windows (since it uses PowerShell 5 and not PowerShell core in addition to accessing files on a windows system for chrome local storage).

## Prerequisite

1. Firstly, as i said in the opening, you must login to FUT Web App using google chrome (which is where the functions get the needed tokens).
2. Since the code is not signed (you can sign it if you want, but it isn't by default), you must allow for unsigned scripts to run (look at Execution Policy below)
3. The code is a powershell module, so, in order to use the commands which are contained within the module, one must first use Import-Module. After which, every command and variables which were defined within the module will be available by the Powershell terminal.
4. At the beginning of the module, theres a constant variable deceleration, which doesn't have a value (NucleasPersonalID). The reason for that is, that each FUT account has a different ID (which is why i deleted the one from my original module, because it was my own ID). In order to acquire the relevant ID for yourself, you need to open chrome developer tools -> go to Network tab (using preserve log, since it jumps between multiple URLs) -> login to the FUT Web App -> and filter using nucpersID -> in the relevant requests, you'll be able to find your very own NucID -> put it at the beginning of the module and it should do the trick.

### Execution Policy

`Set-ExecutionPolicy RemoteSigned`
(Unrestricted will also work, but is less secure).

## Usage

As  i mentioned in the first paragraph, the "main" function is Start-FUTSniper. It only takes 2 parameters, the PlayerID (which can be obtained using chrome developer tools, while making a search for a specific player in the FUT Web App) and the wanted price (which the function will set as max buyNow price, for sniping).\
Example:\

`Start-FUTSniper -PlayerID 207410 -Price 5000`

The above example will try buying kovacic (207410 is kovacic's player ID) for any price of 5000 or lower.

## TODO

I've written a number of TODO lines at the beginning of the module, in order to allow better usage and debug (plus new features i thought would be nice), i'd be happy to work with the community in order to develope them.
