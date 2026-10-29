-- t_sha.lua : ShamanRotation 0.1.0 (Elementaire). Simulateur : GCD 1,5 s, chocs a recharge partagee de 6 s, incantations, mana.
local SH = ShamanRotation
local CFG = SH.CFG

local function fresh(opts)
  SIM.setup(opts); SIM.load(nil)
  SH.autoAoe = false; SH.autoN = nil
  SH.fs = { guid = nil, at = -100 }
  SH.noMana = {}; SH.block = {}; SH.castUntil = 0
  SH.burst.armed = false
  SH.totems = {}; SH.totemTry = -10
  SH.enemies = { list = {}, plates = 0, known = false, at = -10 }
  SH.castsByGuid = {}
  for k, v in pairs(SH.DEFAULTS) do CFG[k] = v end
end

-- ===== 1. mono, 70 s : Flame Shock entretenu, Chain Lightning a chaque retour, Lightning Bolt de remplissage, jamais d'Earth Shock
fresh(); W.mana = 90000; W.manaMax = 90000
SIM.run(70, 0.1)
ok(SIM.count("Flame Shock") >= 5 and SIM.count("Flame Shock") <= 8, "mono 70 s : Flame Shock entretenu (" .. SIM.count("Flame Shock") .. ")")
ok(SIM.count("Chain Lightning") >= 8, "mono 70 s : Chain Lightning a chaque retour (" .. SIM.count("Chain Lightning") .. ")")
ok(SIM.count("Lightning Bolt") >= 8, "mono 70 s : Lightning Bolt de remplissage (" .. SIM.count("Lightning Bolt") .. ")")
eq(SIM.count("Earth Shock"), 0, "mono : aucun Earth Shock de remplissage (les meilleurs joueurs : ~2/min, option esFill)")
eq(SIM.count("Earthquake"), 0, "mono : Earthquake reserve a l'AoE")
-- Flame Shock jamais lance alors qu'il reste plus de fsRefresh s sur la cible
local lastFs, bad = nil, 0
for i = 1, table.getn(CASTS) do
  if CASTS[i].name == "Flame Shock" and CASTS[i].ok then
    if lastFs and (CASTS[i].t - lastFs) < (15 - CFG.fsRefresh - 1.6) then bad = bad + 1 end
    lastFs = CASTS[i].t
  end
end
eq(bad, 0, "Flame Shock jamais rafraichi trop tot")

-- ===== 2. ordre exact au pull : Flame Shock d'abord, puis Chain Lightning, puis Lightning Bolt
fresh()
eq(SIM.press(), "Flame Shock", "pull : Flame Shock en premier")
Pump(1.6)
eq(SIM.press(), "Chain Lightning", "... puis Chain Lightning (prete)")
Pump(2.6)
eq(SIM.press(), "Lightning Bolt", "... puis Lightning Bolt (Chain Lightning en recharge)")

-- ===== 3. incantation en cours : on n'envoie rien (aucun sort qui interromprait)
fresh()
SIM.press()                -- Flame Shock (instantane)
Pump(1.6)
SIM.press()                -- Chain Lightning (2,5 s)
Pump(0.5)
local n0 = table.getn(CASTS)
SIM.press()
eq(table.getn(CASTS), n0, "pendant l'incantation : aucun nouvel appui envoye")

-- ===== 4. AoE automatique : 3 ennemis a moins de 10 m de la cible -> Earthquake
fresh()
PLATES = { { guid = "0xA", dist = 0 }, { guid = "0xB", dist = 5 }, { guid = "0xC", dist = 8 } }
Pump(1.0)
ok(SH.AoeOn(), "3 ennemis proches : AoE automatique")
SIM.run(12, 0.1)
ok(SIM.count("Earthquake") >= 1, "AoE : Earthquake lance")
eq(SIM.count("Earthquake") <= 1, true, "AoE : Earthquake (recharge 16 s) pas plus d'une fois en 12 s")
fresh()
PLATES = { { guid = "0xA", dist = 0 }, { guid = "0xB", dist = 25 } }
Pump(1.0)
ok(not SH.AoeOn(), "ennemi a 25 m de la cible : pas d'AoE")
fresh(); CFG.aoeMode = "on"
SIM.run(6, 0.1)
ok(SIM.count("Earthquake") >= 1, "AoE manuelle (on) : Earthquake sans comptage")
fresh(); CFG.aoeMode = "off"; PLATES = { { guid = "0xA", dist = 0 }, { guid = "0xB", dist = 5 }, { guid = "0xC", dist = 8 } }
SIM.run(6, 0.1)
eq(SIM.count("Earthquake"), 0, "AoE coupee : jamais d'Earthquake")

