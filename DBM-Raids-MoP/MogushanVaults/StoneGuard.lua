local mod	= DBM:NewMod(679, "DBM-Raids-MoP", 5, 317)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("@file-date-integer@")
mod:SetCreatureID(60051, 60043, 59915, 60047)--Cobalt: 60051, Jade: 60043, Jasper: 59915, Amethyst: 60047
mod:SetEncounterID(1395)
mod:SetZone(1008)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 115840 115842 115843 115844 116223 116235 130774",
	"SPELL_AURA_APPLIED 130395 130774",
	"SPELL_AURA_REMOVED 130395",
	"RAID_BOSS_EMOTE",
	"UNIT_SPELLCAST_SUCCEEDED boss1 boss2 boss3 boss4",
	"UNIT_DIED"
)

local Jade = DBM:EJ_GetSectionInfo(5773)
local Jasper = DBM:EJ_GetSectionInfo(5774)
local Cobalt = DBM:EJ_GetSectionInfo(5771)
local Amethyst = DBM:EJ_GetSectionInfo(5691)
--General
local warnPowerDown					= mod:NewSpellAnnounce(116529, 4, nil, "-Tank")

local specWarnOverloadSoon			= mod:NewSpecialWarning("SpecWarnOverloadSoon", nil, nil, nil, 2)

local timerPetrification			= mod:NewNextTimer(76, 125091, nil, nil, nil, 2)
local berserkTimer					= mod:NewBerserkTimer(420)
mod:AddInfoFrameOption(nil)
--Cobalt
mod:AddTimerLine(Cobalt)
local warnCobaltOverload			= mod:NewSpellAnnounce(115840, 4)
local warnCobaltMine				= mod:NewSpellAnnounce(129424, 4)

local timerCobaltMineCD				= mod:NewNextTimer(8.5, 129424, nil, nil, nil, 3)
--Jade
mod:AddTimerLine(Jade)
local warnJadeOverload				= mod:NewSpellAnnounce(115842, 4)
local warnJadeShards				= mod:NewSpellAnnounce(116223, 3, nil, false)

local timerJadeShardsCD				= mod:NewCDTimer(9, 116223, nil, false, nil, 2)--9~12
--Amethyst
mod:AddTimerLine(Amethyst)
local warnAmethystOverload			= mod:NewSpellAnnounce(115844, 4)
local warnAmethystPool				= mod:NewTargetAnnounce(130774, 3, nil, false)

local specWarnAmethystPool			= mod:NewSpecialWarningGTFO(130774, nil, nil, nil, 1, 8)

local timerAmethystPoolCD			= mod:NewCDTimer(6, 130774, nil, false, nil, 3)
--Jasper
mod:AddTimerLine(Jasper)
local warnJasperOverload			= mod:NewSpellAnnounce(115843, 4)

local warnJasperChains				= mod:NewTargetNoFilterAnnounce(130395, 4)

local specWarnJasperChains			= mod:NewSpecialWarningMoveTo(130395, nil, nil, nil, 1, 2)
local specWarnBreakJasperChains		= mod:NewSpecialWarning("specWarnBreakJasperChains", nil, nil, nil, 1, 2, nil, nil, 130395)
local yellJasperChains				= mod:NewYell(130395, nil, false)

local timerJasperChainsCD			= mod:NewCDTimer(12, 130395, nil, nil, nil, 3)--11-13

local Overload = {
	["Cobalt"] = DBM:GetSpellName(115840),
	["Jade"] = DBM:GetSpellName(115842),
	["Jasper"] = DBM:GetSpellName(115843),
	["Amethyst"] = DBM:GetSpellName(115844)
}
mod.vb.expectedBosses = 3
mod.vb.activePetrification = "None"
local playerHasChains = false
local jasperChainsTargets = {}
local amethystPoolTargets = {}

local function warnAmethystPoolTargets()
	warnAmethystPool:Show(table.concat(amethystPoolTargets, "<, >"))
	timerAmethystPoolCD:Start()
	table.wipe(amethystPoolTargets)
end

local function poolTargetCheck(name)
	if #amethystPoolTargets > 0 and name then
		for i = 1, #amethystPoolTargets do
			if amethystPoolTargets[i] == name then
				return false
			end
		end
	end
	return true
