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
  CFG.shield = "off"   -- les autres suites testent la rotation sans bouclier ; les boucliers ont leur suite plus bas
  SH.shieldTry = -10; SH.shieldTick = -10
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

-- ===== tous les totems d'un seul appui : un GCD PAR ELEMENT (serveur), donc les 4 partent dans la meme image
fresh(); CFG.totemPreset = "melee"
local t0 = NOW
ShamanRotation_TotemsAll()
eq(SIM.count("Flametongue Totem") + SIM.count("Windfury Totem") + SIM.count("Strength of Earth Totem") + SIM.count("Mana Spring Totem"), 4, "les 4 totems du combo cac partent dans le meme appui")
eq(NOW, t0, "... sans aucun delai (meme image)")
Pump(0.5); Pump(0.5)
ok(SH.totemSeq == nil, "sequence terminee apres confirmation")
local refused = 0
for i = 1, table.getn(CASTS) do if not CASTS[i].ok then refused = refused + 1 end end
eq(refused, 0, "aucun lancer refuse")
fresh(); CFG.totemPreset = "fear"
ShamanRotation_TotemsAll()
eq(SIM.count("Searing Totem") + SIM.count("Tranquil Air Totem") + SIM.count("Mana Spring Totem") + SIM.count("Tremor Totem"), 4, "combo anti-peur : 4 totems d'un coup")
-- deja en place : rien de plus
local nb = table.getn(CASTS); Pump(1.0); ShamanRotation_TotemsAll(); Pump(0.2)
eq(table.getn(CASTS), nb, "totems deja en place : aucune repose")
-- un sort normal en cours de GCD (133) retarde seulement Windfury r3 (133), pas les autres totems
fresh(); CFG.totemPreset = "melee"
SIM.press()   -- Flame Shock : GCD normal
local tt = NOW
ShamanRotation_TotemsAll()
eq(SIM.count("Flametongue Totem") + SIM.count("Strength of Earth Totem") + SIM.count("Mana Spring Totem"), 3, "GCD normal en cours : 3 totems (categories 105/106/107) partent quand meme")
eq(SIM.count("Windfury Totem"), 0, "... Windfury (GCD normal) attend")
local t1 = NOW; while NOW - t1 < 3 and SH.totemSeq do Pump(0.05) end
eq(SIM.count("Windfury Totem"), 1, "... puis Windfury part des que le GCD normal est fini")
-- un lancer refuse est retente (la marque est retiree)
fresh(); CFG.totemPreset = "caster"; W.reject = { ["Tranquil Air Totem"] = true }
ShamanRotation_TotemsAll()
local t3 = NOW; while NOW - t3 < 2 do Pump(0.05) end
eq(SIM.count("Searing Totem"), 1, "refus d'un totem : les autres sont poses")
ok(SH.totems.air == nil or SH.totems.air.at ~= t3, "... et la pose refusee n'est pas comptee")
W.reject = {}
local t4 = NOW; while NOW - t4 < 3 and SH.totemSeq do Pump(0.05) end
eq(SIM.count("Tranquil Air Totem"), 1, "refus leve : le totem est retente et pose")-- la rotation attend pendant la sequence
fresh(); CFG.totemPreset = "caster"
ShamanRotation_TotemsAll()
SIM.press()
eq(SIM.count("Flame Shock") + SIM.count("Lightning Bolt") + SIM.count("Chain Lightning"), 0, "pendant la sequence : la rotation n'envoie rien")
-- totem non appris : ignore sans bloquer
fresh({ book = { "Searing Totem", "Tranquil Air Totem", "Lightning Bolt" } }); CFG.totemPreset = "caster"
ShamanRotation_TotemsAll()
local t1 = NOW; while NOW - t1 < 8 and SH.totemSeq do Pump(0.05) end
ok(SH.totemSeq == nil and SIM.count("Searing Totem") == 1 and SIM.count("Tranquil Air Totem") == 1, "Mana Spring non appris : ignore, les autres sont poses")
-- pas assez de mana : la sequence s'arrete proprement
fresh(); CFG.totemPreset = "melee"; W.mana = 100
ShamanRotation_TotemsAll()
local t2 = NOW; while NOW - t2 < 8 and SH.totemSeq do Pump(0.05) end
ok(SH.totemSeq == nil, "mana insuffisante : la sequence s'arrete (pas de boucle)")
-- mort : la sequence s'arrete
fresh(); CFG.totemPreset = "melee"; ShamanRotation_TotemsAll(); W.dead = true; Pump(0.2); Pump(0.2)
ok(SH.totemSeq == nil, "mort : sequence annulee")
SH.Slash("totems all")
W.dead = false
CHAT = {}
SH.Slash("known Lightning Bolt"); SH.Slash("known Call of the Elements"); SH.Slash("known")
local seen = {}
for i = 1, table.getn(CHAT) do seen[i] = CHAT[i] end
ok(string.find(table.concat(seen, "|"), "Lightning Bolt : dans ton livre", 1, true) ~= nil, "/shamrot known : sort connu")
ok(string.find(table.concat(seen, "|"), "Call of the Elements : ABSENT", 1, true) ~= nil, "/shamrot known : sort absent")



