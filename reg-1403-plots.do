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

global SIZE = `2'


**************************
**		I/O
**************************

global REG_PREP reg-1403-prep

global PLOT_STEM ../gph/plot-1403

**************************

do $REG_PREP


*******************
**	Plots
*******************

if $SIZE>=1 {
	keep if size==$SIZE
	local sizelabel: label (size) $SIZE
}
else local sizelabel "All"

gen count = 1

collapse (count) count (mean) live_* newadopt_* nomisscontract_* age_* recent_* our_compre* our_basic_notes agha_hit z_* nrev* lrev* beds_h, by(takeup year)

//local mlabconfig "mlabel(payment_bed_group) mlabp(0) msize(medlarge) mc(white) mlabs(medlarge)"

/*
collapse (mean) `var' [fw=count], by(year)
twoway connected `var' year
asdf
*/

qui summ count if takeup==-1 & year==2010
local n_never = r(mean)
qui summ count if takeup==0 & year==2010
local n_adopt = r(mean)
qui summ count if takeup==1 & year==2010
local n_always = r(mean)

foreach var in live_cpoe our_basic_notes our_comprehensive z_core z_read z_mort /*lrev_fte lrev_payroll beds_h*/ {
	
	if inlist("`var'","live_cpoe", "our_basic_notes", "our_comprehensive") local yrange ylab(0(.2)1)
	else local yrange

	
	
	qui summ year if `var'!=.
	local startyear = r(min)


	twoway  (connected `var' year if takeup==0) ///
			(connected `var' year if takeup==-1) ///
			(connected `var' year if takeup==1) if year>=`startyear' , ///
			xlab(`startyear'/2011) ti("`var'") legend(off) name(`var') `yrange'
}
graph combine live_cpoe our_basic_notes our_comprehensive z_core z_read z_mort , c(3) title("Control: $control_var") xsize(7) note("Hospital size: `sizelabel'. Group Obs: Never=`n_never'; Adopters=`n_adopt'; Always=`n_always'")
graph export $PLOT_STEM-$control_var-`sizelabel'.png, replace width(2000)



