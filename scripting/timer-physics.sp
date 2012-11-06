#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <timer>
#include <timer-logging>
#include <timer-physics>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL "http://dl.dropbox.com/u/16304603/timer/updateinfo-timer-physics.txt"

new Handle:g_cookie;

new Handle:g_hCvarJoinTeamDifficulty = INVALID_HANDLE;
new bool:g_bJoinTeamDifficulty = false;

new g_difficulties[32][PhysicsDifficulty];
new g_difficultyCount = 0;
new g_iDefaultDifficulty = 0;

new Float:g_fStamina[MAXPLAYERS+1];
new g_iClientDifficulty[MAXPLAYERS+1];

new bool:g_bPreventAD[MAXPLAYERS+1];
new bool:g_bPreventBack[MAXPLAYERS+1];
new bool:g_bPreventForward[MAXPLAYERS+1];
new bool:g_bAuto[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name        = "[Timer] Physics",
	author      = "alongub | Glite",
	description = "Physics component for [Timer]",
	version     = PL_VERSION,
	url         = "https://github.com/alongubkin/timer"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("timer-physics");
	
	CreateNative("Timer_GetClientDifficulty", Native_GetClientDifficulty);
	CreateNative("Timer_GetDifficultyName", Native_GetDifficultyName);
	CreateNative("Timer_AutoBunny", Native_AutoBunny);

	return APLRes_Success;
}

public OnPluginStart()
{
	g_cookie = RegClientCookie("timer-physics", "", CookieAccess_Public);
	
	LoadTranslations("timer.phrases");

	LoadDifficulties();
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	
	RegConsoleCmd("sm_difficulty", Command_Difficulty);
	
	g_hCvarJoinTeamDifficulty = CreateConVar("timer_jointeam_difficulty", "0", "Whether or not the difficulty menu is being shown to players who join a team.");
	HookConVarChange(g_hCvarJoinTeamDifficulty, Action_OnSettingsChange);
	
	AutoExecConfig(true, "timer-physics");
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}		
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}	
}

public Action_OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if (cvar == g_hCvarJoinTeamDifficulty)
	{
		g_bJoinTeamDifficulty = bool:StringToInt(newvalue);
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	new String:buffer[10];
	GetClientCookie(client, g_cookie, buffer, sizeof(buffer));

	if (StrEqual(buffer, ""))
	{
		g_iClientDifficulty[client] = g_iDefaultDifficulty;
	}
	else
	{
		g_iClientDifficulty[client] = StringToInt(buffer);
	}
	
	ApplyDifficulty(client);
}

public Action:Event_PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_fStamina[client] != -1.0)
	{
		SetEntPropFloat(client, Prop_Send, "m_flStamina", g_fStamina[client]);
	}

	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new team = GetEventInt(event, "team");
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_bJoinTeamDifficulty && team > 1 && client > 0)
	{
		CreateDifficultyMenu(client);
	}

	return Plugin_Continue;
}

public Action:Command_Difficulty(client, args)
{
	CreateDifficultyMenu(client);
	
	return Plugin_Handled;
}

