addon.name      = 'campbuddy';
addon.author    = 'Aesk';
addon.version   = '1.8';
addon.desc      = 'Placeholder repop clock';
addon.link      = 'https://github.com/JamesAnBo/CampBuddy';

require('common');
local zones = require('zones');
local ffi = require("ffi");
ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];

local profiles = require('profiles');
local fonts = require('fonts');


local IntervalActive = false;	-- NO TOUCH!
local mySchedule_default = T{	-- NO TOUCH!
	year = 0,
	month = 0,
	day = 0,
	hour = 0,
	min = 0,
	sec = 0
};
local windowInterval_default = T{	-- NO TOUCH!
	maxTime = 0,
	count = 0,
	hour = 0,
	min = 0,
	sec = 0
};
local mySchedule = mySchedule_default;	-- NO TOUCH!
local windowInterval = windowInterval_default;	-- NO TOUCH!

local tracknames = T{}; -- NO TOUCH!
local trackids = T{};	-- NO TOUCH!
local alarm = {};		--NO TOUCH!
local allTimers = {};	-- NO TOUCH!
local globalTimer = 0;	-- NO TOUCH!
local globalDelay = 1;	-- NO TOUCH!

local dng = 976;	-- Dungeon timers (00:16:16) 
local fld = 346;	-- Field timers (00:05:46)

local zoneProfiles = true; -- If true, profiles will auto-load on zone in and addon load.
local playsound = true;	-- if true, a sound will play when a timer reaches 00:00:00.
local sound = 'ding.wav';	-- if you want a custom sound (must be .wav) define it here and put the .wav in the sounds folder.
local fontSettings = T{
	visible = true,
	color = 0xFFFFFFFF,
	font_family = 'Tahoma',
	font_height = 16,	-- Change this to make things bigger or smaller.
	position_x = 30,	-- Change this to set a default up/down position.
	position_y = 500,	-- Change this to set a default left/right position.
};

local fontTimer = fonts.new(fontSettings);
fontTimer.background.color = 0xCC000000;
fontTimer.background.visible = true; -- if false, background will not be visible.


--[[	Helper functions	]]--

local function do_tables_match( a, b )
    return table.concat(a) == table.concat(b)
end

local function decimalToHex(num)
    if num == 0 then
        return '0'
    end
    local neg = false
    if num < 0 then
        neg = true
        num = num * -1
    end
    local hexstr = "0123456789ABCDEF"
    local result = ""
    while num > 0 do
        local n = math.mod(num, 16)
        result = string.sub(hexstr, n + 1, n + 1) .. result
        num = math.floor(num / 16)
    end
    if neg then
        result = '-' .. result
    end
    return result
end


local function IsNum(str)
	return not (str == "" or str:find("%D"))
end

local function all_trim(str)
   return str:gsub("%s+", "")
end

local function tableHasKey(table,key)
    return table[key] ~= nil
end

local function formatTime(sec)
	local h = sec / 3600;
	local m = (sec % 3600) / 60;
	local s = ((sec % 3600) % 60);
	
	return string.format('%02d:%02d:%02d\n', h, m, s);
end


local function utils_Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end


--[[	Get target ID functions	]]--

local function GetIsMob(targetEntity)
	if (targetEntity == nil) then
		return false;
	end
    -- Obtain the entity spawn flags..
    local flag = targetEntity.SpawnFlags;
    -- Determine the entity type
	local isMob;
    if (bit.band(flag, 0x0001) == 0x0001 or bit.band(flag, 0x0002) == 0x0002) then --players and npcs
        isMob = false;
    else --mob
		isMob = true;
    end
	return isMob;
end

local function GetStPartyIndex()
    local ptr = AshitaCore:GetPointerManager():Get('party');
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    local isActive = (ashita.memory.read_uint32(ptr + 0x54) ~= 0);
    if isActive then
        return ashita.memory.read_uint8(ptr + 0x50);
    else
        return nil;
    end
end

local function GetSubTargetActive()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    if (playerTarget == nil) then
        return false;
    end
    return playerTarget:GetIsSubTargetActive() == 1 or (GetStPartyIndex() ~= nil and playerTarget:GetTargetIndex(0) ~= 0);
end

