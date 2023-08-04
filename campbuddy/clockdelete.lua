local clockdelete = {};

--[[	remove timers ]]--

clockdelete.remove_countdowm = function(s)

	-- Stop/Remove clocks.countdown timer..
	if s == 'ALL' then
		for i=1,#clocks.countdown do
			clocks.countdown[i].time = 0;
		end
		clocks.iscountdown = T{};
	else
		for i=1,#clocks.countdown do
			if (clocks.countdown[i].label == s) then
				clocks.countdown[i].time = 0;
			end
			if clocks.iscountdown[i] == s then
				table.remove(clocks.iscountdown, i)
			end
		end

	end
end
clockdelete.remove_countup = function(s)

	-- Stop/Remove clocks.countup timer..
	if s == 'ALL' then
		for i=1,#clocks.countup do
			clocks.countup[i].eTime = -1;
		end
	else
		for i=1,#clocks.countup do
			if (clocks.countup[i].label == s) then
				clocks.countup[i].eTime = -1;
			end
		end
	end
end

return clockdelete;