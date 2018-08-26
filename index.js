"use strict";

const express = require('express');
const screenshot = require('screenshot-desktop');
const fs = require('fs-extra');
const path = require('path');
const jimp = require('jimp');
const robloxjs = require('roblox-js');
const request = require("request-promise");
const parseDomain = require("parse-domain");
const tough = require('tough-cookie');
const sprintf = require('sprintf-js').sprintf;
const escape = require('querystring').escape;
const sanitizeFilename = require("sanitize-filename");

const DEBUG_MODE = false;

const screenshotOptions = {
    format: 'png'
};

let debugWrite;
if (DEBUG_MODE) {
    debugWrite = function(image, location) {
        return image.writeAsync(location);
    };
}
else {
    debugWrite = function() {};
}

const settings = {
    allow_previews: false,
    allow_registry_login: false,
    allow_password_login: false,
    allow_uploads: false,
};
if (fs.existsSync("./settings.json")) {
    try {
        let settingsFile = fs.readJsonSync("./settings.json");
        for (let prop in settings) {
            if (settingsFile[prop]) {
                if (typeof(settingsFile[prop]) == "boolean") {
                    settings[prop] = settingsFile[prop];
                    console.log("Loaded setting: "+prop+" = "+settings[prop]);
                }
                else {
                    console.log("Bad type for setting "+prop+". Should be boolean, but is "+typeof(settingsFile[prop])+". Using safe value: "+prop+" = "+settings[prop]);
                }
            }
            else {
                console.log("Missing setting "+prop+". Using safe value: "+prop+" = "+settings[prop]);
            }
        }
    }
    catch (err) {
        console.log("settings.json is formatted incorrectly, using safe values (no previews, no registry logins, no password logins, no uploads). Please fix your settings file:\n",err);
    }
}
else {
    console.log("settings.json does not exist, using safe values (no previews, no registry logins, no password logins, no uploads). Please fix your settings file.");
}

async function getRobloxContentDirectory() {
    // roblox versions location on windows: %LOCALAPPDATA%\Roblox\Versions
    let versionsPath = process.env.LOCALAPPDATA + "/Roblox/Versions";
    if (!await fs.exists(versionsPath)) {
        console.error("Versions directory does not exist (`"+versionsPath+"`)");
        return undefined;
    }
    let versionsFile = await fs.open(versionsPath, 'r');
    let versionsStat = await fs.fstat(versionsFile);
    if (!versionsStat.isDirectory()) {
        console.error("Versions is not a directory (`"+versionsPath+"`)");
        return undefined;
    }
    await fs.close(versionsFile);
    let versionsContents = await fs.readdir(versionsPath);
    for (let versionName of versionsContents) {
        let versionPath = versionsPath + "/" + versionName;
        let studioPath = versionPath + "/RobloxStudioBeta.exe";
        let contentPath = versionPath + "/content";
        if (await fs.exists(studioPath) && await fs.exists(contentPath)) {
            // we found the directory!
            return contentPath;
        }
    }
    return undefined;
}

async function getPreviewDirectory() {
    let localDir = path.resolve("./screenshots");
    if (!await fs.exists(localDir)) {
        await fs.mkdir(localDir);
    }
    if (settings.allow_previews) {
        let localPreviewDir = path.resolve("./previews");
        if (!await fs.exists(localPreviewDir)) {
            await fs.mkdir(localPreviewDir);
        }
        let contentDir = await getRobloxContentDirectory();
        if (!contentDir) {
            return undefined;
        }
        let previewDir = contentDir + "/previews";
        if (!await fs.exists(previewDir)) {
            fs.copy(localPreviewDir, previewDir); // copy existing images over
        }
        return [localDir, localPreviewDir, previewDir];
    }
    return [localDir];
}

const tokens = {};
let lastToken;
async function robloxRequest(options) {
    const subdomain = parseDomain(options.url).subdomain;
    const token = tokens[subdomain] || lastToken;
    if (!options.headers)
        options.headers = {};
    options.headers["x-csrf-token"] = token;
    if (options.json == undefined) {
        options.json = true;
    }
    let resolveWithFullResponse = options.resolveWithFullResponse;
    options.resolveWithFullResponse = true;
    try {
        const response = await request(options);
        if (response.headers["x-csrf-token"]) {
            tokens[subdomain] = response.headers["x-csrf-token"];
            lastToken = tokens[subdomain];
        }
        options.resolveWithFullResponse = resolveWithFullResponse;
        if (resolveWithFullResponse)
            return response;
        else
            return response.body;
    }
    catch (error) {
        options.resolveWithFullResponse = resolveWithFullResponse;
        if (error.response.headers["x-csrf-token"]) {
            tokens[subdomain] = error.response.headers["x-csrf-token"];
            lastToken = tokens[subdomain];
        }
        let retry = error.statusCode == 403 && (!error.error || !error.error.errors || !error.error.errors[0] || !error.error.errors[0].code || error.error.errors[0].code == 0);
        if (retry) {
            options.headers["x-csrf-token"] = tokens[subdomain];
            return await request(options);
        }
        throw error;
    }
}

