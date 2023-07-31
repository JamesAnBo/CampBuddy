addon.name      = 'campbuddy';
addon.author    = 'Aesk';
addon.version   = '2.0';
addon.desc      = 'Placeholder repop clock';
addon.link      = 'https://github.com/JamesAnBo/CampBuddy';

require('common');
local chat = require('chat');
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
local countUp = {};		-- NO TOUCH!
local countDown = {};	-- NO TOUCH!
local globalTimer = 0;	-- NO TOUCH!
local globalDelay = 1;	-- NO TOUCH!
local cleanup = false;
local isCountDown = T{};
local isCountUp = T{};

local isDebug = false;

local dng = 976;	-- Dungeon timers (00:16:16) 
local fld = 346;	-- Field timers (00:05:46)

local messages = true;
local zoneProfiles = true; -- If true, profiles will auto-load on zone in and addon load.
local playsound = true;	-- if true, a sound will play when a timer reaches 00:00:00.
local sound = 'Sound01.wav';	-- if you want a custom sound (must be .wav) define it here and put the .wav in the sounds folder.

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

function __LINE__() return debug.getinfo(2, 'l').currentline end
function __FUNC__() return debug.getinfo(2, 'n').name end

local function do_tables_match( a, b )

	-- Is table 'a' and table 'b' are the same..
    return table.concat(a) == table.concat(b)
end

local function args_iterator (col)

	-- Return args[4+] for concat..
	local index = 3
	local count = #col
	
	return function ()
		index = index + 1
		
		if index <= count then
			return col[index]
		end
	end
end

local function decimalToHex(num)

	-- Convert ARGB color values to hex color values..
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

	-- Is str a number..
	return not (str == "" or str:find("%D"))
end

local function all_trim(str)

	-- Return str without spaces..
   return str:gsub("%s+", "")
end

local function tableHasKey(table,key)

	-- Does table have key..
    return table[key] ~= nil
	
end

local function formatTime(sec)
	
	-- Return time in H:M:S format..
	local h = sec / 3600;
	local m = (sec % 3600) / 60;
	local s = ((sec % 3600) % 60);
	
	return string.format('%02d:%02d:%02d', h, m, s);
	
end


--[[	Get target ID functions	]]--

local function GetIsMob(targetEntity)

	if (targetEntity == nil) then
		return false;
	end
	
    -- Obtain the entity spawn flags..
    local flag = targetEntity.SpawnFlags;
	
    -- Determine the entity type..
	local isMob;
	
    if (bit.band(flag, 0x0001) == 0x0001 or bit.band(flag, 0x0002) == 0x0002) then 
		-- Return false if players and npcs..
        isMob = false;
    else 
		-- Return true if mob..
		isMob = true;
    end
	
	return isMob;
	
end

local function GetStPartyIndex()
	
	-- Return subtarget index..
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
	
	-- Is target a subtarget.. 
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
	
    if (playerTarget == nil) then
        return false;
    end
	
    return playerTarget:GetIsSubTargetActive() == 1 or (GetStPartyIndex() ~= nil and playerTarget:GetTargetIndex(0) ~= 0);
	
end

local function GetTargets()

	-- Return target tables..
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

	-- Return target hex ID..
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


--[[ checks and removes timers ]]--

local function check_countDown(s)


	-- Is countdown timer active..
	for i,v in ipairs(countDown) do
		if s == v.label then
			if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..s..'] == ['..v.label..'] true') end;
			return true;
		end
	end
	if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..s..'] false') end;
	return false;
end

local function check_countUp(s)

	-- Is countup timer active..
	for i,v in pairs(countUp) do
		if s == v.label then
			if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..s..'] == ['..v.label..'] true') end;
			return true
		end
	end
	if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..s..'] false') end;
	return false
end

local function remove_countDown(s)

	if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..s..']') end;

	-- Stop/Remove countdown timer..
	if s == 'ALL' then
		for i=1,#countDown do
			countDown[i].time = 0;
		end
		isCountDown = T{};
	else
		for i=1,#countDown do
			if (countDown[i].label == s) then
				countDown[i].time = 0;
			end
			if isCountDown[i] == s then
				table.remove(isCountDown, i)
			end
		end

	end
end
local function remove_countUp(s)

	if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..s..']') end;

	-- Stop/Remove countup timer..
	if s == 'ALL' then
		for i=1,#countUp do
			countUp[i].eTime = -1;
		end
	else
		for i=1,#countUp do
			if (countUp[i].label == s) then
				countUp[i].eTime = -1;
			end
		end
	end
end

--[[	Window interval functions	]]--

