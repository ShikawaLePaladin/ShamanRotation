-- mock_wow.lua : API WoW 1.12 simulee pour les tests (Lua 5.3 de fengari + raccourcis Lua 5.0).
-- Ce fichier ne contient QUE des noms d'API de WoW 1.12 (ou d'extensions connues : Nampower / SuperWoW / UnitXP).

-- ---------------------------------------------------------------- raccourcis Lua 5.0
string.gfind = string.gmatch
tinsert = table.insert
tremove = table.remove
table.getn = function(t) return #t end
getglobal = function(n) return _G[n] end
setglobal = function(n, v) _G[n] = v end
_G._G = _G

LOG = {}
NOW = 1000
GetTime = function() return NOW end

-- ---------------------------------------------------------------- monde simule
W = {
  book = {},       -- noms de sorts (l'index = la position dans le livre)
  defs = {},       -- definitions de sorts (voir lib_sim.lua)
  cdStart = {}, cdDur = {},     -- vraie recharge par sort
  gcdStart = 0, gcdEnd = 0,
  mana = 5000, manaMax = 5000, hp = 5000, hpMax = 5000,
  combat = false, dead = false, mounted = false, chatOpen = false,
  target = nil,    -- { name, guid, hp, hpMax, level, class, player, ctype, dist, friend, dead, debuffs = {} }
  mobs = {},       -- liste pour TargetNearestEnemy
  pbuffs = {},     -- { tex, stacks, sid, exp }
  inv = {}, invcd = {}, talents = {}, casting = {},
  zone = "Elwynn Forest", raid = 0, party = 0, instance = false,
  attackSpeed = 2.0, bindings = {}, shift = false,
}
local function log(s) table.insert(LOG, s) end

-- ---------------------------------------------------------------- unites
UnitExists = function(u)
  if u == "player" then return 1, "0xPLAYER" end
  if u == "target" and W.target then return 1, W.target.guid end
  return nil
end
UnitName = function(u)
  if u == "player" then return "Shikiwa" end
  if u == "target" and W.target then return W.target.name end
  return nil
end
UnitCanAttack = function(a, u) return (u == "target" and W.target ~= nil and not W.target.friend) and 1 or nil end
UnitIsFriend = function(a, u) return (u == "target" and W.target ~= nil and W.target.friend) and 1 or nil end
UnitIsDeadOrGhost = function(u)
  if u == "player" then return W.dead and 1 or nil end
  if u == "target" then return (W.target and W.target.dead) and 1 or nil end
  return nil
end
UnitIsPlayer = function(u) return (u == "target" and W.target and W.target.player) and 1 or nil end
UnitHealth = function(u)
  if u == "player" then return W.hp end
  if u == "target" and W.target then return W.target.hp end
  return 0
end
UnitHealthMax = function(u)
  if u == "player" then return W.hpMax end
  if u == "target" and W.target then return W.target.hpMax end
  return 0
end
UnitMana = function(u) return W.mana end
UnitManaMax = function(u) return W.manaMax end
UnitLevel = function(u)
  if u == "player" then return 60 end
  if u == "target" and W.target then return W.target.level or 60 end
  return 0
end
UnitClassification = function(u)
  if u == "target" and W.target then return W.target.class or "normal" end
  return "normal"
end
UnitCreatureType = function(u)
  if u == "target" and W.target then return W.target.ctype or "Humanoid" end
  return nil
end
UnitClass = function(u) return "Paladin", W.class or "PALADIN" end
UnitAffectingCombat = function(u)
  if u ~= "player" then local p = plateOf(u); if p then return (p.combat ~= false) and 1 or nil end end
  return W.combat and 1 or nil
end
UnitAttackSpeed = function(u) return W.attackSpeed, W.attackSpeed end
UnitBuff = function(u, i)
  if u ~= "player" then return nil end
  local b = W.pbuffs[i]
  if b then return b.tex, b.stacks or 1, (not W.noSpellId) and b.sid or nil end
  return nil
end
UnitDebuff = function(u, i)
  if u ~= "target" or not W.target then return nil end
  local d = W.target.debuffs[i]
  if d then return d.tex, d.stacks or 1 end
  return nil
end
GetPlayerBuff = function(j, filter) return j end
GetPlayerBuffTexture = function(idx) local b = W.pbuffs[idx + 1]; return b and b.tex or nil end
GetPlayerBuffTimeLeft = function(idx) local b = W.pbuffs[idx + 1]; if b then return b.exp - NOW end return nil end

-- ---------------------------------------------------------------- ciblage
ClearTarget = function() W.lastTarget = W.target; W.target = nil; log("ClearTarget") end
TargetNearestEnemy = function()
  log("TargetNearestEnemy")
  W.target = W.mobs[1]
end
TargetLastTarget = function()
  log("TargetLastTarget")
  if W.lastTarget then W.target = W.lastTarget end
end
AttackTarget = function() log("AttackTarget") end

-- ---------------------------------------------------------------- sorts
GetSpellName = function(i, bt) return W.book[i] end
GetSpellTexture = function(i, bt)
  local n = W.book[i]
  local d = n and W.defs[n]
  return d and d.tex or nil
end
GetSpellCooldown = function(i, bt)
  local n = W.book[i]
  if not n then return 0, 0, 1 end
  local cs, cd = W.cdStart[n], W.cdDur[n]
  if cs and cd and cs + cd > NOW then return cs, cd, 1 end
  local d = W.defs[n]
  if d and d.gcd and W.gcdEnd > NOW then return W.gcdStart, W.gcdEnd - W.gcdStart, 1 end
  return 0, 0, 1
end
CASTS = {}   -- toutes les tentatives : { t, name, ok, why }
CastSpellByName = function(n)
  log("CAST " .. n)
  local ok, why = SIM_TRY_CAST(n)
  table.insert(CASTS, { t = NOW, name = n, ok = ok, why = why })
end
IsSpellInRange = function(name, unit)
  if W.noRange then error("IsSpellInRange indisponible") end
  if not W.target then return nil end
  if W.rangeForce and W.rangeForce[name] ~= nil then return W.rangeForce[name] end
  local d = W.defs[name]
  if not d or not d.range then return nil end
  return (W.target.dist or 0) <= d.range and 1 or 0
end

-- plaques de nom (technique du guerrier) : PLATES = { {guid=, dist=, hostile=, dead=, combat=} }
PLATES = {}
local function plateObj(p)
  return { IsObjectType = function(self, t) return t == "Button" end, IsShown = function() return p.shown ~= false end,
           GetName = function(self, i) return p.guid end }
end
WorldFrame = { GetChildren = function(self) local t = {}; for i = 1, table.getn(PLATES) do t[i] = plateObj(PLATES[i]) end; return table.unpack(t) end }
function plateOf(g) for i = 1, table.getn(PLATES) do if PLATES[i].guid == g then return PLATES[i] end end end
UnitReaction = function(u, o) local p = plateOf(u); if not p then return nil end; return (p.hostile == false) and 5 or 2 end
UnitIsDead = function(u) local p = plateOf(u); return (p and p.dead) and 1 or nil end
if W.useXP then end
UnitXP = function(cmd, a, b)
  if W.noXP then error("UnitXP absent") end
  if b == "target" then return W.target and W.target.dist or nil end
  local p = plateOf(b); return p and p.dist or nil
end

-- ---------------------------------------------------------------- inventaire, talents, groupe, zone
GetInventoryItemLink = function(u, s) if W.inv[s] then return "|cffa335ee|Hitem:" .. W.inv[s] .. ":0:0:0|h[Objet]|h|r" end return nil end
GetInventoryItemTexture = function(u, s) if W.inv[s] then return "Interface\\Icons\\INV_Misc_Gem_01" end return nil end
GetInventoryItemCooldown = function(u, s)
  if W.invcd[s] and W.invcd[s] > NOW then return W.invcd[s] - 120, 120, 1 end
  return 0, 0, 1
end
UseInventoryItem = function(s)
  log("USE " .. s)
  W.invcd[s] = NOW + 120
  local id = W.inv[s]
  if W.itemGcd and W.itemGcd[id] then W.gcdStart = NOW; W.gcdEnd = NOW + 1.5 end
end
GetNumTalentTabs = function() return table.getn(W.talents) end
GetNumTalents = function(t) return W.talents[t] and table.getn(W.talents[t].list) or 0 end
GetTalentInfo = function(t, i)
  local e = W.talents[t] and W.talents[t].list[i]
  if not e then return nil end
  return e[1], "Interface\\Icons\\X", 1, 1, e[2], e[3]
end
GetNumRaidMembers = function() return W.raid end
GetNumPartyMembers = function() return W.party end
GetRealZoneText = function() return W.zone end
GetZoneText = function() return W.zone end
GetAddOnMetadata = function(a, f) if f == "Version" then return "2.1.0" end return nil end
PlaySound = function(s) log("SOUND " .. tostring(s)) end

-- ---------------------------------------------------------------- touches
GetBindingKey = function(name) return W.bindings[name] end
SetBinding = function(key, name)
  for n, k in pairs(W.bindings) do if k == key then W.bindings[n] = nil end end
  if name then W.bindings[name] = key end
end
SaveBindings = function(set) end
GetCurrentBindingSet = function() return 1 end
IsAltKeyDown = function() return false end
IsControlKeyDown = function() return false end
IsShiftKeyDown = function() return W.shift end

-- ---------------------------------------------------------------- chat
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) table.insert(CHAT, m); log("CHAT " .. m) end }
UIErrorsFrame = { AddMessage = function(self, m) log("ERRFRAME " .. m) end }
SlashCmdList = {}
UISpecialFrames = {}

