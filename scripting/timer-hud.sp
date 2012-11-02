#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <timer>

#undef REQUIRE_PLUGIN
#include <timer-physics>
#include <updater>

#define UPDATE_URL "http://dl.dropbox.com/u/16304603/timer/updateinfo-timer-hud.txt"

/**
* Global Variables
*/
new String:g_sCurrentMap[32];
new bool:g_bTimerPhysics = false;

new Handle:g_hCvarShowSpeed = INVALID_HANDLE;
new Handle:g_hCvarShowJumps = INVALID_HANDLE;
new Handle:g_hCvarShowFlashbans = INVALID_HANDLE;
new Handle:g_hCvarShowTime = INVALID_HANDLE;
new Handle:g_hCvarShowDifficulty = INVALID_HANDLE;
new Handle:g_hcvarShowBestTimes = INVALID_HANDLE;
new Handle:g_hCvarShowName = INVALID_HANDLE;
new Handle:g_hCvarTimeByKills = INVALID_HANDLE;
new Handle:g_hCvarJumpsByDeaths = INVALID_HANDLE;
new Handle:g_hCvarThreeAxisSpeed = INVALID_HANDLE;

new bool:g_bShowSpeed = true;
new bool:g_bShowJumps = true;
new bool:g_bShowFlashbangs = false;
new bool:g_bShowTime = true;
new bool:g_bShowDifficulty = true;
new bool:g_bShowBestTimes = true;
new bool:g_bShowName = true;
new bool:g_bTimeByKills = false;
new bool:g_bJumpsByDeaths = false;
new bool:g_bThreeAxisSpeed = false;

public Plugin:myinfo =
{
	name        = "[Timer] HUD",
	author      = "alongub | Glite",
	description = "HUD component for [Timer]",
	version     = PL_VERSION,
	url         = "https://github.com/alongubkin/timer"
};

public OnPluginStart()
{
	g_bTimerPhysics = LibraryExists("timer-physics");
	LoadTranslations("timer.phrases");
	
	g_hCvarShowSpeed = CreateConVar("timer_hud_speed", "1", "Whether or not speed is shown in the HUD.");
	g_hCvarShowJumps = CreateConVar("timer_hud_jumps", "1", "Whether or not jump count is shown in the HUD.");
	g_hCvarShowFlashbans = CreateConVar("timer_hud_flashbangs", "0", "Whether or not flashbang count is shown in the HUD.");
	g_hCvarShowTime = CreateConVar("timer_hud_time", "1", "Whether or not fTime is shown in the HUD.");
	g_hCvarShowDifficulty = CreateConVar("timer_hud_difficulty", "1", "Whether or not difficulty is shown in the HUD, if the timer-physics module is enabled.");
	g_hcvarShowBestTimes = CreateConVar("timer_hud_besttimes", "1", "Whether or not best times for this map is shown in the HUD.");
	g_hCvarShowName = CreateConVar("timer_hud_name", "1", "Whether or not spectating player's name is shown in the HUD.");
	g_hCvarTimeByKills = CreateConVar("timer_frags", "0", "Whether or not players' score should be his current timer.");
	g_hCvarJumpsByDeaths = CreateConVar("timer_jumps_death", "0", "Whether or not players' death count should be their jump count.");
	g_hCvarThreeAxisSpeed = CreateConVar("timer_three_axis_speed", "0", "Whether or not Z-axis will be used in speed calculations.");

	HookConVarChange(g_hCvarShowSpeed, Action_OnSettingsChange);
	HookConVarChange(g_hCvarShowJumps, Action_OnSettingsChange);	
	HookConVarChange(g_hCvarShowFlashbans, Action_OnSettingsChange);
	HookConVarChange(g_hCvarShowTime, Action_OnSettingsChange);
	HookConVarChange(g_hCvarShowDifficulty, Action_OnSettingsChange);	
	HookConVarChange(g_hcvarShowBestTimes, Action_OnSettingsChange);
	HookConVarChange(g_hCvarShowName, Action_OnSettingsChange);
	HookConVarChange(g_hCvarTimeByKills, Action_OnSettingsChange);	
	HookConVarChange(g_hCvarJumpsByDeaths, Action_OnSettingsChange);
	HookConVarChange(g_hCvarThreeAxisSpeed, Action_OnSettingsChange);
	
	AutoExecConfig(true, "timer-hud");
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}	
}

public OnMapStart() 
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	StringToLower(g_sCurrentMap);
	
	PrecacheSound("UI/hint.wav");
	
	CreateTimer(0.25, HUDTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "timer-physics"))
	{
		g_bTimerPhysics = true;
	}
	else if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}	
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "timer-physics"))
	{
		g_bTimerPhysics = false;
	}
}

public Action_OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if (cvar == g_hCvarShowSpeed)
	{
		g_bShowSpeed = bool:StringToInt(newvalue);
	}
	else if (cvar == g_hCvarShowJumps)
	{
		g_bShowJumps = bool:StringToInt(newvalue);
	}
	else if (cvar == g_hCvarShowFlashbans)
	{
		g_bShowFlashbangs = bool:StringToInt(newvalue);
	}
	else if (cvar == g_hCvarShowTime)
	{
		g_bShowTime = bool:StringToInt(newvalue);
	}
	else if (cvar == g_hCvarShowDifficulty)
	{
		g_bShowDifficulty = bool:StringToInt(newvalue);
	}
	else if (cvar == g_hcvarShowBestTimes)
	{
		g_bShowBestTimes = bool:StringToInt(newvalue);	
	}
	else if (cvar == g_hCvarShowName)
	{
		g_bShowName = bool:StringToInt(newvalue);	
	}
	else if (cvar == g_hCvarTimeByKills)
	{
		g_bTimeByKills = bool:StringToInt(newvalue);
	}
	else if (cvar == g_hCvarJumpsByDeaths)
	{
		g_bJumpsByDeaths = bool:StringToInt(newvalue);
	}
	else if (cvar == g_hCvarThreeAxisSpeed)
	{
		g_bThreeAxisSpeed = bool:StringToInt(newvalue);
	}

}

