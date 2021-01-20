/*  SM Franug Rep System
 *
 *  Copyright (C) 2021 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define VERSION "0.5"

#define TIME_REQUIRED 86400 // 24 Hours

#define IDAYS 26 // clear franug_reptimes database for entries older that than


// DB handle
Handle g_hDB = INVALID_HANDLE;
bool g_bIsMySQl;

ConVar cv_viptimes, cv_times, cv_vipflag, cv_adminflag,cv_admintimes;

public Plugin myinfo = 
{
	name = "SM Franug Rep System", 
	author = "Franc1sco franug", 
	description = "", 
	version = VERSION, 
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	cv_times = CreateConVar("sm_repsystem_times", "3", "Times that a regular player can vote during 24 H. 0 = unlimited.");
	cv_viptimes = CreateConVar("sm_repsystem_viptimes", "5", "Times that a vip player can vote during 24 H. 0 = unlimited.");
	cv_admintimes = CreateConVar("sm_repsystem_admintimes", "5", "Times that a admin player can vote during 24 H. 0 = unlimited.");
	cv_vipflag = CreateConVar("sm_repsystem_vipflag", "o", "Flag required for be Vip");
	cv_adminflag = CreateConVar("sm_repsystem_adminflag", "b", "Flag required for be Admin");
	
	SQL_TConnect(SQL_OnSQLConnect, "franug_repsystem");
	
	RegConsoleCmd("sm_up", Command_Up);
	RegConsoleCmd("sm_down", Command_Down);
	RegConsoleCmd("sm_reptop", Command_Top);
	RegConsoleCmd("sm_rep", Command_Rep);
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))return;
	
	CheckSQLSteamID(client);
}

public void CheckSQLSteamID(int client)
{
	char query[255], steamid[32];
	if(!GetClientAuthId(client, AuthId_Steam2,steamid, sizeof(steamid) ))return;
	
	Format(query, sizeof(query), "SELECT * FROM franug_reppoints WHERE steamid = '%s'", steamid);
	SQL_TQuery(g_hDB, CheckSQLSteamIDCallback, query, GetClientUserId(client));
}

public int CheckSQLSteamIDCallback(Handle owner, Handle hndl, char [] error, any data)
{
	int client;
	
	/* Make sure the client didn't disconnect while the thread was running */
	
	if((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
	
	if(hndl == INVALID_HANDLE)
	{
		LogError("Query failure: %s", error);
		return;
	}
	if(!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) 
	{
		InsertSQLNewPlayer(client);
	}
}

public void InsertSQLNewPlayer(int client)
{
	char query[255], steamid[32];
	
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))return;
	
	int userid = GetClientUserId(client);
	
	char Name[MAX_NAME_LENGTH+1];
	char SafeName[(sizeof(Name)*2)+1];
	if(!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
		SQL_EscapeString(g_hDB, Name, SafeName, sizeof(SafeName));
	}
	
	Format(query, sizeof(query), "INSERT INTO franug_reppoints(playername, steamid, points) VALUES('%s', '%s','0');", SafeName, steamid);
	SQL_TQuery(g_hDB, SQL_Callback, query, userid);
	
	//LogToFile("addons/sourcemod/queries.log", query);
}

public int SQL_OnSQLConnect(Handle owner, Handle hndl, char [] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Database failure: %s", error);
		
		SetFailState("Databases dont work");
	}
	else
	{
		g_hDB = hndl;
		char g_sSQLBuffer[512];
		SQL_GetDriverIdent(SQL_ReadDriver(g_hDB), g_sSQLBuffer, sizeof(g_sSQLBuffer));
		g_bIsMySQl = StrEqual(g_sSQLBuffer,"mysql", false) ? true : false;
		
		if(g_bIsMySQl)
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `franug_reptimes` (`playername` varchar(128) NOT NULL, `steamid` varchar(32),`time` int(64))");
			
			SQL_TQuery(g_hDB, SQL_OnSQLConnectCallback, g_sSQLBuffer);
			
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `franug_reppoints` (`playername` varchar(128) NOT NULL, `steamid` varchar(32), `points` int(4))");
			
			SQL_TQuery(g_hDB, SQL_OnSQLConnectCallbackNext, g_sSQLBuffer);
		}
		else
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS franug_reptimes (playername varchar(128) NOT NULL, steamid varchar(32),time int(64))");
			
			SQL_TQuery(g_hDB, SQL_OnSQLConnectCallback, g_sSQLBuffer);
			
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS franug_reppoints (playername varchar(128) NOT NULL, steamid varchar(32), points INTEGER)");
			
			SQL_TQuery(g_hDB, SQL_OnSQLConnectCallbackNext, g_sSQLBuffer);
		}
		PruneDatabase(); // todo
		
	}
}

