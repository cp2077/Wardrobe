local AttachmentSlot = require("Modules/AttachmentSlot")

local Helpers = {
    UnequipAllIter = nil,
    EquipAllIter = nil,
    stashEntity = nil,
    photoPuppet = nil,
    photoPuppetComponent = nil,
}

function GetUnderwearBottom()
    local gameItemID = GetSingleton('gameItemID')
    return gameItemID:FromTDBID("Items.Underwear_Basic_01_Bottom")
end
function GetUnderwearTop()
    local gameItemID = GetSingleton('gameItemID')
    return gameItemID:FromTDBID("Items.Underwear_Basic_01_Top")
end


function GetItemIDInSlotOfPuppet(slotName)
    local ts = Game.GetTransactionSystem()
    if Helpers.photoPuppet == nil or ts == nil then
        return nil
    end
    local attachment = TweakDBID.new("AttachmentSlots." .. slotName)
    local slot = ts:GetItemInSlot(Helpers.photoPuppet, attachment)
    if slot == nil then
        return nil
    end

    return slot:GetItemData():GetID()
end

function GetItemIDInSlot(slotName)
    local player = Game.GetPlayer()
    local ts = Game.GetTransactionSystem()
    if player == nil or ts == nil then
        return nil
    end
    local attachment = TweakDBID.new("AttachmentSlots." .. slotName)
    local slot = ts:GetItemInSlot(player, attachment)
    if slot == nil then
        return nil
    end

    return slot:GetItemData():GetID()
end

LastClothing = {}
function Helpers.ResetLastClothing()
    LastClothing = {}
end
function Helpers.ToggleClothing(slot, slot_alt_name)
    -- some items like OUTERCHEST has alternative names like TORSO,
    -- and they used for photo mode puppet and not always used for base player puppet.

    if slot_alt_name == nil then
        slot_alt_name = "UNDEFINED"
    end

    local hasSavedClothing = LastClothing[slot] ~= nil or LastClothing[slot_alt_name] ~= nil
    local hasClothingInSlot = GetItemIDInSlot(slot) ~= nil or GetItemIDInSlot(slot_alt_name)

    if not hasSavedClothing or hasClothingInSlot then
        local itemInSlot = GetItemIDInSlot(slot) or GetItemIDInSlot(slot_alt_name)
        Helpers.UnequipSlot(slot)
        Helpers.UnequipSlot(slot_alt_name)
        if itemInSlot ~= nil then
            LastClothing[slot] = itemInSlot
            LastClothing[slot_alt_name] = itemInSlot
            Helpers.UnequipSlot(slot)
            Helpers.UnequipSlot(slot_alt_name)
        end
    else
        Helpers.EquipItem(LastClothing[slot])
        Helpers.EquipItem(LastClothing[slot_alt_name])
        LastClothing[slot] = nil
        LastClothing[slot_alt_name] = nil
    end

end

function Helpers.PutOnBra()
    if not Helpers.IsFemale() then
        return
    end

    local ts = Game.GetTransactionSystem()
    local underwear = GetUnderwearTop()
    if not ts:HasItem(Game.GetPlayer(), underwear) then
        ts:GiveItem(Game.GetPlayer(), underwear, 1)
    end
    Helpers.EquipItem(underwear)
end

function Helpers.ToggleUnderwear(slot)
    local ts = Game.GetTransactionSystem()
    if slot == AttachmentSlot.UNDERWEARTOP and not Helpers.IsFemale() then
        return
    end

    local underwear = slot == AttachmentSlot.UNDERWEARBOTTOM and GetUnderwearBottom() or GetUnderwearTop()

    if GetItemIDInSlot(slot) ~= nil then
        Helpers.UnequipSlot(slot)
    else
        if not ts:HasItem(Game.GetPlayer(), underwear) then
            ts:GiveItem(Game.GetPlayer(), underwear, 1)
        end
        Helpers.EquipItem(underwear)
    end
end

function GetTweakDBIDInSlot(slotName)
    local legsItemID = GetItemIDInSlot(slotName)
    if legsItemID == nil then
        return nil
    end

    return legsItemID.id
end
function GetSerializedItemInSlot(slotName)
    local tdbid = GetTweakDBIDInSlot(slotName)
    if tdbid == nil then
        return nil
    end
    return SerializeTweakDB(tdbid)
end

function SerializeTweakDB(tweakDBID)
    return { ["hash"] = tweakDBID.hash, ["length"] = tweakDBID.length }
end
function DeserializeTweakDB(tweakDBIDTable)
    local customTDBID = ToTweakDBID({})
    customTDBID.hash = tweakDBIDTable.hash
    customTDBID.length = tweakDBIDTable.length
    return customTDBID
end

function Helpers.UnequipSlot(slotName)
    Game.UnequipItem(slotName, "0")
    if Helpers.photoPuppet then
        local itemID = GetItemIDInSlotOfPuppet(slotName)
        if itemID then
            Game.GetTransactionSystem():RemoveItem(Helpers.photoPuppet, itemID, 1)
        end
    end
end

function Helpers.EquipItem(itemID)
    Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem")):GetPlayerData(Game.GetPlayer()):EquipItem(itemID, false, false, false)
    if Helpers.photoPuppetComponent then
        Helpers.photoPuppetComponent:PutOnFakeItem(itemID)
    end
end

function GetItemIDFromStash(tweakDBID)
    if not Helpers.stashEntity then
        print("no stash stashEntity")
        return nil
    end
    local success, items = Game.GetTransactionSystem():GetItemList(Helpers.stashEntity)

    if not success then
        print("'GetItemList' of stash did not return items")
        return nil
    end

    for _, itemData in pairs(items) do
        if tostring(itemData:GetID().id) == tostring(tweakDBID) then
            return itemData:GetID()
        end
    end
