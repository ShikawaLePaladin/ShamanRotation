---------------------------------------------------------------
-- ShamanRotation_Rot.lua : rotation Elementaire (mono / AoE), burst, touche principale
-- Ordre tire des logs reels des meilleurs Elementaires d'OctoWoW (voir DESIGN.md) et des donnees du serveur (Spell.dbc / spell_template).
-- Lua 5.0 strict.
---------------------------------------------------------------
local SH = ShamanRotation

SH.lastRetarget = -10
function SH.EnsureTarget(now)
	if SH.HarmTarget() then return true end
	if SH.CFG.autoTarget and now - SH.lastRetarget >= SH.CFG.retargetGap then
		SH.lastRetarget = now
		TargetNearestEnemy()
		return SH.HarmTarget()
	end
	return false
end

-- trace de decision (anneau de 60 lignes dans ShamanRotationDB.trace, lue apres un /reload)
SH.decideTxt = ""
SH.decideAt = -10
function SH.Decide(now, txt)
	if txt == SH.decideTxt and now - SH.decideAt < 3 then return end
	SH.decideTxt = txt
	SH.decideAt = now
	local db = ShamanRotationDB
	if type(db) ~= "table" then return end
	if type(db.trace) ~= "table" then db.trace = {} end
	table.insert(db.trace, string.format("%.1f %s mana=%.0f%% aoe=%s", now, txt, SH.ManaPct() * 100, tostring(SH.AoeOn())))
	while table.getn(db.trace) > 60 do table.remove(db.trace, 1) end
end

-- resultat de SH.TryCast : true = sort lance (on note la decision) ; "relic" = l'echange de relique a pris l'appui (rien a noter) ; false = rien
local function used(r, now, txt)
	if r == "relic" then return true end
	if r then
		SH.Decide(now, txt)
		return true
	end
	return false
end

-- Chain Lightning est-il autorise maintenant ? (voir clMode)
function SH.ClAllowed(now, mana, aoe, clearcast)
	local CFG = SH.CFG
	local mode = CFG.clMode
	if mode == "off" then return false end
	if mode == "on" then return true end
	if aoe or clearcast then return true end
	if SH.autoN and SH.autoN >= CFG.clMinTargets then return true end   -- plusieurs ennemis a portee de saut
	if SH.PlayerBuff(SH.IDS.em) ~= nil then return true end              -- Elemental Mastery : -20 % de mana
	if CFG.manaSaver then return SH.AfterPct(SH.SPELLS.cl) >= CFG.clMonoMana end
	return mana >= CFG.clMonoMana
end

