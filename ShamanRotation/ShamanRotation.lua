---------------------------------------------------------------
-- ShamanRotation.lua : noyau (reglages, livre de sorts, recharges, buffs, portee, lancer, evenements)
-- Lua 5.0 strict (client 1.12). Tout passe par la table SH (limite de 32 upvalues par fonction).
-- Extensions utilisees SI PRESENTES, toujours sous pcall : Nampower (IsSpellInRange), SuperWoW (GUID, UNIT_CASTEVENT, UnitBuff etendu),
-- UnitXP_SP3 (distance exacte). Sans elles : repli propre.
---------------------------------------------------------------
ShamanRotation = {}
local SH = ShamanRotation
SH.VERSION = "0.2.0"
SH.DB_VERSION = 1

BINDING_HEADER_SHAMANROT = "Shaman Rotation"
BINDING_NAME_SHAMANROT_ROTATION = "Rotation (une touche)"
BINDING_NAME_SHAMANROT_BURST = "Burst"
BINDING_NAME_SHAMANROT_TOTEMS = "Totems (combo)"
BINDING_NAME_SHAMANROT_TOTEMS4 = "Poser tous les totems (combo)"
BINDING_NAME_SHAMANROT_AOE = "Mode AoE (bascule)"
BINDING_NAME_SHAMANROT_MENU = "Ouvrir le menu"

-- ========= Sorts (noms du jeu, le rang le plus haut est lance par CastSpellByName) =========
SH.SPELLS = {
	lb = "Lightning Bolt", cl = "Chain Lightning", eq = "Earthquake", fs = "Flame Shock", es = "Earth Shock", frs = "Frost Shock",
	mb = "Molten Blast", em = "Elemental Mastery", bf = "Blood Fury",
}
-- identifiants de l'aura Flame Shock sur la cible (tous rangs) et buffs suivis (donnees Spell.dbc du serveur)
SH.FS_IDS = { [8050] = true, [8052] = true, [8053] = true, [10447] = true, [10448] = true, [29228] = true }
SH.IDS = { clearcast = 45542, em = 16166 }
SH.DUR = { fs = 15 }            -- duree du DoT Flame Shock (s) : SpellDuration.dbc, sort 29228
SH.RANGE = { eq = 30, cl = 30, lb = 30 }  -- sorts lances sur la cible (Earthquake aussi : "Breaks the earth beneath the target", degats de zone a 10 m AUTOUR DE LA CIBLE, Spell.dbc 52878)

