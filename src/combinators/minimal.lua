---Disable some expensive components for spammy enemies like Chaotic Motes or Fiendish Souls

---@class LibSlab
local Slab = LibStub("Slab")

local npcBlacklist = {
    [183669] = true, -- Fiendish Souls
    [189707] = true, -- Chaotic Motes
    [167999] = true, -- Echo of Sin
    [182053] = true, -- Degeneration Automata
}

---comment
---@param baseComponent ComponentConstructor
---@return ComponentConstructor
local function disable_minimal(baseComponent)
    local component = {}
    setmetatable(component, { __index = baseComponent })

    function component:bind(settings)
        if npcBlacklist[Slab.UnitNpcId(settings.tag)] then
            self.minimalMode = true
            return
        else
            self.minimalMode = false
            baseComponent.bind(self, settings)
        end
    end

    function component:refresh(settings)
        if npcBlacklist[Slab.UnitNpcId(settings.tag)] or self.minimalMode then
            return
        end
        baseComponent.refresh(self, settings)
    end
    return component
end

Slab.combinators.disable_minimal = Slab.combinator(disable_minimal)