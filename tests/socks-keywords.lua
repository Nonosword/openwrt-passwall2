-- Run from the repository root with Lua 5.1. No LuCI/UCI writes occur.
local root = arg[1] or "."
local file = assert(io.open(root .. "/luci-app-passwall2/luasrc/controller/passwall2.lua"))
local source = file:read("*a")
file:close()
for _, name in ipairs({"socks_autoswitch_add_node", "socks_autoswitch_remove_node"}) do
	local body = assert(source:match("function " .. name .. "%(%).-\nend"), name)
	assert(loadstring(body))()
end

local nodes, selected, keyword, saves
http = {
	formvalue = function(key) return key == "id" and "socks_test" or keyword end,
	redirect = function() end
}
api = { get_valid_nodes = function() return nodes end, url = function() return "/test" end }
function uci_get(id, option)
	if option == "remarks" then
		for _, node in ipairs(nodes) do if node.id == id then return node.remark end end
	end
	if option == "autoswitch_backup_node" then
		local copy = {}; for i, id in ipairs(selected) do copy[i] = id end; return copy
	end
end
function uci_set(_, option, value)
	if option == "autoswitch_backup_node" then selected = value end
end
function uci_save() saves = saves + 1 end

for _, key in ipairs({"HK&IEPL", "US+VIP", "JP#01", "[", ".", "%", "a*b", "a-b", "节点", "Case", "a b"}) do
	keyword, saves = key, 0
	nodes = {
		{id = "keep", node_type = "normal", remark = "unrelated"},
		{id = "match", node_type = "normal", remark = "prefix " .. key .. " suffix"},
		{id = "special", node_type = "balancing", remark = key}
	}
	selected = {"keep", "match"}
	socks_autoswitch_add_node()
	assert(table.concat(selected, ",") == "keep,match", "add: " .. key)
	socks_autoswitch_remove_node()
	assert(table.concat(selected, ",") == "keep", "remove: " .. key)
	assert(saves == 2)
end
keyword, saves, selected = "case", 0, {"keep"}
nodes = {{id = "different_case", node_type = "normal", remark = "Case"}}
socks_autoswitch_add_node()
assert(table.concat(selected, ",") == "keep", "case-sensitive matching")
keyword, saves = "", 0
socks_autoswitch_remove_node()
assert(saves == 0, "empty keywords must not change configuration")
print("SOCKS controller keyword regressions passed")