public Action:HUDTimer(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client > 0)
		{
			UpdateHUD(client);
		}
	}

	return Plugin_Continue;
}

UpdateHUD(client)
{
	if (!g_bShowTime && !g_bShowJumps && !g_bShowFlashbangs && !g_bShowSpeed && !g_bShowBestTimes && !g_bShowDifficulty && !g_bShowName)
	{
		return;
	}

	new target = client;
	new t;
	
	if (IsClientObserver(client))
	{
		new observerMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if (observerMode == 4 || observerMode == 3)
		{
			t = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if (IsClientInGame(t) && !IsFakeClient(t))
			{
				target = t;
			}
		}		
	}

	new bool:bEnabled;
	new Float:fTime;
	new iJumps;
	new iFpsMax;
	new iFlashbangs;

	Timer_GetClientTimer(target, bEnabled, fTime, iJumps, iFpsMax, iFlashbangs);
	
	if (bEnabled && (g_bTimeByKills || g_bJumpsByDeaths) && client == target)
	{		
		if (g_bTimeByKills)
		{
			new roundedTime = RoundToFloor(fTime);
			SetEntProp(target, Prop_Data, "m_iFrags", (roundedTime / 60) * 100 + (roundedTime % 60));
		}
		
		if (g_bJumpsByDeaths)
		{
			SetEntProp(target, Prop_Data, "m_iDeaths", iJumps);		
		}
	}
	
	new String:sHintText[256];
	
	if (bEnabled)
	{
		if (g_bShowTime)
		{
			new String:sTimeString[32];
			Timer_SecondsToTime(fTime, sTimeString, sizeof(sTimeString), false);
			
			Format(sHintText, sizeof(sHintText), "%s%t: %s", sHintText, "Time", sTimeString);
		}	
		
		if (g_bShowJumps)
		{
			if (g_bShowTime)
			{
				Format(sHintText, sizeof(sHintText), "%s\n", sHintText);
			}
			
			Format(sHintText, sizeof(sHintText), "%s%t: %d", sHintText, "Jumps", iJumps);
		}
		
		if (g_bShowFlashbangs)
		{
			if (g_bShowTime || g_bShowJumps)
			{
				Format(sHintText, sizeof(sHintText), "%s\n", sHintText);
			}
			
			Format(sHintText, sizeof(sHintText), "%s%t: %d", sHintText, "Flashbangs", iFlashbangs);
		}
	}
	
	if (g_bShowSpeed)
	{
		decl Float:fVelocity[3];
		GetEntPropVector(target, Prop_Data, "m_vecVelocity", fVelocity);	
		
		if (bEnabled && (g_bShowTime || g_bShowJumps || g_bShowFlashbangs))
		{
			Format(sHintText, sizeof(sHintText), "%s\n", sHintText);
		}
		
		Format(sHintText, sizeof(sHintText), "%s%t: %.02f u/s", sHintText, "HUD Speed", g_bThreeAxisSpeed
		? SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0))
		: SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0)));
	}
	
	if (g_bShowBestTimes)
	{
		new Float:fBestTime;
		new iBestJumps;
		new iBestFlashbangs;
		
		Timer_GetBestRound(target, g_sCurrentMap, fBestTime, iBestJumps, iBestFlashbangs);	
		
		new String:sBuffer[32];
		Timer_SecondsToTime(fBestTime, sBuffer, sizeof(sBuffer), false);	
		
		if ((bEnabled && (g_bShowTime || g_bShowJumps || g_bShowFlashbangs)) || g_bShowSpeed)
		{
			Format(sHintText, sizeof(sHintText), "%s\n", sHintText);
		}
		
		Format(sHintText, sizeof(sHintText), "%s%t: %s", sHintText, "HUD Best Times", sBuffer);
	}
	
	if (g_bTimerPhysics && g_bShowDifficulty) 
	{
		decl String:sDifficulty[32];
		Timer_GetDifficultyName(Timer_GetClientDifficulty(target), sDifficulty, sizeof(sDifficulty));
		
		if ((bEnabled && (g_bShowTime || g_bShowJumps || g_bShowFlashbangs)) || g_bShowSpeed || g_bShowBestTimes)
		{
			Format(sHintText, sizeof(sHintText), "%s\n", sHintText);
		}
		
		Format(sHintText, sizeof(sHintText), "%s%t: %s", sHintText, "HUD Difficulty", sDifficulty);
	}
	
	if (g_bShowName && target == t)
	{
		decl String:sName[MAX_NAME_LENGTH];
		GetClientName(target, sName, sizeof(sName));
		
		if ((bEnabled && (g_bShowTime || g_bShowJumps || g_bShowFlashbangs)) || g_bShowSpeed || g_bShowBestTimes || g_bShowDifficulty)
		{
			Format(sHintText, sizeof(sHintText), "%s\n", sHintText);
		}
		
		Format(sHintText, sizeof(sHintText), "%s%t: %s", sHintText, "Player", sName);
	}
	
	PrintHintText(client, sHintText);
	
	StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
}