local function GetTargets()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    local party = AshitaCore:GetMemoryManager():GetParty();

    if (playerTarget == nil or party == nil) then
        return nil, nil;
    end

    local mainTarget = playerTarget:GetTargetIndex(0);
    local secondaryTarget = playerTarget:GetTargetIndex(1);
    local partyTarget = GetStPartyIndex();

    if (partyTarget ~= nil) then
        secondaryTarget = mainTarget;
        mainTarget = party:GetMemberTargetIndex(partyTarget);
    end

    return mainTarget, secondaryTarget;
end

local function GetIdForMatch()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    local targetIndex;
    local targetEntity;
    if (playerTarget ~= nil) then
        targetIndex, _ = GetTargets();
        targetEntity = GetEntity(targetIndex);
    end

	if (targetEntity == nil or targetEntity.Name == nil) then
		return;
	end
	
	local isMonster = GetIsMob(targetEntity);
	
	if (isMonster) then
		local targetServerId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(targetIndex);
		local targetServerIdHex = string.format('0x%X', targetServerId);

		local idString = string.sub(targetServerIdHex, -3);

		return idString;
	end
end


--[[	Window interval functions	]]--

local function repeater()
	windowInterval.count = windowInterval.count +1
	
	CreateNewTimer('Interval', windowInterval.count, windowInterval.maxTime)
end


--[[	Packet functions	]]--

local deathMes = T { 6, 20, 97, 113, 406, 605, 646 };
local function onMessage(data)
    local message = struct.unpack('i2', data, 0x18 + 1);

    if (deathMes:contains(message)) then
        local target = struct.unpack('i2', data, 0x14 + 1);
        local sender = struct.unpack('i2', data, 0x16 + 1);

		local targetName = AshitaCore:GetMemoryManager():GetEntity():GetName(sender);
		local targetNameTrim = all_trim(targetName);
        local targetServerId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(sender);
        local targetServerIdHex = string.format('0x%X', targetServerId);
    
        local idString = string.sub(targetServerIdHex, -3);
		
		--PPrint(string.lower(targetNameTrim));
        if (trackids ~= nil) then
			for k,v in pairs(trackids) do
				--PPrint(k..' '..v);
				if (k == idString) then
					trackids[k].count = (trackids[k].count + 1)
					CreateNewTimer(idString, trackids[k].count, trackids[k].maxTime)
					PPrint(idString..' timer started')
				end
            end
        end
		if (tracknames ~= nil) then
			for k,v in pairs(tracknames) do
				--PPrint(k..' '..v);
				if (k == string.lower(targetNameTrim)) then
					tracknames[k].count = (tracknames[k].count + 1)
					CreateNewTimer(targetNameTrim, tracknames[k].count, tracknames[k].maxTime)
					PPrint(targetNameTrim..' timer started')
				end
            end
		end
    end
end

local function GetZone()
    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local zoneName = zones[zone]
	
	return zoneName;
end

local function onZone(e)
    trackids = {}; --Clears tracked IDs on zone, but does not stop current running clocks.
end;

local function onZoneLoad(e)
	local ignore = T{'nickname','group','zone'};
	local noprofile = true;
	for k,v in pairs(profiles) do
		for k,v in pairs(profiles.PH) do
			local name = all_trim(k);
			local lowername = string.lower(name);
			local nickname = profiles.PH[k].nickname;
			local zone = profiles.PH[k].zone;
			if (GetZone() == string.upper(zone)) then
				local profile = profiles.PH[k].placeholders;
				if (profile ~= nil) then
					for k,v in pairs(profile) do
						if not ignore:contains(k) then
							if not tableHasKey(trackids,k) then
								local tbl = {
									maxTime = v,
									count = 0
								};
								trackids[k] = tbl;
								PPrint(k..' set to '..formatTime(v));
							end
						end
					end
				end
			end
		end
	end
end

local function HandleOutgoingChunk(e)
	local t = os.date("*t",os.time())
	
	local function IsInterval()
		for i,v in pairs(allTimers) do
			if v.label == 'Interval' then
				return true
			end
		end
		return false
	end
	
	--PPrint(t.hour..':'..t.min..':'..t.sec);
	if (do_tables_match(t, mySchedule)) then
		if (t.hour == mySchedule.hour) and (t.min == mySchedule.min) and ((t.sec == mySchedule.sec)) then
			if (IntervalActive == true) and not (IsInterval()) then
				repeater()
			end
		end
	end