local function repeater()

	--Increase INTERVAL count by 1..
	windowInterval.count = windowInterval.count +1
	
	-- Create new INTERVAL timer..
	CreateNewCountDown('INTERVAL', windowInterval.count, windowInterval.maxTime)
end

--[[	Packet functions	]]--

local deathMes = T { 6, 20, 97, 113, 406, 605, 646 };

local function onMessage(data)

	-- Create new timer on mob defeat..
    local message = struct.unpack('i2', data, 0x18 + 1);

    if (deathMes:contains(message)) then
        local target = struct.unpack('i2', data, 0x14 + 1);
        local sender = struct.unpack('i2', data, 0x16 + 1);

		local targetName = AshitaCore:GetMemoryManager():GetEntity():GetName(sender);
		local targetNameTrim = all_trim(targetName);
		local targetNameTrimUpper = string.upper(targetNameTrim);
        local targetServerId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(sender);
        local targetServerIdHex = string.format('0x%X', targetServerId);
    
        local idString = string.sub(targetServerIdHex, -3);
		local idStringUpper = string.upper(idString);
		
        if (trackids ~= nil) then
			for k,v in pairs(trackids) do
				if (k == idStringUpper) then
				
					if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..k..'] == ['..idStringUpper..']') end;
				
					remove_countUp(idStringUpper)
					remove_countDown(idStringUpper)
					
					trackids[idStringUpper].count = (trackids[idStringUpper].count + 1)
					CreateNewCountDown(idStringUpper, trackids[idStringUpper].count, trackids[idStringUpper].maxTime)
					PPrint(idStringUpper..' timer started')
				end
            end
        end
		if (tracknames ~= nil) then
			for k,v in pairs(tracknames) do
				if (k == targetNameTrimUpper) then
					if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'['..k..'] == ['..targetNameTrimUpper..']') end;
					remove_countUp(targetNameTrimUpper)
					remove_countDown(targetNameTrimUpper)
					
					table.insert(isCountDown, targetNameTrimUpper)
					tracknames[targetNameTrimUpper].count = (tracknames[targetNameTrimUpper].count + 1)
					CreateNewCountDown(targetNameTrimUpper, tracknames[targetNameTrimUpper].count, tracknames[targetNameTrimUpper].maxTime)
					PPrint(targetNameTrimUpper..' timer started')
				end
            end
		end
    end
	
end

--[[	Get current zone name	]]--

local function GetZone()
    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local zoneName = zones[zone]
	
	return zoneName;
	
end

--[[	Clears tracked IDs (not names) on zone; Does not stop current running clocks	]]--

local function onZone(e)
	if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'[on zone]') end;
    trackids = T{};
	
end;

--[[	Load profiles when zoning in	]]--

local function onZoneLoad(e)
	if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'[on zone load]') end;
	local ignore = T{'nickname','group','zone'};
	local loaded = false;
	for k,v in pairs(profiles.PH) do
		local name = all_trim(k);
		local nameUpper = string.upper(name);
		local nickname = profiles.PH[k].nickname;
		local zone = profiles.PH[k].zone;
		if (GetZone() == string.upper(zone)) then
			if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'[zone match]') end;
			local profile = profiles.PH[k].placeholders;
			if (profile ~= nil) then
			
				for k,v in pairs(profile) do
					local strUpper = string.upper(k)
					if not ignore:contains(strUpper) then
						if not tableHasKey(trackids,strUpper) then
							local tbl = {
								maxTime = v,
								count = 0
							};
							trackids[strUpper] = tbl;
							if loaded == false then
								Print_Profile_Load(name);
							end
							PPrint(strUpper..' set to '..formatTime(v));
							loaded = true;
						end
					end
				end
				loaded = false;
			end
		end
	end
end

--[[	Start INTERVAL on schedule	]]--

local function HandleOutgoingChunk(e)

	local t = os.date("*t",os.time())
	
	local function IsInterval()
		for i,v in pairs(countDown) do
			if v.label == 'INTERVAL' then
				return true
			end
		end
		return false
	end
	
	if (do_tables_match(t, mySchedule)) then
		if (t.hour == mySchedule.hour) and (t.min == mySchedule.min) and ((t.sec == mySchedule.sec)) then
			if (IntervalActive == true) and not (IsInterval()) then
				if (isDebug == true) then Debug_Print(__FUNC__()..':'..__LINE__(),'[interval scheduled time match]') end;
				repeater()
			end
		end
	end
	
end


--[[	Command functions (I intend to break this down)	]]--