async function robloxLogin(username, password) {
    let jar = request.jar();
    const response = await robloxRequest({
        method: "POST",
        url: "https://auth.roblox.com/v2/login",
        body: {
            ctype: "Username",
            cvalue: username,
            password: password
        },
        jar: jar,
    });
    for (let cookie of jar.getCookies("https://auth.roblox.com/v2/login"))
        if (cookie.key == ".ROBLOSECURITY")
            return cookie.value;
    throw new Error({error: "No cookie returned", response: response});
}

const uploadUrl = 'http://data.roblox.com/data/upload/json?assetTypeId=%i&name=%s&description=%s&groupId=%s'
async function uploadImage(name, imagePath, groupId, cookie) {
    try {
        let fileBuffer = await fs.readFile(imagePath);
        let response = await robloxRequest({
            method: "POST",
            url: sprintf(uploadUrl, 13, escape(name), "", groupId || ""),
            headers: {
                'Cookie': '.ROBLOSECURITY=' + cookie + ';',
                'Host': 'data.roblox.com',
                'Content-type': "*/*",
                'User-Agent': 'Roblox/WinInet',
            },
            body: fileBuffer, //fs.createReadStream(imagePath),
            json: false,
        });
        return response;
    }
    catch (err) {
        throw err;
    }
}

async function getRegistryCookie() {
    try {
        let Registry = require("winreg");
        let regKey = new Registry({
            hive: Registry.HKCU,
            key: "\\Software\\Roblox\\RobloxStudioBrowser\\roblox.com"
        });
        let cookieItem = await new Promise((resolve, reject) => {
            regKey.get('.ROBLOSECURITY', function(err, item) {
                if (err)
                    reject(err);
                else
                    resolve(item);
            });
        });
        let cookieMatches = cookieItem.value.match("COOK::<([^>]+)>");
        return cookieMatches[1];
    }
    catch (err) {
        console.log("Failed to get cookie from registry:",err);
        return undefined;
    }
}

async function previewImage(name) {
    let directories = await getPreviewDirectory();
    await fs.copy(directories[0]+"/"+name, directories[1]+"/"+name);
    await fs.copy(directories[1]+"/"+name, directories[2]+"/"+name);
}

const app = express();

let calibration = {
    start: [0, 0],
    end: [0, 0]
};

app.get('/settings',
    express.json(),
    async (request, response) => {
        response.send({success: true, settings: settings});
    }
);

app.post('/login',
    express.json(),
    async (request, response) => {
        console.log("Received login request:",request.body);
        try {
            if (request.body.registry) {
                if (!settings.allow_registry_login) {
                    console.log("Rejected login request because registry logins are disabled.");
                    response.send({success: false, errorCode: 12, error: "Registry login has been disabled. Check settings.json."});
                    return;
                }
                getRegistryCookie(); // don't actually return the cookie (that's unsafe!) just return a placeholder
                response.send({success: true, cookie: "registry"});
                return;
            }
            if (!settings.allow_password_login) {
                console.log("Rejected login request because password logins are disabled.");
                response.send({success: false, errorCode: 13, error: "Password login has been disabled. Check settings.json."});
                return;
            }
            let cookie = await robloxLogin(request.body.username, request.body.password);
            console.log("Login success.");
            response.send({success: true, cookie: cookie});
        }
        catch (err) {
            console.log("Login error:", err);
            response.send({success: false, errorCode: 100, error: err.toString()});
        }
    }
);

