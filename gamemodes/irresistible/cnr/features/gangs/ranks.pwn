/*
 * Irresistible Gaming (c) 2018
 * Developed by Stev
 * Module: cnr/features/gangs/rank.pwn
 * Purpose: custom ranks
 */

/* ** Includes ** */
#include 							< YSI\y_hooks >

/* ** Macros ** */
#define Ranks_GetGangRank(%0,%1)	( g_gangRankData[ %0 ] [ %1 ] [ E_NAME ] )

/* ** Definitions ** */
#define MAX_RANKS 					( 25 )

#define DIALOG_GANG_RANK            ( 1205 )
#define DIALOG_SET_RANK             ( 1206 )
#define DIALOG_RANK_EDIT 			( 1207 )
#define DIALOG_EDIT_RANK_NAME 		( 1208 )
#define DIALOG_EDIT_RANK_REQUIRE	( 1209 )
#define DIALOG_RANK_DELETE 			( 1210 )
#define DIALOG_EDIT_RANK_COLOR 		( 1211 )

/* ** Variables ** */
enum E_GANG_RANK
{
	E_SQL_ID,			E_NAME[ 32 ],			E_REQUIRE,
	E_COLOR
};

static stock
	p_PlayerSelectedRank 			[ MAX_PLAYERS ] [ MAX_RANKS ],
	p_PlayerRespect 				[ MAX_PLAYERS ],
	p_PlayerRankID 					[ MAX_PLAYERS ],

	g_gangRankData 					[ MAX_GANGS ] [ MAX_RANKS ] [ E_GANG_RANK ]
;

/* ** Hooks ** */
hook OnPlayerLogin( playerid )
{
	mysql_tquery( dbHandle, sprintf( "SELECT * FROM `USER_GANG_RANKS` WHERE `USER_ID`=%d", GetPlayerAccountID( playerid ) ), "GangRank_LoadRespect", "d", playerid );
	return 1;
}

hook OnPlayerDisconnect( playerid, reason )
{
	p_PlayerRespect[ playerid ] = 0;
	p_PlayerRankID[ playerid ]  = 0;
	return 1;
}

hook OnGangLoad( gangid )
{
	mysql_tquery( dbHandle, sprintf( "SELECT * FROM `GANG_RANKS` WHERE `GANG_ID`=%d", GetGangSqlID( gangid ) ), "GangRank_Load", "d", gangid );
	return 1;
}

hook OnPlayerLeaveGang( playerid, gangid, reason )
{
	mysql_single_query( sprintf( "DELETE FROM `USER_GANG_RANKS` WHERE `USER_ID`=%d" , p_AccountID[ playerid ] ) );
	return 1;
}

hook OnGangUnload( gangid, bool: deleted )
{
	if ( deleted )
	{
		// delete from gang rank table
		mysql_single_query( sprintf( "DELETE FROM `GANG_RANKS` WHERE `GANG_ID`=%d", g_gangData[ gangid ] [ E_SQL_ID ] ) );

		// delete user associated gang ranks
		mysql_single_query( sprintf( "DELETE FROM `USER_GANG_RANKS` WHERE `GANG_ID`=%d" , g_gangData[ gangid ] [ E_SQL_ID ] ) );
	}
	return 1;
}

