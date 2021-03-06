"use strict";

const express = require("express");
const screenshot = require("screenshot-desktop");
const fs = require("fs-extra");
const jimp = require("jimp");
const request = require("request-promise");
const parseDomain = require("parse-domain");
const sprintf = require("sprintf-js").sprintf;
const escape = require("querystring").escape;
const sanitizeFilename = require("sanitize-filename");
const recursiveReaddir = require("recursive-readdir");
const upath = require("upath");
const Delaunay = require("d3-delaunay").Delaunay;

const DEBUG_MODE = false;

const screenshotOptions = {
    format: "png"
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
    let versionsFile = await fs.open(versionsPath, "r");
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
    let localDir = upath.resolve("./screenshots");
    if (!await fs.exists(localDir)) {
        await fs.mkdir(localDir);
    }
    if (settings.allow_previews) {
        let localPreviewDir = upath.resolve("./previews");
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

function getFilePath(fileName) {
    let parts = fileName.split("/");
    for (let index in parts) {
        parts[index] = sanitizeFilename(parts[index]);
    }
    return parts.join("/");
}

function isWithin(dir, parent) {
    const relative = upath.relative(parent, dir);
    return !!relative && !relative.startsWith("..") && !upath.isAbsolute(relative);
}

async function getNameFromAbsolutePath(absolutePath) {
    let directories = await getPreviewDirectory();
    for (let parent of directories) {
        if (isWithin(absolutePath, parent)) {
            let relativePath = upath.relative(parent, absolutePath);
            let directoryName = upath.dirname(relativePath);
            let baseName = upath.basename(relativePath);
            baseName = baseName.replace(/\.png$/, "").replace(/\.json$/, "");
            return directoryName+"/"+baseName;
        }
    }
    return absolutePath;
}

async function forDirectoryDestination(info, func, directories) {
    if (info.directory) {
        let directory = getFilePath(info.directory);
        let folderPath = directories[0]+"/"+directory;
        let imageFilePaths;
        if (info.recursive) {
            imageFilePaths = await recursiveReaddir(folderPath);
        } else {
            imageFilePaths = await fs.readdir(folderPath);
        }
        for (let imageFilePath of imageFilePaths) {
            if (imageFilePath.match("\\.png$")) {
                let name = await getNameFromAbsolutePath(imageFilePath);
                await func(name, imageFilePath);
            }
        }
    }
    if (info.destination) {
        let destination = getFilePath(info.destination);
        let imageFilePath = directories[0]+"/"+destination+".png";
        await func(info.destination, imageFilePath);
    }
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

const uploadUrl = "http://data.roblox.com/data/upload/json?assetTypeId=%i&name=%s&description=%s&groupId=%s";
async function uploadImage(name, imagePath, groupId, cookie) {
    try {
        let fileBuffer = await fs.readFile(imagePath);
        let response = await robloxRequest({
            method: "POST",
            url: sprintf(uploadUrl, 13, escape(name), "", groupId || ""),
            headers: {
                "Cookie": ".ROBLOSECURITY=" + cookie + ";",
                "Host": "data.roblox.com",
                "Content-type": "*/*",
                "User-Agent": "Roblox/WinInet",
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
            regKey.get(".ROBLOSECURITY", function(err, item) {
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
    await fs.ensureFile(directories[1]+"/"+name);
    await fs.ensureFile(directories[2]+"/"+name);
    await fs.copy(directories[0]+"/"+name, directories[1]+"/"+name);
    await fs.copy(directories[0]+"/"+name, directories[2]+"/"+name);
}

const app = express();

let calibration = {
    start: [0, 0],
    end: [0, 0]
};

app.get("/settings",
    express.json(),
    async (request, response) => {
        response.send({success: true, settings: settings});
    }
);

app.post("/login",
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

app.post("/calibrate",
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
                let red   = this.bitmap.data[ idx + 0 ];
                let green = this.bitmap.data[ idx + 1 ];
                let blue  = this.bitmap.data[ idx + 2 ];
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
            console.log("Calibration failed:",err);
            response.send({success: false, errorCode: 400, error: err.toString()});
        }
    }
);

app.post("/upload",
    express.json(),
    async (request, response) => {
        console.log("Received upload request",request.body);
        if (!settings.allow_uploads) {
            console.log("Rejected upload request because uploads are disabled.");
            response.send({success: false, errorCode: 14, error: "Uploads have been disabled. Check settings.json."});
            return;
        }
        let destination = getFilePath(request.body.destination);
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
            response.send({success: false, errorCode: 201, error: "File does not exist"});
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

const neighborLocations = [
    [-1, -1],
    [ 0, -1],
    [ 1, -1],
    [ 1,  0],
    [ 1,  1],
    [ 0,  1],
    [-1,  1],
    [-1,  0]
];
let maskCache = {};
app.post("/screenshot",
    express.json(),
    async (request, response) => {
        console.log("Received screenshot request",request.body);
        let crop = request.body.crop;
        let destination = getFilePath(request.body.destination);
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
                        let red   = this.bitmap.data[ idx + 0 ];
                        let green = this.bitmap.data[ idx + 1 ];
                        let blue  = this.bitmap.data[ idx + 2 ];
                        let otherRed   = imageA.bitmap.data[ idx + 0 ];
                        let otherGreen = imageA.bitmap.data[ idx + 1 ];
                        let otherBlue  = imageA.bitmap.data[ idx + 2 ];
                        this.bitmap.data[ idx + 0 ] = 255 - Math.abs(red - otherRed);
                        this.bitmap.data[ idx + 1 ] = 255 - Math.abs(green - otherGreen);
                        this.bitmap.data[ idx + 2 ] = 255 - Math.abs(blue - otherBlue);
                    });
                    imageA.mask(mask, 0, 0);
                    imageB.mask(mask, 0, 0);
                    await debugWrite(imageA, dirs[0]+"/"+destination+"-masked-a.png");
                    await debugWrite(imageB, dirs[0]+"/"+destination+"-masked-b.png");
                    // start + (end - start)*pct = result
                    // 0 + (red - 0)*pct
                    // 255 + (red - 255)*pct
                    // (result - start)/pct + start = end
                    let voronoiPoints = [];
                    let voronoiColors = [];
                    imageA.scan(0, 0, imageA.bitmap.width, imageA.bitmap.height, function(x, y, idx) {
                        let alpha = this.bitmap.data[ idx + 3 ];
                        if (alpha != 0) { 
                            let red   = this.bitmap.data[ idx + 0 ];
                            let green = this.bitmap.data[ idx + 1 ];
                            let blue  = this.bitmap.data[ idx + 2 ];
                            red   = red*255/alpha;
                            green = green*255/alpha;
                            blue  = blue*255/alpha;

                            let otherRed   = imageB.bitmap.data[ idx + 0 ];
                            let otherGreen = imageB.bitmap.data[ idx + 1 ];
                            let otherBlue  = imageB.bitmap.data[ idx + 2 ];
                            let otherAlpha = imageB.bitmap.data[ idx + 3 ];
                            otherRed   = (otherRed - 255)*255/otherAlpha + 255;
                            otherGreen = (otherGreen - 255)*255/otherAlpha + 255;
                            otherBlue  = (otherBlue - 255)*255/otherAlpha + 255;

                            this.bitmap.data[ idx + 0 ] = Math.min(Math.max(red/2 + otherRed/2, 0), 255);
                            this.bitmap.data[ idx + 1 ] = Math.min(Math.max(green/2 + otherGreen/2, 0), 255);
                            this.bitmap.data[ idx + 2 ] = Math.min(Math.max(blue/2 + otherBlue/2, 0), 255);

                            // DEBUG:
                            if (DEBUG_MODE) {
                                mask.bitmap.data[ idx + 0 ] = red;
                                mask.bitmap.data[ idx + 1 ] = green;
                                mask.bitmap.data[ idx + 2 ] = blue;
                                mask.bitmap.data[ idx + 3 ] = 255;

                                imageB.bitmap.data[ idx + 0 ] = otherRed;
                                imageB.bitmap.data[ idx + 1 ] = otherGreen;
                                imageB.bitmap.data[ idx + 2 ] = otherBlue;
                                imageB.bitmap.data[ idx + 3 ] = 255;
                            }

                            // Voronoi
                            for (let offset of neighborLocations) {
                                let neighborAlpha = this.bitmap.data[imageA.getPixelIndex(x + offset[0], y + offset[1]) + 3];
                                if (neighborAlpha == 0) {
                                    voronoiPoints.push([x, y]);
                                    voronoiColors.push([red, green, blue]);
                                    break;
                                } 
                            }
                        }
                    });
                    if (voronoiPoints.length > 0) {
                        let dela = Delaunay.from(voronoiPoints);
                        imageA.scan(0, 0, imageA.bitmap.width, imageA.bitmap.height, function(x, y, idx) {
                            let alpha = this.bitmap.data[ idx + 3 ];
                            if (alpha == 0) { 
                                let closestIndex = dela.find(x, y);
                                //console.log("closest:",closestIndex,"max:",voronoiColors.length);
                                if (closestIndex != -1) {
                                    let color = voronoiColors[closestIndex];

                                    this.bitmap.data[ idx + 0 ] = color[0];
                                    this.bitmap.data[ idx + 1 ] = color[1];
                                    this.bitmap.data[ idx + 2 ] = color[2];
                                }
                            }
                        });
                    }
                    await debugWrite(mask, dirs[0]+"/"+destination+"-test-a.png");
                    await debugWrite(imageB, dirs[0]+"/"+destination+"-test-b.png");
                    await debugWrite(imageA, dirs[0]+"/"+destination+"-test-final.png");
                    image = imageA;
                    console.log("Screenshot finished. Mask completed.");
                    delete maskCache[destination];
                }
            }
            let name = destination+".png";
            console.log("Writing to:"+(dirs[0] + "/" + name));
            await fs.ensureFile(dirs[0] + "/" + name);
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

app.post("/preview",
    express.json(),
    async (request, response) => {
        console.log("Received preview request",request.body);
        if (!settings.allow_previews) {
            console.log("Rejected preview request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }
        let destination = getFilePath(request.body.destination);
        let fileName = destination+".png";
        let screenshotsDir = (await getPreviewDirectory())[0];
        let filePath = screenshotsDir + "/" + fileName;
        if (!await fs.exists(filePath)) {
            console.log("Preview failed (file ("+filePath+") does not exist)");
            response.send({success: false, errorCode: 501, error: "File does not exist"});
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

app.post("/unpreview",
    express.json(),
    async(request, response) => {
        console.log("Received unpreview request",request.body);
        if (!settings.allow_previews) {
            console.log("Rejected preview request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }
        let destination = getFilePath(request.body.destination);
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

app.post("/delete",
    express.json(),
    async(request, response) => {
        console.log("Received delete request",request.body);
        let fileName;
        if (request.body.destination) {
            let destination = getFilePath(request.body.destination);
            fileName = destination+".png";
        } else {
            fileName = getFilePath(request.body.directory);
        }
        let directories = await getPreviewDirectory();
        try {
            for (let dir of directories) {
                await fs.remove(dir + "/" + fileName);
            }
            if (request.body.destination) {
                await fs.remove(directories[0] + "/" + getFilePath(request.body.destination)+".json");
            }
            console.log("Delete finished.");
            response.send({success: true});
        }
        catch (err) {
            console.log("Delete failed:",err);
            response.send({success: false, errorCode: 600, error: err.toString()});
        }
    }
);

app.post("/spritesheet",
    express.json(),
    async(request, response) => {
        console.log("Received spritesheet request",request.body);
        let directories = await getPreviewDirectory();
        let spriteSize = request.body.size;
        let spriteDestination = getFilePath(request.body.destination);
        let spriteFileName = spriteDestination+".png";
        let spriteFilePath = directories[0] + "/" + spriteFileName;
        let images = request.body.images;
        let isPreview = request.body.preview;
        if (isPreview && !settings.allow_previews) {
            console.log("Rejected spritesheet request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }
        try {
            let sheet = await new jimp(spriteSize[0], spriteSize[1]);
            let imagesInSheet = {};
            for (let info of images) {
                let imageDestination = getFilePath(info.destination);
                let imageFileName = imageDestination+".png";
                let imageFilePath = directories[0]+"/"+imageFileName;
                if (!await fs.exists(imageFilePath)) {
                    console.log("Spritesheet failed (file ("+imageFilePath+") does not exist)");
                    response.send({success: false, errorCode: 901, error: "File does not exist", file: info.destination});
                    return;
                }
                let image = await jimp.read(imageFilePath);
                if (info.resize) {
                    let resizeMode = undefined;
                    if (info.resizeMode) {
                        resizeMode = jimp["RESIZE_"+info.resizeMode.toUpperCase()];
                    }
                    if (typeof(info.resize) == "number") {
                        image.resize(image.bitmap.width*info.resize, image.bitmap.height*info.resize);
                    } else {
                        image.resize(info.resize[0], info.resize[1], resizeMode);
                    }
                }
                let format = info.format || "NAME";
                let formatted = format.replace("NAME", imageDestination);
                imagesInSheet[formatted] = [info.position[0], info.position[1], image.bitmap.width, image.bitmap.height];
                sheet.composite(image, info.position[0], info.position[1]);
            }
            await fs.ensureFile(spriteFilePath);
            await sheet.writeAsync(spriteFilePath);
            await fs.writeJson(directories[0] + "/" + spriteDestination + ".json", imagesInSheet);
            if (isPreview) {
                await previewImage(spriteFileName);
                console.log("Saved preview.");
            }
            console.log("Spritesheet finished.");
            let singleSheet = {destination: spriteDestination, images: imagesInSheet, content: isPreview && "rbxasset://previews/"+spriteFileName || undefined};
            response.send({success: true, sheets: [singleSheet], destination: singleSheet.destination, content: singleSheet.content});
        }
        catch (err) {
            console.log("Spritesheet failed:",err);
            response.send({success: false, errorCode: 900, error: err.toString()});
        }
    }
);

app.post("/autospritesheet",
    express.json(),
    async(request, response) => {
        console.log("Received autospritesheet request",request.body);
        let directories = await getPreviewDirectory();
        let spriteSize = request.body.size;

        let spriteDestination = getFilePath(request.body.destination);
        if (spriteDestination.indexOf("PAGE") == -1) {
            spriteDestination = spriteDestination+"-PAGE";
        }

        let isPreview = request.body.preview;
        if (isPreview && !settings.allow_previews) {
            console.log("Rejected autospritesheet request because previews are disabled.");
            response.send({success: false, errorCode: 11, error: "Previews have been disabled. Check settings.json."});
            return;
        }

        let images = request.body.images;

        let algorithm = request.body.algorithm || "rows";

        let spriteImages = [];
        try {
            async function addImageToSheet(imageFilePath, info) {
                let image = await jimp.read(imageFilePath);
                if (info.resize) {
                    let resizeMode = undefined;
                    if (info.resizeMode) {
                        resizeMode = jimp["RESIZE_"+info.resizeMode.toUpperCase()];
                    }
                    if (typeof(info.resize) == "number") {
                        image.resize(image.bitmap.width*info.resize, image.bitmap.height*info.resize);
                    } else {
                        image.resize(info.resize[0], info.resize[1], resizeMode);
                    }
                }
                spriteImages.push({image: image, path: imageFilePath, format: info.format || "NAME"});
            }
            for (let info of images) {
                if (info.directory) {
                    let directory = getFilePath(info.directory);
                    let folderPath = directories[0]+"/"+directory;
                    if (!await fs.exists(folderPath)) {
                        console.log("Autospritesheet failed (directory ("+folderPath+") does not exist)");
                        response.send({success: false, errorCode: 901, error: "File does not exist", file: info.destination});
                        return;
                    } else {
                        let imageFilePaths;
                        if (info.recursive) {
                            imageFilePaths = await recursiveReaddir(folderPath);
                            for (let imageFilePath of imageFilePaths) {
                                if (imageFilePath.match("\\.png$")) {
                                    await addImageToSheet(imageFilePath, info);
                                }
                            }
                        } else {
                            imageFilePaths = await fs.readdir(folderPath);
                            for (let imageFilePathBase of imageFilePaths) {
                                let imageFilePath = folderPath+"/"+imageFilePathBase;
                                if (imageFilePath.match("\\.png$")) {
                                    await addImageToSheet(imageFilePath, info);
                                }
                            }
                        }
                    } 
                } else if (info.destination) {
                    let destination = getFilePath(info.destination);
                    let imageFileName = destination+".png";
                    let imageFilePath = directories[0]+"/"+imageFileName;
                    if (!await fs.exists(imageFilePath)) {
                        console.log("Autospritesheet failed (file ("+imageFilePath+") does not exist)");
                        response.send({success: false, errorCode: 901, error: "File does not exist", file: info.destination});
                        return;
                    }
                    await addImageToSheet(imageFilePath, info);
                }
            }

            let sheets = [];
            if (algorithm == "rows") {
                console.log("Using rows algorithm");
                spriteImages.sort((a, b) => {
                    return b.image.bitmap.width - a.image.bitmap.width;
                });
                let page = 0;
                while (spriteImages[0]) {
                    page = page + 1;
                    let sheet = await new jimp(spriteSize[0], spriteSize[1]);
                    let imagesInSheet = {};
                    let rows = [[0, 0, spriteSize[1]]];
                    while (rows[0] && rows[0][1] < spriteSize[1]) {
                        let row = rows[0];
                        let space = [spriteSize[0] - row[0], row[2]];
                        let available, availableIndex;
                        for (let i = spriteImages.length - 1; i >= 0; i--) {
                            let imageInfo = spriteImages[i];
                            let image = imageInfo.image;
                            if (image.bitmap.width > space[0]) {
                                break;
                            } else if (image.bitmap.height <= space[1] && (!available || available.image.bitmap.height < image.bitmap.height)) {
                                available = imageInfo;
                                availableIndex = i;
                            }
                        }
                        if (!available) {
                            rows.shift();
                        } else {
                            spriteImages.splice(availableIndex, 1);
                            sheet.composite(available.image, row[0], row[1]);
                            let relative = await getNameFromAbsolutePath(available.path);
                            let formatted = available.format.replace("NAME", relative);
                            imagesInSheet[formatted] = [row[0], row[1], available.image.bitmap.width, available.image.bitmap.height];
         
                            let newRow = [row[0], row[1] + available.image.bitmap.height, row[2] - available.image.bitmap.height];

                            row[0] = row[0] + available.image.bitmap.width;
                            row[2] = available.image.bitmap.height;
                            if (row[0] >= spriteSize[0]) {
                                rows.shift();
                            }

                            if (newRow[1] < spriteSize[1] && newRow[2] > 0) {
                                rows.splice(1, 0, newRow);
                            }
                        }
                    }
                    let destination = spriteDestination.replace("PAGE", page.toString());
                    let name = destination+".png";
                    let spriteFilePath = directories[0] + "/" + name;
                    await fs.ensureFile(spriteFilePath);
                    await sheet.writeAsync(spriteFilePath);
                    let jsonFilePath = directories[0] + "/" + (spriteDestination+".json").replace("PAGE", page.toString());
                    await fs.writeJson(jsonFilePath, imagesInSheet);
                    console.log("Saved sprite page "+page+" with "+imagesInSheet.length+" images.");
                    if (isPreview) {
                        await previewImage(name);
                        console.log("Saved preview.");
                    }
                    sheets.push({destination: destination, images: imagesInSheet, content: (isPreview ? "rbxasset://previews/"+destination : undefined)});
                }
            }
            console.log("Autospritesheet finished.");
            response.send({success: true, sheets: sheets});
        }
        catch (err) {
            console.log("Autospritesheet failed:",err);
            response.send({success: false, errorCode: 900, error: err.toString()});
        }
    }
);

app.listen(28081, async () => {
    console.log("Listening for requests on port 28081");
    await getPreviewDirectory(); // copy previews directory if necessary
});
