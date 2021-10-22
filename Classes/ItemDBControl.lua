﻿-- Path of Building
--
-- Class: Item DB
-- Item DB control.
--
--local launch, main = ...

local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local m_max = math.max
local m_floor = math.floor

local sortDropList = { 
	{ label = "按名称排序", sortMode = "NAME" },
	{ label = "按DPS排序", sortMode = "DPS" },
}

local ItemDBClass = newClass("ItemDBControl", "ListControl", function(self, anchor, x, y, width, height, itemsTab, db, dbType)
	self.ListControl(anchor, x, y, width, height, 16, "VERTICAL", false)
	self.itemsTab = itemsTab
	self.db = db
	self.dbType = dbType
	self.dragTargetList = { }
	self.sortControl = { 
		NAME = { key = "name", dir = "ASCEND", func = function(a,b) return a:gsub("^The ","") < b:gsub("^The ","") end },
		DPS = { key = "CombinedDPS", dir = "DESCEND" },
	}
	self.sortMode = "NAME"
	local leagueFlag = { }
	local typeFlag = { }
	for _, item in pairs(db.list) do
		if item.league then
for leagueName in item.league:gmatch(" ?(.+),?") do
				leagueFlag[leagueName] = true
			end
		end
		typeFlag[item.type] = true
	end
	self.leagueList = { }
	for leagueName in pairs(leagueFlag) do
		t_insert(self.leagueList, leagueName)
	end
	table.sort(self.leagueList)
t_insert(self.leagueList, 1, "任意联盟")
t_insert(self.leagueList, 2, "非联盟专属")
	self.typeList = { }
	for type in pairs(typeFlag) do
		t_insert(self.typeList, type)
	end
	table.sort(self.typeList)
	t_insert(self.typeList, 1, "Any type")
	t_insert(self.typeList, 2, "Armour")
	t_insert(self.typeList, 3, "Jewellery")
	t_insert(self.typeList, 4, "One Handed Melee")
	t_insert(self.typeList, 5, "Two Handed Melee")
	self.slotList = { "Any slot", "Weapon 1", "Weapon 2", "Helmet", "Body Armour", "Gloves", "Boots", "Amulet", "Ring", "Belt", "Jewel" }
	
	local baseY = dbType == "RARE" and -22 or -42
	self.controls.slot = new("DropDownControl", {"BOTTOMLEFT",self,"TOPLEFT"}, 0, baseY, 179, 18, self.slotList, function(index, value)
		self.listBuildFlag = true
	end,"slotListCN")
	self.controls.type = new("DropDownControl", {"LEFT",self.controls.slot,"RIGHT"}, 2, 0, 179, 18, self.typeList, function(index, value)
		self.listBuildFlag = true
	end,"typeListCN")
	if dbType == "UNIQUE" then
		self.controls.sort = new("DropDownControl", {"BOTTOMLEFT",self,"TOPLEFT"}, 0, baseY + 20, 179, 18, sortDropList, function(index, value)
			self.sortMode = value.sortMode
			self:BuildSortOrder()
			self.listBuildFlag = true
		end,"sortDropListCN")
		self.controls.league = new("DropDownControl", {"LEFT",self.controls.sort,"RIGHT"}, 2, 0, 179, 18, self.leagueList, function(index, value)
			self.listBuildFlag = true
		end)
	end
self.controls.search = new("EditControl", {"BOTTOMLEFT",self,"TOPLEFT"}, 0, -2, 258, 18, "", "搜索", "%c", 100, function()
		self.listBuildFlag = true
	end)
	self.controls.searchMode = new("DropDownControl", {"LEFT",self.controls.search,"RIGHT"}, 2, 0, 100, 18, { "Anywhere", "Names", "Modifiers" }, function(index, value)
		self.listBuildFlag = true
	end,"searchModeCN")
	self:BuildSortOrder()
	self.listBuildFlag = true
end)

function ItemDBClass:DoesItemMatchFilters(item)
	if self.controls.slot.selIndex > 1 then
		local primarySlot = item:GetPrimarySlot()
		if primarySlot ~= self.slotList[self.controls.slot.selIndex] and primarySlot:gsub(" %d","") ~= self.slotList[self.controls.slot.selIndex] then
			return false
		end
	end
	local typeSel = self.controls.type.selIndex
	if typeSel > 1 then
		if typeSel == 2 then
			if not item.base.armour then
				return false
			end
		elseif typeSel == 3 then
			if not (item.type == "Amulet" or item.type == "Ring" or item.type == "Belt") then
				return false
			end
		elseif typeSel == 4 or typeSel == 5 then
			local weaponInfo = self.itemsTab.build.data.weaponTypeInfo[item.type]
			if not (weaponInfo and weaponInfo.melee and ((typeSel == 4 and weaponInfo.oneHand) or (typeSel == 5 and not weaponInfo.oneHand))) then 
				return false
			end
		elseif item.type ~= self.typeList[typeSel] then
			return false
		end
	end
	if self.dbType == "UNIQUE" and self.controls.league.selIndex > 1 then
		if (self.controls.league.selIndex == 2 and item.league) or (self.controls.league.selIndex > 2 and (not item.league or not item.league:match(self.leagueList[self.controls.league.selIndex]))) then
			return false
		end
	end
	local searchStr = self.controls.search.buf:lower()
	if searchStr:match("%S") then
		local found = false
		local mode = self.controls.searchMode.selIndex
		if mode == 1 or mode == 2 then
			if item.name:lower():find(searchStr, 1, true) then
				found = true
			end
		end
		if mode == 1 or mode == 3 then
			for _, line in pairs(item.enchantModLines) do
				if line.line:lower():find(searchStr, 1, true) then
					found = true
					break
				end
			end
			for _, line in pairs(item.implicitModLines) do
				if line.line:lower():find(searchStr, 1, true) then
					found = true
					break
				end
			end
			for _, line in pairs(item.explicitModLines) do
				if line.line:lower():find(searchStr, 1, true) then
					found = true
					break
				end
			end
			if not found then
				searchStr = searchStr:gsub(" ","")
				for i, mod in ipairs(item.baseModList) do
					if mod.name:lower():find(searchStr, 1, true) then
						found = true
						break
					end
				end
			end
		end
		if not found then
			return false
		end
	end
	return true