local function helpmsg(isError)

    if (isError) then
        print(chat.header(addon.name):append(chat.error('Invalid command syntax for command: ')):append(chat.success('/' .. addon.name)));
    else
		print(chat.header(addon.name):append(chat.message('Timers won\'t appair until the defined mob(s) are defeated.')));
		print(chat.header(addon.name):append(chat.message('Zone type (dng or fld) instead of H M S works too.')));
		print(chat.header(addon.name):append(chat.message('Available commands:')));
	end
	
	local cmds = T{
		{'/cbud addtg <H> <M> <S>    ', 'will prepare a timer for the current targeted mob.'},
		{'/cbud addid <ID> <H> <M> <S>    ', 'will prepare a timer for the defined mob ID.'},
		{'/cbud addnm <name> <H> <M> <S>    ', 'will prepare a timer for the defined mob name (no spaces).'},
		{'/cbud addpr <profile>    ', 'will prepare a timers for the defined profile.'},
		{'/cbud zonepr    ', 'toggle loading profiles when you enter zones.'},
		{'/cbud start <ID or name>    ', 'force start defined timer with max time.'},
		{'/cbud start <ID or name> <H> <M> <S>   ', 'force start defined timer at H M S'},
		{'/cbud int dur <H> <M> <S>    ', 'Sets an interval duration.'},
		{'/cbud int sch <H> <M> <S>    ', 'Schedules an interval start time (24hrs).'},
		{'/cbud int start    ', 'manually start interval timer.'},
		{'/cbud int stop    ', 'stop interval timer.'},
		{'/cbud del <ID>    ', 'delete chosen timer.'},
		{'/cbud del all    ', 'delete all timers.'},
		{'/cbud list    ', 'print timers list.'},
		{'/cbud move <X> <Y>    ', 'move the timers.'},
		{'/cbud size <size>    ', 'resize the timers'},
		{'/cbud bg    ', 'toggle background'},
		{'/cbud hide    ', 'toggle visibility'},
		{'/cbud sound    ', 'toggle sound when a timer reaches 00:00:00.'},
		{'/cbud sound  <#>  ', 'changed alert sound. (1-7)'},
		{'/cbud info    ', 'print some info.'},
		{'/cbud help    ', 'print help.'},
	};

    -- Print the command list..
    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);

end

