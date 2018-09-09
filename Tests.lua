local RUN_TESTS_LOGIN = true
local RUN_TESTS_REQUEST_LIMIT = true
local RUN_TESTS_SPRITES = true

local LOGIN_USERNAME = ""
local LOGIN_PASSWORD = "" -- DO NOT USE YOUR MAIN ACCOUNT. DO NOT SAVE TO FILE OR UPLOAD.

local Screenshotter = require(script.MainModule:Clone())
-- Screenshotter:Set3dDebugMode(true)

local scr = Screenshotter.new()

-- Test various forms of Calibrate:

scr:Calibrate{
	color = Color3.fromRGB(254, 47, 29),
}:Print("Calibrate "):Assert()

scr:Calibrate{
	color = Color3.fromRGB(254, 47, 29),
	tolerance = 2
}:Print("Calibrate "):Assert()

scr:Calibrate{}:Print("Calibrate "):Assert()

-- Test Spritesheets:

if RUN_TESTS_SPRITES then
	local base = workspace.SpriteBase
	scr:CenterCamera{
		size = Vector2.new(90, 90),
		fov = 20,
		vector = Vector3.new(0, -1, 1),

		parts = base,
	}:Assert()
	for i = 1, 10 do
		base.Color = Color3.new(math.random(), math.random(), math.random())
		scr:Screenshot{
			destination = "spritetest/folder/sprite-"..tostring(i),
			crop = Vector2.new(100, 100),
			mask = true,
		}:Assert()
	end
	for i = 1, 4 do
		base.Color = Color3.new(math.random(), math.random(), math.random())
		scr:Screenshot{
			destination = "spritetest/sprite-"..tostring(i),
			crop = Vector2.new(100, 100),
			mask = true,
		}:Assert()
	end

	scr:Spritesheet{
		destination = "spritetest/result-manual",
		images = {
			{"spritetest/sprite-1", Vector2.new(0, 0)},
			{"spritetest/sprite-2", Vector2.new(1024 - 50, 0), resize = Vector2.new(50, 100), resizeMode = "bicubic"},
			{"spritetest/sprite-3", Vector2.new(0, 1024 - 50), resize = Vector2.new(100, 50)},
			{"spritetest/sprite-4", Vector2.new(1024 - 50, 1024 - 50)},
		},
		preview = true,
	}:Print("Manual Sprites "):Assert()

	scr:AutoSpritesheet{
		destination = "spritetest/result-auto",
		images = {
			{destination = "spritetest/sprite-1"},
			{destination = "spritetest/sprite-2", resize = Vector2.new(50, 100), resizeMode = "bicubic"},
			{destination = "spritetest/sprite-3", resize = Vector2.new(100, 50)},
			{destination = "spritetest/sprite-4"},
			{directory = "spritetest/folder", recursive = true},
			{directory = "spritetest/folder", resize = Vector2.new(10, 10)},
		},
		preview = true,
	}:Print("Auto Sprites "):Assert()

	scr:AutoSpritesheet{
		destination = "spritetest/result-auto-small",
		size = Vector2.new(160, 100),
		images = {
			{destination = "spritetest/sprite-1"},
			{destination = "spritetest/sprite-2", resize = Vector2.new(50, 100), resizeMode = "bicubic"},
			{destination = "spritetest/sprite-3", resize = Vector2.new(100, 50)},
			{destination = "spritetest/sprite-4"},
			{directory = "spritetest/folder", recursive = true},
			{directory = "spritetest/folder", resize = 0.1, format = "NAME-small"},
			{directory = "spritetest/folder", resize = 0.5, format = "NAME-medium"},
		},
		preview = true,
	}:Print("Auto Sprites Small"):Assert()
end

-- Test SaveCameraState:

scr:SaveCameraState{}

-- Test CenterCamera:

scr:CenterCamera{
	size = Vector2.new(300, 500),
	fov = 90,
	cframe = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1)),
}:Print("CenterCamera 1"):Assert()

wait(1)

scr:CenterCamera{
	size = Vector2.new(300, 500),
	fov = 90,
	vector = Vector3.new(0, -1, 1),

	radiusCenter = workspace.RadiusTestPart.Position,
	radius = workspace.RadiusTestPart.Size.x/2,
}:Print("CenterCamera 2"):Assert()
wait(1)

-- used to test and fix issues the minor_axis centering
result = scr:CenterCamera{
	size = Vector2.new(600, 300),
	fov = 50,
	vector = Vector3.new(1, 0, 1),
	force_x = true,

	parts = workspace.SizeTestPart,
}:Print("CenterCamera 4"):Assert()
game.StarterGui.ScreenGui.Frame.Size = UDim2.new(0, result.size.x, 0, result.size.y)

