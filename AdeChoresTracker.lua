local _, ChoresTracker = ...;

_G["ChoresTracker"] = ChoresTracker;

-- Shamelessly copied from Method's Alt Manager and heavily modified afterwards.
-- Original comments below:
--
-- Made by: Qooning - Tarren Mill <Method>, 2017-2019
-- updates for Bfa by: Kabootzey - Tarren Mill <Ended Careers>, 2018
-- Last edit: 07/09/2019

local Dialog = LibStub("LibDialog-1.0")

local sizey = 315;
local instances_y_add = 85;
local xoffset = 0;
local yoffset = 150;
local alpha = 1;
local addon = "AdeChoresTracker";
local numel = table.getn;

local per_alt_x = 120;
local ilvl_text_size = 8;
local remove_button_size = 12;

local min_x_size = 300;

local name_label = "" -- Name
local mythic_done_label = "Highest M+ done"
local mythic_keystone_label = "Keystone"
local seals_owned_label = "Seals owned"
local seals_bought_label = "Seals obtained"
local vessels_of_horrific_visions_label = "Vessels"
local coalescing_visions_label = "Coalescing Visions"
local mementos_label = "Mementos"
local resources_label = "War Resources"
local worldboss_label = "Worldboss"
local conquest_label = "Conquest"
local islands_label = "Islands"
local residuum_label = "Residuum"

local VERSION = "1.0.0"

local dungeons = {
	[244] = "AD",
	[245] = "FH",
	[246] = "TD",
	[247] = "ML",
	[248] = "WCM",
	[249] = "KR",
	[250] = "Seth",
	[251] = "UR",
	[252] = "SotS",
	[353] = "SoB",
	[369] = "Mech:Junk",
	[370] = "Mech:Shop",
 };

function ChoresTracker:DebugData()
	-- local ms = C_AzeriteEssence.GetEssences()
	-- print(ChoresTracker.inspect(ms))
end

local function spairs(t, order)
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end

	if order then
		table.sort(keys, function(a,b) return order(t, a, b) end)
	else
		table.sort(keys)
	end

	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

local function true_numel(t)
	local c = 0
	for k, v in pairs(t) do c = c + 1 end
	return c
end

SLASH_CHORESTRACKER1 = "/act";
function SlashCmdList.CHORESTRACKER(cmd, editbox)
	local rqst, arg = strsplit(' ', cmd)
	if rqst == "help" then
		print("Chores Tracker help:")
		print("   \"/alts purge\" to remove all stored data.")
		print("   \"/alts remove name\" to remove characters by name.")
	elseif rqst == "purge" then
		ChoresTrackerStorage:Purge();
	elseif rqst == "remove" then
		ChoresTracker:RemoveCharactersByName(arg)
	elseif rqst == "debug" then
		ChoresTracker:DebugData()
	else
		ChoresTracker:ShowInterface();
	end
end

