--[[

	The MIT License (MIT)

	Copyright (c) 2022 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...
local UnitStyles = ns.UnitStyles
if (not UnitStyles) then
	return
end

-- Lua API
local string_gsub = string.gsub
local unpack = unpack

-- WoW API
local UnitClass = UnitClass
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsUnit = UnitIsUnit
local UnitPowerType = UnitPowerType

-- Addon API
local Colors = ns.Colors
local Config = ns.Config
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

-- Constants
local playerClass = ns.PlayerClass

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
end

-- Update the health preview color on health color updates.
local Health_PostUpdateColor = function(element, unit, r, g, b)
	local preview = element.Preview
	if (preview) then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

-- Align our custom health prediction texture
-- based on the plugin's provided values.
local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)

	local allIncomingHeal = myIncomingHeal + otherIncomingHeal
	local allNegativeHeals = healAbsorb
	local showPrediction, change

	if ((allIncomingHeal > 0) or (allNegativeHeals > 0)) and (maxHealth > 0) then
		local startPoint = curHealth/maxHealth

		-- Dev switch to test absorbs with normal healing
		--allIncomingHeal, allNegativeHeals = allNegativeHeals, allIncomingHeal

		-- Hide predictions if the change is very small, or if the unit is at max health.
		change = (allIncomingHeal - allNegativeHeals)/maxHealth
		if ((curHealth < maxHealth) and (change > (element.health.predictThreshold or .05))) then
			local endPoint = startPoint + change

			-- Crop heal prediction overflows
			if (endPoint > 1) then
				endPoint = 1
				change = endPoint - startPoint
			end

			-- Crop heal absorb overflows
			if (endPoint < 0) then
				endPoint = 0
				change = -startPoint
			end

			-- This shouldn't happen, but let's do it anyway.
			if (startPoint ~= endPoint) then
				showPrediction = true
			end
		end
	end

	if (showPrediction) then

		local preview = element.preview
		local growth = preview:GetGrowth()
		local min,max = preview:GetMinMaxValues()
		local value = preview:GetValue() / max
		local previewTexture = preview:GetStatusBarTexture()
		local previewWidth, previewHeight = preview:GetSize()
		local left, right, top, bottom = preview:GetTexCoord()
		local isFlipped = preview:IsFlippedHorizontally()

		if (growth == "RIGHT") then

			local texValue, texChange = value, change
			local rangeH, rangeV

			rangeH = right - left
			rangeV = bottom - top
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end

		elseif (growth == "LEFT") then
			local texValue, texChange = value, change
			local rangeH, rangeV
			rangeH = right - left
			rangeV = bottom - top
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end
		end
	else
		element:Hide()
	end

	local absorb = element.Absorb
	if (absorb) then
		local fraction = absorb/maxHealth
		if (fraction > .6) then
			absorb = maxHealth * .6
		end
		absorb:SetMinMaxValues(0, maxHealth)
		absorb:SetValue(absorb)
	end

end

local Power_PostUpdate = function(element, unit, cur, min, max)

	local shouldShow = not UnitHasVehicleUI("player") and UnitPowerType(unit) == Enum.PowerType.Mana

	if (not shouldShow or cur == 0 or max == 0) then
		element:SetAlpha(0)
	else
		local _,class = UnitClass(unit)
		if (class == "DRUID" or class == "PALADIN" or class == "PRIEST" or class == "SHAMAN") then
			if (cur/max < .9) then
				element:SetAlpha(.75)
			else
				element:SetAlpha(0)
			end
		elseif (class == "MAGE" or class == "WARLOCK") then
			if (cur/max < .5) then
				element:SetAlpha(.75)
			else
				element:SetAlpha(0)
			end
		else
			-- The threshold for the "oom" message is .25 (not yet added!)
			if (cur/max < .25) then
				element:SetAlpha(.75)
			else
				element:SetAlpha(0)
			end
		end
	end
end

-- Custom Group Role updater
local GroupRoleIndicator_Override = function(self, event)
	local element = self.GroupRoleIndicator

	--[[ Callback: GroupRoleIndicator:PreUpdate()
	Called before the element has been updated.

	* self - the GroupRoleIndicator element
	--]]
	if (element.PreUpdate) then
		element:PreUpdate()
	end

	local role = UnitGroupRolesAssigned(self.unit)
	if (role and element[role]) then
		element.Icon:SetTexture(element[role])
		element:Show()
	else
		element:Hide()
	end

	--[[ Callback: GroupRoleIndicator:PostUpdate(role)
	Called after the element has been updated.

	* self - the GroupRoleIndicator element
	* role - the role as returned by [UnitGroupRolesAssigned](http://wowprogramming.com/docs/api/UnitGroupRolesAssigned.html)
	--]]
	if (element.PostUpdate) then
		return element:PostUpdate(role)
	end
end

-- Make the portrait look better for offline or invisible units.
local Portrait_PostUpdate = function(element, unit, hasStateChanged)
	if (not element.state) then
		element:ClearModel()
		if (not element.fallback2DTexture) then
			element.fallback2DTexture = element:CreateTexture()
			element.fallback2DTexture:SetDrawLayer("ARTWORK")
			element.fallback2DTexture:SetAllPoints()
			element.fallback2DTexture:SetTexCoord(.1, .9, .1, .9)
		end
		SetPortraitTexture(element.fallback2DTexture, unit)
		element.fallback2DTexture:Show()
	else
		if (element.fallback2DTexture) then
			element.fallback2DTexture:Hide()
		end
		element:SetCamDistanceScale(element.distanceScale or 1)
		element:SetPortraitZoom(1)
		element:SetPosition(element.positionX or 0, element.positionY or 0, element.positionZ or 0)
		element:SetRotation(element.rotation and element.rotation*degToRad or 0)
		element:ClearModel()
		element:SetUnit(unit)
		element.guid = guid
	end
end

-- Update targeting highlight outline
local TargetHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetHighlight
	unit = unit or self.unit

	if (UnitIsUnit(unit, "target")) then
		element:SetVertexColor(unpack(element.colorTarget))
		element:Show()
	elseif (UnitIsUnit(unit, "focus")) then
		element:SetVertexColor(unpack(element.colorFocus))
		element:Show()
	else
		element:Hide()
	end
end

local UnitFrame_PostUpdate = function(self)
	TargetHighlight_Update(self)
end

-- Frame Script Handlers
--------------------------------------------
local OnEvent = function(self, event, unit, ...)
	UnitFrame_PostUpdate(self)
end

UnitStyles["Party"] = function(self, unit, id, ...)

	local db = ns.Config.Party

	--self:SetSize(unpack(db.PartySize))
	self:SetHitRectInsets(unpack(db.PartyHitRectInsets))
	--self:SetFrameLevel(self:GetFrameLevel() + 10)

	-- Overlay for icons and text
	--------------------------------------------
	local overlay = CreateFrame("Frame", nil, self)
	overlay:SetFrameLevel(self:GetFrameLevel() + 7)
	overlay:SetAllPoints()

	self.Overlay = overlay

	-- Health
	--------------------------------------------
	local health = self:CreateBar()
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:SetPoint(unpack(db.HealthBarPosition))
	health:SetSize(unpack(db.HealthBarSize))
	health:SetStatusBarTexture(db.HealthBarTexture)
	health:SetOrientation(db.HealthBarOrientation)
	health:SetSparkMap(db.HealthBarSparkMap)
	health.predictThreshold = .01
	health.colorDisconnected = true
	health.colorClass = true
	health.colorClassPet = true
	health.colorReaction = true
	health.colorHealth = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(overlay:GetFrameLevel())
	healthOverlay:SetAllPoints()

	self.Health.Overlay = healthOverlay

	local healthBackdrop = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)
	healthBackdrop:SetVertexColor(unpack(db.HealthBackdropColor))

	self.Health.Backdrop = healthBackdrop

	local healthPreview = self:CreateBar(nil, health)
	healthPreview:SetAllPoints(health)
	healthPreview:SetFrameLevel(health:GetFrameLevel() - 1)
	healthPreview:SetStatusBarTexture(db.HealthBarTexture)
	healthPreview:SetOrientation(db.HealthBarOrientation)
	healthPreview:SetSparkTexture("")
	healthPreview:SetAlpha(.5)
	healthPreview:DisableSmoothing(true)

	self.Health.Preview = healthPreview

	-- Health Prediction
	--------------------------------------------
	local healPredictFrame = CreateFrame("Frame", nil, health)
	healPredictFrame:SetFrameLevel(health:GetFrameLevel() + 2)

	local healPredict = healPredictFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	healPredict:SetTexture(db.HealthBarTexture)
	healPredict.health = health
	healPredict.preview = healthPreview
	healPredict.maxOverflow = 1

	self.HealthPrediction = healPredict
	self.HealthPrediction.PostUpdate = HealPredict_PostUpdate

	-- Cast Overlay
	--------------------------------------------
	local castbar = self:CreateBar()
	castbar:SetAllPoints(health)
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:SetSparkMap(db.HealthBarSparkMap)
	castbar:SetStatusBarTexture(db.HealthBarTexture)
	castbar:SetStatusBarColor(unpack(db.HealthCastOverlayColor))
	castbar:DisableSmoothing(true)

	self.Castbar = castbar

	-- Health Value
	--------------------------------------------
	local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	healthValue:SetPoint(unpack(db.HealthValuePosition))
	healthValue:SetFontObject(db.HealthValueFont)
	healthValue:SetTextColor(unpack(db.HealthValueColor))
	healthValue:SetJustifyH(db.HealthValueJustifyH)
	healthValue:SetJustifyV(db.HealthValueJustifyV)
	self:Tag(healthValue, prefix("[*:Health(true, nil, nil, true)]"))

	self.Health.Value = healthValue

	-- Power
	--------------------------------------------
	local power = self:CreateBar()
	power:SetFrameLevel(health:GetFrameLevel() + 2)
	power:SetPoint(unpack(db.PowerBarPosition))
	power:SetSize(unpack(db.PowerBarSize))
	power:SetStatusBarTexture(db.PowerBarTexture)
	power:SetOrientation(db.PowerBarOrientation)
	power.frequentUpdates = true
	power.colorPower = true

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	self.Power.PostUpdate = Power_PostUpdate

	local powerBackdrop = power:CreateTexture(nil, "BACKGROUND", nil, -2)
	powerBackdrop:SetPoint(unpack(db.PowerBackdropPosition))
	powerBackdrop:SetSize(unpack(db.PowerBackdropSize))
	powerBackdrop:SetTexture(db.PowerBackdropTexture)
	powerBackdrop:SetVertexColor(unpack(db.PowerBackdropColor))

	self.Power.Backdrop = powerBackdrop

	-- Portrait
	--------------------------------------------
	local portraitFrame = CreateFrame("Frame", nil, self)
	portraitFrame:SetFrameLevel(self:GetFrameLevel() - 2)
	portraitFrame:SetAllPoints()

	local portrait = CreateFrame("PlayerModel", nil, portraitFrame)
	portrait:SetFrameLevel(portraitFrame:GetFrameLevel())
	portrait:SetPoint(unpack(db.PortraitPosition))
	portrait:SetSize(unpack(db.PortraitSize))
	portrait:SetAlpha(db.PortraitAlpha)
	portrait.distanceScale = db.PortraitDistanceScale
	portrait.positionX = db.PortraitPositionX
	portrait.positionY = db.PortraitPositionY
	portrait.positionZ = db.PortraitPositionZ
	portrait.rotation = db.PortraitRotation
	portrait.showFallback2D = db.PortraitShowFallback2D

	self.Portrait = portrait
	self.Portrait.PostUpdate = Portrait_PostUpdate

	local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	portraitBg:SetPoint(unpack(db.PortraitBackgroundPosition))
	portraitBg:SetSize(unpack(db.PortraitBackgroundSize))
	portraitBg:SetTexture(db.PortraitBackgroundTexture)
	portraitBg:SetVertexColor(unpack(db.PortraitBackgroundColor))

	self.Portrait.Bg = portraitBg

	local portraitOverlayFrame = CreateFrame("Frame", nil, self)
	portraitOverlayFrame:SetFrameLevel(self:GetFrameLevel() - 1)
	portraitOverlayFrame:SetAllPoints()

	local portraitShade = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
	portraitShade:SetPoint(unpack(db.PortraitShadePosition))
	portraitShade:SetSize(unpack(db.PortraitShadeSize))
	portraitShade:SetTexture(db.PortraitShadeTexture)

	self.Portrait.Shade = portraitShade

	local portraitBorder = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	portraitBorder:SetPoint(unpack(db.PortraitBorderPosition))
	portraitBorder:SetSize(unpack(db.PortraitBorderSize))
	portraitBorder:SetTexture(db.PortraitBorderTexture)
	portraitBorder:SetVertexColor(unpack(db.PortraitBorderColor))

	self.Portrait.Border = portraitBorder

	-- Absorb Bar (Retail)
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)
		absorb:SetStatusBarTexture(db.HealthBarTexture)
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
		absorb:SetSparkMap(db.HealthBarSparkMap)

		local orientation
		if (db.HealthBarOrientation == "UP") then
			orientation = "DOWN"
		elseif (db.HealthBarOrientation == "DOWN") then
			orientation = "UP"
		elseif (db.HealthBarOrientation == "LEFT") then
			orientation = "RIGHT"
		else
			orientation = "LEFT"
		end
		absorb:SetOrientation(orientation)

		self.Health.Absorb = absorb
	end

	-- Readycheck
	--------------------------------------------
	local readyCheckIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
	readyCheckIndicator:SetSize(unpack(db.ReadyCheckSize))
	readyCheckIndicator:SetPoint(unpack(db.ReadyCheckPosition))
	readyCheckIndicator.readyTexture = db.ReadyCheckReadyTexture
	readyCheckIndicator.notReadyTexture = db.ReadyCheckNotReadyTexture
	readyCheckIndicator.waitingTexture = db.ReadyCheckWaitingTexture

	self.ReadyCheckIndicator = ReadyCheckIndicator

	-- Ressurection Indicator
	--------------------------------------------
	local resurrectIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
	resurrectIndicator:SetSize(unpack(db.ResurrectIndicatorSize))
	resurrectIndicator:SetPoint(unpack(db.ResurrectIndicatorPosition))
	resurrectIndicator:SetTexture(ResurrectIndicatorTexture)

	self.ResurrectIndicator = resurrectIndicator

	-- Group Role
	-----------------------------------------
    local groupRoleIndicator = CreateFrame("Frame", nil, overlay)
	groupRoleIndicator:SetSize(unpack(db.GroupRoleSize))
	groupRoleIndicator:SetPoint(unpack(db.GroupRolePosition))
	groupRoleIndicator.DAMAGER = db.GroupRoleDPSTexture
	groupRoleIndicator.HEALER = db.GroupRoleHealerTexture
	groupRoleIndicator.TANK = db.GroupRoleTankTexture
	--groupRoleIndicator.NONE = groupRoleIndicator.DAMAGER -- fallback

	local groupRoleBackdrop = groupRoleIndicator:CreateTexture(nil, "BACKGROUND", nil, 1)
	groupRoleBackdrop:SetSize(unpack(db.GroupRoleBackdropSize))
	groupRoleBackdrop:SetPoint(unpack(db.GroupRoleBackdropPosition))
	groupRoleBackdrop:SetTexture(db.GroupRoleBackdropTexture)
	groupRoleBackdrop:SetVertexColor(unpack(db.GroupRoleBackdropColor))

	groupRoleIndicator.Backdrop = groupRoleBackdrop

	local groupRoleIcon = groupRoleIndicator:CreateTexture(nil, "ARTWORK", nil, 1)
	groupRoleIcon:SetSize(unpack(db.GroupRoleIconSize))
	groupRoleIcon:SetPoint(unpack(db.GroupRoleIconPositon))

	groupRoleIndicator.Icon = groupRoleIcon

    self.GroupRoleIndicator = groupRoleIndicator
	self.GroupRoleIndicator.Override = GroupRoleIndicator_Override

	-- CombatFeedback Text
	--------------------------------------------
	local feedbackText = overlay:CreateFontString(nil, "OVERLAY")
	feedbackText:SetPoint(db.CombatFeedbackPosition[1], self[db.CombatFeedbackAnchorElement], unpack(db.CombatFeedbackPosition))
	feedbackText:SetFontObject(db.CombatFeedbackFont)
	feedbackText.feedbackFont = db.CombatFeedbackFont
	feedbackText.feedbackFontLarge = db.CombatFeedbackFontLarge
	feedbackText.feedbackFontSmall = db.CombatFeedbackFontSmall

	self.CombatFeedback = feedbackText

	-- Target Highlight
	--------------------------------------------
	local targetHighlight = overlay:CreateTexture(nil, "BACKGROUND", nil, -2)
	targetHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	targetHighlight:SetSize(unpack(db.TargetHighlightSize))
	targetHighlight:SetTexture(db.TargetHighlightTexture)
	targetHighlight.colorTarget = db.TargetHighlightTargetColor
	targetHighlight.colorFocus = db.TargetHighlightFocusColor

	self.TargetHighlight = targetHighlight

	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras:SetSize(unpack(db.AurasSize))
	auras:SetPoint(unpack(db.AurasPosition))
	auras.size = db.AuraSize
	auras.spacing = db.AuraSpacing
	auras.numTotal = db.AurasNumTotal
	auras.disableMouse = db.AurasDisableMouse
	auras.disableCooldown = db.AurasDisableCooldown
	auras.onlyShowPlayer = db.AurasOnlyShowPlayer
	auras.showStealableBuffs = db.AurasShowStealableBuffs
	auras.initialAnchor = db.AurasInitialAnchor
	auras["spacing-x"] = db.AurasSpacingX
	auras["spacing-y"] = db.AurasSpacingY
	auras["growth-x"] = db.AurasGrowthX
	auras["growth-y"] = db.AurasGrowthY
	auras.tooltipAnchor = db.AurasTooltipAnchor
	auras.sortMethod = db.AurasSortMethod
	auras.sortDirection = db.AurasSortDirection
	auras.reanchorIfVisibleChanged = true
	auras.CreateButton = ns.AuraStyles.CreateButton
	auras.PostUpdateButton = ns.AuraStyles.TargetPostUpdateButton
	auras.CustomFilter = ns.AuraFilters.TargetAuraFilter
	auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
	auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail

	self.Auras = auras

	-- Range Alpha
	--------------------------------------------
	self.Range = {
		insideAlpha = 1,
		outsideAlpha = db.OutOfRangeAlpha,
	}

	-- Add a callback for external style overriders
	self:AddForceUpdate(UnitFrame_PostUpdate)

	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", OnEvent, true)

end