ashita.events.register('command', 'command_callback1', function (e)

    local args = e.command:args();
	
    if (#args == 0 or (args[1] ~= '/cbud' and args[1] ~= '/campbuddy')) then
        return;
    else
        e.blocked = true;
        local cmd = args[2];
		
	--[[	Add timer by current target ID	]]--
        if (cmd:any('addtg', 'tgadd')) then
		
			local id = GetIdForMatch();
			if (id == '0x0') or (id == nil) then
				PPrint('Missing or invalid target')
			elseif (#args == 5) then
				if (args[3] == nil or args[4] == nil or args[5] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need H M S)');
				elseif (not IsNum(args[3]) or not IsNum(args[4]) or not IsNum(args[5])) then
					PPrint('Unable to create timer; H M S must be numbers')
				else
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', custom timer',__LINE__()) end;
					local idUpper = string.upper(id)
					local h = tonumber(args[3]);
					local m = tonumber(args[4]);
					local s = tonumber(args[5]);
					local totaltime = (h * 3600) + (m * 60) + s;
					local ttbl = {
						maxTime = totaltime,
						count = 0
					};
					trackids[idUpper] = ttbl;
					PPrint(idUpper..' set to '..formatTime(totaltime));
				end;
			elseif (#args == 3) then
				if (args[3] == nil or IsNum(args[3])) then
					PPrint('Unable to create timer; Missing parameters (Need zone type)');
				elseif (args[3] == 'dng') then
					local idUpper = string.upper(id)
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', dng timer',__LINE__()) end;
					local ttbl = {
						maxTime = dng,
						count = 0
					};
					trackids[idUpper] = ttbl;
					PPrint(idUpper..' set to '..formatTime(dng));
				elseif (args[3] == 'fld') then
					local idUpper = string.upper(id)
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', fld timer',__LINE__()) end;
					local ttbl = {
						maxTime = fld,
						count = 0
					};
					trackids[idUpper] = ttbl;
					PPrint(idUpper..' set to '..formatTime(fld));
				end
			end;
			
	--[[	Add timer by defined ID	]]--
		elseif (cmd:any('addid', 'idadd')) then
			if (#args == 6) then
				if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need ID H M S)');
				elseif (string.len(args[3]) ~= 3) or (string.len(args[3]) ~= 8) then
					PPrint('Unable to create timer; ID must be 3 characters');
				elseif (not IsNum(args[4]) or not IsNum(args[5]) or not IsNum(args[6])) then
					PPrint('Unable to create timer; H M S must be numbers')
				else
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', custom timer',__LINE__()) end;
					local a_id;
					if (IsNum(args[3]) and string.len(args[3]) == 8) then
						dec_hex = decimalToHex(args[3])
						a_id = string.sub(dec_hex, -3);
					else
						a_id = string.upper(args[3])
					end
					local h = tonumber(args[4]);
					local m = tonumber(args[5]);
					local s = tonumber(args[6]);
					local totaltime = (h * 3600) + (m * 60) + s;
					local ttbl = {
						maxTime = totaltime,
						count = 0
					};
					trackids[a_id] = ttbl;
					PPrint(a_id..' set to '..formatTime(totaltime));
				end;
			elseif (#args == 4) then
				if (args[3] == nil or args[4] == nil or IsNum(args[4]))  then
					PPrint('Unable to create timer; Missing parameters (Need ID and zone type)');
				elseif (string.len(args[3]) ~= 3) then
					PPrint('Unable to create timer; ID must be 3 characters');
				elseif (args[4] == 'dng') then
					local a_id;
					if (IsNum(args[3]) and string.len(args[3]) == 8) then
						dec_hex = decimalToHex(args[3])
						a_id = string.sub(dec_hex, -3);
					else
						a_id = string.upper(args[3])
					end
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', dng timer',__LINE__()) end;
					local ttbl = {
						maxTime = dng,
						count = 0
					};
					trackids[a_id] = ttbl;
					PPrint(a_id..' set to '..formatTime(dng));
				elseif (args[4] == 'fld') then
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', fld timer',__LINE__()) end;
					local a_id;
					if (IsNum(args[3]) and string.len(args[3]) == 8) then
						dec_hex = decimalToHex(args[3])
						a_id = string.sub(dec_hex, -3);
					else
						a_id = string.upper(args[3])
					end
					local ttbl = {
						maxTime = fld,
						count = 0
					};
					trackids[a_id] = ttbl;
					PPrint(a_id..' set to '..formatTime(fld));
				end
			end
			
	--[[	Add timer by profile	]]--
		elseif (cmd:any('addpr', 'pradd')) then
			if (args[3] == nil) then
				PPrint('Unable to create timer; Missing parameters (Need profile name)');
			elseif (#args >= 3) then
				local tbl = T{};
				table.insert(tbl, args[3]);
				for k in args_iterator(args) do
					table.insert(tbl, k);
				end
				local str = string.format("%s", table.concat(tbl, ''));
				local strUpper = string.upper(str)
				
				local ignore = T{'nickname','group','zone'};
				for k,v in pairs(profiles.PH) do
					local name = all_trim(k);
					local nickname = profiles.PH[k].nickname;
					local nicknameTrim = all_trim(nickname);
					local group = profiles.PH[k].group;
					local groupTrim = all_trim(group);
					if (strUpper == string.upper(name)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', from name',__LINE__()) end;
						local profile = profiles.PH[k].placeholders;
						if (profile ~= nil) then
						Print_Profile_Load(k);
							for k,v in pairs(profile) do
								local idUpper = string.upper(k)
								if not ignore:contains(idUpper) then
									if not tableHasKey(trackids,idUpper) then
										local ttbl = {
											maxTime = v,
											count = 0
										};
										trackids[idUpper] = ttbl;
										PPrint(idUpper..' set to '..formatTime(v));
									end
								end
							end
						end
					elseif (strUpper == string.upper(nicknameTrim)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', from nickname',__LINE__()) end;
						local profile = profiles.PH[k].placeholders;
						if (profile ~= nil) then
						Print_Profile_Load(k);
							for k,v in pairs(profile) do
								local idUpper = string.upper(k)
								if not ignore:contains(idUpper) then
									if not tableHasKey(trackids,idUpper) then
										local ttbl = {
											maxTime = v,
											count = 0
										};
										trackids[idUpper] = ttbl;
										PPrint(idUpper..' set to '..formatTime(v));
									end
								end
							end
						end
					elseif (strUpper == string.upper(groupTrim)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', from group',__LINE__()) end;
						local profile = profiles.PH[k].placeholders;
						if (profile ~= nil) then
						Print_Profile_Load(k);
							for k,v in pairs(profile) do
								local idUpper = string.upper(k)
								if not ignore:contains(idUpper) then
									if not tableHasKey(trackids,idUpper) then
										local ttbl = {
											maxTime = v,
											count = 0
										};
										trackids[idUpper] = ttbl;
										PPrint(idUpper..' set to '..formatTime(v));
									end
								end
							end
						end
					end
				end

				for k,v in pairs(profiles.NMsets) do
					local name = k
					local keyTrim = all_trim(k);
					if (strUpper == string.upper(keyTrim)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', from sets',__LINE__()) end;
						local profile = profiles.NMsets[k];
						if (profile ~= nil) then
						Print_Profile_Load(k);
							for k,v in pairs(profile) do
								local nameTrim = all_trim(k)
								local nameTrimUpper = string.upper(nameTrim)
								if not ignore:contains(k) then
									if not tableHasKey(tracknames,nameTrimUpper) then
										local ttbl = {
											maxTime = v,
											count = 0
										};
										tracknames[nameTrimUpper] = ttbl;
										PPrint(nameTrimUpper..' set to '..formatTime(v));
									end
								end
							end
						end
					end
				end
			end
			
	--[[	Add timer by defined name	]]--
		elseif (cmd:any('addnm', 'nmadd')) then
			if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) then
					PPrint('Unable to create timer; Missing or invalid parameters (Needs name H M S)');
			elseif (#args >= 3) then
				local tbl = T{};
				local nums = T{};
				table.insert(tbl, args[3]);
				for k in args_iterator(args) do
					if not IsNum(k) then
						table.insert(tbl, k);
					else
						table.insert(nums, k)
					end
				end
				local str = string.format("%s", table.concat(tbl, ''));
				local strUpper = string.upper(str)
				if (#nums >= 3) then
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', custom time',__LINE__()) end;
					local h = tonumber(nums[1]);
					local m = tonumber(nums[2]);
					local s = tonumber(nums[3]);
					local totaltime = (h * 3600) + (m * 60) + s;
					local ttbl = {
						maxTime = totaltime,
						count = 0
					};
					tracknames[strUpper] = ttbl;
					PPrint(strUpper..' set to '..formatTime(totaltime));
				else
					PPrint('Unable to create timer; Missing or invalid parameters (Needs name H M S)');
				end
			end;
			
	--[[	Clear all or defined timers	]]--
		elseif (cmd:any('del', 'clear')) then
		
			if (args[3] == nil) then
				PPrint('Missing timer label in arguments');
			elseif (#args >= 3) then
				local tbl = T{};
				table.insert(tbl, args[3]);
				for k in args_iterator(args) do
					table.insert(tbl, k);
				end
				local str = string.format("%s", table.concat(tbl, ''));
				local strUpper = string.upper(str)
				
				if (strUpper == 'ALL') then
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', ALL',__LINE__()) end;
					remove_countDown(strUpper);
					remove_countUp(strUpper);
					trackids = {};
					tracknames = {};
					cleanup = true;
					PPrint('Clearing ALL timers.');
					return;
				elseif (tableHasKey(trackids, strUpper)) then
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', is match',__LINE__()) end;
					remove_countDown(strUpper);
					for k,v in pairs(trackids) do
						if (k == strUpper) then
							trackids[strUpper] = nil;
							PPrint('Clearing ID timer '..strUpper);
							return;
						end
					end
				elseif (tableHasKey(tracknames, strUpper)) then
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', name match',__LINE__()) end;
					remove_countDown(strUpper);
					remove_countUp(strUpper);
					for k,v in pairs(tracknames) do
						if (k == strUpper) then
							tracknames[strUpper] = nil;
							PPrint('Clearing NM timer '..strUpper);
							return;
						end
					end
				end
				PPrint('No timer found with that label');
			end;
			
	--[[	Manually start defined timer	]]--
		elseif (cmd:any('start')) then
			if (args[3] == nil) then
				PPrint('Unable to start timer; No timer found');
			elseif (#args >= 3) then
				local tbl = T{};
				local nums = T{};
				table.insert(tbl, args[3]);
				for k in args_iterator(args) do
					if not IsNum(k) then
						table.insert(tbl, k);
					else
						table.insert(nums, k)
					end
				end
				local str = string.format("%s", table.concat(tbl, ''));
				local strUpper = string.upper(str)
				if (isDebug == true) then Debug_Print('cmd: '..args[2]..', remove countDown',__LINE__()) end;
				remove_countDown(strUpper)
				if (#nums >= 3) then
					local h = tonumber(nums[1]);
					local m = tonumber(nums[2]);
					local s = tonumber(nums[3]);
					local totaltime = (h * 3600) + (m * 60) + s;
					if (tableHasKey(trackids,strUpper)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', id custom time',__LINE__()) end;
						trackids[strUpper].count = (trackids[strUpper].count + 1);
						CreateNewCountDown(strUpper, trackids[strUpper].count, totaltime)
						PPrint(strUpper..' started at '..formatTime(totaltime));
						return;
					elseif (tableHasKey(tracknames,strUpper)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', name custom time',__LINE__()) end;
						
						remove_countUp(strUpper);
						table.insert(isCountDown, strUpper)
						tracknames[strUpper].count = (tracknames[strUpper].count + 1);
						CreateNewCountDown(strUpper, tracknames[strUpper].count, totaltime)
						PPrint(strUpper..' started at '..formatTime(totaltime));
						return;
					end;
					PPrint('No timer found: '..strUpper);
				else
					if (tableHasKey(trackids, strUpper)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', '..args[3],__LINE__()) end;
						trackids[strUpper].count = (trackids[strUpper].count + 1);
						CreateNewCountDown(strUpper, trackids[strUpper].count, trackids[strUpper].maxTime)
						return;
					elseif (tableHasKey(tracknames, strUpper)) then
						if (isDebug == true) then Debug_Print('cmd: '..args[2]..', '..args[3],__LINE__()) end;
						table.insert(isCountDown, strUpper)
						tracknames[strUpper].count = (tracknames[strUpper].count + 1);
						CreateNewCountDown(strUpper, tracknames[strUpper].count, tracknames[strUpper].maxTime)
						return;
					end
					PPrint('No timer found: '..strUpper);
				end;
			end;
			
		
	--[[	List current timers 	]]--		
		elseif (cmd:any('list')) then
		
			local next = next;
			if (next(trackids) == nil) and (next(tracknames) == nil) then
				PPrint('No timers found');
			else
				if (trackids ~= nil) then
				if (isDebug == true) then Debug_Print('cmd: '..args[2]..', ids',__LINE__()) end;
					for k,v in pairs(trackids) do
						PPrint(k..' ('..trackids[k].count..') - '..formatTime(trackids[k].maxTime));
					end;
				end
				if (tracknames ~= nil) then
				if (isDebug == true) then Debug_Print('cmd: '..args[2]..', names',__LINE__()) end;
					for k,v in pairs(tracknames) do
						PPrint(k..' ('..tracknames[k].count..') - '..formatTime(tracknames[k].maxTime));
					end;
				end
			end
			
	--[[	Toggle auto-loading profiles on zone in	 ]]--
        elseif (cmd:any('zonepr')) then
		
                zoneProfiles = not zoneProfiles;
                PPrint('Zone profiles is '..tostring(zoneProfiles));
				
	--[[	Toggle addon messages on/off	]]--
		elseif (cmd:any('message', 'msg')) then
			
				messages = not messages
				PPrint('Messages changed to '..tostring(messages));		
		
	--[[	Toggle sound when a timer reaches 00:00:00	]]--
        elseif (cmd:any('sound', 'alert')) then
		
			if args[3] == nil then
                playsound = not playsound;
                PPrint('Sound is '..tostring(playsound));
			elseif IsNum(args[3]) then
				local num = tonumber(args[3])
				if (num <= 0) or (num > 7) then
					PPrint('Choose alert 1-7.');
				else
					sound = ('Sound0'..args[3]..'.wav')
					PPrint('Alert changed to '..args[3]);
				end
			end
			
	--[[	Move the active timers display	]]--
        elseif (cmd:any('move', 'pos')) then
		
            if (args[3] == nil or args[4] == nil) then
				PPrint('Unable to move timers; Missing parameters (Need X Y)');
			else
                fontTimer.position_x = tonumber(args[3]);
                fontTimer.position_y = tonumber(args[4]);
				PPrint('Position set to '..fontTimer.position_x..' '..fontTimer.position_y);
            end
			
	--[[	Resize the active timers display	]]--
        elseif (cmd:any('size')) then
		
            if (args[3] == nil) then
				PPrint('Unable to resize timers; Missing parameters (Needs a size)');
			else
                fontTimer.font_height = tonumber(args[3]);
				PPrint('Size set to '..fontTimer.font_height);
            end
			
	--[[	Recolor the active timers font	]]--
        elseif (cmd:any('color')) then
		
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
				argb = string.format('%d, %d, %d, %d', a, r, g, b);
                fontTimer.color = math.d3dcolor(a, r, g, b);
				hex = decimalToHex(fontTimer.color)
				PPrint('Color hex set to 0x'..hex..' (Use this value in the settings)');
				PPrint('Color argb set to '..argb);
            end
			
	--[[	Toggle background visibility	]]--
		elseif (cmd:any('bg', 'background')) then
		
			fontTimer.background.visible = not fontTimer.background.visible;
			PPrint('Background set to '..tostring(fontTimer.background.visible));
			elseif (cmd == 'hide') then
					fontTimer.visible = not fontTimer.visible;
			PPrint('Visible set to '..tonumber(fontTimer.visible));
			
	--[[	Print a list of commands	]]--
		elseif (cmd:any('help')) then
			helpmsg();
			
	--[[	Toggle isDebug messages	]]--		
		elseif (cmd:any('debug')) then
			isDebug = not isDebug;
			PPrint('Debug set to '..tostring(isDebug));
			
	--[[	Print current settings	]]--
		elseif (cmd:any('info')) then
		
			local id = GetIdForMatch();
			if (id == '0x0') or (id == nil) then
				PPrint('[Current target ID: No mob target]');
			else
				PPrint('[Current target ID: '..id..']');
			end
			PPrint('[Position: '..fontTimer.position_x..' '..fontTimer.position_y..'] [Size: '..fontTimer.font_height..'] [Background: '..tostring(fontTimer.background.visible)..']');
			PPrint('[Sound: '..tostring(playsound)..'] [Zone Profiles: '..tostring(zoneProfiles)..'] [Visible: '..tostring(fontTimer.visible)..']');
		
	--[[	Add camp window intervals timer	]]--
		elseif (cmd:any('interval', 'int')) then
		
			if (#args == 6) then
				if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) or (not IsNum(args[4]) or not IsNum(args[5]) or not IsNum(args[6])) then
					PPrint('Invalid values. (need H M S)');
				elseif (args[3]:any('duration', 'dur')) then
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', '..args[3],__LINE__()) end;
					windowInterval.hour = tonumber(args[4]);
					windowInterval.min = tonumber(args[5]);
					windowInterval.sec = tonumber(args[6]);
					local h = windowInterval.hour;
					local m = windowInterval.min;
					local s = windowInterval.sec;
					local totaltime = (h * 3600) + (m * 60) + s;
					windowInterval.maxTime = totaltime;
					local fmt = string.format('%02d:%02d:%02d', h, m, s);
					PPrint('Duration set to: '..fmt);
				elseif (args[3]:any('schedule', 'sch')) then
					if (isDebug == true) then Debug_Print('cmd: '..args[2]..', '..args[3],__LINE__()) end;
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
					local fmt = string.format('%02d:%02d:%02d', mySchedule.hour, mySchedule.min, mySchedule.sec);
					PPrint('Scheduled to start at: '..fmt);
				end
				
			elseif (args[3]:any('start')) then
				if (isDebug == true) then Debug_Print('cmd: '..args[2]..', '..args[3],__LINE__()) end;
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
				
			elseif (args[3]:any('stop')) then
				if (isDebug == true) then Debug_Print('cmd: '..args[2]..', '..args[3],__LINE__()) end;
				IntervalActive = false
				mySchedule = mySchedule_default;
				windowInterval = windowInterval_default;
				for i=1,#countDown do
					if (countDown[i].label == 'INTERVAL') then
						countDown[i].time = 0;
					end
				end
				
				PPrint('Stopping interval timers.');
				
	--[[	Bad isDebug testing	]]--
			elseif (args[3]:any('test')) then
				if (isDebug == true) then Debug_Print('cmd: '..args[2]..', '..args[3],__LINE__()) end;
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

	--	Remove any remaining timers.
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
		return;
    end
	
end);