do
	local main_frame = CreateFrame("frame", "ChoresTrackerFrame", UIParent);
	ChoresTracker.main_frame = main_frame;
	main_frame:SetFrameStrata("MEDIUM");
	main_frame.background = main_frame:CreateTexture(nil, "BACKGROUND");
	main_frame.background:SetAllPoints();
	main_frame.background:SetDrawLayer("ARTWORK", 1);
	main_frame.background:SetColorTexture(0, 0, 0, 0.5);

	-- Set frame position
	main_frame:ClearAllPoints();
	main_frame:SetPoint("CENTER", UIParent, "CENTER", xoffset, yoffset);

	main_frame:RegisterEvent("ADDON_LOADED");
	main_frame:RegisterEvent("PLAYER_LOGIN");
	main_frame:RegisterEvent("PLAYER_LOGOUT");
	main_frame:RegisterEvent("QUEST_TURNED_IN");
	main_frame:RegisterEvent("BAG_UPDATE_DELAYED");
	main_frame:RegisterEvent("ARTIFACT_XP_UPDATE");
	main_frame:RegisterEvent("CHAT_MSG_CURRENCY");
	main_frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
	main_frame:RegisterEvent("PLAYER_LEAVING_WORLD");

	main_frame:SetScript("OnEvent", function(self, ...)
		local event, loaded = ...;
		if event == "ADDON_LOADED" then
			if addon == loaded then
			ChoresTracker:OnLoad();
			end
		end
		if event == "PLAYER_LOGIN" then
			ChoresTracker:OnLogin();
		end
		if event == "PLAYER_LEAVING_WORLD" or event == "ARTIFACT_XP_UPDATE" then
			local data = ChoresTrackerStorage:CollectData();
			ChoresTracker:StoreData(data);
		end
		if (event == "BAG_UPDATE_DELAYED" or event == "QUEST_TURNED_IN" or event == "CHAT_MSG_CURRENCY" or event == "CURRENCY_DISPLAY_UPDATE") and ChoresTracker.addon_loaded then
			local data = ChoresTrackerStorage:CollectData();
			ChoresTracker:StoreData(data);
		end
	end)

	main_frame:Hide();
end

function ChoresTracker:CalculateXSizeNoGuidCheck()
	local alts = AdeChoresTrackerDB.alts;
	return max((alts + 1) * per_alt_x, min_x_size)
end

function ChoresTracker:CalculateXSize()
	return self:CalculateXSizeNoGuidCheck()
end

-- because of guid...
function ChoresTracker:OnLogin()
	self:ValidateReset();
	self:StoreData(ChoresTrackerStorage:CollectData());

	self.main_frame:SetSize(self:CalculateXSize(), sizey);
	self.main_frame.background:SetAllPoints();

	-- Create menus
	ChoresTracker:CreateContent();
	ChoresTracker:MakeTopBottomTextures(self.main_frame);
	ChoresTracker:MakeBorder(self.main_frame, 5);
end

function ChoresTracker:OnLoad()
	self.main_frame:UnregisterEvent("ADDON_LOADED");

	AdeChoresTrackerDB = AdeChoresTrackerDB or ChoresTrackerStorage:InitDB();

	if AdeChoresTrackerDB.alts ~= true_numel(AdeChoresTrackerDB.data) then
		print("Altcount inconsistent, using", true_numel(AdeChoresTrackerDB.data))
		AdeChoresTrackerDB.alts = true_numel(AdeChoresTrackerDB.data)
	end

	self.addon_loaded = true

	C_MythicPlus.RequestRewards();
	C_MythicPlus.RequestCurrentAffixes();
	C_MythicPlus.RequestMapInfo();

	for k,v in pairs(dungeons) do
		C_MythicPlus.RequestMapInfo(k);
	end
end

function ChoresTracker:CreateFontFrame(parent, x_size, height, relative_to, y_offset, label, justify)
	local f = CreateFrame("Button", nil, parent);
	f:SetSize(x_size, height);
	f:SetNormalFontObject(GameFontHighlightSmall)
	f:SetText(label)
	f:SetPoint("TOPLEFT", relative_to, "TOPLEFT", 0, y_offset);
	f:GetFontString():SetJustifyH(justify);
	f:GetFontString():SetJustifyV("CENTER");
	f:SetPushedTextOffset(0, 0);
	f:GetFontString():SetWidth(120)
	f:GetFontString():SetHeight(20)

	return f;
end

function ChoresTracker:Keyset()
	local keyset = {}
	if AdeChoresTrackerDB and AdeChoresTrackerDB.data then
		for k in pairs(AdeChoresTrackerDB.data) do
			table.insert(keyset, k)
		end
	end
	return keyset
end

