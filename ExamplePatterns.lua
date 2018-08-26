
local Screenshotter = require(2218503664)

local scr = Screenshotter.new()

-- See `TestsAndExamples.lua` for parameter examples
-- This file will provide examples of programming patterns used when workign with Screenshotter

--- Error handling:


-- Ignore all errors:

scr:Calibrate{}


-- Error on all errors:

scr:Calibrate{}:Assert()


-- Handle specific errors, ignore all others

local result = scr:Upload{"example"}
if result:IsError("UploadFileDoesNotExist") then
	-- do something
elseif result:IsError("UploadNotLoggedIn") then
	-- do something else
end


-- Handle specific errors, error on unhandled errors

local result = scr:Upload{"example"}
if result:IsError("UploadFileDoesNotExist") then
	-- do something
elseif result:IsError("UploadNotLoggedIn") then
	-- do something else
else
	result:Assert()
end


-- Handle two errors at once

local result = scr:Upload{"example"}
if result:IsAnyError("UploadFileDoesNotExist", "UploadNotLoggedIn") then
	-- do something
else
	result:Assert()
end


-- Ignore specific errors and do something even if they happen. Error for every other error.

local result = scr:Upload{"example"}:AssertIgnore("UploadFileDoesNotExist", "UploadNotLoggedIn")


-- Ignore specific errors and do something only if they don't happen. Error for every other error.

local result = scr:Upload{"example"}:AssertIgnore("UploadFileDoesNotExist", "UploadNotLoggedIn")
if not result:IsError() then
	-- do something
end


-- Debug the result of an API call

scr:Upload{"example"}:Print()


-- Debug the result of an API call with a label

scr:Upload{"example"}:Print("label ")


--- Small example of taking screenshots of different models, previewing them, then uploading them

-- take screenshots and save their preview ids to test in-game

scr:Calibrate{}:Assert()

scr:SaveCameraState{}

for _, model in next, workspace.Models:GetChildren() do
	local result = scr:CenterCamera{
		parts = model,
		fov = 90,
		vector = Vector3.new(0, -1, 1).Unit,
		size = Vector2.new(200, 200),
	}:AssertIgnore("CameraNoCenteringMethods")
	if not result:IsError() then -- if this error happens, it just means the model was empty, so let's just not screenshot it
		wait(0.1) -- let the screen update, sometimes graphics can take a moment to update
		result = scr:Screenshot{
			destination = model.Name,
			preview = true,
		}:Assert()
		-- set or create the ImageContent value which will store the preview image or uploaded image
		local imageContentValue = model:FindFirstChild("ImageContent")
		if not imageContentValue then
			imageContentValue = Instance.new("StringValue")
			imageContentValue.Name = "ImageContent"
			imageContentValue.Parent = model
		end
		imageContentValue.Value = result.content
		-- imageContentValue.Value is now something like `rbxasset://previews/modelName.png`
	end
end

scr:LoadCameraState{}

-- after previewing in-game, upload the screenshots so that they can be used in a live game

scr:Login{
	registry = true
}:Assert()

for _, model in next, workspace.Models:GetChildren() do
	local result = scr:Upload{
		destination = model.Name,
		delete = true, -- delete when we're done with it, if the upload succeeds
	}:AssertIgnore("UploadFileDoesNotExist")

	if not result:IsError() then -- if this error happens, it just means that we never got a preview, probably because it was empty.
		model.ImageContent.Value = result.content
		-- ImageContent.Value is now something like `rbxassetid://1234567890`
	end
end

