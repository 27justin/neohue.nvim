local curl = require "plenary.curl"
local json = require "cjson"

local M = {}

function M:new(obj)
	obj = obj or {}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function M:set_settings(settings)
	self.settings = settings
end

function M:set_idx(idx)
	self.idx = idx
end

function M:update()
	local success, response = pcall(curl.get, "http://" .. self.settings.bridge_ip .. "/api/" .. self.settings.username .. "/lights/" .. self.idx, {
		headers = {
			["Content-Type"] = "application/json"
		}
	})
	if not success then
		vim.notify("HUE Bridge is unreachable, maybe the network is down?", vim.log.levels.ERROR)
		return false
	else
		local data = json.decode(response)
		-- Update `self` with the data from `data`
		for k, v in pairs(data) do
			self[k] = v
		end
		return true
	end

end


function M:off()
	local success, response = pcall(curl.put, "http://" .. self.settings.bridge_ip .. "/api/" .. self.settings.username .. "/lights/" .. self.idx .. "/state", {
		headers = {
			["Content-Type"] = "application/json"
		},
		body = json.encode({
			["on"] = false
		})
	})
	if not success then
		vim.notify("HUE Bridge is unreachable, maybe the network is down?", vim.log.levels.ERROR)
		return false
	else
		return true
	end
end

function M:on()
	local success, response = pcall(curl.put, "http://" .. self.settings.bridge_ip .. "/api/" .. self.settings.username .. "/lights/" .. self.idx .. "/state", {
		headers = {
			["Content-Type"] = "application/json"
		},
		body = json.encode({
			["on"] = true
		})
	})
	if not success then
		vim.notify("HUE Bridge is unreachable, maybe the network is down?", vim.log.levels.ERROR)
		return false
	else
		return true
	end
end

function M:toggle()
	-- Toggle off if any lights are on
	-- Toggle on if all lights are off
	local toggle_status = not self.state.on == true

	if toggle_status then
		self:on()
		self.state.on = true
	else
		self:off()
		self.state.on = false
	end

end

function M:set_brightness(value)
	-- Set the brightness of this light to `val` * 2.54
	-- (HUE API expects brightness in 0-254 range)
	self.state.bri = math.floor(math.max(0, math.min(value * 2.54, 254)))
	local success, response = pcall(curl.put, "http://" .. self.settings.bridge_ip .. "/api/" .. self.settings.username .. "/lights/" .. self.idx .. "/state", {
		body = json.encode({
			["bri"] = self.state.bri
		}),
		headers = {
			["Content-Type"] = "application/json"
		}
	})

end

function M:brighten(value)
	-- Get current brightness from self.state.bri, the value is between 0 and 254
	-- `value` is a value between 0 and 100, representing the percentage we have to add to the current brightness
	self.state.bri = math.floor(math.max(0, math.min(self.state.bri + value * 2.54, 254)))

	-- Take the new brightness and curl.put it to the Hue Bridge
	-- The username is set in self.settings.username, the IP address in self.settings.bridge_ip
	local success, response = pcall(curl.put, "http://" .. self.settings.bridge_ip .. "/api/" .. self.settings.username .. "/lights/" .. self.idx .. "/state", {
		body = json.encode({
			["bri"] = self.state.bri
		}),
		headers = {
			["Content-Type"] = "application/json"
		}
	})
	if not success then
		vim.notify("HUE Bridge is unreachable, maybe the network is down?", vim.log.levels.ERROR)
		return false
	else
		return true
	end
end


M.__index = M
return M

