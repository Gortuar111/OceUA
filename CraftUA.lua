--[[
  OceUA — мітка «Крафтовий предмет» у тултіпі (як OceCraftMarker)
  База: Data/Craft_Reagents.lua

  Хукаємо Set* і додатково перевіряємо на OnUpdate —
  SkillUA / ShaguTweaks можуть перебудовувати тултіп після нашого AddLine.
]]

local COLOR = "|cff66ccff"
local TEXT  = "Крафтовий предмет"

local tooltipItemLink = {}

local function Enabled()
  if OceUA_IsEnabled then
    return OceUA_IsEnabled("craft")
  end
  if OceUA_Settings and OceUA_Settings.craft == false then
    return false
  end
  return true
end

local function ExtractItemID(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return id and tonumber(id) or nil
end

local function IsCraftItem(link)
  if not link then return false end
  local byID = OceUA_CraftReagentsByID
  local byName = OceUA_CraftReagentNames

  local id = ExtractItemID(link)
  if id and byID and byID[id] then
    return true
  end

  local itemName = GetItemInfo(link)
  if itemName and byName and byName[itemName] then
    return true
  end

  -- fallback по типу (як у окремому OceCraftMarker)
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(link)
  if itemType == "Trade Goods" or itemType == "Reagent" then
    return true
  end
  if itemSubType then
    local sub = string.lower(itemSubType)
    if string.find(sub, "trade", 1, true) or
       string.find(sub, "herb", 1, true) or
       string.find(sub, "metal", 1, true) or
       string.find(sub, "stone", 1, true) or
       string.find(sub, "leather", 1, true) or
       string.find(sub, "cloth", 1, true) or
       string.find(sub, "part", 1, true) or
       string.find(sub, "element", 1, true) or
       string.find(sub, "enchant", 1, true) or
       string.find(sub, "jewel", 1, true) or
       string.find(sub, "reagent", 1, true) or
       string.find(sub, "cook", 1, true) then
      return true
    end
  end
  return false
end

local function HasCraftLine(tooltip)
  if not tooltip then return false end
  local tname = tooltip:GetName()
  if not tname then return false end
  local num = tooltip:NumLines() or 0
  local i
  for i = 1, num do
    local left = getglobal(tname .. "TextLeft" .. i)
    if left then
      local txt = left:GetText()
      if txt and string.find(txt, TEXT, 1, true) then
        return true
      end
    end
  end
  return false
end

local function AddCraftLine(tooltip)
  if not Enabled() then return end
  if not tooltip or not tooltip:IsVisible() then return end
  local link = tooltipItemLink[tooltip]
  if not link or not IsCraftItem(link) then return end
  if HasCraftLine(tooltip) then return end

  tooltip:AddLine(COLOR .. TEXT .. "|r")
  tooltip:Show()
end

local function CaptureAndAdd(tooltip, link)
  if tooltip and link then
    tooltipItemLink[tooltip] = link
    AddCraftLine(tooltip)
  end
end

local function HookMethod(obj, method, hookFunc)
  if not obj or not obj[method] then return end
  local original = obj[method]
  obj[method] = function(self, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    local r1, r2, r3, r4, r5 = original(self, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    hookFunc(self, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    return r1, r2, r3, r4, r5
  end
end

-- ---- Хуки Set* (зберігаємо лінк + одразу додаємо рядок) ----
HookMethod(GameTooltip, "SetBagItem", function(self, bag, slot)
  CaptureAndAdd(self, GetContainerItemLink and GetContainerItemLink(bag, slot) or nil)
end)
HookMethod(GameTooltip, "SetInventoryItem", function(self, unit, slot)
  CaptureAndAdd(self, GetInventoryItemLink and GetInventoryItemLink(unit, slot) or nil)
end)
HookMethod(GameTooltip, "SetHyperlink", function(self, link)
  CaptureAndAdd(self, link)
end)
HookMethod(GameTooltip, "SetMerchantItem", function(self, index)
  CaptureAndAdd(self, GetMerchantItemLink and GetMerchantItemLink(index) or nil)
end)
if GameTooltip.SetBuybackItem then
  HookMethod(GameTooltip, "SetBuybackItem", function(self, index)
    CaptureAndAdd(self, GetBuybackItemLink and GetBuybackItemLink(index) or nil)
  end)
end
HookMethod(GameTooltip, "SetTradePlayerItem", function(self, index)
  CaptureAndAdd(self, GetTradePlayerItemLink and GetTradePlayerItemLink(index) or nil)
end)
HookMethod(GameTooltip, "SetTradeTargetItem", function(self, index)
  CaptureAndAdd(self, GetTradeTargetItemLink and GetTradeTargetItemLink(index) or nil)
end)
HookMethod(GameTooltip, "SetAuctionItem", function(self, list, index)
  CaptureAndAdd(self, GetAuctionItemLink and GetAuctionItemLink(list, index) or nil)
end)
HookMethod(GameTooltip, "SetLootItem", function(self, slot)
  CaptureAndAdd(self, GetLootSlotLink and GetLootSlotLink(slot) or nil)
end)
HookMethod(GameTooltip, "SetLootRollItem", function(self, id)
  CaptureAndAdd(self, GetLootRollItemLink and GetLootRollItemLink(id) or nil)
end)
HookMethod(GameTooltip, "SetQuestItem", function(self, itemType, index)
  CaptureAndAdd(self, GetQuestItemLink and GetQuestItemLink(itemType, index) or nil)
end)
HookMethod(GameTooltip, "SetQuestLogItem", function(self, itemType, index)
  CaptureAndAdd(self, GetQuestLogItemLink and GetQuestLogItemLink(itemType, index) or nil)
end)
HookMethod(GameTooltip, "SetCraftItem", function(self, index, reagent)
  CaptureAndAdd(self, GetCraftReagentItemLink and GetCraftReagentItemLink(index, reagent) or nil)
end)
HookMethod(GameTooltip, "SetTradeSkillItem", function(self, skillIndex, reagentIndex)
  if reagentIndex then
    CaptureAndAdd(self, GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(skillIndex, reagentIndex) or nil)
  else
    CaptureAndAdd(self, GetTradeSkillItemLink and GetTradeSkillItemLink(skillIndex) or nil)
  end
end)

if ItemRefTooltip then
  HookMethod(ItemRefTooltip, "SetHyperlink", function(self, link)
    CaptureAndAdd(self, link)
  end)
end

-- ---- OnUpdate: якщо рядок зник (SkillUA/Shagu перебудували тултіп) — додати знову ----
local function HookOnUpdate(tip)
  if not tip then return end
  local oldOnUpdate = tip:GetScript("OnUpdate")
  tip:SetScript("OnUpdate", function()
    if oldOnUpdate then oldOnUpdate() end
    if this:IsVisible() and tooltipItemLink[this] then
      AddCraftLine(this)
    end
  end)
end

HookOnUpdate(GameTooltip)
if ItemRefTooltip then
  HookOnUpdate(ItemRefTooltip)
end

-- ---- OnHide: чистимо збережений лінк ----
if GameTooltip then
  local oldOnHide = GameTooltip:GetScript("OnHide")
  GameTooltip:SetScript("OnHide", function()
    tooltipItemLink[GameTooltip] = nil
    if oldOnHide then oldOnHide() end
  end)
end
if ItemRefTooltip then
  local oldOnHide = ItemRefTooltip:GetScript("OnHide")
  ItemRefTooltip:SetScript("OnHide", function()
    tooltipItemLink[ItemRefTooltip] = nil
    if oldOnHide then oldOnHide() end
  end)
end
