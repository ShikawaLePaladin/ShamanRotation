---------------------------------------------------------------
-- ShamanRotation_UI.lua : menu a onglets (taille FIXE, defilement par onglet), aide au survol, HUD (GCD, recharges, DoT, totems), bouton de minimap
-- Meme ergonomie que ShikiwaRotation. Lua 5.0 strict : tout dans la table SH.
---------------------------------------------------------------
local SH = ShamanRotation

SH.HELP = {
	aoeMode = "Mode AoE. AUTO : bascule tout seul selon le nombre d'ennemis a moins de 10 m de la cible (plaques de nom + UnitXP). ON : toujours AoE. OFF : jamais. Clique pour changer.",
	autoAoeMin = "Nombre d'ennemis (cible comprise) a partir duquel l'AoE s'active en mode AUTO.",
	autoDelay = "Delai avant de repasser en mono quand il reste moins d'ennemis (anti-yoyo).",
	aoeRadius = "Rayon de comptage autour de la CIBLE (m). Earthquake touche la cible et les ennemis a 10 m autour d'elle (Spell.dbc).",
	fsRefresh = "Flame Shock est relance quand il reste moins de ce temps sur le DoT (15 s). Les meilleurs joueurs le relancent toutes les ~10,7 s, soit vers 4 s restantes.",
	useFs = "Entretient Flame Shock sur la cible (sauf si la cible y est immunisee).",
	useCl = "Chain Lightning autorise (case maitre). Le MODE (auto / toujours / jamais) se choisit plus bas ou avec la touche dediee.",
	clMode = "AUTO : economise la mana. Chain Lightning coute 605 mana contre 210 pour Lightning Bolt : sur UNE cible il rapporte ~3 fois moins de degats par mana ; a 3 cibles il est a egalite et fait bien plus de DPS. En auto il part a plusieurs cibles, sous Clearcasting, sous Elemental Mastery, ou tant que ta mana est au-dessus du seuil. TOUJOURS : a chaque retour de recharge (6 s). JAMAIS : coupe.",
	clMonoMana = "Mode AUTO, une seule cible : Chain Lightning seulement s'il te reste au moins ce pourcentage de ta mana MAX apres l'avoir lance (son cout reel est appris sur tes lancers). Plus ta reserve de mana est petite, plus ce sort pese lourd.",
	manaSaver = "Les sorts chers (Flame Shock, Chain Lightning, Earthquake) ne partent que s'il reste une reserve de mana APRES le lancer. Le cout reel de chaque sort est appris sur tes propres lancers (mediane des 5 derniers). Decoche pour l'ancien comportement.",
	fsMana = "Flame Shock (410 mana, ~4 fois moins de degats par mana que Lightning Bolt) : lance seulement s'il reste cette fraction de ta mana max apres.",
	eqMana = "Earthquake en AoE : lance seulement s'il reste cette fraction de ta mana max apres.",
	clMinTargets = "Mode AUTO : nombre d'ennemis (cible comprise) a moins de la distance de saut a partir duquel Chain Lightning devient rentable.",
	useEq = "Earthquake en AoE (recharge 16 s, 2,5 s d'incantation, degats de zone autour de la cible).",
	useMb = "DEDUIT, desactive par defaut : Molten Blast rafraichit Flame Shock (210 mana, 2 s) quand les chocs sont en recharge et que le DoT va expirer.",
	interrupt = "Earth Shock pour interrompre l'incantation de la cible (2 s). Demande SuperWoW pour voir les incantations ennemies.",
	esFill = "Earth Shock de remplissage. Desactive par defaut : les meilleurs joueurs n'en lancent que ~2 par minute (5 % des degats).",
	esFillMana = "Earth Shock de remplissage seulement au-dessus de cette mana.",
	manaCl = "Sous cette mana : plus de Flame Shock / Chain Lightning / Earthquake, seulement Lightning Bolt.",
	autoTarget = "Cible l'ennemi le plus proche quand tu n'as pas de cible.",
	totemPreset = "Combo de totems pour le bouton Totems : CASTER (Searing, Tranquil Air, Mana Spring), MELEE (Flametongue, Windfury, Strength of Earth, Mana Spring), AOE (Magma), NOVA (Fire Nova), FEAR (+ Tremor), POISON / DISEASE (purification). Clique pour changer.",
	totemsInCombat = "La rotation pose et entretient le totem de FEU (Searing, ou Magma en AoE) en combat. Son GCD est celui du FEU (categorie 105 du serveur), pas celui des sorts : la rotation ne perd aucun appui. Les autres totems : bouton Totems.",
	burstEm = "Le burst utilise Elemental Mastery (recharge 3 min, +% degats Feu/Givre/Nature et sorts moins chers).",
	burstBf = "Le burst utilise Blood Fury (racial orc).",
	burstTrinkets = "Le burst utilise aussi tes deux bijoux (s'ils sont a utiliser). Desactive : pas assez de toucher selon ton ami.",
	quiet = "Masque les messages automatiques.",
	debug = "Affiche les decisions dans le chat (diagnostic).",
	relicMode = "Echange de reliques. COUPE : rien. UNE RELIQUE : la relique choisie est posee HORS combat. PAR SORT : la relique du sort a lancer est equipee en combat (un echange = un GCD de 1,5 s, le sort part a l'appui suivant), au plus un echange toutes les N secondes.",
	relicMain = "Relique posee hors combat en mode UNE RELIQUE (Totem of Crackling Thunder : 10 % de chances de +8 % vitesse d'incantation sur Lightning Bolt).",
	relicGap = "Mode PAR SORT : delai minimal entre deux echanges en combat (chaque echange coute 1,5 s de GCD).",
	shield = "Bouclier elementaire remis automatiquement. WATER SHIELD : 0 mana, chaque attaque qui te touche rend 130 mana (3 charges). EARTH SHIELD : 300 mana, 150 PV par attaque et 30 % de chances de ne pas etre interrompu. Un seul a la fois : le choisi remplace l'autre.",
	shieldAuto = "Hors combat : remet le bouclier des qu'il disparait (pas pendant que tu bois ou manges, detecte a l'icone du buff).",
	shieldCombat = "En combat : remet le bouclier quand ses 3 charges sont consommees. Ca coute un GCD de 1,5 s (Water Shield : 0 mana).",
	totemRedrop = "Repose tout seul un totem de buff quand tu t'en eloignes (rayon des auras : 30 m) ou quand il est detruit. Le totem est repere juste apres sa pose grace aux plaques de nom AMICALES et a UnitXP ; sans eux, seul le minuteur decide. Surveilles : Mana Spring, Healing Stream, Strength of Earth, Grace of Air, Tranquil Air, Stoneskin, Flametongue.",
	totemRedropCombat = "Autorise la repose automatique pendant le combat (sinon seulement hors combat). Coute de la mana ; les totems ne prennent pas le GCD des sorts.",
	totemRange = "Distance a partir de laquelle le totem est considere trop loin. Le rayon reel des auras est de 30 m (Spell.dbc) : 27 m laisse une marge de 3 m.",
	hud = "Affiche l'indicateur : GCD, recharges, minuteur de Flame Shock, totems.",
	hudLocked = "Verrouille la position de l'indicateur (decoche pour le deplacer a la souris).",
	hudScale = "Taille de l'indicateur.",
}

