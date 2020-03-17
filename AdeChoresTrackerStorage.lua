local _, ChoresTrackerStorage = ...;

_G["ChoresTrackerStorage"] = ChoresTrackerStorage;

local min_level = 120;

function ChoresTrackerStorage:InitDB(self)
	local t = {};
	t.alts = 0;
	t.data = {};
	return t;
end

function ChoresTrackerStorage:Purge()
	AdeChoresTrackerDB = self:InitDB();
end

local function round(num)
	if ((num % 1) < 0.5) then
	   return math.floor(num)
	else
	   return math.ceil(num)
	end
 end

local function GetAzeriteInformation()
	local info = {
		level = 0,
		current = 0,
		next_level = 0,
		percentage = 0,
	}

	local location = C_AzeriteItem.FindActiveAzeriteItem()

	if (location) then
		info.level = C_AzeriteItem.GetPowerLevel(location)
		info.current, info.next_level = C_AzeriteItem.GetAzeriteItemXPInfo(location)
		info.percentage = round((info.current) * 100 / (info.next_level))
	end

	return info
end

local function GetSealsBought()
	local seals_bought = 0

	local gold_1 = IsQuestFlaggedCompleted(52834)
	if gold_1 then seals_bought = seals_bought + 1 end
	local gold_2 = IsQuestFlaggedCompleted(52838)
	if gold_2 then seals_bought = seals_bought + 1 end
	local resources_1 = IsQuestFlaggedCompleted(52837)
	if resources_1 then seals_bought = seals_bought + 1 end
	local resources_2 = IsQuestFlaggedCompleted(52840)
	if resources_2 then seals_bought = seals_bought + 1 end
	local marks_1 = IsQuestFlaggedCompleted(52835)
	if marks_1 then seals_bought = seals_bought + 1 end
	local marks_2 = IsQuestFlaggedCompleted(52839)
	if marks_2 then seals_bought = seals_bought + 1 end

	return seals_bought
end

local function GetWorldBoss()
	local worldbossquests = {
		[55466] = "Vuk'laz the Earthbreaker",
	}

	for k,v in pairs(worldbossquests)do
		if IsQuestFlaggedCompleted(k) then
			return v
		end
	end

	return "-"
end

local function GetConquestCap()
	local CONQUEST_QUESTLINE_ID = 782;
	local currentQuestID = QuestUtils_GetCurrentQuestLineQuest(CONQUEST_QUESTLINE_ID);

	-- if not on a current quest that means all caught up for this week
	if currentQuestID == 0 then
		return 0, 0, 0;
	end

	if not HaveQuestData(currentQuestID) then
		return 0, 0, nil;
	end

	local objectives = C_QuestLog.GetQuestObjectives(currentQuestID);
	if not objectives or not objectives[1] then
		return 0, 0, nil;
	end

	return objectives[1].numFulfilled, objectives[1].numRequired, currentQuestID;
end

