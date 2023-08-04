local data = {};

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

data.GetIdForMatch = function()

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

return data;