function ChoresTracker:ValidateReset()
	local db = AdeChoresTrackerDB
	if not db then return end;
	if not db.data then return end;

	local keyset = {}
	for k in pairs(db.data) do
		table.insert(keyset, k)
	end

	for alt = 1, db.alts do
		local expiry = db.data[keyset[alt]].expires or 0;
		local char_table = db.data[keyset[alt]];
		if time() > expiry then
			char_table.seals_bought = 0;
			char_table.dungeon = "Unknown";
			char_table.level = "?";
			char_table.highest_mplus = 0;
			char_table.is_depleted = false;
			char_table.expires = self:GetNextWeeklyResetTime();
			char_table.worldboss = "-";

			char_table.islands = 0;
			char_table.islands_finished = false;

			char_table.conquest = 0;

			char_table.nyalotha_normal = 0;
			char_table.nyalotha_heroic = 0;
			char_table.nyalotha_mythic = 0;
		end
	end
end

function ChoresTracker:RemoveCharactersByName(name)
	local db = AdeChoresTrackerDB;

	local indices = {};
	for guid, data in pairs(db.data) do
		if db.data[guid].name == name then
			indices[#indices+1] = guid
		end
	end

	db.alts = db.alts - #indices;
	for i = 1,#indices do
		db.data[indices[i]] = nil
	end

	print("Found " .. (#indices) .. " characters by the name of " .. name)
	print("Please reload ui to update the displayed info.")
end

function ChoresTracker:RemoveCharacterByGuid(index)
	local db = AdeChoresTrackerDB;

	if db.data[index] == nil then return end

	local name = db.data[index].name
	Dialog:Register("ChoresTrackerRemoveCharacterDialog", {
		text = "Are you sure you want to remove " .. name .. " from the list?",
		width = 500,
		on_show = function(self, data)
		end,
		buttons = {
			{ text = "Delete",
			  on_click = function()
					if db.data[index] == nil then return end
					db.alts = db.alts - 1;
					db.data[index] = nil

					self.main_frame:SetSize(self:CalculateXSizeNoGuidCheck(), sizey);
					if self.main_frame.alt_columns ~= nil then
						-- Hide the last col
						-- find the correct frame to hide
						local count = #self.main_frame.alt_columns
						for j = 0,count-1 do
							if self.main_frame.alt_columns[count-j]:IsShown() then
								self.main_frame.alt_columns[count-j]:Hide()
								break
							end
						end
						-- and hide the remove button
						if self.main_frame.remove_buttons ~= nil and self.main_frame.remove_buttons[index] ~= nil then
							self.main_frame.remove_buttons[index]:Hide()
						end
					end
					self:UpdateStrings()
				end},
			{ text = "Cancel", }
		},
		show_while_dead = true,
		hide_on_escape = true,
	})
	if Dialog:ActiveDialog("ChoresTrackerRemoveCharacterDialog") then
		Dialog:Dismiss("ChoresTrackerRemoveCharacterDialog")
	end
	Dialog:Spawn("ChoresTrackerRemoveCharacterDialog", {string = string})
end

function ChoresTracker:StoreData(data)
	if not self.addon_loaded then
		return
	end

	ChoresTrackerStorage:StoreData(data)
end

function ChoresTracker:UpdateStrings()
	local font_height = 20;
	local db = AdeChoresTrackerDB;

	local keyset = {}
	for k in pairs(db.data) do
		table.insert(keyset, k)
	end

	self.main_frame.alt_columns = self.main_frame.alt_columns or {};

	local alt = 0
	for alt_guid, alt_data in spairs(db.data, function(t, a, b) return t[a].ilevel > t[b].ilevel end) do
		alt = alt + 1

		-- create the frame to which all the fontstrings anchor
		local anchor_frame = self.main_frame.alt_columns[alt] or CreateFrame("Button", nil, self.main_frame);

		if not self.main_frame.alt_columns[alt] then
			self.main_frame.alt_columns[alt] = anchor_frame;
			self.main_frame.alt_columns[alt].guid = alt_guid
			anchor_frame:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", per_alt_x * alt, -1);
		end
		anchor_frame:SetSize(per_alt_x, sizey);

		-- init table for fontstring storage
		self.main_frame.alt_columns[alt].label_columns = self.main_frame.alt_columns[alt].label_columns or {};
		local label_columns = self.main_frame.alt_columns[alt].label_columns;

		-- create / fill fontstrings
		local i = 1;
		for column_iden, column in spairs(self.columns_table, function(t, a, b) return t[a].order < t[b].order end) do
			-- only display data with values
			if type(column.data) == "function" then
				local current_row = label_columns[i] or self:CreateFontFrame(
					anchor_frame,
					per_alt_x,
					column.font_height or font_height,
					anchor_frame,
					-(i - 1) * font_height,
					column.data(alt_data),
					"CENTER"
				);

				-- insert it into storage if just created
				if not self.main_frame.alt_columns[alt].label_columns[i] then
					self.main_frame.alt_columns[alt].label_columns[i] = current_row;
				end
				if column.color then
					local color = column.color(alt_data)
					current_row:GetFontString():SetTextColor(color.r, color.g, color.b, 1);
				end
				current_row:SetText(column.data(alt_data))
				if column.font then
					current_row:GetFontString():SetFont(column.font, ilvl_text_size)
				end
				if column.justify then
					current_row:GetFontString():SetJustifyV(column.justify);
				end
				if column.remove_button ~= nil then
					self.main_frame.remove_buttons = self.main_frame.remove_buttons or {}
					local extra = self.main_frame.remove_buttons[alt_data.guid] or column.remove_button(alt_data)
					if self.main_frame.remove_buttons[alt_data.guid] == nil then
						self.main_frame.remove_buttons[alt_data.guid] = extra
					end
					extra:SetParent(current_row)
					extra:SetPoint("TOPRIGHT", current_row, "TOPRIGHT", -18, 2 );
					extra:SetPoint("BOTTOMRIGHT", current_row, "TOPRIGHT", -18, -remove_button_size + 2);
					extra:SetFrameLevel(current_row:GetFrameLevel() + 1)
					extra:Show();
				end
			end
			i = i + 1
		end
	end
end

function ChoresTracker:UpdateInstanceStrings(my_rows, font_height)
	self.instances_unroll.alt_columns = self.instances_unroll.alt_columns or {};
	local alt = 0
	local db = AdeChoresTrackerDB;
	for alt_guid, alt_data in spairs(db.data, function(t, a, b) return t[a].ilevel > t[b].ilevel end) do
		alt = alt + 1

		-- create the frame to which all the fontstrings anchor
		local anchor_frame = self.instances_unroll.alt_columns[alt] or CreateFrame("Button", nil, self.main_frame.alt_columns[alt]);
		if not self.instances_unroll.alt_columns[alt] then
			self.instances_unroll.alt_columns[alt] = anchor_frame;
		end
		anchor_frame:SetPoint("TOPLEFT", self.instances_unroll.unroll_frame, "TOPLEFT", per_alt_x * alt, -1);
		anchor_frame:SetSize(per_alt_x, instances_y_add);

		-- init table for fontstring storage
		self.instances_unroll.alt_columns[alt].label_columns = self.instances_unroll.alt_columns[alt].label_columns or {};
		local label_columns = self.instances_unroll.alt_columns[alt].label_columns;

		-- create / fill fontstrings
		local i = 1;
		for column_iden, column in spairs(my_rows, function(t, a, b) return t[a].order < t[b].order end) do
			local current_row = label_columns[i] or self:CreateFontFrame(anchor_frame, per_alt_x, column.font_height or font_height, anchor_frame, -(i - 1) * font_height, column.data(alt_data), "CENTER");
			-- insert it into storage if just created
			if not self.instances_unroll.alt_columns[alt].label_columns[i] then
				self.instances_unroll.alt_columns[alt].label_columns[i] = current_row;
			end
			current_row:SetText(column.data(alt_data)) -- fills data
			i = i + 1
		end

		-- hotfix visibility
		if anchor_frame:GetParent():IsShown() then anchor_frame:Show() else anchor_frame:Hide() end
	end
end

function ChoresTracker:CloseInstancesUnroll()
	-- do rollup
	self.main_frame:SetSize(self:CalculateXSizeNoGuidCheck(), sizey);
	self.main_frame.background:SetAllPoints();
	self.instances_unroll.unroll_frame:Hide();
	for k, v in pairs(self.instances_unroll.alt_columns) do
		v:Hide()
	end
end

function ChoresTracker:CreateContent()

	-- Close button
	self.main_frame.closeButton = CreateFrame("Button", "CloseButton", self.main_frame, "UIPanelCloseButton");
	self.main_frame.closeButton:ClearAllPoints()
	self.main_frame.closeButton:SetPoint("BOTTOMRIGHT", self.main_frame, "TOPRIGHT", -10, -2);
	self.main_frame.closeButton:SetScript("OnClick", function() ChoresTracker:HideInterface(); end);
	--self.main_frame.closeButton:SetSize(32, h);

	local column_table = {
		name = {
			order = 1,
			label = name_label,
			data = function(alt_data) return alt_data.name end,
			color = function(alt_data) return RAID_CLASS_COLORS[alt_data.class] end,
			remove_button = function(alt_data)
				return self:CreateRemoveButton(function() ChoresTracker:RemoveCharacterByGuid(alt_data.guid) end)
			end
		},
		ilevel = {
			order = 2,
			data = function(alt_data)
				return string.format(
					"%.2f - %d (%d%%)",
					alt_data.ilevel or 0,
					alt_data.azerite_neck.level or 0,
					alt_data.azerite_neck.percentage or 0
				)
			end,
			justify = "TOP",
			font = "Fonts\\FRIZQT__.TTF"
		},
		mplus = {
			order = 3,
			label = mythic_done_label,
			data = function(alt_data) return tostring(alt_data.highest_mplus) end,
		},
		keystone = {
			order = 4,
			label = mythic_keystone_label,
			data = function(alt_data) local depleted_string = alt_data.is_depleted and " (D)" or ""; return (dungeons[alt_data.dungeon] or alt_data.dungeon) .. " +" .. tostring(alt_data.level) .. depleted_string; end,
		},
		seals_owned = {
			order = 5,
			label = seals_owned_label,
			data = function(alt_data) return tostring(alt_data.seals) end,
		},
		seals_bought = {
			order = 6,
			label = seals_bought_label,
			data = function(alt_data) return tostring(alt_data.seals_bought) end,
		},
		fake_just_for_offset = {
			order = 6.1,
			label = "",
			data = function(alt_data) return " " end,
		},
		vessels = {
			order = 6.5,
			label = vessels_of_horrific_visions_label,
			data = function(alt_data) return tostring(alt_data.vessels or "0") end,
		},
		coalascing_visions = {
			order = 6.6,
			label = coalescing_visions_label,
			data = function(alt_data) return tostring(alt_data.coalescing_visions or "0") end,
		},
		corrupted_mementos = {
			order = 6.7,
			label = mementos_label,
			data = function(alt_data) return tostring(alt_data.corrupted_mementos or "0") end,
		},
		residuum = {
			order = 7,
			 label = residuum_label,
			data = function(alt_data) return alt_data.residuum and tostring(alt_data.residuum) or "0" end,
		},
		conquest_cap = {
			order = 8,
			label = conquest_label,
			data = function(alt_data) return (alt_data.conquest and tostring(alt_data.conquest) or "?")  .. "/" .. "500"  end,
		},
		order_resources = {
			order = 9,
			label = resources_label,
			data = function(alt_data) return alt_data.order_resources and tostring(alt_data.order_resources) or "0" end,
		},
		worldbosses = {
			order = 10,
			label = worldboss_label,
			data = function(alt_data) return alt_data.worldboss or "?" end,
		},
		islands = {
			order = 11,
			label = islands_label,
			data = function(alt_data) return (alt_data.islands_finished and "Capped") or ((alt_data.islands and tostring(alt_data.islands)) or "?") .. "/ 36K"  end,
		},
		nyalotha = {
			order = 13,
			label = "Ny'alotha",
			data = function(alt_data) return self:MakeRaidString(
				alt_data.nyalotha_normal,
				alt_data.nyalotha_heroic,
				alt_data.nyalotha_mythic)
			end
		}
	}

	self.columns_table = column_table;

	-- create labels and unrolls
	local font_height = 20;
	local label_column = self.main_frame.label_column or CreateFrame("Button", nil, self.main_frame);
	if not self.main_frame.label_column then self.main_frame.label_column = label_column; end
	label_column:SetSize(per_alt_x, sizey);
	label_column:SetPoint("TOPLEFT", self.main_frame, "TOPLEFT", 4, -1);

	local i = 1;
	for row_iden, row in spairs(self.columns_table, function(t, a, b) return t[a].order < t[b].order end) do
		if row.label then
			local label_row = self:CreateFontFrame(self.main_frame, per_alt_x, font_height, label_column, -(i-1)*font_height, row.label~="" and row.label..":" or " ", "RIGHT");
			self.main_frame.lowest_point = -(i-1)*font_height;
		end
		if row.data == "unroll" then
			-- create a button that will unroll it
			local unroll_button = CreateFrame("Button", "UnrollButton", self.main_frame, "UIPanelButtonTemplate");
			unroll_button:SetText(row.name);
			--unroll_button:SetFrameStrata("HIGH");
			unroll_button:SetFrameLevel(self.main_frame:GetFrameLevel() + 2)
			unroll_button:SetSize(unroll_button:GetTextWidth() + 20, 25);
			unroll_button:SetPoint("BOTTOMRIGHT", self.main_frame, "TOPLEFT", 4 + per_alt_x, -(i-1)*font_height-10);
			unroll_button:SetScript("OnClick", function() row.unroll_function(unroll_button, row.rows) end);
			self.main_frame.lowest_point = -(i-1)*font_height-10;
		end
		i = i + 1
	end

end

function ChoresTracker:MakeRaidString(normal, heroic, mythic)
	if not normal then normal = 0 end
	if not heroic then heroic = 0 end
	if not mythic then mythic = 0 end

	local string = ""
	if mythic > 0 then string = string .. tostring(mythic) .. "M" end
	if heroic > 0 and mythic > 0 then string = string .. "-" end
	if heroic > 0 then string = string .. tostring(heroic) .. "H" end
	if normal > 0 and (mythic > 0 or heroic > 0) then string = string .. "-" end
	if normal > 0 then string = string .. tostring(normal) .. "N" end
	return string == "" and "-" or string
end

function ChoresTracker:HideInterface()
	self.main_frame:Hide();
end

function ChoresTracker:ShowInterface()
	self.main_frame:Show();
	self:StoreData(self:CollectData())
	self:UpdateStrings();
end

function ChoresTracker:CreateRemoveButton(func)
	local frame = CreateFrame("Button", nil, nil)
	frame:ClearAllPoints()
	frame:SetScript("OnClick", function() func() end);
	self:MakeRemoveTexture(frame)
	frame:SetWidth(remove_button_size)
	return frame
end

function ChoresTracker:MakeRemoveTexture(frame)
	if frame.remove_tex == nil then
		frame.remove_tex = frame:CreateTexture(nil, "BACKGROUND")
		frame.remove_tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
		frame.remove_tex:SetAllPoints()
		frame.remove_tex:Show();
	end
	return frame
end

function ChoresTracker:MakeTopBottomTextures(frame)
	if frame.bottomPanel == nil then
		frame.bottomPanel = frame:CreateTexture(nil);
	end
	if frame.topPanel == nil then
		frame.topPanel = CreateFrame("Frame", "ChoresTrackerTopPanel", frame);
		frame.topPanelTex = frame.topPanel:CreateTexture(nil, "BACKGROUND");
		frame.topPanelTex:SetAllPoints();
		frame.topPanelTex:SetDrawLayer("ARTWORK", -5);
		frame.topPanelTex:SetColorTexture(0, 0, 0, 0.7);

		frame.topPanelString = frame.topPanel:CreateFontString("Method name");
		frame.topPanelString:SetFont("Fonts\\FRIZQT__.TTF", 20)
		frame.topPanelString:SetTextColor(1, 1, 1, 1);
		frame.topPanelString:SetJustifyH("CENTER")
		frame.topPanelString:SetJustifyV("CENTER")
		frame.topPanelString:SetWidth(260)
		frame.topPanelString:SetHeight(20)
		frame.topPanelString:SetText("Chores Tracker");
		frame.topPanelString:ClearAllPoints();
		frame.topPanelString:SetPoint("CENTER", frame.topPanel, "CENTER", 0, 0);
		frame.topPanelString:Show();
	end

	frame.bottomPanel:SetColorTexture(0, 0, 0, 0.7);
	frame.bottomPanel:ClearAllPoints();
	frame.bottomPanel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0);
	frame.bottomPanel:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0);
	frame.bottomPanel:SetSize(frame:GetWidth(), 30);
	frame.bottomPanel:SetDrawLayer("ARTWORK", 7);

	frame.topPanel:ClearAllPoints();
	frame.topPanel:SetSize(frame:GetWidth(), 30);
	frame.topPanel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0);
	frame.topPanel:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0);

	frame:SetMovable(true);
	frame.topPanel:EnableMouse(true);
	frame.topPanel:RegisterForDrag("LeftButton");
	frame.topPanel:SetScript("OnDragStart", function(self,button)
		frame:SetMovable(true);
		frame:StartMoving();
	end);
	frame.topPanel:SetScript("OnDragStop", function(self,button)
		frame:StopMovingOrSizing();
		frame:SetMovable(false);
	end);
