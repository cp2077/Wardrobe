local Wardrobe = { version = "1.9.0" }

--[[
TODO:
1. wear clothing from stash
]]

local Helpers = require("Modules/Helpers")
local Config = require("Modules/Config")
local Window = require("Modules/Window")
local Cron = require("Modules/Cron")
local GameSession = require("Modules/GameSession")

local isReady = false
local isInited = false
local isLoaded = false
local lastToggled = 0
function SetReady(ready) isReady = ready end
function IsReady() return isReady end


local cetVer = tonumber((GetVersion():gsub('^v(%d+)%.(%d+)%.(%d+)(.*)', function(major, minor, patch, wip)
  return ('%d.%02d%02d%d'):format(major, minor, patch, (wip == '' and 0 or 1))
end))) or 1.12

function GetEngineTime()
  local engineTime = Game.GetEngineTime()
  if engineTime == nil then
    return 0
  end

  if cetVer >= 1.14 then
    return engineTime:ToFloat()
  else
    return engineTime:ToFloat(engineTime)
  end
end

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

function genOufitId(name)
  if name == nil then
    name = "unnamed"
  end
  return tostring(#Config.data.outfits + 1 + os.time()) .. name .. tostring(math.random())
end

function GetCurrOutfit(name)
  if name == nil or name == "" then
    name = "Unnamed Outfit"
  end

  local outfitSet = Helpers.GetCurrentOutfitSet()
  local id = genOufitId(name)
  local outfit = {
    set = outfitSet,
    name = name,
    created = os.time(),
    isFemale = Helpers.IsFemale(),
    id = id,
  }

  return outfit
end

function SaveQuickAccessOutfit(number)
  if number > 5 then
    return
  end

  local outfit = GetCurrOutfit()
  Config.data.quickAccess[tostring(number)] = outfit
  -- table.remove(Config.data.quickAccess, number)
  -- table.insert(Config.data.quickAccess, number, outfit)
  Config.SaveConfig()
end

function SaveCurrentOutfit(name)
  local outfit = GetCurrOutfit(name)
  table.insert(Config.data.outfits, 1, outfit)
  Config.SaveConfig()
end

function ApplyOutfit(outfit)
  if outfit == nil then
    return
  end

  -- Save latest outfit
  -- SaveQuickAccessOutfit(5)

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

local lastEquipped = 0
function Wardrobe:Init()
  registerForEvent("onInit", function()
    GameSession.OnStart(function()
      SetReady(true)
    end)

    GameSession.OnResume(function()
      SetReady(true)
    end)

    GameSession.OnEnd(function()
      SetReady(false)
      Helpers.ResetLastClothing()
    end)
    -- Observe('Stash', 'GetDevicePS', function(self)
    --     print("GetDevicePS")
    --     if self:GetEntityID().hash == 16570246047455160070ULL then
    --         Helpers.stashEntity = Game.FindEntityByID(self:GetEntityID())
    --     end
    -- end)

    -- don't auto equip underpants
    -- Override("EquipmentSystemPlayerData", "IsUnderwearHidden", function(_) return true end)
    -- don't auto equip bra
    Override("EquipmentSystemPlayerData", "EvaluateUnderwearTopHiddenState", function(_) return true end)

    -- Override("EquipmentSystemPlayerData", "IsBuildCensored", function() return true end)
    
    Override("EquipmentSystemPlayerData", "OnUnderwearEquipFailsafe", function() end)
    Observe("gameuiMenuItemListGameController", "OnInitialize", function()
      isInMenu = true
    end)
    Observe("gameuiMenuItemListGameController", "OnUninitialize", function()
      isInMenu = false
    end)
    Observe('gameuiInventoryGameController', 'OnInitialize', function()
      isInInventory = true
      SetReady(true)
    end)
    Observe('gameuiInventoryGameController', 'OnUninitialize', function()
      isInInventory = false
      SetReady(true)
    end)

    Observe('PhotoModePlayerEntityComponent', 'ListAllCurrentItems', function(self)
      Helpers.photoPuppet = self.fakePuppet
      Helpers.photoPuppetComponent = self
      SetReady(true)
    end)

    Observe('PhotoModePlayerEntityComponent', 'ListAllCurrentItems', function(self)
      Helpers.photoPuppet = self.fakePuppet
      Helpers.photoPuppetComponent = self
      SetReady(true)
    end)

    Observe('gameuiPhotoModeMenuController', 'OnHide', function()
      Helpers.photoPuppet = nil
      Helpers.photoPuppetComponent = nil
      SetReady(true)
    end)
    Observe('gameuiPhotoModeMenuController', 'OnShow', function(self)
      Helpers.photoModeMenuController = self
      SetReady(true)
    end)

    Observe('OnscreenMessageGameController', 'CreateAnimations', function(self)
      messageController = self
    end)

    Config.InitConfig()
    isInited = true

    local function msg()
      -- ShowMessage("Outfit has been changed")
    end


    Cron.Every(0.12, function()
      if not IsReady() then
        return
      end

      if Helpers.UnequipAllIter ~= nil then
        local called =  Helpers.UnequipAllIter(function(item)
          local name = item.key
          local slot = item.value

          local alt_name = slot
          if slot == "InnerChest" then
            alt_name = "Chest"
          end
          if slot == "OuterChest" then
            alt_name = "Torso"
          end
          if slot == "Chest" then
            alt_name = "InnerChest"
          end
          Helpers.UnequipSlot(slot)
          Helpers.UnequipSlot(alt_name)
        end)
        if not called then
          if Helpers.EquipAllIter == nil then
            msg()
            lastEquipped = GetEngineTime()
          end
          Helpers.UnequipAllIter = nil
        end
      elseif Helpers.EquipAllIter ~= nil then
        local called =  Helpers.EquipAllIter(function(item)
          local name = item.key
          local slot = item.value

          if name == "UNDERWEARTOP" then
            return Helpers.PutOnBra()
          end

          local desTweakDBID = DeserializeTweakDB(slot.serTweakDBID)
          local itemID = GetItemIDFromInventory(desTweakDBID)

          if itemID ~= nil then
            Helpers.EquipItem(itemID)
          end
        end)
        if not called then
          Helpers.EquipAllIter = nil
          msg()
          lastEquipped = GetEngineTime()
        end
      end
    end, {})
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

    local function turnOffEquipmentEx()
      pcall(function()
        option = NewObject('gameuiPhotoModeOptionSelectorData')
        option.optionText = GetLocalizedTextByKey("UI-Wardrobe-NoOutfit");
        option.optionData = 3302;
    
        Helpers.photoModeMenuController:OnAttributeOptionSelected(3301, option)
      end)

      pcall(function()
        EquipmentEx.Deactivate()
      end)
    end

    local function onOutfitSelected(outfit)
      turnOffEquipmentEx()

      Cron.NextTick(function() Helpers.ApplyOutfit(outfit) end, {})
      
      lastSearchString = nil
    end

    local function onOutfitSave(name)
      SaveCurrentOutfit(name)
      lastSearchString = nil
    end

    local function onQuickAccessOutfitSave(number)
      local isUndressing = Helpers.UnequipAllIter ~= nil
      local isDressing = Helpers.EquipAllIter ~= nil

      if isUndressing or isDressing then
        return
      end

      SaveQuickAccessOutfit(number)
    end

    local function onQuickAccessOutfitLoad(number)
      turnOffEquipmentEx()

      local isUndressing = Helpers.UnequipAllIter ~= nil
      local isDressing = Helpers.EquipAllIter ~= nil
      
      if isInInventory or not isInited or isInMenu or not isReady or isDressing or isUndressing then
        return
      end

      Cron.NextTick(function() ApplyOutfit(Config.data.quickAccess[tostring(number)]) end, {})
    end

    local function onOutfitDelete(id)
      DeleteOutfit(id)
      lastSearchString = nil
    end

    local function onOutfitMove(id, offset)
      MoveOutfit(id, offset)
    end

    local function onSlotTakeOff(slot, alt_name)
      turnOffEquipmentEx()

      Cron.NextTick(function()
        Helpers.ToggleClothing(slot, alt_name)
        lastToggled = GetEngineTime()
      end, {})
    end

    local function onToggleUnderwear(slot)
      turnOffEquipmentEx()

      Cron.NextTick(function()
        Helpers.ToggleUnderwear(slot)
        lastToggled = GetEngineTime()
      end, {})
    end


    local function onUnlockEveryItem()
      Helpers.UnlockEveryItem()
    end

    local isUndressing = Helpers.UnequipAllIter ~= nil
    local isDressing = Helpers.EquipAllIter ~= nil

    local canToggleClothing = math.abs((GetEngineTime() - lastToggled)) >= 0.5
    local canEquip = math.abs((GetEngineTime() - lastEquipped)) >= 1
    local function hasItemInSlot(slot)
      return GetItemIDInSlot(slot) ~= nil
    end
    local function hasSavedToggleClothing(slot)
      return LastClothing[slot] ~= nil
    end

    -- TODO: these arguments are ugly
    Window.Draw(
    OutfitsSearched(),
    Helpers.IsFemale(),
    onOutfitSelected,
    onOutfitSave,
    onOutfitDelete,
    onOutfitMove,
    onQuickAccessOutfitSave,
    onQuickAccessOutfitLoad,
    onUnlockEveryItem,
    onSlotTakeOff,
    onToggleUnderwear,
    hasItemInSlot,
    hasSavedToggleClothing,
    isUndressing,
    isDressing,
    IsReady(),
    false,
    isInMenu,
    canToggleClothing,
    canEquip
    )
  end)
  registerForEvent('onUpdate', function(delta)
    Cron.Update(delta)
  end)

  -- hotkey for the first 6 outfits
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

  for var=1,4 do
    registerHotkey("outfit_quick_access_save" .. var, "Save quick access outfit #" .. var, function()
      SaveQuickAccessOutfit(var)
    end)

    registerHotkey("outfit_quick_access_load" .. var, "Load quick access outfit #" .. var, function()
      local isUndressing = Helpers.UnequipAllIter ~= nil
      local isDressing = Helpers.EquipAllIter ~= nil

      if isInInventory or not isInited or isInMenu or not isReady or isDressing or isUndressing then
        return
      end

      ApplyOutfit(Config.data.quickAccess[tostring(var)])
    end)
  end

  -- registerHotkey("outfit_quick_access_load_latest", "Load latest outfit", function()
  --   local isUndressing = Helpers.UnequipAllIter ~= nil
  --   local isDressing = Helpers.EquipAllIter ~= nil
  --
  --   if isInInventory or not isInited or isInMenu or not isReady or isDressing or isUndressing then
  --     return
  --   end
  --
  --   ApplyOutfit(Config.data.quickAccess["5"])
  -- end)

  return {
    Helpers = Helpers,
  }
end

return Wardrobe:Init()
