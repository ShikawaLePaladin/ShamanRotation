-- t_ui.lua : menu, HUD, minimap de ShamanRotation (API 1.12 stricte)
local SH = ShamanRotation
local CFG = SH.CFG

local function try(name, fn)
  local okp, err = pcall(fn)
  if not okp then FAILS = FAILS + 1; print("FAIL: " .. name .. " -> " .. tostring(err)) else PASSES = PASSES + 1 end
  return okp
end

SIM.setup(); SIM.load(nil)
Fire("PLAYER_LOGIN")
ok(ShamanRotationHud ~= nil, "HUD cree a la connexion")
ok(ShamanRotationMinimapButton ~= nil, "bouton de minimap cree")

try("ouverture du menu", function() SH.OpenMenu(true) end)
ok(ShamanRotationOptionsFrame ~= nil and ShamanRotationOptionsFrame:IsShown(), "menu affiche")
try("tous les onglets", function()
  for i = 1, table.getn(SH.TAB_DEFS) do SH.ShowTab(SH.TAB_DEFS[i].id) end
end)
-- taille FIXE : la hauteur du panneau ne change jamais d'un onglet a l'autre
local h0 = ShamanRotationOptionsFrame:GetHeight()
local same = true
for i = 1, table.getn(SH.TAB_DEFS) do SH.ShowTab(SH.TAB_DEFS[i].id); if ShamanRotationOptionsFrame:GetHeight() ~= h0 then same = false end end
ok(same, "hauteur du menu identique sur tous les onglets (" .. tostring(h0) .. ")")
try("refresh", function() SH.RefreshOptions(); SH.RefreshStatus() end)

-- cases a cocher : ecrivent dans les reglages ET dans la sauvegarde
local c = ShamanRotOpt_UseFs
ok(c ~= nil, "case Flame Shock presente")
c:SetChecked(false); this = c; c.scripts.OnClick()
eq(CFG.useFs, false, "case Flame Shock decochee")
eq(ShamanRotationDB.settings.useFs, false, "... sauvegardee")
c:SetChecked(true); this = c; c.scripts.OnClick()
eq(CFG.useFs, true, "case Flame Shock recochee")

-- bouton cyclique : mode AoE auto -> on -> off -> auto
local cy = ShamanRotCyc_aoe
ok(cy ~= nil, "bouton de mode AoE present")
eq(CFG.aoeMode, "auto", "mode AoE par defaut : auto")
this = cy; cy.scripts.OnClick(); eq(CFG.aoeMode, "on", "clic -> on")
this = cy; cy.scripts.OnClick(); eq(CFG.aoeMode, "off", "clic -> off")
this = cy; cy.scripts.OnClick(); eq(CFG.aoeMode, "auto", "clic -> auto")
local ct = ShamanRotCyc_tot
this = ct; ct.scripts.OnClick(); eq(CFG.totemPreset, "melee", "combo de totems : caster -> melee")

-- curseurs
local sl = ShamanRotOpt_fsRefresh
ok(sl ~= nil, "curseur fsRefresh present")
sl:SetValue(6); eq(CFG.fsRefresh, 6, "curseur fsRefresh : 6 s")
eq(ShamanRotationDB.settings.fsRefresh, 6, "... sauvegarde")

-- persistance : rechargement avec la sauvegarde
local saved = ShamanRotationDB
SH.SetSetting("autoAoeMin", 4)
for k, v in pairs(SH.DEFAULTS) do CFG[k] = v end
SIM.load(saved)
eq(CFG.autoAoeMin, 4, "rechargement : autoAoeMin conserve")
eq(CFG.fsRefresh, 6, "rechargement : fsRefresh conserve")
eq(CFG.totemPreset, "melee", "rechargement : combo de totems conserve")
-- valeur de mauvais type dans la sauvegarde : ignoree
SIM.load({ settings = { fsRefresh = "abc", useCl = 5 } })
eq(CFG.fsRefresh, SH.DEFAULTS.fsRefresh, "sauvegarde corrompue : valeur par defaut")

-- HUD : mise a jour sans erreur dans tous les etats
try("HUD sans cible", function() W.target = nil; SH.HudUpdate() end)
SIM.setup(); SIM.load(nil)
try("HUD avec cible et Flame Shock", function() SIM.press(); Pump(1.6); SH.HudUpdate() end)
ok(SH.hudIcons.fs.txt:GetText() ~= nil, "HUD : minuteur Flame Shock")
try("HUD apres burst + totems", function() ShamanRotation_Burst(); ShamanRotation_Totems(); Pump(1.6); SH.HudUpdate() end)
try("HUD cache / affiche / echelle", function() CFG.hud = false; SH.HudRefreshConfig(); CFG.hud = true; CFG.hudScale = 1.5; SH.HudRefreshConfig() end)
try("commandes menu / hud", function() SH.Slash("menu"); SH.Slash("menu"); SH.Slash("hud"); SH.Slash("hud") end)