-- ---------------------------------------------------------------- widgets (liste blanche des methodes 1.12)
local WOW112 = {}
for w in string.gmatch([[SetWidth GetWidth SetHeight GetHeight SetPoint GetPoint GetNumPoints ClearAllPoints SetAllPoints Show Hide IsShown IsVisible SetAlpha GetAlpha SetParent GetParent GetName GetLeft GetRight GetTop GetBottom GetCenter SetScript GetScript RegisterEvent UnregisterEvent UnregisterAllEvents IsEventRegistered SetFrameStrata GetFrameStrata SetFrameLevel GetFrameLevel SetMovable IsMovable SetResizable EnableMouse IsMouseEnabled EnableMouseWheel EnableKeyboard IsKeyboardEnabled RegisterForDrag StartMoving StopMovingOrSizing StartSizing SetBackdrop SetBackdropColor SetBackdropBorderColor GetBackdrop CreateTexture CreateFontString SetScale GetScale GetEffectiveScale SetToplevel SetClampedToScreen SetHitRectInsets IsObjectType GetObjectType GetChildren GetRegions GetNumChildren GetNumRegions SetID GetID Raise Lower SetMinResize SetMaxResize SetUserPlaced SetTexture GetTexture SetTexCoord GetTexCoord SetVertexColor SetBlendMode SetDesaturated SetGradient SetGradientAlpha SetDrawLayer GetDrawLayer SetText GetText SetFont GetFont SetFontObject GetFontObject SetTextColor SetJustifyH SetJustifyV SetShadowColor SetShadowOffset GetStringWidth GetStringHeight SetNonSpaceWrap SetTextHeight GetTextHeight SetNormalTexture SetPushedTexture SetHighlightTexture SetDisabledTexture GetNormalTexture GetPushedTexture GetHighlightTexture GetDisabledTexture RegisterForClicks Enable Disable IsEnabled Click LockHighlight UnlockHighlight SetTextFontObject GetFontString SetNormalFontObject SetHighlightFontObject SetDisabledFontObject SetChecked GetChecked SetCheckedTexture GetCheckedTexture SetDisabledCheckedTexture SetMinMaxValues GetMinMaxValues SetValue GetValue SetValueStep GetValueStep SetOrientation GetOrientation SetThumbTexture GetThumbTexture SetStatusBarTexture SetStatusBarColor GetStatusBarTexture GetStatusBarColor SetAutoFocus SetFocus ClearFocus HasFocus SetMaxLetters SetMaxBytes SetNumeric SetNumber GetNumber SetMultiLine SetTextInsets HighlightText Insert SetPassword SetAltArrowKeyMode SetOwner AddLine AddDoubleLine SetInventoryItem SetHyperlink ClearLines NumLines SetBagItem SetUnit SetSpell SetAction SetScrollChild SetVerticalScroll GetVerticalScroll GetVerticalScrollRange UpdateScrollChildRect SetModel SetTimeVisible SetMaxLines AddMessage SetFading SetFadeDuration SetHyperlinksEnabled GetNumLines]], "%S+") do WOW112[w] = true end

