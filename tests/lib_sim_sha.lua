-- lib_sim_sha.lua : outils de test + mini-simulateur de combat chaman (GCD, recharges partagees des chocs, mana, incantations)
-- Donnees = Spell.dbc / spell_template du serveur (voir DESIGN.md) : GCD 1,5 s ; chocs : categorie 19, recharge 6 s ; Chain Lightning 6 s ;
-- Earthquake 16 s ; Elemental Mastery 180 s ; Blood Fury 120 s.

FAILS, PASSES = 0, 0
VERBOSE = false
function eq(a, b, msg)
  if a ~= b then FAILS = FAILS + 1; print("FAIL: " .. msg .. " (obtenu " .. tostring(a) .. ", attendu " .. tostring(b) .. ")")
  else PASSES = PASSES + 1; if VERBOSE then print("ok: " .. msg) end end
end
function ok(cond, msg)
  if not cond then FAILS = FAILS + 1; print("FAIL: " .. msg) else PASSES = PASSES + 1; if VERBOSE then print("ok: " .. msg) end end
end
function DONE()
  print(string.format("%d verifications OK, %d ECHECS", PASSES, FAILS))
  TESTS_DONE = true
  if FAILS > 0 then os.exit(1) end
end

SIM = {}
FS_TEX = "Interface\\Icons\\Spell_Fire_FlameShock"
local SHOCKS = { "Flame Shock", "Earth Shock", "Frost Shock" }
local DEFS = {}
local function shockCd(n) for i = 1, 3 do W.cdStart[SHOCKS[i]] = NOW; W.cdDur[SHOCKS[i]] = 6 end end
DEFS["Lightning Bolt"] = { gcd = true, cast = 3.0, mana = 265, range = 30, hostile = true, tex = "Interface\\Icons\\Spell_Nature_Lightning" }
DEFS["Chain Lightning"] = { gcd = true, cast = 2.5, cd = 6, mana = 605, range = 30, hostile = true, tex = "Interface\\Icons\\Spell_Nature_ChainLightning" }
DEFS["Earthquake"] = { gcd = true, cast = 2.5, cd = 16, mana = 440, range = 30, hostile = true, tex = "Interface\\Icons\\Spell_Nature_EarthQuake" }
DEFS["Flame Shock"] = { gcd = true, shock = true, mana = 410, range = 20, hostile = true, tex = FS_TEX,
  onCast = function() SIM.addDebuff(FS_TEX, 15); shockCd() end }
DEFS["Earth Shock"] = { gcd = true, shock = true, mana = 450, range = 20, hostile = true, tex = "Interface\\Icons\\Spell_Nature_EarthShock", onCast = function() shockCd() end }
DEFS["Frost Shock"] = { gcd = true, shock = true, mana = 430, range = 20, hostile = true, tex = "Interface\\Icons\\Spell_Frost_FrostShock", onCast = function() shockCd() end }
DEFS["Molten Blast"] = { gcd = true, cast = 2.0, mana = 210, range = 30, hostile = true, tex = "Interface\\Icons\\Spell_Fire_Fireball02",
  onCast = function() for i = 1, table.getn(W.target.debuffs) do if W.target.debuffs[i].tex == FS_TEX then W.target.debuffs[i].exp = NOW + 15 end end end }
DEFS["Elemental Mastery"] = { gcd = false, cd = 180, mana = 0, tex = "Interface\\Icons\\Spell_Nature_WispHeal" }
DEFS["Blood Fury"] = { gcd = false, cd = 120, mana = 0, tex = "Interface\\Icons\\Racial_Orc_BerserkerStrength" }
local TOTEMS = { "Searing Totem", "Magma Totem", "Fire Nova Totem", "Flametongue Totem", "Mana Spring Totem", "Healing Stream Totem", "Poison Cleansing Totem",
  "Disease Cleansing Totem", "Tranquil Air Totem", "Windfury Totem", "Grace of Air Totem", "Strength of Earth Totem", "Tremor Totem", "Stoneskin Totem" }
for i = 1, table.getn(TOTEMS) do DEFS[TOTEMS[i]] = { gcd = true, mana = 150, tex = "Interface\\Icons\\Spell_Nature_Totem" } end
SIM.DEFS = DEFS

function SIM.addDebuff(tex, dur)
  if W.target then table.insert(W.target.debuffs, { tex = tex, exp = NOW + (dur or 10) }) end
end
function SIM.addBuff(tex, sid, stacks, dur)
  table.insert(W.pbuffs, { tex = tex, sid = sid, stacks = stacks or 1, exp = NOW + (dur or 30) })
end
function SIM_EXPIRE()
  for i = table.getn(W.pbuffs), 1, -1 do if W.pbuffs[i].exp <= NOW then table.remove(W.pbuffs, i) end end
  if W.target then
    for i = table.getn(W.target.debuffs), 1, -1 do
      if W.target.debuffs[i].exp and W.target.debuffs[i].exp <= NOW then table.remove(W.target.debuffs, i) end
    end
  end
