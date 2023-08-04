local commands = {};

local function print_help(isError)

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

local function print_info()
	local id = data.GetIdForMatch();
	if (id == '0x0') or (id == nil) then
		PPrint('[Current target ID: No mob target]');
	else
		PPrint('[Current target ID: '..id..']');
	end
	
	-- Reapply the font settings..
	if (campbuddy.font ~= nil) then
		campbuddy.font:apply(campbuddy.settings.font);
	end
	
	local sound_num = string.sub(campbuddy.settings.sound, 6, 7);
	
	PPrint('[Position: '..campbuddy.font.position_x..' '..campbuddy.font.position_y..'] [Size: '..campbuddy.font.font_height..'] [Background: '..tostring(campbuddy.font.background.visible)..']');
	PPrint('[sound: '..tostring(campbuddy.settings.playsound)..'('..sound_num..')] [Zone Profiles: '..tostring(campbuddy.settings.zone_profiles)..'] [Visible: '..tostring(campbuddy.font.visible)..']');
end

commands.addTarget = function(args)
	local id = data.GetIdForMatch();
	if (id == '0x0') or (id == nil) then
		PPrint('Missing or invalid target')
	elseif (#args == 5) then
		if (args[3] == nil or args[4] == nil or args[5] == nil) then
			PPrint('Unable to create timer; Missing parameters (Need H M S)');
		elseif (not helpers.IsNum(args[3]) or not helpers.IsNum(args[4]) or not helpers.IsNum(args[5])) then
			PPrint('Unable to create timer; H M S must be numbers')
		else
			local idUpper = string.upper(id)
			local h = tonumber(args[3]);
			local m = tonumber(args[4]);
			local s = tonumber(args[5]);
			local totaltime = (h * 3600) + (m * 60) + s;
			local ttbl = {
				maxTime = totaltime,
				count = 0
			};
			clocks.trackids[idUpper] = ttbl;
			PPrint(idUpper..' set to '..helpers.formatTime(totaltime));
		end;
	elseif (#args == 3) then
		if (args[3] == nil or helpers.IsNum(args[3])) then
			PPrint('Unable to create timer; Missing parameters (Need zone type)');
		elseif (args[3] == 'dng') then
			local idUpper = string.upper(id)
			local ttbl = {
				maxTime = campbuddy.dng,
				count = 0
			};
			clocks.trackids[idUpper] = ttbl;
			PPrint(idUpper..' set to '..helpers.formatTime(campbuddy.dng));
		elseif (args[3] == 'fld') then
			local idUpper = string.upper(id)
			local ttbl = {
				maxTime = campbuddy.fld,
				count = 0
			};
			clocks.trackids[idUpper] = ttbl;
			PPrint(idUpper..' set to '..helpers.formatTime(campbuddy.fld));
		end
	end
end;

	--[[	Add timer by defined ID	]]--
commands.addId = function(args)
	if (#args == 6) then
		if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) then
			PPrint('Unable to create timer; Missing parameters (Need ID H M S)');
		elseif not ((string.len(args[3]) == 3) or (string.len(args[3]) == 8)) then
			PPrint('Unable to create timer; must be 3 character hex, or 8 decimal ID');
		elseif (not helpers.IsNum(args[4]) or not helpers.IsNum(args[5]) or not helpers.IsNum(args[6])) then
			PPrint('Unable to create timer; H M S must be numbers')
		else
			local a_id;
			if (helpers.IsNum(args[3]) and string.len(args[3]) == 8) then
				dec_hex = helpers.decimalToHex(args[3])
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
			clocks.trackids[a_id] = ttbl;
			PPrint(a_id..' set to '..helpers.formatTime(totaltime));
		end;
	elseif (#args == 4) then
		
		if (args[3] == nil or args[4] == nil or helpers.IsNum(args[4]))  then
			PPrint('Unable to create timer; Missing parameters (Need ID and zone type)');
		elseif (string.len(args[3]) ~= 3) then
			PPrint('Unable to create timer; ID must be 3 characters');
		elseif (args[4] == 'dng') then
			local a_id;
			if (helpers.IsNum(args[3]) and string.len(args[3]) == 8) then
				dec_hex = helpers.decimalToHex(args[3])
				a_id = string.sub(dec_hex, -3);
			else
				a_id = string.upper(args[3])
			end
			local ttbl = {
				maxTime = campbuddy.dng,
				count = 0
			};
			clocks.trackids[a_id] = ttbl;
			PPrint(a_id..' set to '..helpers.formatTime(campbuddy.dng));
		elseif (args[4] == 'fld') then
			local a_id;
			if (helpers.IsNum(args[3]) and string.len(args[3]) == 8) then
				dec_hex = helpers.decimalToHex(args[3])
				a_id = string.sub(dec_hex, -3);
			else
				a_id = string.upper(args[3])
			end
			local ttbl = {
				maxTime = campbuddy.fld,
				count = 0
			};
			clocks.trackids[a_id] = ttbl;
			PPrint(a_id..' set to '..helpers.formatTime(campbuddy.fld));
		end
	end
end;

	--[[	Add timer by profile	]]--
commands.addProfile = function(args)
	if (args[3] == nil) then
		PPrint('Unable to create timer; Missing parameters (Need profile name)');
	elseif (#args >= 3) then
		local tbl = T{};
		table.insert(tbl, args[3]);
		for k in helpers.args_iterator(args) do
			table.insert(tbl, k);
		end
		local str = string.format("%s", table.concat(tbl, ''));
		local strUpper = string.upper(str)
		
		local ignore = T{'nickname','group','zone'};
		for k,v in pairs(profiles.PH) do
			local name = helpers.all_trim(k);
			--PPrint('name: '..name)
			local nickname = profiles.PH[k].nickname;
			local nicknameTrim = helpers.all_trim(nickname);
			--PPrint('nickname: '..nicknameTrim)
			local group = profiles.PH[k].group;
			local groupTrim = helpers.all_trim(group);
			--PPrint('group: '..groupTrim)
			if (strUpper == string.upper(name)) then
				local profile = profiles.PH[k].placeholders;
				if (profile ~= nil) then
				Print_Profile_Load(k);
					for k,v in pairs(profile) do
						local idUpper = string.upper(k)
						if not ignore:contains(idUpper) then
							if not helpers.tableHasKey(clocks.trackids,idUpper) then
								local ttbl = {
									maxTime = v,
									count = 0
								};
								clocks.trackids[idUpper] = ttbl;
								PPrint(idUpper..' set to '..helpers.formatTime(v));
							end
						end
					end
				end
			elseif (strUpper == string.upper(nicknameTrim)) then
				local profile = profiles.PH[k].placeholders;
				if (profile ~= nil) then
				Print_Profile_Load(k);
					for k,v in pairs(profile) do
						local idUpper = string.upper(k)
						if not ignore:contains(idUpper) then
							if not helpers.tableHasKey(clocks.trackids,idUpper) then
								local ttbl = {
									maxTime = v,
									count = 0
								};
								clocks.trackids[idUpper] = ttbl;
								PPrint(idUpper..' set to '..helpers.formatTime(v));
							end
						end
					end
				end
			elseif (strUpper == string.upper(groupTrim)) then
				local profile = profiles.PH[k].placeholders;
				if (profile ~= nil) then
				Print_Profile_Load(k);
					for k,v in pairs(profile) do
						local idUpper = string.upper(k)
						if not ignore:contains(idUpper) then
							if not helpers.tableHasKey(clocks.trackids,idUpper) then
								local ttbl = {
									maxTime = v,
									count = 0
								};
								clocks.trackids[idUpper] = ttbl;
								PPrint(idUpper..' set to '..helpers.formatTime(v));
							end
						end
					end
				end
			end
		end

		for k,v in pairs(profiles.NMsets) do
			local name = k
			local keyTrim = helpers.all_trim(k);
			if (strUpper == string.upper(keyTrim)) then
				local profile = profiles.NMsets[k];
				if (profile ~= nil) then
				Print_Profile_Load(k);
					for k,v in pairs(profile) do
						local nameTrim = helpers.all_trim(k)
						local nameTrimUpper = string.upper(nameTrim)
						if not ignore:contains(k) then
							if not helpers.tableHasKey(clocks.tracknames,nameTrimUpper) then
								local ttbl = {
									maxTime = v,
									count = 0
								};
								clocks.tracknames[nameTrimUpper] = ttbl;
								PPrint(nameTrimUpper..' set to '..helpers.formatTime(v));
							end
						end
					end
				end
			end
		end
	end
end;	
	--[[	Add timer by defined name	]]--
commands.addName = function(args)
	if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) then
			PPrint('Unable to create timer; Missing or invalid parameters (Needs name H M S)');
	elseif (#args >= 3) then
		local tbl = T{};
		local nums = T{};
		table.insert(tbl, args[3]);
		for k in helpers.args_iterator(args) do
			if not helpers.IsNum(k) then
				table.insert(tbl, k);
			else
				table.insert(nums, k)
			end
		end
		local str = string.format("%s", table.concat(tbl, ''));
		local strUpper = string.upper(str)
		if (#nums >= 3) then
			local h = tonumber(nums[1]);
			local m = tonumber(nums[2]);
			local s = tonumber(nums[3]);
			local totaltime = (h * 3600) + (m * 60) + s;
			local ttbl = {
				maxTime = totaltime,
				count = 0
			};
			clocks.tracknames[strUpper] = ttbl;
			PPrint(strUpper..' set to '..helpers.formatTime(totaltime));
		else
			PPrint('Unable to create timer; Missing or invalid parameters (Needs name H M S)');
		end
	end
end;

	--[[	Add camp window intervals timer	]]--
commands.addInterval = function(args)
		
	if (#args == 6) then
		if (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) or (not helpers.IsNum(args[4]) or not helpers.IsNum(args[5]) or not helpers.IsNum(args[6])) then
			PPrint('Invalid values. (need H M S)');
		elseif (args[3]:any('duration', 'dur')) then
			clocks.window_interval.hour = tonumber(args[4]);
			clocks.window_interval.min = tonumber(args[5]);
			clocks.window_interval.sec = tonumber(args[6]);
			local h = clocks.window_interval.hour;
			local m = clocks.window_interval.min;
			local s = clocks.window_interval.sec;
			local totaltime = (h * 3600) + (m * 60) + s;
			clocks.window_interval.maxTime = totaltime;
			local fmt = string.format('%02d:%02d:%02d', h, m, s);
			PPrint('Duration set to: '..fmt);
		elseif (args[3]:any('schedule', 'sch')) then
			if clocks.window_interval.maxTime <= 0 then
				PPrint('Duration must be set');
				return
			end
			local t = os.date("*t",os.time())
			clocks.my_schedule = {
				year = t.year,
				month = t.month,
				day = t.day,
				hour = tonumber(args[4]),
				min = tonumber(args[5]),
				sec = tonumber(args[6]),
			};
			clocks.interval_active = true
			local fmt = string.format('%02d:%02d:%02d', clocks.my_schedule.hour, clocks.my_schedule.min, clocks.my_schedule.sec);
			PPrint('Scheduled to start at: '..fmt);
		end
		
	elseif (args[3]:any('start')) then
		if clocks.window_interval.maxTime <= 0 then
			PPrint('Duration must be set');
			return
		end
		local t = os.date("*t",os.time())
		clocks.my_schedule = {
			year = t.year,
			month = t.month,
			day = t.day,
			hour = t.hour,
			min = t.min,
			sec = t.sec + 1
		};
		clocks.interval_active = true;
		PPrint('Starting interval timers every '..helpers.formatTime(clocks.window_interval.maxTime));
		
	elseif (args[3]:any('stop')) then
		clocks.interval_active = false;
		clocks.my_schedule = default_schedule;
		clocks.window_interval = default_window_interval;
		for i=1,#clocks.countdown do
			if (clocks.countdown[i].label == 'INTERVAL') then
				clocks.countdown[i].time = 0;
			end
		end
		
		PPrint('Stopping interval timers.');
		
--[[	Bad debug testing	]]--
	elseif (args[3]:any('test')) then
		--local timestr = string.format('%02d:%02d:%02d\n', h, m, s);
		PPrint('Year: '..clocks.my_schedule.year..' Month: '..clocks.my_schedule.month..' Day: '..clocks.my_schedule.day..' Hour: '..clocks.my_schedule.hour..' Minute: '..clocks.my_schedule.min..' Second: '..clocks.my_schedule.sec);
		PPrint('Interval: '..clocks.window_interval.count);
		PPrint('Max time: '..clocks.window_interval.maxTime);
		if (#clocks.alarm > 0) then
			PPrint('Time: '..clocks.alarm[#clocks.alarm].time);
		else
			PPrint('No scheduled alarms');
		end
		
	end
end;

	--[[	Clear all or defined timers	]]--
commands.delete = function(args)
		
	if (args[3] == nil) then
		PPrint('Missing timer label in arguments');
	elseif (#args >= 3) then
		local tbl = T{};
		table.insert(tbl, args[3]);
		for k in helpers.args_iterator(args) do
			table.insert(tbl, k);
		end
		local str = string.format("%s", table.concat(tbl, ''));
		local strUpper = string.upper(str)
		
		if (strUpper == 'ALL') then
			clockdelete.remove_countdowm(strUpper);
			clockdelete.remove_countup(strUpper);
			clocks.trackids = {};
			clocks.tracknames = {};
			clocks.cleanup = true;
			PPrint('Clearing ALL timers.');
			return;
		elseif (helpers.tableHasKey(clocks.trackids, strUpper)) then
			clockdelete.remove_countdowm(strUpper);
			for k,v in pairs(clocks.trackids) do
				if (k == strUpper) then
					clocks.trackids[strUpper] = nil;
					PPrint('Clearing ID timer '..strUpper);
					return;
				end
			end
		elseif (helpers.tableHasKey(clocks.tracknames, strUpper)) then
			clockdelete.remove_countdowm(strUpper);
			clockdelete.remove_countup(strUpper);
			for k,v in pairs(clocks.tracknames) do
				if (k == strUpper) then
					clocks.tracknames[strUpper] = nil;
					PPrint('Clearing NM timer '..strUpper);
					return;
				end
			end
		end
		PPrint('No timer found with that label');
	end
end;
			
	--[[	Manually start defined timer	]]--
commands.start = function(args)
	if (args[3] == nil) then
		PPrint('Unable to start timer; No timer found');
	elseif (#args >= 3) then
		local tbl = T{};
		local nums = T{};
		table.insert(tbl, args[3]);
		for k in helpers.args_iterator(args) do
			if not helpers.IsNum(k) then
				table.insert(tbl, k);
			else
				table.insert(nums, k)
			end
		end
		local str = string.format("%s", table.concat(tbl, ''));
		local strUpper = string.upper(str)
		clockdelete.remove_countdowm(strUpper)
		if (#nums >= 3) then
			local h = tonumber(nums[1]);
			local m = tonumber(nums[2]);
			local s = tonumber(nums[3]);
			local totaltime = (h * 3600) + (m * 60) + s;
			if (helpers.tableHasKey(clocks.trackids,strUpper)) then
				clocks.trackids[strUpper].count = (clocks.trackids[strUpper].count + 1);
				CreateNewclockscountdown(strUpper, clocks.trackids[strUpper].count, totaltime)
				PPrint(strUpper..' started at '..helpers.formatTime(totaltime));
				return;
			elseif (helpers.tableHasKey(clocks.tracknames,strUpper)) then
				
				clockdelete.remove_countup(strUpper);
				table.insert(clocks.iscountdown, strUpper)
				clocks.tracknames[strUpper].count = (clocks.tracknames[strUpper].count + 1);
				CreateNewclockscountdown(strUpper, clocks.tracknames[strUpper].count, totaltime)
				PPrint(strUpper..' started at '..helpers.formatTime(totaltime));
				return;
			end;
			PPrint('No timer found: '..strUpper);
		else
			if (helpers.tableHasKey(clocks.trackids, strUpper)) then
				clocks.trackids[strUpper].count = (clocks.trackids[strUpper].count + 1);
				CreateNewclockscountdown(strUpper, clocks.trackids[strUpper].count, clocks.trackids[strUpper].maxTime)
				return;
			elseif (helpers.tableHasKey(clocks.tracknames, strUpper)) then
				table.insert(clocks.iscountdown, strUpper)
				clocks.tracknames[strUpper].count = (clocks.tracknames[strUpper].count + 1);
				CreateNewclockscountdown(strUpper, clocks.tracknames[strUpper].count, clocks.tracknames[strUpper].maxTime)
				return;
			end
			PPrint('No timer found: '..strUpper);
		end
	end
end;
		
	--[[	List current timers 	]]--		
commands.list = function(args)
		
	local next = next;
	if (next(clocks.trackids) == nil) and (next(clocks.tracknames) == nil) then
		PPrint('No timers found');
	else
		if (clocks.trackids ~= nil) then
			for k,v in pairs(clocks.trackids) do
				PPrint(k..' ('..clocks.trackids[k].count..') - '..helpers.formatTime(clocks.trackids[k].maxTime));
			end;
		end
		if (clocks.tracknames ~= nil) then
			for k,v in pairs(clocks.tracknames) do
				PPrint(k..' ('..clocks.tracknames[k].count..') - '..helpers.formatTime(clocks.tracknames[k].maxTime));
			end;
		end
	end
end;
	
commands.changeSettings = function(args)
--[[	Toggle auto-loading profiles on zone in	 ]]--
	if (args[2]:any('zonepr')) then
	
		campbuddy.settings.zone_profiles = not campbuddy.settings.zone_profiles;
		PPrint('Zone profiles is '..tostring(campbuddy.settings.zone_profiles));
		return;
--[[	Toggle addon messages on/off	]]--
	elseif (args[2]:any('message', 'msg')) then
		
		campbuddy.settings.messages = not campbuddy.settings.messages
		print(chat.header(addon.name):append(chat.message('messages changed to '..tostring(campbuddy.settings.messages))));
		return;
--[[	Toggle sound when a timer reaches 00:00:00	]]--
	elseif (args[2]:any('sound', 'alert')) then
	
		if args[3] == nil then
			campbuddy.settings.playsound = not campbuddy.settings.playsound;
			PPrint('sound is '..tostring(campbuddy.settings.playsound));
		elseif helpers.IsNum(args[3]) then
			local num = tonumber(args[3])
			if (num <= 0) or (num > 7) then
				PPrint('Choose alert 1-7.');
			else
				campbuddy.settings.sound = ('sound0'..args[3]..'.wav')
				PPrint('Alert changed to '..args[3]);
			end
		end
		if (campbuddy.settings.playsound == true) then
			ashita.misc.play_sound(addon.path:append('\\sounds\\'):append(campbuddy.settings.sound));
		end
		return;
--[[	Move the active timers display	]]--
	elseif (args[2]:any('move', 'pos')) then
	
		if (args[3] == nil or args[4] == nil) then
			PPrint('Unable to move timers; Missing parameters (Need X Y)');
		else
			campbuddy.settings.font.position_x = tonumber(args[3]);
			campbuddy.settings.font.position_y = tonumber(args[4]);
			
			-- Reapply the font settings..
			if (campbuddy.font ~= nil) then
				campbuddy.font:apply(campbuddy.settings.font);
			end
			
			PPrint('Position set to '..campbuddy.font.position_x..' '..campbuddy.font.position_y);
		end
		return;
--[[	Resize the active timers display	]]--
	elseif (args[2]:any('size')) then
	
		if (args[3] == nil) then
			PPrint('Unable to resize timers; Missing parameters (Needs a size)');
		else
			campbuddy.settings.font.font_height = tonumber(args[3]);
			
			-- Reapply the font settings..
			if (campbuddy.font ~= nil) then
				campbuddy.font:apply(campbuddy.settings.font);
			end

			
			PPrint('Size set to '..campbuddy.font.font_height);
		end
		return;
--[[	Recolor the active timers font	]]--
	elseif (args[2]:any('color')) then
	
		if (#args ~= 6) then
			PPrint('Missing values. Expected: /cbud color <a> <r> <g> <b>');
		elseif (args[3] == nil or args[4] == nil or args[5] == nil or args[6] == nil) or (not helpers.IsNum(args[3]) or not helpers.IsNum(args[4]) or not helpers.IsNum(args[5]) or not helpers.IsNum(args[6])) then
			PPrint('Invalid color value. Expected: /cbud color <a> <r> <g> <b>');
			PPrint('a (0-128) r,g,b (0-255)');
		else
			local a = args[3]:num_or(128);
			local r = args[4]:num_or(255);
			local g = args[5]:num_or(255);
			local b = args[6]:num_or(255);
			argb = string.format('%d, %d, %d, %d', a, r, g, b);
			campbuddy.settings.font.color = math.d3dcolor(a, r, g, b);
			hex = helpers.decimalToHex(campbuddy.settings.font.color)
			PPrint('Color hex set to 0x'..hex..' (Use this value in the settings)');
			PPrint('Color argb set to '..argb);
			
			-- Reapply the font settings..
			if (campbuddy.font ~= nil) then
				campbuddy.font:apply(campbuddy.settings.font);
			end
		end
		return;
--[[	Toggle background visibility	]]--
	elseif (args[2]:any('bg', 'background')) then
	
		campbuddy.settings.font.background.visible = not campbuddy.settings.font.background.visible;
		
		-- Reapply the font settings..
		if (campbuddy.font ~= nil) then
			campbuddy.font:apply(campbuddy.settings.font);
		end
		
		PPrint('Background set to '..tostring(campbuddy.font.background.visible));
		return;
	elseif (args[2] == 'hide') then
		campbuddy.settings.font.visible = not campbuddy.settings.font.visible;
		
		-- Reapply the font settings..
		if (campbuddy.font ~= nil) then
			campbuddy.font:apply(campbuddy.settings.font);
		end
		
		PPrint('Visible set to '..tonumber(campbuddy.font.visible));
		return;
	--[[	Print current settings	]]--
	elseif (args[2]:any('info')) then
		print_info();
		return;
	end
	print_help(true);
end;

	--[[	Print a list of commands	]]--
commands.help = function(args)
	print_help(false);
end;

return commands;