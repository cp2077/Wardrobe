local AttachmentSlot = require("Modules/AttachmentSlot")

local Helpers = {
    UnequipAllIter = nil,
    EquipAllIter = nil,
    stashEntity = nil,
}

-- function Helpers.GetStashItems()
--     if Helpers.stashEntity then
--         local success, items = Game.GetTransactionSystem():GetItemList(Helpers.stashEntity)
--
-- 		if success then
-- 			print('[Stash] Total Items:', #items)
--
-- 			for _, itemData in pairs(items) do
-- 				print('[Stash]', Game.GetLocalizedTextByKey(Game['TDB::GetLocKey;TweakDBID'](itemData:GetID().id + '.displayName')))
-- 			end
-- 		end
--     end
-- end

function GetUnderwearBottom()
    local gameItemID = GetSingleton('gameItemID')
    return gameItemID:FromTDBID("Items.Underwear_Basic_01_Bottom")
end
function GetUnderwearTop()
    local gameItemID = GetSingleton('gameItemID')
    return gameItemID:FromTDBID("Items.Underwear_Basic_01_Top")
end


function GetItemIDInSlotOfPuppet(slotName, puppet)
    local attachment = TweakDBID.new("AttachmentSlots." .. slotName)
    local slot = Game.GetTransactionSystem():GetItemInSlot(puppet, attachment)
    if slot == nil then
        return nil
    end

    return slot:GetItemData():GetID()
end

function GetItemIDInSlot(slotName)
    local attachment = TweakDBID.new("AttachmentSlots." .. slotName)
    local slot = Game.GetTransactionSystem():GetItemInSlot(Game.GetPlayer(), attachment)
    if slot == nil then
        return nil
    end

    return slot:GetItemData():GetID()
end

LastClothing = {}
function Helpers.ResetLastClothing()
    LastClothing = {}
end
function Helpers.ToggleClothing(slot, photoPuppetComponent, slot_alt_name)
    -- some items like OUTERCHEST has alternative names like TORSO,
    -- and they used for photo mode puppet and not always used for base player puppet.

    if slot_alt_name == nil then
        slot_alt_name = "UNDEFINED"
    end

    local hasSavedClothing = LastClothing[slot] ~= nil or LastClothing[slot_alt_name] ~= nil
    local hasClothingInSlot = GetItemIDInSlot(slot) ~= nil or GetItemIDInSlot(slot_alt_name)

    if not hasSavedClothing or hasClothingInSlot then
        local itemInSlot = GetItemIDInSlot(slot) or GetItemIDInSlot(slot_alt_name)
        Helpers.UnequipSlot(slot, photoPuppetComponent)
        Helpers.UnequipSlot(slot_alt_name, photoPuppetComponent)
        if itemInSlot ~= nil then
            LastClothing[slot] = itemInSlot
            LastClothing[slot_alt_name] = itemInSlot
            Helpers.UnequipSlot(slot, photoPuppetComponent)
            Helpers.UnequipSlot(slot_alt_name, photoPuppetComponent)
        end
    else
        Helpers.EquipItem(LastClothing[slot], photoPuppetComponent)
        Helpers.EquipItem(LastClothing[slot_alt_name], photoPuppetComponent)
        LastClothing[slot] = nil
        LastClothing[slot_alt_name] = nil
    end

end

function Helpers.ToggleUnderwear(slot, photoPuppetComponent)
    local ts = Game.GetTransactionSystem()
    if slot == AttachmentSlot.UNDERWEARTOP and not Helpers.IsFemale() then
        return
    end

    local underwear = slot == AttachmentSlot.UNDERWEARBOTTOM and GetUnderwearBottom() or GetUnderwearTop()

    if GetItemIDInSlot(slot) ~= nil then
        Helpers.UnequipSlot(slot, photoPuppetComponent)
    else
        if not ts:HasItem(Game.GetPlayer(), underwear) then
            ts:GiveItem(Game.GetPlayer(), underwear, 1)
        end
        Helpers.EquipItem(underwear, photoPuppetComponent)
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
function Helpers.UnequipSlot(slotName, photoPuppetComponent)
    Game.UnequipItem(slotName, "0")
    if photoPuppetComponent then
        local itemID = GetItemIDInSlotOfPuppet(slotName, photoPuppetComponent.fakePuppet)
        Game.GetTransactionSystem():RemoveItem(photoPuppetComponent.fakePuppet, itemID, 1)
    end
end

function Helpers.EquipItem(itemID, photoPuppetComponent)
    Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem")):GetPlayerData(Game.GetPlayer()):EquipItem(itemID, false, false, false)
    if photoPuppetComponent then
        photoPuppetComponent:PutOnFakeItem(itemID)
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

function iter_table(t)
    local keys = {}
    for k, _ in pairs(t) do table.insert(keys, k) end
    return function (cb)
        local key = table.remove(keys, 1)
        if key ~= nil then
            cb(t[key])
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

function RequestUnequipAll()
    Helpers.ResetLastClothing()

    Helpers.UnequipAllIter = iter_table(AttachmentSlot)
end

function RequestEquipAll(outfitSet)
    Helpers.ResetLastClothing()

    Helpers.EquipAllIter = iter_table(outfitSet)
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
