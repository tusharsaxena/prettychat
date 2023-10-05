local frame = CreateFrame("FRAME", "LootLiteFrame");
frame:RegisterEvent('PLAYER_ENTERING_WORLD');

local function eventHandler(self, event, ...)
	-- Loot
	BATTLE_PET_LOOT_RECEIVED="|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff ";
	LOOT_CURRENCY_REFUND="|cffff0000Loot|cffffffff | |cffe06666Refund|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_DISENCHANT_CREDIT="|cffff0000Loot|cffffffff | |cff8e7cc3Disenchant|cffffffff | |cfff6b26b%s|cffffffff ";
	LOOT_ITEM="|cffff0000Loot|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_BONUS_ROLL="|cffff0000Loot|cffffffff | |cff76a5afBonus|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_BONUS_ROLL_MULTIPLE="|cffff0000Loot|cffffffff | |cff76a5afBonus|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_BONUS_ROLL_SELF="|cffff0000Loot|cffffffff | |cff76a5afBonus|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE="|cffff0000Loot|cffffffff | |cff76a5afBonus|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_CREATED_SELF="|cffff0000Loot|cffffffff | |cff93c47dCreate|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_CREATED_SELF_MULTIPLE="|cffff0000Loot|cffffffff | |cff93c47dCreate|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_MULTIPLE="|cffff0000Loot|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_PUSHED="|cffff0000Loot|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_PUSHED_MULTIPLE="|cffff0000Loot|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_PUSHED_SELF="|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_PUSHED_SELF="|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_PUSHED_SELF_MULTIPLE="|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_PUSHED_SELF_MULTIPLE="|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_REFUND="|cffff0000Loot|cffffffff | |cffe06666Refund|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_REFUND_MULTIPLE="|cffff0000Loot|cffffffff | |cffe06666Refund|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_SELF="|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_SELF_MULTIPLE="|cffff0000Loot|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	-- Currency
	CURRENCY_GAINED="|cffff9900Currency|cffffffff | |cffffffff+ %s|cffffffff";
	CURRENCY_GAINED_MULTIPLE="|cffff9900Currency|cffffffff | |cffffffff+ %s x%d|cffffffff";
	CURRENCY_GAINED_MULTIPLE_BONUS="|cffff9900Currency|cffffffff | |cff76a5afBonus Objective|cffffffff | |cffffffff+ %s x%d|cffffffff";
	CURRENCY_LOST_FROM_DEATH="|cffff9900Currency|cffffffff | |cffe06666Lost|cffffffff | |cffffffff- %s x%d|cffffffff";
	-- Money
	LOOT_MONEY="|cffffff00Money|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_MONEY_REFUND="|cffffff00Money|cffffffff | |cffe06666Refund|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_MONEY_SPLIT="|cffffff00Money|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	YOU_LOOT_MONEY="|cffffff00Money|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	YOU_LOOT_MONEY_GUILD="|cffffff00Money|cffffffff | |cff93c47dGuild Bank|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s (+ %s guild bank)|cffffffff";
	YOU_LOOT_MONEY_MOD="|cffffff00Money|cffffffff | |cff93c47dYou|cffffffff | |cffffffff%s (+ %s)|cffffffff";
	GENERIC_MONEY_GAINED_RECEIPT="|cffffff00Money|cffffffff | |cffccccccGeneric|cffffffff | |cffffffff+ %s|cffffffff";
	-- Faction
	FACTION_STANDING_CHANGED="|cff00ff00Rep|cffffffff | |cff76a5afStanding|cffffffff | |cffffffff%s - %s|cffffffff";
	FACTION_STANDING_CHANGED_GUILD="|cff00ff00Rep|cffffffff | |cff76a5afStanding|cffffffff | |cffffffff%s - Guild|cffffffff";
	FACTION_STANDING_CHANGED_GUILDNAME="|cff00ff00Rep|cffffffff | |cff76a5afStanding|cffffffff | |cffffffff%s - %s|cffffffff";
	FACTION_STANDING_DECREASED="|cff00ff00Rep|cffffffff | |cff76a5af%s|cffffffff | |cffffffff- %d|cffffffff";
	FACTION_STANDING_DECREASED_GENERIC="|cff00ff00Rep|cffffffff | |cff76a5af%s|cffffffff | |cffffffff- %d|cffffffff";
	FACTION_STANDING_INCREASED="|cff00ff00Rep|cffffffff | |cff76a5af%s|cffffffff | |cffffffff+ %d|cffffffff";
	FACTION_STANDING_INCREASED_ACH_BONUS="|cff00ff00Rep|cffffffff | |cff76a5af%s|cffffffff | |cffffffff+ %d (+ %.1f bonus)|cffffffff";
	FACTION_STANDING_INCREASED_ACH_PART="|cff00ff00Rep|cffffffff | |cffcccccc:|cffffffff | |cffffffff(+ %.1f bonus)|cffffffff";
	FACTION_STANDING_INCREASED_BONUS="|cff00ff00Rep|cffffffff | |cff76a5af%s|cffffffff | |cffffffff+ %d (+ %.1f Recruit A Friend bonus)|cffffffff";
	FACTION_STANDING_INCREASED_DOUBLE_BONUS="|cff00ff00Rep|cffffffff | |cff76a5af%s|cffffffff | |cffffffff+ %d (+ %.1f Recruit A Friend bonus) (+ %.1f bonus)|cffffffff";
	FACTION_STANDING_INCREASED_GENERIC="|cff00ff00Rep|cffffffff | |cff76a5af%s|cffffffff ";
	FACTION_STANDING_INCREASED_GUARDIAN="|cff00ff00Rep|cffffffff | |cffccccccGuardian|cffffffff | |cffffffff+ %d|cffffffff";
	FACTION_STANDING_INCREASED_REFER_PART="|cff00ff00Rep|cffffffff | |cffccccccRAF|cffffffff | |cffffffff(+ %.1f Recruit A Friend bonus)|cffffffff";
	FACTION_STANDING_INCREASED_REST_PART="|cff00ff00Rep|cffffffff | |cffccccccRested|cffffffff | |cffffffff(+ %.1f Rested bonus)|cffffffff";
	-- Experience
	COMBATLOG_XPGAIN_EXHAUSTION1="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s bonus)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION1_GROUP="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s bonus, + %d group bonus)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION1_RAID="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s bonus, - %d raid penalty)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION2="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s bonus)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION2_GROUP="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s bonus, + %d group bonus)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION2_RAID="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s bonus, - %d raid penalty)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION4="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s penalty)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION4_GROUP="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s penalty, + %d group bonus)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION4_RAID="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s penalty, - %d raid penalty)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION5="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s penalty)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION5_GROUP="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s penalty, + %d group bonus)|cffffffff";
	COMBATLOG_XPGAIN_EXHAUSTION5_RAID="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s exp %s penalty, - %d raid penalty)|cffffffff";
	COMBATLOG_XPGAIN_FIRSTPERSON="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d|cffffffff";
	COMBATLOG_XPGAIN_FIRSTPERSON_GROUP="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (+ %d group bonus)|cffffffff";
	COMBATLOG_XPGAIN_FIRSTPERSON_RAID="|cff00ffffXP|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (- %d raid penalty)|cffffffff";
	COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED="|cff00ffffXP|cffffffff | |cfff6b26bUnknown|cffffffff | |cffffffff+ %d|cffffffff";
	COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_GROUP="|cff00ffffXP|cffffffff | |cfff6b26bUnknown|cffffffff | |cffffffff+ %d (+ %d group bonus)|cffffffff";
	COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_RAID="|cff00ffffXP|cffffffff | |cfff6b26bUnknown|cffffffff | |cffffffff+ %d (- %d raid penalty)|cffffffff";
	COMBATLOG_XPGAIN_QUEST="|cff00ffffXP|cffffffff | |cfff6b26bUnknown|cffffffff | |cffffffff+ %d (%s exp %s bonus)|cffffffff";
	COMBATLOG_XPLOSS_FIRSTPERSON_UNNAMED="|cff00ffffXP|cffffffff | |cfff6b26bUnknown|cffffffff | |cffffffff- %d|cffffffff";
	-- Honor
	COMBATLOG_DISHONORGAIN="|cff4a86e8Honor|cffffffff | |cffe06666:|cffffffff | |cffffffffDishonorable Kill|cffffffff";
	COMBATLOG_HONORAWARD="|cff4a86e8Honor|cffffffff | |cffffffff+ %d|cffffffff";
	COMBATLOG_HONORGAIN="|cff4a86e8Honor|cffffffff | |cfff6b26b%s (%s)|cffffffff | |cffffffff+ %d|cffffffff";
	COMBATLOG_HONORGAIN_EXHAUSTION1="|cff4a86e8Honor|cffffffff | |cfff6b26b%s (%s)|cffffffff | |cffffffff+ %d (%s %s bonus)|cffffffff";
	COMBATLOG_HONORGAIN_NO_RANK="|cff4a86e8Honor|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d|cffffffff";
	COMBATLOG_HONORGAIN_NO_RANK_EXHAUSTION1="|cff4a86e8Honor|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %d (%s %s bonus)|cffffffff";
	-- Tradeskill
	CREATED_ITEM="|cffff00ffTradeskill|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s|cffffffff";
	CREATED_ITEM_MULTIPLE="|cffff00ffTradeskill|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s x%d|cffffffff";
	LOOT_ITEM_CREATED_SELF="|cffff00ffTradeskill|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	LOOT_ITEM_CREATED_SELF_MULTIPLE="|cffff00ffTradeskill|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s x%d|cffffffff";
	TRADESKILL_LOG_FIRSTPERSON="|cffff00ffTradeskill|cffffffff | |cff93c47dYou|cffffffff | |cffffffff+ %s|cffffffff";
	TRADESKILL_LOG_THIRDPERSON="|cffff00ffTradeskill|cffffffff | |cfff6b26b%s|cffffffff | |cffffffff+ %s|cffffffff";
	OPEN_LOCK_OTHER="|cffff00ff%s|cffffffff | |cfff6b26b%s|cffffffff ";
	OPEN_LOCK_SELF="|cffff00ff%s|cffffffff | |cff93c47dYou|cffffffff ";
	-- Misc
	ERR_QUEST_REWARD_EXP_I="|cffffffffMisc|cffffffff | |cffccccccExp|cffffffff | |cffffffff+ %d|cffffffff";
	ERR_QUEST_REWARD_MONEY_S="|cffffffffMisc|cffffffff | |cffccccccMoney Received|cffffffff | |cffffffff+ %s|cffffffff";
	ERR_ZONE_EXPLORED_XP="|cffffffffDiscovery XP|cffffffff | |cffcccccc%s|cffffffff | |cffffffff+ %d|cffffffff";
end

frame:SetScript("OnEvent", eventHandler);
