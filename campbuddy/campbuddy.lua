addon.name      = 'campbuddy';
addon.author    = 'Aesk';
addon.version   = '2.2.0';
addon.desc      = 'Placeholder repop clock';
addon.link      = 'https://github.com/JamesAnBo/CampBuddy';

require('common')
chat = require('chat')
settings = require('settings');
fonts = require('fonts')
ffi = require("ffi")

profiles = require('profiles')
zones = require('zones')
helpers = require('helpers')
data = require('data')
clockdelete = require('clockdelete')

ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];

local commands = require('commands')
local packethandlers = require('packethandlers')

local windowWidth = AshitaCore:GetConfigurationManager():GetFloat('boot', 'ffxi.registry', '0001', 1024);
local windowHeight = AshitaCore:GetConfigurationManager():GetFloat('boot', 'ffxi.registry', '0002', 768);

local default_settings = T{
	messages = true,
	zone_profiles = true,
	playsound = true,
	sound = 'sound01.wav',
	font = T{
		visible = true,
		color = 0xFFFFFFFF,
		font_family = 'Tahoma',
		font_height = 16,
		position_x = 30,
		position_y = 500,
		background = {
			color = 0xCC000000,
			visible = true,
		},
	},
};


local default_schedule = T{	
	year = 0,
	month = 0,
	day = 0,
	hour = 0,
	min = 0,
	sec = 0
};
local default_window_interval = T{	
	maxTime = 0,
	count = 0,
	hour = 0,
	min = 0,
	sec = 0
;}


clocks = T{
	tracknames = T{},
	trackids = T{},
	iscountdown = T{},
	iscountup = T{},
	alarm = {},
	countup = {},
	countdown = {},
	globalTimer = 0,	
	globalDelay = 1,	
	cleanup = false,
	interval_active = false,	
	my_schedule = default_schedule,
	window_interval = default_window_interval,
};


campbuddy = T{
	dng = 976,
	fld = 346,
	font = nil,
	settings = settings.load(default_settings),
};



local function update_settings(s)
    -- Update the settings table..
    if (s ~= nil) then
        campbuddy.settings = s;
    end
	
	    -- Update the font object..
    if (campbuddy.font ~= nil) then
        campbuddy.font:apply(campbuddy.settings.font);
    end

    -- Save the current settings..
    settings.save();
end

settings.register('settings', 'settings_update', update_settings);

--[[	On addon load	]]--
ashita.events.register('load', 'load_callback1', function ()
	campbuddy.font = fonts.new(campbuddy.settings.font);
	if (campbuddy.settings.zone_profiles == true) then
		packethandlers.onZoneLoad()
	end
	
end);

--[[	On addon unload	]]--
ashita.events.register('unload', 'unload_callback1', function ()	
	--	Remove any remaining timers..
    if (campbuddy.font ~= nil) then
        campbuddy.font:destroy();
        campbuddy.font = nil;
    end
	
	-- Save settings..
	settings.save();
end);

--[[	On receiving packets	]]--

ashita.events.register('packet_in', 'packet_in_th_cb', function(e)

    if (e.id == 0x29) then
        packethandlers.onMessage(e.data);
    elseif (e.id == 0x0A or e.id == 0x0B) then
        packethandlers.onZone(e);
	elseif (e.id == 0x001D) then
		if (campbuddy.settings.zone_profiles == true) then
			packethandlers.onZoneLoad();
		end
		return;
    end
	
end);

--[[	On sending packets (Does not inject)	]]--

ashita.events.register('packet_out', 'packet_out_cb', function (e)

	if (clocks.interval_active == true) then
		--If we're in a new outgoing chunk, handle idle / action stuff..
		if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
			packethandlers.HandleOutgoingChunk:once(0);
		end

	end
	
end);

--[[	Display and run timers	]]--