public int SQL_OnSQLConnectCallbackNext(Handle owner, Handle hndl, char [] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Query failure: %s", error);
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				OnClientPostAdminCheck(i);
			}
		}
}

public int SQL_OnSQLConnectCallback(Handle owner, Handle hndl, char [] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Query failure: %s", error);
		return;
	}
}

public Action Command_Rep(int client, int args)
{
	
	if(args < 1) // Not enough parameters
	{
		ReplyToCommand(client, "[SM] Use: sm_rep <#userid|name>");
		return Plugin_Handled;
	}
	char arg1[64];
	/* Get the first argument */
	GetCmdArg(1, arg1, sizeof(arg1));
	
	/* Try and find a matching player */
	int target = FindTarget(client, arg1, true, false);
	if (target == -1)
	{
		/* FindTarget() automatically replies with the 
		 * failure reason.
		 */
		return Plugin_Handled;
	}
	
	CheckPoints(client, target);
	
	return Plugin_Handled;
}

public Action Command_Up(int client, int args)
{
	
	if(args < 1) // Not enough parameters
	{
		ReplyToCommand(client, "[SM] Use: sm_up <#userid|name>");
		return Plugin_Handled;
	}
	char arg1[64];
	/* Get the first argument */
	GetCmdArg(1, arg1, sizeof(arg1));
	
	/* Try and find a matching player */
	int target = FindTarget(client, arg1, true, false);
	if (target == -1)
	{
		/* FindTarget() automatically replies with the 
		 * failure reason.
		 */
		return Plugin_Handled;
	}
	
	if(target == client)
	{
		ReplyToCommand(client, "Cant vote yourself");
		return Plugin_Handled;
	}
	
	GivePoints(client, target, 1);
	
	return Plugin_Handled;
}

public Action Command_Down(int client, int args)
{
	
	if(args < 1) // Not enough parameters
	{
		ReplyToCommand(client, "[SM] Use: sm_down <#userid|name>");
		return Plugin_Handled;
	}
	char arg1[64];
	/* Get the first argument */
	GetCmdArg(1, arg1, sizeof(arg1));
	/* Try and find a matching player */
	int target = FindTarget(client, arg1, true, false);
	if (target == -1)
	{
		/* FindTarget() automatically replies with the 
		 * failure reason.
		 */
		return Plugin_Handled;
	}
	
	if(target == client)
	{
		ReplyToCommand(client, "Cant vote yourself");
		return Plugin_Handled;
	}
	
	GivePoints(client, target, 0);
	
	return Plugin_Handled;
}

void CheckPoints(int client, int target)
{
	char steamid[32];
	if (!GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid)))return;
	
	char buffer[512];
	Format(buffer, sizeof(buffer), "SELECT points FROM franug_reppoints WHERE steamid = '%s'", steamid);
	
	DataPack Pack = new DataPack();
	Pack.WriteCell(GetClientUserId(client));
	Pack.WriteCell(GetClientUserId(target));
	
	SQL_TQuery(g_hDB, SQL_GetPoints, buffer, Pack);
}

public void SQL_GetPoints(Handle db, Handle results, char [] error, DataPack Pack)
{
	Pack.Reset();
	int client = ReadPackCell(Pack);
	int target = ReadPackCell(Pack);
    
	if((client = GetClientOfUserId(client)) == 0)
	{
		return;
	}
	
	if((target = GetClientOfUserId(target)) == 0)
	{
		PrintToChat(client, "Target client disconnected");
		return;
	}
	
	if (results == INVALID_HANDLE)
	{
		LogError("Failed to query (error: %s)", error);
		PrintToChat(client, "An unexpected error has occurred");
		return;
	}
	int points;
	if(!SQL_GetRowCount(results) || !SQL_FetchRow(results)) 
	{
		points = 0;
	}
	else
		points = SQL_FetchInt(results, 0);
	
	PrintToChat(client, "%N have %i points", target, points);
	
}