end

function ItemDBClass:SetSortMode(sortMode)
	self.sortMode = sortMode
	self:BuildSortOrder()
	self.listBuildFlag = true
end

function ItemDBClass:BuildSortOrder()
	self.sortOrder = wipeTable(self.sortOrder)
	t_insert(self.sortOrder, self.sortControl[self.sortMode])
	if self.controls.sort then
		self.controls.sort:SelByValue(self.sortMode, "sortMode")
	end
end

function ItemDBClass:ListBuilder()
	local list = { }
	for id, item in pairs(self.db.list) do
		if self:DoesItemMatchFilters(item) then
			t_insert(list, item)
		end
	end

	if self.sortMode == "DPS" then
		local start = GetTime()
		local calcFunc, calcBase = self.itemsTab.build.calcsTab:GetMiscCalculator(self.build)
		local baseDPS = calcBase.Minion and calcBase.Minion.CombinedDPS or calcBase.CombinedDPS
		for itemIndex, item in ipairs(list) do
			item.CombinedDPS = 0
			for slotName, slot in pairs(self.itemsTab.slots) do
				if self.itemsTab:IsItemValidForSlot(item, slotName) and not slot.inactive and (not slot.weaponSet or slot.weaponSet == (self.itemsTab.activeItemSet.useSecondWeaponSet and 2 or 1)) then
					local output = calcFunc(item.base.flask and { toggleFlask = item } or { repSlotName = slotName, repItem = item }, { nodeAlloc = true, requirementsGems = true })
					item.CombinedDPS = m_max(item.CombinedDPS, output.Minion and output.Minion.CombinedDPS or output.CombinedDPS)				
				end
			end
			local now = GetTime()
			if now - start > 50 then
				self.defaultText = "^7Sorting... ("..m_floor(itemIndex/#list*100).."%)"
				coroutine.yield()
				start = now
			end
		end
	end

	table.sort(list, function(a, b)
		for _, data in ipairs(self.sortOrder) do
			local aVal = a[data.key]
			local bVal = b[data.key]
			if aVal ~= bVal then
				if data.dir == "DESCEND" then
					if data.func then
						return data.func(bVal, aVal)
					else
						return bVal < aVal
					end
				else
					if data.func then
						return data.func(aVal, bVal)
					else
						return aVal < bVal
					end
				end
			end
		end
	end)

	self.list = list
	self.defaultText = "^7No items found that match those filters."
end

function ItemDBClass:Draw(viewPort)
	if self.itemsTab.build.outputRevision ~= self.listOutputRevision then
		self.listBuildFlag = true
	end
	if self.listBuildFlag then
		self.listBuildFlag = false
		wipeTable(self.list)
		self.listBuilder = coroutine.create(self.ListBuilder)
		self.listOutputRevision = self.itemsTab.build.outputRevision
	end
	if self.listBuilder then
		local res, errMsg = coroutine.resume(self.listBuilder, self)
		if launch.devMode and not res then
			error(errMsg)
		end
		if coroutine.status(self.listBuilder) == "dead" then
			self.listBuilder = nil
		end
	end
	self.ListControl.Draw(self, viewPort)
end

function ItemDBClass:GetRowValue(column, index, item)
	
	if column == 1 and item then
		return colorCodes[item.rarity] .. item.name
	end
end

function ItemDBClass:AddValueTooltip(tooltip, index, item)
	if main.popups[1] then
		tooltip:Clear()
		return
	end
	if tooltip:CheckForUpdate(item, IsKeyDown("SHIFT"), launch.devModeAlt, self.itemsTab.build.outputRevision) then
		self.itemsTab:AddItemTooltip(tooltip, item, nil, true)
	end
end

function ItemDBClass:GetDragValue(index, item)
	return "Item", item
end

function ItemDBClass:OnSelClick(index, item, doubleClick)
	if IsKeyDown("CTRL") then
		-- Add item
		local newItem = new("Item", item.raw)
		newItem:NormaliseQuality()
		self.itemsTab:AddItem(newItem, true)

		-- Equip item if able
		local slotName = newItem:GetPrimarySlot()
		if slotName and self.itemsTab.slots[slotName] then
			if self.itemsTab.slots[slotName].weaponSet == 1 and self.itemsTab.activeItemSet.useSecondWeaponSet then
				-- Redirect to second weapon set
				slotName = slotName .. " Swap"
			end
			if IsKeyDown("SHIFT") then
				-- Redirect to second slot if possible
				local altSlot = slotName:gsub("1","2")
				if self.itemsTab:IsItemValidForSlot(newItem, altSlot) then
					slotName = altSlot
				end
			end
			self.itemsTab.slots[slotName]:SetSelItemId(newItem.id)
		end

		self.itemsTab:PopulateSlots()
		self.itemsTab:AddUndoState()
		self.itemsTab.build.buildFlag = true
	elseif doubleClick then
		self.itemsTab:CreateDisplayItemFromRaw(item.raw, true)
	end
end

function ItemDBClass:OnSelCopy(index, item)
	Copy(item.raw:gsub("\n","\r\n"))
end
