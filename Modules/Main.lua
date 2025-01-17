﻿-- Path of Building
--
-- Module: Main
-- Main module of program.
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_ceil = math.ceil
local m_floor = math.floor
local m_max = math.max
local m_min = math.min
local m_sin = math.sin
local m_cos = math.cos
local m_pi = math.pi

LoadModule("GameVersions")

LoadModule("Modules/Common")
LoadModule("Modules/Data")
LoadModule("Modules/ModTools")
LoadModule("Modules/ItemTools")
LoadModule("Modules/CalcTools")
LoadModule("Modules/PantheonTools")

--[[if launch.devMode then
	for skillName, skill in pairs(data.enchantments.Helmet) do
		for _, mod in ipairs(skill.ENDGAME) do
			local modList, extra = modLib.parseMod(mod)
			if not modList or extra then
				ConPrintf("%s: '%s' '%s'", skillName, mod, extra or "")
			end
		end
	end
end]]

local tempTable1 = { }
local tempTable2 = { }

main = new("ControlHost")

function main:Init()
	self.POESESSID = ""
	self.modes = { }
	self.modes["LIST"] = LoadModule("Modules/BuildList")
	self.modes["BUILD"] = LoadModule("Modules/Build")

	if launch.devMode or GetScriptPath() == GetRuntimePath() then
		-- If running in dev mode or standalone mode, put user data in the script path
		self.userPath = GetScriptPath().."/"
	else
		self.userPath = GetUserPath().."/Path of Building/"
		MakeDir(self.userPath)
	end
	self.defaultBuildPath = self.userPath.."Builds/"
	self.buildPath = self.defaultBuildPath
	MakeDir(self.buildPath)

	if launch.devMode and IsKeyDown("CTRL") then
		--不生成缓存词缀
		self.rebuildModCache = true
	else
		-- Load mod caches
		LoadModule("Data/ModCache", modLib.parseModCache)
	end
	if launch.devMode and IsKeyDown("CTRL") and IsKeyDown("SHIFT") then
		self.allowTreeDownload = true
	end


	self.inputEvents = { }
	self.popups = { }
	self.tooltipLines = { }

	self.gameAccounts = { }

	self.buildSortMode = "NAME"
	self.connectionProtocol = 0
	self.nodePowerTheme = "RED/BLUE"
	self.showThousandsSeparators = true
	self.thousandsSeparator = ","
	self.decimalSeparator = "."
	self.defaultItemAffixQuality = 0.5
	self.showTitlebarName = true
	self.showWarnings = true
	self.slotOnlyTooltips = true

	local ignoreBuild
	if arg[1] then
		buildSites.DownloadBuild(arg[1], nil, function(isSuccess, data)
			if not isSuccess then
				self:SetMode("BUILD", false, data)
			else
				local xmlText = Inflate(common.base64.decode(data:gsub("-","+"):gsub("_","/")))
				self:SetMode("BUILD", false, "Imported Build", xmlText)
				self.newModeChangeToTree = true
			end
		end)
		arg[1] = nil -- Protect against downloading again this session.
		ignoreBuild = true
	end

	if not ignoreBuild then
		self:SetMode("BUILD", false, "Unnamed build")
	end
	self:LoadSettings(ignoreBuild)
	self.tree = { }
	self:LoadTree(latestTreeVersion)

	ConPrintf("Loading item databases...")
	self.uniqueDB = { list = { } }
	for type, typeList in pairs(data.uniques) do
		for _, raw in pairs(typeList) do
			local newItem = new("Item",  "稀 有 度: 传奇\n"..raw)
			if newItem.base then
				newItem:NormaliseQuality()
				self.uniqueDB.list[newItem.name] = newItem
			elseif launch.devMode then
				ConPrintf("Unique DB unrecognised item of type '%s':\n%s", type, raw)
			end
		end
	end
	self.rareDB = { list = { } }
	for _, raw in pairs(data.rares) do
		local newItem = new("Item",  "稀 有 度: 稀有\n"..raw)
		if newItem.base then
			newItem:NormaliseQuality()
			if newItem.crafted then
				if newItem.base.implicit and #newItem.implicitModLines == 0 then
					-- Automatically add implicit
					for line in newItem.base.implicit:gmatch("[^\n]+") do
						t_insert(newItem.implicitModLines, { line = line })
					end
				end
				newItem:Craft()
			end
			self.rareDB.list[newItem.name] = newItem
		elseif launch.devMode then
			ConPrintf("Rare DB unrecognised item:\n%s", raw)
		end
	end
		

	if self.rebuildModCache then
		-- Update mod caches
		local out = io.open("Data/ModCache.lua", "w")
		out:write('local c=...')
		for line, dat in pairs(modLib.parseModCache) do
			if not dat[1] or not dat[1][1] or dat[1][1].name ~= "JewelFunc" then
				out:write('c["', line:gsub("\n","\\n"), '"]={')
				if dat[1] then
					writeLuaTable(out, dat[1])
				else
					out:write('nil')
				end
				if dat[2] then
					out:write(',"', dat[2]:gsub("\n","\\n"), '"}\n')
				else
					out:write(',nil}\n')
				end
			end
		end
		out:close()
	end

	self.sharedItemList = { }
	self.sharedItemSetList = { }

	self.anchorMain = new("Control", nil, 4, 0, 0, 0)
	self.anchorMain.y = function()
		return self.screenH - 4
	end
	self.controls.options = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, 0, 70, 20, "设置", function()
		self:OpenOptionsPopup()
	end)
	--[[
	self.controls.patreon = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 112, 0, 74, 20, "", function()
		OpenURL("https://www.patreon.com/openarl")
	end)]]--
	--self.controls.patreon:SetImage("Assets/patreon_logo.png")
	--self.controls.patreon.tooltipText = "给国际服的原作者捐款赞助！"