end

local function hostile() return W.target and not W.target.friend and not W.target.dead end
function SIM_TRY_CAST(n)
  local idx = nil
  for i = 1, table.getn(W.book) do if W.book[i] == n then idx = i end end
  if not idx then return false, "inconnu" end
  local d = W.defs[n]
  if not d then return false, "sans definition" end
  if W.reject and W.reject[n] then return false, "refuse par le serveur" end
  if W.castEnd and W.castEnd > NOW then return false, "incantation en cours" end
  local cs, cd = W.cdStart[n], W.cdDur[n]
  if cs and cd and cs + cd > NOW then return false, "recharge" end
  if d.gcd and W.gcdEnd > NOW then return false, "gcd" end
  if W.mana < d.mana then Fire("UI_ERROR_MESSAGE", "Not enough mana"); return false, "mana" end
  if d.hostile then
    if not hostile() then return false, "cible" end
    if d.range and (W.target.dist or 0) > d.range then return false, "portee" end
  end
  W.mana = W.mana - d.mana
  if d.gcd then W.gcdStart = NOW; W.gcdEnd = NOW + 1.5 end
  if d.cd then W.cdStart[n] = NOW; W.cdDur[n] = d.cd end
  if d.cast then W.castEnd = NOW + d.cast; Fire("SPELLCAST_START", n, d.cast * 1000) end
  if d.onCast then d.onCast(n) end
  return true
end

function SIM.setup(opts)
  opts = opts or {}
  W.book = {}
  W.defs = DEFS
  local names = opts.book or { "Lightning Bolt", "Chain Lightning", "Earthquake", "Flame Shock", "Earth Shock", "Frost Shock", "Molten Blast", "Elemental Mastery",
    "Blood Fury", "Searing Totem", "Magma Totem", "Fire Nova Totem", "Flametongue Totem", "Mana Spring Totem", "Tranquil Air Totem", "Windfury Totem",
    "Strength of Earth Totem", "Tremor Totem", "Poison Cleansing Totem", "Disease Cleansing Totem" }
  for i = 1, table.getn(names) do W.book[i] = names[i] end
  Fire("SPELLS_CHANGED")
  W.cdStart, W.cdDur = {}, {}
  W.gcdStart, W.gcdEnd = 0, 0
  W.castEnd = nil
  W.mana, W.manaMax = 9000, 9000
  W.hp, W.hpMax = 5000, 5000
  W.combat = true; W.dead = false; W.mounted = false
  W.class = "SHAMAN"
  W.pbuffs = {}
  W.inv, W.invcd = {}, {}
  W.talents = {}
  W.noRange = false; W.noSpellId = false; W.noXP = false
  W.reject = {}; W.rangeForce = {}
  W.mobs = {}
  CASTS = {}; LOG = {}; CHAT = {}
  PLATES = {}
  SIM.newTarget(opts.target)
  NOW = NOW + 100
end
function SIM.newTarget(t)
  t = t or {}
  W.target = { name = t.name or "Defias Thug", guid = t.guid or ("0xMOB" .. tostring(math.floor(NOW))), hp = 100000, hpMax = 100000, level = 60, class = "normal",
    player = false, ctype = "Humanoid", dist = t.dist or 20, friend = false, dead = false, debuffs = {} }
  W.mobs = { W.target }
  return W.target
end
function SIM.load(db)
  ShamanRotationDB = db
  Fire("VARIABLES_LOADED")
end
function SIM.press()
  if W.castEnd and W.castEnd <= NOW then W.castEnd = nil; Fire("SPELLCAST_STOP") end
  local n0 = table.getn(CASTS)
  ShamanRotation_Execute()
  if table.getn(CASTS) > n0 then return CASTS[table.getn(CASTS)].name, CASTS[table.getn(CASTS)].ok end
  return nil
end
function SIM.count(name)
  local c = 0
  for i = 1, table.getn(CASTS) do if CASTS[i].name == name and CASTS[i].ok then c = c + 1 end end
  return c
end
function SIM.attempts(name)
  local c = 0
  for i = 1, table.getn(CASTS) do if CASTS[i].name == name then c = c + 1 end end
  return c
end
function SIM.run(secs, dt, hook)
  dt = dt or 0.1
  local t = 0
  while t < secs do
    if hook then hook(t) end
    SIM.press()
    Pump(dt)
    t = t + dt
  end
end
function SIM.trace(t0)
  local out = {}
  for i = 1, table.getn(CASTS) do
    if CASTS[i].ok then table.insert(out, CASTS[i].name .. "@" .. string.format("%.1f", CASTS[i].t - (t0 or 0))) end
  end
  return table.concat(out, ", ")
end
