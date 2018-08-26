 
# Screenshotter
 
 Combined with a small Node.js server, `roblox-screenshot` takes, crops, and masks screenshots of the Roblox viewport for automated screenshotting.
 
 For docs, see [`module.lua`](https://github.com/Corecii/roblox-screenshot/blob/master/module.lua).

 For examples, see [`ExamplePatterns.lua`](https://github.com/Corecii/roblox-screenshot/blob/master/ExamplePatterns.lua) and [`Tests.lua`](https://github.com/Corecii/roblox-screenshot/blob/master/Tests.lua).

 You can use the module in Studio at any time with

 ```lua
 local Screenshotter = require(2218503664)
 ```

 ---
 
## Installation
 
 Head to [the Releases page](https://github.com/Corecii/roblox-screenshot/releases) to download the latest release. Unzip it and place it somewhere you can run it from.
 
 Head to [the Node.js page](https://nodejs.org/en/) and download the Current version. Install Node.js. Make sure that you install `npm` and that `node` and `npm` are added to your PATH.
 
 Windows:
 
 1. Run `Install.bat`, which downloads all of the dependencies
 
 Mac:
 
 1. Open the terminal to the `roblox-screenshot` folder
 2. Run `npm install`
 3. Turn off `allow_previews` and `allow_registry_login` in `settings.json`
 
## Running

 Check `settings.json` to make sure the settings are to your liking.

 * `allow_previews` allows scripts to copy screenshots to your Roblox content directory to preview screenshots in-game.
 * `allow_uploads` allows scripts to upload screenshots to Roblox
 * `allow_registry_login` allows scripts to upload screenshots to your account. Scripts *do not* see your login cookie.
 * `allow_password_login` allows scripts to upload screenshots to accounts that they have the username and password for. Scripts *do* see these login cookies.
 
 Windows:
 
 1. Run `Run.bat`
 
 Mac:
 
 1. Open the terminal to the `roblox-screenshot` folder
 2. Run `node .`

 While calibrating or taking screenshots, you must leave the Roblox Studio window open and leave it unobstructed. `roblox-screenshot` takes a screenshot of your screen and crops it down to the Roblox Studio viewport, so `roblox-screenshot` will only work properly if Roblox Studio is on top.
 
 ---
 
## Compatibility
 
 The server *should* work on Mac (and Linux). I have no way to test this out though, and the following restrictions apply to the Mac server *if it works*:
 
 * Previews will not work, as I don't know where the Roblox directory is on Mac. You should turn previews off in `settings.json` to avoid errors.
 * Registry login will not work, since the Registry is a Windows feature.
 
 Advice or pull requests to fix these features or to fix general Mac compatibility is appreciated and encouraged.
 
 ---
 
## Issues
 
### Display scaling on Windows
 
 Display scaling on windows can cause the screenshot program to not take screenshots of the whole screen.
 `Install.bat` will automatically add registry keys to disable scaling for the screenshot program.
 If this does not work for you, you will need to go to `node_modules/screenshot_desktop/lib/win32` and change the compatibility options of `screenCapture.exe` yourself. You will need to run Calibrate or Screenshot from the Lua module at least once for this file to appear.
 
### Package issues
 
 Some packages are included using their github address instead of automatically through npm.
 
 * `screenshot-desktop` does this because it uses some changes I made to add `png` support.
 * `tough-cookie` and `winreg` do this because I was having issues with their npm packages, but the versions on github do not have the issues.