-- ===== 5. interruption : la cible incante -> Earth Shock (instantane, avant le reste)
fresh()
SIM.press(); Pump(1.6)       -- Flame Shock pose, les chocs sont en recharge 6 s
Pump(6.1)                    -- chocs prets
Fire("UNIT_CASTEVENT", W.target.guid, nil, "START", 1234, 2000)
eq(SIM.press(), "Earth Shock", "la cible incante : Earth Shock")
Fire("UNIT_CASTEVENT", W.target.guid, nil, "FAIL", 1234, 0)
fresh(); CFG.interrupt = false
Fire("UNIT_CASTEVENT", W.target.guid, nil, "START", 1234, 2000)
ok(SIM.press() ~= "Earth Shock", "interruption coupee : pas d'Earth Shock")

-- ===== 6. immunite apprise : "Your Flame Shock failed. X is immune." -> plus de Flame Shock sur ce mob, retenu a la sauvegarde
fresh()
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Flame Shock failed. " .. W.target.name .. " is immune.")
ok(SH.Immune("fire", W.target.name), "immunite Feu retenue")
SIM.run(12, 0.1)
eq(SIM.count("Flame Shock"), 0, "mob immunise au Feu : aucun Flame Shock")
ok(SIM.count("Chain Lightning") >= 1 and SIM.count("Lightning Bolt") >= 1, "... la rotation continue (Nature)")
ok(ShamanRotationDB.immune.fire[W.target.name] == true, "immunite sauvegardee")
fresh()
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Flame Shock failed. Autre mob is immune.")
SIM.press()
eq(SIM.count("Flame Shock"), 1, "un autre mob n'est pas immunise")

-- ===== 7. mana : sous manaCl, plus de Flame Shock / Chain Lightning ; Lightning Bolt seul
fresh(); W.mana = 900     -- 10 %
SIM.run(10, 0.1)
eq(SIM.count("Chain Lightning"), 0, "mana 10 % : pas de Chain Lightning")
eq(SIM.count("Flame Shock"), 0, "mana 10 % : pas de Flame Shock")
ok(SIM.count("Lightning Bolt") >= 1, "mana 10 % : Lightning Bolt")
-- refus 'Not enough mana' : le sort est mis de cote jusqu'a ce que la mana remonte
fresh(); W.mana = 300; CFG.manaCl = 0
SIM.press()
ok(SH.Blocked("Flame Shock") or SH.Blocked("Chain Lightning") or SH.Blocked("Lightning Bolt"), "refus mana : sort mis de cote")
local a0 = SIM.attempts("Lightning Bolt") + SIM.attempts("Chain Lightning") + SIM.attempts("Flame Shock")
SIM.run(3, 0.1)
ok(SIM.attempts("Lightning Bolt") + SIM.attempts("Chain Lightning") + SIM.attempts("Flame Shock") - a0 <= 3, "mana : pas de rafale de tentatives refusees")

-- ===== 8. burst : Elemental Mastery + Blood Fury, une seule fois, sans GCD
fresh()
ShamanRotation_Burst()
eq(SIM.count("Elemental Mastery"), 1, "burst : Elemental Mastery")
eq(SIM.count("Blood Fury"), 1, "burst : Blood Fury")
ok(not SH.burst.armed, "burst desarme apres le tir")
ShamanRotation_Burst()
eq(SIM.count("Elemental Mastery"), 1, "burst relance : Elemental Mastery en recharge, pas de 2e tir")
fresh(); CFG.burstBf = false
ShamanRotation_Burst()
eq(SIM.count("Blood Fury"), 0, "burst : Blood Fury decoche")
fresh({ book = { "Lightning Bolt", "Chain Lightning", "Flame Shock" } })
ShamanRotation_Burst()
eq(SIM.count("Elemental Mastery") + SIM.count("Blood Fury"), 0, "burst sans les sorts : rien, pas d'erreur")