void GivePoints(int client, int target, int isUp)
{
	char steamid[32];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))return;
	
	char buffer[512];
	Format(buffer, sizeof(buffer), "SELECT COUNT(*) FROM franug_reptimes WHERE time > (%i-%i) AND steamid = '%s'", GetTime(),TIME_REQUIRED, steamid);
	
	DataPack Pack = new DataPack();
	Pack.WriteCell(GetClientUserId(client));
	Pack.WriteCell(GetClientUserId(target));
	Pack.WriteCell(isUp);
	
	SQL_TQuery(g_hDB, SQL_GetVoteCount, buffer, Pack);
}

public void SQL_GetVoteCount(Handle db, Handle results, char [] error, DataPack Pack)
{
	Pack.Reset();
	int client = ReadPackCell(Pack);
	int target = ReadPackCell(Pack);
	int isUp = ReadPackCell(Pack);
    
	if((client = GetClientOfUserId(client)) == 0)
	{
		return;
	}
	
	if((target = GetClientOfUserId(target)) == 0)
	{
		PrintToChat(client, "Target client disconnected");
		return;
	}
	
	if (results == INVALID_HANDLE)
	{
		LogError("Failed to query (error: %s)", error);
		PrintToChat(client, "An unexpected error has occurred");
		return;
	}
	int times;
    
	if(!SQL_GetRowCount(results) || !SQL_FetchRow(results)) 
	{
		times = 0;
	}
	else
		times = SQL_FetchInt(results, 0);
	
	int maxtimes;
	
	if(isAdmin(client))
		maxtimes = cv_admintimes.IntValue;
	else if(isVip(client))
		maxtimes = cv_viptimes.IntValue;
	else
		maxtimes = cv_times.IntValue;
	
	if(times >= maxtimes && maxtimes != 0)
	{
		PrintToChat(client, "You exceeded the max votes per 24 H");
		return;
	}
	
	doVote(client, target, isUp);
	
}

void doVote(int client, int target, int isUp)
{
	char query[512];
	
	char Name[MAX_NAME_LENGTH+1];
	char SafeName[(sizeof(Name)*2)+1];
	if(!GetClientName(client, Name, sizeof(Name)))
		Format(SafeName, sizeof(SafeName), "<noname>");
	else
	{
		TrimString(Name);
		SQL_EscapeString(g_hDB, Name, SafeName, sizeof(SafeName));
	}
	
	char NameVoted[MAX_NAME_LENGTH+1];
	char SafeNameVoted[(sizeof(NameVoted)*2)+1];
	if(!GetClientName(target, NameVoted, sizeof(NameVoted)))
		Format(SafeNameVoted, sizeof(SafeNameVoted), "<noname>");
	else
	{
		TrimString(NameVoted);
		SQL_EscapeString(g_hDB, NameVoted, SafeNameVoted, sizeof(SafeNameVoted));
	}
	char steamid[32];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))return;
	
	char steamidvoted[32];
	if (!GetClientAuthId(target, AuthId_Steam2,steamidvoted, sizeof(steamidvoted)))return;
	
	Format(query, sizeof(query), "INSERT INTO franug_reptimes(playername, steamid, time) VALUES('%s', '%s', '%d');", SafeName, steamid, GetTime());
	SQL_TQuery(g_hDB, SQL_Callback, query);
	
	Format(query, sizeof(query), "UPDATE franug_reppoints SET playername = '%s', points = points + '%i' WHERE steamid = '%s';", SafeNameVoted, isUp?1:-1, steamidvoted);
	SQL_TQuery(g_hDB, SQL_Callback, query);
	
	PrintToChatAll("%N give %s to %N", client, isUp ? "+1":"-1", target);
}

public int SQL_Callback(Handle owner, Handle hndl, char [] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Query failure: %s", error);
		return;
	}
}