function SH.ShowHelp(w)
	local key = w.helpKey
	if not key or not GameTooltip then return end
	GameTooltip:SetOwner(w, "ANCHOR_RIGHT")
	GameTooltip:SetText(w.helpLabel or key, 0, 0.7, 1)
	local h = SH.HELP[key]
	if h then GameTooltip:AddLine(h, 1, 1, 1, 1) end
	local d = SH.DEFAULTS[key]
	if d ~= nil then
		GameTooltip:AddLine("Valeur par defaut : " .. tostring(d) .. "   actuel : " .. tostring(SH.CFG[key]), 0.6, 0.9, 0.6)
	end
	GameTooltip:Show()
end
function SH.AttachHelp(w, key, label)
	w.helpKey = key
	w.helpLabel = label
	w:SetScript("OnEnter", function() SH.ShowHelp(this) end)
	w:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- ===================================================================
-- Widgets
-- ===================================================================
SH.checks = {}
SH.sliders = {}
SH.cycles = {}

function SH.AddCheck(name, cont, prev, dy, label, key)
	local c = CreateFrame("CheckButton", "ShamanRotOpt_" .. name, cont, "UICheckButtonTemplate")
	if prev == cont then
		c:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, dy)
	else
		c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, dy)
	end
	getglobal(c:GetName() .. "Text"):SetText(label)
	c.key = key
	c:SetChecked(SH.CFG[key])
	c:SetScript("OnClick", function()
		SH.SetSetting(this.key, this:GetChecked() and true or false)
		if SH.HudRefreshConfig then SH.HudRefreshConfig() end
	end)
	SH.AttachHelp(c, key, label)
	table.insert(SH.checks, c)
	return c
end

function SH.AddSlider(cont, prev, dy, key, label, minV, maxV, step, suffix, pct)
	local s = CreateFrame("Slider", "ShamanRotOpt_" .. key, cont, "OptionsSliderTemplate")
	s:SetWidth(240)
	s:SetHeight(16)
	if prev == cont then
		s:SetPoint("TOPLEFT", cont, "TOPLEFT", 4, dy)
	else
		s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 4, dy)
	end
	s:SetOrientation("HORIZONTAL")
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	getglobal(s:GetName() .. "Low"):SetText(tostring(minV))
	getglobal(s:GetName() .. "High"):SetText(tostring(maxV))
	s.key = key
	s.label = label
	s.suffix = suffix or ""
	s.step = step
	s.pct = pct
	s.getVal = function() if pct then return math.floor(SH.CFG[key] * 100 + 0.5) end return SH.CFG[key] end
	s:SetScript("OnValueChanged", function()
		local st = this.step
		local v = math.floor(this:GetValue() / st + 0.5) * st
		if st < 1 then v = math.floor(v * 100 + 0.5) / 100 end
		if not SH.refreshing then
			if this.pct then SH.SetSetting(this.key, v / 100) else SH.SetSetting(this.key, v) end
			if SH.HudRefreshConfig then SH.HudRefreshConfig() end
		end
		getglobal(this:GetName() .. "Text"):SetText(this.label .. " : " .. tostring(v) .. this.suffix)
	end)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function() this:SetValue(this:GetValue() + (arg1 or 0) * this.step) end)
	SH.refreshing = true
	s:SetValue(s.getVal())
	SH.refreshing = false
	SH.AttachHelp(s, key, label)
	table.insert(SH.sliders, s)
	return s
end

-- bouton qui fait defiler une liste de valeurs
function SH.AddCycle(name, cont, prev, dy, key, label, list, shown)
	local b = CreateFrame("Button", "ShamanRotCyc_" .. name, cont, "UIPanelButtonTemplate")
	b:SetWidth(300)
	b:SetHeight(22)
	if prev == cont then
		b:SetPoint("TOPLEFT", cont, "TOPLEFT", 4, dy)
	else
		b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 4, dy)
	end
	b.key = key
	b.label = label
	b.list = list
	b.shown = shown or {}
	b.Refresh = function(self)
		local v = SH.CFG[self.key]
		self:SetText(self.label .. " : " .. tostring(self.shown[v] or v))
	end
	b:SetScript("OnClick", function()
		local cur, i, nxt = SH.CFG[this.key], 0, 1
		for i = 1, table.getn(this.list) do
			if this.list[i] == cur then nxt = i + 1 end
		end
		if nxt > table.getn(this.list) then nxt = 1 end
		SH.SetSetting(this.key, this.list[nxt])
		if this.key == "aoeMode" then SH.autoAoe = false end
		this:Refresh()
	end)
	b:Refresh()
	SH.AttachHelp(b, key, label)
	table.insert(SH.cycles, b)
	return b
end

function SH.AddHeader(cont, prev, dy, text)
	local h = cont:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	if prev == cont then
		h:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, dy)
	else
		h:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, dy)
	end
	h:SetText("|cff0070de" .. text .. "|r")
	local line = cont:CreateTexture(nil, "ARTWORK")
	line:SetTexture("Interface\\Buttons\\WHITE8x8")
	line:SetHeight(1)
	line:SetWidth(560)
	line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)
	line:SetVertexColor(0, 0.44, 0.87, 0.4)
	return line
end

function SH.AddText(cont, prev, dy, text)
	local t = cont:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	t:SetWidth(560)
	t:SetJustifyH("LEFT")
	if prev == cont then
		t:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, dy)
	else
		t:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, dy)
	end
	t:SetText(text)
	return t
end

function SH.AddButton(name, cont, prev, dy, label, onClick, width)
	local b = CreateFrame("Button", "ShamanRotBtn_" .. name, cont, "UIPanelButtonTemplate")
	b:SetWidth(width or 200)
	b:SetHeight(22)
	if prev == cont then
		b:SetPoint("TOPLEFT", cont, "TOPLEFT", 4, dy)
	else
		b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 4, dy)
	end
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

-- ===================================================================
-- Onglets
-- ===================================================================
-- ---------- Touches : clic sur un bouton, puis appuie sur la touche (clavier ET souris) ----------
SH.KEYROWS = {
	{ "SHAMANROT_ROTATION", "Rotation (une touche)" },
	{ "SHAMANROT_BURST", "Burst" },
	{ "SHAMANROT_TOTEMS", "Totem suivant du combo" },
	{ "SHAMANROT_TOTEMS4", "Poser tous les totems" },
	{ "SHAMANROT_CL", "Chain Lightning (bascule)" },
	{ "SHAMANROT_AOE", "Mode AoE (bascule)" },
	{ "SHAMANROT_MENU", "Ouvrir ce menu" },
}
SH.keyBtns = {}