LoadDifficulties()
{
	new String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/timer/difficulties.cfg");

	new Handle:kv = CreateKeyValues("difficulties");
	if (!FileToKeyValues(kv, path))
	{
		CloseHandle(kv);
		return;
	}
	
	g_difficultyCount = 0;

	if (!KvGotoFirstSubKey(kv))
	{
		CloseHandle(kv);
		return;
	}
	
	do 
	{
		decl String:sectionName[32];
		KvGetSectionName(kv, sectionName, sizeof(sectionName));

		g_difficulties[g_difficultyCount][Id] = StringToInt(sectionName);
		KvGetString(kv, "name", g_difficulties[g_difficultyCount][Name], 32);
		g_difficulties[g_difficultyCount][IsDefault] = bool:KvGetNum(kv, "default", 0);
		g_difficulties[g_difficultyCount][Stamina] = KvGetFloat(kv, "stamina", -1.0);
		g_difficulties[g_difficultyCount][Gravity] = KvGetFloat(kv, "gravity", 1.0);
		g_difficulties[g_difficultyCount][PreventAD] = bool:KvGetNum(kv, "prevent_ad", 0);
		g_difficulties[g_difficultyCount][PreventBack] = bool:KvGetNum(kv, "prevent_back", 0);
		g_difficulties[g_difficultyCount][PreventForward] = bool:KvGetNum(kv, "prevent_forward", 0);
		g_difficulties[g_difficultyCount][Auto] = bool:KvGetNum(kv, "auto", 0);
		
		if (g_difficulties[g_difficultyCount][IsDefault])
		{
			g_iDefaultDifficulty = g_difficulties[g_difficultyCount][Id];
		}
		
		g_difficultyCount++;
	} while (KvGotoNextKey(kv));
	
	CloseHandle(kv);	
}

CreateDifficultyMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Difficulty);

	SetMenuTitle(menu, "%T", "Physics Difficulty", client);
	SetMenuExitButton(menu, true);

	for (new difficulty = 0; difficulty < g_difficultyCount; difficulty++)
	{
		decl String:id[5];
		IntToString(g_difficulties[difficulty][Id], id, sizeof(id));

		AddMenuItem(menu, id, g_difficulties[difficulty][Name]);
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Difficulty(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End) 
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Select) 
	{
		decl String:info[32];		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		g_iClientDifficulty[param1] = StringToInt(info);
		SetClientCookie(param1, g_cookie, info);
		ApplyDifficulty(param1);

		Timer_Restart(param1);
	}
}

ApplyDifficulty(client)
{
	if (!IsClientInGame(client))
	{
		return;
	}
	
	new difficulty = 0;
	for (; difficulty < g_difficultyCount; difficulty++)
	{
		if (g_difficulties[difficulty][Id] == g_iClientDifficulty[client])
		{
			break;
		}
	}

	SetEntityGravity(client, g_difficulties[difficulty][Gravity]);
	g_fStamina[client] = g_difficulties[difficulty][Stamina];
	g_bPreventAD[client] = g_difficulties[difficulty][PreventAD];
	g_bPreventBack[client] = g_difficulties[difficulty][PreventBack];
	g_bPreventForward[client] = g_difficulties[difficulty][PreventForward];
	g_bAuto[client] = g_difficulties[difficulty][Auto];
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{	
	if (g_bPreventAD[client] && IsPlayerAlive(client))
	{
		if (!(GetEntityFlags(client) & FL_ONGROUND) && (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT))
		{
			return Plugin_Handled;
		}
	}
	
	if (g_bPreventBack[client] && IsPlayerAlive(client))
	{
		if (!(GetEntityFlags(client) & FL_ONGROUND) && (buttons & IN_BACK))
		{
			return Plugin_Handled;
		}
	}
	
	if (g_bPreventForward[client] && IsPlayerAlive(client))
	{
		if (!(GetEntityFlags(client) & FL_ONGROUND) && (buttons & IN_FORWARD))
		{
			return Plugin_Handled;
		}
	}
	
	if (g_bAuto[client] && IsPlayerAlive(client))
	{
		if (buttons & IN_JUMP)
		{
			if (!(GetEntityFlags(client) & FL_ONGROUND))
			{
				if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
				{
					if (GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
					{
						buttons &= ~IN_JUMP;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Native_GetClientDifficulty(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	return g_iClientDifficulty[client];
}

public Native_GetDifficultyName(Handle:plugin, numParams)
{
	new difficulty = GetNativeCell(1);
	new maxlength = GetNativeCell(3);

	new t = 0;
	for (; t < g_difficultyCount; t++)
	{
		if (g_difficulties[t][Id] == difficulty)
		{
			break;
		}
	}

	SetNativeString(2, g_difficulties[t][Name], maxlength);
	return true;
}

public Native_AutoBunny(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	return g_bAuto[client];
}