end

local function warnJasperChainsTargets()
	warnJasperChains:Show(table.concat(jasperChainsTargets, "<, >"))
	table.wipe(jasperChainsTargets)
end

local updateInfoFrame
do
	local lines = {}
	local sortedLines = {}
	local function addLine(key, value)
		-- sort by insertion order
		lines[key] = value
		sortedLines[#sortedLines + 1] = key
	end
	updateInfoFrame = function()
		table.wipe(lines)
		table.wipe(sortedLines)
		for i = 1, 5 do
			if UnitExists("boss"..i) then
				addLine(UnitName("boss"..i), UnitPower("boss"..i))
			end
		end
		addLine(UnitName("player"), UnitPower("player", ALTERNATE_POWER_INDEX))

		return lines, sortedLines
	end
end

function mod:ThreeBossStart(delay)
	for i = 1, 5 do
		local id = self:GetUnitCreatureId("boss"..i)
		if id == 60051 then -- cobalt
			if self:IsDifficulty("lfr25") then
				timerCobaltMineCD:Start(10.5-delay-1)
			else
				timerCobaltMineCD:Start(-delay-1)
			end
		elseif id == 60043 then -- jade
			timerJadeShardsCD:Start(-delay-1)
		elseif id == 59915 then -- jasper
			timerJasperChainsCD:Start(-delay-1)
		elseif id == 60047 then -- amethyst
			timerAmethystPoolCD:Start(-delay-1)
		end
	end
end

function mod:OnCombatStart(delay)
	self.vb.activePetrification = "None"
	playerHasChains = false
	table.wipe(jasperChainsTargets)
	table.wipe(amethystPoolTargets)
	if self:IsHeroic() then
		berserkTimer:Start(-delay)
	else
		berserkTimer:Start(485-delay)
	end
	if self:IsDifficulty("normal25", "heroic25") then
		timerCobaltMineCD:Start(-delay)
		timerJadeShardsCD:Start(-delay)
		timerJasperChainsCD:Start(-delay)
		timerAmethystPoolCD:Start(-delay)
		self.vb.expectedBosses = 4--Only fight all 4 at once on 25man (excluding LFR)
	else
		self.vb.expectedBosses = 3--Else you get a random set of 3/4
		self:ScheduleMethod(1, "ThreeBossStart", delay)
	end
end

function mod:OnCombatEnd()
	if self.Options.InfoFrame then
		DBM.InfoFrame:Hide()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 115840 then -- Cobalt
		warnCobaltOverload:Show()
		if self.vb.activePetrification == "Cobalt" then
			timerPetrification:Cancel()
		end
		self.vb.activePetrification = "None"
	elseif spellId == 115842 then -- Jade
		warnJadeOverload:Show()
		if self.vb.activePetrification == "Jade" then
			timerPetrification:Cancel()
		end
		self.vb.activePetrification = "None"
	elseif spellId == 115843 then -- Jasper
		warnJasperOverload:Show()
		if self.vb.activePetrification == "Jasper" then
			timerPetrification:Cancel()
		end
		self.vb.activePetrification = "None"
	elseif spellId == 115844 then -- Amethyst
		warnAmethystOverload:Show()
		if self.vb.activePetrification == "Amethyst" then
			timerPetrification:Cancel()
		end
		self.vb.activePetrification = "None"
	elseif spellId == 116223 then
		warnJadeShards:Show()
		timerJadeShardsCD:Start()
	elseif args:IsSpellID(116235, 130774) then--is 116235 still used? my logs show ONLY 130774 being used.
		if poolTargetCheck(args.destName) then--antispam can not prevent spam, try another way.
			amethystPoolTargets[#amethystPoolTargets + 1] = args.destName
			self:Unschedule(warnAmethystPoolTargets)
			self:Schedule(0.5, warnAmethystPoolTargets)
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 130395 then
		jasperChainsTargets[#jasperChainsTargets + 1] = args.destName
		if self:AntiSpam(3, 1) then
			timerJasperChainsCD:Start()
		end
		self:Unschedule(warnJasperChainsTargets)
		self:Schedule(0.3, warnJasperChainsTargets)
		if self.vb.activePetrification ~= "Jasper" then
			if #jasperChainsTargets == 2 then
				if jasperChainsTargets[1] == UnitName("player") then
					specWarnJasperChains:Show(jasperChainsTargets[2])
					specWarnJasperChains:Play("gathershare")
				elseif jasperChainsTargets[2] == UnitName("player") then
					specWarnJasperChains:Show(jasperChainsTargets[1])
					specWarnJasperChains:Play("gathershare")
				end
			end
		end
		if args:IsPlayer() then
			playerHasChains = true
			if not self:IsDifficulty("lfr25") then
				yellJasperChains:Yell()
			end
			--Figure out which one is Jasper
			for i = 1, 5 do
				local unitId = "boss"..i
				local cid = self:GetUnitCreatureId(unitId)
				if cid == 59915 then--Right unit ID
					if UnitPower(unitId) <= 50 and self.vb.activePetrification == "Jasper" then--Make sure his energy isn't already high, otherwise breaking chains when jasper will only be active for a few seconds is bad
						specWarnBreakJasperChains:Show()
						specWarnBreakJasperChains:Play("breakchain")
					end
					break
				end
			end
		end
	elseif spellId == 130774 and args:IsPlayer() then
		specWarnAmethystPool:Show(args.spellName)
		specWarnAmethystPool:Play("watchfeet")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 130395 and args:IsPlayer() then
		playerHasChains = false
	end
end

function mod:RAID_BOSS_EMOTE(msg, boss)
	if msg == L.Overload or msg:find(L.Overload) then--Cast trigger is an emote 7 seconds before, CLEU only shows explosion. Just like nefs electrocute
		self:SendSync("Overload", boss == Cobalt and "Cobalt" or boss == Jade and "Jade" or boss == Jasper and "Jasper" or boss == Amethyst and "Amethyst" or "Unknown")
	elseif msg:find("spell:116529") then
		warnPowerDown:Show()
	end
end

function mod:OnSync(msg, boss)
	-- if boss aprats from 10 yard and get Solid Stone, power no longer increase. If this, overlord not casts. So timer can be confusing. Disabled for find better way.
	if msg == "Overload" and boss ~= self.vb.activePetrification then
		specWarnOverloadSoon:Show(Overload[boss])
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 60051 or cid == 60043 or cid == 59915 or cid == 60047 then--Fight is over.
		self.vb.expectedBosses = self.vb.expectedBosses - 1
		if self.vb.expectedBosses == 0 then
			DBM:EndCombat(self)
		end
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(uId, _, spellId)
	if spellId == 115852 then
		self.vb.activePetrification = "Cobalt"
		timerPetrification:Start()
		if self.Options.InfoFrame then
			DBM.InfoFrame:SetHeader(Cobalt)
			DBM.InfoFrame:Show(5, "function", updateInfoFrame)
		end
	elseif spellId == 116006 then
		self.vb.activePetrification = "Jade"
		timerPetrification:Start()
		if self.Options.InfoFrame then
			DBM.InfoFrame:SetHeader(Jade)
			DBM.InfoFrame:Show(5, "function", updateInfoFrame)
		end
	elseif spellId == 116036 then
		self.vb.activePetrification = "Jasper"
		timerPetrification:Start()
		if self.Options.InfoFrame then
			DBM.InfoFrame:SetHeader(Jasper)
			DBM.InfoFrame:Show(5, "function", updateInfoFrame)
		end
		if playerHasChains then
			if uId and UnitPower(uId) <= 50 then--Make sure his energy isn't already high, otherwise breaking chains when jasper will only be active for a few seconds is bad
				specWarnBreakJasperChains:Show()
				specWarnBreakJasperChains:Play("breakchain")
			end
		end
	elseif spellId == 116057 then
		self.vb.activePetrification = "Amethyst"
		timerPetrification:Start()
		if self.Options.InfoFrame then
			DBM.InfoFrame:SetHeader(Amethyst)
			DBM.InfoFrame:Show(5, "function", updateInfoFrame)
		end
	elseif spellId == 129424 then
		warnCobaltMine:Show()
		if self:IsDifficulty("lfr25") then
			timerCobaltMineCD:Start(10.5)
		else
			timerCobaltMineCD:Start()
		end
	end
end