function SH.RefreshKeyButtons()
	local i
	for i = 1, table.getn(SH.keyBtns) do
		local b = SH.keyBtns[i]
		local k1, k2 = GetBindingKey(b.bind)
		b:SetText(k1 and (k2 and (k1 .. " / " .. k2) or k1) or "Cliquer pour definir")
	end
end

function SH.CaptureInput(raw)
	local cf = SH.keyCap
	if raw == "ESCAPE" then
		cf:Hide()
		SH.RefreshKeyButtons()
		return
	end
	if raw == "UNKNOWN" or raw == "LSHIFT" or raw == "RSHIFT" or raw == "LCTRL" or raw == "RCTRL" or raw == "LALT" or raw == "RALT" then
		return
	end
	local mods, hasMod = "", false
	if IsAltKeyDown() then mods = mods .. "ALT-"; hasMod = true end
	if IsControlKeyDown() then mods = mods .. "CTRL-"; hasMod = true end
	if IsShiftKeyDown() then mods = mods .. "SHIFT-"; hasMod = true end
	local key = raw
	if raw == "LeftButton" or raw == "RightButton" then
		if not hasMod then return end -- clic gauche / droit seuls : ignores (on cliquerait par erreur)
		if raw == "LeftButton" then key = "BUTTON1" else key = "BUTTON2" end
	elseif raw == "MiddleButton" then
		key = "BUTTON3"
	elseif raw == "Button4" then
		key = "BUTTON4"
	elseif raw == "Button5" then
		key = "BUTTON5"
	end
	local combo = mods .. key
	local bind = cf.bindName
	-- la touche etait liee a une autre action : on le dit (SetBinding la reprend)
	local was = GetBindingAction and GetBindingAction(combo) or nil
	local o1, o2 = GetBindingKey(bind)
	if o1 then SetBinding(o1, nil) end
	if o2 then SetBinding(o2, nil) end
	SetBinding(combo, bind)
	SaveBindings(GetCurrentBindingSet())
	SH.Print("Touche " .. (cf.label or bind) .. " -> " .. combo .. ((was and was ~= "" and was ~= bind) and ("  (retiree de : " .. was .. ")") or ""))
	cf:Hide()
	SH.RefreshKeyButtons()
end

function SH.StartKeyCapture(bindName, label)
	local cf = SH.keyCap
	if not cf then
		cf = CreateFrame("Frame", "ShamanRotKeyCapture", UIParent)
		cf:SetAllPoints(UIParent)
		cf:SetFrameStrata("FULLSCREEN_DIALOG")
		cf:EnableMouse(true)
		cf:EnableMouseWheel(true)
		cf:EnableKeyboard(true)
		cf:Hide()
		local dim = cf:CreateTexture(nil, "BACKGROUND")
		dim:SetTexture("Interface\\Buttons\\WHITE8x8")
		dim:SetAllPoints(cf)
		dim:SetVertexColor(0, 0, 0, 0.6)
		cf.msg = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		cf.msg:SetPoint("CENTER", cf, "CENTER", 0, 40)
		cf.sub = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		cf.sub:SetPoint("TOP", cf.msg, "BOTTOM", 0, -10)
		cf.sub:SetText("Appuie sur une touche, un bouton de souris (milieu, 4, 5...) ou la molette.  Maj / Ctrl / Alt acceptes.  Echap = annuler.")
		cf:SetScript("OnKeyDown", function() SH.CaptureInput(arg1) end)
		cf:SetScript("OnMouseDown", function() SH.CaptureInput(arg1) end)
		cf:SetScript("OnMouseWheel", function()
			if arg1 and arg1 > 0 then SH.CaptureInput("MOUSEWHEELUP") else SH.CaptureInput("MOUSEWHEELDOWN") end
		end)
		SH.keyCap = cf
	end
	cf.bindName = bindName
	cf.label = label
	cf.msg:SetText("Nouvelle touche pour : " .. label)
	cf:Show()
end

function SH.BuildKeys(cont)
	local line = SH.AddHeader(cont, cont, -4, "Touches (clic = definir, Echap = annuler)")
	local t = SH.AddText(cont, line, -6, "Clique sur un bouton puis appuie sur la touche voulue : clavier, bouton de souris (milieu, 4, 5), molette, avec Maj / Ctrl / Alt si tu veux. "
		.. "Les clics gauche / droit seuls sont ignores. La touche est enregistree tout de suite (comme dans Echap > Raccourcis).")
	local prev = t
	local i
	for i = 1, table.getn(SH.KEYROWS) do
		local def = SH.KEYROWS[i]
		local lab = cont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		lab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, (i == 1) and -14 or -10)
		lab:SetWidth(170)
		lab:SetJustifyH("LEFT")
		lab:SetText(def[2])
		local kb = CreateFrame("Button", "ShamanRotKeyBtn" .. i, cont, "UIPanelButtonTemplate")
		kb:SetWidth(190)
		kb:SetHeight(22)
		kb:SetPoint("LEFT", lab, "LEFT", 174, 0)
		kb.bind = def[1]
		kb.klabel = def[2]
		kb:SetScript("OnClick", function()
			this:SetText("En attente de la touche...")
			SH.StartKeyCapture(this.bind, this.klabel)
		end)
		local kc = CreateFrame("Button", "ShamanRotKeyClr" .. i, cont, "UIPanelButtonTemplate")
		kc:SetWidth(70)
		kc:SetHeight(22)
		kc:SetPoint("LEFT", kb, "RIGHT", 4, 0)
		kc:SetText("Retirer")
		kc.bind = def[1]
		kc:SetScript("OnClick", function()
			local o1, o2 = GetBindingKey(this.bind)
			if o1 then SetBinding(o1, nil) end
			if o2 then SetBinding(o2, nil) end
			SaveBindings(GetCurrentBindingSet())
			SH.Print("Touche retiree.")
			SH.RefreshKeyButtons()
		end)
		table.insert(SH.keyBtns, kb)
		prev = lab
	end
	SH.RefreshKeyButtons()
	local m = CreateFrame("Frame", nil, cont)
	m:SetWidth(1)
	m:SetHeight(1)
	m:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -20)
	cont.last = m
