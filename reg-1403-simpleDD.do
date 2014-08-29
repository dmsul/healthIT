/*
	Regressions using data from HospCompare and AHA.

	***Assume for EHR that 0 = no; 1 = partial, 2 = full, N = no
	
	
*/
set more off
clear all

global EDITION 2

global STARTYEAR 2005

local discharge_var aha_admits

global CONTROL = `1'

**************************
**		I/O
**************************

global REG_PREP reg-1403-prep

global OUTREG_1st ../out/regs-1403-1st.xls
global OUTREG_RF ../out/regs-1403-RF.xls
global OUTREG_DD ../out/regs-1403-DD.xls


*******************
*******************

do $REG_PREP


*******************
**	Regressions
*******************

	* Post-period interactions
foreach var in adopter always never small medium large {
	gen `var'_post = `var'*post
}
	* Takeup-size-post
foreach var in small medium large {
	gen adopter_`var'_post = adopter_post*`var'
	gen always_`var'_post = always_post*`var'
}


			*** 	1st Stage

sort id year

* TEMP

local replace replace


global adopt_diff adopter_post always_post
global adopt_size_diff adopter_small_post adopter_medium_post adopter_large_post always_small_post always_medium_post always_large_post


**	First Stage
if $CONTROL == 1 local replace replace
else local replace
foreach lhv in live_cpoe our_basic_notes our_comprehensive {
	xtreg `lhv' $adopt_diff i.year, fe robust
	outreg2 $adopt_diff using $OUTREG_1st, `replace' excel cttop($control_var) label
	xtreg `lhv' $adopt_size_diff i.year, fe robust
	outreg2 $adopt_size_diff using $OUTREG_1st, excel cttop($control_var) label
	local replace
}


**	First Stage
if $CONTROL == 1 local replace replace
else local replace
foreach lhv in z_core z_read z_mort {
	xtreg `lhv' $adopt_diff i.year, fe robust
	outreg2 $adopt_diff using $OUTREG_RF, `replace' excel cttop($control_var) label
	xtreg `lhv' $adopt_size_diff i.year, fe robust
	outreg2 $adopt_size_diff using $OUTREG_RF, excel cttop($control_var) label
	local replace
}