-- ===== bouclier elementaire automatique
local function hasShield() for i = 1, table.getn(W.pbuffs) do local s = W.pbuffs[i].sid; if s == 51536 or s == 51526 then return s end end return nil end
local function dropAll() for i = table.getn(W.pbuffs), 1, -1 do local s = W.pbuffs[i].sid; if s == 51536 or s == 51526 then table.remove(W.pbuffs, i) end end end
fresh(); CFG.shield = "water"; W.combat = false
Pump(1.2)
eq(SIM.count("Water Shield"), 1, "hors combat : Water Shield pose tout seul")
eq(hasShield(), 51536, "... le buff est la")
Pump(6); eq(SIM.count("Water Shield"), 1, "bouclier present : pas de repose")
dropAll(); Pump(4.5)
eq(SIM.count("Water Shield"), 2, "bouclier disparu : remis tout seul")
fresh(); CFG.shield = "water"; W.combat = false; W.reject = { ["Water Shield"] = true }
Pump(10)
ok(SIM.attempts("Water Shield") <= 4, "lancer refuse : pas de rafale de tentatives (" .. SIM.attempts("Water Shield") .. ")")
fresh(); CFG.shield = "water"
eq(SIM.press(), "Water Shield", "en combat : Water Shield remis avant la rotation")
Pump(1.6); eq(SIM.press(), "Flame Shock", "... puis Flame Shock")
dropAll(); Pump(3.5)
SIM.run(6, 0.1)
ok(SIM.count("Water Shield") >= 2, "consomme en combat : remis (" .. SIM.count("Water Shield") .. ")")
fresh(); CFG.shield = "water"; CFG.shieldCombat = false
SIM.run(6, 0.1); eq(SIM.count("Water Shield"), 0, "option 'en combat' decochee : pas de bouclier en combat")
fresh(); CFG.shield = "off"; W.combat = false; Pump(8); eq(SIM.count("Water Shield") + SIM.count("Earth Shield"), 0, "bouclier coupe : rien")
fresh(); CFG.shield = "water"; CFG.shieldAuto = false; W.combat = false; Pump(8); eq(SIM.count("Water Shield"), 0, "remise auto decochee : rien hors combat")
fresh(); CFG.shield = "earth"; W.combat = false; SIM.addBuff("Interface\\Icons\\Ability_Shaman_WaterShield", 51536, 3, 600)
Pump(1.2)
eq(SIM.count("Earth Shield"), 1, "Earth Shield choisi : remplace Water Shield")
eq(hasShield(), 51526, "... Earth Shield en place")
fresh(); CFG.shield = "water"; CFG.shieldMinCharges = 3; W.combat = false; SIM.addBuff("Interface\\Icons\\Ability_Shaman_WaterShield", 51536, 2, 600)
Pump(1.2); eq(SIM.count("Water Shield"), 1, "reste 2 charges sur 3 demandees : remis")
fresh(); CFG.shield = "water"; W.combat = false; SIM.addBuff("Interface\\Icons\\INV_Drink_07", 1137, 1, 18)
Pump(8); eq(SIM.count("Water Shield"), 0, "il boit : pas de bouclier (la boisson serait interrompue)")
Pump(12); ok(SIM.count("Water Shield") == 1, "apres la boisson : bouclier remis")
fresh(); CFG.shield = "water"; W.combat = false; SIM.addBuff("Interface\\Icons\\Ability_Mount_RidingHorse", 458, 1, 3600)
Pump(6); eq(SIM.count("Water Shield"), 0, "monte : pas de bouclier")
fresh({ book = { "Lightning Bolt", "Chain Lightning", "Flame Shock" } }); CFG.shield = "water"; W.combat = false
Pump(6); eq(SIM.count("Water Shield"), 0, "Water Shield non appris : rien, aucune erreur")
fresh(); CFG.shield = "water"; W.combat = false; W.dead = true; Pump(6); eq(SIM.count("Water Shield"), 0, "mort : rien"); W.dead = false
fresh(); SH.Slash("set shield earth"); eq(CFG.shield, "earth", "/shamrot set shield earth")
SH.Slash("set shield water")