self.controls.about = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 228, 0, 70, 20, "关于", function()
		self:OpenAboutPopup()
	end)
self.controls.applyUpdate = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, -24, 140, 20, "^x50E050准备更新", function()
		self:OpenUpdatePopup()
	end)
	self.controls.applyUpdate.shown = function()
		return launch.updateAvailable and launch.updateAvailable ~= "none"
	end
	self.controls.checkUpdate = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, -24, 140, 20, "", function()
		launch:CheckForUpdate()
	end)
	self.controls.checkUpdate.shown = function()
		return not launch.devMode and (not launch.updateAvailable or launch.updateAvailable == "none")
	end
	self.controls.checkUpdate.label = function()
return launch.updateCheckRunning and launch.updateProgress or "检查更新"
	end
	self.controls.checkUpdate.enabled = function()
		return not launch.updateCheckRunning
	end
	self.controls.versionLabel = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 144, -27, 0, 14, "")
	self.controls.versionLabel.label = function()
		return "^8版本号: "..launch.versionNumber..(launch.versionBranch == "dev" and " (Dev)" or "")
	end
	self.controls.devMode = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, -26, 0, 20, "^1Dev Mode")
	self.controls.devMode.shown = function()
		return launch.devMode
	end
	self.controls.dismissToast = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, function() return -self.mainBarHeight + self.toastHeight end, 80, 20, "忽略", function()
		self.toastMode = "HIDING"
		self.toastStart = GetTime()
	end)
	self.controls.dismissToast.shown = function()
		return self.toastMode == "SHOWN"
	end

	self.mainBarHeight = 58
	self.toastMessages = { }

	if launch.devMode and GetTime() >= 0 and GetTime() < 15000 then
		t_insert(self.toastMessages, [[
^xFF7700Warning: ^7Developer Mode active!
The program is currently running in developer
mode, which is not intended for normal use.
If you are not expecting this, then you may have
set up the program from the source .zip instead
of using one of the installers. If that is the case,
please reinstall using one of the installers from
the "Releases" section of the GitHub page.]])
	end

	self.inputEvents = { }
	self.popups = { }
	self.tooltipLines = { }

	self.buildSortMode = "NAME"
	self.nodePowerTheme = "RED/BLUE"
	self.showThousandsSeparators = true
	self.thousandsSeparator = ","
	self.decimalSeparator = "."
	

	local ignoreBuild = self:LoadPastebinBuild()

	if not ignoreBuild then
		self:SetMode("BUILD", false, "Unnamed build")
	end

	self:LoadSharedItems()

	self.onFrameFuncs = { }
end

function main:LoadTree(treeVersion)
	if self.tree[treeVersion] then
		data.setJewelRadiiGlobally(treeVersion)
		return self.tree[treeVersion]
	elseif isValueInTable(treeVersionList, treeVersion) then
		data.setJewelRadiiGlobally(treeVersion)
		--ConPrintf("[main:LoadTree] - Lazy Loading Tree " .. treeVersion)
		self.tree[treeVersion] = new("PassiveTree", treeVersion)
		return self.tree[treeVersion]
	end
	return nil
end


function main:CanExit()
	local ret = self:CallMode("CanExit", "EXIT")
	if ret ~= nil then
		return ret
	else
		return true
	end
end

function main:Shutdown()
	self:CallMode("Shutdown")
	self:SaveSettings()
end

function main:OnFrame()
	self.screenW, self.screenH = GetScreenSize()
	if self.screenH > self.screenW then
		self.portraitMode = true
	else
		self.portraitMode = false
	end
	while self.newMode do
		if self.mode then
			self:CallMode("Shutdown")
		end
		self.mode = self.newMode
		self.newMode = nil
		self:CallMode("Init", unpack(self.newModeArgs))
	end

	self.viewPort = { x = 0, y = 0, width = self.screenW, height = self.screenH }

	if self.popups[1] then
		self.popups[1]:ProcessInput(self.inputEvents, self.viewPort)
		wipeTable(self.inputEvents)
	else
		self:ProcessControlsInput(self.inputEvents, self.viewPort)
	end

	self:CallMode("OnFrame", self.inputEvents, self.viewPort)

	if launch.updateErrMsg then
t_insert(self.toastMessages, string.format("检查更新失败!\n%s", launch.updateErrMsg))
		launch.updateErrMsg = nil
	end
	if launch.updateAvailable then
		if launch.updateAvailable == "none" then
t_insert(self.toastMessages, "当前程序是最新版，无需更新.")
			launch.updateAvailable = nil
		elseif not self.updateAvailableShown then
