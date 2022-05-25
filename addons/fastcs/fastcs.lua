--[[
* Addons - Copyright (c) 2021 Ashita Development Team
* Contact: https://www.ashitaxi.com/
* Contact: https://discord.gg/Ashita
*
* This file is part of Ashita.
*
* Ashita is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Ashita is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name      = 'fastcs';
addon.author    = 'Spiken & atom0s';
addon.version   = '1.0';
addon.desc      = 'Uses the fps plugin to automatically disable the frame rate cap during custcenes.';
addon.link      = 'https://ashitaxi.com/';

require('common');
local chat      = require('chat');
local settings  = require('settings');

-- Default Settings
local default_settings = T{
    frame_rate_divisor =  2,
    exclusions = T{ 
		"home point #1",
		"home point #2",
		"home point #3",
		"home point #4",
		"home point #5",
		"igsli",
		"urbiolaine",
		"teldro-kesdrodo",
		"nunaarl bthtrogg",
		"survival guide",
		"waypoint"
	},
};

-- FastCS Variables
local fastcs = T{
	settings = settings.load(default_settings),
	enabled = false, -- Boolean that indicates whether the Config speed-up is currently enabled
	zoning = false,  -- Boolean that indicates whether the player is zoning with the config speed-up enabled
};

--[[
* Prints the addon help information.
*
* @param {boolean} isError - Flag if this function was invoked due to an error.
--]]
local function print_help(isError)
    -- Print the help header..
    if (isError) then
        print(chat.header(addon.name):append(chat.error('Invalid command syntax for command: ')):append(chat.success('/' .. addon.name)));
    else
        print(chat.header(addon.name):append(chat.message('Available commands:')));
    end
	
    local cmds = T{
        { '/fastcs help', 'Displays this help menu.' },
        { '/fastcs fps [30|60|uncapped]', 'Changes the default FPS after exiting a cutscene.' },
        { '/fastcs frameratedivisor [2|1|0]', 'The prefix can be used interchangeably. For example, "fastcs fps 2" will set the default to 30 FPS.' },
        { '/fastcs exclusion [add|remove] <name>', 'Adds or removes a target from the exclusions list. Case insensitive.' },
    };
	
    -- Print the command list..
    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);
end

--[[
* Registers a callback for the settings to monitor for character switches.
--]]
settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        fastcs.settings = s;
    end

    -- Save the current settings..
    settings.save();
end);

function set_fastcs(state)
	if (state) then
		AshitaCore:GetChatManager():QueueCommand(1, ('/fps 0'))
	elseif (not state) then
		AshitaCore:GetChatManager():QueueCommand(1, ('/fps ' .. (fastcs.settings.frame_rate_divisor or 2)))
	end
	fastcs.enabled = state;
end

--[[
* event: unload
* desc : Event called when the addon is being unloaded.
--]]
ashita.events.register('unload', 'unload_cb', function ()
    settings.save();
end);

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'packet_in_callback1', function (e)
	if (e.id == 0x00A and not e.injected) then -- Last packet sent when zoning out
		if (fastcs.zoning) then
			set_fastcs(true);
			fastcs.zoning = false
		end
		return;
	end
end);

--[[
* event: packet_out
* desc : Event called when the addon is processing outgoing packets.
--]]
ashita.events.register('packet_out', 'packet_out_callback1', function (e)
	if (e.id == 0x00D) then
		if (fastcs.enabled) then
			set_fastcs(false);
			fastcs.zoning = true
		end
		return;
	end
end);

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function ()
	local player = GetPlayerEntity();
	local target = GetEntity(AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0));
	
	if (player ~= nil) then
		local player_status = player.StatusServer

		if not (target ~= nil and fastcs.settings.exclusions:contains(target.Name:lower())) then
			if (player_status == 4 and fastcs.enabled == false) and (target ~= nil) then
				set_fastcs(true);
			elseif (player_status ~= 4 and fastcs.enabled == true) then
				set_fastcs(false);
			end
		end
	end
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/fastcs')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Handle: /fastcs help - Displays the addons help information.
    if (#args >= 2 and args[2]:any('help')) then
        print_help();
        return;
    end
	
    -- Handle: /fastcs fps [30|60|uncapped] - Changes the default FPS after exiting a cutscene.
    -- Handle: /fastcs frameratedivisor [2|1|0] - The prefix can be used interchangeably. For example, "fastcs fps 2" will set the default to 30 FPS.
    if (#args >= 3 and args[2]:any('fps', 'frameratedivisor')) then
		if (args[3] == '60' or args[3] == '1') then
			fastcs.settings.frame_rate_divisor = 1
		elseif (args[3] == '30' or args[3] == '2') then
			fastcs.settings.frame_rate_divisor = 2
		elseif (args[3] == 'uncapped' or args[3] == '0') then
			fastcs.settings.frame_rate_divisor = 0 
		end
		
		local help_message = (fastcs.settings.frame_rate_divisor == 0) and 'Uncapped' or (fastcs.settings.frame_rate_divisor == 1 ) and '60 FPS' or (fastcs.settings.frame_rate_divisor == 2) or '30 FPS'
		print(chat.header(addon.name):append(chat.message('Default frame rate divisor is now: ' .. fastcs.settings.frame_rate_divisor .. '(' .. help_message .. ')')));
		settings.save();
        return;
    end
	
    -- Handle: /fastcs exclusion [add|remove] <name> - Adds or removes a target from the exclusions list. Case insensitive.
    if (#args >= 4 and args[2]:any('exclusion')) then
        if (args[3] == 'add' and not fastcs.settings.exclusions:contains(args[4]:lower())) then
			table.insert(fastcs.settings.exclusions, args[4]:lower())
			print(chat.header(addon.name):append(chat.message(args[4] .. ' added to the exclusions list.')));
		elseif (args[3] == 'add' and fastcs.settings.exclusions:contains(args[4]:lower())) then
			print(chat.header(addon.name):append(chat.message(args[4] .. ' is already on the exclusions list.')));
		elseif (args[3] == 'remove' and fastcs.settings.exclusions:contains(args[4]:lower())) then
			for x = 1, #fastcs.settings.exclusions do
				if (fastcs.settings.exclusions[x] == args[4]:lower()) then
					table.remove(fastcs.settings.exclusions, x);
					print(chat.header(addon.name):append(chat.message(args[4] .. ' removed from the exclusions list.')))
				end
			end
		elseif (args[3] == 'remove' and not fastcs.settings.exclusions:contains(args[4]:lower())) then
			print(chat.header(addon.name):append(chat.message(args[4] .. ' is not on the exclusions list.')));
		end
		settings.save();
        return;
    end
	
	-- Unhandled: Print help information..
	print_help(true);
end);
