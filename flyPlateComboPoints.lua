local AddonName, fPCP = ...
L = fPCP.L

local	C_NamePlate_GetNamePlateForUnit, C_NamePlate_GetNamePlates, CreateFrame, UnitDebuff, UnitBuff, UnitIsUnit, UnitIsPlayer, UnitPlayerControlled, UnitIsFriend, strmatch =
		C_NamePlate.GetNamePlateForUnit, C_NamePlate.GetNamePlates, CreateFrame, UnitDebuff, UnitBuff, UnitIsUnit, UnitIsPlayer, UnitPlayerControlled, UnitIsFriend, strmatch

local LSM = LibStub("LibSharedMedia-3.0")
fPCP.LSM = LSM
local MSQ, Group

local config = LibStub("AceConfig-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

fPCP.db = {}
local db

local DefaultSettings = {
	profile = {
		notHideOnPersonalResource = true,
		parentWorldFrame = false,
		font = "Friz Quadrata TT",
		fontSize = 12,
	},
}

local function FilterUnits(nameplateID)
	-- filter units
	if UnitIsUnit(nameplateID,"player") then return true end
	if UnitIsFriend(nameplateID,"player") then return true end

	return false
end

local function CreatePoint(frame, i)
	frame.fPCPFrame.points[i] = CreateFrame("Button")
	frame.fPCPFrame.points[i]:SetParent(frame.fPCPFrame)
	local point = frame.fPCPFrame.points[i]

	point.texture = point:CreateTexture(nil, "BACKGROUND")
	point.texture:SetAllPoints(point)
	point.texture:SetTexture("Interface\\Addons\\flyPlateComboPoints\\textures\\point.tga")
	point.texture:SetVertexColor(0.3,0.3,0.3)

	point:SetWidth(10)
	point:SetHeight(10)
	point:SetAlpha(1)

	point:ClearAllPoints()
	if i == 1 then
		point:SetPoint("BOTTOMLEFT", frame.fPCPFrame, "BOTTOMLEFT", 0, 0)
	else
		point:SetPoint("BOTTOMLEFT",  frame.fPCPFrame.points[i-1], "BOTTOMRIGHT", 0, 0)
	end
end

local function UpdateUnitComboPoints(nameplateID)
	local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)
	if not frame then return end 	-- modifying friendly nameplates is restricted in instances since 7.2

	if FilterUnits(nameplateID) then
		if frame.fPCPFrame then
			frame.fPCPFrame:Hide()
		end
		return
	end

	local comboPoints = GetComboPoints("player", nameplateID)

	if comboPoints == 0 then
		if frame.fPCPFrame then
			frame.fPCPFrame:Hide()
		end
		return
	end

	if not frame.fPCPFrame then
		-- if parent == frame then it will change scale and alpha with nameplates
		-- otherwise use UIParent, but this causes mess of icon/border textures
		frame.fPCPFrame = CreateFrame("Frame")
		local parent = db.parentWorldFrame and WorldFrame
		if not parent then
			parent = frame.unitFrame -- for ElvUI
		end
		if not parent then
			parent = frame.TPFrame -- for ThreatPlates
		end
		if not parent then
			parent = frame
		end
		frame.fPCPFrame:SetParent(parent)
	end
	if not frame.fPCPFrame.points then
		frame.fPCPFrame.points = {}
	end


	frame.fPCPFrame:SetWidth(50)
	frame.fPCPFrame:SetHeight(10)
	frame.fPCPFrame:SetFrameStrata("HIGH")

	for i = 1, 5 do
		if not frame.fPCPFrame.points[i] then
			CreatePoint(frame,i)
		end

		local point = frame.fPCPFrame.points[i]
		if comboPoints == 5 then 
			-- Red
			point.texture:SetVertexColor(0.97, 0.1, 0.1)
		elseif i <= comboPoints then
			-- Yellow
			point.texture:SetVertexColor(0.97, 0.84, 0.1)
		else
			-- Gray
			point.texture:SetVertexColor(0.3,0.3,0.3)
		end
	end

	frame.fPCPFrame:Show()
	frame.fPCPFrame:ClearAllPoints()
	frame.fPCPFrame:SetPoint("TOP",frame,"BOTTOM",0,7)

	if MSQ then
		Group:ReSkin()
	end
end

function fPCP.UpdateAllNameplates()
	for i, p in ipairs(C_NamePlate_GetNamePlates()) do
		local unit = p.namePlateUnitToken
		if not unit then --try ElvUI
			unit = p.unitFrame and p.unitFrame.unit
		end
		if unit then
			UpdateUnitComboPoints(unit)
		end
	end
end
local UpdateAllNameplates = fPCP.UpdateAllNameplates

local function Nameplate_Added(...)
	local nameplateID = ...
	local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)
	if frame.UnitFrame and frame.UnitFrame.BuffFrame then
		if db.notHideOnPersonalResource and UnitIsUnit(nameplateID,"player") then
			frame.UnitFrame.BuffFrame:SetAlpha(1)
		else
			frame.UnitFrame.BuffFrame:SetAlpha(0)	--Hide terrible standart debuff frame
		end
	end

	UpdateUnitComboPoints(nameplateID)
end
local function Nameplate_Removed(...)
	local nameplateID = ...
	local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)

	if frame.fPCPFrame then
		frame.fPCPFrame:Hide()
	end
end

local function Initialize()
	fPCP.db = LibStub("AceDB-3.0"):New("flyPlateComboPointsDB", DefaultSettings, true)

	db = fPCP.db.profile
	fPCP.font = fPCP.LSM:Fetch("font", db.font)
end

function fPCP.RegisterCombat()
	fPCP.Events:RegisterEvent("PLAYER_REGEN_DISABLED")
	fPCP.Events:RegisterEvent("PLAYER_REGEN_ENABLED")
end
function fPCP.UnregisterCombat()
	fPCP.Events:UnregisterEvent("PLAYER_REGEN_DISABLED")
	fPCP.Events:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

fPCP.Events = CreateFrame("Frame")
fPCP.Events:RegisterEvent("ADDON_LOADED")
fPCP.Events:RegisterEvent("PLAYER_LOGIN")

fPCP.Events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" and (...) == AddonName then
		Initialize()
	elseif event == "PLAYER_LOGIN" then
		MSQ = LibStub("Masque", true)
		if MSQ then
			Group = MSQ:Group(AddonName)
			MSQ:Register(AddonName, function(addon, group, skinId, gloss, backdrop, colors, disabled)
				if disabled then
					UpdateAllNameplates(true)
				end
			end)
		end

		fPCP.Events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		fPCP.Events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		fPCP.Events:RegisterEvent("UNIT_AURA")
		fPCP.Events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")

	elseif event == "PLAYER_REGEN_DISABLED" then
		fPCP.Events:RegisterEvent("UNIT_AURA")
		UpdateAllNameplates()
	elseif event == "PLAYER_REGEN_ENABLED" then
		fPCP.Events:UnregisterEvent("UNIT_AURA")
		UpdateAllNameplates()
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		Nameplate_Added(...)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		Nameplate_Removed(...)
	elseif event == "UNIT_AURA" then
		if strmatch((...),"nameplate%d+") then
			UpdateUnitComboPoints(...)
		end
	elseif event == "UNIT_POWER_UPDATE" then
		UpdateAllNameplates()
	end
end)
