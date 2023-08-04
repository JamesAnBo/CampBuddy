local packethandlers = {}

--[[	Get current zone name	]]--

local function GetZone()
    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local zoneName = zones[zone]
	
	return zoneName;
	
end

--[[	Window interval functions	]]--

packethandlers.repeater = function()

	--Increase INTERVAL count by 1..
	clocks.window_interval.count = clocks.window_interval.count +1
	
	-- Create new INTERVAL timer..
	CreateNewclockscountdown('INTERVAL', clocks.window_interval.count, clocks.window_interval.maxTime)
end

--[[	Packet functions	]]--

local deathMes = T { 6, 20, 97, 113, 406, 605, 646 };

packethandlers.onMessage = function(data)

	-- Create new timer on mob defeat..
    local message = struct.unpack('i2', data, 0x18 + 1);

    if (deathMes:contains(message)) then
        local target = struct.unpack('i2', data, 0x14 + 1);
        local sender = struct.unpack('i2', data, 0x16 + 1);

		local targetName = AshitaCore:GetMemoryManager():GetEntity():GetName(sender);
		local targetNameTrim = helpers.all_trim(targetName);
		local targetNameTrimUpper = string.upper(targetNameTrim);
        local targetServerId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(sender);
        local targetServerIdHex = string.format('0x%X', targetServerId);
    
        local idString = string.sub(targetServerIdHex, -3);
		local idStringUpper = string.upper(idString);
		
        if (clocks.trackids ~= nil) then
			for k,v in pairs(clocks.trackids) do
				if (k == idStringUpper) then
				
					clockdelete.remove_countup(idStringUpper)
					clockdelete.remove_countdowm(idStringUpper)
					
					clocks.trackids[idStringUpper].count = (clocks.trackids[idStringUpper].count + 1)
					CreateNewclockscountdown(idStringUpper, clocks.trackids[idStringUpper].count, clocks.trackids[idStringUpper].maxTime)
					PPrint(idStringUpper..' timer started')
				end
            end
        end
		if (clocks.tracknames ~= nil) then
			for k,v in pairs(clocks.tracknames) do
				if (k == targetNameTrimUpper) then
					clockdelete.remove_countup(targetNameTrimUpper)
					clockdelete.remove_countdowm(targetNameTrimUpper)
					
					table.insert(clocks.iscountdown, targetNameTrimUpper)
					clocks.tracknames[targetNameTrimUpper].count = (clocks.tracknames[targetNameTrimUpper].count + 1)
					CreateNewclockscountdown(targetNameTrimUpper, clocks.tracknames[targetNameTrimUpper].count, clocks.tracknames[targetNameTrimUpper].maxTime)
					PPrint(targetNameTrimUpper..' timer started')
				end
            end
		end
    end
	
end

--[[	Clears tracked IDs (not names) on zone; Does not stop current running clocks	]]--

packethandlers.onZone = function(e)
    clocks.trackids = T{};
	
end;

--[[	Load profiles when zoning in	]]--

packethandlers.onZoneLoad = function(e)
	local ignore = T{'nickname','group','zone'};
	local loaded = false;
	for k,v in pairs(profiles.PH) do
		local name = helpers.all_trim(k);
		local nameUpper = string.upper(name);
		local nickname = profiles.PH[k].nickname;
		local zone = profiles.PH[k].zone;
		if (GetZone() == string.upper(zone)) then
			local profile = profiles.PH[k].placeholders;
			if (profile ~= nil) then
			
				for k,v in pairs(profile) do
					local strUpper = string.upper(k)
					if not ignore:contains(strUpper) then
						if not helpers.tableHasKey(clocks.trackids,strUpper) then
							local tbl = {
								maxTime = v,
								count = 0
							};
							clocks.trackids[strUpper] = tbl;
							if loaded == false then
								Print_Profile_Load(name);
							end
							PPrint(strUpper..' set to '..helpers.formatTime(v));
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

packethandlers.HandleOutgoingChunk = function(e)

	local t = os.date("*t",os.time())
	
	local function IsInterval()
		for i,v in pairs(clocks.countdown) do
			if v.label == 'INTERVAL' then
				return true
			end
		end
		return false
	end
	
	if (helpers.do_tables_match(t, clocks.my_schedule)) then
		if (t.hour == clocks.my_schedule.hour) and (t.min == clocks.my_schedule.min) and ((t.sec == clocks.my_schedule.sec)) then
			if (clocks.interval_active == true) and not (IsInterval()) then
				packethandlers.repeater()
			end
		end
	end
	
end

return packethandlers;