ALLFRAMES = {}
local function newFrame(name, kind)
  local f = { scripts = {}, name = name, shown = true, events = {}, kind = kind, points = {}, value = 0, minv = 0, maxv = 100, text = nil }
  setmetatable(f, { __index = function(t, k)
    if k == "GetName" then return function() return name end end
    if type(k) == "string" and string.find(k, "^%u") and not WOW112[k] then error("API absente de WoW 1.12 : " .. k, 2) end
    if type(k) == "string" and string.find(k, "^%u") then return function() return f end end
    return nil end })
  f.SetScript = function(self, k, fn) self.scripts[k] = fn end
  f.GetScript = function(self, k) return self.scripts[k] end
  f.RegisterEvent = function(self, ev) self.events[ev] = true end
  f.UnregisterEvent = function(self, ev) self.events[ev] = nil end
  f.CreateFontString = function(self) return newFrame(nil, "FontString") end
  f.CreateTexture = function(self) return newFrame(nil, "Texture") end
  f.SetChecked = function(self, v) self.checked = v and true or false end
  f.GetChecked = function(self) return self.checked and 1 or nil end
  f.IsShown = function(self) return self.shown end
  f.IsVisible = function(self) return self.shown end
  f.Show = function(self)
    if not self.shown then
      self.shown = true
      if self.scripts.OnShow then local o = this; this = self; self.scripts.OnShow(); this = o end
    end
  end
  f.Hide = function(self)
    if self.shown then
      self.shown = false
      if self.scripts.OnHide then local o = this; this = self; self.scripts.OnHide(); this = o end
    end
  end
  f.GetText = function(self) return self.text or "" end
  f.SetText = function(self, t) self.text = t end
  f.SetMinMaxValues = function(self, a, b) self.minv = a; self.maxv = b end
  f.GetValue = function(self) return self.value end
  f.SetValue = function(self, v)
    if v < self.minv then v = self.minv end
    if v > self.maxv then v = self.maxv end
    local changed = (v ~= self.value)
    self.value = v
    if changed and self.scripts.OnValueChanged then
      local o = this; this = self; self.scripts.OnValueChanged(); this = o
    end
  end
  f.GetTop = function() return 800 end
  f.GetBottom = function() return 100 end
  f.GetLeft = function() return 100 end
  f.GetRight = function() return 500 end
  f.GetCenter = function() return 0, 0 end
  f.GetWidth = function(self) return self.w or 100 end
  f.GetHeight = function(self) return self.h or 20 end
  f.SetWidth = function(self, w) self.w = w end
  f.SetHeight = function(self, h) self.h = h end
  f.GetFrameLevel = function() return 1 end
  f.GetStringWidth = function() return 50 end
  f.HasFocus = function() return false end
  f.GetParent = function(self) return self.parent end
  f.SetPoint = function(self, ...) end
  f.Click = function(self)
    if self.scripts.OnClick then local o = this; this = self; self.scripts.OnClick(); this = o end
  end
  table.insert(ALLFRAMES, f)
  return f