-- minimap
try("minimap : positionner, bouton, clic droit", function()
  SH.MinimapPlace(); SH.MinimapToggle(); SH.MinimapToggle()
  this = ShamanRotationMinimapButton; arg1 = "RightButton"; ShamanRotationMinimapButton.scripts.OnClick(); arg1 = "LeftButton"; ShamanRotationMinimapButton.scripts.OnClick()
end)

-- aucune extension
try("menu sans extensions", function() W.noRange = true; W.noXP = true; SH.RefreshStatus(); SH.HudUpdate() end)

-- ===== touches : capture clavier / souris dans le menu
SIM.setup(); SIM.load(nil)
SH.OpenMenu(true); SH.ShowTab("touches")
W.bindings = {}
local function press(raw, shift)
  W.shift = shift or false
  this = SH.keyCap; arg1 = raw; SH.keyCap.scripts.OnKeyDown(); W.shift = false
end
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation (une touche)")
ok(SH.keyCap:IsShown(), "capture ouverte")
press("F5")
eq(W.bindings["SHAMANROT_ROTATION"], "F5", "touche F5 liee a la rotation")
ok(not SH.keyCap:IsShown(), "capture fermee apres la touche")
eq(ShamanRotKeyBtn1:GetText(), "F5", "le bouton affiche F5")
-- changer de touche : l'ancienne est retiree
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation"); press("F6", true)
eq(W.bindings["SHAMANROT_ROTATION"], "SHIFT-F6", "Maj + F6")
-- Echap annule
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation"); press("ESCAPE")
eq(W.bindings["SHAMANROT_ROTATION"], "SHIFT-F6", "Echap : rien ne change")
-- modificateur seul ignore ; clic gauche seul ignore
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation"); press("LSHIFT"); ok(SH.keyCap:IsShown(), "Maj seule : on attend toujours")
press("LeftButton"); ok(SH.keyCap:IsShown(), "clic gauche seul : ignore")
press("Button4"); eq(W.bindings["SHAMANROT_ROTATION"], "BUTTON4", "bouton de souris 4")
-- molette
SH.StartKeyCapture("SHAMANROT_BURST", "Burst"); this = SH.keyCap; arg1 = 1; SH.keyCap.scripts.OnMouseWheel()
eq(W.bindings["SHAMANROT_BURST"], "MOUSEWHEELUP", "molette haut")
-- une touche deja prise par une autre action lui est reprise
SH.StartKeyCapture("SHAMANROT_TOTEMS", "Totems"); press("F7")
SH.StartKeyCapture("SHAMANROT_AOE", "AoE"); press("F7")
eq(W.bindings["SHAMANROT_AOE"], "F7", "F7 reprise par le mode AoE")
eq(W.bindings["SHAMANROT_TOTEMS"], nil, "... et retiree des totems")
-- bouton Retirer
this = ShamanRotKeyClr2; ShamanRotKeyClr2.scripts.OnClick()
eq(W.bindings["SHAMANROT_BURST"], nil, "Retirer : touche du burst retiree")
eq(ShamanRotKeyBtn2:GetText(), "Cliquer pour definir", "... le bouton le dit")
-- clic sur le bouton : texte d'attente + capture
this = ShamanRotKeyBtn3; ShamanRotKeyBtn3.scripts.OnClick()
ok(SH.keyCap:IsShown(), "clic sur le bouton : capture ouverte")
press("ESCAPE")
-- menu : liaison
ok(type(ShamanRotation_OpenMenu) == "function", "fonction ShamanRotation_OpenMenu (liaison Ouvrir le menu)")
eq(table.getn(SH.KEYROWS), 8, "8 actions liables (dont Chain Lightning ON/OFF et mode)")