ashita.events.register('d3d_present', 'present_cb', function ()
	local cleanupList_cd = {};
	local cleanupList_cu = {};
	
	local fontObject = campbuddy.font;
	if (fontObject.position_x > windowWidth) then
      fontObject.position_x = 0;
    end
    if (fontObject.position_y > windowHeight) then
      fontObject.position_y = 0;
    end
    if (fontObject.position_x ~= campbuddy.settings.font.position_x) or (fontObject.position_y ~= campbuddy.settings.font.position_y) then
        campbuddy.settings.font.position_x = fontObject.position_x;
        campbuddy.settings.font.position_y = fontObject.position_y;
        settings.save()
    end
	
	local function countdown_end()
		if  (os.time() >= (clocks.globalTimer + clocks.globalDelay)) then
			clocks.globalTimer = os.time();
			for i,v in pairs(clocks.countdown) do
				clear_cu_if_cd()
				v.time = v.time - 1;
				
				-- What to do when a clocks.countdown reaches 0..
				if (v.time <= 0) then
					if (campbuddy.settings.playsound == true) then
						ashita.misc.play_sound(addon.path:append('\\sounds\\'):append(campbuddy.settings.sound));
					end
					
					if (clocks.interval_active == true) and (v.label == 'INTERVAL') then
						packethandlers.repeater()
					end
					
					if not clocks.iscountup:contains(v.label) then
						if helpers.tableHasKey(clocks.tracknames,v.label) then
							CreateNewclockscountup(v.label, v.tally, os.time())
							table.insert(clocks.iscountup, v.label);
							for i=1,#clocks.iscountdown do
								if clocks.iscountdown[i] == v.label then
									table.remove(clocks.iscountdown, i)
								end
							end
						end
					end
					table.insert(cleanupList_cd, v.id);
				end
			end
		end
	end;
	
	local function countup_end()
		for i,v in pairs(clocks.countup) do
			clear_cd_if_cu()
			for i=0,#clocks.iscountdown do
				if clocks.iscountdown[i] == v.label then
					for i=1,#clocks.iscountup do
						if clocks.iscountup[i] == v.label then
							table.remove(clocks.iscountup, i)
						end
					end
					table.insert(cleanupList_cu, v.label);
				end
			end
			if (v.eTime < 0) then
				for i=1,#clocks.iscountup do
					if clocks.iscountup[i] == v.label then
						table.remove(clocks.iscountup, i)
					end
				end
				table.insert(cleanupList_cu, v.label);
			end
		end
	end;
	
	countdown_end();
	countup_end();

	-- Update timer displays..
	local strOut = '';
	
	local function update_countdown()
		for i,v in pairs(clocks.countdown) do
			if (v.time >= 0) then
				local h, m, s
				h = v.time / 3600;
				m = (v.time % 3600) / 60;
				s = ((v.time % 3600) % 60);
				strOut = strOut .. string.format('%s(%03d)> %02d:%02d:%02d\n', v.label, v.tally, h, m, s);
			end
		end
	end
	
	local function update_countup()
		for i,v in pairs(clocks.countup) do
			v.eTime = math.floor(os.time() - v.time)
			if (v.eTime >= 0) then
				local h, m, s
				s = v.eTime % 60
				v.eTime = math.floor(v.eTime / 60)
				m = v.eTime % 60
				v.eTime = math.floor(v.eTime / 60)
				h = v.eTime % 60
				strOut = strOut .. string.format('%s(%03d)> %02d:%02d:%02d\n', v.label, v.tally, h, m, s);
			end
		end
	end
	
	if (#clocks.countdown > 0) then
		update_countdown();
		campbuddy.font.text = strOut:sub(1, #strOut - 1);
	end
	if (#clocks.countup > 0) then
		update_countup();
		campbuddy.font.text = strOut:sub(1, #strOut + 1);
	end

	-- clocks.cleanup timers..

	function clear_cd_if_cu()
		for i=1,#clocks.countup do
			local indexToRemove = 0;
			for x=1,#clocks.countdown do
				if clocks.countdown[x] == clocks.countup[i] then
					indexToRemove = x;
				end
			end;
			table.remove(clocks.countdown, indexToRemove)
		end
	end
	function clear_cu_if_cd()
		for i=1,#clocks.countdown do
			local indexToRemove = 0;
			for x=1,#clocks.countup do
				if clocks.countup[x] == clocks.countdown[i] then
					indexToRemove = x;
				end
			end;
			table.remove(clocks.countup, indexToRemove)
		end
	end
	
	if (#cleanupList_cd > 0) then
		for i=1,#cleanupList_cd do
			local indexToRemove = 0;
			for x=1,#clocks.countdown do
				if (clocks.countdown[x].id == cleanupList_cd[i]) then
					indexToRemove = x;
				end;
			end;
			table.remove(clocks.countdown, indexToRemove);
		end;

        cleanupList_cd = {};
	end;
	
	if (#cleanupList_cu > 0) then
		for i=1,#cleanupList_cu do
			local indexToRemove = 0;
			for x=1,#clocks.countup do
				if (clocks.countup[x].label == cleanupList_cu[i]) then
					indexToRemove = x;
				end;
			end;
			table.remove(clocks.countup, indexToRemove);
		end;
        cleanupList_cu = {};
	end;
end);

ashita.events.register('command', 'command_callback1', function (e)

    local args = e.command:args();
	
    if (#args == 0 or (args[1] ~= '/cbud' and args[1] ~= '/campbuddy')) then
        return;
    else
        e.blocked = true;
        local cmd = args[2];
		
	--[[	Add timer by current target ID	]]--
        if (cmd:any('addtg', 'tgadd')) then
			commands.addTarget(args)
			return;
	--[[	Add timer by defined ID	]]--
		elseif (cmd:any('addid', 'idadd')) then
			commands.addId(args)
			return;
	--[[	Add timer by profile	]]--
		elseif (cmd:any('addpr', 'pradd')) then
			commands.addProfile(args)
			return;
	--[[	Add timer by defined name	]]--
		elseif (cmd:any('addnm', 'nmadd')) then
			commands.addName(args)
			return;
	--[[	Add camp window intervals timer	]]--
		elseif (cmd:any('interval', 'int')) then
			commands.addInterval(args)
			return;
	--[[	Clear all or defined timers	]]--
		elseif (cmd:any('del', 'delete', 'clear')) then
			commands.delete(args)
			return;
	--[[	Manually start defined timer	]]--
		elseif (cmd:any('start')) then
			commands.start(args)
			return;
	--[[	List current timers 	]]--		
		elseif (cmd:any('list')) then
			commands.list(args)
			return;
	--[[	Toggle auto-loading profiles on zone in	 ]]--
        else
			commands.changeSettings(args)
			return;
		end

    end
	
end);

--[[	Create new timer	]]--

CreateNewclockscountdown = function(txtName, totalCount, maxTime)

	table.insert(clocks.countdown, { id = txtName .. os.time(), label = txtName, tally = totalCount, time = maxTime });
	
end;

CreateNewclockscountup = function(txtName, totalCount, startTime)

	table.insert(clocks.countup, { id = txtName .. os.time(), label = txtName, tally = totalCount, time = startTime, eTime = 0});
	
end;

--[[	Make print look good	]]--

function PPrint(txt)
	if (campbuddy.settings.messages == true) then
		print(chat.header(addon.name):append(chat.message(txt)));
	end
end

function Print_Profile_Load(s)
	if (campbuddy.settings.messages == true) then
		print(chat.header(addon.name):append(chat.error('Profile: ')):append(chat.message(s):append(' - ')):append(chat.color1(6, 'loaded')));
	end
end;