t_insert(self.toastMessages, "有更新\n更新文件已经下载完毕，等待应用更新.")
			self.updateAvailableShown = true
		end
	end

	-- Run toasts
	if self.toastMessages[1] then
		if not self.toastMode then
			self.toastMode = "SHOWING"
			self.toastStart = GetTime()
			self.toastHeight = #self.toastMessages[1]:gsub("[^\n]","") * 16 + 20 + 40
		end
		if self.toastMode == "SHOWING" then
			local now = GetTime()
			if now >= self.toastStart + 250 then
				self.toastMode = "SHOWN"
			else
				self.mainBarHeight = 58 + self.toastHeight * (now - self.toastStart) / 250
			end
		end
		if self.toastMode == "SHOWN" then
			self.mainBarHeight = 58 + self.toastHeight
		elseif self.toastMode == "HIDING" then
			local now = GetTime()
			if now >= self.toastStart + 75 then
				self.toastMode = nil
				self.mainBarHeight = 58
				t_remove(self.toastMessages, 1)
			else
				self.mainBarHeight = 58 + self.toastHeight * (1 - (now - self.toastStart) / 75)
			end
		end
		if self.toastMode then
			SetDrawColor(0.85, 0.85, 0.85)
			DrawImage(nil, 0, self.screenH - self.mainBarHeight, 312, self.mainBarHeight)
			SetDrawColor(0.1, 0.1, 0.1)
			DrawImage(nil, 0, self.screenH - self.mainBarHeight + 4, 308, self.mainBarHeight - 4)
			SetDrawColor(1, 1, 1)
			DrawString(4, self.screenH - self.mainBarHeight + 8, "LEFT", 20, "VAR", self.toastMessages[1]:gsub("\n.*",""))
			DrawString(4, self.screenH - self.mainBarHeight + 28, "LEFT", 16, "VAR", self.toastMessages[1]:gsub("^[^\n]*\n?",""))
		end
	end

	-- Draw main controls
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, 0, self.screenH - 58, 312, 58)
	SetDrawColor(0.1, 0.1, 0.1)
	DrawImage(nil, 0, self.screenH - 54, 308, 54)
	self:DrawControls(self.viewPort)

	if self.popups[1] then
		SetDrawLayer(10)
		SetDrawColor(0, 0, 0, 0.5)
		DrawImage(nil, 0, 0, self.screenW, self.screenH)
		self.popups[1]:Draw(self.viewPort)
		SetDrawLayer(0)
	end

	if self.showDragText then
		local cursorX, cursorY = GetCursorPos()
		local strWidth = DrawStringWidth(16, "VAR", self.showDragText)
		SetDrawLayer(20, 0)
		SetDrawColor(0.15, 0.15, 0.15, 0.75)
		DrawImage(nil, cursorX, cursorY - 8, strWidth + 2, 18)
		SetDrawColor(1, 1, 1)
		DrawString(cursorX + 1, cursorY - 7, "LEFT", 16, "VAR", self.showDragText)
		self.showDragText = nil
	end
	
	--[[local par = 300
	for x = 0, 750 do
		for y = 0, 750 do
			local dpsCol = (x / par * 1.5) ^ 0.5
			local defCol = (y / par * 1.5) ^ 0.5
			local mixCol = (m_max(dpsCol - 0.5, 0) + m_max(defCol - 0.5, 0)) / 2
			if main.nodePowerTheme == "RED/BLUE" then
				SetDrawColor(dpsCol, mixCol, defCol)
			elseif main.nodePowerTheme == "RED/GREEN" then
				SetDrawColor(dpsCol, defCol, mixCol)
			elseif main.nodePowerTheme == "GREEN/BLUE" then
				SetDrawColor(mixCol, dpsCol, defCol)
			end
			DrawImage(nil, x + 500, y + 200, 1, 1)
		end
	end
	SetDrawColor(0, 0, 0)
	DrawImage(nil, par + 500, 200, 2, 750)
	DrawImage(nil, 500, par + 200, 759, 2)]]

	wipeTable(self.inputEvents)
end

function main:OnKeyDown(key, doubleClick)
	t_insert(self.inputEvents, { type = "KeyDown", key = key, doubleClick = doubleClick })
end

function main:OnKeyUp(key)
	t_insert(self.inputEvents, { type = "KeyUp", key = key })
end

function main:OnChar(key)
	t_insert(self.inputEvents, { type = "Char", key = key })
end

function main:SetMode(newMode, ...)
	self.newMode = newMode
	self.newModeArgs = {...}
end

function main:CallMode(func, ...)
	local modeTbl = self.modes[self.mode]
	if modeTbl and modeTbl[func] then
		return modeTbl[func](modeTbl, ...)
	end
end

function main:LoadPastebinBuild()
	local fullUri = arg[1]
	if not fullUri then
		return false
	end
	arg[1] = nil -- Protect against downloading again this session.
	local pastebinCode = string.match(fullUri, "^pob:[/\\]*pastebin[/\\]+(%w+)[/\\]*")
	if pastebinCode then
		launch:DownloadPage("https://pastebin.com/raw/" .. pastebinCode, function(page, errMsg)
			if errMsg then
				self:SetMode("BUILD", false, "Failed Build Import (Download failed " .. pastebinCode .. ")")
			else
				local xmlText = Inflate(common.base64.decode(page:gsub("-","+"):gsub("_","/")))
				if xmlText then
					self:SetMode("BUILD", false, "Imported Build", xmlText)
					self.newModeChangeToTree = true
				else
					self:SetMode("BUILD", false, "Failed Build Import (Decompress failed)")
				end
			end
		end)
		return true
	end
	return false
end

function main:LoadSettings(ignoreBuild)
	
	local setXML, errMsg = common.xml.LoadXMLFile(self.userPath.."Settings.xml")
	if not setXML then
		return true
	elseif setXML[1].elem ~= "PathOfBuilding" then