end
function SH.BuildHome(cont)
	local last = SH.AddHeader(cont, cont, -4, "Shaman Rotation " .. SH.VERSION .. " - Elementaire")
	local t = SH.AddText(cont, last, -8, "Une touche (Controles > Raccourcis > Shaman Rotation) : Flame Shock entretenu, Chain Lightning a chaque retour, Lightning Bolt en remplissage, "
		.. "Earthquake en AoE. Les priorites viennent des logs reels des meilleurs Elementaires d'OctoWoW et des donnees du serveur (Spell.dbc).")
	last = SH.AddHeader(cont, t, -14, "Etat en direct")
	SH.homeStatus = SH.AddText(cont, last, -8, "")
	SH.homeStatus:SetHeight(120)
	last = SH.AddHeader(cont, SH.homeStatus, -10, "Actions")
	local b1 = SH.AddButton("burst", cont, last, -8, "Burst (arme / lance)", function() ShamanRotation_Burst() end, 220)
	local b2 = SH.AddButton("totems", cont, b1, -6, "Poser tous les totems du combo", function() ShamanRotation_TotemsAll() end, 260)
	local b3 = SH.AddButton("aoe", cont, b2, -6, "Mode AoE : auto / on / off", function() ShamanRotation_AoeToggle(); SH.RefreshOptions() end, 220)
	cont.last = b3
end

function SH.BuildRotation(cont)
	local last = SH.AddHeader(cont, cont, -4, "Sorts de la rotation")
	local c1 = SH.AddCheck("UseFs", cont, last, -6, "Entretenir Flame Shock", "useFs")
	local c2 = SH.AddCheck("UseCl", cont, c1, -2, "Chain Lightning autorise", "useCl")
	local c3 = SH.AddCheck("Interrupt", cont, c2, -2, "Interrompre avec Earth Shock", "interrupt")
	local c4 = SH.AddCheck("EsFill", cont, c3, -2, "Earth Shock de remplissage (non recommande)", "esFill")
	local c5 = SH.AddCheck("UseMb", cont, c4, -2, "Molten Blast pour rafraichir Flame Shock (deduit)", "useMb")
	local c6 = SH.AddCheck("AutoTarget", cont, c5, -2, "Cibler l'ennemi le plus proche sans cible", "autoTarget")
	local h = SH.AddHeader(cont, c6, -12, "Reglages")
	local s1 = SH.AddSlider(cont, h, -22, "fsRefresh", "Relancer Flame Shock sous", 1, 10, 0.5, " s")
	local s2 = SH.AddSlider(cont, s1, -26, "manaCl", "Mana minimum (sorts chers)", 0, 50, 1, " %", true)
	local s3 = SH.AddSlider(cont, s2, -26, "esFillMana", "Earth Shock de remplissage au-dessus de", 30, 100, 5, " %", true)
	local ms = SH.AddCheck("ManaSaver", cont, s3, -18, "Economie de mana : gros sorts seulement s'il reste une reserve APRES le lancer", "manaSaver")
	local s3b = SH.AddSlider(cont, ms, -24, "fsMana", "Flame Shock : reserve apres le lancer", 0, 80, 5, " %", true)
	local s3c = SH.AddSlider(cont, s3b, -26, "eqMana", "Earthquake : reserve apres le lancer", 0, 80, 5, " %", true)
	local ccl = SH.AddCycle("clmode", cont, s3c, -22, "clMode", "Chain Lightning", { "auto", "on", "off" },
		{ auto = "AUTO (economise la mana)", on = "TOUJOURS (a chaque recharge)", off = "JAMAIS" })
	ccl:SetWidth(420)
	local s4 = SH.AddSlider(cont, ccl, -26, "clMonoMana", "Chain Lightning (1 cible) : reserve apres le lancer", 10, 90, 5, " %", true)
	local s5 = SH.AddSlider(cont, s4, -26, "clMinTargets", "Auto : des que cet nombre d'ennemis est proche", 2, 5, 1, "")
	local hs = SH.AddHeader(cont, s5, -18, "Bouclier elementaire (remis automatiquement)")
	local cs = SH.AddCycle("shield", cont, hs, -8, "shield", "Bouclier", { "water", "earth", "off" },
		{ water = "WATER SHIELD (mana)", earth = "EARTH SHIELD (anti-interruption)", off = "COUPE" })
	cs:SetWidth(420)
	local k1 = SH.AddCheck("ShieldAuto", cont, cs, -6, "Hors combat : le remettre des qu'il disparait", "shieldAuto")
	local k2 = SH.AddCheck("ShieldCombat", cont, k1, -2, "En combat : le remettre quand il est consomme (1 GCD)", "shieldCombat")
	local ti = SH.AddText(cont, k2, -8, "Water Shield (rang 5) : 0 mana, 3 charges ; chaque attaque qui te touche rend 130 mana (une fois / 3 s). Earth Shield (rang 3) : 300 mana, 3 charges ; "
		.. "150 PV par attaque et 30 % de chances de ne pas etre interrompu par les degats. Un seul bouclier elementaire a la fois. Si personne ne te frappe, aucun des deux ne fait grand-chose.")
	local h2 = SH.AddHeader(cont, ti, -14, "Diagnostic")
	local c7 = SH.AddCheck("Quiet", cont, h2, -6, "Masquer les messages automatiques", "quiet")
	local c8 = SH.AddCheck("Debug", cont, c7, -2, "Afficher les decisions dans le chat", "debug")
	cont.last = c8
end

function SH.BuildAoe(cont)
	local last = SH.AddHeader(cont, cont, -4, "Mono / AoE")
	local cy = SH.AddCycle("aoe", cont, last, -8, "aoeMode", "Mode", { "auto", "on", "off" }, { auto = "AUTO (selon les ennemis)", on = "TOUJOURS AoE", off = "JAMAIS (mono)" })
	local c1 = SH.AddCheck("UseEq", cont, cy, -8, "Earthquake en AoE", "useEq")
	local s1 = SH.AddSlider(cont, c1, -26, "autoAoeMin", "AoE a partir de", 2, 8, 1, " ennemis")
	local s2 = SH.AddSlider(cont, s1, -26, "aoeRadius", "Rayon de comptage autour de la cible", 5, 20, 1, " m")
	local s3 = SH.AddSlider(cont, s2, -26, "autoDelay", "Retour en mono apres", 0, 6, 0.5, " s")
	local t = SH.AddText(cont, s3, -22, "Le comptage utilise les plaques de nom et UnitXP. Sans eux, l'AUTO ne peut pas compter : utilise TOUJOURS / JAMAIS (touche AoE).")
	SH.aoeStatus = SH.AddText(cont, t, -10, "")
	cont.last = SH.aoeStatus
end

