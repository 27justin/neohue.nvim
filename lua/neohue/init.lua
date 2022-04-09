local uv = require "luv"
local curl = require "plenary.curl"
local json = require "cjson"
local a = require"plenary.async"
local group_mt = require"neohue.group"
local light_mt = require"neohue.light"

local M = {}

local settings = {
	bridge_ip = nil,
	auto_discover = true,
	cache_bridge_ip = true,
	silent = false,
	username = nil
}


local function get_username()
	-- Get user secret from datadir at `datadir`/neohue.secret and return it
	local datadir = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
	local secret_file = datadir .. "/neohue-username.txt"
	local f = io.open(secret_file, "r")
	if f then
		local secret = f:read("*a")
		f:close()
		-- Return the trimmed secret
		return secret:match("^%s*(.-)%s*$")
	end
end
local function set_username(secret)
	-- Set user secret in datadir at `datadir`/neohue.secret
	local datadir = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
	local secret_file = datadir .. "/neohue-username.txt"
	local f = io.open(secret_file, "w")
	if f then
		f:write(secret)
		f:close()
	end
end
local function get_cached_ip() 
	-- Get cached bridge ip from datadir at `datadir`/neohue.ip and return it
	local datadir = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
	local ip_file = datadir .. "/neohue-ip.txt"
	local f = io.open(ip_file, "r")
	if f then
		local ip = f:read("*a")
		f:close()
		return ip:match("^%s*(.-)%s*$")
	end
end
local function set_cached_ip(ip)
	-- Set cached bridge ip in datadir at `datadir`/neohue.ip
	local datadir = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
	local ip_file = datadir .. "/neohue-ip.txt"
	local f = io.open(ip_file, "w")
	if f then
		f:write(ip)
		f:close()
	end
end


function M.get_bridge_ip()
	return settings.bridge_ip
end

function M.discover()
	-- TODO: stop sockets if no response after ~10secs
	local server = uv.new_udp()
	server:bind('0.0.0.0', 2222);

	server:recv_start(function(err, data, addr, flags)
		if addr then
			if data:find("hue-bridgeid", 1, true) then
				if not settings.silent then
					vim.notify("Discovered HUE Bridge on " .. addr['ip'] .. ":" .. addr['port'], vim.log.levels.INFO)
				end
				settings.bridge_ip = addr['ip']

				if settings.cache_bridge_ip then
					set_cached_ip(addr['ip'])
				end

				server:close()
				return
			end
		end
	end)
	server:send("M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: urn:dial-multiscreen-org:service:dial:1\r\n\r\n", "239.255.255.250", 1900, function(err, n)
	end)
end

function M.reset()
	-- Clear secret file at `datadir`/neohue-username.txt
	local datadir = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
	local secret_file = datadir .. "/neohue-username.txt"
	local f = io.open(secret_file, "w")
	if f then
		f:close()
	end
	if settings.cache_bridge_ip then
		settings.bridge_ip = nil
		local ip_file = datadir .. "/neohue-ip.txt"
		local f = io.open(ip_file, "w")
		if f then
			f:close()
		end
	end
end

function M.connect()
	local username = get_username()
	-- Check if neohue is already connected
	if username and #username > 0 then
		return true
	end

	if not settings.bridge_ip then
		vim.notify("No HUE Bridge discovered yet, start discovering with :HueDiscover", vim.log.levels.ERROR)
		return
	end

	local result = curl.post("http://" .. settings.bridge_ip .. "/api", {
		body = '{"devicetype": "nvim/neohue"}',
		headers = {
			["Content-Type"] = "application/json"
		}
	})
	if result.status == 200 then
		local body = result.body
		local json_body = json.decode(body)
		-- Check if the response from the HUE bridge is an error of error.type: 101, if it is prompt the user to press the link button
		if json_body[1].error ~= nil and json_body[1].error.type == 101 then
			vim.notify("Please press the link button on your HUE Bridge", vim.log.levels.ERROR)
			return
		else
			-- Get the username from the response and save it in the datadir
			local username = json_body[1].success.username
			if #username > 0 then
				if not settings.silent then
					vim.notify("Successfully connected to HUE Bridge", vim.log.levels.INFO)
				end
				settings.username = username
				set_username(username)
				return true
			else
				vim.notify("Could not retrieve username from HUE Bridge, this may be due to API incompabilities.", vim.log.levels.ERROR)
			end
		end
	end
end