launch:ShowErrMsg("^1文件解析失败 'Settings.xml': 'PathOfBuilding'子节点丢失")
		return true
	end
	for _, node in ipairs(setXML[1]) do
		if type(node) == "table" then
			if not ignoreBuild and node.elem == "Mode" then
				if not node.attrib.mode or not self.modes[node.attrib.mode] then
launch:ShowErrMsg("^1文件解析失败 'Settings.xml':  'Mode' 节点错误")
					return true
				end
				local args = { }
				for _, child in ipairs(node) do
					if type(child) == "table" then
						if child.elem == "Arg" then
							if child.attrib.number then
								t_insert(args, tonumber(child.attrib.number))
							elseif child.attrib.string then
								t_insert(args, child.attrib.string)
							elseif child.attrib.boolean then
								t_insert(args, child.attrib.boolean == "true")
							end
						end
					end
				end
				self:SetMode(node.attrib.mode, unpack(args))
			elseif node.elem == "Accounts" then
				self.lastAccountName = node.attrib.lastAccountName
				self.lastRealm = node.attrib.lastRealm
				for _, child in ipairs(node) do
					if child.elem == "Account" then
						self.gameAccounts[child.attrib.accountName] = {
							sessionID = child.attrib.sessionID,
						}
						self.POESESSID = child.attrib.sessionID
					end
				end
			elseif node.elem == "Misc" then
				if node.attrib.buildSortMode then
					self.buildSortMode = node.attrib.buildSortMode
				end
				launch.proxyURL = node.attrib.proxyURL
				if node.attrib.buildPath then
					self.buildPath = node.attrib.buildPath
				end
				if node.attrib.nodePowerTheme then
					self.nodePowerTheme = node.attrib.nodePowerTheme
				end
				-- In order to preserve users' settings through renameing/merging this variable, we have this if statement to use the first found setting
				-- Once the user has closed PoB once, they will be using the new `showThousandsSeparator` variable name, so after some time, this statement may be removed
				if node.attrib.showThousandsCalcs then
					self.showThousandsSeparators = node.attrib.showThousandsCalcs == "true"
				elseif node.attrib.showThousandsSidebar then
					self.showThousandsSeparators = node.attrib.showThousandsSidebar == "true"
				end
				if node.attrib.showThousandsSeparators then
					self.showThousandsSeparators = node.attrib.showThousandsSeparators == "true"
				end
				if node.attrib.thousandsSeparator then
					self.thousandsSeparator = node.attrib.thousandsSeparator
				end
				if node.attrib.decimalSeparator then
					self.decimalSeparator = node.attrib.decimalSeparator
				end
				-- if node.attrib.POESESSID then
				-- 	self.POESESSID = node.attrib.POESESSID or ""
				-- end
				if node.attrib.showTitlebarName then
					self.showTitlebarName = node.attrib.showTitlebarName == "true"
				end				
				
			end
		end
	end
end

function main:LoadSharedItems()
	local setXML, errMsg = common.xml.LoadXMLFile(self.userPath.."Settings.xml")
	if not setXML then
		return true
	elseif setXML[1].elem ~= "PathOfBuilding" then
		launch:ShowErrMsg("^1Error parsing 'Settings.xml': 'PathOfBuilding' root element missing")
		return true
	end
	for _, node in ipairs(setXML[1]) do
		if type(node) == "table" then
			if node.elem == "SharedItems" then
				for _, child in ipairs(node) do
					if child.elem == "Item" then
						local rawItem = { raw = "" }
						for _, subChild in ipairs(child) do
							if type(subChild) == "string" then
								rawItem.raw = subChild
							end
						end
						local newItem = new("Item", rawItem.raw)
						t_insert(self.sharedItemList, newItem)
					elseif child.elem == "ItemSet" then
						local sharedItemSet = { title = child.attrib.title, slots = { } }
						for _, grandChild in ipairs(child) do
							if grandChild.elem == "Item" then
								local rawItem = { raw = "" }
								for _, subChild in ipairs(grandChild) do
									if type(subChild) == "string" then
										rawItem.raw = subChild
									end
								end
								local newItem = new("Item", rawItem.raw)
								sharedItemSet.slots[grandChild.attrib.slotName] = newItem
							end
						end
						t_insert(self.sharedItemSetList, sharedItemSet)
					end
				end
			end
		end
	end
end