hook OnDialogResponse( playerid, dialogid, response, listitem, inputtext[ ] )
{
	new
		gangid = p_GangID[ playerid ];

	if ( ! IsValidGangID( gangid ) )
		return 1;

	if ( dialogid == DIALOG_EDIT_RANK_COLOR )
	{
		if ( ! response ) {
			return GangRank_ShowPlayerRanks( playerid );
		}

		if ( !strlen( inputtext ) || !isHex( inputtext ) )
		    return ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_COLOR, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "{FFFFFF}Write a hexidecimal color within the textbox\n\n"COL_RED"Invalid HEX color", "Submit", "Cancel" );

		new
			hex_to_int = HexToInt( inputtext ),
			rankid = GetPVarInt( playerid, "viewing_rankid" ),
			color = setAlpha( hex_to_int, 0xFF );

		SendClientMessageFormatted( playerid, g_gangData[ p_GangID[ playerid ] ] [ E_COLOR ], "[GANG]"COL_WHITE" You have changed the %s color.", Ranks_GetGangRank( gangid, rankid ), hex_to_int >>> 8 );
		mysql_query( dbHandle, sprintf( "UPDATE `GANG_RANKS` SET `COLOR`=%d WHERE `ID`=%d", color, rankid ) );
		return 1;
	}
	else if ( dialogid == DIALOG_RANK_DELETE )
	{
		if ( ! response ) {
			return 1;
		}

		new
			rankid = GetPVarInt( playerid, "viewing_rankid" );

		SendClientMessageToGang( p_GangID[ playerid ], g_gangData[ p_GangID[ playerid ] ] [ E_COLOR ], "[GANG] "COL_WHITE"%s rank has been deleted by %s(%d).", Ranks_GetGangRank( gangid, rankid ), ReturnPlayerName( playerid ), playerid );

		mysql_single_query( sprintf( "DELETE FROM `GANG_RANKS` WHERE `ID`=%d", rankid ) );
		mysql_single_query( sprintf( "DELETE FROM `USER_GANG_RANKS` WHERE `GANG_RANK_ID`=%d", rankid ) );

		return 1;
	}
	else if ( dialogid == DIALOG_EDIT_RANK_REQUIRE )
	{
		if ( ! response ) {
			return GangRank_ShowPlayerRanks( playerid );
		}

		new
			rankid = GetPVarInt( playerid, "viewing_rankid" ),
			value;

		if ( sscanf( inputtext, "d", value ) )
			return ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_REQUIRE, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "Type the rank requirement value below (gang respect level to achieve rank)\n0 = No requirement\n\n"COL_RED"Invalid Amount!", "Submit", "Cancel" );

		SendClientMessageFormatted( playerid, g_gangData[ p_GangID[ playerid ] ] [ E_COLOR ], "[GANG]"COL_WHITE" You have changed the requirement on %s to %d.", Ranks_GetGangRank( gangid, rankid ), value );
		mysql_query( dbHandle, sprintf( "UPDATE `GANG_RANKS` WHERE `REQUIRE`='%s' WHERE `ID`=%d", value, rankid ) );
		return 1;
	}
	else if ( dialogid == DIALOG_EDIT_RANK_NAME )
	{
		if ( ! response ) {
			return GangRank_ShowPlayerRanks( playerid );
		}

		new
			rankid = GetPVarInt( playerid, "viewing_rankid" ),
			rank_name[ 32 ];

		if ( sscanf( inputtext, "s[32]", rank_name ) )
			return ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_NAME, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "Enter the rank name you want to change it to\n\n", "Submit", "Cancel" );

		if ( ! GangRank_IsNameAlreadyUsed( gangid, rank_name ) )
			return ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_NAME, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "Enter the rank name you want to change it to\n\n"COL_RED"This rank name is already created, use another name.", "Submit", "Cancel" );

		if ( strlen( rank_name ) < 3 )
			return ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_NAME, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "Enter the rank name you want to change it to\n\n", "Submit", "Cancel" );

		SendClientMessageFormatted( playerid, g_gangData[ p_GangID[ playerid ] ] [ E_COLOR ], "[GANG]"COL_WHITE" You have changed %s to %s.", Ranks_GetGangRank( gangid, rankid ), rank_name );
		mysql_query( dbHandle, sprintf( "UPDATE `GANG_RANKS` WHERE `RANK_NAME`='%s' WHERE `ID`=%d" , mysql_escape( rank_name ), rankid ) );
		return 1;
	}
	else if ( dialogid == DIALOG_GANG_RANK && response )
	{
		new
            rankid = p_PlayerSelectedRank[ playerid ] [ listitem ];

        SendServerMessage( playerid, "You have selected rank %s(%d)", Ranks_GetGangRank( gangid, rankid ), rankid );

		ShowPlayerDialog( playerid, DIALOG_RANK_EDIT, DIALOG_STYLE_LIST, sprintf( ""COL_WHITE"Gang Ranks - %s", Ranks_GetGangRank( gangid, rankid ) ), "Edit Color\nEdit Requirements\nEdit Name\n"COL_RED"Delete Rank", "Select", "Back" );
		SetPVarInt( playerid, "viewing_rankid", rankid );
		return 1;
	}
	else if ( dialogid == DIALOG_RANK_EDIT )
	{
		if ( ! response ) {
			return GangRank_ShowPlayerRanks( playerid );
		}

		new rankid = GetPVarInt( playerid, "viewing_rankid" );

		switch ( listitem )
		{
			// edit color
			case 0: ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_COLOR, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "{FFFFFF}Write a hexidecimal color within the textbox\n\n{C0C0C0}Example: FF0000FF (RRGGBBAA)", "Submit", "Cancel" );

			// edit requirement
			case 1: ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_REQUIRE, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "{FFFFFF}Type the rank requirement value below (gang respect level to achieve rank)\n0 = No requirement\n\n", "Submit", "Cancel" );

			// edit name
			case 2: ShowPlayerDialog( playerid, DIALOG_EDIT_RANK_NAME, DIALOG_STYLE_INPUT, ""COL_WHITE"Gang Ranks", "{FFFFFF}Enter the rank name you want to change it to\n\n", "Submit", "Cancel" );

			// delete rank
			case 3: ShowPlayerDialog( playerid, DIALOG_RANK_DELETE, DIALOG_STYLE_MSGBOX, ""COL_WHITE"Gang Ranks", sprintf( "{FFFFFF}Are you sure you want to delete %s", Ranks_GetGangRank( gangid, rankid ) ), "Yes", "No" );
		}

		return 1;
	}
	else if ( dialogid == DIALOG_SET_RANK && response )
	{
		new
			rankid = p_PlayerSelectedRank[ playerid ] [ listitem ],
			otherid = GetPVarInt( playerid, "set_rankid" );

		format( szNormalString, sizeof( szNormalString ), "SELECT `USER_ID` FROM `USER_GANG_RANKS` WHERE `USER_ID`=%d LIMIT 0,1", p_AccountID[ playerid ] );
		mysql_tquery( dbHandle, szNormalString, "GangRank_OnSetPlayerRank", "ddd", playerid, otherid, rankid );
		return 1;
	}
	return 1;
}

