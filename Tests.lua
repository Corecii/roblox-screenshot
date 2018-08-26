local RUN_LOGIN_TESTS = true

local Screenshotter = require(2218503664)

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

-- Test SaveCameraState:

scr:SaveCameraState{}

-- Test CenterCamera:

scr:CenterCamera{
	size = Vector2.new(300, 500),
	fov = 90,
	vector = Vector3.new(0, -1, 1),

	radiusCenter = workspace.RadiusTestPart.Position,
	radius = workspace.RadiusTestPart.Size.x/2,
}:Print("CenterCamera "):Assert()

wait(1)

scr:CenterCamera{
	size = Vector2.new(300, 500),
	fov = 90,
	vector = Vector3.new(0, -1, 1),

	parts = workspace["Observation Tower"],
}:Print("CenterCamera "):Assert()

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

if RUN_LOGIN_TESTS then
	-- Test login:

	scr:Login{
		"", -- ENTER USERNAME HERE
		""  -- ENTER PASSWORD HERE. DO NOT USE YOUR MAIN ACCOUNT. DO NOT SAVE TO FILE OR UPLOAD.
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

-- http request limit tests
print("Beginning request limit tests...")
for i = 1, 500 do
	scr:Preview{"test-11"}:Assert()
	if i%10 == 0 then
		print("  On request",i)
	end
end
print("Request limit tests done")