function main:SaveSettings()
	local setXML = { elem = "PathOfBuilding" }
	local mode = { elem = "Mode", attrib = { mode = self.mode } }
	for _, val in ipairs({ self:CallMode("GetArgs") }) do
		local child = { elem = "Arg", attrib = { } }
		if type(val) == "number" then
			child.attrib.number = tostring(val)
		elseif type(val) == "boolean" then
			child.attrib.boolean = tostring(val)
		else
			child.attrib.string = tostring(val)
		end
		t_insert(mode, child)
	end
	t_insert(setXML, mode)
	local accounts = { elem = "Accounts", attrib = { lastAccountName = self.lastAccountName, lastRealm = self.lastRealm } }
	for accountName, account in pairs(self.gameAccounts) do
		t_insert(accounts, { elem = "Account", attrib = { accountName = accountName, sessionID = account.sessionID } })
	end
	t_insert(setXML, accounts)
	local sharedItemList = { elem = "SharedItems" }
	for _, verItem in ipairs(self.sharedItemList) do
		t_insert(sharedItemList, { elem = "Item", [1] = verItem.raw })
	end
	for _, sharedItemSet in ipairs(self.sharedItemSetList) do
		local set = { elem = "ItemSet", attrib = { title = sharedItemSet.title } }
		for slotName, verItem in pairs(sharedItemSet.slots) do
			t_insert(set, { elem = "Item", attrib = { slotName = slotName }, [1] = verItem.raw })
		end
		t_insert(sharedItemList, set)
	end
	t_insert(setXML, sharedItemList)
	t_insert(setXML, { elem = "Misc", attrib = { 
		buildSortMode = self.buildSortMode, 
		proxyURL = launch.proxyURL, 
		buildPath = (self.buildPath ~= self.defaultBuildPath and self.buildPath or nil),
		nodePowerTheme = self.nodePowerTheme,
		showThousandsSeparators = tostring(self.showThousandsSeparators),
		thousandsSeparator = self.thousandsSeparator,
		decimalSeparator = self.decimalSeparator,
		POESESSID = self.POESESSID,
	} })
	local res, errMsg = common.xml.SaveXMLFile(setXML, self.userPath.."Settings.xml")
	if not res then
		launch:ShowErrMsg("Error saving 'Settings.xml': %s", errMsg)
		return true
	end
end

function main:OpenOptionsPopup()
	local controls = { }
	-- proxy
	controls.proxyType = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, 150, 20, 80, 18, {
		{ label = "HTTP", scheme = "http" },
		{ label = "SOCKS", scheme = "socks5" },
		{ label = "SOCKS5H", scheme = "socks5h" },
	})
	controls.proxyLabel = new("LabelControl", {"RIGHT",controls.proxyType,"LEFT"}, -4, 0, 0, 16, "^7代理服务器:")
	controls.proxyURL = new("EditControl", {"LEFT",controls.proxyType,"RIGHT"}, 4, 0, 206, 18)
	if launch.proxyURL then
		local scheme, url = launch.proxyURL:match("(%w+)://(.+)")
		controls.proxyType:SelByValue(scheme, "scheme")
		controls.proxyURL:SetText(url)
	end

	-- repo
	controls.repoURL = new("EditControl", {"TOPLEFT", nil, "TOPLEFT"}, 150, 44, 230, 18)
	controls.repoURLLabel = new("LabelControl", {"RIGHT",controls.repoURL,"LEFT"}, -4, 0, 0, 16, "^7代码仓库地址:")
	controls.RepoFetchButton = new("ButtonControl", {"LEFT",controls.repoURL,"RIGHT"}, 4, 0, 56, 18, "更新", function()
		local newRepoURL = launch.UpdateRepoUrl()
		controls.repoURL:SetText(newRepoURL)
	end)
	local currentRepo = launch.ReadCurrentRepoUrl()
	controls.repoURL:SetText(currentRepo)

	-- build save path
	controls.buildPath = new("EditControl", {"TOPLEFT",nil,"TOPLEFT"}, 150, 68, 290, 18)
	controls.buildPathLabel = new("LabelControl", {"RIGHT",controls.buildPath,"LEFT"}, -4, 0, 0, 16, "^7Build 保存路径:")
	if self.buildPath ~= self.defaultBuildPath then
		controls.buildPath:SetText(self.buildPath)
	end
	controls.buildPath.tooltipText = "覆盖默认的build保存路径.\n默认路径为: '"..self.defaultBuildPath.."'"

	-- power theme
	controls.nodePowerTheme = new("DropDownControl", {"TOPLEFT",nil,"TOPLEFT"}, 150, 92, 100, 18, {
		{ label = "Red & Blue", theme = "RED/BLUE" },
		{ label = "Red & Green", theme = "RED/GREEN" },
		{ label = "Green & Blue", theme = "GREEN/BLUE" },
	}, function(index, value)
		self.nodePowerTheme = value.theme
	end)
	controls.nodePowerThemeLabel = new("LabelControl", {"RIGHT",controls.nodePowerTheme,"LEFT"}, -4, 0, 0, 16, "^7天赋树节点高亮颜色:")
	controls.nodePowerTheme.tooltipText = "修改天赋树中节点的高亮颜色."
	controls.nodePowerTheme:SelByValue(self.nodePowerTheme, "theme")
	
	-- seperator checkbox
	controls.separatorLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, 210, 120, 0, 16, "^7显示千位分隔符:")	
	controls.thousandsSeparators = new("CheckBoxControl", {"TOPLEFT",nil,"TOPLEFT"}, 280, 118, 20, nil, function(state)
		self.showThousandsSeparators = state
	end)
	controls.thousandsSeparators.state = self.showThousandsSeparators

	-- seperator 1
	controls.thousandsSeparator = new("EditControl", {"TOPLEFT",nil,"TOPLEFT"}, 280, 140, 20, 20, self.thousandsSeparator, nil, "%%^", 1, function(buf)
		self.thousandsSeparator = buf
	end)
	controls.thousandsSeparatorLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, 210, 140, 92, 16, "千位分隔符:")
	
	-- seperator 2
	controls.decimalSeparator = new("EditControl", {"TOPLEFT",nil,"TOPLEFT"}, 280, 160, 20, 20, self.decimalSeparator, nil, "%%^", 1, function(buf)
		self.decimalSeparator = buf
	end)
	controls.decimalSeparatorLabel = new("LabelControl", {"TOPRIGHT",nil,"TOPLEFT"}, 210, 160, 92, 16, "小数分隔符:")

	-- save button
	local initialNodePowerTheme = self.nodePowerTheme
	local initialThousandsSeparatorDisplay = self.showThousandsSeparators
	local initialThousandsSeparator = self.thousandsSeparator
	local initialDecimalSeparator = self.decimalSeparator
	controls.save = new("ButtonControl", nil, -45, 182, 80, 20, "保存", function()
		if controls.proxyURL.buf:match("%w") then
			launch.proxyURL = controls.proxyType.list[controls.proxyType.selIndex].scheme .. "://" .. controls.proxyURL.buf
		else
			launch.proxyURL = nil
		end
		if controls.buildPath.buf:match("%S") then
			self.buildPath = controls.buildPath.buf
			if not self.buildPath:match("[\\/]$") then
				self.buildPath = self.buildPath .. "/"
			end
		else
			self.buildPath = self.defaultBuildPath
		end
		if self.mode == "LIST" then
			self.modes.LIST:BuildList()
		end
		main:ClosePopup()
		main:SaveSettings()
	end)
