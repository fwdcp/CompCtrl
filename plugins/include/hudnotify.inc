#include <sdktools>
#include <tf2>
#include <usermessages>

#pragma newdecls required

stock void HudNotify(int client, const char[] icon = "timer_icon", TFTeam color = TFTeam_Unassigned, const char[] message, any ...) {
    char[] formattedMessage = new char[strlen(message) * 2];
    VFormat(formattedMessage, strlen(message) * 2, message, 5);

    Handle bf = StartMessageOne("HudNotifyCustom", client);
    BfWriteString(bf, formattedMessage);
    BfWriteString(bf, icon);
    BfWriteByte(bf, view_as<int>(color));

    EndMessage();
}

stock void HudNotifyAll(const char[] icon = "timer_icon", TFTeam color = TFTeam_Unassigned, const char[] message, any ...) {
    char[] formattedMessage = new char[strlen(message) * 2];
    VFormat(formattedMessage, strlen(message) * 2, message, 4);

    int entity = CreateEntityByName("game_text_tf");

	if (entity != -1) {
		if (DispatchKeyValue(entity, "message", formattedMessage)
		    && DispatchKeyValue(entity, "icon", icon)
		    && DispatchKeyValueFloat(entity, "display_to_team", float(0))
            && DispatchKeyValueFloat(entity, "background", float(view_as<int>(color)))
            && DispatchSpawn(entity)
            && AcceptEntityInput(entity, "Display", entity, entity)) {
			return;
		}

		AcceptEntityInput(entity, "Kill");
	}

    /* Handle bf = StartMessageAll("HudNotifyCustom");
    BfWriteString(bf, formattedMessage);
    BfWriteString(bf, icon);
    BfWriteByte(bf, view_as<int>(color));

    EndMessage(); */
}

#pragma newdecls optional