/* ** Functions ** */
thread GangRank_LoadRespect( playerid )
{
	new
		rows = cache_get_row_count( );

	if ( rows )
	{
		p_PlayerRespect[ playerid ] = cache_get_field_content_int( 0, "RESPECT" );
		p_PlayerRankID[ playerid ]  = cache_get_field_content_int( 0, "GANG_RANK_ID" );
	}
	return 1;
}

thread GangRank_Load( gangid )
{
	new
		rows = cache_get_row_count( );

	if ( rows )
	{
		for ( new i = 0; i < rows; i ++ )
		{
			g_gangRankData[ gangid ] [ i ] [ E_SQL_ID ]  = cache_get_field_content_int( i, "ID" );
			g_gangRankData[ gangid ] [ i ] [ E_COLOR ] = cache_get_field_content_int( i, "COLOR" );
			g_gangRankData[ gangid ] [ i ] [ E_REQUIRE ] = cache_get_field_content_int( i, "REQUIRE" );

			cache_get_field_content( i, "RANK_NAME", g_gangRankData[ gangid ] [ i ] [ E_NAME ] );

			if ( g_Debugging )
			{
				printf( "[GANG RANKS] {id: %d, color: %d, requirement: %d, name: %s}", \
					g_gangRankData[ gangid ] [ i ] [ E_SQL_ID ], g_gangRankData[ gangid ] [ i ] [ E_COLOR ], g_gangRankData[ gangid ] [ i ] [ E_REQUIRE ] , g_gangRankData[ gangid ] [ i ] [ E_NAME ] );
			}
		}
	}
	return 1;
}

// stock Ranks_RespawnRanks( playerid )
// {
// 	mysql_tquery( dbHandle, sprintf( "SELECT * FROM `USER_GANG_RANKS` WHERE `USER_ID` = %d ", GetPlayerAccountID( playerid ) ), "GangRank_LoadRespect", "d", playerid );
// 	p_PlayerRespect[ playerid ] = 0;
// 	p_PlayerRankID[ playerid ]  = 0;
// 	return 1;
// }

stock GangRank_IsNameAlreadyUsed( gangid, const rank[ ] )
{
	for ( new r = 0; r < MAX_RANKS; r ++ ) if ( ! strcmp( g_gangRankData[ gangid ] [ r ] [ E_NAME ], rank, true ) ) {
		return true;
	}
	return false;
}

stock GangRank_ShowPlayerRanks( playerid, bool: setting = false )
{
	format( szNormalString, sizeof( szNormalString ), "SELECT * FROM `GANG_RANKS` WHERE `GANG_ID`=%d", g_gangData[ p_GangID[ playerid ] ] [ E_SQL_ID ] );
 	mysql_tquery( dbHandle, szNormalString, ! setting ? ( "GangRank_OnDisplayGangRanks" ) : ( "GangRank_OnDisplaySetRanks" ), "d", playerid );
	return 1;
}

stock GangRank_GivePlayerRespect( playerid, default_respect )
{
	if ( ! IsPlayerConnected( playerid ) )
		return 0;

	new gangid = p_GangID[ playerid ];
	new previous_respect = p_PlayerRespect[ playerid ];
	new current_respect = previous_respect + default_respect;

	if ( current_respect < 0 )
		current_respect = 0;

	for ( new rankid = 0; rankid < MAX_RANKS; rankid ++ )
	{
		new
			bGained = ( previous_respect < g_gangRankData[ gangid ] [ rankid ] [ E_REQUIRE ] <= current_respect );

		if ( bGained )
		{
			p_PlayerRankID[ playerid ] = g_gangRankData[ gangid ] [ rankid ] [ E_SQL_ID ];
			SendServerMessage( playerid, "Congratulations, your gang ranking has been increased to {%06x}%s"COL_WHITE"!", g_gangRankData[ gangid ] [ rankid ] [ E_COLOR ] >>> 8, g_gangRankData[ gangid ] [ rankid ] [ E_NAME ] );

			mysql_single_query( sprintf( "UPDATE `USER_GANG_RANKS` SET `GANG_RANK_ID`=%d WHERE `USER_ID`=%d", g_gangRankData[ gangid ] [ rankid ] [ E_SQL_ID ], GetPlayerAccountID( playerid ) ) );
			break;
		}
	}

	p_PlayerRespect[ playerid ] = current_respect;
	mysql_single_query( sprintf( "UPDATE `USER_GANG_RANKS` SET `RESPECT`=%d WHERE `USER_ID`=%d", p_PlayerRespect[ playerid ], GetPlayerAccountID( playerid ) ) );
	return 1;
}