controls.cancel = new("ButtonControl", nil, 45, 182, 80, 20, "取消", function()
		self.nodePowerTheme = initialNodePowerTheme
		self.showThousandsSeparators = initialThousandsSeparatorDisplay
		self.thousandsSeparator = initialThousandsSeparator
		self.decimalSeparator = initialDecimalSeparator
		main:ClosePopup()
	end)
	self:OpenPopup(450, 218, "选项", controls, "save", nil, "cancel")
end

function main:OpenUpdatePopup()
	local changeList = { }
	local changelogName = launch.devMode and "changelog.txt" or "changelog.txt"
	for line in io.lines(changelogName) do
		local ver, date = line:match("^VERSION%[(.+)%]%[(.+)%]$")
		if ver then
			if ver == launch.versionNumber then
				break
			end
			if #changeList > 0 then
				t_insert(changeList, { height = 12 })
			end
			t_insert(changeList, { height = 20, "^7版本 "..ver.." ("..date..")" })
		else
			t_insert(changeList, { height = 14, "^7"..line })
		end
	end
	local controls = { }
	controls.changeLog = new("TextListControl", nil, 0, 20, 780, 192, nil, changeList)
	controls.update = new("ButtonControl", nil, -45, 220, 80, 20, "更新", function()
		self:ClosePopup()
		local ret = self:CallMode("CanExit", "UPDATE")
		if ret == nil or ret == true then
			launch:ApplyUpdate(launch.updateAvailable)
		end
	end)
		controls.cancel = new("ButtonControl", nil, 45, 220, 80, 20, "取消", function()
		self:ClosePopup()
	end)
	--[[
	controls.patreon = new("ButtonControl", {"BOTTOMLEFT",nil,"BOTTOMLEFT"}, 10, -10, 82, 22, "", function()
		OpenURL("https://www.patreon.com/openarl")
	end)
	controls.patreon:SetImage("Assets/patreon_logo.png")
controls.patreon.tooltipText = "给pob原作者：Openarl 捐款赞助!"
]]--

self:OpenPopup(800, 250, "【可用更新】", controls)
end

function main:OpenAboutPopup()
	local changeList = { }
	local changelogName = launch.devMode and "changelog.txt" or "changelog.txt"
	for line in io.lines(changelogName) do
		local ver, date = line:match("^VERSION%[(.+)%]%[(.+)%]$")
		if ver then
			if #changeList > 0 then
				t_insert(changeList, { height = 10 })
			end
			t_insert(changeList, { height = 18, "^7Version "..ver.." ("..date..")" })
		else
			t_insert(changeList, { height = 12, "^7"..line })
		end
	end
	local controls = { }
controls.close = new("ButtonControl", {"TOPRIGHT",nil,"TOPRIGHT"}, -10, 10, 50, 20, "关闭", function()
		self:ClosePopup()
	end)
controls.version = new("LabelControl", nil, 0, 18, 0, 18, "Path of Building v"..launch.versionNumber.." 作者：Openarl 国服版：幸福的闪电")
controls.forum = new("ButtonControl", nil, 0, 42, 450, 18, "国服版反馈: ^x4040FFhttps://gitee.com/echo28/PathOfBuildingCN17173/issues/new", function(control)
OpenURL("https://gitee.com/echo28/PathOfBuildingCN17173/issues/new")
	end)
controls.github = new("ButtonControl", nil, 0, 64, 450, 18, "国服POB交流群: ^x4040FF318952371", function(control)
OpenURL("https://jq.qq.com/?_wv=1027&k=IVaR5lfl")
	end)
	controls.patreon = new("ButtonControl", {"TOPLEFT",nil,"TOPLEFT"}, 10, 10, 70, 70, "", function()
		OpenURL("https://gitee.com/echo28/PathOfBuildingCN17173/blob/main/%E8%B5%9E%E8%B5%8F%E4%B8%80%E4%B8%8B.jpg")
	end)
controls.patreon:SetImage("Assets/patreon_logo.png")
controls.patreon.tooltipText = "点击赞赏一下国服POB!"
controls.verLabel = new("LabelControl", {"TOPLEFT",nil,"TOPLEFT"}, 10, 82, 0, 18, "点击图片打开")
controls.changelog = new("TextListControl", nil, 0, 100, 630, 290, nil, changeList)
self:OpenPopup(650, 400, "【  POB·国服版  】", controls)
end