function M.lights()
	local username = get_username()
	if #username == 0 then
		vim.notify("You are not connected with the HUE Bridge, please connect using :HueConnect", vim.log.levels.ERROR)
		return
	end
	if not settings.bridge_ip then
		vim.notify("No HUE Bridge discovered yet, start discovering with :HueDiscover", vim.log.levels.ERROR)
		return
	end

	local result = curl.get("http://" .. settings.bridge_ip .. "/api/" .. username .. "/lights")
	if result.status == 200 then
		local body = result.body
		local json_body = json.decode(body)
		for k, v in pairs(json_body) do
			v = light_mt:new(v)
			v:set_settings(settings)
			v:set_idx(k)
		end
		return json_body
	end
end

function M.groups()
	local username = get_username()
	if #username == 0 then
		vim.notify("You are not connected with the HUE Bridge, please connect using :HueConnect", vim.log.levels.ERROR)
		return
	end
	if not settings.bridge_ip then
		vim.notify("No HUE Bridge discovered yet, start discovering with :HueDiscover", vim.log.levels.ERROR)
		return
	end

	local result = curl.get("http://" .. settings.bridge_ip .. "/api/" .. username .. "/groups")
	if result.status == 200 then
		local body = result.body
		local json_body = json.decode(body)
		for k, v in pairs(json_body) do
			v = group_mt:new(v)
			v:set_settings(settings)
			v:set_idx(k)
		end
		return json_body
	end
end


function M.group(value)
	local groups = M.groups()
	if type(value) == "string" then
		-- Check if string is fully numeric, if it is return groups[string]
		if tonumber(value) ~= nil then
			return groups[value]
		else
			for k, v in pairs(groups) do
				-- Check if the group name matches the string (case insensitive)
				if v.name:lower() == value:lower() then
					return v
				end
			end
		end
	elseif type(value) == "number" then
		-- M.groups() always returns a table with string indices, therefore convert value to string before indexing
		return groups[tostring(value)]
	end
end

function M.light(index)
	local username = get_username()
	if #username == 0 then
		vim.notify("You are not connected with the HUE Bridge, please connect using :HueConnect", vim.log.levels.ERROR)
		return
	end
	if not settings.bridge_ip then
		vim.notify("No HUE Bridge discovered yet, start discovering with :HueDiscover", vim.log.levels.ERROR)
		return
	end

	local result = curl.get("http://" .. settings.bridge_ip .. "/api/" .. username .. "/lights/" .. index)
	if result.status == 200 then
		local body = result.body
		local json_body = json.decode(body)
		local light = light_mt:new(json_body)
		light:set_settings(settings)
		light:set_idx(index)
		return light
	end
end

function M.setup(config)
	if config ~= nil and type(config) == "table" then
		-- Merge the config with the default settings
		for k, v in pairs(config) do
			settings[k] = v
		end
	end

	-- Check if telescope.nvim is installed, if it is load the extension
	local success, _ = pcall(require, "telescope")
	if success then
		require"telescope".load_extension"neohue"
	end

	vim.cmd[[
		command! HueDiscover lua require'neohue'.discover()
		command! HueConnect lua require'neohue'.connect()

		command! -nargs=+ HueLight lua function __(i,s) local l = require'neohue'.light(i); if s == "on" or s == true then l:on(); else l:off(); end end;__(<f-args>)
		command! -nargs=1 HueLightToggle lua require'neohue'.light(<q-args>):toggle()
		command! -nargs=+ HueLightBrightness lua function __(i,s) local l = require'neohue'.light(i); l:set_brightness(s); end;__(<f-args>)

		command! -nargs=+ HueGroup lua function __(i,s) local l = require'neohue'.group(i); if s == "on" or s == true then l:on(); else l:off(); end end;__(<f-args>)
		command! -nargs=1 HueGroupToggle lua require'neohue'.group(<q-args>):toggle()
		command! -nargs=+ HueGroupBrightness lua function __(i,s) local l = require'neohue'.group(i); l:set_brightness(s); end;__(<f-args>)
	]]
	-- Check if get_username return a non nil value, if it does set that value into settings.username
	local username = get_username()
	if username and #username > 0 then
		settings.username = username
	end

	-- Check if settings.bridge_ip is set.
	-- If it is, do nothing.
	-- If it isn't and settings.cache_bridge_ip is true, then read the cache file and set the bridge_ip, if the content is empty, check whether settings.auto_discover is enabled, if it is call M:discover
	-- If it isn't and settings.cache_bridge_ip is false, AND settings.auto_discover is enabled, call M:discover
	if not settings.bridge_ip then
		if settings.cache_bridge_ip then
			local cache_content = get_cached_ip()
			if cache_content and #cache_content > 0 then
				settings.bridge_ip = cache_content
			else
				if settings.auto_discover then
					M:discover()
				end
			end
		else
			if settings.auto_discover then
				M:discover()
			end
		end
	end
end


return M
