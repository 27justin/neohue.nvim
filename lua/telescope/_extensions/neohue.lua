local telescope = require"telescope"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local rooms = {}

local find_rooms = function(opts)
	opts = opts or {}
	rooms = require"neohue".groups()
	if rooms == nil then
		return nil
	end
	-- Filter rooms and remove anything where room.type ~= "Room"
	local rooms_filtered = {}
	for k, room in pairs(rooms) do
		if room.type == "Room" then
			table.insert(rooms_filtered, { room, k })
		end
	end

	pickers.new(opts, {
		prompt_title = "NeoHUE Rooms",
		finder = finders.new_table {
			results = rooms_filtered,
			entry_maker = function(entry)
				return {
					value = entry[2],
					display = "[" .. ( entry[1].state.any_on and "ON" or "OFF" ) .. "] " .. entry[1].name,
					ordinal = entry[1].name
				}
			end
		},
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				rooms[selection.value]:toggle()
			end)
			return true
		end
	}):find()
end

return telescope.register_extension {
	exports = {
		rooms = find_rooms,
		default = find_rooms
	}
}
