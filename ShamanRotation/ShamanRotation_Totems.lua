---------------------------------------------------------------
-- ShamanRotation_Totems.lua : combos de totems (caster / melee / AoE / anti-peur / purification), suivi par minuteur
-- Durees et couts : Spell.dbc du serveur (voir DESIGN.md). Aucune API 1.12 ne dit si un totem est detruit : le suivi est un MINUTEUR
-- (remis a zero au changement de zone et a la mort) ; le bouton Totems repose ce qui manque.
-- Lua 5.0 strict.
---------------------------------------------------------------
local SH = ShamanRotation

-- nom -> { element, duree (s) }   (Spell.dbc : SpellDuration)
SH.TOTEM = {
	["Searing Totem"] = { "fire", 55 }, ["Magma Totem"] = { "fire", 20 }, ["Fire Nova Totem"] = { "fire", 5 }, ["Flametongue Totem"] = { "fire", 120 },
	["Mana Spring Totem"] = { "water", 60 }, ["Healing Stream Totem"] = { "water", 60 }, ["Poison Cleansing Totem"] = { "water", 120 },
	["Disease Cleansing Totem"] = { "water", 120 },
	["Tranquil Air Totem"] = { "air", 120 }, ["Windfury Totem"] = { "air", 90 }, ["Grace of Air Totem"] = { "air", 120 },
	["Strength of Earth Totem"] = { "earth", 120 }, ["Tremor Totem"] = { "earth", 120 }, ["Stoneskin Totem"] = { "earth", 120 },
}
SH.TOTEM_ORDER = { "fire", "air", "earth", "water" }

-- presets : element -> totem (texte de l'ami : caster = Mana Spring + Tranquil Air + Searing ; cac = Windfury + Flametongue + Strength of Earth + Mana Spring ;
-- AoE = Magma ou Fire Nova ; anti-peur = Tremor ; anti-poison / anti-maladie = totems de purification)
SH.PRESETS = {
	caster = { fire = "Searing Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem" },
	melee = { fire = "Flametongue Totem", air = "Windfury Totem", earth = "Strength of Earth Totem", water = "Mana Spring Totem" },
	aoe = { fire = "Magma Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem" },
	nova = { fire = "Fire Nova Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem" },
	fear = { fire = "Searing Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem", earth = "Tremor Totem" },
	poison = { fire = "Searing Totem", water = "Poison Cleansing Totem", air = "Tranquil Air Totem" },
	disease = { fire = "Searing Totem", water = "Disease Cleansing Totem", air = "Tranquil Air Totem" },
}
SH.PRESET_LIST = { "caster", "melee", "aoe", "nova", "fear", "poison", "disease", "off" }

SH.totems = {}          -- [element] = { name, at }
SH.totemGuid = {}       -- [element] = { guid, name } : le totem repere sur les plaques de nom (UnitXP)
SH.totemOut = {}        -- [element] = true : totem hors de portee / detruit
SH.totemTry = -10

function SH.TotemsReset() SH.totems = {}; SH.totemGuid = {}; SH.totemOut = {}; SH.totemPend = {} end

-- le totem `name` est-il (suppose) en place ? marge de 3 s avant la fin
function SH.TotemActive(name, now)
	local info = SH.TOTEM[name]
	if not info then return false end
	local t = SH.totems[info[1]]
	if SH.totemOut[info[1]] then return false end -- trop loin de toi (ou detruit) : a reposer
	return t ~= nil and t.name == name and now < t.at + info[2] - 3
end

function SH.PresetTotem(el, aoe)
	local p = SH.PRESETS[SH.CFG.totemPreset]
	if not p then return nil end
	if el == "fire" and aoe and SH.CFG.totemPreset ~= "nova" then return "Magma Totem" end
	return p[el]
end

