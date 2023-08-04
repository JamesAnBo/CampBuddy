local helpers = {};

helpers.args_iterator = function(col)

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

helpers.decimalToHex = function(num)
	
	local num = tonumber(num);
	
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


helpers.IsNum = function(str)

	-- Is str a number..
	return not (str == "" or str:find("%D"))
end

helpers.all_trim = function(str)

	-- Return str without spaces..
   return str:gsub("%s+", "")
end

helpers.tableHasKey = function(table,key)

	-- Does table have key..
    return table[key] ~= nil
	
end

helpers.formatTime = function(sec)
	
	-- Return time in H:M:S format..
	local h = sec / 3600;
	local m = (sec % 3600) / 60;
	local s = ((sec % 3600) % 60);
	
	return string.format('%02d:%02d:%02d', h, m, s);
	
end

helpers.do_tables_match = function( a, b )

	-- Is table 'a' and table 'b' are the same..
    return table.concat(a) == table.concat(b)
end

return helpers;