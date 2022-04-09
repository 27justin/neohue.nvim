# NeoHUE

Control your Philips Hue lights from inside neovim.

## Demo

*Coming soon*

## Features

* Toggle individual lights on and off
* Toggle groups (rooms) on and off
* Set brightness of groups or individual lights
* List groups configured on the bridge
* List lights configured on the bridge

## Dependencies

To function properly, neohue requires:

* `plenary.nvim` - to send cURL requests
* `lua-cjson` - to parse JSON responses from the bridge (luarocks dependency)

## Installation

Use your favourite plugin manager, packer, vim-plug, etc.

Here's an example for packer.nvim:
```lua
use {
	"27justin/neohue.nvim",
	config = function()
		require"neohue".setup{
			cache_bridge_ip = true,
			auto_discover = true,
			silent = false
		}
	end,
	requires = { "nvim-lua/plenary.nvim" },
	rocks = { "lua-cjson" }
}
```

## Setup

```lua
require"neohue".setup{
	-- `auto_discover`: whether neohue should try and discover your HUE bridge through SSDP
	auto_discover = true,

	-- `cache_bridge_ip`: tells neohue to cache the discovered IP-address on your filesystem, that way on the subsequent starts of neovim, neohue doesn't have to check your network again
	cache_bridge_ip = true

	-- `silent`: en/-disable notifications for events with the HUE bridge (IP found, etc.)
	-- true is on = no notifications
	-- false is off = notifications
	silent = false,

	-- `bridge_ip`: if you know the IP-address of your HUE bridge, set this field
	-- if it is set, discovering and caching is not needed, if it is nil, then you have to either
	-- enable `auto_discover`, or manually start discovering with `:HueDiscover` or `require"neohue".discover()`
	bridge_ip = nil
}
```

Once the plugin is installed and the bridge was discovered, you have to pair neohue with the bridge.

1. Go to your HUE Bridge and press the link button
2. Go back to your PC and run :HueConnect, if everything goes well neohue will now be paired to your bridge

>__NOTE__: Do it in this order, it won't work if you first execute :HueConnect and then go press the link button

## Commands

```
:HueDiscover							Try to discover the hue bridge on your network, only needed when bridge_ip wasn't set AND auto_discover is false
:HueConnect								Create a new API user on the HUE bridge (required to interact with the bridge, after pairing neohue with the bridge, the API-"key" is saved locally)

:HueLight <index> on/off				Turn light <index> on or off
:HueLightToggle <index>					Turn light <index> on or off, depending on its current state
:HueLightBrightness <index> <val>		Set the brightness for light <index> to <val> where <val> is a value between 0-100 (percentage)

:HueGroup <index/name> on/off 			Turn group/room <index> on or off
:HueGroupToggle <index/name>			Turn group/room <index> on or off, depending on its current state
:HueGroupBrightness <index/name> <val> 	Set the brightness for group <index> to <val> where <val> is a value between 0-100 (percentage)
```

## Lua API

```lua
local neohue = require"neohue"

local ip = neohue.get_bridge_ip()  	-- Return the bridge IP-address
neohue.discover()		 	-- Try to discover the bridge on your network using SSP
neohue.reset()				-- Reset the stored API username & the cached IP address
neohue.connect()			-- Pair neohue to your bridge


-- Get one specific room with `neohue.group`
local my_room = neohue.group("justin")
-- `my_room` supports the same functions as the examples below, (i.e. on, off, toggle, brighten, set_brightness)

-- ... or get one light bulb (only by index)
local first_bulb = neohue.light(1)
-- `first_bulb` also supports the same functions as described in the example below

-- Returns a table of light bulbs configured on the bridge, 
local bulbs = neohue.lights()
for k, bulb in pairs(bulbs) do
	bulb:on() -- To toggle it on
	bulb:off() -- To toggle it off
	bulb:toggle() -- To switch depending on its current state
	bulb:brighten(10) -- Brighten by 10%
	bulb:set_brightness(90) -- Set brightness to 90%
end

local groups = neohue.groups()
for k, group in pairs(groups) do
	-- Not every group is a room
	if v.type == "Room" then
		group:on() -- To toggle it on
		group:off() -- To toggle it off
		group:toggle() -- To switch depending on its current state
		group:brighten(10) -- Brighten by 10%
		group:set_brightness(90) -- Set brightness to 90%
	end
end
```

## Telescope Integration

If you have telescope installed, you can run the neohue picker:

`:Telescope neohue rooms theme=dropdown`

Pressing <CR> on any room listed toggles the lights in the room on or off.

## Planned

- [ ] Make curl requests asynchronous

