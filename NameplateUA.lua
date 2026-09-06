--[[
  OceUA — неймплейти EN→UA (оптимізовано)
  Рідший повний скан WorldFrame + реєстр відомих плейтів.
  /oceanp on|off|toggle|debug
]]

local cache = {}
local debugMode = false
local debugCD = 0

-- відомі фрейми плейтів (оновлюємо повним сканом рідко)
local known = {}
local knownN = 0
local fullAcc = 0
local quickAcc = 0
local targetAcc = 0

local FULL_INTERVAL  = 1.20  -- повний обхід WorldFrame
local QUICK_INTERVAL = 0.35  -- лише відомі плейти
local TARGET_INTERVAL = 0.25

local function Enabled()
  if OceUA_IsEnabled then
    return OceUA_IsEnabled("nameplates")
  end
  return OceUA_Settings and OceUA_Settings.nameplates == true
end

local function Lookup(en)
  if not en or en == "" then return nil end
  local c = cache[en]
  if c ~= nil then
    if c == false then return nil end
    return c
  end
  local function hit(d)
    if d and d[en] and d[en] ~= "" and d[en] ~= en then return d[en] end
    return nil
  end
  local ua = hit(OceUA_Mobs_Dictionary)
    or hit(OceUA_NPC_Names_Dictionary)
    or hit(OceUA_Objects_Dictionary)
  if ua then cache[en] = ua return ua end
  cache[en] = false
  return nil
end

local function Strip(s)
  if not s then return "" end
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, "|T.-|t", "")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

local function TranslateText(tx)
  tx = Strip(tx)
  if not tx or tx == "" then return nil end
  -- вже схоже на кирилицю
  if string.find(tx, "[А-Яа-яІіЇїЄєҐґ]") then return nil end
  local len = string.len(tx)
  if len < 2 or len > 70 then return nil end
  if string.find(tx, "^%d") or string.find(tx, "%%") then return nil end
  if string.find(tx, "^Level") then return nil end

  local ua = Lookup(tx)
  if ua then return ua end

  local _, _, inner = string.find(tx, "^<(.+)>$")
  if inner then
    inner = Strip(inner)
    local u2 = Lookup(inner)
    if u2 then return "<" .. u2 .. ">" end
  end
  return nil
end

local function TrySetUA(fs)
  if not fs or not fs.GetText or not fs.SetText then return false end
  local tx = fs:GetText()
  if not tx then return false end
  local ua = TranslateText(tx)
  if not ua then return false end
  fs:SetText(ua)
  return true
end

local function ProcessPlate(frame)
  if not frame or not frame.GetRegions then return 0 end
  local hits = 0
  local regs = { frame:GetRegions() }
  local i
  for i = 1, table.getn(regs) do
    local r = regs[i]
    if r and r.GetObjectType and r:GetObjectType() == "FontString" then
      if TrySetUA(r) then hits = hits + 1 end
    end
  end
  -- один рівень дітей (без глибокої рекурсії)
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    for i = 1, table.getn(kids) do
      local ch = kids[i]
      if ch and ch.GetRegions then
        local r2 = { ch:GetRegions() }
        local j
        for j = 1, table.getn(r2) do
          local r = r2[j]
          if r and r.GetObjectType and r:GetObjectType() == "FontString" then
            if TrySetUA(r) then hits = hits + 1 end
          end
        end
      end
    end
  end
  return hits
end

local function IsLikelyNameplate(fr)
  if not fr or not fr.IsVisible or not fr:IsVisible() then return false end
  local nm = fr.GetName and fr:GetName()
  if nm and nm ~= "" then
    local low = string.lower(nm)
    if string.find(low, "nameplate", 1, true) then return true end
    -- іменовані UI-фрейми не чіпаємо
    return false
  end
  -- без імені — кандидат (класичні плейти часто без GetName)
  return true
end

local function FullScan()
  if not WorldFrame then return 0 end
  known = {}
  knownN = 0
  local children = { WorldFrame:GetChildren() }
  local hits, i = 0, 1
  for i = 1, table.getn(children) do
    local fr = children[i]
    if IsLikelyNameplate(fr) then
      knownN = knownN + 1
      known[knownN] = fr
      hits = hits + ProcessPlate(fr)
    end
  end
  return hits
end

local function QuickScan()
  local hits, i = 0, 1
  local n = knownN
  for i = 1, n do
    local fr = known[i]
    if fr and fr.IsVisible and fr:IsVisible() then
      hits = hits + ProcessPlate(fr)
    end
  end
  return hits
end

local TARGET_FS = {
  "TargetName",
  "TargetFrameTextureFrameName",
  "TargetFrameName",
  "TargetofTargetName",
}

local function TranslateTargetFrame()
  if not UnitExists or not UnitExists("target") then return end
  if UnitIsPlayer and UnitIsPlayer("target") then return end
  local i
  for i = 1, table.getn(TARGET_FS) do
    local fs = getglobal(TARGET_FS[i])
    if fs then TrySetUA(fs) end
  end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:SetScript("OnEvent", function()
  if Enabled() then pcall(TranslateTargetFrame) end
end)

driver:SetScript("OnUpdate", function()
  if not Enabled() then
    -- майже нічого не робимо, коли модуль вимкнено
    return
  end

  targetAcc = targetAcc + arg1
  if targetAcc >= TARGET_INTERVAL then
    targetAcc = 0
    pcall(TranslateTargetFrame)
  end

  fullAcc = fullAcc + arg1
  if fullAcc >= FULL_INTERVAL then
    fullAcc = 0
    quickAcc = 0
    local hits = 0
    pcall(function() hits = FullScan() end)
    if debugMode then
      debugCD = debugCD + 1
      if debugCD >= 5 then
        debugCD = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rNP full hits=" .. hits .. " plates=" .. knownN)
      end
    end
    return
  end

  quickAcc = quickAcc + arg1
  if quickAcc >= QUICK_INTERVAL then
    quickAcc = 0
    if knownN > 0 then
      pcall(QuickScan)
    end
  end
end)

if type(TargetFrame_Update) == "function" then
  local _old = TargetFrame_Update
  TargetFrame_Update = function(a1, a2, a3, a4)
    _old(a1, a2, a3, a4)
    if Enabled() then pcall(TranslateTargetFrame) end
  end
end

SLASH_OCENAMEPLATE1 = "/oceanp"
SLASH_OCENAMEPLATE2 = "/ocenameplate"
SlashCmdList["OCENAMEPLATE"] = function(msg)
  msg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
  OceUA_Settings = OceUA_Settings or {}
  if msg == "on" then
    OceUA_Settings.nameplates = true
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA неймплейти: |cff00ff00ON|r")
  elseif msg == "off" then
    OceUA_Settings.nameplates = false
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA неймплейти: |cffff0000OFF|r")
  elseif msg == "toggle" then
    OceUA_Settings.nameplates = not (OceUA_Settings.nameplates == true)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA неймплейти: " ..
      (OceUA_Settings.nameplates and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
  elseif msg == "debug" then
    debugMode = not debugMode
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rNP debug: " .. (debugMode and "ON" or "OFF"))
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rNP: /oceanp on|off|toggle|debug")
  end
end