function SH.BuildTotems(cont)
	local labels = { caster = "CASTER (Searing, Tranquil Air, Mana Spring)", melee = "MELEE (Flametongue, Windfury, Strength of Earth, Mana Spring)",
		aoe = "AOE (Magma Totem)", nova = "NOVA (Fire Nova Totem)", fear = "ANTI-PEUR (+ Tremor)", poison = "POISON (purification)", disease = "MALADIE (purification)", off = "COUPE" }
	local last = SH.AddHeader(cont, cont, -4, "Combo de totems")
	local cy = SH.AddCycle("tot", cont, last, -8, "totemPreset", "Combo", SH.PRESET_LIST, labels)
	cy:SetWidth(520)
	local c1 = SH.AddCheck("TotCombat", cont, cy, -6, "La rotation entretient le totem de feu en combat", "totemsInCombat")
	local r1 = SH.AddCheck("TotRedrop", cont, c1, -2, "Reposer un totem trop loin de moi ou detruit (automatique)", "totemRedrop")
	local r2 = SH.AddCheck("TotRedropC", cont, r1, -2, "... aussi pendant le combat", "totemRedropCombat")
	local r3 = SH.AddSlider(cont, r2, -24, "totemRange", "Distance maximale a mon totem", 10, 30, 1, " m")
	local b0 = SH.AddButton("totall", cont, r3, -14, "Poser TOUS les totems du combo (d'un coup)", function() ShamanRotation_TotemsAll() end, 320)
	local b1 = SH.AddButton("totbtn", cont, b0, -6, "Poser le totem suivant (un par appui)", function() ShamanRotation_Totems() end, 320)
	local h = SH.AddHeader(cont, b1, -14, "Etat des totems (minuteur)")
	SH.totemStatus = SH.AddText(cont, h, -8, "")
	SH.totemStatus:SetHeight(90)
	local t = SH.AddText(cont, SH.totemStatus, -8, "Le jeu ne dit pas si un totem est detruit : le suivi est un minuteur (remis a zero a la mort et au changement de zone).")
	cont.last = t
end

function SH.BuildBurst(cont)
	local last = SH.AddHeader(cont, cont, -4, "Burst")
	local c1 = SH.AddCheck("BEm", cont, last, -6, "Elemental Mastery", "burstEm")
	local c2 = SH.AddCheck("BBf", cont, c1, -2, "Blood Fury", "burstBf")
	local c3 = SH.AddCheck("BTr", cont, c2, -2, "Bijoux a utiliser", "burstTrinkets")
	local b = SH.AddButton("burstbtn", cont, c3, -10, "Lancer / armer le burst", function() ShamanRotation_Burst() end, 220)
	local t = SH.AddText(cont, b, -10, "Les deux sorts sont instantanes et sans GCD : le burst n'ajoute aucun temps a la rotation. S'ils sont en recharge, le burst reste arme et part des qu'ils sont prets.")
	cont.last = t
end

function SH.BuildRelics(cont)
	local last = SH.AddHeader(cont, cont, -4, "Echange de reliques (mode wait uniquement)")
	local t0 = SH.AddText(cont, last, -8, "Equiper une relique en combat coute un GCD de 1,5 s (prouve cote serveur) : l'echange prend un appui et le sort part au suivant. "
		.. "Il n'existe donc que le mode WAIT.")
	local cy = SH.AddCycle("relicmode", cont, t0, -8, "relicMode", "Mode", { "off", "main", "spell" },
		{ off = "COUPE", main = "UNE RELIQUE (posee hors combat)", spell = "UNE RELIQUE PAR SORT (echange en combat)" })
	cy:SetWidth(420)
	local cm = SH.AddCycle("relicmain", cont, cy, -6, "relicMain", "Relique du mode UNE RELIQUE", SH.RELIC_NAMES)
	cm:SetWidth(420)
	local sg = SH.AddSlider(cont, cm, -26, "relicGap", "Espacement mini entre deux echanges en combat", 5, 120, 5, " s")
	local h = SH.AddHeader(cont, sg, -18, "Relique par sort (mode PAR SORT)")
	local prev = h
	local i
	for i = 1, table.getn(SH.RELIC_SPELLS) do
		local sp = SH.RELIC_SPELLS[i]
		local b = SH.AddButton("relic" .. i, cont, prev, (i == 1) and -8 or -3, "", function() end, 420)
		b.spell = sp
		b.Refresh = function(self)
			self:SetText(self.spell .. " : " .. (SH.RelicRule(self.spell) or "aucune"))
		end
		b:SetScript("OnClick", function()
			local cur, n, idx = SH.RelicRule(this.spell), table.getn(SH.RELIC_NAMES), 0
			local k
			for k = 1, n do
				if SH.RELIC_NAMES[k] == cur then idx = k end
			end
			idx = idx + 1
			if idx > n then
				SH.SetRelicRule(this.spell, nil)
			else
				SH.SetRelicRule(this.spell, SH.RELIC_NAMES[idx])
			end
			this:Refresh()
		end)
		b:Refresh()
		table.insert(SH.cycles, b)
		prev = b
	end
	local h2 = SH.AddHeader(cont, prev, -14, "Reliques connues (effet verifie sur le serveur)")
	SH.relicInfo = SH.AddText(cont, h2, -8, "")
	SH.relicInfo:SetHeight(190)
	cont.last = SH.relicInfo
end
function SH.BuildDisplay(cont)
	local last = SH.AddHeader(cont, cont, -4, "Indicateur (HUD)")
	local c1 = SH.AddCheck("Hud", cont, last, -6, "Afficher l'indicateur", "hud")
	local c2 = SH.AddCheck("HudLock", cont, c1, -2, "Verrouiller la position", "hudLocked")
	local s1 = SH.AddSlider(cont, c2, -22, "hudScale", "Taille", 50, 200, 10, " %", true)
	local h = SH.AddHeader(cont, s1, -18, "Minimap")
	local b = SH.AddButton("mm", cont, h, -8, "Afficher / cacher le bouton de minimap", function() SH.MinimapToggle() end, 280)
	cont.last = b
end

-- ===================================================================
-- Panneau principal : taille FIXE, chaque onglet defile (molette + barre)
-- ===================================================================
SH.TAB_DEFS = {
	{ id = "accueil", label = "Accueil", icon = "Interface\\Icons\\Spell_Nature_Lightning", c = { 0.00, 0.60, 1.00 } },
	{ id = "touches", label = "Touches", icon = "Interface\\Icons\\INV_Misc_Note_01", c = { 0.95, 0.80, 0.30 } },
	{ id = "rotation", label = "Rotation", icon = "Interface\\Icons\\Spell_Nature_ChainLightning", c = { 0.40, 0.80, 1.00 } },
	{ id = "aoe", label = "AoE", icon = "Interface\\Icons\\Spell_Nature_EarthQuake", c = { 0.80, 0.60, 0.30 } },
	{ id = "totems", label = "Totems", icon = "Interface\\Icons\\Spell_Fire_SearingTotem", c = { 1.00, 0.50, 0.20 } },
	{ id = "burst", label = "Burst", icon = "Interface\\Icons\\Spell_Nature_WispHeal", c = { 0.95, 0.30, 0.25 } },
	{ id = "reliques", label = "Reliques", icon = "Interface\\Icons\\INV_Misc_Idol_03", c = { 0.40, 0.85, 0.50 } },
	{ id = "affichage", label = "Affichage", icon = "Interface\\Icons\\INV_Misc_Gear_03", c = { 0.62, 0.70, 0.82 } },
}