app.post('/upload',
    express.json(),
    async (request, response) => {
        console.log("Received upload request",request.body);
        if (!settings.allow_uploads) {
            console.log("Rejected upload request because uploads are disabled.");
            response.send({success: false, errorCode: 14, error: "Uploads have been disabled. Check settings.json."});
            return;
        }
        let destination = sanitizeFilename(request.body.destination);
        let groupId = request.body.groupId;
        let deletePreview = request.body.deletePreview;
        if (deletePreview && !settings.allow_previews) {
            console.log("Rejected upload request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }
        let toDelete = request.body.delete;
        let cookie = request.body.cookie;
        let fileName = destination+".png";
        let name = request.body.name || destination;
        let screenshotsDir = (await getPreviewDirectory())[0];
        let filePath = screenshotsDir + "/" + fileName;
        if (!await fs.exists(filePath)) {
            console.log("Upload failed (file ("+filePath+") does not exist)");
            response.send({success: false, errorCode: 201, error: 'File does not exist'});
            return;
        }
        let dataString;
        let data;
        try {
            if (cookie == "registry") {
                cookie = await getRegistryCookie();
            }
            dataString = await uploadImage(name, filePath, groupId, cookie);
            data = JSON.parse(dataString); // we can't use the `json: true` of request because the *request* needs to be non-json
            if (!data.Success) {
                console.log("Upload error:",data);
                if (data.Message && data.Message.search("You are uploading too much") != -1) {
                    console.log("Upload failed (uploading too much)");
                    response.send({success: false, errorCode: 211, error: "Uploading too much"});
                } else if (data.Message && data.Message.search("inappropriate") != -1) {
                    console.log("Upload failed (inappropriate text)");
                    response.send({success: false, errorCode: 212, error: "Inappropriate text"});
                } else {
                    response.send({success: false, errorCode: 220, error: dataString});
                }
                return;
            }
            console.log("Uploaded! At: " + data.BackingAssetId);
            response.send({success: true, destination: destination, imageId: data.BackingAssetId, content: "rbxassetid://"+data.BackingAssetId});
            if (toDelete || deletePreview) {
                try {
                   let directories = await getPreviewDirectory();
                   if (deletePreview && !toDelete) {
                        directories.shift();
                   }
                    for (let dir of directories) {
                        await fs.remove(dir + "/" + fileName);
                    }
                    if (deletePreview && !toDelete) {
                        console.log("Deleted preview");
                    }
                    else {
                        console.log("Delete screenshot");
                    }
                }
                catch (err) {
                    console.log("Failed to delete screenshot or preview, but succeeded at uploading screenshot.");
                }
            }
        }
        catch (err) {
            console.log("Upload failed: ",err);
            if (err.message && err.message.search("/NewLogin") != -1) {
                console.log("Upload failed (not logged in)");
                response.send({success: false, errorCode: 210, error: "Not logged in"});
            } else {
                console.log("Upload failed (unknown/generic)");
                response.send({success: false, errorCode: 200, error: err.toString()});
            }
        }
    }
);

let maskCache = {};
app.post('/screenshot',
    express.json(),
    async (request, response) => {
        console.log("Received screenshot request",request.body);
        let crop = request.body.crop;
        let destination = sanitizeFilename(request.body.destination);
        let maskStep = request.body.mask;
        let isPreview = request.body.preview;
        if (isPreview && !settings.allow_previews) {
            console.log("Rejected screenshot request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }
        try {
            let scrBuffer = await screenshot(screenshotOptions);
            let image = await jimp.read(scrBuffer);
            let start = calibration.start, end = calibration.end;
            image.crop(start[0], start[1], end[0] - start[0], end[1] - start[1]);
            if (crop) {
                console.log("Cropping: ("+crop.x+", "+crop.y+") ("+crop.width+", "+crop.height+") out of ("+image.bitmap.width+", "+image.bitmap.height+")");
                image.crop(crop.x, crop.y, crop.width, crop.height);
            }
            let dirs = await getPreviewDirectory();
            if (maskStep) {
                if (maskStep == 1) {
                    await debugWrite(image, dirs[0]+"/"+destination+"-imageB.png");
                    maskCache[destination] = image;
                    console.log("Screenshot finished. Saved to mask cache.");
                    response.send({success: true, destination: destination, maskCached: true});
                    setTimeout(() => {
                        if (maskCache[destination] == image) {
                            delete maskCache[destination];
                        }
                    }, 60*1000);
                    return;
                }
                else {
                    let imageA = image;
                    await debugWrite(image, dirs[0]+"/"+destination+"-imageA.png");
                    let imageB = maskCache[destination];
                    let mask = imageB.clone();
                    //Can't get the difference compositing to work, so here it is manually:
                    mask.scan(0, 0, mask.bitmap.width, mask.bitmap.height, function(x, y, idx) {
                        var red   = this.bitmap.data[ idx + 0 ];
                        var green = this.bitmap.data[ idx + 1 ];
                        var blue  = this.bitmap.data[ idx + 2 ];
                        var otherRed   = imageA.bitmap.data[ idx + 0 ];
                        var otherGreen = imageA.bitmap.data[ idx + 1 ];
                        var otherBlue  = imageA.bitmap.data[ idx + 2 ];
                        this.bitmap.data[ idx + 0 ] = 255 - Math.abs(red - otherRed);
                        this.bitmap.data[ idx + 1 ] = 255 - Math.abs(green - otherGreen);
                        this.bitmap.data[ idx + 2 ] = 255 - Math.abs(blue - otherBlue);
                    });
                    await debugWrite(mask, dirs[0]+"/"+destination+"-difference.png");
                    imageA.mask(mask, 0, 0);
                    await debugWrite(imageA, dirs[0]+"/"+destination+"-a-masked.png");
                    imageB.mask(mask, 0, 0);
                    await debugWrite(imageB, dirs[0]+"/"+destination+"-b-masked.png");
                    imageA.composite(imageB, 0, 0);
                    await debugWrite(imageA, dirs[0]+"/"+destination+"-ab-composite.png");
                    imageA.mask(mask, 0, 0);
                    image = imageA;
                    console.log("Screenshot finished. Mask completed.");
                    delete maskCache[destination];
                }
            }
            let name = destination+".png";
            await image.writeAsync(dirs[0] + "/" + name);
            if (isPreview) {
                await previewImage(name);
                console.log("Saved preview.");
            }
            console.log("Screenshot finished.");
            response.send({success: true, destination: destination, content: isPreview && "rbxasset://previews/"+name || undefined});
        }
        catch (err) {
            console.log("Screenshot failed:",err);
            response.send({success: false, errorCode: 300, error: err.toString()});
        }
    }
);

app.post('/preview',
    express.json(),
    async (request, response) => {
        console.log("Received preview request",request.body);
        if (!settings.allow_previews) {
            console.log("Rejected preview request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }
        let destination = sanitizeFilename(request.body.destination);
        let fileName = destination+".png";
        let screenshotsDir = (await getPreviewDirectory())[0];
        let filePath = screenshotsDir + "/" + fileName;
        if (!await fs.exists(filePath)) {
            console.log("Preview failed (file ("+filePath+") does not exist)");
            response.send({success: false, errorCode: 501, error: 'File does not exist'});
            return;
        }
        try {
            previewImage(fileName);
            console.log("Preview finished.");
            response.send({success: true, destination: destination, content: "rbxasset://previews/"+fileName});
        }
        catch (err) {
            console.log("Preview failed:",err);
            response.send({success: false, errorCode: 500, error: err.toString()});
        }
    }
);

app.post('/unpreview',
    express.json(),
    async(request, response) => {
        console.log("Received unpreview request",request.body);
        if (!settings.allow_previews) {
            console.log("Rejected preview request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }
        let destination = sanitizeFilename(request.body.destination);
        let fileName = destination+".png";
        try {
           let directories = await getPreviewDirectory();
            directories.shift();
            for (let dir of directories) {
                await fs.remove(dir + "/" + fileName);
            }
            console.log("Unpreview finished.");
            response.send({success: true});
        }
        catch (err) {
            console.log("Unpreview failed:",err);
            response.send({success: false, errorCode: 700, error: err.toString()});
        }
    }
);

app.post('/delete',
    express.json(),
    async(request, response) => {
        console.log("Received delete request",request.body);
        let destination = sanitizeFilename(request.body.destination);
        let fileName = destination+".png";
        let directories = await getPreviewDirectory();
        try {
            for (let dir of directories) {
                await fs.remove(dir + "/" + fileName);
            }
            console.log("Delete finished.");
            response.send({success: true});
        }
        catch (err) {
            console.log("Delete failed:",err);
            response.send({success: false, errorCode: 600, error: err});
        }
    }
);

app.post('/calibrate',
    express.json(),
    async (request, response) => {
        console.log("Received calibrate request",request.body);
        let color = request.body.color;
        let tolerance = request.body.tolerance;
        let r = color[0], g = color[1], b = color[2];
        try {
            let scrBuffer = await screenshot(screenshotOptions);
            let image = await jimp.read(scrBuffer);
            let start = null;
            let end = null;
            image.scan(0, 0, image.bitmap.width, image.bitmap.height, function(x, y, idx) {
                var red   = this.bitmap.data[ idx + 0 ];
                var green = this.bitmap.data[ idx + 1 ];
                var blue  = this.bitmap.data[ idx + 2 ];
                if (Math.abs(red - r) <= tolerance && Math.abs(green - g) <= tolerance && Math.abs(blue - b) <= tolerance) {
                    if (!start || x + y <= start[0] + start[1]) {
                        start = [x, y];
                    }
                    if (!end || x + y >= end[0] + end[1]) {
                        end = [x, y];
                    }
                }
            });
            if (start && end && start[0] <= end[0] && start[1] <= end[1]) {
                calibration.start = start;
                calibration.end = end;
                console.log("Calibrate finished: (",start,") to (",end,")");
                response.send({success: true, calibration: calibration});
            } else {
                console.log("Calibration failed (could not find start and end)");
                response.send({success: false, errorCode: 401, error: "Could not find start and end"});
            }
        }
        catch (err) {
            console.log("Calibration failed:",err)
            response.send({success: false, errorCode: 400, error: err.toString()});
        }
    }
);

app.listen(28081, async () => {
    console.log("Listening for requests on port 28081");
    await getPreviewDirectory(); // copy previews directory if necessary
});
