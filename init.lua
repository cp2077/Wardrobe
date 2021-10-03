local Wardrobe = { version = "1.6.1" }

--[[
TODO:
1. wear clothing from stash
]]

local Helpers = require("Modules/Helpers")
local Config = require("Modules/Config")
local Window = require("Modules/Window")
local Cron = require("Modules/Cron")

local isReady = false
local isInited = false
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

function Wardrobe:Init()
  registerForEvent("onInit", function()

    -- Observe('Stash', 'GetDevicePS', function(self)
      --     print("GetDevicePS")
      --     if self:GetEntityID().hash == 16570246047455160070ULL then
      --         Helpers.stashEntity = Game.FindEntityByID(self:GetEntityID())
      --     end
      -- end)

      -- don't auto equip underpants
      Override("EquipmentSystemPlayerData", "IsUnderwearHidden", function(_) return true end)
      -- don't auto equip bra
      Override("EquipmentSystemPlayerData", "EvaluateUnderwearTopHiddenState", function(_) return true end)


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
        Helpers.photoPuppet = self.fakePuppet
        Helpers.photoPuppetComponent = self
        SetReady(true)
      end)

      Observe('gameuiPhotoModeMenuController', 'OnHide', function()
        Helpers.photoPuppet = nil
        Helpers.photoPuppetComponent = nil
        SetReady(true)
      end)

      Observe('OnscreenMessageGameController', 'CreateAnimations', function(self)
        messageController = self
      end)

      Config.InitConfig()
      isInited = true


      Cron.Every(0.14, function()
        local function msg()
          ShowMessage("Outfit has been changed")
        end
        -- Cron.Every(0.13, function()
          if Helpers.UnequipAllIter ~= nil then
            local called =  Helpers.UnequipAllIter(function(item)
              local name = item.key
              local slot = item.value

              Helpers.UnequipSlot(slot)
            end)
            if not called then
              if Helpers.EquipAllIter == nil then
                msg()
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
          Helpers.ToggleClothing(slot, alt_name)
          lastToggled = GetEngineTime()
        end

        local function onToggleUnderwear(slot)
          Helpers.ToggleUnderwear(slot)
          lastToggled = GetEngineTime()
        end


        local function onUnlockEveryItem()
          Helpers.UnlockEveryItem()
        end

        local isUndressing = Helpers.UnequipAllIter ~= nil
        local isDressing = Helpers.EquipAllIter ~= nil

        local canToggleClothing = math.abs((GetEngineTime() - lastToggled)) >= 0.5
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
    end

    return Wardrobe:Init()
