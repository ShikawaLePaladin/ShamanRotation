-- t_relic.lua : echange de reliques (mode wait uniquement)
local SH = ShamanRotation
local CFG = SH.CFG
local STORM, RAGE, CRACK = 23199, 22395, 61292

local function fresh(equipped, bag)
  SIM.setup(); SIM.load({ relics = {} })
  for k, v in pairs(SH.DEFAULTS) do CFG[k] = v end
  W.mana = 90000; W.manaMax = 90000
  W.bags = { [0] = bag or {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
  W.inv[18] = equipped
  W.equips = 0
  SH.relic = { at = -100, busyUntil = 0 }
  SH.fs = { guid = nil, at = -100 }
  SH.noMana = {}; SH.block = {}; SH.castUntil = 0
end

-- ===== mode off : aucun echange
fresh(STORM, { RAGE, CRACK })
CFG.relicMode = "off"; SH.SetRelicRule("Flame Shock", "Totem of Rage")
SIM.run(20, 0.1)
eq(W.equips, 0, "mode off : aucun echange")

-- ===== mode spell, en combat : l'echange prend l'appui, le sort part a l'appui suivant (wait)
fresh(STORM, { RAGE, CRACK })
CFG.relicMode = "spell"; SH.SetRelicRule("Flame Shock", "Totem of Rage"); SH.SetRelicRule("Chain Lightning", "Totem of the Storm")
local first = SIM.press()
eq(W.equips, 1, "Flame Shock du : Totem of Rage equipe (echange)")
eq(W.inv[18], RAGE, "... Totem of Rage en place")
eq(first, nil, "l'echange a pris l'appui : aucun sort lance cet appui")
eq(SIM.count("Flame Shock"), 0, "... Flame Shock pas encore lance")
Pump(1.6)
eq(SIM.press(), "Flame Shock", "appui suivant (apres le GCD d'echange) : Flame Shock part")
ok(SH.fs.guid ~= nil, "minuteur de Flame Shock pose APRES le vrai lancer (pas apres l'echange)")
-- Chain Lightning veut la Storm mais l'espacement (25 s) protege : pas de nouvel echange tout de suite
Pump(1.6)
SIM.press()
eq(W.equips, 1, "espacement mini : pas de 2e echange avant 25 s")
ok(SIM.count("Chain Lightning") + SIM.count("Lightning Bolt") >= 1, "... la rotation continue avec la relique en place")
-- apres 25 s : l'echange pour Chain Lightning se fait
SIM.run(25, 0.1)
ok(W.equips >= 2, "apres 25 s : echange pour Chain Lightning (" .. W.equips .. ")")

-- ===== relique absente des sacs : aucun echange, aucun blocage
fresh(STORM, {})
CFG.relicMode = "spell"; SH.SetRelicRule("Flame Shock", "Totem of Rage")
SIM.press()
eq(W.equips, 0, "relique absente : pas d'echange")
eq(SIM.count("Flame Shock"), 1, "... Flame Shock part quand meme")

-- ===== deja equipee : rien a faire
fresh(RAGE, { STORM })
CFG.relicMode = "spell"; SH.SetRelicRule("Flame Shock", "Totem of Rage")
SIM.press()
eq(W.equips, 0, "relique deja equipee : pas d'echange")
eq(SIM.count("Flame Shock"), 1, "... Flame Shock part tout de suite")

-- ===== mode main : relique posee hors combat uniquement
fresh(STORM, { CRACK })
CFG.relicMode = "main"; CFG.relicMain = "Totem of Crackling Thunder"
SIM.run(10, 0.1)
eq(W.equips, 0, "mode main : jamais d'echange pendant le combat")
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
eq(W.inv[18], CRACK, "mode main : fin de combat -> Totem of Crackling Thunder")
-- en combat : l'ouverture ne fait rien
fresh(STORM, { CRACK }); CFG.relicMode = "main"; W.combat = true
Fire("PLAYER_REGEN_ENABLED")
eq(W.equips, 0, "en combat : pas d'echange a l'ouverture")

-- ===== mode spell : a la fin du combat, la relique de Lightning Bolt
fresh(RAGE, { STORM })
CFG.relicMode = "spell"; SH.SetRelicRule("Lightning Bolt", "Totem of the Storm"); W.combat = false
Fire("PLAYER_REGEN_ENABLED")
eq(W.inv[18], STORM, "mode spell : hors combat -> relique de Lightning Bolt")
eq(W.gcdEnd <= NOW, true, "hors combat : l'echange ne coute pas de GCD")

-- ===== regle sauvegardee et rechargee
fresh(STORM, { RAGE }); SH.SetRelicRule("Earth Shock", "Totem of Rage")
local saved = ShamanRotationDB
SIM.load(saved)
eq(SH.RelicRule("Earth Shock"), "Totem of Rage", "regle de relique conservee apres rechargement")
SH.SetRelicRule("Earth Shock", nil)
eq(SH.RelicRule("Earth Shock"), nil, "regle retiree")
-- nom de relique inconnu dans la sauvegarde : ignore
ShamanRotationDB.relics = { ["Flame Shock"] = "Totem Imaginaire" }
eq(SH.RelicRule("Flame Shock"), nil, "relique inconnue : ignoree")

-- ===== commandes
local okc, errc = pcall(function() SH.Slash("relic"); SH.Slash("relic mode spell"); SH.Slash("relic mode off") end)
ok(okc, "commandes relic sans erreur (" .. tostring(errc) .. ")")
eq(CFG.relicMode, "off", "/shamrot relic mode off")

-- ===== sans API de sacs (client minimal) : aucune erreur
fresh(nil, {}); CFG.relicMode = "spell"; SH.SetRelicRule("Flame Shock", "Totem of Rage")
ok(pcall(function() SIM.run(5, 0.1) end), "aucune erreur sans relique")

DONE()