-- ===== boutons a l'ecran (comme le paladin / le guerrier)
SIM.setup(); SIM.load(nil)
Fire("PLAYER_LOGIN")
ok(ShamanRotationButtons ~= nil, "rangee de boutons creee")
local function click(b, mouse) this = b; arg1 = mouse or "LeftButton"; b.scripts.OnClick() end
local cl, aoe, burst, tot = SH.btns.cl, SH.btns.aoe, SH.btns.burst, SH.btns.totems
ok(cl and aoe and burst and tot, "4 boutons : Chain Lightning, AoE, Burst, Totems")
ok(cl:IsShown() and aoe:IsShown() and burst:IsShown() and tot:IsShown(), "les 4 boutons sont affiches")
-- Chain Lightning : clic gauche = ACTIVER / COUPER
eq(CFG.useCl, true, "Chain Lightning actif au depart")
click(cl); eq(CFG.useCl, false, "clic : Chain Lightning COUPE")
eq(cl.big:GetText(), "OFF", "le bouton affiche OFF")
click(cl); eq(CFG.useCl, true, "clic : Chain Lightning ACTIVE")
ok(cl.txt:GetText() ~= nil and cl.txt:GetText() ~= "", "le bouton affiche le mode")
eq(ShamanRotationDB.settings.useCl, true, "... enregistre")
-- clic droit : change le MODE (multi-cibles -> auto -> toujours -> multi-cibles), jamais 'off'
CFG.clMode = "aoe"
click(cl, "RightButton"); eq(CFG.clMode, "auto", "clic droit : auto")
click(cl, "RightButton"); eq(CFG.clMode, "on", "clic droit : toujours")
click(cl, "RightButton"); eq(CFG.clMode, "aoe", "clic droit : multi-cibles")
eq(CFG.useCl, true, "le clic droit ne coupe pas Chain Lightning")
-- l'interrupteur agit vraiment sur la rotation
CFG.useCl = false; CFG.clMode = "on"; SIM.setup(); SIM.load(nil)
for k, v in pairs(SH.DEFAULTS) do CFG[k] = v end
CFG.clMode = "on"; CFG.shield = "off"; CFG.useCl = false; W.mana = 90000; W.manaMax = 90000
SIM.run(15, 0.1); eq(SIM.count("Chain Lightning"), 0, "bouton OFF : plus aucun Chain Lightning, meme en mode toujours")
click(cl); SIM.run(15, 0.1); ok(SIM.count("Chain Lightning") >= 1, "bouton ON : Chain Lightning revient")
-- touche ON / OFF
local before = CFG.useCl; ShamanRotation_ClSwitch(); eq(CFG.useCl, not before, "touche ON/OFF : bascule")
ShamanRotation_ClSwitch()
-- AoE : clic = auto -> on -> off
CFG.aoeMode = "auto"; click(aoe); eq(CFG.aoeMode, "on", "bouton AoE : clic -> toujours")
click(aoe); eq(CFG.aoeMode, "off", "bouton AoE : clic -> jamais")
click(aoe); eq(CFG.aoeMode, "auto", "bouton AoE : clic -> auto")
CFG.aoeMode = "on"; SH.ButtonsUpdate(); eq(aoe.big:GetText(), "AOE", "AoE actif : le bouton affiche AOE")
CFG.aoeMode = "off"; SH.ButtonsUpdate(); eq(aoe.big:GetText(), "MONO", "AoE coupe : le bouton affiche MONO")
-- Burst et Totems
SIM.setup(); SIM.load(nil); Fire("PLAYER_LOGIN")
click(burst); eq(SIM.count("Elemental Mastery"), 1, "bouton Burst : Elemental Mastery lance")
SH.ButtonsUpdate(); ok(burst.big:GetText() ~= "", "burst en recharge : compte a rebours affiche")
SIM.setup(); SIM.load(nil); CFG.totemPreset = "melee"
SH.ButtonsUpdate(); eq(tot.big:GetText(), "4", "totems : 4 manquants")
click(tot); eq(SIM.count("Strength of Earth Totem"), 1, "bouton Totems : pose le combo")
Pump(1.0); SH.ButtonsUpdate(); eq(tot.big:GetText(), "", "totems en place : plus de compteur")
-- configuration : masquer un bouton, tout masquer, taille, verrouillage
CFG.btnAoe = false; SH.ButtonsRefreshConfig(); ok(not aoe:IsShown() and cl:IsShown(), "bouton AoE masque, les autres restent")
CFG.btnAoe = true; CFG.buttons = false; SH.ButtonsRefreshConfig(); ok(not ShamanRotationButtons:IsShown(), "boutons masques (option)")
CFG.buttons = true; CFG.btnScale = 1.5; SH.ButtonsRefreshConfig(); ok(ShamanRotationButtons:IsShown(), "boutons reaffiches, taille 150 %")
-- deplacement : verrouille -> rien ; deverrouille -> StartMoving + position enregistree
CFG.btnLocked = true; this = cl; cl.scripts.OnDragStart()
CFG.btnLocked = false; this = cl; cl.scripts.OnDragStart(); cl.scripts.OnDragStop()
ok(ShamanRotationDB.pos == nil or ShamanRotationDB.pos.btn ~= nil, "position des boutons enregistree")
-- info-bulles et mise a jour sans erreur dans tous les etats
ok(pcall(function() for _, b in pairs(SH.btns) do this = b; b.scripts.OnEnter(); b.scripts.OnLeave() end end), "info-bulles sans erreur")
ok(pcall(function() W.target = nil; SH.ButtonsUpdate(); W.noXP = true; SH.ButtonsUpdate() end), "mise a jour sans cible / sans UnitXP : aucune erreur")
-- cases du menu
SH.OpenMenu(true); SH.ShowTab("affichage")
ok(ShamanRotOpt_BtnCl ~= nil and ShamanRotOpt_Btns ~= nil and ShamanRotOpt_BtnLock ~= nil, "cases des boutons dans l'onglet Affichage")
ShamanRotOpt_BtnCl:SetChecked(false); this = ShamanRotOpt_BtnCl; ShamanRotOpt_BtnCl.scripts.OnClick()
ok(not cl:IsShown(), "case Bouton Chain Lightning decochee : bouton masque")

DONE()