-- Un sort de la liste est lance : retourne vrai (l'appui est consomme)
function SH.Rotation(now)
	local CFG = SH.CFG
	local S = SH.SPELLS
	if not SH.EnsureTarget(now) then return false end
	-- incantation en cours : on ne decide qu'a moins de queueWin s de la fin (Nampower met le sort suivant en file)
	if now < SH.castUntil - CFG.queueWin then return false end

	local name = UnitName("target")
	local mana = SH.ManaPct()
	local rich = mana >= CFG.manaCl
	local fireOk = not SH.Immune("fire", name)
	local natOk = not SH.Immune("nature", name)
	local frostOk = not SH.Immune("frost", name)
	local aoe = SH.AoeOn()
	local clearcast = SH.PlayerBuff(SH.IDS.clearcast) ~= nil

	-- 1. interruption (Earth Shock : 2 s de silence ; repli Frost Shock sans interruption si la cible est immunisee a la Nature)
	if CFG.interrupt and SH.TargetCasting(now) then
		if natOk and used(SH.TryCast(S.es, true), now, "Earth Shock : interruption") then return true end
	end

	-- 1b. bouclier elementaire : remis des qu'il est consomme (Water Shield : 0 mana ; 1 GCD)
	if SH.ShieldStep(now, true) then return true end

	-- 2. totem de feu en combat (Searing / Magma selon le preset), 1 GCD, seulement si l'option est cochee
	if CFG.totemsInCombat and SH.TotemFireStep then SH.TotemFireStep(now, aoe) end

	-- 3. Flame Shock entretenu (DoT 15 s) : rafraichi sous fsRefresh s ; Molten Blast (si active) rafraichit le DoT quand les chocs sont en recharge
	if CFG.useFs and fireOk and rich and ((not CFG.manaSaver) or SH.AfterPct(S.fs) >= CFG.fsMana) then
		local remain = SH.FsRemain()
		if remain <= CFG.fsRefresh then
			local r = SH.TryCast(S.fs, true)
			if r == true then
				SH.fs.guid = SH.TargetGuid()
				SH.fs.at = now
			end
			if used(r, now, "Flame Shock (reste " .. string.format("%.1f", remain) .. " s)") then return true end
			if CFG.useMb and remain > 0 and remain <= 2.5 and SH.Known(S.mb) then
				r = SH.TryCast(S.mb, true)
				if r == true then
					SH.fs.guid = SH.TargetGuid()
					SH.fs.at = now
				end
				if used(r, now, "Molten Blast : rafraichit Flame Shock") then return true end
			end
		end
	end

	-- 4. AoE : Earthquake (recharge 16 s, degats de zone a 10 m autour de la cible) puis Chain Lightning
	if aoe and rich and CFG.useEq and ((not CFG.manaSaver) or SH.AfterPct(S.eq) >= CFG.eqMana) and used(SH.TryCast(S.eq, true), now, "Earthquake (AoE)") then return true end

	-- 5. Chain Lightning. Donnees (serveur + logs) : 605 mana (Lightning Bolt : 210), incantation 1,5 s avec Lightning Mastery, 3 cibles a -30 % par saut.
	--    Une seule cible : environ 3 fois moins de degats par mana que Lightning Bolt ; a 3 cibles : a egalite et bien plus de DPS.
	--    Mode "on" : a chaque retour de recharge (6 s). Mode "auto" : a plusieurs cibles, ou sous Clearcasting / Elemental Mastery (sorts moins chers),
	--    ou tant que la mana reste au-dessus de clMonoMana. Mode "off" : jamais.
	if CFG.useCl and rich and SH.ClAllowed(now, mana, aoe, clearcast) then
		if used(SH.TryCast(S.cl, true), now, clearcast and "Chain Lightning (Clearcasting)" or (aoe and "Chain Lightning (AoE)" or "Chain Lightning")) then return true end
	end
	-- 6. Earth Shock de remplissage (desactive par defaut : ~2/min chez les meilleurs joueurs)
	if CFG.esFill and natOk and mana >= CFG.esFillMana and used(SH.TryCast(S.es, true), now, "Earth Shock (remplissage)") then return true end

	-- 7. Lightning Bolt de remplissage (55 % des degats des meilleurs joueurs)
	if used(SH.TryCast(S.lb, true), now, "Lightning Bolt") then return true end
	-- cible a portee d'aucun sort a incantation : Frost Shock (instantane) en dernier recours
	if frostOk and SH.InRange(S.frs) == 1 and used(SH.TryCast(S.frs, true), now, "Frost Shock (repli)") then return true end
	return false
end

-- ===================================================================
-- Burst : Elemental Mastery + Blood Fury (+ objets a utiliser si coches). Instantanes, sans GCD : n'ajoutent aucun temps a la rotation.
-- Le bouton ARME le burst ; il part des que les sorts sont prets (immediatement s'ils le sont).
-- ===================================================================
function SH.BurstStep(now)
	local CFG = SH.CFG
	local S = SH.SPELLS
	local fired, waiting = false, false
	if CFG.burstEm and SH.Known(S.em) then
		if SH.Ready(S.em) then
			SH.Cast(S.em)
			fired = true
			SH.Decide(now, "BURST : Elemental Mastery")
		else
			waiting = true
		end
	end
	if CFG.burstBf and SH.Known(S.bf) then
		if SH.Ready(S.bf) then
			SH.Cast(S.bf)
			fired = true
			SH.Decide(now, "BURST : Blood Fury")
		else
			waiting = true
		end
	end
	if CFG.burstTrinkets then
		local slot
		for slot = 13, 14 do
			local start, dur, en = GetInventoryItemCooldown("player", slot)
			if GetInventoryItemLink("player", slot) and start == 0 and dur == 0 and en == 1 then
				UseInventoryItem(slot)
				fired = true
			end
		end
	end
	-- tout est parti (ou rien n'est disponible) : on desarme
	if not waiting or fired then
		SH.burst.armed = false
	end
	return fired
end

function ShamanRotation_Burst()
	local now = GetTime()
	SH.burst.armed = true
	SH.burst.at = now
	if not SH.BurstStep(now) then
		if SH.burst.armed then
			SH.Print("Burst arme : il part des que Elemental Mastery / Blood Fury sont prets.")
		else
			SH.Print("Burst : rien de disponible (Elemental Mastery / Blood Fury en recharge ou non appris).")
		end
	end
end

-- ===================================================================
-- Touche principale
-- ===================================================================
function ShamanRotation_Execute()
	local now = GetTime()
	if UnitIsDeadOrGhost("player") then return end
	SH.TotemConfirm(now)
	if SH.totemSeq then return end -- pose des totems en cours : le GCD est pris, la rotation attend
	if SH.burst.armed then SH.BurstStep(now) end
	SH.Rotation(now)
end

function ShamanRotation_AoeToggle()
	local m = SH.CFG.aoeMode
	local nxt = (m == "auto") and "on" or ((m == "on") and "off" or "auto")
	SH.SetSetting("aoeMode", nxt)
	SH.autoAoe = false
	SH.Print("Mode AoE : " .. nxt .. ((nxt == "auto") and " (selon le nombre d'ennemis)" or ""))
end

-- bascule Chain Lightning : auto -> toujours -> jamais -> auto
function ShamanRotation_ClToggle()
	local m = SH.CFG.clMode
	local nxt = (m == "auto") and "on" or ((m == "on") and "off" or "auto")
	SH.SetSetting("clMode", nxt)
	local txt = { auto = "AUTO (economise la mana : plusieurs cibles, Clearcasting, Elemental Mastery, ou mana > " .. string.format("%.0f", SH.CFG.clMonoMana * 100) .. " %)",
		on = "TOUJOURS (a chaque retour de recharge)", off = "JAMAIS" }
	SH.Print("Chain Lightning : " .. txt[nxt])
	if SH.RefreshOptions then SH.RefreshOptions() end
end