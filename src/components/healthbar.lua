---@class LibSlab
local Slab = LibStub("Slab")

local WIDTH = 152
local HEIGHT = 12

---stolen from plater
---@param unit UnitId
---@return integer
local function UnitNpcId(unit)
    local guid = UnitGUID(unit)
    if guid == nil then
        return 0
    end
    local npcID = select (6, strsplit ("-", guid))
    return tonumber (npcID or "0") or 0
end

Slab.UnitNpcId = UnitNpcId

---determine if a unit is a tank pet
---@param unit UnitId
---@return boolean
local function IsTankPet(unit)
    local npcId = UnitNpcId(unit)

    return
        npcId == 61146 -- ox statue
        or npcId == 103822 -- trees
        or npcId == 15352 -- earth ele
        or npcId == 95072 -- greater earth ele
        or npcId == 61056 -- primal earth ele
end

---@param unit UnitId
---@return boolean
local function IsTankPlayer(unit)
    local role = UnitGroupRolesAssigned(unit)
    return role == "TANK"
end

---determine if a unit is a tank player or pet
---@param unit UnitId
---@return boolean
local function IsTank(unit)
    return IsTankPlayer(unit) or IsTankPet(unit)
end

---determine if the player is a tank spec
---@return boolean
local function IsPlayerTank()
    return GetSpecializationRole(GetSpecialization()) == "TANK"
end

---Determine the appropriate saturation level to use for the source unit, based on threat.
---@param target UnitId
---@param source UnitId
---@return integer
local function threatSaturation(target, source)
    local threatStatus = UnitThreatSituation(target, source)
    if threatStatus == nil then return 1 end
    if IsPlayerTank() then
        if threatStatus == 1 or threatStatus == 2 then
            return 3
        elseif threatStatus == 0 and not IsTank(source .. "target") then
            return 6
        elseif threatStatus == 0 and IsTank(source .. 'target') then
            return 0.5
        end
    else
        if threatStatus == 1 then
            return 3
        elseif threatStatus > 1 then
            return 6
        end
    end
end

---@class HealthBarComponent:Component
---@field public frame HealthBar
local component = {
}

---@param settings SlabNameplateSettings
function component:refreshName(settings)
    local name = UnitName(settings.tag)
    if name == UNKNOWNOBJECT then
        local tag = settings.tag
        C_Timer.After(0.3, function()
            -- quick check to help avoid race conditions
            if tag ~= settings.tag then
                return
            end
            self.frame.name:SetText(UnitName(settings.tag))
        end)
    else
        self.frame.name:SetText(name)
    end
end

local function playerColor(unitName)
    local classKey = select(2, UnitClass(unitName))
    if classKey ~= nil then
        return C_ClassColor.GetClassColor(classKey)
    end
    return nil 
end

---@param settings SlabNameplateSettings
function component:refreshColor(settings)
    local color = nil
    if UnitIsPlayer(settings.tag) then
        color = playerColor(settings.tag)
    end
    if color == nil then
        local saturation = threatSaturation('player', settings.tag)
        color = Slab.color.point_to_color(settings.point, saturation)
    end
    self.frame:SetStatusBarColor(color.r, color.g, color.b)
end

---@param settings SlabNameplateSettings
function component:refreshHealth(settings)
    local unitId = settings.tag
    self.frame:SetMinMaxValues(0, UnitHealthMax(unitId))
    self.frame:SetValue(UnitHealth(unitId))
end

---@param settings SlabNameplateSettings
function component:refreshTargetMarker(settings)
    local markerId = GetRaidTargetIndex(settings.tag)
    local raidMarker = self.frame.raidMarker
    if markerId == nil then
        raidMarker:Hide()
    else
        local iconTexture = 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_' .. markerId
        raidMarker:SetTexture(iconTexture)
        raidMarker:Show()
    end
end

---@param settings SlabNameplateSettings
function component:refreshReaction(settings)
    local target = settings.tag .. 'target'
    local reaction = UnitReaction(settings.tag, 'player')
    local threatStatus = UnitThreatSituation('player', settings.tag)
    if reaction == 4 and threatStatus == nil then
        self.frame.reactionIndicator:SetText('N')
        -- stolen from plater
        self.frame.reactionIndicator:SetTextColor(0.9254901, 0.8, 0.2666666, 1)
        self.frame.reactionIndicator:Show()
    elseif IsTankPet(target) then
        self.frame.reactionIndicator:SetText('PET')
        self.frame.reactionIndicator:SetTextColor(0.75, 0.75, 0.5, 1)
        self.frame.reactionIndicator:Show()
    elseif not UnitIsUnit("player", target) and IsPlayerTank() and IsTankPlayer(target) then
        self.frame.reactionIndicator:SetText('CO')
        self.frame.reactionIndicator:SetTextColor(0.44, 0.81, 0.37, 1)
        self.frame.reactionIndicator:Show()
    else
        self.frame.reactionIndicator:Hide()
    end
end