-- ========= Reglages =========
SH.CFG = {
	aoeMode = "auto",       -- "off" | "auto" | "on"
	autoAoeMin = 3,         -- AoE a partir de ce nombre d'ennemis proches (plaques de nom + UnitXP)
	autoDelay = 2,          -- retour en mono apres ce delai (s)
	aoeRadius = 10,         -- rayon de comptage (m)
	fsRefresh = 4.0,        -- Flame Shock rafraichi sous ce temps restant (s) : les meilleurs joueurs le relancent toutes les ~10,7 s sur un DoT de 15 s
	useFs = true,
	useCl = true,           -- Chain Lightning a chaque retour de recharge (6 s)
	useEq = true,           -- Earthquake en AoE
	useMb = false,          -- Molten Blast pour rafraichir Flame Shock (DEDUIT, voir DESIGN.md : desactive par defaut)
	interrupt = true,       -- Earth Shock pour interrompre une incantation
	esFill = false,         -- Earth Shock de remplissage (les meilleurs joueurs n'en lancent que ~2/min : desactive)
	esFillMana = 0.7,       -- ... seulement au-dessus de cette fraction de mana
	manaCl = 0.15,          -- pas de Chain Lightning / Earthquake / Flame Shock sous cette fraction de mana (Lightning Bolt seul)
	focusExpensive = true,  -- sous Clearcasting : prefere Chain Lightning / Earthquake (sorts les plus chers)
	autoTarget = true,
	retargetGap = 0.4,
	quarantine = 1.0,
	totemPreset = "caster", -- "caster" | "melee" | "aoe" | "fear" | "cleanse" | "off"
	totemsInCombat = false, -- le bouton Totems pose le totem manquant ; en rotation seulement le totem de feu (1 GCD)
	burstEm = true, burstBf = true, burstTrinkets = false, burstTrinketGcd = false,
	queueWin = 0.25,        -- on prepare le sort suivant dans les 0,25 s avant la fin de l'incantation (Nampower met en file)
	totemRedrop = true,     -- repose les totems de buff quand ils sont trop loin de toi (ou detruits) ; demande UnitXP + plaques de nom amicales
	totemRedropCombat = false, -- ... aussi pendant le combat (sinon seulement hors combat)
	totemRange = 27,        -- distance maximale a ton totem (m) : le rayon reel de ses auras est de 30 m (Spell.dbc), 3 m de marge
	shield = "water",       -- bouclier elementaire remis automatiquement : "water" | "earth" | "off"
	shieldAuto = true,      -- hors combat : remis des qu'il disparait (sauf si tu bois / manges)
	shieldCombat = true,    -- en combat : remis (1 GCD) quand il est consomme
	shieldMinCharges = 1,   -- remis quand il reste moins de ce nombre de charges (1 = seulement quand il a disparu)
	relicMode = "off",      -- "off" | "main" (une relique, hors combat) | "spell" (une relique par sort, mode wait uniquement)
	relicMain = "Totem of Crackling Thunder", relicGap = 25, -- relique du mode main ; espacement minimal entre deux echanges en combat (s)
	hud = true, hudLocked = false, hudScale = 1.0,   -- indicateur (GCD, recharges, DoT, totems)
	quiet = false, debug = false,
}
SH.DEFAULTS = {}
do
	local k, v
	for k, v in pairs(SH.CFG) do SH.DEFAULTS[k] = v end
end

-- ========= Etat =========
SH.spellCache = {}
SH.noMana = {}
SH.block = {}
SH.castUntil = 0
SH.lastCastName = nil
SH.lastCastAt = -10
SH.lastErr = nil
SH.lastErrAt = -10
SH.fs = { guid = nil, at = -100 }     -- derniere pose de Flame Shock (par cible)
SH.castsByGuid = {}                    -- SuperWoW : [guid] = fin de l'incantation de l'ennemi
SH.burst = { armed = false, at = -100 }
SH.regenHooks = {}

function SH.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[ShamanRot]|r " .. tostring(msg))
	end
end
function SH.Say(msg)
	if not SH.CFG.quiet then SH.Print(msg) end
end
function SH.Dbg(msg)
	if SH.CFG.debug then SH.Print("|cff88ccff" .. tostring(msg) .. "|r") end
end

function SH.SetSetting(key, value)
	SH.CFG[key] = value
	local db = ShamanRotationDB
	if type(db) == "table" then
		db.settings = db.settings or {}
		db.settings[key] = value
	end
end

-- ========= Livre de sorts =========
function SH.GetSpellIdx(name)
	local c = SH.spellCache[name]
	if c ~= nil then
		if c == false then return nil end
		return c
	end
	local i, found = 1, nil
	while true do
		local n = GetSpellName(i, "spell")
		if not n then break end
		if n == name then found = i end -- on garde le rang le plus haut (dernier)
		i = i + 1
	end
	SH.spellCache[name] = found or false
	return found
end
function SH.WipeSpellCache() SH.spellCache = {} end
function SH.Known(name) return SH.GetSpellIdx(name) ~= nil end

-- rem = secondes avant lancable (GCD compris) ; real = vraie recharge (GCD exclu : une duree <= 1.55 s n'est pas une recharge) ; known
function SH.CdInfo(name)
	local idx = SH.GetSpellIdx(name)
	if not idx then return 0, 0, false end
	local start, dur = GetSpellCooldown(idx, "spell")
	if not start or start == 0 or not dur or dur == 0 then return 0, 0, true end
	local rem = start + dur - GetTime()
	if rem < 0 then rem = 0 end
	local real = 0
	if dur > 1.55 then real = rem end
	return rem, real, true
end

-- vrai si le sort est mis de cote (refus du serveur, mana manquante)
function SH.Blocked(name)
	local nm = SH.noMana[name]
	if nm ~= nil then
		if UnitMana("player") > nm + 40 then SH.noMana[name] = nil else return true end
	end
	local b = SH.block[name]
	return b ~= nil and b > GetTime()
end

function SH.Ready(name)
	local rem, _, known = SH.CdInfo(name)
	return known and rem <= 0 and not SH.Blocked(name)
end
-- pret avec file d'attente (Nampower) : plus de vraie recharge et le GCD finit dans moins de queueWin s
function SH.ReadyQ(name)
	local rem, real, known = SH.CdInfo(name)
	return known and real <= 0 and rem <= SH.CFG.queueWin and not SH.Blocked(name)
end

function SH.ManaPct()
	local m = UnitManaMax("player")
	if not m or m <= 0 then return 0 end
	return UnitMana("player") / m
end

-- ========= Buffs du joueur =========
function SH.PlayerBuff(spellId)
	local i = 1
	while i <= 32 do
		local tex, stacks, sid = UnitBuff("player", i)
		if not tex then break end
		if sid and tonumber(sid) == spellId then return stacks or 1, tex end
		i = i + 1
	end
	return nil, nil
end

-- ========= Cible =========
function SH.TargetGuid()
	if not UnitExists("target") then return nil end
	local ok, ex, g = pcall(UnitExists, "target")
	if ok and type(g) == "string" then return g end
	return UnitName("target")
end

function SH.HarmTarget()
	if not UnitExists("target") then return false end
	if UnitIsDeadOrGhost("target") then return false end
	if not UnitCanAttack("player", "target") then return false end
	return true
end

-- 1 = a portee, 0 = hors portee, nil = inconnu (on suppose OK)
function SH.InRange(name)
	if type(IsSpellInRange) ~= "function" then return nil end
	if not UnitExists("target") then return nil end
	local ok, res = pcall(IsSpellInRange, name, "target")
	if not ok then return nil end
	if res == 1 or res == true then return 1 end
	if res == 0 or res == false then return 0 end
	return nil
end

function SH.TargetDist()
	if not SH.HarmTarget() then return nil end
	local ok, d = pcall(UnitXP, "distanceBetween", "player", "target")
	if ok and type(d) == "number" then return d end
	return nil
end

-- debuff Flame Shock sur la cible : presence confirmee par l'ID du sort (SuperWoW) ou l'icone du sort du livre
function SH.TargetHasFs()
	local fsTex = nil
	local idx = SH.GetSpellIdx(SH.SPELLS.fs)
	if idx and GetSpellTexture then fsTex = GetSpellTexture(idx, "spell") end
	if not fsTex then return false end
	local i = 1
	while i <= 16 do
		local tex = UnitDebuff("target", i)
		if not tex then break end
		if tex == fsTex then return true end
		i = i + 1
	end
	return false
end

-- temps restant du DoT Flame Shock sur la cible : minuteur depuis NOTRE pose (le jeu ne donne pas la duree des debuffs), verifie par la presence du debuff
function SH.FsRemain()
	if not SH.TargetHasFs() then return 0 end
	local g = SH.TargetGuid()
	if SH.fs.guid and g and SH.fs.guid == g then
		local r = SH.DUR.fs - (GetTime() - SH.fs.at)
		if r < 0 then r = 0 end
		return r
	end
	return SH.DUR.fs * 0.5 -- pose par quelqu'un d'autre ou avant le chargement : duree inconnue, on suppose la moitie
end

-- ========= Incantation ennemie (interruption) =========
function SH.TargetCasting(now)
	local g = SH.TargetGuid()
	if g and SH.castsByGuid[g] and SH.castsByGuid[g] > now + 0.2 then return true end
	return false
end

-- ========= Immunites (apprises, par nom de mob) =========
SH.SCHOOL_OF = { fs = "fire", es = "nature", frs = "frost" }
function SH.Immune(school, name)
	local db = ShamanRotationDB
	if type(db) ~= "table" or type(db.immune) ~= "table" then return false end
	local t = db.immune[school]
	return type(t) == "table" and name ~= nil and t[name] == true
end
function SH.SetImmune(school, name, on)
	local db = ShamanRotationDB
	if type(db) ~= "table" or not name then return end
	db.immune = db.immune or {}
	db.immune[school] = db.immune[school] or {}
	db.immune[school][name] = on and true or nil
end

-- ========= Lancer =========
function SH.Cast(name)
	SH.lastCastName = name
	SH.lastCastAt = GetTime()
	CastSpellByName(name)
end

function SH.TryCast(name, checkRange)
	if not SH.ReadyQ(name) then return false end
	if checkRange and SH.InRange(name) == 0 then return false end
	-- relique du sort pas equipee (mode "spell") : l'echange prend cet appui, le sort part au suivant (wait)
	if SH.RelicGate and SH.RelicGate(name, GetTime()) then return "relic" end
	SH.Dbg("CAST -> " .. name)
	SH.Cast(name)
	return true
end

-- ========= Evenements =========
SH.EV = {}
SH.frame = CreateFrame("Frame", "ShamanRotationFrame", UIParent)
local function reg(ev) SH.frame:RegisterEvent(ev) end
reg("VARIABLES_LOADED"); reg("PLAYER_ENTERING_WORLD"); reg("SPELLS_CHANGED"); reg("LEARNED_SPELL_IN_TAB")
reg("SPELLCAST_START"); reg("SPELLCAST_STOP"); reg("SPELLCAST_FAILED"); reg("SPELLCAST_INTERRUPTED"); reg("UI_ERROR_MESSAGE")
reg("CHAT_MSG_SPELL_SELF_DAMAGE"); reg("PLAYER_DEAD"); reg("UNIT_CASTEVENT")
SH.frame:SetScript("OnEvent", function()
	local f = SH.EV[event]
	if f then f(arg1, arg2, arg3, arg4, arg5) end
end)

SH.EV["VARIABLES_LOADED"] = function()
	if type(ShamanRotationDB) ~= "table" then ShamanRotationDB = {} end
	local db = ShamanRotationDB
	db.settings = db.settings or {}
	db.immune = db.immune or {}
	local k, v
	for k, v in pairs(SH.DEFAULTS) do SH.CFG[k] = v end -- d'abord les defauts : une valeur absente ou invalide de la sauvegarde y revient
	for k, v in pairs(db.settings) do
		if SH.DEFAULTS[k] ~= nil and type(v) == type(SH.DEFAULTS[k]) then SH.CFG[k] = v end
	end
	db.mv = SH.DB_VERSION
end
SH.EV["PLAYER_ENTERING_WORLD"] = function()
	SH.WipeSpellCache()
	if SH.TotemsReset then SH.TotemsReset() end
end
SH.EV["SPELLS_CHANGED"] = function() SH.WipeSpellCache() end
SH.EV["LEARNED_SPELL_IN_TAB"] = function() SH.WipeSpellCache() end
SH.EV["PLAYER_DEAD"] = function()
	if SH.TotemsReset then SH.TotemsReset() end
end

SH.EV["SPELLCAST_START"] = function(name, ms)
	if ms then SH.castUntil = GetTime() + (tonumber(ms) or 0) / 1000 end
end
SH.EV["SPELLCAST_STOP"] = function() SH.castUntil = 0 end
SH.EV["SPELLCAST_FAILED"] = function() SH.castUntil = 0 end
SH.EV["SPELLCAST_INTERRUPTED"] = function() SH.castUntil = 0 end

SH.EV["UI_ERROR_MESSAGE"] = function(msg)
	SH.lastErr = msg
	SH.lastErrAt = GetTime()
	local nm = SH.lastCastName
	if not nm or GetTime() - SH.lastCastAt > 0.5 then return end
	local low = string.lower(tostring(msg))
	if string.find(low, "not enough mana", 1, true) then
		SH.noMana[nm] = UnitMana("player")
	elseif string.find(low, "out of range", 1, true) or string.find(low, "too far", 1, true) or string.find(low, "line of sight", 1, true)
		or string.find(low, "wrong way", 1, true) or string.find(low, "in front", 1, true) then
		SH.block[nm] = GetTime() + 0.6
	end
end

-- "Your Flame Shock failed. X is immune." -> immunite apprise (par ecole), sauvegardee
SH.EV["CHAT_MSG_SPELL_SELF_DAMAGE"] = function(msg)
	if type(msg) ~= "string" then return end
	local _, _, spell, mob = string.find(msg, "^Your (.+) failed%. (.+) is immune%.")
	if spell and mob then
		local k, sp
		for k, sp in pairs(SH.SPELLS) do
			if sp == spell and SH.SCHOOL_OF[k] then
				SH.SetImmune(SH.SCHOOL_OF[k], mob, true)
				SH.Say(mob .. " est immunise (" .. SH.SCHOOL_OF[k] .. ") : retenu, " .. spell .. " ne sera plus lance dessus.")
			end
		end
	end
end

-- SuperWoW : incantations ennemies (pour l'interruption)
SH.EV["UNIT_CASTEVENT"] = function(guid, target, ev, spellId, dur)
	if not guid then return end
	if ev == "START" or ev == "CHANNEL" then
		SH.castsByGuid[guid] = GetTime() + (tonumber(dur) or 0) / 1000
	elseif ev == "CAST" or ev == "FAIL" or ev == "INTERRUPT" then
		SH.castsByGuid[guid] = nil
	end
end

-- ========= Comptage des ennemis (plaques de nom + UnitXP) : meme technique que le guerrier / le paladin =========
SH.enemies = { list = {}, plates = 0, known = false, at = -10 }
function SH.ScanEnemies(now)
	local E = SH.enemies
	if now - E.at < 0.4 then return end
	E.at = now
	local list, plates, known = {}, 0, false
	if WorldFrame then
		local okP, children = pcall(function() return { WorldFrame:GetChildren() } end)
		if okP and children then
			local seen, i = {}, 0
			for i = 1, table.getn(children) do
				local plate = children[i]
				local okT, isBtn = pcall(plate.IsObjectType, plate, "Button")
				local okS, shown = pcall(plate.IsShown, plate)
				if okT and isBtn and okS and shown then
					local okG, guid = pcall(plate.GetName, plate, 1)
					if okG and guid and tostring(guid) ~= "0x0000000000000000" and not seen[tostring(guid)] then
						seen[tostring(guid)] = true
						local hostile = true
						local okR, reaction = pcall(UnitReaction, guid, "player")
						if okR and reaction then hostile = (reaction <= 2) end
						local alive = true
						local okD, dead = pcall(UnitIsDead, guid)
						if okD and dead then alive = false end
						local fighting = true
						if alive and hostile then
							local okC, inCombat = pcall(UnitAffectingCombat, guid)
							if okC then fighting = (inCombat == 1 or inCombat == true) end
						end
						if hostile and alive and fighting then
							plates = plates + 1
							-- Earthquake / Chain Lightning frappent autour de la CIBLE (Spell.dbc : rayon 10 m autour de la cible) : distance a la cible
							local okX, dist = pcall(UnitXP, "distanceBetween", UnitExists("target") and "target" or "player", guid)
							if okX and type(dist) == "number" then
								known = true
								table.insert(list, dist)
							end
						end
					end
				end
			end
		end
	end
	E.list = list
	E.plates = plates
	E.known = known
end

-- nombre d'ennemis en combat dans `range` m ; nil = inconnu (UnitXP ou plaques absents)
function SH.CountEnemies(range, now)
	SH.ScanEnemies(now)
	local E = SH.enemies
	if not E.known then return nil end
	local n, i = 0, 0
	for i = 1, table.getn(E.list) do
		if E.list[i] <= range then n = n + 1 end
	end
	return n
end

SH.autoAoe = false
SH.autoN = nil
SH.autoSince = 0
function SH.AoeOn()
	local m = SH.CFG.aoeMode
	if m == "on" then return true end
	if m == "off" then return false end
	return SH.autoAoe
end

-- horloge 5 fois / s : bascule auto mono <-> AoE avec hysteresis (anti-yoyo)
SH.tickFrame = CreateFrame("Frame", "ShamanRotationTickFrame")
SH.tickAcc = 0
SH.tickFrame:SetScript("OnUpdate", function()
	SH.tickAcc = SH.tickAcc + (arg1 or 0)
	if SH.tickAcc < 0.2 then return end
	SH.tickAcc = 0
	local now = GetTime()
	local CFG = SH.CFG
	if SH.TotemWatch and now - (SH.totemWatchAt or -10) >= 0.5 then
		SH.totemWatchAt = now
		SH.TotemWatch(now)
	end
	-- bouclier elementaire hors combat (1 fois / s suffit)
	if SH.ShieldStep and now - (SH.shieldTick or -10) >= 1 then
		SH.shieldTick = now
		if (not UnitAffectingCombat("player")) and not UnitIsDeadOrGhost("player") and not SH.IsMountedNow() then
			SH.ShieldStep(now, false)
		end
	end
	if CFG.aoeMode ~= "auto" then
		SH.autoAoe = false
		return
	end
	local n = SH.CountEnemies(CFG.aoeRadius, now)
	SH.autoN = n
	if n == nil then return end
	if not SH.autoAoe then
		if n >= CFG.autoAoeMin then
			SH.autoAoe = true
			SH.autoSince = 0
			SH.Say("Auto : " .. n .. " ennemis a moins de " .. CFG.aoeRadius .. " m -> AoE.")
		end
	else
		if n < CFG.autoAoeMin then
			if SH.autoSince == 0 then
				SH.autoSince = now
			elseif now - SH.autoSince >= CFG.autoDelay then
				SH.autoAoe = false
				SH.autoSince = 0
				SH.Say("Auto : plus que " .. n .. " ennemi(s) -> mono.")
			end
		else
			SH.autoSince = 0
		end
	end
end)
