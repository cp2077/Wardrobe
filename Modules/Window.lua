local Changelog = require("Modules/Changelog")
local AttachmentSlot = require("Modules/AttachmentSlot")
local Helpers = require("Modules/Helpers")
local Config = require("Modules/Config")

local Window = {}

local newOutfitName = ""

Window.searchInput = ""

local MSG_DOESNT_WORK_INV = "Exit inventory to select an outfit"
local MSG_DOESNT_WORK_MENU = "Wardrobe doesn't work when you are in menu"
local MSG_LOAD_RELOAD_SAVE = "Load the save file!"
local function MSG_UNDRESSING_CHARACTER(isFemale)
  local characterName = isFemale and "Valerie" or "Vincent"
  return ("Undressing %s..."):format(characterName)
end
local function MSG_DRESSING_CHARACTER(isFemale)
  local characterName = isFemale and "Valerie" or "Vincent"
  return ("Dressing %s..."):format(characterName)
end

local SCROLLBAR_SIZE = 4.0

ImGui = ImGui

function HoverTooltip(text)
  if ImGui.IsItemHovered() then
    ImGui.BeginTooltip()
    ImGui.SetTooltip(text)
    ImGui.EndTooltip()
  end
end

function DisableButton()
  ImGui.PushStyleColor(ImGuiCol.Button, 0.40, 0.40, 0.40, 0.8)
  ImGui.PushStyleColor(ImGuiCol.Text, 0.50, 0.50, 0.50, 0.8)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.40, 0.40, 0.40, 0.8)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.40, 0.40, 0.40, 0.8)
end
function UndisableButton()
  ImGui.PopStyleColor(4)
end

