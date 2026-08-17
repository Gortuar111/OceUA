--[[
  OceUA — заміна EN→UA на неймплейтах (простий режим)
  Без окремих вікон — лише підміна тексту (стабільно, без миготіння).
  /oceanp on|off|toggle|debug
]]

local cache = {}
local debugMode = false
local debugCD = 0
local scanAcc = 0
local targetAcc = 0

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
  -- вже українською
  if string.find(tx, "[А-Яа-яІіЇїЄєҐґ]") then return nil end
  if string.len(tx) < 2 or string.len(tx) > 70 then return nil end
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

local function ForEachFontString(frame, depth, fn)
  if not frame or depth > 5 then return end
  if frame.GetRegions then
    local regs = { frame:GetRegions() }
    local i
    for i = 1, table.getn(regs) do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
        fn(r)
      end
    end
  end
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    local i
    for i = 1, table.getn(kids) do
      ForEachFontString(kids[i], depth + 1, fn)
    end
  end
end

local function ScanNameplates()
  if not WorldFrame then return 0 end
  local children = { WorldFrame:GetChildren() }
  local i, hits = 1, 0
  for i = 1, table.getn(children) do
    local fr = children[i]
    if fr and fr.IsVisible and fr:IsVisible() then
      local nm = fr.GetName and fr:GetName()
      local ok = false
      if not nm or nm == "" then
        ok = true
      elseif string.find(string.lower(nm), "nameplate") then
        ok = true
      end
      if ok then
        ForEachFontString(fr, 0, function(fs)
          if TrySetUA(fs) then hits = hits + 1 end
        end)
      end
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
  if TargetFrame then
    ForEachFontString(TargetFrame, 0, function(fs) TrySetUA(fs) end)
  end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:SetScript("OnEvent", function()
  if Enabled() then pcall(TranslateTargetFrame) end
end)

driver:SetScript("OnUpdate", function()
  if not Enabled() then return end
  targetAcc = targetAcc + arg1
  if targetAcc >= 0.08 then
    targetAcc = 0
    pcall(TranslateTargetFrame)
  end
  scanAcc = scanAcc + arg1
  if scanAcc >= 0.08 then
    scanAcc = 0
    local hits = 0
    pcall(function() hits = ScanNameplates() end)
    if debugMode then
      debugCD = debugCD + 1
      if debugCD >= 20 then
        debugCD = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rNP hits=" .. hits)
      end
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
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA неймплейти: |cffff4040OFF|r")
  elseif msg == "toggle" then
    OceUA_Settings.nameplates = not OceUA_Settings.nameplates
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA неймплейти: " ..
      (OceUA_Settings.nameplates and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
  elseif msg == "debug" then
    debugMode = not debugMode
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA NP debug: " .. (debugMode and "ON" or "OFF"))
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffb266ffOce|rUA неймплейти: " ..
      ((OceUA_Settings.nameplates and "|cff00ff00ON|r") or "|cffff4040OFF|r") ..
      "  /oceanp on|off|toggle|debug")
  end
end