end


--[[	Command functions (I intend to break this down)	]]--

local function helpmsg()

PPrint('CampBuddy help. Timers won\'t appair until the chosen mob(s) are defeated.');
PPrint('Zone type (dng or fld) instead of H M S works too.');
PPrint('/cbud addtg <H> <M> <S>     - will prepare a timer for the current targeted mob.');
PPrint('/cbud addid <ID> <H> <M> <S>     - will prepare a timer for the defined mob ID.');
PPrint('/cbud addnm <name> <H> <M> <S>     - will prepare a timer for the defined mob name (no spaces).');
PPrint('/cbud addpr <profile>     - will prepare a timers for the defined profile.');
PPrint('/cbud zonepr     - toggle loading profiles when you enter zones.');
PPrint('/cbud start <ID or name>     - force start defined timer with max time.');
PPrint('/cbud start <ID or name> <H> <M> <S>    - force start defined timer at H M S');
PPrint('/cbud int dur <H> <M> <S>     - Sets an interval duration.');
PPrint('/cbud int sch <H> <M> <S>     - Schedules an interval start time (24hrs).');
PPrint('/cbud int start     - manually start interval timer.');
PPrint('/cbud int stop     - stop interval timer.');
PPrint('/cbud del <ID>     - delete chosen timer.');
PPrint('/cbud del all     - delete all timers.');
PPrint('/cbud list     - print timers list.');
PPrint('/cbud move <X> <Y>     - move the timers.');
PPrint('/cbud size <size>     - resize the timers');
PPrint('/cbud bg     - toggle background');
PPrint('/cbud hide     - toggle visibility');
PPrint('/cbud sound     - toggle sound when a timer reaches 00:00:00.');
PPrint('/cbud info     - print some info.');
PPrint('/cbud help     - print help.');

end