function SH.CreateOptionsPanel()
	if SH.optionsFrame then return end
	local PANEL_W, PANEL_H, FOOT_H = 640, 520, 28
	local f = CreateFrame("Frame", "ShamanRotationOptionsFrame", UIParent)
	SH.optionsFrame = f
	f:SetWidth(PANEL_W)
	f:SetHeight(PANEL_H)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	f:SetBackdropColor(0.03, 0.05, 0.09, 0.97)
	f:SetBackdropBorderColor(0, 0.44, 0.87, 1)
	f:Hide()
	table.insert(UISpecialFrames, "ShamanRotationOptionsFrame")

	local head = f:CreateTexture(nil, "BACKGROUND")
	head:SetTexture("Interface\\Buttons\\WHITE8x8")
	head:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
	head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	head:SetHeight(30)
	head:SetVertexColor(0, 0.44, 0.87, 0.25)
	local logo = f:CreateTexture(nil, "ARTWORK")
	logo:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
	logo:SetWidth(22)
	logo:SetHeight(22)
	logo:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
	title:SetText("|cff0070deShaman Rotation|r")
	local ver = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	ver:SetPoint("LEFT", title, "RIGHT", 10, -1)
	ver:SetText("v" .. SH.VERSION .. " - Elementaire")
	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
	local tabLine = f:CreateTexture(nil, "ARTWORK")
	tabLine:SetTexture("Interface\\Buttons\\WHITE8x8")
	tabLine:SetHeight(2)
	tabLine:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -90)
	tabLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -90)
	tabLine:SetVertexColor(0, 0.44, 0.87, 1)
	local foot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 8)
	foot:SetTextColor(0.62, 0.62, 0.68)
	foot:SetText("Survole un reglage pour lire son aide. Tout est enregistre automatiquement. /shamrot menu")

	local tabButtons, tabContents = {}, {}
	SH.tabContents = tabContents
	local function setTabState(b, on)
		local c = b.col
		if on then
			b.bg:SetVertexColor(c[1], c[2], c[3], 0.30); b.bar:SetVertexColor(c[1], c[2], c[3], 1); b.text:SetTextColor(1, 1, 1); b.icon:SetAlpha(1)
		else
			b.bg:SetVertexColor(c[1], c[2], c[3], 0.07); b.bar:SetVertexColor(c[1], c[2], c[3], 0.35); b.text:SetTextColor(0.72, 0.72, 0.75); b.icon:SetAlpha(0.65)
		end
	end

	SH.ShowTab = function(id)
		if ShamanRotationDB and ShamanRotationDB.settings then ShamanRotationDB.settings.lastTab = id end
		local i, def
		for i = 1, table.getn(SH.TAB_DEFS) do
			def = SH.TAB_DEFS[i]
			if def.id == id then
				tabContents[def.id].scroll:Show()
				setTabState(tabButtons[def.id], true)
				tabLine:SetVertexColor(def.c[1], def.c[2], def.c[3], 1)
			else
				tabContents[def.id].scroll:Hide()
				setTabState(tabButtons[def.id], false)
			end
		end
		-- taille de fenetre fixe : on regle la zone defilante sur le contenu reel de l'onglet, retour en haut
		local act = tabContents[id]
		local sc0 = act.scroll
		sc0:SetVerticalScroll(0)
		if act.last then
			local bottom = act.last:GetBottom()
			local top = act:GetTop()
			if bottom and top then act:SetHeight((top - bottom) + 12) end
		end
		local range = (act:GetHeight() or 0) - (sc0:GetHeight() or 0)
		if range < 0 then range = 0 end
		sc0.bar.syncing = true
		sc0.bar:SetMinMaxValues(0, range)
		sc0.bar:SetValue(0)
		sc0.bar.syncing = false
		if range > 0 then sc0.bar:Show() else sc0.bar:Hide() end
		if sc0.UpdateScrollChildRect then sc0:UpdateScrollChildRect() end
		local uiH = UIParent.GetHeight and UIParent:GetHeight() or nil
		if uiH and uiH > 0 and PANEL_H > uiH * 0.92 then f:SetScale(uiH * 0.92 / PANEL_H) else f:SetScale(1) end
		SH.RefreshStatus()
	end

	local i, def
	for i = 1, table.getn(SH.TAB_DEFS) do
		def = SH.TAB_DEFS[i]
		local b = CreateFrame("Button", "ShamanRotTab_" .. def.id, f)
		b.tabId = def.id
		b.col = def.c
		b:SetWidth(66)
		b:SetHeight(48)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + (i - 1) * 69, -40)
		b:EnableMouse(true)
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function() SH.ShowTab(this.tabId) end)
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
		b.bg:SetAllPoints(b)
		b.bar = b:CreateTexture(nil, "ARTWORK")
		b.bar:SetTexture("Interface\\Buttons\\WHITE8x8")
		b.bar:SetHeight(3)
		b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
		b.bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetTexture(def.icon)
		b.icon:SetWidth(22)
		b.icon:SetHeight(22)
		b.icon:SetPoint("TOP", b, "TOP", 0, -5)
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.text:SetPoint("TOP", b.icon, "BOTTOM", 0, -3)
		b.text:SetText(def.label)
		setTabState(b, false)
		tabButtons[def.id] = b

		local scroll = CreateFrame("ScrollFrame", "ShamanRotScroll_" .. def.id, f)
		scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -96)
		scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, FOOT_H + 6)
		scroll:EnableMouseWheel(true)
		scroll:Hide()
		local cont = CreateFrame("Frame", nil, scroll)
		cont:SetWidth(PANEL_W - 70)
		cont:SetHeight(10)
		cont:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
		scroll:SetScrollChild(cont)
		cont.scroll = scroll
		local sb = CreateFrame("Slider", "ShamanRotScrollBar_" .. def.id, scroll)
		sb:SetOrientation("VERTICAL")
		sb:SetWidth(10)
		sb:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
		sb:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
		sb:SetMinMaxValues(0, 1)
		sb:SetValueStep(1)
		sb:SetValue(0)
		local sbBg = sb:CreateTexture(nil, "BACKGROUND")
		sbBg:SetTexture("Interface\\Buttons\\WHITE8x8")
		sbBg:SetAllPoints(sb)
		sbBg:SetVertexColor(1, 1, 1, 0.08)
		sb:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
		local thumb = sb:GetThumbTexture()
		if thumb then
			thumb:SetWidth(10)
			thumb:SetHeight(36)
			thumb:SetVertexColor(def.c[1], def.c[2], def.c[3], 0.85)
		end
		sb:Hide()
		scroll.bar = sb
		sb:SetScript("OnValueChanged", function()
			if not this.syncing then this:GetParent():SetVerticalScroll(this:GetValue()) end
		end)
		scroll:SetScript("OnMouseWheel", function()
			local range = this:GetVerticalScrollRange() or 0
			local v = (this:GetVerticalScroll() or 0) - (arg1 or 0) * 40
			if v < 0 then v = 0 end
			if v > range then v = range end
			this:SetVerticalScroll(v)
			this.bar.syncing = true
			this.bar:SetValue(v)
			this.bar.syncing = false
		end)
		tabContents[def.id] = cont
	end

	SH.BuildHome(tabContents.accueil)
	SH.BuildKeys(tabContents.touches)
	SH.BuildRotation(tabContents.rotation)
	SH.BuildAoe(tabContents.aoe)
	SH.BuildTotems(tabContents.totems)
	SH.BuildBurst(tabContents.burst)
	SH.BuildRelics(tabContents.reliques)
	SH.BuildDisplay(tabContents.affichage)

	f:SetScript("OnShow", function() SH.RefreshOptions() end)
	f:SetScript("OnUpdate", function()
		SH.panelAcc = (SH.panelAcc or 0) + (arg1 or 0)
		if SH.panelAcc >= 0.5 then
			SH.panelAcc = 0
			SH.RefreshStatus()
		end
	end)