--[[	On sending packets (Does not inject)	]]--

ashita.events.register('packet_out', 'packet_out_cb', function (e)

	if (IntervalActive == true) then
		--If we're in a new outgoing chunk, handle idle / action stuff..
		if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
			HandleOutgoingChunk:once(0);
		end

	end
	
end);

--[[	Display and run timers	]]--

ashita.events.register('d3d_present', 'present_cb', function ()
	local cleanupList_cd = {};
	local cleanupList_cu = {};
	
	
	local function countDown_end()
		if  (os.time() >= (globalTimer + globalDelay)) then
			globalTimer = os.time();
			for i,v in pairs(countDown) do
				clear_cu_if_cd()
				v.time = v.time - 1;
				
				-- What to do when a countdown reaches 0..
				if (v.time <= 0) then
					if (playsound == true) then
						ashita.misc.play_sound(addon.path:append('\\sounds\\'):append(sound));
					end
					
					if (IntervalActive == true) and (v.label == 'INTERVAL') then
						repeater()
					end
					
					if not isCountUp:contains(v.label) then
						if tableHasKey(tracknames,v.label) then
							if (isDebug == true) then Debug_Print('creating counntUp',__LINE__()) end;
							CreateNewCountUp(v.label, v.tally, os.time())
							table.insert(isCountUp, v.label);
							for i=1,#isCountDown do
								if isCountDown[i] == v.label then
									table.remove(isCountDown, i)
								end
							end
						end
					end
					if (isDebug == true) then Debug_Print('countDown cleanup',__LINE__()) end;
					table.insert(cleanupList_cd, v.id);
				end
			end
		end
	end;
	
	local function countUp_end()
		for i,v in pairs(countUp) do
			clear_cd_if_cu()
			for i=0,#isCountDown do
				if isCountDown[i] == v.label then
					for i=1,#isCountUp do
						if isCountUp[i] == v.label then
							table.remove(isCountUp, i)
						end
					end
					if (isDebug == true) then Debug_Print('countUp cleanup',__LINE__()) end;
					table.insert(cleanupList_cu, v.label);
				end
			end
			if (v.eTime < 0) then
				for i=1,#isCountUp do
					if isCountUp[i] == v.label then
						table.remove(isCountUp, i)
					end
				end
				if (isDebug == true) then Debug_Print('countUp cleanup',__LINE__()) end;
				table.insert(cleanupList_cu, v.label);
			end
		end
	end;
	
	countDown_end();
	countUp_end();

	-- Update timer displays..
	local strOut = '';
	
	local function update_countDown()
		for i,v in pairs(countDown) do
			if (v.time >= 0) then
				local h, m, s
				h = v.time / 3600;
				m = (v.time % 3600) / 60;
				s = ((v.time % 3600) % 60);
				strOut = strOut .. string.format('%s(%03d)> %02d:%02d:%02d\n', v.label, v.tally, h, m, s);
			end
		end
	end
	
	local function update_countUp()
		for i,v in pairs(countUp) do
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
	
	if (#countDown > 0) then
		update_countDown();
		fontTimer.text = strOut:sub(1, #strOut - 1);
	end
	if (#countUp > 0) then
		update_countUp();
		fontTimer.text = strOut:sub(1, #strOut + 1);
	end

	-- Cleanup timers..

	function clear_cd_if_cu()
		for i=1,#countUp do
			local indexToRemove = 0;
			for x=1,#countDown do
				if countDown[x] == countUp[i] then
					indexToRemove = x;
				end
			end;
			table.remove(countDown, indexToRemove)
		end
	end
	function clear_cu_if_cd()
		for i=1,#countDown do
			local indexToRemove = 0;
			for x=1,#countUp do
				if countUp[x] == countDown[i] then
					indexToRemove = x;
				end
			end;
			table.remove(countUp, indexToRemove)
		end
	end
	
	if (#cleanupList_cd > 0) then
		for i=1,#cleanupList_cd do
			local indexToRemove = 0;
			for x=1,#countDown do
				if (countDown[x].id == cleanupList_cd[i]) then
					indexToRemove = x;
				end;
			end;
			table.remove(countDown, indexToRemove);
		end;

        cleanupList_cd = {};
	end;
	
	if (#cleanupList_cu > 0) then
		for i=1,#cleanupList_cu do
			local indexToRemove = 0;
			for x=1,#countUp do
				if (countUp[x].label == cleanupList_cu[i]) then
					indexToRemove = x;
				end;
			end;
			table.remove(countUp, indexToRemove);
		end;
        cleanupList_cu = {};
	end;
	
end);

--[[	Create new timer	]]--

function CreateNewCountDown(txtName, totalCount, maxTime)

	table.insert(countDown, { id = txtName .. os.time(), label = txtName, tally = totalCount, time = maxTime });
	
end;

function CreateNewCountUp(txtName, totalCount, startTime)

	table.insert(countUp, { id = txtName .. os.time(), label = txtName, tally = totalCount, time = startTime, eTime = 0});
	
end;

--[[	Make print look good	]]--

function PPrint(txt)
	if (messages == true) then
		print(chat.header(addon.name):append(chat.message(txt)));
	end
end

function Print_Profile_Load(s)
	if (messages == true) then
		print(chat.header(addon.name):append(chat.error('Profile: ')):append(chat.message(s):append(' - ')):append(chat.color1(6, 'loaded')));
	end
end;


function Debug_Print(txt1, txt2)
	
    print(chat.header(addon.name):append(chat.error('Debug: ')):append(chat.message(txt1):append(' - ')):append(chat.color1(6, txt2)));
	
end