function main:DrawBackground(viewPort)
	SetDrawLayer(nil, -100)
	SetDrawColor(0.5, 0.5, 0.5)
	if self.tree[latestTreeVersion].assets.Background2 then
		DrawImage(self.tree[latestTreeVersion].assets.Background2.handle, viewPort.x, viewPort.y, viewPort.width, viewPort.height, 0, 0, viewPort.width / 100, viewPort.height / 100)
	else
		DrawImage(self.tree[latestTreeVersion].assets.Background1.handle, viewPort.x, viewPort.y, viewPort.width, viewPort.height, 0, 0, viewPort.width / 100, viewPort.height / 100)
	end
	SetDrawLayer(nil, 0)
end

function main:DrawArrow(x, y, width, height, dir)
	local x1 = x - width / 2
	local x2 = x + width / 2
	local xMid = (x1 + x2) / 2
	local y1 = y - height / 2
	local y2 = y + height / 2
	local yMid = (y1 + y2) / 2
	if dir == "UP" then
		DrawImageQuad(nil, xMid, y1, xMid, y1, x2, y2, x1, y2)
	elseif dir == "RIGHT" then
		DrawImageQuad(nil, x1, y1, x2, yMid, x2, yMid, x1, y2)
	elseif dir == "DOWN" then
		DrawImageQuad(nil, x1, y1, x2, y1, xMid, y2, xMid, y2)
	elseif dir == "LEFT" then
		DrawImageQuad(nil, x1, yMid, x2, y1, x2, y2, x1, yMid)
	end
end

function main:DrawCheckMark(x, y, size)
	size = size / 0.8
	x = x - size / 2
	y = y - size / 2
	DrawImageQuad(nil, x + size * 0.15, y + size * 0.50, x + size * 0.30, y + size * 0.45, x + size * 0.50, y + size * 0.80, x + size * 0.40, y + size * 0.90)
	DrawImageQuad(nil, x + size * 0.40, y + size * 0.90, x + size * 0.35, y + size * 0.75, x + size * 0.80, y + size * 0.10, x + size * 0.90, y + size * 0.20)
end

do
	local cos45 = m_cos(m_pi / 4)
	local cos35 = m_cos(m_pi * 0.195)
	local sin35 = m_sin(m_pi * 0.195)
	function main:WorldToScreen(x, y, z, width, height)
		-- World -> camera
		local cx = (x - y) * cos45
		local cy = -5.33 - (y + x) * cos45 * cos35 - z * sin35
		local cz = 122 + (y + x) * cos45 * sin35 - z * cos35
		-- Camera -> screen
		local sx = width * 0.5 + cx / cz * 1.27 * height
		local sy = height * 0.5 + cy / cz * 1.27 * height
		return round(sx), round(sy)
	end
end

function main:RenderCircle(x, y, width, height, oX, oY, radius)
	local minX = wipeTable(tempTable1)
	local maxX = wipeTable(tempTable2)
	local minY = height
	local maxY = 0
	for d = 0, 360, 0.15 do
		local r = d / 180 * m_pi
		local px, py = main:WorldToScreen(oX + m_sin(r) * radius, oY + m_cos(r) * radius, 0, width, height)
		if py >= 0 and py < height then
			px = m_min(width, m_max(0, px))
			minY = m_min(minY, py)
			maxY = m_max(maxY, py)
			minX[py] = m_min(minX[py] or px, px)
			maxX[py] = m_max(maxX[py] or px, px)
		end
	end
	for ly = minY, maxY do
		if minX[ly] then
			DrawImage(nil, x + minX[ly], y + ly, maxX[ly] - minX[ly] + 1, 1)
		end
	end
end

function main:RenderRing(x, y, width, height, oX, oY, radius, size)
	local lastX, lastY
	for d = 0, 360, 0.2 do
		local r = d / 180 * m_pi
		local px, py = main:WorldToScreen(oX + m_sin(r) * radius, oY + m_cos(r) * radius, 0, width, height)
		if px >= -size/2 and px < width + size/2 and py >= -size/2 and py < height + size/2 and (px ~= lastX or py ~= lastY) then
			DrawImage(nil, x + px - size/2, y + py, size, size)
			lastX, lastY = px, py
		end
	end
end

function main:StatColor(stat, base, limit)
	if limit and stat > limit then
		return colorCodes.NEGATIVE
	elseif base and stat ~= base then
		return colorCodes.MAGIC
	else
		return "^7"
	end
end

function main:MoveFolder(name, srcPath, dstPath)
	-- Create destination folder
	local res, msg = MakeDir(dstPath..name)
	if not res then
		self:OpenMessagePopup("Error", "Couldn't move '"..name.."' to '"..dstPath.."' : "..msg)
		return
	end

	-- Move subfolders
	local handle = NewFileSearch(srcPath..name.."/*", true)
	while handle do
		self:MoveFolder(handle:GetFileName(), srcPath..name.."/", dstPath..name.."/")
		if not handle:NextFile() then
			break
		end
	end

	-- Move files
	handle = NewFileSearch(srcPath..name.."/*") 
	while handle do
		local fileName = handle:GetFileName()
		local srcName = srcPath..name.."/"..fileName
		local dstName = dstPath..name.."/"..fileName
		local res, msg = os.rename(srcName, dstName)
		if not res then
			self:OpenMessagePopup("Error", "Couldn't move '"..srcName.."' to '"..dstName.."': "..msg)
			return
		end
		if not handle:NextFile() then
			break
		end		
	end

	-- Remove source folder
	local res, msg = RemoveDir(srcPath..name)
	if not res then
		self:OpenMessagePopup("Error", "Couldn't delete '"..dstPath..name.."' : "..msg)
		return
	end