end

function SH.RefreshStatus()
	local now = GetTime()
	if SH.homeStatus then
		local n = SH.autoN
		SH.homeStatus:SetText("Cible : " .. (UnitName("target") or "aucune") .. "\nFlame Shock : "
			.. (SH.HarmTarget() and string.format("%.1f s", SH.FsRemain()) or "-")
			.. "\nMana : " .. string.format("%.0f %%", SH.ManaPct() * 100)
			.. "\nMode : " .. (SH.AoeOn() and "AOE" or "MONO") .. " (" .. SH.CFG.aoeMode .. ")" .. (n and (" - " .. n .. " ennemi(s) proche(s)") or "")
			.. "\nExtensions : Nampower " .. (type(IsSpellInRange) == "function" and "oui" or "non") .. ", UnitXP " .. (type(UnitXP) == "function" and "oui" or "non")
			.. ", SuperWoW " .. (type(SUPERWOW_VERSION) ~= "nil" and "oui" or "non"))
	end
	if SH.totemStatus then SH.totemStatus:SetText(SH.TotemStatus()) end
	if SH.relicInfo then
		local txt, i = "", 0
		for i = 1, table.getn(SH.RELIC_NAMES) do
			local nm = SH.RELIC_NAMES[i]
			txt = txt .. (SH.RelicOwned(nm) and "|cff40ff40[possedee]|r " or "|cff888888[absente]|r ") .. nm .. " : " .. SH.RELICS[nm][2] .. "\n"
		end
		SH.relicInfo:SetText(txt)
	end
	if SH.aoeStatus then
		SH.aoeStatus:SetText("Etat : " .. (SH.AoeOn() and "AOE" or "MONO") .. (SH.autoN and (" - " .. SH.autoN .. " ennemi(s) a moins de " .. SH.CFG.aoeRadius .. " m de la cible") or " - comptage impossible (UnitXP / plaques absents)"))
	end
end

function SH.RefreshOptions()
	local i
	SH.refreshing = true
	for i = 1, table.getn(SH.checks) do SH.checks[i]:SetChecked(SH.CFG[SH.checks[i].key]) end
	for i = 1, table.getn(SH.sliders) do SH.sliders[i]:SetValue(SH.sliders[i].getVal()) end
	SH.refreshing = false
	for i = 1, table.getn(SH.cycles) do SH.cycles[i]:Refresh() end
	SH.RefreshKeyButtons()
	SH.RefreshStatus()
end

function ShamanRotation_OpenMenu() SH.OpenMenu() end

function SH.OpenMenu(show)
	SH.CreateOptionsPanel()
	local f = SH.optionsFrame
	if show == nil then show = not f:IsShown() end
	if show then
		f:Show()
		local tab = ShamanRotationDB and ShamanRotationDB.settings and ShamanRotationDB.settings.lastTab or "accueil"
		if not SH.tabContents[tab] then tab = "accueil" end
		SH.ShowTab(tab)
	else
		f:Hide()
	end
end

-- ===================================================================
-- HUD : GCD, recharges (Chain Lightning, chocs, Earthquake, Elemental Mastery, Blood Fury), minuteur Flame Shock, totems
-- ===================================================================
SH.hudIcons = {}
function SH.BuildHud()
	if SH.hud then return end
	local f = CreateFrame("Frame", "ShamanRotationHud", UIParent)
	SH.hud = f
	f:SetWidth(232)
	f:SetHeight(76)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() if not SH.CFG.hudLocked then this:StartMoving() end end)
	f:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
		local db = ShamanRotationDB
		if type(db) == "table" then
			local x, y = this:GetCenter()
			db.pos = db.pos or {}
			db.pos.hud = { x = x, y = y }
		end
	end)
	f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	f:SetBackdropColor(0.02, 0.04, 0.08, 0.8)
	f:SetBackdropBorderColor(0, 0.44, 0.87, 0.9)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
	-- barre de GCD
	f.gcdBg = f:CreateTexture(nil, "BACKGROUND")
	f.gcdBg:SetTexture("Interface\\Buttons\\WHITE8x8")
	f.gcdBg:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
	f.gcdBg:SetWidth(220)
	f.gcdBg:SetHeight(5)
	f.gcdBg:SetVertexColor(1, 1, 1, 0.12)
	f.gcd = f:CreateTexture(nil, "ARTWORK")
	f.gcd:SetTexture("Interface\\Buttons\\WHITE8x8")
	f.gcd:SetPoint("TOPLEFT", f.gcdBg, "TOPLEFT", 0, 0)
	f.gcd:SetWidth(1)
	f.gcd:SetHeight(5)
	f.gcd:SetVertexColor(0, 0.7, 1, 1)
	-- icones : DoT Flame Shock, chocs, Chain Lightning, Earthquake, Elemental Mastery, Blood Fury
	local defs = {
		{ key = "fs", tex = "Interface\\Icons\\Spell_Fire_FlameShock" }, { key = "shock", tex = "Interface\\Icons\\Spell_Nature_EarthShock" },
		{ key = "cl", tex = "Interface\\Icons\\Spell_Nature_ChainLightning" }, { key = "eq", tex = "Interface\\Icons\\Spell_Nature_EarthQuake" },
		{ key = "em", tex = "Interface\\Icons\\Spell_Nature_WispHeal" }, { key = "bf", tex = "Interface\\Icons\\Racial_Orc_BerserkerStrength" },
	}
	local i
	for i = 1, table.getn(defs) do
		local d = defs[i]
		local ic = CreateFrame("Frame", nil, f)
		ic:SetWidth(32)
		ic:SetHeight(32)
		ic:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + (i - 1) * 37, -15)
		ic.tex = ic:CreateTexture(nil, "ARTWORK")
		ic.tex:SetTexture(d.tex)
		ic.tex:SetAllPoints(ic)
		ic.txt = ic:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		ic.txt:SetPoint("CENTER", ic, "CENTER", 0, 0)
		ic.key = d.key
		SH.hudIcons[d.key] = ic
	end
	-- totems : 4 pastilles (feu, air, terre, eau)
	f.tot = {}
	local els = { "fire", "air", "earth", "water" }
	local cols = { fire = { 1, 0.45, 0.1 }, air = { 0.7, 0.85, 1 }, earth = { 0.7, 0.55, 0.3 }, water = { 0.2, 0.6, 1 } }
	for i = 1, 4 do
		local el = els[i]
		local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + (i - 1) * 56, -55)
		t:SetTextColor(cols[el][1], cols[el][2], cols[el][3])
		f.tot[el] = t
	end
	f.els = els
	f:SetScript("OnUpdate", function()
		SH.hudAcc = (SH.hudAcc or 0) + (arg1 or 0)
		if SH.hudAcc < 0.1 then return end
		SH.hudAcc = 0
		SH.HudUpdate()
	end)
	local pos = ShamanRotationDB and ShamanRotationDB.pos and ShamanRotationDB.pos.hud
	if pos and pos.x and pos.y then
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	end
	SH.HudRefreshConfig()