-- ===== 9. totems : preset caster = Searing (feu), Tranquil Air (air), Mana Spring (eau) ; un par appui ; puis "en place"
fresh(); CFG.totemPreset = "caster"
ShamanRotation_Totems(); eq(CASTS[table.getn(CASTS)].name, "Searing Totem", "totem 1 : feu")
Pump(1.6); ShamanRotation_Totems(); eq(CASTS[table.getn(CASTS)].name, "Tranquil Air Totem", "totem 2 : air")
Pump(1.6); ShamanRotation_Totems(); eq(CASTS[table.getn(CASTS)].name, "Mana Spring Totem", "totem 3 : eau")
Pump(1.6); local nt = table.getn(CASTS); ShamanRotation_Totems()
eq(table.getn(CASTS), nt, "totems en place : rien de plus")
fresh(); CFG.totemPreset = "melee"
ShamanRotation_Totems(); Pump(1.6); ShamanRotation_Totems(); Pump(1.6); ShamanRotation_Totems(); Pump(1.6); ShamanRotation_Totems()
eq(SIM.count("Flametongue Totem") + SIM.count("Windfury Totem") + SIM.count("Strength of Earth Totem") + SIM.count("Mana Spring Totem"), 4, "preset cac : 4 totems")
-- Searing dure 55 s : repose apres expiration
fresh(); CFG.totemPreset = "caster"; CFG.totemsInCombat = true; W.mana = 90000; W.manaMax = 90000
SIM.press(); Pump(1.6)
eq(SIM.count("Searing Totem"), 1, "rotation : totem de feu pose en combat (option)")
SIM.run(40, 0.1)
eq(SIM.count("Searing Totem"), 1, "Searing Totem tient 55 s : pas repose avant")
SIM.run(20, 0.1)
eq(SIM.count("Searing Totem"), 2, "Searing Totem repose apres 55 s")
-- AoE : Magma Totem remplace Searing
fresh(); CFG.totemPreset = "caster"; CFG.totemsInCombat = true; CFG.aoeMode = "on"
SIM.press()
eq(SIM.count("Magma Totem"), 1, "AoE : Magma Totem")
fresh(); CFG.totemPreset = "fear"
ShamanRotation_Totems(); Pump(1.6); ShamanRotation_Totems(); Pump(1.6); ShamanRotation_Totems(); Pump(1.6); ShamanRotation_Totems(); Pump(1.6)
eq(SIM.count("Tremor Totem"), 1, "preset anti-peur : Tremor Totem")
-- reinitialisation a la mort
fresh(); ShamanRotation_Totems(); ok(SH.totems.fire ~= nil, "totem note")
Fire("PLAYER_DEAD"); ok(SH.totems.fire == nil, "mort : suivi des totems remis a zero")

-- ===== 10. sans extensions (pas de Nampower / UnitXP) : tourne sans erreur
fresh(); W.noRange = true; W.noXP = true
local okp, err = pcall(function() SIM.run(30, 0.1) end)
ok(okp, "sans IsSpellInRange / UnitXP : aucune erreur (" .. tostring(err) .. ")")
ok(SIM.count("Lightning Bolt") >= 1, "... et la rotation tourne")

-- ===== 11. commandes
local okc, errc = pcall(function()
  SH.Slash("status"); SH.Slash("aoe on"); SH.Slash("aoe auto"); SH.Slash("totems melee"); SH.Slash("immune fire"); SH.Slash("set fsRefresh 5"); SH.Slash("set useMb on")
  SH.Slash("debug"); SH.Slash("debug"); SH.Slash("trace"); SH.Slash("help")
end)
ok(okc, "commandes sans erreur (" .. tostring(errc) .. ")")
eq(CFG.fsRefresh, 5, "/shamrot set fsRefresh 5")
eq(CFG.totemPreset, "melee", "/shamrot totems melee")
fresh()
SH.Slash("reset")
eq(CFG.fsRefresh, 4.0, "/shamrot reset")

DONE()