function Window.Draw(
  outfits,
  isFemale,
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
  isReady,
  isInInventory,
  isInMenu,
  canToggleClothing
  )

  ImGui.PushStyleColor(ImGuiCol.Border, 0, 0, 0, 0)
  ImGui.PushStyleColor(ImGuiCol.ScrollbarBg, 0, 0, 0, 0)
  ImGui.PushStyleColor(ImGuiCol.TitleBg, 0, 0, 0, 0.8)
  ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0, 0, 0, 0.8)
  ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0.8)
  ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.35, 0.45, 0.8)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.35, 0.45, 0.55, 1.0)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.35, 0.45, 0.5)
  ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.25, 0.35, 0.45, 0.8)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
  ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, SCROLLBAR_SIZE)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, 450, 384)

  ImGui.PushStyleColor(ImGuiCol.Tab, 0.25, 0.35, 0.45, 0.45)
  ImGui.PushStyleColor(ImGuiCol.TabHovered, 0.35, 0.45, 0.55, 1.0)
  ImGui.PushStyleColor(ImGuiCol.TabActive, 0.25, 0.35, 0.45, 0.8)
  ImGui.PushStyleColor(ImGuiCol.TabUnfocused, 0.25, 0.35, 0.45, 0.8)
  ImGui.PushStyleColor(ImGuiCol.TabUnfocusedActive, 0.25, 0.35, 0.45, 0.8)
  ImGui.PushStyleColor(ImGuiCol.Separator, 0.25, 0.35, 0.45, 0.8)

  ImGui.Begin('Wardrobe', ImGuiWindowFlags.AlwaysAutoResize)

  local msgInvSizeX, msgInvSizeY = ImGui.CalcTextSize(MSG_DOESNT_WORK_INV)
  local windowWidth = ImGui.GetWindowWidth()

  local autoSpawn = Config.data.autoSpawn == true
  local autoTransfer = Config.data.autoTransfer == true

  function NewLine(n)
    for _=1,n do ImGui.Text("") end
  end

  if isInInventory then
    NewLine(1)
    ImGui.SameLine(math.max(0, windowWidth / 2 - msgInvSizeX/2))
    ImGui.TextWrapped(MSG_DOESNT_WORK_INV)
    NewLine(1)
  end

  if isInMenu then
    local msgLoadSaveX, _ = ImGui.CalcTextSize(MSG_DOESNT_WORK_MENU)
    NewLine(2)
    ImGui.SameLine(math.max(0, (windowWidth / 2 - msgLoadSaveX/2)))
    ImGui.TextWrapped(MSG_DOESNT_WORK_MENU)
  elseif not isReady then
    local msgLoadSaveX, _ = ImGui.CalcTextSize(MSG_LOAD_RELOAD_SAVE)
    NewLine(2)
    ImGui.SameLine(math.max(0, windowWidth / 2 - msgLoadSaveX/2))
    ImGui.TextWrapped(MSG_LOAD_RELOAD_SAVE)
    NewLine(2)

    -- Changelog
    ImGui.Separator()
    NewLine(2)
    ImGui.TextWrapped("Changelog")
    NewLine(1)
    ImGui.BeginChild('ChangeLog', 433, 300)
    for _, log in pairs(Changelog) do
      ImGui.TextWrapped(" - " .. log.version)
      ImGui.PushStyleColor(ImGuiCol.Separator, 1, 1, 1, 0)
      ImGui.Separator()
      ImGui.PopStyleColor()
      for _, change in pairs(log.changes) do
        ImGui.TextWrapped(change)
      end
      ImGui.TextWrapped("")
    end
    ImGui.EndChild()

  elseif isUndressing then
    local msgUndressX, _ = ImGui.CalcTextSize(MSG_UNDRESSING_CHARACTER(isFemale))
    NewLine(2)
    ImGui.SameLine(math.max(0, windowWidth / 2 - msgUndressX/2))
    ImGui.TextWrapped(MSG_UNDRESSING_CHARACTER(isFemale))
  elseif isDressing then
    local msgDressX, _ = ImGui.CalcTextSize(MSG_DRESSING_CHARACTER(isFemale))
    NewLine(2)
    ImGui.SameLine(math.max(0, windowWidth / 2 - msgDressX/2))
    ImGui.TextWrapped(MSG_DRESSING_CHARACTER(isFemale))
  else
    ImGui.BeginTabBar("wardrobe_tabs")

    -- Tab: Outfits
    if ImGui.BeginTabItem(" Outfits ") then

      -- New Outfit Name
      ImGui.PushID("outfit_name")
      newOutfitName, IsEnterPressed = ImGui.InputTextWithHint("", " Outfit name ", newOutfitName, 150, ImGuiInputTextFlags.EnterReturnsTrue)
      ImGui.PopID("outfit_name")
      ImGui.SameLine()
      if ImGui.Button(" Save ") or IsEnterPressed then
        onOutfitSave(newOutfitName)
        Window.searchInput = ""
        newOutfitName = ""
      end

      -- Search field
      ImGui.PushID("search")
      Window.searchInput = ImGui.InputTextWithHint("", " Search ", Window.searchInput, 150)
      ImGui.PopID("search")
      ImGui.SameLine()
      if ImGui.Button(' Clear ') then
        Window.searchInput = ""
      end

      ImGui.PushStyleColor(ImGuiCol.Separator, 1, 1, 1, 0)
      ImGui.Separator()
      ImGui.Separator()
      ImGui.PopStyleColor()

      ImGui.BeginChild('WardrobeList', 433, 270)

      local hasScrollBar = ImGui.GetScrollMaxY() > 0

      local wearWidth, _ = ImGui.CalcTextSize(" Select ")
      local deleteWidth, _ = ImGui.CalcTextSize(" Delete ")


      if #outfits == 0 then
        if Window.searchInput ~= "" then
          ImGui.TextWrapped("No outfits found")
        else
          ImGui.TextWrapped("No outfits")
        end
      else
        local i = 0
        for outfitIndex, outfit in pairs(outfits) do
          if outfit.isFemale == isFemale then
            i = i + 1
            local name = (outfit.name or "Unnamed outfit")
            local hasMissingItems = OutfitHasMissingItems(outfit.set)

            -- HOTKEY info
            local iStr = tostring(i)
            if i < 10 then
              iStr = iStr .. " "
            end
            ImGui.TextWrapped(iStr)
            if i <= 6 then
              HoverTooltip("Hotkey number " .. i .. " is assigned to this outfit. Check your bindings in CET overlay to set it up.")
            else
              HoverTooltip("To have a hotkey assigned to this outfit, move it up in position 1-6.")
            end
            ImGui.SameLine()

            -- Move UP
            ImGui.PushID(("U" .. tostring(outfitIndex)))
            if ImGui.ArrowButton("up", ImGuiDir.Up) then
              onOutfitMove(outfit.id, -1)
            end
            ImGui.PopID()
            ImGui.SameLine()

            -- Move DOWN
            ImGui.PushID(("D" .. tostring(outfitIndex)))
            if ImGui.ArrowButton("down", ImGuiDir.Down) then
              onOutfitMove(outfit.id, 1)
            end
            ImGui.PopID()
            ImGui.SameLine()

            -- "Select" Button
            if isInInventory then
              ImGui.PushStyleColor(ImGuiCol.Button, 0.40, 0.40, 0.40, 0.8)
              ImGui.PushStyleColor(ImGuiCol.Text, 0.50, 0.50, 0.50, 0.8)
              ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.40, 0.40, 0.40, 0.8)
              ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.40, 0.40, 0.40, 0.8)
            end
            ImGui.SameLine()
            ImGui.PushID(("wear" .. tostring(outfitIndex)))

            local selectOutfitText = " Select "

            if hasMissingItems and not isInInventory then
              ImGui.PushStyleColor(ImGuiCol.Button, 0.60, 0.30, 0.05, 1.0)
            end

            if ImGui.Button(selectOutfitText) and not isInInventory then
              onOutfitSelected(outfit)
            end
            if hasMissingItems and not isInInventory then
              if not autoSpawn and autoTransfer then
                HoverTooltip('Some items are missing!\n\nTransfer from stash is enabled.')
                elseif autoSpawn and not autoTransfer then
                HoverTooltip('Some items are missing!\n\nAuto spawn is enabled.')
                elseif not autoSpawn and not autoTransfer then
                HoverTooltip('Some items are missing!\n\nCheck "Settings" tab to configure auto spawn or transfer from stash.')
                elseif autoSpawn and autoTransfer then
                HoverTooltip('Some items are missing!\n\nAuto spawn and transfer from stash is enabled.\n\n')
              end
            end

            if hasMissingItems and not isInInventory then
              ImGui.PopStyleColor(1)
            end

            ImGui.PopID()
            if not hasMissingItems then
              HoverTooltip("Put outfit on")
            end

            if isInInventory then
              ImGui.PopStyleColor(4)
            end
            ImGui.SameLine()

            -- "Delete" Button
            ImGui.PushStyleColor(ImGuiCol.Button, 0.60, 0.20, 0.30, 0.8)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.70, 0.20, 0.30, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.70, 0.20, 0.30, 0.5)
            ImGui.PushID(("delete" .. tostring(outfitIndex)))
            if ImGui.Button('R') then
              onOutfitDelete(outfit.id)
            end
            ImGui.PopID()
            HoverTooltip("Delete outfit. This action can not be undone!")
            ImGui.PopStyleColor(3)
            ImGui.SameLine()

            -- Outfit Name
            ImGui.SameLine()
            ImGui.TextWrapped(name)

            -- if ImGui.IsItemHovered() and ImGui.IsMouseDragging() then
            --     local dragx, dragy = ImGui.GetMouseDragDelta()
            --     print(dragx)
            --     print(dragy)
            -- end

            -- ImGui.SameLine()
            -- ImGui.SameLine(windowWidth - deleteWidth - 28 - (hasScrollBar and (SCROLLBAR_SIZE + 5) or 0))
          end
        end
      end
      ImGui.EndChild()
      ImGui.BeginChild('WardrobeQuickAccess', 433, 20)
      for var=1,4 do
        ImGui.PushStyleColor(ImGuiCol.Button, 0.60, 0.20, 0.30, 0.8)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.70, 0.20, 0.30, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.70, 0.20, 0.30, 0.5)
        ImGui.PushID(("save_qa_btn" .. tostring(var)))
        if ImGui.Button('S' .. tostring(var)) then
          onQuickAccessOutfitSave(var)
        end
        ImGui.PopID()
        HoverTooltip("Save quick access outfit. (See CET->Bindings for a shortcut)")
        ImGui.PopStyleColor(3)

        ImGui.SameLine()
        if not Config.data.quickAccess[tostring(var)] then
          DisableButton()
        end
        ImGui.PushID(("load_qa_btn" .. tostring(var)))
        if ImGui.Button('L' .. tostring(var)) then
          if Config.data.quickAccess[tostring(var)] then
            onQuickAccessOutfitLoad(var)
          end
        end
        ImGui.PopID()
        if not Config.data.quickAccess[tostring(var)] then
          UndisableButton()
        end

        HoverTooltip("Load quick access outfit. (See CET->Bindings for a shorcut)")

        ImGui.SameLine()
        ImGui.Spacing(1)
        ImGui.SameLine()
      end

      -- ImGui.PushID(("load_qa_btn_latest" .. tostring(5)))
      -- if ImGui.Button('Load latest ') then
      --   if Config.data.quickAccess["5"] then
      --     onQuickAccessOutfitLoad(5)
      --   end
      -- end
      -- ImGui.PopID()
      -- HoverTooltip("Load quick access outfit. (See CET->Bindings for a shorcut)")

      ImGui.EndChild()
      ImGui.EndTabItem()
    end

    -- Tab: Items

    if ImGui.BeginTabItem(" Items ") then
      if not canToggleClothing then
        DisableButton()
      end


      local listSlotsNames = {
        [AttachmentSlot.HEAD] = "Hat",
        [AttachmentSlot.FACE] = "Accessory",
        [AttachmentSlot.OUTERCHEST] = "Jacket",
        [AttachmentSlot.INNERCHEST] = "Top",
        [AttachmentSlot.LEGS] = "Pants",
        [AttachmentSlot.FEET] = "Shoes",
        [AttachmentSlot.UNDERWEARBOTTOM] = "Underpants",
        [AttachmentSlot.UNDERWEARTOP] = "Bra",
        [AttachmentSlot.OUTFIT] = "Suit",
      }
      local listSlots = {
        { AttachmentSlot.HEAD, nil }, { AttachmentSlot.FACE, AttachmentSlot.EYES },
        { AttachmentSlot.OUTERCHEST, AttachmentSlot.TORSO }, { AttachmentSlot.INNERCHEST, AttachmentSlot.CHEST },
        { AttachmentSlot.LEGS, nil }, { AttachmentSlot.FEET, nil },
        { AttachmentSlot.OUTFIT, nil },
      }

      -- Take Off Clothing
      local btnWidth, btnHeight = ImGui.CalcTextSize((" %s "):format(" Changing "))

      local function getButtonText(slot, slot_alt_name)
        if not canToggleClothing then
          return "Changing"
        end

        local isUnderwear = slot == AttachmentSlot.UNDERWEARBOTTOM or slot == AttachmentSlot.UNDERWEARTOP
        if isUnderwear then
          return "Toggle"
        end

        if hasItemInSlot(slot) or (slot_alt_name and hasItemInSlot(slot_alt_name)) then
          return "Take off"
        else
          if not hasSavedToggleClothing(slot) or (slot_alt_name and not hasSavedToggleClothing(slot_alt_name)) then
            return "No item"
          end
          return "Put on"
        end
      end

      local function hasItemToTakeOff(slot)
        if slot == nil then
          return false
        end
        return hasItemInSlot(slot) or hasSavedToggleClothing(slot)
      end

      for index, sl in pairs(listSlots) do
        local slot = sl[1]
        local slot_alt_name = sl[2]
        local hasItemToToggle = hasItemToTakeOff(slot) or hasItemToTakeOff(slot_alt_name)
        if not hasItemToToggle then
          DisableButton()
        end

        ImGui.PushID(tostring(index) .. slot)

        -- If slot is locked wee need to unlock it first
        if Helpers.IsSlotLocked(slot) or Helpers.IsSlotLocked(slot_alt_name) then
          ImGui.PushStyleColor(ImGuiCol.Button, 0.60, 0.20, 0.30, 0.8)
          ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.70, 0.20, 0.30, 1.0)
          ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.70, 0.20, 0.30, 0.5)
          if ImGui.Button(' Unlock ', btnWidth, btnHeight + 4) then
            Helpers.UnlockSlot(slot)
            Helpers.UnlockSlot(slot_alt_name)
          end
          HoverTooltip("To unequip quest items you have to unlock them first.")
          ImGui.PopStyleColor(3)
        else
          if ImGui.Button(getButtonText(slot, slot_alt_name), btnWidth, btnHeight+4) and canToggleClothing and hasItemToToggle then
            onSlotTakeOff(slot, slot_alt_name)
          end
        end

        ImGui.PopID()
        if not hasItemToToggle then
          UndisableButton()
        end
        ImGui.SameLine()
        ImGui.TextWrapped(listSlotsNames[slot])
      end

      -- UnderwearTop
      if isFemale then
        ImGui.PushID("underweartop")
        if ImGui.Button(getButtonText(AttachmentSlot.UNDERWEARTOP), btnWidth, btnHeight+4) and canToggleClothing then
          onToggleUnderwear(AttachmentSlot.UNDERWEARTOP)
        end
        ImGui.PopID()
        ImGui.SameLine()
        ImGui.TextWrapped(listSlotsNames[AttachmentSlot.UNDERWEARTOP])
        ImGui.SameLine()
        ImGui.SmallButton("!")
        HoverTooltip("If you have a large breast type, bra will clip through it")
      end

      -- UnderwearBottom
      ImGui.PushID("underwearbottom")
      if ImGui.Button(getButtonText(AttachmentSlot.UNDERWEARBOTTOM), btnWidth, btnHeight+4) and canToggleClothing then
        onToggleUnderwear(AttachmentSlot.UNDERWEARBOTTOM)
      end
      ImGui.PopID()
      ImGui.SameLine()
      ImGui.TextWrapped(listSlotsNames[AttachmentSlot.UNDERWEARBOTTOM])

      ImGui.TextWrapped("")
      if not canToggleClothing then
        UndisableButton()
      end
      ImGui.EndTabItem()
    end

    -- Tab: Settings
    if ImGui.BeginTabItem(" Settings ") then
      -- Auto transfer
      local autoTransferChecked, changed = ImGui.Checkbox("Transfer from stash", Config.data.autoTransfer == true)
      ImGui.SameLine()
      ImGui.SmallButton("?")
      HoverTooltip("Attempt to transfer missing items from the stash")
      if changed then
        Config.data.autoTransfer = autoTransferChecked
        Config.SaveConfig()
      end

      -- Auto spawn
      local autoSpawnChecked, changed2 = ImGui.Checkbox("Spawn missing items", Config.data.autoSpawn == true)
      ImGui.SameLine()
      ImGui.SmallButton("?")
      HoverTooltip("Missing items will auto spawn with random qualities")
      if changed2 then
        Config.data.autoSpawn = autoSpawnChecked
        Config.SaveConfig()
      end

      ImGui.EndTabItem()
    end
    ImGui.EndTabBar()
  end

  ImGui.End()

  ImGui.PopStyleColor(15)
  ImGui.PopStyleVar(3)
end

return Window