end
CreateFrame = function(kind, name, parent, tmpl)
  local f = newFrame(name, kind)
  f.parent = parent
  if name then
    _G[name] = f
    _G[name .. "Text"] = newFrame(nil, "FontString")
    _G[name .. "Low"] = newFrame(nil, "FontString")
    _G[name .. "High"] = newFrame(nil, "FontString")
  end
  return f
end
UIParent = newFrame("UIParent", "Frame")
UIParent.GetHeight = function() return 1080 end
UIParent.GetWidth = function() return 1920 end
GameTooltip = nil     -- les suites qui testent les infobulles definissent leur propre GameTooltip
ChatFrameEditBox = nil

-- Evenements : envoyes a TOUTES les frames qui les ont enregistres, comme le client
FIRED = {}
function Fire(ev, a1, a2, a3, a4, a5)
  event = ev; arg1, arg2, arg3, arg4, arg5 = a1, a2, a3, a4, a5
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if f.events[ev] and f.scripts.OnEvent then
      this = f
      f.scripts.OnEvent()
    end
  end
end
-- Horloge : fait avancer le temps et appelle les OnUpdate des frames visibles
function Pump(dt)
  NOW = NOW + dt
  SIM_EXPIRE()
  arg1 = dt
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if f.shown and f.scripts.OnUpdate then
      this = f
      arg1 = dt
      f.scripts.OnUpdate()
    end
  end
end