end

function main:CopyFolder(srcName, dstName)
	-- Create destination folder
	local res, msg = MakeDir(dstName)
	if not res then
		self:OpenMessagePopup("Error", "Couldn't copy '"..srcName.."' to '"..dstName.."' : "..msg)
		return
	end

	-- Copy subfolders
	local handle = NewFileSearch(srcName.."/*", true)
	while handle do
		local fileName = handle:GetFileName()
		self:CopyFolder(srcName.."/"..fileName, dstName.."/"..fileName)
		if not handle:NextFile() then
			break
		end
	end

	-- Copy files
	handle = NewFileSearch(srcName.."/*") 
	while handle do
		local fileName = handle:GetFileName()
		local srcName = srcName.."/"..fileName
		local dstName = dstName.."/"..fileName
		local res, msg = copyFile(srcName, dstName)
		if not res then
			self:OpenMessagePopup("Error", "Couldn't copy '"..srcName.."' to '"..dstName.."': "..msg)
			return
		end
		if not handle:NextFile() then
			break
		end		
	end
end

function main:OpenPopup(width, height, title, controls, enterControl, defaultControl, escapeControl)
	local popup = new("PopupDialog", width, height, title, controls, enterControl, defaultControl, escapeControl)
	t_insert(self.popups, 1, popup)
	return popup
end

function main:ClosePopup()
	t_remove(self.popups, 1)
end

function main:OpenMessagePopup(title, msg)
	local controls = { }
	local numMsgLines = 0
	for line in string.gmatch(msg .. "\n", "([^\n]*)\n") do
		t_insert(controls, new("LabelControl", nil, 0, 20 + numMsgLines * 16, 0, 16, line))
		numMsgLines = numMsgLines + 1
	end
	controls.close = new("ButtonControl", nil, 0, 40 + numMsgLines * 16, 80, 20, "Ok", function()
		main:ClosePopup()
	end)
	return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, 500), 70 + numMsgLines * 16, title, controls, "close")
end

function main:OpenConfirmPopup(title, msg, confirmLabel, onConfirm)
	local controls = { }
	local numMsgLines = 0
	for line in string.gmatch(msg .. "\n", "([^\n]*)\n") do
		t_insert(controls, new("LabelControl", nil, 0, 20 + numMsgLines * 16, 0, 16, line))
		numMsgLines = numMsgLines + 1
	end
	local confirmWidth = m_max(80, DrawStringWidth(16, "VAR", confirmLabel) + 10)
	controls.confirm = new("ButtonControl", nil, -5 - m_ceil(confirmWidth/2), 40 + numMsgLines * 16, confirmWidth, 20, confirmLabel, function()
		main:ClosePopup()
		onConfirm()
	end)
	t_insert(controls, new("ButtonControl", nil, 5 + m_ceil(confirmWidth/2), 40 + numMsgLines * 16, confirmWidth, 20, "取消", function()
		main:ClosePopup()
	end))
	return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, 290), 70 + numMsgLines * 16, title, controls, "confirm")
end

function main:OpenNewFolderPopup(path, onClose)
	local controls = { }
	controls.label = new("LabelControl", nil, 0, 20, 0, 16, "^7Enter folder name:")
	controls.edit = new("EditControl", nil, 0, 40, 350, 20, nil, nil, "\\/:%*%?\"<>|%c", 100, function(buf)
		controls.create.enabled = buf:match("%S")
	end)
	controls.create = new("ButtonControl", nil, -45, 70, 80, 20, "Create", function()
		local newFolderName = controls.edit.buf
		local res, msg = MakeDir(path..newFolderName)
		if not res then
			main:OpenMessagePopup("Error", "Couldn't create '"..newFolderName.."': "..msg)
			return
		end
		if onClose then
			onClose(newFolderName)
		end
		main:ClosePopup()
	end)
	controls.create.enabled = false
	controls.cancel = new("ButtonControl", nil, 45, 70, 80, 20, "Cancel", function()
		if onClose then
			onClose()
		end
		main:ClosePopup()
	end)
main:OpenPopup(370, 100, "新文件夹", controls, "create", "edit", "cancel")	
end

function main:SetWindowTitleSubtext(subtext)
	if not subtext or not self.showTitlebarName then
		SetWindowTitle(APP_NAME)
	else
		SetWindowTitle(APP_NAME.." - "..subtext)
	end
end

do
	local wrapTable = { }
	function main:WrapString(str, height, width)
		wipeTable(wrapTable)
		local lineStart = 1
		local lastSpace, lastBreak
		while true do
			local s, e = str:find("%s+", lastSpace)
			if not s then
				s = #str + 1
				e = #str + 1
			end
			if lineStart == nil then break end
			if DrawStringWidth(height, "VAR", str:sub(lineStart, s - 1)) > width then
				t_insert(wrapTable, str:sub(lineStart, lastBreak))
				lineStart = lastSpace
			end
			if s > #str then
if str~=nil and lineStart~=nil  then  t_insert(wrapTable, str:sub(lineStart, -1)) end
				break
			end
			lastBreak = s - 1
			lastSpace = e + 1
		end
		return wrapTable
	end
end

return main