-- pose le totem ; vrai si l'appui est consomme. multi = on lance plusieurs totems dans le MEME appui (pas de garde de 0,5 s).
-- Serveur (spell_template.StartRecoveryCategory) : chaque element a SA categorie de GCD (feu 105, terre 106, eau 107, air 108) ; les sorts normaux
-- sont en 133. Un totem n'est donc pas retarde par les trois autres (ni par un sort a incantation) : les 4 totems partent dans la meme image.
-- Exceptions relevees : Windfury Totem rang 3 et Fire Nova Totem sont en 133 (GCD normal).
SH.totemPend = {}       -- [element] = { name, at, prev } : poses supposees, a confirmer
function SH.PlaceTotem(name, now, multi)
	if not SH.Known(name) then return false end
	if (not multi) and now - SH.totemTry < 0.5 then return true end -- laisse le jeu repondre
	if SH.CdInfo(name) > 0 or SH.Blocked(name) then return false end
	SH.totemTry = now
	SH.Dbg("TOTEM -> " .. name)
	SH.Cast(name)
	local info = SH.TOTEM[name]
	if info then
		-- pose supposee ; confirmee ensuite si le GCD DU TOTEM a demarre (sinon le lancer a ete refuse : la marque est retiree)
		SH.totemPend[info[1]] = { name = name, at = now, prev = SH.totems[info[1]] }
		SH.totems[info[1]] = { name = name, at = now }
		SH.totemGuid[info[1]] = nil
		SH.totemOut[info[1]] = nil
	end
	return true
end