-- ===== totems trop loin / detruits : repose automatique (UnitXP + plaques de nom)
local function tplates(d1, d2, d3, names)
  PLATES = {
    { guid = "0xSOE", name = "Strength of Earth Totem V", dist = d1, hostile = false, combat = false },
    { guid = "0xMS", name = "Mana Spring Totem IV", dist = d2, hostile = false, combat = false },
    { guid = "0xFT", name = "Flametongue Totem IV", dist = d3, hostile = false, combat = false },
  }
end
local function setupTotems()
  fresh(); CFG.totemPreset = "melee"; W.combat = false
  tplates(1, 1, 1)
  ShamanRotation_TotemsAll()
  Pump(1.0)
end
setupTotems()
ok(SH.totemGuid.earth ~= nil and SH.totemGuid.water ~= nil and SH.totemGuid.fire ~= nil, "mes totems sont reperes sur les plaques (GUID, a moins de 8 m)")
ok(SH.totemGuid.air == nil, "Windfury (rayon non verifie) : non surveille")
local n0 = SIM.count("Strength of Earth Totem")
Pump(2); eq(SIM.count("Strength of Earth Totem"), n0, "a portee : aucune repose")
-- je m'eloigne de mon totem de Terre (40 m)
PLATES[1].dist = 40
Pump(1.5)
eq(SIM.count("Strength of Earth Totem"), n0 + 1, "totem a 40 m : repose automatique (hors combat)")
eq(SIM.count("Mana Spring Totem"), 1, "... les totems a portee ne sont pas reposes")
-- le nouveau totem apparait pres de moi ; l'ancien reste la-bas
PLATES[1].dist = 40; table.insert(PLATES, { guid = "0xSOE2", name = "Strength of Earth Totem V", dist = 1, hostile = false, combat = false })
Pump(2)
ok(SH.totemGuid.earth and SH.totemGuid.earth.guid == "0xSOE2", "le nouveau totem est repere (pas l'ancien, a 40 m)")
Pump(4); eq(SIM.count("Strength of Earth Totem"), n0 + 1, "pas de nouvelle repose en boucle")
-- totem detruit
setupTotems()
PLATES[2].gone = true
Pump(1.5)
eq(SIM.count("Mana Spring Totem"), 2, "totem detruit : repose automatique")
-- en combat : pas de repose (option), avec l'option oui
setupTotems(); W.combat = true; PLATES[1].dist = 40; Pump(2)
eq(SIM.count("Strength of Earth Totem"), 1, "en combat : pas de repose automatique (option decochee)")
setupTotems(); W.combat = true; CFG.totemRedropCombat = true; PLATES[1].dist = 40; Pump(2)
eq(SIM.count("Strength of Earth Totem"), 2, "en combat avec l'option : repose")
-- option coupee
setupTotems(); CFG.totemRedrop = false; PLATES[1].dist = 40; Pump(2)
eq(SIM.count("Strength of Earth Totem"), 1, "repose automatique coupee : rien")
-- distance reglable
setupTotems(); CFG.totemRange = 50; PLATES[1].dist = 40; Pump(2)
eq(SIM.count("Strength of Earth Totem"), 1, "totemRange 50 m : 40 m reste a portee")
-- sans plaques amicales (totems introuvables) : aucun comportement hasardeux
fresh(); CFG.totemPreset = "melee"; W.combat = false; PLATES = {}
ShamanRotation_TotemsAll(); Pump(8)
ok(next(SH.totemGuid) == nil, "pas de plaques : aucun totem repere")
eq(SIM.count("Strength of Earth Totem"), 1, "... et aucune repose (le minuteur decide)")
-- sans UnitXP
fresh(); CFG.totemPreset = "melee"; W.combat = false; W.noXP = true; tplates(1, 1, 1)
ShamanRotation_TotemsAll()
ok(pcall(function() Pump(4) end), "sans UnitXP : aucune erreur")
eq(SIM.count("Strength of Earth Totem"), 1, "... et aucune repose")
-- mort : on ne repose pas
setupTotems(); W.dead = true; PLATES[1].dist = 40; Pump(2)
eq(SIM.count("Strength of Earth Totem"), 1, "mort : pas de repose"); W.dead = false