-- ---------------------------------------------------------------- mode strict
-- Globales optionnelles : extensions du client (Nampower / SuperWoW / UnitXP) ou API absentes de certains clients.
local OPTIONAL = {
  IsSpellInRange = true, GetNampowerVersion = true, SpellInfo = true, SUPERWOW_VERSION = true, GetUnitField = true,
  TargetNearestEnemyPlayer = true, IsMounted = true, IsInInstance = true, StartDuel = true, AcceptDuel = true,
  UnitXP = true, ShamanRotationDB = true, SlashCmdList = true, ShikiwaRotation_Silent = true, ShikaSwap = true, GameTooltip = true, ChatFrameEditBox = true,
  event = true, this = true, arg1 = true, arg2 = true, arg3 = true, arg4 = true, arg5 = true, arg6 = true, arg7 = true,
  ShikiwaRotationDB = true, ShikiwaRotation = true, DONE = true,
  TESTS_DONE = true, LEGACY = true, FIXTURES = true, OctoManaSwap_API = true, WorldFrame = true, UnitReaction = true, UnitIsDead = true, SIM_TRY_CAST = true, SIM_EXPIRE = true, Fire = true, Pump = true,
}
function STRICT_ON()
  setmetatable(_G, { __index = function(t, k)
    if OPTIONAL[k] or (type(k) == "string" and (string.find(k, "^BINDING_") or string.find(k, "^SLASH_") or string.find(k, "^ShikiwaRot"))) then return nil end
    error("globale non definie lue : " .. tostring(k), 2)
  end })
end
function STRICT_OFF() setmetatable(_G, nil) end
function OPTIONAL_ALLOW(name) OPTIONAL[name] = true end

-- Retire des API optionnelles / d'extension (test "client sans extensions")
function NOAPI_REMOVE()
  local list = { "IsSpellInRange", "GetNampowerVersion", "SpellInfo", "GetUnitField", "TargetNearestEnemyPlayer", "TargetLastTarget", "IsMounted",
    "IsInInstance", "StartDuel", "AcceptDuel", "UnitClassification", "GetSpellTexture", "GetNumTalentTabs", "GetNumTalents", "GetTalentInfo",
    "GetPlayerBuff", "GetPlayerBuffTexture", "GetPlayerBuffTimeLeft", "GetRealZoneText", "GetZoneText", "GetAddOnMetadata", "GetInventoryItemTexture",
    "UnitClass", "GetNumRaidMembers", "GetNumPartyMembers", "ChatFrameEditBox", "GameTooltip", "PlaySound", "UIErrorsFrame", "UnitXP", "WorldFrame", "UnitReaction", "UnitIsDead", "OctoManaSwap_API" }
  for i = 1, table.getn(list) do
    OPTIONAL[list[i]] = true
    _G[list[i]] = nil
  end
end

-- ---------------------------------------------------------------- minimap (ShamanRotation)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
GetCursorPosition = function() return 150, 150 end
if not math.atan2 then math.atan2 = function(y, x) return math.atan(y, x) end end
if not math.deg then math.deg = function(r) return r * 180 / math.pi end end

-- ---------------------------------------------------------------- sacs et echange de relique (ShamanRotation)
W.bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
GetContainerNumSlots = function(bag) return W.bags[bag] and table.getn(W.bags[bag]) or 0 end
GetContainerItemLink = function(bag, slot)
  local id = W.bags[bag] and W.bags[bag][slot]
  if id and id ~= 0 then return "|cffa335ee|Hitem:" .. id .. ":0:0:0|h[Objet]|h|r" end
  return nil
end
UseContainerItem = function(bag, slot)
  local id = W.bags[bag] and W.bags[bag][slot]
  if not id or id == 0 then return end
  log("EQUIP " .. id)
  local old = W.inv[18]
  W.inv[18] = id
  W.bags[bag][slot] = old or 0
  W.equips = (W.equips or 0) + 1
  -- equiper en combat declenche un GCD de 1,5 s (Player.cpp)
  if W.combat then W.gcdStart = NOW; W.gcdEnd = NOW + 1.5 end
end

GetBindingAction = function(key) for n, k in pairs(W.bindings) do if k == key then return n end end return "" end

-- noms / existence des unites designees par GUID de plaque (totems) : ShamanRotation
do
  local origName, origExists = UnitName, UnitExists
  UnitName = function(u) local p = plateOf(u); if p and p.name then return p.name end return origName(u) end
  UnitExists = function(u) local p = plateOf(u); if p then if p.gone then return nil end return 1, u end return origExists(u) end
end
