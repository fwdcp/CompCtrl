#include "extension.h"
#include "player.h"

PlayerManager g_PlayerManager;

SH_DECL_MANUALHOOK0_void(CTFPlayer_ResetScores, 0, 0, 0);

void PlayerManager::Enable() {
	if (!m_hooksSetup) {
		int offset;

		if (!g_pGameConfig->GetOffset("CTFPlayer::ResetScores", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFPlayer::ResetScores offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFPlayer_ResetScores, offset, 0, 0);

		m_hooksSetup = true;
	}
}

void PlayerManager::Disable() {
	if (m_hooksEnabled) {
		SH_REMOVE_HOOK_ID(m_resetScoresHook);

		m_hooksEnabled = false;
	}
}

void PlayerManager::Hook_CTFPlayer_ResetScores() {
	CBaseEntity *player = META_IFACEPTR(CBaseEntity);

	if (player) {
		g_ResetPlayerScoresForward->PushCell(gamehelpers->ReferenceToIndex(gamehelpers->EntityToBCompatRef(player)));

		cell_t result = 0;

		g_ResetPlayerScoresForward->Execute(&result);

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
		m_resetScoresHook = SH_ADD_MANUALVPHOOK(CTFPlayer_ResetScores, pEntity, SH_MEMBER(this, &PlayerManager::Hook_CTFPlayer_ResetScores), false);

		m_hooksEnabled = true;
	}
}
