-- Run with Lua 5.1 from the repository root. Never stops real services.
local root = arg[1] or "."
local file = assert(io.open(root .. "/luci-app-passwall2/luasrc/passwall2/api.lua"))
local source = file:read("*a"); file:close()
local body = assert(source:match("function to_move%([^\n]*.-\nend"))
local scenarios = {
	{ name = "space failure", free = 10, new_size = 100, expected = 1, stops = 0 },
	{ name = "invalid binary", invalid = true, expected = 1, stops = 0 },
	{ name = "invalid destination", bad_path = true, expected = 1, stops = 0 },
	{ name = "empty input", input = "", expected = 1, stops = 0 },
	{ name = "running success", expected = 0, stops = 1, moves = 1, restarts = 1 },
	{ name = "stopped success", stopped = true, expected = 0, stops = 0, moves = 1 },
	{ name = "move failure", move_error = true, expected = 1, stops = 1, moves = 1, restarts = 1 },
	{ name = "unknown free space", free = 0, expected = 0, stops = 1, moves = 1, restarts = 1 },
	{ name = "reclaim existing size", free = 95, new_size = 100, old_size = 10, expected = 0, stops = 1, moves = 1, restarts = 1 }
}
for _, scenario in ipairs(scenarios) do
	local calls = { stops = 0, moves = 0, restarts = 0 }
	local env = setmetatable({}, { __index = _G })
	env.check_path = function() return {code = scenario.bad_path and 1 or 0, app_path = "/test/xray"} end
	env.com = { xray = {name = "Xray"} }
	env.fs = { stat = function() return "reg" end, access = function() return true end }
	env.get_app_version = function() return scenario.invalid and "" or "26.10.21" end
	env.get_file_space = function(path)
		return path == "/test/xray" and (scenario.old_size or 1) or (scenario.new_size or 100)
	end
	env.get_final_dir = function() return "/test" end
	env.get_free_space = function() return scenario.free or 1000 end
	env.i18n = { translate = function(s) return s end, translatef = string.format }
	env.sys = {call = function(command)
		if command:find("pgrep", 1, true) then return scenario.stopped and 1 or 0 end
		if command == "/etc/init.d/passwall2 stop" then calls.stops = calls.stops + 1 end
		if command:find("/etc/init.d/passwall2 restart", 1, true) then calls.restarts = calls.restarts + 1 end
		return 0
	end}
	env.exec = function(command)
		assert(command == "/bin/mv", command)
		assert(calls.stops == (scenario.stops or 0), "move occurred before stop")
		calls.moves = calls.moves + 1
		return scenario.move_error and 1 or 0
	end
	local chunk = assert(loadstring(body)); setfenv(chunk, env); chunk()
	local result = env.to_move("xray", scenario.input or "/tmp/new-xray")
	assert(result.code == scenario.expected, scenario.name .. ": return code")
	for _, key in ipairs({"stops", "moves", "restarts"}) do
		assert(calls[key] == (scenario[key] or 0), scenario.name .. ": " .. key)
	end
	print("ok - " .. scenario.name)
end