end

function ChoresTracker:MakeBorderPart(frame, x, y, xoff, yoff, part)
	if part == nil then
		part = frame:CreateTexture(nil);
	end
	part:SetTexture(0, 0, 0, 1);
	part:ClearAllPoints();
	part:SetPoint("TOPLEFT", frame, "TOPLEFT", xoff, yoff);
	part:SetSize(x, y);
	part:SetDrawLayer("ARTWORK", 7);
	return part;
end

function ChoresTracker:MakeBorder(frame, size)
	if size == 0 then
		return;
	end
	frame.borderTop = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, 0, frame.borderTop); -- top
	frame.borderLeft = self:MakeBorderPart(frame, size, frame:GetHeight(), 0, 0, frame.borderLeft); -- left
	frame.borderBottom = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, -frame:GetHeight() + size, frame.borderBottom); -- bottom
	frame.borderRight = self:MakeBorderPart(frame, size, frame:GetHeight(), frame:GetWidth() - size, 0, frame.borderRight); -- right
end

-- shamelessly stolen from saved instances
function ChoresTracker:GetNextWeeklyResetTime()
	if not self.resetDays then
		local region = self:GetRegion()
		if not region then return nil end
		self.resetDays = {}
		self.resetDays.DLHoffset = 0
		if region == "US" then
			self.resetDays["2"] = true -- tuesday
			-- ensure oceanic servers over the dateline still reset on tues UTC (wed 1/2 AM server)
			self.resetDays.DLHoffset = -3
		elseif region == "EU" then
			self.resetDays["3"] = true -- wednesday
		elseif region == "CN" or region == "KR" or region == "TW" then -- XXX: codes unconfirmed
			self.resetDays["4"] = true -- thursday
		else
			self.resetDays["2"] = true -- tuesday?
		end
	end
	local offset = (self:GetServerOffset() + self.resetDays.DLHoffset) * 3600
	local nightlyReset = self:GetNextDailyResetTime()
	if not nightlyReset then return nil end
	while not self.resetDays[date("%w",nightlyReset+offset)] do
		nightlyReset = nightlyReset + 24 * 3600
	end
	return nightlyReset
