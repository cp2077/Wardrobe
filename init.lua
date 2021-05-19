local Wardrobe = { version = "1.3.0" }

--[[
TODO:
1. "unlock" quest item unequipment
2. wear clothing from stash
]]

local Helpers = require("Modules/Helpers")
local Config = require("Modules/Config")
local Window = require("Modules/Window")
local Cron = require("Modules/Cron")
local AttachmentSlot = require("Modules/AttachmentSlot")

local isReady = false
local isInited = false
local lastToggled = 0
function SetReady(ready) isReady = ready end
function IsReady() return isReady end

local messageController = nil
function ShowMessage(text)
	if messageController then
		local message = NewObject('gameSimpleScreenMessage')
		message.isShown = true
		message.duration = 3.0
		message.message = text

		messageController.screenMessage = message
		messageController:UpdateWidgets()
	end
end

function DeleteOutfit(id)
    local filteredOutfits = {}
    for _, outfit in pairs(Config.data.outfits) do
        if outfit.id ~= id then
            table.insert(filteredOutfits, outfit)
        end
    end
    Config.data.outfits = filteredOutfits
    Config.SaveConfig()
end

local lastSearchString = nil
local outfitsFilteredCache = nil

function MoveOutfit(id, n)
    local outfitIndex = 0
    local curOutfit = nil
    for i, outfit in pairs(Config.data.outfits) do
        if outfit.id == id then
            curOutfit = outfit
            table.remove(Config.data.outfits, i)
            outfitIndex = i
            lastSearchString = nil
            outfitsFilteredCache = nil
            break
        end
    end
    if outfitIndex > 0 then
        table.insert(Config.data.outfits, math.max(1, math.min(#Config.data.outfits, (outfitIndex + n))), curOutfit)
        Config.SaveConfig()
    end

end

function SaveCurrentOutfit(name)
    if name == nil or name == "" then
        name = "Unnamed Outfit"
    end

    local outfitSet = Helpers.GetCurrentOutfitSet()
    local id = tostring(#Config.data.outfits + 1 + os.time()) .. name .. tostring(#outfitSet) .. tostring(math.random())
    local outfit = {
        ["set"] = outfitSet,
        ["name"] = name,
        ["created"] = os.time(),
        ["isFemale"] = Helpers.IsFemale(),
        ["id"] = id,
    }
    table.insert(Config.data.outfits, 1, outfit)
    Config.SaveConfig()
end

function ApplyOutfit(outfit)
    if outfit == nil then
        return
    end

    return Helpers.ApplyOutfit(outfit)
end

function ListOutfits()
    return Config.data.outfits
end

function OutfitsSearched()
    local searchString = Window.searchInput

    if searchString == lastSearchString and outfitsFilteredCache ~= nil then
        return outfitsFilteredCache
    end

    local outfits = ListOutfits()
    local outfitsFiltered = {}

    for _, outfit in pairs(outfits) do
        if string.find(outfit.name:lower():gsub(" ", ""), searchString:lower():gsub(" ", "")) then
            table.insert(outfitsFiltered, outfit)
        end
    end

    lastSearchString = searchString
    outfitsFilteredCache = outfitsFiltered

    return outfitsFiltered
end

function ListOutfitsByGender(isFemale)
    if isFemale == nil then
        isFemale = false
    end
    local outfits = {}
    for _, outfit in pairs(ListOutfits()) do
        if outfit.isFemale == isFemale then
            table.insert(outfits, outfit)
        end
    end

    return outfits
end

local isOverlayOpen = false
local isInInventory = false
local isInMenu = false

local photoPuppetComponent = nil

function Wardrobe:Init()
    registerForEvent("onInit", function ()

        -- Observe('Stash', 'GetDevicePS', function(self)
        --     print("GetDevicePS")
        --     if self:GetEntityID().hash == 16570246047455160070ULL then
        --         Helpers.stashEntity = Game.FindEntityByID(self:GetEntityID())
        --     end
        -- end)

        Observe("gameuiMenuItemListGameController", "OnInitialize", function()
            isInMenu = true
        end)
        Observe("gameuiMenuItemListGameController", "OnUninitialize", function()
            isInMenu = false
        end)
        Observe('RadialWheelController', 'RegisterBlackboards', function(_, loaded)
            Helpers.ResetLastClothing()
            SetReady(loaded)
        end)
        Observe('gameuiInventoryGameController', 'OnInitialize', function()
            isInInventory = true
            SetReady(true)
        end)
        Observe('gameuiInventoryGameController', 'OnUninitialize', function()
            isInInventory = false
            SetReady(true)
        end)

        Observe('PhotoModePlayerEntityComponent', 'ListAllItems', function(self)
            photoPuppetComponent = self
            SetReady(true)
        end)

        Observe('gameuiPhotoModeMenuController', 'OnHide', function()
            photoPuppetComponent = nil
            SetReady(true)
        end)

        Observe('OnscreenMessageGameController', 'CreateAnimations', function(self)
            messageController = self
        end)

        Config.InitConfig()
        isInited = true

        Cron.Every(0.12, { tick = 1 }, function()
            if Helpers.UnequipAllIter ~= nil then
                local called =  Helpers.UnequipAllIter(function(slotName)
                    -- we don't have to take off underwear when undressing
                    if slotName == AttachmentSlot.UNDERWEARTOP or slotName == AttachmentSlot.UNDERWEARBOTTOM then
                        return
                    end

                    Helpers.UnequipSlot(slotName, photoPuppetComponent)
                end)
                if not called then
                    Helpers.UnequipAllIter = nil
                end
            elseif Helpers.EquipAllIter ~= nil then
                local called =  Helpers.EquipAllIter(function(slot)
                    if slot == AttachmentSlot.UNDERWEARTOP or slot == AttachmentSlot.UNDERWEARBOTTOM then
                        return
                    end

                    local desTweakDBID = DeserializeTweakDB(slot.serTweakDBID)
                    local itemID = GetItemIDFromInventory(desTweakDBID)

                    if itemID ~= nil then
                        Helpers.EquipItem(itemID, photoPuppetComponent)
                    end
                end)
                if not called then
                    Helpers.EquipAllIter = nil
                    ShowMessage("Outfit has been changed")
                end
            end
        end)

    end)
    registerForEvent("onOverlayOpen", function () isOverlayOpen = true end)
    registerForEvent("onOverlayClose", function () isOverlayOpen = false end)

    registerForEvent("onDraw", function ()
        if not isInited then
            return
        end
        if not isOverlayOpen then
            return
        end

        local function onOutfitSelected(outfit)
            Helpers.ApplyOutfit(outfit)
            lastSearchString = nil
        end

        local function onOutfitSave(name)
            SaveCurrentOutfit(name)
            lastSearchString = nil
        end

        local function onOutfitDelete(id)
            DeleteOutfit(id)
            lastSearchString = nil
        end

        local function onOutfitMove(id, offset)
            MoveOutfit(id, offset)
        end

        local function onSlotTakeOff(slot, alt_name)
            Helpers.ToggleClothing(slot, photoPuppetComponent, alt_name)
            lastToggled = Game.GetEngineTime():ToFloat(Game.GetEngineTime())
        end

        local function onToggleUnderwear(slot)
            Helpers.ToggleUnderwear(slot, photoPuppetComponent)
            lastToggled = Game.GetEngineTime():ToFloat(Game.GetEngineTime())
        end


        local function onUnlockEveryItem()
            Helpers.UnlockEveryItem()
        end

        local isUndressing = Helpers.UnequipAllIter ~= nil
        local isDressing = Helpers.EquipAllIter ~= nil

        local canToggleClothing = (Game.GetEngineTime():ToFloat(Game.GetEngineTime()) - lastToggled) >= 0.5
        local function hasItemInSlot(slot)
            return GetItemIDInSlot(slot) ~= nil
        end
        local function hasSavedToggleClothing(slot)
            return LastClothing[slot] ~= nil
        end
        Window.Draw(
            OutfitsSearched(),
            Helpers.IsFemale(),
            onOutfitSelected,
            onOutfitSave,
            onOutfitDelete,
            onOutfitMove,
            onUnlockEveryItem,
            onSlotTakeOff,
            onToggleUnderwear,
            hasItemInSlot,
            hasSavedToggleClothing,
            isUndressing,
            isDressing,
            IsReady(),
            isInInventory,
            isInMenu,
            canToggleClothing
        )
    end)
    registerForEvent('onUpdate', function(delta)
        Cron.Update(delta)
    end)

    for var=1,6 do
        registerHotkey("outfit_" .. var, "Select outfit number " .. var, function()
            local isUndressing = Helpers.UnequipAllIter ~= nil
            local isDressing = Helpers.EquipAllIter ~= nil

            if isInInventory or not isInited or isInMenu or not isReady or isDressing or isUndressing then
                return
            end

            ApplyOutfit(Config.data.outfits[var])
        end)
    end
end

return Wardrobe:Init()
