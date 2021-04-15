local AttachmentSlot = require("Modules/AttachmentSlot")

local Helpers = {
    UnequipAllIter = nil,
    EquipAllIter = nil,
}

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

function Sleep(n)  -- seconds
  local t0 = os.time()
  while os.time() - t0 <= n do end
end

function UnequipAllBegin()
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
    Helpers.UnequipAllIter = iter_table(AttachmentSlot)
end

function RequestEquipAll(outfitSet)
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