end

local function setCd(ic, rem, active)
	if rem and rem > 0.05 then
		ic.tex:SetVertexColor(0.4, 0.4, 0.4)
		ic.txt:SetText(rem >= 10 and string.format("%.0f", rem) or string.format("%.1f", rem))
	else
		ic.tex:SetVertexColor(1, 1, 1)
		ic.txt:SetText(active and "" or "")
	end
end

function SH.HudUpdate()
	local f = SH.hud
	if not f or not f:IsShown() then return end
	local S = SH.SPELLS
	-- GCD : duree restante du GCD d'un sort instantane / a incantation (Lightning Bolt sert de reference)
	local rem, real, known = SH.CdInfo(S.lb)
	local w = 1
	if known and real <= 0 and rem > 0 then w = math.max(1, 220 * (1 - rem / 1.5)) elseif known and real > 0 then w = 220 else w = 220 end
	f.gcd:SetWidth(w)
	-- DoT Flame Shock : temps restant sur la cible
	local ic = SH.hudIcons
	if ic.fs then
		local r = SH.HarmTarget() and SH.FsRemain() or 0
		if r > 0 then
			ic.fs.tex:SetVertexColor(1, 1, 1)
			ic.fs.txt:SetText(string.format("%.0f", r))
			if r <= SH.CFG.fsRefresh then ic.fs.txt:SetTextColor(1, 0.3, 0.2) else ic.fs.txt:SetTextColor(1, 1, 1) end
		else
			ic.fs.tex:SetVertexColor(0.4, 0.4, 0.4)
			ic.fs.txt:SetText("")
		end
	end
	local _, rShock = SH.CdInfo(S.fs)
	setCd(ic.shock, rShock)
	local _, rCl = SH.CdInfo(S.cl)
	setCd(ic.cl, rCl)
	if SH.CFG.clMode == "off" then
		ic.cl.tex:SetVertexColor(0.7, 0.2, 0.2)
		ic.cl.txt:SetText("OFF")
	elseif SH.CFG.clMode == "auto" and not (rCl and rCl > 0.05) then
		ic.cl.txt:SetText("A")
	end
	local _, rEq = SH.CdInfo(S.eq)
	setCd(ic.eq, rEq)
	local _, rEm = SH.CdInfo(S.em)
	setCd(ic.em, rEm)
	local _, rBf = SH.CdInfo(S.bf)
	setCd(ic.bf, rBf)
	-- totems
	local i, el
	for i = 1, 4 do
		el = f.els[i]
		local t = SH.totems[el]
		local left = nil
		if t and SH.TOTEM[t.name] then left = t.at + SH.TOTEM[t.name][2] - GetTime() end
		local want = SH.PresetTotem(el, SH.AoeOn())
		if t and left and left > 0 then
			f.tot[el]:SetText(string.gsub(t.name, " Totem", "") .. " " .. string.format("%.0f", left))
		elseif want then
			f.tot[el]:SetText("|cffff4040" .. string.gsub(want, " Totem", "") .. " !|r")
		else
			f.tot[el]:SetText("")
		end
	end
end

function SH.HudRefreshConfig()
	local f = SH.hud
	if not f then return end
	f:SetScale(SH.CFG.hudScale or 1)
	if SH.CFG.hud then f:Show() else f:Hide() end
	f:EnableMouse(not SH.CFG.hudLocked)
end

-- ===================================================================
-- Bouton de minimap : clic = menu, clic droit = bascule AoE, glisser = deplacer
-- ===================================================================
function SH.MinimapPlace()
	local b = SH.mmButton
	if not b then return end
	local db = ShamanRotationDB
	local ang = (db and db.mm and db.mm.angle) or 215
	local r = ang * math.pi / 180
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(r), 80 * math.sin(r))
end

function SH.BuildMinimap()
	if SH.mmButton or not Minimap then return end
	local b = CreateFrame("Button", "ShamanRotationMinimapButton", Minimap)
	SH.mmButton = b
	b:SetWidth(32)
	b:SetHeight(32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	b.icon = b:CreateTexture(nil, "BACKGROUND")
	b.icon:SetWidth(20)
	b.icon:SetHeight(20)
	b.icon:SetPoint("CENTER", b, "CENTER", 0, 1)
	b.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetWidth(52)
	border:SetHeight(52)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", function()
		if arg1 == "RightButton" then ShamanRotation_AoeToggle(); SH.RefreshStatus() else SH.OpenMenu() end
	end)
	b:SetScript("OnEnter", function()
		if not GameTooltip then return end
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("Shaman Rotation")
		GameTooltip:AddLine("Clic : menu", 1, 1, 1)
		GameTooltip:AddLine("Clic droit : mode AoE (" .. SH.CFG.aoeMode .. ")", 1, 1, 1)
		GameTooltip:AddLine("Glisser : deplacer", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	b:SetScript("OnDragStart", function()
		this:SetScript("OnUpdate", function()
			local mx, my = GetCursorPosition()
			local sc = Minimap:GetEffectiveScale()
			local cx, cy = Minimap:GetCenter()
			if not (mx and cx) then return end
			local ang = math.deg(math.atan2(my / sc - cy, mx / sc - cx))
			local db = ShamanRotationDB
			if type(db) == "table" then db.mm = db.mm or {}; db.mm.angle = ang end
			SH.MinimapPlace()
		end)
	end)
	b:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
	SH.MinimapPlace()
end

function SH.MinimapToggle()
	if not SH.mmButton then SH.BuildMinimap() return end
	if SH.mmButton:IsShown() then SH.mmButton:Hide() else SH.mmButton:Show() end
end

-- construit l'interface une fois les reglages charges
SH.uiFrame = CreateFrame("Frame")
SH.uiFrame:RegisterEvent("PLAYER_LOGIN")
SH.uiFrame:SetScript("OnEvent", function()
	SH.BuildHud()
	SH.BuildMinimap()
end)