end

function ChoresTracker:GetNextDailyResetTime()
	local resettime = GetQuestResetTime()
	if not resettime or resettime <= 0 or -- ticket 43: can fail during startup
		-- also right after a daylight savings rollover, when it returns negative values >.<
		resettime > 24*3600+30 then -- can also be wrong near reset in an instance
		return nil
	end
	if false then -- this should no longer be a problem after the 7.0 reset time changes
		-- ticket 177/191: GetQuestResetTime() is wrong for Oceanic+Brazilian characters in PST instances
		local serverHour, serverMinute = GetGameTime()
		local serverResetTime = (serverHour*3600 + serverMinute*60 + resettime) % 86400 -- GetGameTime of the reported reset
		local diff = serverResetTime - 10800 -- how far from 3AM server
		if math.abs(diff) > 3.5*3600  -- more than 3.5 hours - ignore TZ differences of US continental servers
			and self:GetRegion() == "US" then
			local diffhours = math.floor((diff + 1800)/3600)
			resettime = resettime - diffhours*3600
			if resettime < -900 then -- reset already passed, next reset
				resettime = resettime + 86400
				elseif resettime > 86400+900 then
				resettime = resettime - 86400
			end
		end
	end
	return time() + resettime
end

function ChoresTracker:GetServerOffset()
	local serverDay = C_Calendar.GetDate().weekday - 1 -- 1-based starts on Sun
	local localDay = tonumber(date("%w")) -- 0-based starts on Sun
	local serverHour, serverMinute = GetGameTime()
	local localHour, localMinute = tonumber(date("%H")), tonumber(date("%M"))
	if serverDay == (localDay + 1)%7 then -- server is a day ahead
		serverHour = serverHour + 24
	elseif localDay == (serverDay + 1)%7 then -- local is a day ahead
		localHour = localHour + 24
	end
	local server = serverHour + serverMinute / 60
	local localT = localHour + localMinute / 60
	local offset = floor((server - localT) * 2 + 0.5) / 2
	return offset