function ChoresTrackerStorage:CollectData()
	if UnitLevel('player') < min_level then return end;

	-- this is an awful hack that will probably have some unforeseen consequences,
	-- but Blizzard fucked something up with systems on logout, so let's see how it
	-- goes.
	_, i = GetAverageItemLevel()
	if i == 0 then return end;

	local dungeon = nil;
	local level = nil;
	local depleted = false;
	local vessels = 0

	C_MythicPlus.RequestRewards();

	-- find keystone
	local keystone_found = false;
	for container=BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(container)
		for slot=1, slots do
			local _, _, _, _, _, _, slotLink, _, _, slotItemID = GetContainerItemInfo(container, slot)

			--	might as well check if the item is a vessel of horrific vision
			if slotItemID == 173363 then
				vessels = vessels + 1
			end
			if slotItemID == 158923 then
				local itemString = slotLink:match("|Hkeystone:([0-9:]+)|h(%b[])|h")
				local info = { strsplit(":", itemString) }
				dungeon = tonumber(info[2])
				if not dungeon then dungeon = nil end
				level = tonumber(info[3])
				if not level then level = nil end
				expire = tonumber(info[4])
				keystone_found = true;
			end
		end
	end

	if not keystone_found then
		dungeon = "Unknown";
		level = "?"
	end

	local saves = GetNumSavedInstances();
	local lfr_difficulty = 17
	local normal_difficulty = 14
	local heroic_difficulty = 15
	local mythic_difficulty = 16
	local nyalotha_lfr = nil
	local nyalotha_normal = nil
	local nyalotha_heroic = nil
	local nyalotha_mythic = nil

	for i = 1, saves do
		local name, _, reset, difficulty, _, _, _, _, _, _, _, killed_bosses = GetSavedInstanceInfo(i);

		-- hack that may not work for other localizations
		-- I can't find any reference to the full name in the API, but the saved info returns the full name
		local nyalotha_lfg_name = GetLFGDungeonInfo(2033)
		if name == nyalotha_lfg_name and reset > 0 then -- is it okay to use any Nyalotha id? 2217
			if difficulty == lfr_difficulty then nyalotha_lfr = killed_bosses end
			if difficulty == normal_difficulty then nyalotha_normal = killed_bosses end
			if difficulty == heroic_difficulty then nyalotha_heroic = killed_bosses end
			if difficulty == mythic_difficulty then nyalotha_mythic = killed_bosses end
		end
	end

	local _, _, _, islands, _ = GetQuestObjectiveInfo(C_IslandsQueue.GetIslandsWeeklyQuestID(), 1, false);

	-- Bake the whole return data
	local char_table = {}

	char_table.guid = UnitGUID('player');
	char_table.name = UnitName('player');
	_, char_table.class = UnitClass('player');
	_, char_table.ilevel = GetAverageItemLevel();
	_, char_table.seals = GetCurrencyInfo(1580);
	char_table.seals_bought = GetSealsBought();
	char_table.vessels = vessels;
	_, char_table.coalescing_visions = GetCurrencyInfo(1755);
	char_table.dungeon = dungeon;
	char_table.level = level;
	char_table.highest_mplus = C_MythicPlus.GetWeeklyChestRewardLevel();
	char_table.worldboss = GetWorldBoss();
	char_table.conquest = GetConquestCap();
	char_table.islands =  islands;
	char_table.islands_finished = IsQuestFlaggedCompleted(C_IslandsQueue.GetIslandsWeeklyQuestID());
	_, char_table.residuum = GetCurrencyInfo(1718);
	_, char_table.corrupted_mementos =  GetCurrencyInfo(1719);

	char_table.azerite_neck = GetAzeriteInformation()

	char_table.nyalotha_lfr = nyalotha_lfr;
	char_table.nyalotha_normal = nyalotha_normal;
	char_table.nyalotha_heroic = nyalotha_heroic;
	char_table.nyalotha_mythic = nyalotha_mythic;

	_, char_table.war_resources = GetCurrencyInfo(1560);
	char_table.is_depleted = depleted;
	char_table.expires = self:GetNextWeeklyResetTime();

	-- print(ChoresTracker.inspect(char_table))

	return char_table;
end

function ChoresTrackerStorage:StoreData(data)
	-- This can happen shortly after logging in, the game doesn't know the characters guid yet
	if not data or not data.guid then
		return
	end

	if UnitLevel('player') < min_level then return end;

	local db = AdeChoresTrackerDB;
	local guid = data.guid;

	db.data = db.data or {};

	local update = false;
	for k, v in pairs(db.data) do
		if k == guid then
			update = true;
		end
	end

	if not update then
		db.data[guid] = data;
		db.alts = db.alts + 1;
	else
		local lvl = db.data[guid].artifact_level;
		data.artifact_level = data.artifact_level or lvl;
		db.data[guid] = data;
	end
end