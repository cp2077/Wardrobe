local AttachmentSlot = require("Modules/AttachmentSlot")
local Config = require("Modules/Config")
local Cron = require("Modules/Cron")

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
    if Helpers.photoPuppet ~= nil then
      Helpers.UnequipSlot(slot_alt_name, true)
      Helpers.UnequipSlot(slot)
    else
      Helpers.UnequipSlot(slot)
    end
    -- if slot_alt_name ~= "UNDEFINED" then
    -- end
    if itemInSlot ~= nil then
      LastClothing[slot] = itemInSlot
      LastClothing[slot_alt_name] = itemInSlot
      if Helpers.photoPuppet ~= nil then
        Helpers.UnequipSlot(slot_alt_name, true)
        Helpers.UnequipSlot(slot)
      else
        Helpers.UnequipSlot(slot)
      end
      -- if slot_alt_name ~= "UNDEFINED" then
      --   Helpers.UnequipSlot(slot_alt_name)
      -- end
    end
  else
    if Helpers.photoPuppet ~= nil then
      Helpers.EquipItem(LastClothing[slot_alt_name], true)
      Helpers.EquipItem(LastClothing[slot])
    else
      Helpers.EquipItem(LastClothing[slot])
    end
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

function Helpers.UnequipSlot(slotName, puppetOnly)
  if puppetOnly == nil then
    puppetOnly = false
  end
  if not puppetOnly then
    Game.UnequipItem(slotName, "0")
  end
  if Helpers.photoPuppet then
    local itemID = GetItemIDInSlotOfPuppet(slotName)
    if itemID then
      Game.GetTransactionSystem():RemoveItem(Helpers.photoPuppet, itemID, 1)
    end
  end
end



function Helpers.EquipItem(itemID, puppetOnly)
  if puppetOnly == nil then
    puppetOnly = false
  end
  
  if not puppetOnly then
    Game.GetScriptableSystemsContainer():Get(CName.new("EquipmentSystem")):GetPlayerData(Game.GetPlayer()):EquipItem(itemID, false, false)
  end
  if Helpers.photoPuppetComponent then
    Helpers.photoPuppetComponent:PutOnFakeItemFromMainPuppet(itemID)
  end
end

function GetItemIDFromStash(tweakDBID)
  local success, items = Game.GetTransactionSystem():GetItemList(Helpers.stashEntity or GetStashEntity())

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

function GetStashEntity()
  return Game.FindEntityByID(EntityID.new({ hash = 16570246047455160070ULL }))
end

function HasItemInInventory(tweakDBID)
  return Game.GetTransactionSystem():GetItemQuantity(Game.GetPlayer(), ItemID.CreateQuery(tweakDBID)) > 0
end

function HasItemInStash(tweakDBID)
  return Game.GetTransactionSystem():GetItemQuantity(GetStashEntity(), ItemID.CreateQuery(tweakDBID)) > 0
end

function OutfitHasMissingItems(outfitSet)
  for slotName, slot in pairs(outfitSet) do
    if slotName ~= AttachmentSlot.UNDERWEARBOTTOM and slotName ~= AttachmentSlot.UNDERWEARTOP then
      local tdbid = DeserializeTweakDB(slot.serTweakDBID)
      if not HasItemInInventory(tdbid) then
        return true
      end
    end
  end

  return false
end

function StashTransfer(tdbids, to)
  local missing = {}
  local transactionSystem = GameInstance.GetTransactionSystem()
  for key,tdbid in pairs(tdbids) do
    if to then
      local itemID = GetItemIDFromInventory(tdbid)
      if itemID then
        transactionSystem:TransferItem(Game.GetPlayer(), GetStashEntity(), itemID, 1)
      else
        table.insert(missing, tdbid)
      end
    else
      local itemID =  GetItemIDFromStash(tdbid)
      if itemID then
        transactionSystem:TransferItem(GetStashEntity(), Game.GetPlayer(), itemID, 1)
      else
        table.insert(missing, tdbid)
      end
    end
  end

  return missing
end


function GetMissingItemsTDBIDs(outfitSet)
  local out = {}
  for slotName, slot in pairs(outfitSet) do
    if slotName ~= AttachmentSlot.UNDERWEARBOTTOM and slotName ~= AttachmentSlot.UNDERWEARTOP then
      local tdbid = DeserializeTweakDB(slot.serTweakDBID)
      if not HasItemInInventory(tdbid) then
        table.insert(out, tdbid)
      end
    end
  end

  return out
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
    if slotName == "Eyes" or slotName == "Chest" or slotName == "Torso" then
      if Helpers.photoPuppet ~= nil then
        Helpers.UnequipSlot(slotName, true)
      end
    else
      Helpers.UnequipSlot(slotName)
    end
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

function SpawnItem(tdbid)
  itemID = ItemID.FromTDBID(tdbid);
  local ts = Game.GetTransactionSystem()
  local pl = Game.GetPlayer()
  return ts:GiveItem(pl, itemID, 1)
end

function SpawnItems(tdbids)
  for _,tdbid in pairs(tdbids) do
    SpawnItem(tdbid)
  end
end

function Helpers.ApplyOutfit(outfit)
  if Config.data.autoTransfer or Config.data.autoSpawn then
    local missingItemsTDBIDs = GetMissingItemsTDBIDs(outfit.set)
    if #missingItemsTDBIDs > 0 then
      if Config.data.autoTransfer then
        local failedToTransferTDBIDs = StashTransfer(missingItemsTDBIDs, false)
        if #failedToTransferTDBIDs > 0 then
          if Config.data.autoSpawn then
            SpawnItems(failedToTransferTDBIDs)
          end
        end
      elseif Config.data.autoSpawn then
        SpawnItems(missingItemsTDBIDs)
      end
    end
  end

  -- Cron.NextTick(function()
  if Helpers.UnequipAllIter == nil and Helpers.EquipAllIter == nil then
    RequestUnequipAll()
    RequestEquipAll(outfit.set)
  end
  -- end)

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