end

function ChoresTracker:GetRegion()
	if not self.region then
		local reg
		reg = GetCVar("portal")
		if reg == "public-test" then -- PTR uses US region resets, despite the misleading realm name suffix
			reg = "US"
		end
		if not reg or #reg ~= 2 then
			local gcr = GetCurrentRegion()
			reg = gcr and ({ "US", "KR", "EU", "TW", "CN" })[gcr]
		end
		if not reg or #reg ~= 2 then
			reg = (GetCVar("realmList") or ""):match("^(%a+)%.")
		end
		if not reg or #reg ~= 2 then -- other test realms?
			reg = (GetRealmName() or ""):match("%((%a%a)%)")
		end
		reg = reg and reg:upper()
		if reg and #reg == 2 then
			self.region = reg
		end
	end
	return self.region
end

function ChoresTracker:GetWoWDate()
	local hour = tonumber(date("%H"));
	local day = C_Calendar.GetDate().weekday;
	return day, hour;
end

function ChoresTracker:TimeString(length)
	if length == 0 then
		return "Now";
	end
	if length < 3600 then
		return string.format("%d mins", length / 60);
	end
	if length < 86400 then
		return string.format("%d hrs %d mins", length / 3600, (length % 3600) / 60);
	end
	return string.format("%d days %d hrs", length / 86400, (length % 86400) / 3600);
end
