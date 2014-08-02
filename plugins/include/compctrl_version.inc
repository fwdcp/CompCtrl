#if defined _compctrl_version_included
 #endinput
#endif
#define _compctrl_version_included

#tryinclude <compctrl_version_auto>

#if !defined _compctrl_auto_version_included 
#define COMPCTRL_V_TAG			"manual"
#define COMPCTRL_V_REV			0
#define COMPCTRL_V_CSET			"0"
#define COMPCTRL_V_MAJOR		0				/**< CompCtrl Major version */
#define COMPCTRL_V_MINOR		1				/**< CompCtrl Minor version */
#define COMPCTRL_V_RELEASE		0				/**< CompCtrl Release version */

#define COMPCTRL_VERSION		"0.1.0-manual"	/**< CompCtrl version string (major.minor.release-tag) */
#endif