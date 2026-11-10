/* tc_util_user_override.h - end every ztest run through tohost (lockstep / TB verdict).
 * Enabled by CONFIG_ZTEST_TC_UTIL_USER_OVERRIDE=y; tohost lives in tohost.c.
 * TC_END_POST cannot be overridden (tc_util.h redefines it unconditionally), so this
 * replaces TC_END_REPORT, same text as Zephyr's, plus the exit. The macros it uses are
 * defined later by tc_util.h, which is fine: they expand at the point of use. */
#ifndef RV128IMAC_TC_UTIL_USER_OVERRIDE_H
#define RV128IMAC_TC_UTIL_USER_OVERRIDE_H

void rv_tohost_exit(int result);

#define TC_END_REPORT(result)                                                  \
	do {                                                                   \
		PRINT_LINE;                                                    \
		TC_PRINT_RUNID;                                                \
		TC_END(result, "PROJECT EXECUTION %s\n",                       \
		       (result) == TC_PASS ? "SUCCESSFUL" : "FAILED");         \
		rv_tohost_exit(result);                                        \
	} while (false)

#endif