wait(1)

result = scr:CenterCamera{
	size = Vector2.new(600, 300),
	fov = 50,
	vector = Vector3.new(1, 0, 1),
	force_y = true,

	parts = workspace.SizeTestPart,
}:Print("CenterCamera 5"):Assert()
game.StarterGui.ScreenGui.Frame.Size = UDim2.new(0, result.size.x, 0, result.size.y)

wait(1)

local result = scr:CenterCamera{
	size = Vector2.new(300, 500),
	fov = 90,
	vector = Vector3.new(0, -1, 1),

	parts = workspace["Observation Tower"],
}:Print("CenterCamera 3"):Assert()
game.StarterGui.ScreenGui.Frame.Size = UDim2.new(0, result.size.x, 0, result.size.y)


wait(1)

-- Test various forms of Screenshot:

scr:Screenshot{
	destination = "test-01",
	--crop = Vector2.new(300, 500),
	--mask = true,
}:Print("Screenshot test-01 "):Assert()

scr:Screenshot{
	destination = "test-02",
	crop = Vector2.new(300, 500),
	--mask = true,
}:Print("Screenshot test-02 "):Assert()

scr:Screenshot{
	destination = "test-03",
	crop = Vector2.new(300, 500),
	mask = true,
}:Print("Screenshot test-03 "):Assert()

scr:Screenshot{
	destination = "test-04",
	crop = Rect.new(50, 20, 200, 500),
	mask = true,
}:Print("Screenshot test-04 "):Assert()

scr:Screenshot{
	"test-05",
	Vector2.new(300, 500),
	true,
}:Print("Screenshot test-05 "):Assert()

-- Test bad file names:

scr:Screenshot{
	"..\\test-06.png.\\..!@#$%^&*()[]{}-=|:;<>,.?|~_+`\"'\0aaaa",
}:Print("Screenshot test-06 "):Assert()

scr:Screenshot{
	"..",
}:Print("Screenshot test-07 "):Assert()

scr:Screenshot{
	"C:\\\\test",
}:Print("Screenshot test-08 "):Assert()

-- Test directory support:

scr:Screenshot{
	destination = "dir/test-01",
}:Print("Screenshot dir-test-01 "):Assert()

scr:Screenshot{
	destination = "dir/test-02",
}:Print("Screenshot dir-test-02 "):Assert()

scr:Screenshot{
	destination = "dir/dir2/dir3/test-03",
}:Print("Screenshot dir-test-03 "):Assert()

-- Test previews:

scr:Screenshot{
	"test-09",
	preview = true,
}:Print("Screenshot test-09 "):Assert()

scr:Screenshot{
	"test-11",
}:Print("Screenshot test-11 "):Assert()

scr:Preview{
	"test-11"
}:Print("Preview test-11 "):Assert()

-- Test unpreviews and deletes:

scr:Screenshot{
	"test-12",
	preview = true,
}:Print("Screenshot test-12 "):Assert()

wait(1)

scr:Unpreview{
	"test-12"
}:Print("Unpreview test-12 "):Assert()

wait(1)

scr:Preview{
	"test-12"
}:Print("Preview test-12 "):Assert()

wait(1)

scr:Delete{
	"test-12"
}:Print("Delete test-12 "):Assert()

wait(1)

scr:Delete{
	directory = "dir"
}:Print("Delete dir "):Assert()

if RUN_TESTS_LOGIN then
	-- Test login:

	scr:Login{
		LOGIN_USERNAME,
		LOGIN_PASSWORD,
	}:Assert()
	-- Print left off to avoid leaking cookie

	-- Test uploads:

	scr:Upload{
		"test-11",
		deletePreview = true,
	}:Print("Upload test-11 "):Assert()

	scr:Upload{
		"test-11",
		"non-default name",
	}:Print("Upload test-11 non-default name "):Assert()

	-- Test logout:

	scr:Logout{}:Print("Logout "):Assert()

	scr:Upload{
		"test-11"
	}:Print("Upload test-11 logged out")
	-- Assert left out because this should error

	-- Test login registry:

	scr:Login{
		registry = true,
	}:Print("Login registry "):Assert()

	scr:Upload{
		"test-11",
		"test upload",
		delete = true,
	}:Print("Upload test-11 registry "):Assert()
end

if RUN_TESTS_REQUEST_LIMIT then
	-- http request limit tests
	print("Beginning request limit tests...")
	for i = 1, 500 do
		scr:Preview{"test-11"}:Assert()
		if i%10 == 0 then
			print("  On request",i)
		end
	end
	print("Request limit tests done")
end

print("Tests done")