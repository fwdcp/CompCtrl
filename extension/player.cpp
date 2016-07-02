#include "extension.h"
#include "player.h"

PlayerManager g_PlayerManager;

SH_DECL_MANUALHOOK0_void(CTFPlayer_ForceRespawn, 0, 0, 0);

void PlayerManager::Enable() {
	if (!m_hooksSetup) {
		int offset;

		if (!g_pGameConfig->GetOffset("CTFPlayer::ForceRespawn", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFPlayer::ForceRespawn offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFPlayer_ForceRespawn, offset, 0, 0);

		m_hooksSetup = true;
	}
}

void PlayerManager::Disable() {
	if (m_hooksEnabled) {
		SH_REMOVE_HOOK_ID(m_forceRespawnHook);

		m_hooksEnabled = false;
	}
}

void PlayerManager::Hook_CTFPlayer_ForceRespawn() {
	CBaseEntity *player = META_IFACEPTR(CBaseEntity);

	if (player) {
		int client = player->entindex();

		g_RespawnForward->PushCell(client);

		cell_t result = 0;

		g_RespawnForward->Execute(&result);

		if (result > Pl_Continue) {
			RETURN_META(MRES_SUPERCEDE);
		}
		else {
			RETURN_META(MRES_IGNORED);
		}
	}

	RETURN_META(MRES_IGNORED);
}

void PlayerManager::OnEntityCreated(CBaseEntity *pEntity, const char *classname) {
	if (!m_hooksEnabled && pEntity && V_stricmp(classname, "player") == 0) {
		m_forceRespawnHook = SH_ADD_MANUALVPHOOK(CTFPlayer_ForceRespawn, pEntity, SH_MEMBER(this, &PlayerManager::Hook_CTFPlayer_ForceRespawn), false);

		m_hooksEnabled = true;
	}
}
