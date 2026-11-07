local env = env
GLOBAL.setfenv(1, GLOBAL)

TALKINGFONT_SCAREDCROW = "scaredcrow"

env.AddSimPostInit(function()
	TheSim:UnloadFont(TALKINGFONT_SCAREDCROW)
	TheSim:UnloadPrefabs({"tot_fonts"})

	local font = resolvefilepath("fonts/talkingfont_scaredcrow.zip")
	local assets = {
		Asset("FONT", font),
	}

	local FontsPrefab = Prefab("tot_fonts", function() return CreateEntity() end, assets)
	RegisterPrefabs(FontsPrefab)
	TheSim:LoadPrefabs({"tot_fonts"})
	TheSim:LoadFont(font, TALKINGFONT_SCAREDCROW)
end)