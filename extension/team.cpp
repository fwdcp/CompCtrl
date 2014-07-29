#include "extension.h"
#include "team.h"

TeamManager g_TeamManager;

SH_DECL_MANUALHOOK0(CTFTeam_GetTeamNumber, 0, 0, 0, int);
SH_DECL_MANUALHOOK0_void(CTFTeam_ResetScores, 0, 0, 0, int)

void TeamManager::Enable() {
	if (!m_hooksSetup) {
		int offset;

		if (!g_pGameConfig->GetOffset("CTFTeam::GetTeamNumber", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFTeam::GetTeamNumber offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFTeam_GetTeamNumber, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFTeam::ResetScores", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFTeam::ResetScores offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFTeam_ResetScores, offset, 0, 0);

		m_hooksSetup = true;
	}
}

void TeamManager::Disable() {
	if (m_hooksEnabled) {
		SH_REMOVE_HOOK_ID(m_resetScoresHook);

		m_hooksEnabled = false;
	}
}

int TeamManager::Call_CTFTeam_GetTeamNumber(CBaseEntity *pEntity) {
	if (pEntity) {
		return SH_MCALL(pEntity, CTFTeam_GetTeamNumber)();
	}

	return -1;
}

void TeamManager::Hook_CTFTeam_ResetScores() {
	CBaseEntity *team = META_IFACEPTR(CBaseEntity);

	if (team) {
		int teamNum = Call_CTFTeam_GetTeamNumber(team);

		if (teamNum != -1) {
			g_ResetTeamScoresForward->PushCell(teamNum);

			cell_t result = 0;

			g_ResetTeamScoresForward->Execute(&result);

			if (result > Pl_Continue) {
				RETURN_META(MRES_SUPERCEDE);
			}
			else {
				RETURN_META(MRES_IGNORED);
			}
		}
	}

	RETURN_META(MRES_IGNORED);
}

void TeamManager::OnEntityCreated(CBaseEntity *pEntity, const char *classname) {
	if (!m_hooksEnabled && pEntity && V_stricmp(classname, "tf_team") == 0) {
		m_resetScoresHook = SH_ADD_MANUALVPHOOK(CTFTeam_ResetScores, pEntity, SH_MEMBER(this, &TeamManager::Hook_CTFTeam_ResetScores), false);

		m_hooksEnabled = true;
	}
}