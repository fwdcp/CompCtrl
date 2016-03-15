#include "extension.h"
#include "demorecorder.h"

#include "demofile/demoformat.h"
#include "tier2/utlstreambuffer.h"

DemoRecorderManager g_DemoRecorderManager;

class CDemoFileProxy {
public:
	char m_szFileName[MAX_PATH];
	demoheader_t m_DemoHeader;
	CUtlStreamBuffer m_Buffer;
};

class CHLTVDemoRecorderProxy {
public:
	virtual CDemoFileProxy *GetDemoFile() = 0;
	virtual int GetRecordingTick(void) = 0;
	virtual void StartRecording(const char *filename, bool bContinuously) = 0;
	virtual void SetSignonState(int state) = 0;
	virtual bool IsRecording(void) = 0;
	virtual void PauseRecording(void) = 0;
	virtual void ResumeRecording(void) = 0;
	virtual void StopRecording(void) = 0;
	virtual void RecordCommand(const char *cmdstring) = 0;
	virtual void RecordUserInput(int cmdnumber) = 0;
	virtual void RecordMessages(bf_read &data, int bits) = 0;
	virtual void RecordPacket(void) = 0;
	virtual void RecordServerClasses(ServerClass *pClasses) = 0;
	virtual void ResetDemoInterpolation() = 0;

public:
	void StartRecording_Detour(const char *filename, bool bContinuously);
	void StopRecording_Detour(void);
	static void (CHLTVDemoRecorderProxy::*StartRecording_Actual)(const char *filename, bool bContinuously);
	static void (CHLTVDemoRecorderProxy::*StopRecording_Actual)(void);
};

void CHLTVDemoRecorderProxy::StartRecording_Detour(const char *filename, bool bContinuously) {
	bool newRecording = !this->IsRecording();

	(this->*StartRecording_Actual)(filename, bContinuously);

	if (newRecording && this->IsRecording()) {
		CDemoFileProxy *demoFile = this->GetDemoFile();
		const char *fileName = demoFile->m_szFileName;

		g_StartRecordingForward->PushString(fileName);

		cell_t result = 0;

		g_StartRecordingForward->Execute(&result);
	}
}

void CHLTVDemoRecorderProxy::StopRecording_Detour(void) {
	bool currentlyRecording = this->IsRecording();

	(this->*StopRecording_Actual)();

	if (currentlyRecording && !this->IsRecording()) {
		CDemoFileProxy *demoFile = this->GetDemoFile();
		const char *fileName = demoFile->m_szFileName;

		g_StopRecordingForward->PushString(fileName);

		cell_t result = 0;

		g_StopRecordingForward->Execute(&result);
	}
}

void DemoRecorderManager::Enable() {
	if (!m_detoursSetup) {
		m_startRecordingDetour = CDetourManager::CreateDetour(GetCodeAddress(&CHLTVDemoRecorderProxy::StartRecording_Detour), (void **)(&CHLTVDemoRecorderProxy::StartRecording_Actual), "CHLTVDemoRecorder::StartRecording");
		if (!m_startRecordingDetour) {
			g_pSM->LogError(myself, "Failed to find CHLTVDemoRecorder::StartRecording signature");
			return;
		}

		m_stopRecordingDetour = CDetourManager::CreateDetour(GetCodeAddress(&CHLTVDemoRecorderProxy::StopRecording_Detour), (void **)(&CHLTVDemoRecorderProxy::StopRecording_Actual), "CHLTVDemoRecorder::StopRecording");
		if (!m_stopRecordingDetour) {
			g_pSM->LogError(myself, "Failed to find CHLTVDemoRecorder::StopRecording signature");
			return;
		}

		m_detoursSetup = true;
	}

	if (!m_detoursEnabled) {
		m_startRecordingDetour->EnableDetour();
		m_stopRecordingDetour->EnableDetour();

		m_detoursEnabled = true;
	}
}

void DemoRecorderManager::Disable() {
	if (m_detoursEnabled) {
		m_startRecordingDetour->DisableDetour();
		m_stopRecordingDetour->DisableDetour();

		m_detoursEnabled = false;
	}
}