---@param settings SlabNameplateSettings
function component:refreshPlayerTargetIndicator(settings)
    if UnitIsUnit('target', settings.tag) then
        self.frame.bg:SetAlpha(0.8)
        for _, pin in ipairs(self.frame.targetPins) do
            pin:Show()
        end
    else
        self.frame.bg:SetAlpha(0.5)
        for _, pin in ipairs(self.frame.targetPins) do
            pin:Hide()
        end
    end
end

---@param settings SlabNameplateSettings
function component:refresh(settings)
    self:refreshName(settings)
    self:refreshColor(settings)
    self:refreshHealth(settings)
    self:refreshTargetMarker(settings)
    self:refreshReaction(settings)
    self:refreshPlayerTargetIndicator(settings)
end

---@param settings SlabNameplateSettings
function component:bind(settings)
    self.frame:RegisterUnitEvent('UNIT_HEALTH', settings.tag)
    self.frame:RegisterUnitEvent('UNIT_THREAT_LIST_UPDATE', settings.tag)
    self.frame:RegisterUnitEvent('UNIT_NAME_UPDATE', settings.tag)
    self.frame:RegisterEvent('RAID_TARGET_UPDATE')
    self.frame:RegisterEvent('PLAYER_TARGET_CHANGED')
end

---@param eventName string
---@vararg any
function component:update(eventName, ...)
    if eventName == 'UNIT_HEALTH' then
        self:refreshHealth(self.settings)
    elseif eventName == 'UNIT_THREAT_LIST_UPDATE' then
        self:refreshColor(self.settings)
        self:refreshReaction(self.settings)
    elseif eventName == 'RAID_TARGET_UPDATE' then
        self:refreshTargetMarker(self.settings)
    elseif eventName == 'PLAYER_TARGET_CHANGED' then
        self:refreshPlayerTargetIndicator(self.settings)
    elseif eventName == 'UNIT_NAME_UPDATE' then
        self:refreshName(self.settings)
    end
end

local function buildTargetPins(frame)
    -- coords stolen from plater, but i suppose they're just fundamental to the texture
    local coords = {{145/256, 161/256, 3/256, 19/256}, {145/256, 161/256, 19/256, 3/256}, {161/256, 145/256, 19/256, 3/256}, {161/256, 145/256, 3/256, 19/256}}
    local positions = {"TOPLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOPRIGHT"}
    local offsets = {{-2, 2}, {-2, -2}, {2, -2}, {2, 2}}

    local pins = {}
    for i = 1, 4 do
        local pin = frame:CreateTexture(frame:GetName() .. "TargetPin" .. i, 'OVERLAY')
        pin:SetTexture([[Interface\ITEMSOCKETINGFRAME\UI-ItemSockets]])
        pin:SetTexCoord(unpack(coords[i]))
        pin:SetPoint(positions[i], frame, positions[i], unpack(offsets[i]))
        pin:SetSize(4, 4)
        pin:Hide()
        pins[i] = pin
    end

    return pins
end

---@param parent Frame
---@return HealthBar
function component:build(parent)
    ---@class HealthBar:StatusBar
    local healthBar = CreateFrame('StatusBar', parent:GetName() .. 'HealthBar', parent)

    healthBar:SetStatusBarTexture('interface/addons/Slab/resources/textures/healthbar')
    healthBar:SetStatusBarColor(1, 1, 1, 1)
    healthBar:SetSize(Slab.scale(WIDTH), Slab.scale(HEIGHT))
    healthBar:SetPoint('CENTER')

    local bg = healthBar:CreateTexture(healthBar:GetName() .. 'Background', 'BACKGROUND')
    bg:SetTexture('interface/buttons/white8x8')
    bg:SetVertexColor(0.01, 0, 0, 0.5)
    bg:SetPoint('TOPLEFT', healthBar, 'TOPLEFT', 0, 0)
    bg:SetPoint('BOTTOMRIGHT', healthBar, 'BOTTOMRIGHT', 0, 0)

    local raidMarker = healthBar:CreateTexture(healthBar:GetName() .. 'RaidMarker', 'OVERLAY')
    raidMarker:SetPoint('LEFT', healthBar, 'LEFT', 2, 0)
    raidMarker:SetSize(Slab.scale(HEIGHT) - 2, Slab.scale(HEIGHT) - 2)
    raidMarker:Hide()

    local name = healthBar:CreateFontString(healthBar:GetName() .. 'NameText', 'OVERLAY')
    name:SetPoint('BOTTOM', healthBar, 'TOP', 0, 2)
    name:SetFont(Slab.font, Slab.scale(8), "OUTLINE")

    local reactionIndicator = healthBar:CreateFontString(healthBar:GetName() .. 'IndicatorText', 'OVERLAY')
    reactionIndicator:SetPoint('BOTTOMLEFT', healthBar, 'TOPLEFT', 0, 2)
    reactionIndicator:SetFont(Slab.font, Slab.scale(7), "OUTLINE")
    reactionIndicator:Hide()

    local pins = buildTargetPins(healthBar)

    healthBar.raidMarker = raidMarker
    healthBar.bg = bg
    healthBar.name = name
    healthBar.reactionIndicator = reactionIndicator
    healthBar.targetPins = pins

    return healthBar
end

Slab.RegisterComponent('healthBar', component)