-- ===== Chain Lightning : auto (economise la mana) / toujours / jamais
local function clRun(mode, mana, secs)
  fresh(); CFG.clMode = mode; W.manaMax = 90000; W.mana = 90000 * mana
  SIM.run(secs or 20, 0.1)
  return SIM.count("Chain Lightning")
end
ok(clRun("on", 0.30) >= 1, "mode toujours : Chain Lightning meme a 30 % de mana")
eq(clRun("off", 1.0), 0, "mode jamais : aucun Chain Lightning")
ok(clRun("auto", 0.90) >= 2, "auto, mana 90 % : Chain Lightning utilise")
eq(clRun("auto", 0.40), 0, "auto, une cible, mana 40 % : Lightning Bolt seulement (mana economisee)")
ok(SIM.count("Lightning Bolt") >= 3, "... la rotation continue en Lightning Bolt")
-- plusieurs ennemis proches : Chain Lightning rentable meme a mana moyenne
fresh(); CFG.clMode = "auto"; W.manaMax = 90000; W.mana = 36000; PLATES = { { guid = "0xA", dist = 0 }, { guid = "0xB", dist = 5 } }
SIM.run(20, 0.1)
ok(SIM.count("Chain Lightning") >= 1, "auto, 2 ennemis proches, mana 40 % : Chain Lightning (il saute)")
fresh(); CFG.clMode = "auto"; CFG.clMinTargets = 3; W.manaMax = 90000; W.mana = 36000; PLATES = { { guid = "0xA", dist = 0 }, { guid = "0xB", dist = 5 } }
SIM.run(20, 0.1)
eq(SIM.count("Chain Lightning"), 0, "clMinTargets 3 : 2 ennemis ne suffisent pas")
-- AoE active : Chain Lightning
fresh(); CFG.clMode = "auto"; CFG.aoeMode = "on"; W.manaMax = 90000; W.mana = 36000
SIM.run(20, 0.1); ok(SIM.count("Chain Lightning") >= 1, "auto + AoE : Chain Lightning meme a mana basse")
-- Clearcasting / Elemental Mastery
fresh(); CFG.clMode = "auto"; W.manaMax = 90000; W.mana = 36000; SIM.addBuff("Interface\\Icons\\Spell_Nature_Lightning", 45542, 1, 30)
SIM.run(6, 0.1); ok(SIM.count("Chain Lightning") >= 1, "auto + Clearcasting : Chain Lightning")
fresh(); CFG.clMode = "auto"; W.manaMax = 90000; W.mana = 36000; SIM.addBuff("Interface\\Icons\\Spell_Nature_WispHeal", 16166, 1, 15)
SIM.run(6, 0.1); ok(SIM.count("Chain Lightning") >= 1, "auto + Elemental Mastery : Chain Lightning")
-- seuil reglable
fresh(); CFG.clMode = "auto"; CFG.clMonoMana = 0.30; W.manaMax = 90000; W.mana = 45000
SIM.run(10, 0.1); ok(SIM.count("Chain Lightning") >= 1, "seuil 30 % : Chain Lightning a 50 %")
-- sous manaCl : jamais, quel que soit le mode
fresh(); CFG.clMode = "on"; W.manaMax = 90000; W.mana = 9000
SIM.run(10, 0.1); eq(SIM.count("Chain Lightning"), 0, "mode toujours mais mana sous le minimum : pas de Chain Lightning")
-- case maitre
fresh(); CFG.clMode = "on"; CFG.useCl = false; SIM.run(10, 0.1); eq(SIM.count("Chain Lightning"), 0, "case maitre decochee : jamais")
-- bascule
fresh(); eq(CFG.clMode, "auto", "defaut : auto")
ShamanRotation_ClToggle(); eq(CFG.clMode, "on", "bascule -> toujours")
ShamanRotation_ClToggle(); eq(CFG.clMode, "off", "bascule -> jamais")
ShamanRotation_ClToggle(); eq(CFG.clMode, "auto", "bascule -> auto")
SH.Slash("cl off"); eq(CFG.clMode, "off", "/shamrot cl off")
SH.Slash("cl"); eq(CFG.clMode, "auto", "/shamrot cl : bascule")

DONE()