ashita.events.register('command', 'command_callback1', function (e)
    local args = e.command:args();
    if (#args == 0 or (args[1] ~= '/cbud' and args[1] ~= '/campbuddy')) then
        return;
    else
        e.blocked = true;
        local cmd = args[2];
		
	--[[	Add timer by current target ID	]]--
        if (cmd == 'addtg') or (cmd == 'tgadd') then
			local id = GetIdForMatch();
			if (id == '0x0') or (id == nil) then
				PPrint('Missing or invalid target')
			elseif (#args == 5) then
				if (args[3] == nil or args[4] == nil or args[5] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need H M S)');
				elseif (not IsNum(args[3]) or not IsNum(args[4]) or not IsNum(args[5])) then
					PPrint('Unable to create timer; H M S must be numbers')
				else
					local h = tonumber(args[3]);
					local m = tonumber(args[4]);
					local s = tonumber(args[5]);
					local totaltime = (h * 3600) + (m * 60) + s;
					local tbl = {
						maxTime = totaltime,
						count = 0
					};
					trackids[id] = tbl;
					PPrint(id..' set to '..formatTime(totaltime));
				end;
			elseif (#args == 3) then
				if (args[3] == nil or IsNum(args[3])) then
					PPrint('Unable to create timer; Missing parameters (Need zone type)');
				elseif (args[3] == 'dng') then
					local tbl = {
						maxTime = dng,
						count = 0
					};
					trackids[id] = tbl;
					PPrint(id..' set to '..formatTime(dng));
				elseif (args[3] == 'fld') then
					local tbl = {
						maxTime = fld,
						count = 0
					};
					trackids[id] = tbl;
					PPrint(id..' set to '..formatTime(fld));
				end
			end;
			
	--[[	Add timer by defined ID	]]--
		elseif (cmd == 'addid') or (cmd == 'idadd') then
			if (#args == 6) then
				if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need ID H M S)');
				elseif (string.len(args[3]) ~= 3) then
					PPrint('Unable to create timer; ID must be 3 characters');
				elseif (not IsNum(args[4]) or not IsNum(args[5]) or not IsNum(args[6])) then
					PPrint('Unable to create timer; H M S must be numbers')
				else
					local h = tonumber(args[4]);
					local m = tonumber(args[5]);
					local s = tonumber(args[6]);
					local totaltime = (h * 3600) + (m * 60) + s;
					local id = string.upper(args[3])
					local tbl = {
						maxTime = totaltime,
						count = 0
					};
					trackids[id] = tbl;
					PPrint(id..' set to '..formatTime(totaltime));
				end;
			elseif (#args == 4) then
				if (args[3] == nil or args[4] == nil or IsNum(args[4]))  then
					PPrint('Unable to create timer; Missing parameters (Need ID and zone type)');
				elseif (string.len(args[3]) ~= 3) then
					PPrint('Unable to create timer; ID must be 3 characters');
				elseif (args[4] == 'dng') then
					local id = string.upper(args[3])
					local tbl = {
						maxTime = dng,
						count = 0
					};
					trackids[id] = tbl;
					PPrint(id..' set to '..formatTime(dng));
				elseif (args[4] == 'fld') then
					local id = string.upper(args[3])
					local tbl = {
						maxTime = fld,
						count = 0
					};
					trackids[id] = tbl;
					PPrint(id..' set to '..formatTime(fld));
				end
			end
			
	--[[	Add timer by profile	]]--
		elseif (cmd == 'addpr') or (cmd == 'pradd') then
			if (#args == 3) then
				if (args[3] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need profile name)');
				else
					local ignore = T{'nickname','group','zone'};
					local noprofile = true;
					for k,v in pairs(profiles) do
						for k,v in pairs(profiles.PH) do
							local name = all_trim(k);
							local lowername = string.lower(name);
							local nickname = profiles.PH[k].nickname;
							local group = profiles.PH[k].group;
							--local zone = profiles.PH[k].zone;
							if (string.lower(args[3]) == lowername) then
								local profile = profiles.PH[k].placeholders;
								if (profile ~= nil) then
									for k,v in pairs(profile) do
										if not ignore:contains(k) then
											if not tableHasKey(trackids,k) then
												local tbl = {
													maxTime = v,
													count = 0
												};
												trackids[k] = tbl;
												PPrint(k..' set to '..formatTime(v));
											end
										end
									end
									noprofile = false;
								end
							elseif (string.lower(args[3]) == string.lower(nickname)) then
								local profile = profiles.PH[k].placeholders;
								if (profile ~= nil) then
									for k,v in pairs(profile) do
										if not ignore:contains(k) then
											if not tableHasKey(trackids,k) then
												local tbl = {
													maxTime = v,
													count = 0
												};
												trackids[k] = tbl;
												PPrint(k..' set to '..formatTime(v));
											end
										end
									end
									noprofile = false;
								end
							elseif (string.lower(args[3]) == string.lower(group)) then
								local profile = profiles.PH[k].placeholders;
								if (profile ~= nil) then
									for k,v in pairs(profile) do
										if not ignore:contains(k) then
											if not tableHasKey(trackids,k) then
												local tbl = {
													maxTime = v,
													count = 0
												};
												trackids[k] = tbl;
												PPrint(k..' set to '..formatTime(v));
											end
										end
									end
									noprofile = false;
								end
							end
						end
					end
					for k,v in pairs(profiles.NMsets) do
						if (string.lower(args[3]) == string.lower(k)) then
							local profile = profiles.NMsets[k];
							if (profile ~= nil) then
								for k,v in pairs(profile) do
									if not ignore:contains(k) then
										if not tableHasKey(tracknames,k) then
											local tbl = {
												maxTime = v,
												count = 0
											};
											tracknames[k] = tbl;
											PPrint(k..' set to '..formatTime(v));
										end
									end
								end
								noprofile = false;
							end
						end
					end
					if noprofile == true then
							PPrint('No profile found')
					end
				end
			else
				PPrint('Unable to create timer; No spaces in profile names.');
			end
			
	--[[	Add timer by defined name	]]--
		elseif (cmd == 'addnm') or (cmd == 'nmadd') then
			if (#args >= 7) then
				PPrint('Unable to create timer; Too many parameters (Name cannot contain spaces)');
			elseif (#args == 6) then
				if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need ID H M S)');
				elseif (not IsNum(args[4])) and (IsNum(args[5]) or IsNum(args[6])) then
					PPrint('Unable to create timer; Name cannot contain spaces')
				elseif (not IsNum(args[4]) or not IsNum(args[5]) or not IsNum(args[6])) then
					PPrint('Unable to create timer; H M S must be numbers')
				else
					local h = tonumber(args[4]);
					local m = tonumber(args[5]);
					local s = tonumber(args[6]);
					local totaltime = (h * 3600) + (m * 60) + s;
					local name = string.lower(args[3])
					local tbl = {
						maxTime = totaltime,
						count = 0
					};
					tracknames[name] = tbl;
					PPrint(name..' set to '..formatTime(totaltime));
				end;
			end;
		elseif (cmd == 'del') then
			if (args[3] == nil) then
				PPrint('Missing timer label in arguments');
			elseif (args[3] == 'all') then
				for i,v in pairs(allTimers) do
					allTimers[i].time = 0;
				end;
				trackids = {};
				tracknames = {};
				PPrint('Clearing all timers.');
			else
				for i=1,#allTimers do
					if (allTimers[i].label == args[3]) then
						allTimers[i].time = 0;
					end
				end
				for k,v in pairs(trackids) do
					if (k == args[3]) then
						trackids[k] = nil;
						PPrint('Clearing timer '..k);
						return;
					end
				end
				for k,v in pairs(tracknames) do
					if (k == args[3]) then
						tracknames[k] = nil;
						PPrint('Clearing timer '..k);
						return;
					end
				end

                PPrint('No timer found with that label');
			end;
			
	--[[	Manually start defined timer	]]--
		elseif (cmd == 'start') then
			if (#args == 3) then
				if (args[3] == nil) then
					PPrint('Unable to start timer; No timer found');
				elseif (tableHasKey(trackids, string.upper(args[3]))) then
					local id = string.upper(args[3])
					trackids[id].count = (trackids[id].count + 1);
					CreateNewTimer(id, trackids[id].count, trackids[id].maxTime)
				elseif (tableHasKey(tracknames,args[3])) then
					local name = args[3];
					tracknames[name].count = (tracknames[name].count + 1);
					CreateNewTimer(name, tracknames[name].count, tracknames[name].maxTime)
				else
					PPrint('No timer found');
				end;
			elseif (#args == 6) then
				if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need ID H M S)');
				elseif (not IsNum(args[4]) or not IsNum(args[5]) or not IsNum(args[6])) then
					PPrint('Unable to create timer; H M S must be numbers')
				else
					local h = tonumber(args[4]);
					local m = tonumber(args[5]);
					local s = tonumber(args[6]);
					local totaltime = (h * 3600) + (m * 60) + s;
					local id = string.upper(args[3]);
					local name = string.lower(args[3]);
					if (tableHasKey(trackids,string.upper(args[3]))) then
						trackids[id].count = (trackids[id].count + 1);
						CreateNewTimer(id, trackids[id].count, totaltime)
						PPrint(id..' started at '..formatTime(totaltime));
					elseif (tableHasKey(tracknames,args[3])) then
						tracknames[name].count = (tracknames[name].count + 1);
						CreateNewTimer(name, tracknames[name].count, totaltime)
						PPrint(name..' started at '..formatTime(totaltime));
					else
						PPrint('No timer found');
					end;
				end;
			else
				PPrint('Unable to start timer; Missing parameters');
			end;

	--[[	List current timers 	]]--		
		elseif (cmd == 'list') then
			local next = next;
			if (next(trackids) == nil) and (next(tracknames) == nil) then
				PPrint('No timers found');
			else
				if (trackids ~= nil) then
					for k,v in pairs(trackids) do
						PPrint(k..'('..trackids[k].count..') - '..formatTime(trackids[k].maxTime));
					end;
				end
				if (tracknames ~= nil) then
					for k,v in pairs(tracknames) do
						PPrint(k..'('..tracknames[k].count..') - '..formatTime(tracknames[k].maxTime));
					end;
				end
			end
			
	--[[	Toggle auto-loading profiles on zone in	 ]]--
        elseif (cmd == 'zonepr') then
                zoneProfiles = not zoneProfiles;
                PPrint('Zone profiles is '..tostring(zoneProfiles));
				
	--[[	Toggle sound when a timer reaches 00:00:00	]]--
        elseif (cmd == 'sound') then
                playsound = not playsound;
                PPrint('Sound is '..tostring(playsound));
				
	--[[	Move the active timers display	]]--
        elseif (cmd == 'move') then
            if (args[3] == nil or args[4] == nil) then
				PPrint('Unable to move timers; Missing parameters (Need X Y)');
			else
                fontTimer.position_x = tonumber(args[3]);
                fontTimer.position_y = tonumber(args[4]);
				PPrint('Position set to '..fontTimer.position_x..' '..fontTimer.position_y);
            end
			
	--[[	Resize the active timers display	]]--
        elseif (cmd == 'size') then
            if (args[3] == nil) then
				PPrint('Unable to resize timers; Missing parameters (Needs a size)');
			else
                fontTimer.font_height = tonumber(args[3]);
				PPrint('Size set to '..fontTimer.font_height);
            end
			
	--[[	Recolor the active timers font	]]--
        elseif (cmd == 'color') then
			if (#args ~= 6) then
				PPrint('Missing values. Expected: /cbud color <a> <r> <g> <b>');
            elseif (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) or (not IsNum(args[3]) or not IsNum(args[4]) or not IsNum(args[5]) or not IsNum(args[6])) then
				PPrint('Invalid color value. Expected: /cbud color <a> <r> <g> <b>');
				PPrint('a (0-128) r,g,b (0-255)');
			else
				local a = args[3]:num_or(128);
				local r = args[4]:num_or(255);
				local g = args[5]:num_or(255);
				local b = args[6]:num_or(255);
				argb = string.format('%d, %d, %d, %d\n', a, r, g, b);
                fontTimer.color = math.d3dcolor(a, r, g, b);
				hex = decimalToHex(fontTimer.color)
				PPrint('Color hex set to 0x'..hex..' (Use this value in the settings)');
				PPrint('Color argb set to '..argb);
            end
			
	--[[	Toggle background visibility	]]--
		elseif (cmd == 'bg') then
			fontTimer.background.visible = not fontTimer.background.visible;
			PPrint('Background set to '..tostring(fontTimer.background.visible));
			elseif (cmd == 'hide') then
					fontTimer.visible = not fontTimer.visible;
			PPrint('Visible set to '..tonumber(fontTimer.visible));
			
	--[[	Print a list of commands	]]--
		elseif (cmd == 'help') then
				helpmsg();
			
	--[[	Print current settings	]]--
		elseif (cmd == 'info') then
			local id = GetIdForMatch();
			if (id == '0x0') or (id == nil) then
				PPrint('[Current target ID: No mob target]');
			else
				PPrint('[Current target ID: '..id..']');
			end
			PPrint('[Position: '..fontTimer.position_x..' '..fontTimer.position_y..'] [Size: '..fontTimer.font_height..'] [Background: '..tostring(fontTimer.background.visible)..']');
			PPrint('[Sound: '..tostring(playsound)..'] [Zone Profiles: '..tostring(zoneProfiles)..'] [Visible: '..tostring(fontTimer.visible)..']');
		
	--[[	Add camp window intervals timer	]]--
		elseif (cmd == 'interval') or (cmd == 'int') then
			if (#args == 6) then
				if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) or (not IsNum(args[4]) or not IsNum(args[5]) or not IsNum(args[6])) then
					PPrint('Invalid values. (need H M S)');
				elseif (args[3] == 'duration') or (args[3] == 'dur') then
					windowInterval.hour = tonumber(args[4]);
					windowInterval.min = tonumber(args[5]);
					windowInterval.sec = tonumber(args[6]);
					local h = windowInterval.hour;
					local m = windowInterval.min;
					local s = windowInterval.sec;
					local totaltime = (h * 3600) + (m * 60) + s;
					windowInterval.maxTime = totaltime;
					local fmt = string.format('%02d:%02d:%02d\n', h, m, s);
					PPrint('Duration set to: '..fmt);
				elseif (args[3] == 'schedule') or (args[3] == 'sch') then
					if windowInterval.maxTime <= 0 then
						PPrint('Duration must be set');
						return
					end
					local t = os.date("*t",os.time())
					mySchedule = {
						year = t.year,
						month = t.month,
						day = t.day,
						hour = tonumber(args[4]),
						min = tonumber(args[5]),
						sec = tonumber(args[6]),
					};
					IntervalActive = true
					local fmt = string.format('%02d:%02d:%02d\n', mySchedule.hour, mySchedule.min, mySchedule.sec);
					PPrint('Scheduled to start at: '..fmt);
				end
			elseif (args[3] == 'start') then
				if windowInterval.maxTime <= 0 then
					PPrint('Duration must be set');
					return
				end
				local t = os.date("*t",os.time())
				mySchedule = {
					year = t.year,
					month = t.month,
					day = t.day,
					hour = t.hour,
					min = t.min,
					sec = t.sec + 1
				};
				IntervalActive = true;
				PPrint('Starting interval timers every '..formatTime(windowInterval.maxTime));
			elseif (args[3] == 'stop') then
				IntervalActive = false
				mySchedule = mySchedule_default;
				windowInterval = windowInterval_default;
				for i=1,#allTimers do
					if (allTimers[i].label == 'Interval') then
						allTimers[i].time = 0;
					end
				end
				
				PPrint('Stopping interval timers.');
			elseif (args[3] == 'test') then
				--local timestr = string.format('%02d:%02d:%02d\n', h, m, s);
				PPrint('Year: '..mySchedule.year..' Month: '..mySchedule.month..' Day: '..mySchedule.day..' Hour: '..mySchedule.hour..' Minute: '..mySchedule.min..' Second: '..mySchedule.sec);
				PPrint('Interval: '..windowInterval.count);
				PPrint('Max time: '..windowInterval.maxTime);
				if (#alarm > 0) then
					PPrint('Time: '..alarm[#alarm].time);
				else
					PPrint('No scheduled alarms');
				end
			end
		end
    end
end);

--[[	On addon load	]]--

ashita.events.register('load', 'load_callback1', function ()
	if (zoneProfiles == true) then
		onZoneLoad()
	end
end);

--[[	On addon unload	]]--

ashita.events.register('unload', 'unload_callback1', function ()
    fontTimer:destroy();
end);

--[[	On receiving packets	]]--

ashita.events.register('packet_in', 'packet_in_th_cb', function(e)
    if (e.id == 0x29) then
        onMessage(e.data);
    elseif (e.id == 0x0A or e.id == 0x0B) then
        onZone(e);
	elseif (e.id == 0x001D) then
		if (zoneProfiles == true) then
			onZoneLoad();
		end
    end
end);

ashita.events.register('packet_out', 'packet_out_cb', function (e)
	if (IntervalActive == true) then
		--If we're in a new outgoing chunk, handle idle / action stuff.
		if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
			HandleOutgoingChunk:once(0);
		end

		--Block all action and item packets that aren't injected.
		--HandleOutgoingChunk will automatically reinject them if keeping them.
		-- if (e.id == 0x1A) or (e.id == 0x37) then
			-- e.blocked = true;
			-- return;
		-- end
	end
end);

--[[	Display and run timers	]]--

ashita.events.register('d3d_present', 'present_cb', function ()
	local cleanupList = {};
	if  (os.time() >= (globalTimer + globalDelay)) then
		globalTimer = os.time();

        for i,v in pairs(allTimers) do
            v.time = v.time - 1;
            if (v.time <= 0) then
                if (playsound == true) then
                    ashita.misc.play_sound(addon.path:append('\\sounds\\'):append(sound));
                end
				if (IntervalActive == true) and (v.label == 'Interval') then
					repeater()
				end
                table.insert(cleanupList, v.id);
			end
        end
	end;

	-- Update timer display
    local strOut = '';
    for i,v in pairs(allTimers) do
        if (v.time >= 0) then
            local h = v.time / 3600;
            local m = (v.time % 3600) / 60;
            local s = ((v.time % 3600) % 60);
            strOut = strOut .. string.format('%s(%03d)> %02d:%02d:%02d\n', v.label, v.tally, h, m, s);
        end
    end
    fontTimer.text = strOut:sub(1, #strOut - 1);

	if (#cleanupList > 0) then
		for i=1,#cleanupList do
			local indexToRemove = 0;
			for x=1,#allTimers do
				if (allTimers[x].id == cleanupList[i]) then
					indexToRemove = x;
				end;
			end;
			table.remove(allTimers, indexToRemove);
		end;

        cleanupList = {};
	end;
end);

--[[	Create new timer	]]--

function CreateNewTimer(txtName, totalCount, maxTime)
	table.insert(allTimers, { id = txtName .. os.time(), label = txtName, tally = totalCount, time = maxTime });
end;

--[[	Make print look good	]]--

function PPrint(txt)
    print(string.format('[\30\08CampBuddy\30\01] %s', txt));
end