public Action Command_Top(int client, int args)
{
	if(!client)
		return Plugin_Handled;
	
	if(g_hDB != INVALID_HANDLE)
	{
		char buffer[200];
		Format(buffer, sizeof(buffer), "SELECT playername, steamid, points FROM franug_reppoints ORDER BY points DESC LIMIT 999");
		SQL_TQuery(g_hDB, ShowTotalCallback, buffer, client);
	}
	else
	{
		PrintToChat(client, "Rank System is now not avilable");
	}
	
	return Plugin_Handled;
}

public int ShowTotalCallback(Handle owner, Handle hndl, char [] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		return;
	}
	
	Menu menu2 = CreateMenu(DIDMenuHandler2);
	menu2.SetTitle("Top Rep System");
	
	int order = 0;
	char number[64];
	char name[64];
	char textbuffer[128];
	char steamid[128];
	int points;
	
	if(SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			order++;
			Format(number,64, "option%i", order);
			SQL_FetchString(hndl, 0, name, sizeof(name));
			SQL_FetchString(hndl, 1, steamid, sizeof(steamid));
			points = SQL_FetchInt(hndl, 2);
			
			Format(textbuffer,128, "top%i %s - %i points", order,name,points);
			menu2.AddItem(steamid, textbuffer);
		}
	}
	if(order < 1) 
	{
		menu2.AddItem("empty", "TOP is empty!");
	}
	
	menu2.ExitButton = true;
	menu2.Display(client,MENU_TIME_FOREVER);
}

public int DIDMenuHandler2(Menu menu2, MenuAction action, int client, int itemNum) 
{
	if( action == MenuAction_Select ) 
	{
			char info[128], community[128];
		
			GetMenuItem(menu2, itemNum, info, sizeof(info));
			GetCommunityID(info, community, sizeof(community));
			
			Format(community, sizeof(community), "http://steamcommunity.com/profiles/%s", community);
			PrintToChat(client, community);
			PrintToConsole(client, community);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu2);
	}
}

public void PruneDatabase()
{
	if(g_hDB == INVALID_HANDLE)
	{
		return;
	}

	int maxlastaccuse;
	maxlastaccuse = GetTime() - (IDAYS * 86400);

	char buffer[1024];

	if(g_bIsMySQl)
		Format(buffer, sizeof(buffer), "DELETE FROM `franug_reptimes` WHERE `time`<'%d' AND `time`>'0';", maxlastaccuse);
	else
		Format(buffer, sizeof(buffer), "DELETE FROM franug_reptimes WHERE time<'%d' AND time>'0';", maxlastaccuse);

	SQL_TQuery(g_hDB, SQL_Callback, buffer);
}

bool GetCommunityID(char [] AuthID, char [] FriendID, int size)
{
	if(strlen(AuthID) < 11 || AuthID[0]!='S' || AuthID[6]=='I')
	{
		FriendID[0] = 0;
		return false;
	}
	int iUpper = 765611979;
	int iFriendID = StringToInt(AuthID[10])*2 + 60265728 + AuthID[8]-48;
	int iDiv = iFriendID/100000000;
	int iIdx = 9-(iDiv?iDiv/10+1:0);
	iUpper += iDiv;
	IntToString(iFriendID, FriendID[iIdx], size-iIdx);
	iIdx = FriendID[9];
	IntToString(iUpper, FriendID, size);
	FriendID[9] = iIdx;
	return true;
}

bool isAdmin(int client)
{
	char flag[12];
	GetConVarString(cv_adminflag, flag, 12);
	
	if(HasPermission(client, "z") || HasPermission(client, flag))
		return true;
		
	return false;
}

bool isVip(int client)
{
	char flag[12];
	GetConVarString(cv_vipflag, flag, 12);
	
	if(HasPermission(client, flag))
		return true;
		
	return false;
}

stock bool HasPermission(int iClient, char[] flagString) 
{
	if (StrEqual(flagString, "")) 
	{
		return true;
	}
	
	AdminId admin = GetUserAdmin(iClient);
	
	if (admin != INVALID_ADMIN_ID)
	{
		int count, found, flags = ReadFlagString(flagString);
		for (int i = 0; i <= 20; i++) 
		{
			if (flags & (1<<i)) 
			{
				count++;
				
				if (GetAdminFlag(admin, view_as<AdminFlag>(i))) 
				{
					found++;
				}
			}
		}

		if (count == found) {
			return true;
		}
	}

	return false;
} 