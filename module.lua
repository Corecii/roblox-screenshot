--[[

#Screenshotter
Combined with a small Node.JS server, takes, crops, and masks screenshots of the Roblox viewport for automated screenshotting.

Module API:
	Screenshotter .new{
		optional string apiBase = 'localhost:28081'
		optional number port/[1] = 28081
		optional autoRetry = true
	}
		Creates a Screenshotter for the given url or localhost:port
		Uses 'http://localhost:28081' by default
		If autoRetry is on then requests will be retried until they succeed when the http request limit is reached

Result API:
	bool .success
	number .errorCode
	string .error
	Result :Assert()
		Errors if this result did not succeed.
		Errors with the errorCode and error.
		Returns self.
	Result :AssertIgnore(string [1], string [2], string [3], ...)
		The parameters act as errors to ignore
		Errors if this result did not succeed.
		Errors with the errorCode and error.
		Returns self.
	bool :IsError(string errorName)
		Returns whether this result is an instance of the given errors.
		Errors if any of the given error names are invalid.
	bool :IsAnyError(string [1], string [2], string [3], ...)
		Returns whether this result is an instance of any of the given errors.
		Errors if any of the given error names are invalid.
	string :ToString()
		Gets a string representation of this result for debugging
	Result :Print(string prefix)
		Prints a string representation prefixed by `prefix` for debugging. Returns self.

Screenshotter API:
	result{Rect calibration} :Calibrate{
		optional Color3 color/[1] = Color3.fromRGB(255, 0, 255)
		optional number tolerance/[2] = 1
	}
		Calibrates the viewport location and size by covering it in a colored gui.
		The color is determined by the given color or the default magenta.
		The tolerance is the maximum difference the R, G, or B values can be from the given color to count as part of the viewport.
		result:
			`calibration` is the region of the screen that the Roblox viewport takes up.

	result{string destination, string content} :Screenshot{
		string destination/[1]
		optional Vector2 crop/[2]
		optional Rect crop/[2]
		optional bool mask/[3] = false
		optional bool preview = false
	}
		Takes a screenshot. Crops if applicable. Copies to preview directories if applicable.
		If `crop` is a Rect, it will crop from any part of the screen.
		If `crop` is a Vector2, it will crop from the center of the screen.
		If `mask` is true then two screenshots are taken with black and white backgrounds which are combined to mask out the background.
		If `mask` is a number, it's used as the distance for the background. The default is 1000.
		result:
			`destination` is the sanitized `destination`
			`content` is present only if `preview = true` and is the string content you can put in a decal or imagelabel to see the preview in-game.

	result{string destination, string content} :Preview{
		string destination/[1]
	}
		Copies a screenshot to the previews directory.
		result:
			`destination` is the sanitized `destination`
			`content` is the string content you can put in a decal or imagelabel to see the preview in-game.

	result{} :Unpreview{
		string destination/[1]
	}
		Deletes preview copies of a screenshot.

	result{} :Delete{
		string destination/[1]
	}
		Deletes a screenshot and its preview copies.

	result{string destination, number imageId, string content} :Upload{
		string destination/[1]
		optional string name/[2]
		optional number groupId/[3]
		optional bool deletePreview = false
		optional bool delete = false
		optional bool autoRetry = false
		optional string cookie
	}
		Uploads the screenshot with the given destination to Roblox.
		If name is not provided then the destination is used.
		If deletePreview is true then any previews of the image are deleted *only if uploading succeeds*. Errors encountered while deleting the previews are not returned.
		If delete is true then the screenshot and any previews of the image are delete *only is uploading succeeds*. Errors encountered while deleting the are not returned.
		If autoRetry is true then the request is retried every 60 seconds if the user is uploading too much.
		If cookie is not provided then the internal cookie from :Login is used.
		result:
			`destination` is the sanitized `destination`
			`content` is the string content you can put in a decal or imagelabel to see the preview in-game.
			`imageId` is the id of the *image* (not the decal), which becomes part of `content`

	result{string cookie} :Login{
		string username/[1]
		string password/[2]
	}
	result{string cookie} :Login{
		bool registry = true
	}
	result{string cookie} :Login{
		string cookie
	}
		Logs this Screenshotter into Roblox. The cookie is saved to the screenshotter for future requests.
		The registry option will grab the currently logged in user from the Windows registry. The registry option *does not* return the actual cookie, just a placeholder.

	void :Logout()
		Removes stored cookie information to log the user out.

	result{bool loggedIn} :LoggedIn()
		Returns whether or not this screenshotter has a cookie saved. *Does not* make sure that the login session is valid.

	void :SaveCameraState{
		optional Camera camera/[1]
	}
		Saves the camera CFrame, Focus, and FoV to the Screenshotter to be restored later.

	void :LoadCameraState()
		Restores the saved camera state.

	result{number fov} :GetCameraFovForSize{
		number fov
		Vector2 size
	}
		Gets the actual vertical FoV needed for the given region in the middle of the screen with size `size` to have the given vertical FoV `fov`.

	result{Vector3 position, CFrame cframe, CFrame focus, number fov} :GetCameraParams{
		number fov
		optional Vector2 size
		Vector3 vector
		optional Vector3 upVector

		optional Vector3 radiusCenter
		optional number radius

		optional Array<Vector3> points
		optional Array<Instance> parts

		optional CFrame cframe
	}
		Gets the required camera parameters to fit the radius, points, or parts within a center part of the screen with the given size, FoV, and direction (vector).
		If `size` is not provided, it defaults to the full screen size.
		If `upVector` is not provided then it defaults to the vector nearest to Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
		You can provide either radiusCenter and radius OR an array of points and/or parts OR a camera cframe (where it will only solve for needed FoV).
		If you provide points, then the # of points must be greater than 1.

	result{Vector3 position, CFrame cframe, CFrame focus, number fov} :CenterCamera{
		optional Camera camera,
		number fov
		optional Vector2 size
		Vector3 vector
		optional Vector3 upVector

		optional Vector3 radiusCenter
		optional number radius

		optional Array<Vector3> points
		optional Array<Instance> parts

		optional CFrame cframe
	}
		Calls GetCameraParams then applies them to the camera.

Error codes for use with IsError:
	Generic (category)

	---
	Http (category)
	HttpJsonEncodeFail
	HttpFail
	HttpRequestLimit
	HttpJsonDecodeFail

	---
	Disallowed (category)
	DisallowedGeneric
	DisallowedPreviews
	DisallowedLoginRegistry
	DisallowedLoginPassword
	DisallowedUploads

	---
	Login (category)
	LoginGeneric

	---
	Upload (category)
	UploadGeneric
	UploadFileDoesNotExist
	UploadNotLoggedIn
	UploadTooOften
	UploadInappropriate
	UploadFailed

	---
	Screenshot (category)
	ScreenshotGeneric

	---
	Preview (category)
	PreviewGeneric
	PreviewFileDoesNotExist

	---
	Unpreview (category)
	UnpreviewGeneric

	---
	Delete (category)
	DeleteGeneric

	---
	Calibrate (category)
	CalibrateGeneric
	CalibrateNoStartEnd

	---
	Camera (category)
	CameraSizeTooBig
	CameraFovOutOfBounds
	CameraNeededFovOutOfBounds
	CameraNoCenteringMethods
--]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local function makeBackground()
	local part = Instance.new("Part")
	part.Shape = "Ball"
	part.Size = Vector3.new(0.05,0.05, 0.05)
	part.Transparency = 1
	part.TopSurface = "Smooth"
	part.BottomSurface = "Smooth"
	part.CanCollide = false
	part.Anchored = true
	local bbg = Instance.new("BillboardGui", part)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.Parent = bbg
	local id = "Background "..HttpService:GenerateGUID()
	part.Name = id
	local distance = 1000
	return {
		SetDistance = function(self, dist)
			distance = dist
		end,
		SetColor = function(self, color)
			frame.BackgroundColor3 = color
		end,
		Show = function(self)
			RunService:UnbindFromRenderStep(id)
			RunService:BindToRenderStep(id, Enum.RenderPriority.Camera.Value + 1, function()
				part.Parent = workspace.CurrentCamera
				part.CFrame = workspace.CurrentCamera.CFrame*CFrame.new(0,0,-distance)
				local screenSize = workspace.CurrentCamera.ViewportSize
				bbg.Size = UDim2.new(0, screenSize.x, 0, screenSize.y)
			end)
		end,
		Hide = function(self)
			RunService:UnbindFromRenderStep(id)
			part.Parent = nil
		end
	}
end

local function makeCalibrator(color)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Calibrator"
	screenGui.DisplayOrder = 100000
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.Parent = screenGui
	return screenGui
end

local function waitForGuiUpdate()
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
end

local PRIVELEGED = pcall(function() game:GetService("CoreGui"):GetChildren() end)

local DEBUG_MODE = false
local DEBUG_MODE_3D = false
local dbgPrint, dbgWarn
if DEBUG_MODE then
	function dbgPrint(...)
		print("dbg:",...)
	end
	function dbgWarn(...)
		local asStr = {...}
		for i, v in next, asStr do
			asStr[i] = tostring(v)
		end
		warn("dbg: "..table.concat(asStr, " "))
	end
else
	function dbgPrint() end
	function dbgWarn() end
end

local function typeCheck(name, allowed, count, ...)
	local allowedDict = {}
	for i = 1, #allowed do
		allowedDict[allowed[i]] = true
	end
	local args = {...}
	for i = 1, count do
		local iType = typeof(args[i])
		if iType == "Instance" and not allowedDict.Instance then
			local arg = args[i]
			local isAllowed = false
			for i_a = 1, #allowed do
				if arg:IsA(allowed[i_a]) then
					isAllowed = true
					break
				end
			end
			if not isAllowed then
				error("Bad type for "..name..": got "..arg.ClassName..", expected "..(#allowed > 0 and "one of: "..table.concat(allowed, ", ") or allowed[1])..".")
			end
		elseif not allowedDict[iType] then
			error("Bad type for "..name..": got "..iType..", expected "..(#allowed > 0 and "one of: "..table.concat(allowed, ", ") or allowed[1])..".")
		end
	end
end

local function limitArgs(name, args, allowed)
	local allowedDict = {}
	for i = 1, #allowed do
		allowedDict[allowed[i]] = true
	end
	for key in next, args do
		if not allowedDict[key] then
			error("Argument "..tostring(key).." not allowed for "..name)
		end
	end
end

local errorCodes = {
	Generic = function(code)
		return code >= 0 and code < 100
	end,

	---
	Http = function(code)
		return code >= 1 and code < 10
	end,
	HttpJsonEncodeFail = 1,
	HttpFail = 2,
	HttpRequestLimit = 3,
	HttpJsonDecodeFail = 4,

	---
	Disallowed = function(code)
		return code >= 10 and code < 30
	end,
	DisallowedGeneric = 10,
	DisallowedPreviews = 11,
	DisallowedLoginRegistry = 12,
	DisallowedLoginPassword = 13,
	DisallowedUploads = 14,

	---
	Login = function(code)
		return code >= 100 and code < 200
	end,
	LoginGeneric = 100,

	---
	Upload = function(code)
		return code >= 200 and code < 300
	end,
	UploadGeneric = 200,
	UploadFileDoesNotExist = 201,
	UploadNotLoggedIn = 210,
	UploadTooOften = 211,
	UploadInappropriate = 212,
	UploadFailed = 220,

	---
	Screenshot = function(code)
		return code >= 300 and code < 400
	end,
	ScreenshotGeneric = 300,

	---
	Preview = function(code)
		return code >= 500 and code < 600
	end,
	PreviewGeneric = 500,
	PreviewFileDoesNotExist = 501,

	---
	Unpreview = function(code)
		return code >= 700 and code < 800
	end,
	UnpreviewGeneric = 700,

	---
	Delete = function(code)
		return code >= 600 and code < 700
	end,
	DeleteGeneric = 600,

	---
	Calibrate = function(code)
		return code >= 400 and code < 500
	end,
	CalibrateGeneric = 400,
	CalibrateNoStartEnd = 401,

	---
	Camera = function(code)
		return code >= 800 and code < 900
	end,
	CameraSizeTooBig = 801,
	CameraFovOutOfBounds = 802,
	CameraNeededFovOutOfBounds = 803,
	CameraNoCenteringMethods = 804,
}

local resultMeta = {}
resultMeta.__index = resultMeta
function resultMeta:Assert()
	if not self.success then
		error("("..tostring(self.errorCode)..") "..tostring(self.error))
	end
	return self
end
function resultMeta:AssertIgnore(...)
	local args = {...}
	if not self.success then
		if args and #args > 0 then
			for i = 1, #args do
				if self:IsError(args[i]) then
					return self
				end
			end
		end
		error("("..tostring(self.errorCode)..") "..tostring(self.error))
	end
	return self
end
function resultMeta:IsError(name)
	if not name then
		return self.errorCode and true or false
	end
	local check = errorCodes[name]
	if not check then
		error("Unknown error name '"..tostring(name).."' ("..typeof(name)..")")
	end
	if type(check) == "number" then
		return self.errorCode == check
	elseif type(check) == "function" then
		return self.errorCode and check(self.errorCode) or false
	else
		error("Unknown check type ("..typeof(check)..")")
	end
end
function resultMeta:IsAnyError(...)
	local args = {...}
	if not args or #args == 0 then
		return self.errorCode and true or false
	end
	for i = 1, #args do
		local name = args[i]
		local check = errorCodes[name]
		if not check then
			error("Unknown error name '"..tostring(name).."' ("..typeof(name)..")")
		end
		if type(check) == "number" then
			return self.errorCode == check
		elseif type(check) == "function" then
			return self.errorCode and check(self.errorCode) or false
		else
			error("Unknown check type ("..typeof(check)..")")
		end
	end
end
function resultMeta:ToString()
	local contains = {}
	for k, v in next, self do
		contains[#contains + 1] = tostring(k).." = "..tostring(v)
	end
	return "{\n"..table.concat(contains,"\n").."\n}"
end
function resultMeta:Print(prefix)
	print((prefix or "")..self:ToString())
	return self
end
local function asResult(result)
	return setmetatable(result, resultMeta)
end

local function makeApiRequest(url, path, method, body, autoRetry)
	local jsonSuccess, jsonBody
	if body then
		jsonSuccess, jsonBody = pcall(HttpService.JSONEncode, HttpService, body)
		if not jsonSuccess then
			dbgWarn("Json failure:",jsonBody)
			return asResult{
				success = false,
				errorCode = 1,
				error = jsonBody,
			}
		else
			dbgPrint("Json success:",jsonBody)
		end
	end
	dbgPrint("Sending request to:",url..path,"with method",method)
	local start = tick()
	local tries = 1
	local success, response
	while not success do
		success, response = pcall(HttpService.RequestAsync, HttpService, {
			Url = url..path,
			Method = method,
			Headers = {["Content-type"] = "application/json"},
			Body = jsonBody,
		})
		if success then
			dbgPrint("Request success after",tick() - start,"with response:\n",response.Body)
			local jsonDecodeSuccess, resultBody = pcall(HttpService.JSONDecode, HttpService, response.Body)
			if not jsonDecodeSuccess then
				return asResult{
					success = false,
					errorCode = 4,
					error = resultBody,
				}
			else
				return asResult(resultBody)
			end
		elseif not autoRetry or not response:find("Number of requests exceeded limit") then
			dbgWarn("Request failure after:",tick() - start,"with response:",response)
			return asResult{
				success = false,
				errorCode = response:find("Number of requests exceeded limit") and 3 or 2,
				error = response,
			}
		end
		dbgPrint("Retrying request because we reached the http request limit")
		tries = tries + 1
		wait(5)
	end
end

local object = {}
object.__index = object
local function makeObject(args)
	args = args or {}
	local apiBase = args.apiBase
	if not apiBase then
		local port = tonumber(args[1] or args.port or nil) or 28081
		apiBase = ("localhost:%d"):format(port)
	end
	while apiBase:sub(-1) == "/" do
		apiBase = apiBase:sub(1, #apiBase - 1)
	end
	if not apiBase:match("^https?://") then
		apiBase = "http://"..apiBase
	end
	return setmetatable({
		url = apiBase,
		autoRetry = args.autoRetry == nil and true or args.autoRetry
	}, object)
end

function object:GetSettings()
	if self.settings then
		return self.settings
	end
	local apiResult = makeApiRequest(self.url, "/settings", "GET", self.autoRetry);
	if apiResult.success then
		self.settings = apiResult
	end
	return apiResult
end

function object:Calibrate(args)
	args = args or {}
	limitArgs("Calibrate", args, {1, 2, "color", "tolerance"})
	typeCheck("parameter 1", {"Color3", "nil"}, 1, args[1])
	typeCheck("color", {"Color3", "nil"}, 1, args.color)
	typeCheck("parameter 2", {"number", "nil"}, 1, args[2])
	typeCheck("tolerance", {"number", "nil"}, 1, args.tolerance)

	local color = args[1] or args.color or Color3.new(1, 0, 1)
	local tolerance = args[2] or args.tolerance or 0

	local calibrator = makeCalibrator(color)
	calibrator.Parent = PRIVELEGED and game:GetService("CoreGui") or game:GetService("StarterGui")
		waitForGuiUpdate()
	local result = makeApiRequest(self.url, "/calibrate", "POST", {
		color = {math.floor(color.r*255), math.floor(color.g*255), math.floor(color.b*255)},
		tolerance = tolerance
	}, self.autoRetry)
	calibrator:Destroy()
	if result.calibration then
		result.calibration = Rect.new(Vector2.new(unpack(result.calibration.start)), Vector2.new(unpack(result.calibration["end"])))
	end
	return result
end

function object:Login(args)
	args = args or {}
	limitArgs("Login", args, {1, 2, "cookie", "registry", "username", "password"})
	local cookie = args.cookie
	if cookie then
		-- skip the login process
		typeCheck("cookie", {"string"}, 1, cookie)
		self.cookie = cookie
		return asResult{success = true, cookie = cookie}
	end
	if args.registry then
		typeCheck("registry", {"boolean"}, 1, args.registry)
		local result = makeApiRequest(self.url, "/login", "POST", {
			registry = true,
		}, self.autoRetry)
		self.cookie = result.cookie -- if the request fails then the cookie is cleared.
		return result
	end
	typeCheck("parameter 1", {"string", "nil"}, 1, args[1])
	typeCheck("username", {"string", "nil"}, 1, args.username)
	typeCheck("parameter 1 or username", {"string"}, 1, args[1] or args.username)
	typeCheck("parameter 2", {"string", "nil"}, 1, args[2])
	typeCheck("password", {"string", "nil"}, 1, args.password)
	typeCheck("parameter 2 or password", {"string"}, 1, args[2] or args.password)
	local username = args[1] or args.username or error("Username ([1] or ['username']) argument required")
	local password = args[2] or args.password or error("Password ([2] or ['password']) argument required")
	local result = makeApiRequest(self.url, "/login", "POST", {
		username = username,
		password = password,
	}, self.autoRetry)
	self.cookie = result.cookie -- if the request fails then the cookie is cleared.
	return result
end

function object:Logout()
	self.cookie = nil
	return asResult {success = true}
end

function object:LoggedIn()
	return asResult{success = true, loggedIn = self.cookie and true or false}
end

function object:Upload(args)
	args = args or {}
	limitArgs("Upload", args, {1, 2, 3, "destination", "name", "groupId", "cookie", "deletePreview", "delete","autoRetry"})
	typeCheck("parameter 1", {"string", "nil"}, 1, args[1])
	typeCheck("destination", {"string", "nil"}, 1, args.destination)
	typeCheck("parameter 1 or destination", {"string"}, 1, args[1] or args.destination)
	typeCheck("parameter 2", {"string", "nil"}, 1, args[2])
	typeCheck("name", {"string", "nil"}, 1, args.name)
	typeCheck("parameter 3", {"string", "nil"}, 1, args[3])
	typeCheck("groupId", {"number", "nil"}, 1, args.groupId)
	typeCheck("deletePreview", {"boolean", "nil"}, 1, args.deletePreview)
	typeCheck("delete", {"boolean", "nil"}, 1, args.delete)
	typeCheck("autoRetry", {"boolean", "nil"}, 1, args.autoRetry)
	local destination = args[1] or args.destination or error("Destination ([1] or ['destination']) argument required")
	local name = args[2] or args.name
	local groupId = args[3] or args.groupId
	local cookie = args.cookie or self.cookie
	local deletePreview = args.deletePreview
	local delete = args.delete
	local autoRetry = args.autoRetry
	local result
	while not result do
		result = makeApiRequest(self.url, "/upload", "POST", {
			destination = destination,
			name = name,
			groupId = groupId,
			cookie = cookie,
			deletePreview = deletePreview,
			delete = delete,
		}, self.autoRetry)
		if autoRetry and not result.success and result:IsError("UploadTooOften") then
			result = nil
			wait(60)
		end
	end
	return result
end

function object:Preview(args)
	args = args or {}
	limitArgs("Preview", args, {1, "destination"})
	typeCheck("parameter 1", {"string", "nil"}, 1, args[1])
	typeCheck("destination", {"string", "nil"}, 1, args.destination)
	typeCheck("parameter 1 or destination", {"string"}, 1, args[1] or args.destination)
	local destination = args[1] or args.destination or error("Destination ([1] or ['destination']) argument required")
	local result = makeApiRequest(self.url, "/preview", "POST", {
		destination = destination
	}, self.autoRetry)
	return result
end

function object:Unpreview(args)
	args = args or {}
	limitArgs("Unpreview", args, {1, "destination"})
	typeCheck("parameter 1", {"string", "nil"}, 1, args[1])
	typeCheck("destination", {"string", "nil"}, 1, args.destination)
	typeCheck("parameter 1 or destination", {"string"}, 1, args[1] or args.destination)
	local destination = args[1] or args.destination or error("Destination ([1] or ['destination']) argument required")
	local result = makeApiRequest(self.url, "/unpreview", "POST", {
		destination = destination
	}, self.autoRetry)
	return result
end

function object:Delete(args)
	args = args or {}
	limitArgs("Unpreview", args, {1, "destination"})
	typeCheck("parameter 1", {"string", "nil"}, 1, args[1])
	typeCheck("destination", {"string", "nil"}, 1, args.destination)
	typeCheck("parameter 1 or destination", {"string"}, 1, args[1] or args.destination)
	local destination = args[1] or args.destination or error("Destination ([1] or ['destination']) argument required")
	local result = makeApiRequest(self.url, "/delete", "POST", {
		destination = destination
	}, self.autoRetry)
	return result
end

function object:Screenshot(args)
	args = args or {}
	limitArgs("Screenshot", args, {1, 2, 3, "destination", "mask", "crop", "preview", "showMouseIcon", "showGui"})
	typeCheck("parameter 1", {"string", "nil"}, 1, args[1])
	typeCheck("destination", {"string", "nil"}, 1, args.destination)
	typeCheck("parameter 1 or destination", {"string"}, 1, args[1] or args.destination)
	typeCheck("parameter 2", {"boolean", "number", "nil"}, 1, args[3])
	typeCheck("mask", {"boolean", "number", "nil"}, 1, args.mask)
	typeCheck("parameter 3", {"Vector2", "Rect", "nil"}, 1, args[2])
	typeCheck("crop", {"Vector2", "Rect", "nil"}, 1, args.crop)
	typeCheck("preview", {"boolean", "nil"}, 1, args.preview)
	typeCheck("showMouseIcon", {"boolean", "nil"}, 1, args.showMouseIcon)
	typeCheck("showGui", {"boolean", "nil"}, 1, args.showGui)
	local destination = args[1] or args.destination
	local crop = args[2] or args.crop
	local mask = args[3] or args.mask or false
	local preview = args.preview or false
	local showMouseIcon = args.showMouseIcon or false
	local showGui = args.showGui or false
	local cropValue
	if typeof(crop) == "Rect" then
		cropValue = {
			x = crop.Min.x,
			y = crop.Min.y,
			width = crop.Width,
			height = crop.Height,
		}
	elseif typeof(crop) == "Vector2" then
		local screenSize = workspace.CurrentCamera.ViewportSize
		cropValue = {
			x = screenSize.x/2 - crop.x/2,
			y = screenSize.y/2 - crop.y/2,
			width = crop.x,
			height = crop.y,
		}
	end
	local mouse, preIcon
	if plugin then
		mouse = plugin:GetMouse()
	end
	if mouse and not showMouseIcon then
		preIcon = mouse.Icon
		mouse.Icon = "rbxassetid://2268193568"
	end
	local preShowDevGui
	if not showGui then
		preShowDevGui = game:GetService("StarterGui").ShowDevelopmentGui
		game:GetService("StarterGui").ShowDevelopmentGui = false
	end
	local function cleanup()
		if mouse and not showMouseIcon then
			mouse.Icon = preIcon
		end
		if not showGui then
			game:GetService("StarterGui").ShowDevelopmentGui = preShowDevGui
		end
	end
	if mask then
		local bg = makeBackground()
		if args.distance or typeof(mask) == "number" then
			bg:SetDistance(args.distance or mask)
		end

		bg:SetColor(Color3.new(0, 0, 0))
		bg:Show()
		waitForGuiUpdate()
		local result = makeApiRequest(self.url, "/screenshot", "POST", {
			destination = destination,
			mask = 1, -- 1: save to mask cache
			crop = cropValue,
		}, self.autoRetry)
		if not result.success then
			bg:Hide()
			cleanup()
			return result
		end

		bg:SetColor(Color3.new(1, 1, 1))
		waitForGuiUpdate()
		result = makeApiRequest(self.url, "/screenshot", "POST", {
			destination = destination,
			mask = 2, -- 2: mask with 1 then save to folders
			crop = cropValue,
			preview = preview,
		}, self.autoRetry)
		bg:Hide()
		cleanup()
		return result
	else
		waitForGuiUpdate()
		local result = makeApiRequest(self.url, "/screenshot", "POST", {
			destination = destination,
			crop = cropValue,
			preview = preview,
		}, self.autoRetry)
		cleanup()
		return result
	end
end

function object:SaveCameraState(args)
	args = args or {}
	limitArgs("SaveCameraState", args, {1, "camera"})
	typeCheck("parameter 1", {"Camera", "nil"}, 1, args[1])
	typeCheck("camera", {"Camera", "nil"}, 1, args.camera)
	local camera = args[1] or args.camera or workspace.CurrentCamera
	self.cameraState = {
		camera = camera,
		cameraType = camera.CameraType,
		cframe = camera.CFrame,
		focus = camera.Focus,
		fov = camera.FieldOfView,
	}
end

function object:LoadCameraState()
	if not self.cameraState then
		return
	end
	local cameraState = self.cameraState
	local camera = cameraState.camera
	camera.CameraType = cameraState.cameraType
	camera.CFrame = cameraState.cframe
	camera.Focus = cameraState.focus
	camera.FieldOfView = cameraState.fov
end

local function debugPoint(name, point, color)
	local p = Instance.new("Part")
	p.TopSurface, p.BottomSurface = "Smooth", "Smooth"
	p.Anchored, p.CanCollide = true, false
	p.Shape, p.Size = "Ball", Vector3.new(1, 1, 1)
	p.Material, p.Transparency, p.Color = "Neon", 0.2, color
	p.CFrame = CFrame.new(point)
	p.Name = "DbgPoint "..name
	p.Parent = workspace
end

local function debugVector(name, point, vector, color)
	local p = Instance.new("Part")
	p.TopSurface, p.BottomSurface = "Smooth", "Smooth"
	p.Anchored, p.CanCollide = true, false
	p.Shape, p.Size = "Block", Vector3.new(0.1, 0.1, vector.Magnitude)
	p.Material, p.Transparency, p.Color = "Neon", 0.2, color
	p.CFrame = CFrame.new(point + vector/2, point + vector)
	p.Name = "DbgVector "..name
	p.Parent = workspace
end

-- get yPercent from two FoVs: math.tan(math.rad(goal/2))/math.tan(math.rad(actual/2))
-- get goal   from yPercent: math.deg(math.atan( yPercent * math.tan(math.rad(actual/2)) )*2)
-- get actual from yPercent: math.deg(math.atan( (1/yPercent) * math.tan(math.rad(goal/2)) )*2)

local function getNumeratorFov(ratio, denominator)
	local mid = ratio*math.tan(math.rad(denominator/2))
	return math.deg(math.atan(mid)*2)
end

local function getDenominatorFov(ratio, numerator)
	local mid = (1/ratio)*math.tan(math.rad(numerator/2))
	return math.deg(math.atan(mid)*2)
end

local function rotateVectorTowards(vector1, vector2, angle)
	local vector2_t = vector1:Cross(vector2):Cross(vector1).Unit
	return math.cos(angle)*vector1 + math.sin(angle)*vector2_t
end

function object:GetCameraFovForSize(args)
	args = args or {}
	limitArgs("GetCameraParams", args, {1, "size", "fov"})
	typeCheck("size", {"Vector2"}, 1, args.size)
	typeCheck("fov", {"number"}, 1, args.fov)
	local size = args.size
	local fov = args.fov

	local camera = workspace.CurrentCamera
	local screenSize = camera.ViewportSize
	if size.x > screenSize.x or size.y > screenSize.y then
		return asResult{success = false, errorCode = 801, error = "size is bigger than screenSize: "..tostring(size).." > "..tostring(screenSize)}
	end

	if fov > 120 or fov < 1 then
		return asResult{success = false, errorCode = 802, error = "fov is bigger than max (120) or smaller than min (1)"}
	end

	local actualFov = getDenominatorFov(size.y/screenSize.y, fov)

	if actualFov > 120 or actualFov < 1 then
		return asResult{success = false, errorCode = 803, fov = actualFov, error = "Needed fov is bigger than max (120) or smaller than min (1). Make your screen size closer to size. Needed fov: "..tostring(actualFov)}
	end

	return asResult{success = true, fov = actualFov}
end

local defaultUpVector1 = Vector3.new(0, 1, 0)
local defaultUpVector2 = Vector3.new(1, 0, 0)
function object:GetCameraParams(args)
	args = args or {}
	limitArgs("GetCameraParams", args, {1, "camera", "size", "fov", "vector", "upVector", "radiusCenter", "radius", "points", "parts", "cframe"})
	typeCheck("parameter 1", {"Camera", "nil"}, 1, args[1])
	typeCheck("camera", {"Camera", "nil"}, 1, args.camera)
	typeCheck("size", {"Vector2", "nil"}, 1, args.size)
	typeCheck("fov", {"number"}, 1, args.fov)
	typeCheck("vector", {"Vector3", args.cframe and "nil"}, 1, args.vector)
	typeCheck("upVector", {"Vector3", "nil"}, 1, args.upVector)
	typeCheck("radiusCenter", {"Vector3", "nil"}, 1, args.radiusCenter)
	typeCheck("radius", {"number", "nil"}, 1, args.radius)
	typeCheck("points", {"table", "nil"}, 1, args.points)
	typeCheck("parts", {"table", "Instance", "nil"}, 1, args.parts)
	typeCheck("cframe", {"CFrame", "nil"}, 1, args.cframe)
	if not (args.radiusCenter and args.radius) and not args.points and not args.parts and not args.cframe then
		error("One of (radiusCenter and radius) or points or parts or cframe arguments requires")
	end
	local size = args.size
	local fov = args.fov

	local vector, upVector, rightVector
	if args.vector then
		vector = args.vector.Unit
		upVector = args.upVector
		if not upVector then
			local defaultUpVector = defaultUpVector1
			if math.abs(defaultUpVector:Dot(vector)) == 1 then
				defaultUpVector = defaultUpVector2
			end
			local tmpRightVector = defaultUpVector:Cross(vector)
			upVector = vector:Cross(tmpRightVector).Unit
		end
		upVector = upVector.Unit
		rightVector = -upVector:Cross(vector).Unit
	end

	local radiusCenter = args.radiusCenter
	local radius = args.radius

	local points = args.points

	local parts = args.parts

	local setCameraCFrame = args.cframe

	local camera = workspace.CurrentCamera
	local screenSize = camera.ViewportSize
	if not size then
		size = screenSize
	end
	if size.x > screenSize.x or size.y > screenSize.y then
		return asResult{success = false, errorCode = 801, error = "size is bigger than screenSize: "..tostring(size).." > "..tostring(screenSize)}
	end

	if fov > 120 or fov < 1 then
		return asResult{success = false, errorCode = 802, error = "fov is bigger than max (120) or smaller than min (1)"}
	end

	local actualFov = getDenominatorFov(size.y/screenSize.y, fov)

	if actualFov > 120 or actualFov < 1 then
		return asResult{success = false, errorCode = 803, fov = actualFov, error = "Needed fov is bigger than max (120) or smaller than min (1). Make your screen size closer to size. Needed fov: "..tostring(actualFov)}
	end

	if setCameraCFrame then
		return asResult{success = true, position = setCameraCFrame.p, cframe = setCameraCFrame, focus = setCameraCFrame*CFrame.new(0, 0, 1), fov = actualFov}
	end

	-- sorry for the case switch (camelCase to snake_case) in the following sections, snake_case is easier to comprehend for math stuff
	local final_position

	if radiusCenter and radius then
		local minSize = math.min(size.x, size.y)
		local squareFov = getNumeratorFov(minSize/size.y, fov)

		local angle = math.rad(squareFov/2)
		local add_depth = math.sin(angle)*radius
		local width = math.cos(angle)*radius
		local base_depth = width/math.tan(angle)
		local full_depth = base_depth + add_depth
		final_position = radiusCenter - vector*full_depth
	end

	if parts then
		if typeof(parts) == "Instance" then
			parts = {parts}
		end
		points = points or {}
		for _, ancestor in next, parts do
			if typeof(ancestor) ~= "Instance" then
				error("Bad type provided inside parts table: got "..typeof(ancestor)..", expected Instance.")
			end
			local descendants = ancestor:GetDescendants()
			descendants[#descendants + 1] = ancestor
			for _, part in next, descendants do
				if part:IsA("BasePart") then
					local cframe, sz = part.CFrame, part.Size/2
					if part:IsA("WedgePart") then
						points[#points + 1], points[#points + 2], points[#points + 3], points[#points + 4],
						points[#points + 5], points[#points + 6] =
							cframe*Vector3.new( sz.x, -sz.y,  sz.z), cframe*Vector3.new(-sz.x, -sz.y,  sz.z),
							cframe*Vector3.new( sz.x, -sz.y, -sz.z), cframe*Vector3.new(-sz.x, -sz.y, -sz.z),
							cframe*Vector3.new( sz.x,  sz.y,  sz.z), cframe*Vector3.new(-sz.x,  sz.y,  sz.z)
					elseif part:IsA("CornerWedgePart") then
						points[#points + 1], points[#points + 2], points[#points + 3], points[#points + 4],
						points[#points + 5] =
							cframe*Vector3.new( sz.x, -sz.y,  sz.z), cframe*Vector3.new(-sz.x, -sz.y,  sz.z),
							cframe*Vector3.new( sz.x, -sz.y, -sz.z), cframe*Vector3.new(-sz.x, -sz.y, -sz.z),
							cframe*Vector3.new( sz.x,  sz.y, -sz.z)
					else
						points[#points + 1], points[#points + 2], points[#points + 3], points[#points + 4],
						points[#points + 5], points[#points + 6], points[#points + 7], points[#points + 8] =
							cframe*Vector3.new( sz.x, -sz.y,  sz.z), cframe*Vector3.new(-sz.x, -sz.y,  sz.z),
							cframe*Vector3.new( sz.x, -sz.y, -sz.z), cframe*Vector3.new(-sz.x, -sz.y, -sz.z),
							cframe*Vector3.new( sz.x,  sz.y, -sz.z), cframe*Vector3.new(-sz.x,  sz.y, -sz.z),
							cframe*Vector3.new( sz.x,  sz.y,  sz.z), cframe*Vector3.new(-sz.x,  sz.y,  sz.z)
					end
				end
			end
		end
	end

	if points and #points > 1 then

		local yFov = fov
		local xFov = getNumeratorFov(size.x/size.y, fov)

		local upPlane    = rotateVectorTowards(vector, upVector,    math.rad( yFov/2 + 90))
		local downPlane  = rotateVectorTowards(vector, upVector,    math.rad(-yFov/2 - 90))
		local rightPlane = rotateVectorTowards(vector, rightVector, math.rad( xFov/2 + 90))
		local leftPlane  = rotateVectorTowards(vector, rightVector, math.rad(-xFov/2 - 90))

		local upPoint, downPoint, rightPoint, leftPoint = points[1], points[1], points[1], points[1]

		for _, point in next, points do
			if typeof(point) ~= "Vector3" then
				error("Bad type provided inside parts table: got "..typeof(point)..", expected Vector3.")
			end
			if (point - upPoint):Dot(upPlane) >= 0 then
				upPoint = point
			end
			if (point - downPoint):Dot(downPlane) >= 0 then
				downPoint = point
			end
			if (point - rightPoint):Dot(rightPlane) >= 0 then
				rightPoint = point
			end
			if (point - leftPoint):Dot(leftPlane) >= 0 then
				leftPoint = point
			end
		end

		if DEBUG_MODE_3D then
			debugPoint("up",    upPoint,    Color3.new(0, 1, 1))
			debugPoint("down",  downPoint,  Color3.new(1, 1, 0))
			debugPoint("right", rightPoint, Color3.new(1, 0, 1))
			debugPoint("left",  leftPoint,  Color3.new(1, 1, 1))
		end

		local y_midpoint, y_camera_point
		local x_midpoint, x_camera_point
		local dbg_y_depth, dbg_x_depth
		local dbg_y_mid_dist, dbg_x_mid_dist

		do
			local diff = (upPoint - downPoint)
			local x_diff_base = diff:Dot(upVector)
			local y_diff_base = diff:Dot(vector)
			local x_diff, y_diff = math.abs(x_diff_base), math.abs(y_diff_base)
			local slope = 1/math.tan(math.rad(yFov)/2)
			local depth_dist = (x_diff*slope - y_diff)/2
			local midpoint_dist = x_diff*(depth_dist/(x_diff*slope))

			local midpoint
			local camera_point
			if y_diff_base >= 0 then
				midpoint = downPoint:Dot(upVector) + midpoint_dist
				camera_point = downPoint:Dot(vector) - depth_dist
			else
				midpoint = upPoint:Dot(upVector) - midpoint_dist
				camera_point = upPoint:Dot(vector) - depth_dist
			end

			dbg_y_mid_dist = midpoint_dist
			dbg_y_depth = depth_dist

			y_camera_point, y_midpoint = camera_point, midpoint
		end

		do
			local diff = (rightPoint - leftPoint)
			local x_diff_base = diff:Dot(rightVector)
			local y_diff_base = diff:Dot(vector)
			local x_diff, y_diff = math.abs(x_diff_base), math.abs(y_diff_base)
			local slope = 1/math.tan(math.rad(xFov)/2)
			local depth_dist = (x_diff*slope - y_diff)/2
			local midpoint_dist = x_diff*(depth_dist/(x_diff*slope))

			local midpoint
			local camera_point
			if y_diff_base >= 0 then
				midpoint = leftPoint:Dot(rightVector) + midpoint_dist
				camera_point = leftPoint:Dot(vector) - depth_dist
			else
				midpoint = rightPoint:Dot(rightVector) - midpoint_dist
				camera_point = rightPoint:Dot(vector) - depth_dist
			end

			dbg_x_mid_dist = midpoint_dist
			dbg_x_depth = depth_dist

			x_camera_point, x_midpoint = camera_point, midpoint
		end

		if y_camera_point < x_camera_point then
			final_position = y_camera_point
		else
			final_position = x_camera_point
		end

		final_position = final_position*vector + y_midpoint*upVector + x_midpoint*rightVector

		if DEBUG_MODE_3D then
			debugVector("depth_dist", final_position, (y_camera_point < x_camera_point and dbg_y_depth or dbg_x_depth)*vector, Color3.new(0, 0, 0))

			debugVector("y_mid", final_position + dbg_y_depth*vector, dbg_y_mid_dist*upVector, Color3.new(1, 0, 0))
			debugVector("x_mid", final_position + dbg_x_depth*vector, dbg_x_mid_dist*rightVector, Color3.new(0, 1, 0))

			debugVector("vector",      final_position,      vector, Color3.new(0, 0, 1))
			debugVector("upVector",    final_position,    upVector, Color3.new(0, 1, 0))
			debugVector("rightVector", final_position, rightVector, Color3.new(1, 0, 0))

			debugVector("plane_up",    final_position,    upPlane, Color3.new(0, 1, 1))
			debugVector("plane_down",  final_position,  downPlane, Color3.new(1, 1, 0))
			debugVector("plane_right", final_position, rightPlane, Color3.new(1, 0, 1))
			debugVector("plane_left",  final_position,  leftPlane, Color3.new(1, 1, 1))

			debugVector("fov_up",    final_position, rotateVectorTowards(vector,    upVector, math.rad( yFov/2))*100, Color3.new(0, 1, 1))
			debugVector("fov_down",  final_position, rotateVectorTowards(vector,    upVector, math.rad(-yFov/2))*100, Color3.new(1, 1, 0))
			debugVector("fov_right", final_position, rotateVectorTowards(vector, rightVector, math.rad( xFov/2))*100, Color3.new(1, 0, 1))
			debugVector("fov_left",  final_position, rotateVectorTowards(vector, rightVector, math.rad(-xFov/2))*100, Color3.new(1, 1, 1))
		end
	end

	if not final_position then
		return asResult{success = false, errorCode = 804, error = "No provided centering methods or your points array had no points or your part ancestors array had no parts"}
	end

	local cameraCFrame = CFrame.new(
		final_position.x, final_position.y, final_position.z,
		rightVector.x, upVector.x, vector.x,
		rightVector.y, upVector.y, vector.y,
		rightVector.z, upVector.z, vector.z
	)
	local focusCFrame = cameraCFrame*CFrame.new(0, 0, 1)

	return asResult{success = true, position = final_position, cframe = cameraCFrame, focus = focusCFrame, fov = actualFov}
end

function object:CenterCamera(args)
	local params = self:GetCameraParams(args)
	if not params.success then
		return params
	end
	local camera = args[1] or args.camera or workspace.CurrentCamera
	camera.CFrame, camera.Focus, camera.FieldOfView = params.cframe, params.focus, params.fov
	return params
end

return {
	new = makeObject
}

--[[
MIT License

Copyright (c) 2018 Corecii Cyr

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]