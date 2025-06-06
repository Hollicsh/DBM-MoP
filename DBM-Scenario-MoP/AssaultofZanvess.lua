local mod	= DBM:NewMod("d593", "DBM-Scenario-MoP")
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal"

mod:SetRevision("@file-date-integer@")
mod:SetZone(1050)

mod:RegisterCombat("scenario", 1050)

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 135546 134974",
	"UNIT_DIED",
	"CHAT_MSG_MONSTER_YELL"
)

--Zan'thik Swarmer spawns don't show in logs, so might need to do /chatlog and /yell when they spawn and schedule a loop to get add wave timers for final boss
local warnImpale			= mod:NewSpellAnnounce(133942, 2)

local specWarnGuidedMissle	= mod:NewSpecialWarningPreWarn(135546, nil, 5, nil, nil, 1, 2)--So you can use Force field and not get weapons disabled.

local timerGuidedMissle		= mod:NewCastTimer(5, 135546, nil, nil, nil, 5)--Time until impact
local timerImpaleCD			= mod:NewNextTimer(6, 133942, nil, nil, nil, 3)

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 135546 then
		timerGuidedMissle:Start(args.sourceGUID)
		if self:AntiSpam(2) then--Sometime 2 fire within 1-2 sec of eachother. We want to throttle warning spam but not cast timers so we can time our shield so it's up for both missles
			specWarnGuidedMissle:Show()
			specWarnGuidedMissle:Play("specialsoon")
		end
	elseif args.spellId == 134974 then
		warnImpale:Show()
		timerImpaleCD:Start()
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 67879 then--Commander Tel'vrak
		timerImpaleCD:Cancel()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.TelvrakPull or msg:find(L.TelvrakPull) then
		timerImpaleCD:Start(20)
	end
end