end

function GetItemIDFromInventory(tweakDBID)
    local success, items = Game.GetTransactionSystem():GetItemList(Game.GetPlayer())
    if not success then
        print("'GetItemList' did not return items")
        return nil
    end

    for _, itemData in ipairs(items) do
        if tostring(itemData:GetID().id) == tostring(tweakDBID) then
            return itemData:GetID()
        end
    end
end

function Helpers.IsFemale()
    local _, res = pcall(function() return Game.NameToString(Game.GetPlayer():GetResolvedGenderName()) == "Female" end)
    return res == true
end

local function iter_list(list)
    return function (cb)
        local item = table.remove(list, 1)
        if item ~= nil then
            cb(item)
            return true
        end
        return false
    end
end

local function iter_table(table)
    local keys = {}
    for k, _ in pairs(table) do table.insert(keys, k) end
    return function (cb)
        local key = table.remove(keys, 1)
        if key ~= nil then
            cb(table[key])
            return true
        end
        return false
    end
end

function UnequipAll()
    for _, slotName in pairs(AttachmentSlot) do
        Helpers.UnequipSlot(slotName)
    end
end

local slotsPriorities = {
    HEAD = 0,
    FACE = 1,
    EYES = 2,
    OUTFIT = 3,
    OUTERCHEST = 4,
    TORSO = 5,
    INNERCHEST = 6,
    CHEST = 7,
    FEET = 8,
    LEGS = 9,
    UNDERWEARTOP = 10,
    UNDERWEARBOTTOM = 11
}

-- Remove empty attachment slots
function FilterAndSortUsedAttachmentSlotsList(slotsList)
    local usedAttachmentSlots = {}

    for index, item in ipairs(slotsList) do
        local key = item["key"]
        local value = item["value"]

        local alt_name = "UNDEFINED"

        if value == AttachmentSlot.FACE then alt_name = AttachmentSlot.EYES end
        if value == AttachmentSlot.OUTERCHEST then alt_name = AttachmentSlot.TORSO end
        if value == AttachmentSlot.INNERCHEST then alt_name = AttachmentSlot.CHEST end
        if value == AttachmentSlot.EYES then alt_name = AttachmentSlot.FACE end
        if value == AttachmentSlot.TORSO then alt_name = AttachmentSlot.OUTERCHEST end
        if value == AttachmentSlot.CHEST then alt_name = AttachmentSlot.INNERCHEST end

        local hasItem = (GetItemIDInSlot(value) ~= nil)
            or (GetItemIDInSlotOfPuppet(value) ~= nil)
            or (GetItemIDInSlot(alt_name) ~= nil)
            or (GetItemIDInSlotOfPuppet(alt_name) ~= nil)
        if hasItem then
            table.insert(usedAttachmentSlots, item)
        end
    end

    -- move underwear to the end
    table.sort(usedAttachmentSlots, function (left, right)
        return slotsPriorities[left.key:upper()] < slotsPriorities[right.key:upper()]
    end)

    return usedAttachmentSlots
end

function TableToList(t)
    local outputList = {}
    for key, value in pairs(t) do
        table.insert(outputList, { key = key, value = value })
    end
    return outputList
end

function SortOutfitSet(outfitSet)
    table.sort(outfitSet, function (left, right)
        return slotsPriorities[left.key:upper()] > slotsPriorities[right.key:upper()]
    end)

    return outfitSet
end

function RequestUnequipAll()
    Helpers.ResetLastClothing()

    local usedAttachmentSlots = FilterAndSortUsedAttachmentSlotsList(TableToList(AttachmentSlot))

    if #usedAttachmentSlots > 0 then
        Helpers.UnequipAllIter = iter_list(usedAttachmentSlots)
    end

end

function RequestEquipAll(outfitSet)
    Helpers.ResetLastClothing()

    local list = SortOutfitSet(TableToList(outfitSet))
    if #list > 0 then
        Helpers.EquipAllIter = iter_list(list)
    end
end

function Helpers.ApplyOutfit(outfit)
    local isSomeClothesAreMissing = false

    if Helpers.UnequipAllIter == nil and Helpers.EquipAllIter == nil then
        RequestUnequipAll()
        RequestEquipAll(outfit.set)
    end

    return isSomeClothesAreMissing
end

function Helpers.UnlockSlot(slot)
    local ts = Game.GetTransactionSystem()
    local pl = Game.GetPlayer()
    pcall(function()
        ts:GetItemInSlot(pl, TweakDBID.new("AttachmentSlots." .. slot)):GetItemData():RemoveDynamicTag("UnequipBlocked")
    end)
end

function Helpers.IsSlotLocked(slot)
    local ts = Game.GetTransactionSystem()
    local pl = Game.GetPlayer()
    local ok, res = pcall(function()
        return ts:GetItemInSlot(pl, TweakDBID.new("AttachmentSlots." .. slot)):GetItemData():HasTag("UnequipBlocked")
    end)
    if ok then
        return res
    end
    return false
end

function Helpers.UnlockEveryItem()
    local ts = Game.GetTransactionSystem()
    local pl = Game.GetPlayer()
    for _, slot in pairs(AttachmentSlot) do
        pcall(function()
            ts:GetItemInSlot(pl, TweakDBID.new("AttachmentSlots." .. slot)):GetItemData():RemoveDynamicTag("UnequipBlocked")
        end)
    end
end

function Helpers.GetCurrentOutfitSet()
    local outfitSet = {}
    for _, slotName in pairs(AttachmentSlot) do
        local serTweakDBID = GetSerializedItemInSlot(slotName)
        if serTweakDBID then
            outfitSet[slotName] = { serTweakDBID = serTweakDBID }
        end
    end

    return outfitSet
end

return Helpers
