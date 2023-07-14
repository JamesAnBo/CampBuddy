addon.name      = 'campbuddy';
addon.author    = 'Aesk';
addon.version   = '1.3.2';
addon.desc      = 'Placeholder repop clock';
addon.link      = 'https://github.com/JamesAnBo/CampBuddy';

require('common');

local profiles = require('profiles');
local fonts = require('fonts');

local trackids = T{};	-- NO TOUCH!
local allTimers = {};	-- NO TOUCH!
local globalTimer = 0;	-- NO TOUCH!
local globalDelay = 1;	-- NO TOUCH!

local playsound = false;	-- Change to true for default sound on
local sound = 'ding.wav';	-- if you want a custom sound (must be .wav) define it here and put the .wav in the sounds folder.
local fontSettings = T{
	visible = true,
	color = 0xFFFFFFFF,
	font_family = 'Tahoma',
	font_height = 11,	-- Change this to make things bigger or smaller.
	position_x = 500,	-- Change this to set a default up/down position.
	position_y = 500,	-- Change this to set a default left/right position.
};

local fontTimer = fonts.new(fontSettings);
fontTimer.background.color = 0xCC000000;
fontTimer.background.visible = true;

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

-- local function GetIsMobByIndex(index)
	-- return (bit.band(AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(index), 0x10) ~= 0);
-- end

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

local deathMes = T { 6, 20, 97, 113, 406, 605, 646 };
local function onMessage(data)
    local message = struct.unpack('i2', data, 0x18 + 1);

    if (deathMes:contains(message)) then
        local target = struct.unpack('i2', data, 0x14 + 1);
        local sender = struct.unpack('i2', data, 0x16 + 1);

        local targetServerId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(sender);
        local targetServerIdHex = string.format('0x%X', targetServerId);
    
        local idString = string.sub(targetServerIdHex, -3);

        if (trackids ~= nil) then
			for k,v in pairs(trackids) do
				--PPrint(k..' '..v);
				if (k == idString) then
					CreateNewTimer(idString, trackids[idString])
					PPrint(idString..' timer started')
				end
            end
        end
    end
end

local function onZone(e)
    trackids = {}; --Clears tracked IDs on zone, but does not stop current running clocks.
end;

local function helpmsg()

PPrint('CampBuddy help. Timers won\'t appair until the chosen mob(s) are defeated.');
PPrint('/cbud addtg <H> <M> <S>     - will prepare a timer for the current targeted mob.');
PPrint('/cbud addid <ID> <H> <M> <S>     - will prepare a timer for the defined mob ID.');
PPrint('/cbud addpr <profile>     - will prepare a timers for the defined profile.');
PPrint('/cbud del <ID>     - delete chosen timer.');
PPrint('/cbud del all     - delete all timers.');
PPrint('/cbud list     - print timers list.');
PPrint('/cbud move <X> <Y>     - move the timers.');
PPrint('/cbud sound     - toggle sound when a timer reaches 00:00:00.');
PPrint('/cbud help     - print help.');

end

local function IsNum(str)
	return not (str == "" or str:find("%D")) 
end

ashita.events.register('command', 'command_callback1', function (e)
    local args = e.command:args();
    if (#args == 0 or (args[1] ~= '/cbud' and args[1] ~= '/campbuddy')) then
        return;
    else
        e.blocked = true;
        local cmd = args[2];

        if (cmd == 'addtg') or (cmd == 'tgadd') then
			if (#args == 5) then
				local id = GetIdForMatch();
				if (id == '0x0') or (id == nil) then
					PPrint('Missing or invalid target');
				elseif (args[3] == nil or args[4] == nil or args[5] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need H M S)');
				elseif (not IsNum(args[3]) or not IsNum(args[4]) or not IsNum(args[5])) then
					PPrint('Unable to create timer; H M S must be numbers')
				else
					local h = tonumber(args[3]);
					local m = tonumber(args[4]);
					local s = tonumber(args[5]);
					local totaltime = (h * 3600) + (m * 60) + s;
					trackids[id] = totaltime;
					PPrint(id..' set to '..totaltime..' seconds');
				end;
			end;
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
					trackids[id] = totaltime;
					PPrint(id..' set to '..totaltime..' seconds');
				end;
			end
		elseif (cmd == 'addpr') or (cmd == 'pradd') then
			if (#args == 3) then
				if (args[3] == nil) then
					PPrint('Unable to create timer; Missing parameters (Need profile name)');
				else
					local profile = {};
					for k,v in pairs(profiles) do
						if (string.lower(args[3]) == string.lower(k)) then
							profile = profiles[k];
						end
					end
					if (profile ~= nil) then
						for k,v in pairs(profile) do
							local id = k
							trackids[id] = v;
							PPrint(k..' set to '..v..' seconds');
						end
					else
						PPrint('No profile found for that NM')
					end
				end
			else
				PPrint('Unable to create timer; No spaces in profile names.');
			end
		elseif (cmd == 'del') then
			if (args[3] == nil) then
				PPrint('Missing timer label in arguments');
			elseif (args[3] == 'all') then
				for i,v in pairs(allTimers) do
					allTimers[i].time = 0;
				end;
				trackids = {};
				PPrint('Clearing all timers.');
			else
				for i=1,#allTimers do
					if (allTimers[i].label == args[3]) then
						allTimers[i].time = 0;
					end
				end
				for k,v in pairs(trackids) do
					if (k == args[3]) then
						PPrint('Clearing timer '..k);
						trackids[k] = nil;
						return;
					end
				end

                PPrint('No timer found with that label');
			end;
		elseif (cmd == 'list') then
			local next = next;
			if next(trackids) == nil then
				PPrint('No timers found');
			else
				for k,v in pairs(trackids) do
					PPrint(k..' - '..v..' seconds');
				end;
			end
        elseif (cmd == 'sound') then
                playsound = not playsound;
                PPrint('Sound is '..tostring(playsound));
        elseif (cmd == 'warnpt') then
                warnpt = not warnpt;
                PPrint('Warnpt is '..tostring(warnpt));
        elseif (cmd == 'move') then
            if (args[3] == nil or args[4] == nil) then
				PPrint('Unable to move timers; Missing parameters (Need X Y)');
			else
                fontTimer.position_x = tonumber(args[3]);
                fontTimer.position_y = tonumber(args[4]);
				 PPrint('Position set to '..fontTimer.position_x..' '..fontTimer.position_y);
            end
		elseif (cmd == 'help') then
			helpmsg();
			
		elseif (cmd == 'test') then
			local id = GetIdForMatch();
			if (id == '0x0') or (id == nil) then
				PPrint('Missing or invalid target')
			else
				PPrint('Current target ID: '..id);
			end
		end
    end
end);

ashita.events.register('unload', 'unload_callback1', function ()
    fontTimer:destroy();
end);

ashita.events.register('packet_in', 'packet_in_th_cb', function(e)
    if (e.id == 0x29) then
        onMessage(e.data);
    elseif (e.id == 0x0A or e.id == 0x0B) then
        onZone(e);
    end
end);

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
            strOut = strOut .. string.format('%s> %02d:%02d:%02d\n', v.label, h, m, s);
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

function CreateNewTimer(txtName, maxTime)
	table.insert(allTimers, { id = txtName .. os.time(), label = txtName, time = maxTime });
end;

function PPrint(txt)
    print(string.format('[\30\08CampBuddy\30\01] %s', txt));
end