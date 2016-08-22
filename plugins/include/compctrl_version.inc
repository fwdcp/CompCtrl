#if defined _compctrl_version_included
 #endinput
#endif
#define _compctrl_version_included

#pragma newdecls required

#tryinclude <compctrl_version_auto>

#if !defined _compctrl_auto_version_included
#define COMPCTRL_V_TAG      "manual"
#define COMPCTRL_V_REV      0
#define COMPCTRL_V_CSET     "0"
#define COMPCTRL_V_MAJOR    0               /**< CompCtrl Major version */
#define COMPCTRL_V_MINOR    5               /**< CompCtrl Minor version */
#define COMPCTRL_V_RELEASE  1               /**< CompCtrl Release version */

#define COMPCTRL_VERSION    "0.5.1-manual"  /**< CompCtrl version string (major.minor.release-tag) */
#endif

#pragma newdecls optional