thread GangRank_OnSetPlayerRank( playerid, otherid, rankid )
{
	new
		rows = cache_get_row_count( );

	if ( rows ) {
		mysql_single_query( sprintf( "UPDATE `USER_GANG_RANKS` SET `GANG_RANK_ID`=%d WHERE `USER_ID`=%d" , rankid, p_AccountID[ otherid ] ) );
	} else {
		mysql_single_query( sprintf( "INSERT INTO `USER_GANG_RANKS` (`USER_ID`,`GANG_RANK_ID`) VALUES(%d,%d)", p_AccountID[ otherid ], rankid ) );
	}

	new gangid = p_GangID[ otherid ];

	p_PlayerRankID[ otherid ] = rankid;

	SendClientMessageFormatted( otherid,  g_gangData[ gangid ] [ E_COLOR ], "[GANG]{FFFFFF} %s(%d) has set your rank to %s.", ReturnPlayerName( playerid ), playerid, Ranks_GetGangRank( gangid, rankid ) );
	SendClientMessageFormatted( playerid, g_gangData[ gangid ] [ E_COLOR ], "[GANG]{FFFFFF} You have set %s(%d)'s rank to %s.", ReturnPlayerName( otherid ), otherid, Ranks_GetGangRank( gangid, rankid ) );
	return 1;
}

thread GangRank_OnDisplaySetRanks( playerid )
{
	new
		rows = cache_get_row_count( );

    if ( ! rows ) {
        return SendError( playerid, "This gang doesn't have any ranks." );
    }

	szLargeString = ""COL_WHITE"Rank\t"COL_WHITE"Internal ID\n";

    for ( new i = 0; i < rows; i ++ )
    {
		if ( i < MAX_RANKS )
		{
			new
				rankName[ 32 ];

			new id = cache_get_field_content_int( i, "ID" );
			new color = cache_get_field_content_int( i, "COLOR" );
			cache_get_field_content( i, "RANK_NAME", rankName );

			format( szLargeString, sizeof( szLargeString ), "%s{%06x}%s\t%d\n", szLargeString, setAlpha( color, 0xFF ) >>> 8, rankName, id );
			p_PlayerSelectedRank[ playerid ] [ i ] = id;
		}
		else
		{
			p_PlayerSelectedRank[ playerid ] [ i ] = 0;
		}
    }

    return ShowPlayerDialog( playerid, DIALOG_SET_RANK, DIALOG_STYLE_TABLIST_HEADERS, "{FFFFFF}Gang Ranks", szLargeString, "Okay", "" ), 1;
}

thread GangRank_OnDisplayGangRanks( playerid )
{

	new
		rows = cache_get_row_count( );

    if ( ! rows ) {
        return SendError( playerid, "This gang doesn't have any ranks." );
    }

	szLargeString = ""COL_WHITE"Rank\t"COL_WHITE"Internal ID\n";

    for ( new i = 0; i < MAX_RANKS; i ++ )
    {
		if ( i < rows )
		{
			new
				rankName[ 32 ];

			new id = cache_get_field_content_int( i, "ID" );
			new color = cache_get_field_content_int( i, "COLOR" );

			cache_get_field_content( i, "RANK_NAME", rankName );

			format( szLargeString, sizeof( szLargeString ), "%s{%06x}%s\t%d\n", szLargeString, setAlpha( color, 0xFF ) >>> 8, rankName, id );
			p_PlayerSelectedRank[ playerid ] [ i ] = id;
		}
		else
		{
			p_PlayerSelectedRank[ playerid ] [ i ] = 0;
		}
    }

    return ShowPlayerDialog( playerid, DIALOG_GANG_RANK, DIALOG_STYLE_TABLIST_HEADERS, "{FFFFFF}Gang Ranks", szLargeString, "Okay", "" ), 1;
}

stock GangRank_IsOverLimit( gangid ) {
	for ( new i = 0; i < MAX_RANKS; i ++ ) if ( ! g_gangRankData[ gangid ] [ i ] [ E_SQL_ID ] ) {
		return false;
	}
	return true;
}