-- confirme / annule les poses supposees (au moins 0,15 s apres l'appui)
function SH.TotemConfirm(now)
	local el, p
	for el, p in pairs(SH.totemPend) do
		if now - p.at >= 0.15 then
			SH.totemPend[el] = nil
			if now - p.at <= 0.6 then -- plus tard : le GCD est peut-etre deja fini, on garde la pose supposee
				local idx = SH.GetSpellIdx(p.name)
				local start = 0
				if idx then
					local s = GetSpellCooldown(idx, "spell")
					start = s or 0
				end
				if start < p.at - 0.1 then
					SH.totems[el] = p.prev -- aucun GCD demarre apres notre appui : lancer refuse
					SH.totemTry = -10
				end
			end
		end
	end
end

-- une pose vient d'etre tentee (moins de 0,45 s) : en attente de confirmation
function SH.TotemPendingAny(now)
	local el, p
	for el, p in pairs(SH.totemPend) do
		if now - p.at < 0.45 then return true end
	end
	return false
end

-- rotation : seul le totem de feu (Searing / Magma), pendant le combat. Sa categorie de GCD (105) n'est pas celle des sorts (133) : le totem part
-- SANS prendre l'appui, la rotation lance son sort normalement dans la meme image. Retourne toujours faux (l'appui n'est pas consomme).
function SH.TotemFireStep(now, aoe)
	if now < SH.castUntil then return false end -- un sort a incantation est en cours : un instantane ne peut pas partir (il attend la fin)
	local want = SH.PresetTotem("fire", aoe)
	if not want or SH.TotemActive(want, now) or SH.totemPend.fire then return false end
	if SH.PlaceTotem(want, now, true) then
		SH.Decide(now, "Totem : " .. want .. " (GCD de son element : la rotation continue)")
	end
	return false
end
-- bouton Totems : pose le premier totem MANQUANT du preset (feu, air, terre, eau), un par appui (1 GCD chacun)
function ShamanRotation_Totems()
	local now = GetTime()
	SH.TotemConfirm(now)
	if SH.CFG.totemPreset == "off" then
		SH.Print("Totems : preset coupe (/shamrot totems caster|melee|aoe|nova|fear|poison|disease).")
		return
	end
	local i, el, want
	for i = 1, table.getn(SH.TOTEM_ORDER) do
		el = SH.TOTEM_ORDER[i]
		want = SH.PresetTotem(el, SH.AoeOn())
		if want and not SH.TotemActive(want, now) then
			if SH.PlaceTotem(want, now) then return end
		end
	end
	SH.Print("Totems en place (preset " .. SH.CFG.totemPreset .. ").")
end

function SH.TotemStatus()
	local now = GetTime()
	local txt, i, el = "", 0, nil
	for i = 1, table.getn(SH.TOTEM_ORDER) do
		el = SH.TOTEM_ORDER[i]
		local want = SH.PresetTotem(el, SH.AoeOn())
		local t = SH.totems[el]
		local left = nil
		if t and SH.TOTEM[t.name] then left = t.at + SH.TOTEM[t.name][2] - now end
		txt = txt .. "  " .. el .. " : " .. (want or "-") .. ((t and left and left > 0) and (" (en place " .. string.format("%.0f", left) .. " s)") or (want and " (MANQUANT)" or "")) .. "\n"
	end
	return txt
end

-- ===================================================================
-- Tous les totems du combo d'UN SEUL appui : les 4 partent dans la meme image (une categorie de GCD par element).
-- Ceux qui seraient refuses (meme categorie, mana, GCD) sont retentes automatiquement, un par un, jusqu'a 15 s.
-- ===================================================================
SH.totemSeq = nil

function ShamanRotation_TotemsAll()
	if SH.CFG.totemPreset == "off" then
		SH.Print("Totems : preset coupe (/shamrot totems caster|melee|aoe|nova|fear|poison|disease).")
		return
	end
	SH.totemSeq = { at = GetTime(), skipped = {} }
	SH.Print("Pose des totems du combo " .. SH.CFG.totemPreset .. "...")
	SH.TotemSeqStep(GetTime()) -- tout de suite : les totems prets partent dans cette image
end

-- une etape : lance tous les totems manquants qui sont prets ; vrai tant que la sequence continue
function SH.TotemSeqStep(now)
	local q = SH.totemSeq
	if not q then return false end
	if UnitIsDeadOrGhost("player") or now - q.at > 15 then
		SH.totemSeq = nil
		return false
	end
	SH.TotemConfirm(now)
	if now < SH.castUntil then return true end         -- incantation en cours
	local i, el, want
	local waiting = false
	for i = 1, table.getn(SH.TOTEM_ORDER) do
		el = SH.TOTEM_ORDER[i]
		want = SH.PresetTotem(el, SH.AoeOn())
		if want and not q.skipped[el] and not SH.TotemActive(want, now) then
			if not SH.Known(want) then
				q.skipped[el] = true                    -- totem non appris : on passe
				SH.Say(want .. " : non appris, ignore.")
			elseif SH.Blocked(want) then
				SH.Print("Pose des totems interrompue : pas assez de mana pour " .. want .. ".")
				SH.totemSeq = nil
				return false
			elseif SH.CdInfo(want) > 0 then
				waiting = true                          -- sa categorie de GCD est occupee : on retente
			else
				SH.PlaceTotem(want, now, true)          -- multi : pas de garde, les autres partent dans la meme image
			end
		end
	end
	if waiting or next(SH.totemPend) ~= nil then return true end
	SH.totemSeq = nil
	SH.Print("Totems en place (combo " .. SH.CFG.totemPreset .. ").")
	return false
end

SH.totemSeqFrame = CreateFrame("Frame", "ShamanRotationTotemSeqFrame")
SH.totemSeqAcc = 0
SH.totemSeqFrame:SetScript("OnUpdate", function()
	if not SH.totemSeq then return end
	SH.totemSeqAcc = SH.totemSeqAcc + (arg1 or 0)
	if SH.totemSeqAcc < 0.05 then return end
	SH.totemSeqAcc = 0
	SH.TotemSeqStep(GetTime())
end)

-- ===================================================================
-- Surveillance : ton totem est-il trop loin (ou detruit) ? Rayon des auras de buff = 30 m (Spell.dbc : Mana Spring, Healing Stream, Strength of Earth, Grace of Air,
-- Tranquil Air, Stoneskin, Flametongue). Windfury, Tremor, purification, Searing, Magma : rayon non verifie, pas surveilles.
-- Methode : juste apres la pose, le totem apparait sur les plaques de nom (GUID) a moins de 8 m de toi : on retient ce GUID, puis UnitXP donne la distance
-- et UnitExists / UnitIsDead disent s'il est detruit. Demande UnitXP + SuperWoW + plaques de nom AMICALES visibles ; sinon on reste sur le minuteur.
-- ===================================================================
SH.TOTEM_RANGE = { ["Mana Spring Totem"] = true, ["Healing Stream Totem"] = true, ["Strength of Earth Totem"] = true, ["Grace of Air Totem"] = true,
	["Tranquil Air Totem"] = true, ["Stoneskin Totem"] = true, ["Flametongue Totem"] = true }
SH.totemWatchWarned = false
SH.totemRedropAt = -10

-- GUIDs des plaques de nom visibles : liste de { guid, name }
function SH.PlateList()
	local out = {}
	if not WorldFrame then return out end
	local okP, children = pcall(function() return { WorldFrame:GetChildren() } end)
	if not (okP and children) then return out end
	local i
	for i = 1, table.getn(children) do
		local plate = children[i]
		local okT, isBtn = pcall(plate.IsObjectType, plate, "Button")
		local okS, shown = pcall(plate.IsShown, plate)
		if okT and isBtn and okS and shown then
			local okG, guid = pcall(plate.GetName, plate, 1)
			if okG and guid and tostring(guid) ~= "0x0000000000000000" then
				local okN, nm = pcall(UnitName, guid)
				if okN and nm then table.insert(out, { guid = guid, name = nm }) end
			end
		end
	end
	return out
end

function SH.DistTo(guid)
	local ok, d = pcall(UnitXP, "distanceBetween", "player", guid)
	if ok and type(d) == "number" then return d end
	return nil
end

function SH.TotemWatch(now)
	local CFG = SH.CFG
	if not CFG.totemRedrop or UnitIsDeadOrGhost("player") then return end
	local el, t
	-- 1. reperer le GUID des totems poses depuis moins de 5 s
	for el, t in pairs(SH.totems) do
		if SH.TOTEM_RANGE[t.name] and not SH.totemGuid[el] and now - t.at >= 0.3 and now - t.at <= 5 then
			local plates = SH.PlateList()
			local k, best, bestD = 0, nil, 9
			for k = 1, table.getn(plates) do
				if string.find(plates[k].name, t.name, 1, true) then
					local d = SH.DistTo(plates[k].guid)
					if d and d < bestD then best = plates[k]; bestD = d end
				end
			end
			if best then SH.totemGuid[el] = { guid = best.guid, name = t.name } end
		end
	end
	-- 2. surveiller ceux qu'on suit : detruit ? trop loin ?
	local anyOut = false
	for el, t in pairs(SH.totemGuid) do
		local gone = false
		local okE, ex = pcall(UnitExists, t.guid)
		if (not okE) or not ex then gone = true end
		if not gone then
			local okD, dead = pcall(UnitIsDead, t.guid)
			if okD and dead then gone = true end
		end
		if gone then
			SH.totemGuid[el] = nil
			SH.totems[el] = nil
			SH.totemOut[el] = true
			SH.Say(t.name .. " detruit : a reposer.")
			anyOut = true
		else
			local d = SH.DistTo(t.guid)
			if d and d > CFG.totemRange then
				if not SH.totemOut[el] then SH.Say(t.name .. " trop loin (" .. string.format("%.0f", d) .. " m) : a reposer.") end
				SH.totemOut[el] = true
				anyOut = true
			end
		end
	end
	if not anyOut then
		for el in pairs(SH.totemOut) do
			if SH.totems[el] and SH.totemGuid[el] then
				-- reviens a portee : le totem compte a nouveau
				local d = SH.DistTo(SH.totemGuid[el].guid)
				if d and d <= CFG.totemRange then SH.totemOut[el] = nil end
			end
		end
	end
	-- 3. repose automatique
	if next(SH.totemOut) == nil then return end
	if SH.totemSeq or now - SH.totemRedropAt < 4 then return end
	if SH.CFG.totemPreset == "off" or SH.IsMountedNow and SH.IsMountedNow() then return end
	if UnitAffectingCombat("player") and not CFG.totemRedropCombat then return end
	if now < SH.castUntil then return end
	SH.totemRedropAt = now
	ShamanRotation_TotemsAll()
end