/*
	This file makes tables and graphs to summarize EMR takeup over
	time by quintiles of the various variables 
	(e.g., Incentive Pay per Hospital Bed).
	
	
	
	
*/
cap log close

global DATA_EDITION 130723
global EDITION 130812

local discharge_var aha_admits


set more off
clear all

********************
*	Data Prep
********************


use ../dta/hIT-combineddata

cap drop temp*
ren netoperrev netoperrev

gen emr_miss = emr_frac==.


foreach var in qual_mcd qual_mcr sh10 {
	gen `var'_post = `var'*post
}

gen qual_both = qual_mcr*qual_mcd
gen qual_both_post = qual_both*post

gen bene_post = bene_tot*post


* Norm benefits by some size metrics
foreach var in netoperr beds_h ftetotal {
	gen temp = `var' if year==2009
	gen temp2 = `var' if year==2008
	bys id: egen `var'_09 = max(temp)
	bys id: egen temp3 = max(temp2)
	replace `var'_09 = temp3 if `var'_09==.
	drop temp*
}

gen bene_rev = bene_tot/netoperr_09
gen bene_beds = bene_tot/beds_h_09
gen bene_fte = bene_tot/(ftetotal_09*1e6)

xtsum bene_rev-bene_fte


***** Categorization variables


foreach var in bene_rev bene_beds bene_fte bene_tot netoperrev beds_h {
	xtile temp1 = `var' if year==2009, n(5)
	bys id: egen `var'_group = max(temp1)
	summ `var'_group
	drop temp*
}

/*

***********************
*	Summary Tables
***********************
gen qual_mcd_group = qual_mcd
replace netoperrev = netoperrev/1e6


	* Output tables of Benefits-by-beds joint distribution
cap log close
log using ../log/bene_tot-beds_joint.txt, text replace
bys year: tab bene_tot_group beds_h_group, cell nofreq
bys year: tab bene_tot_group beds_h_group
log close

log using ../log/bene_tot-beds_emr.txt, text replace
bys year: tab bene_tot_group beds_h_group, summ(emr_frac) nost nofreq
bys year: tab bene_tot_group beds_h_group if emr_frac!=.
log close

log using ../log/bene_tot-beds_emr100.txt, text replace
bys year: tab bene_tot_group beds_h_group, summ(emr_100) nost nofreq
bys year: tab bene_tot_group beds_h_group if emr_100!=.
log close



	* Output table for each Quintile basis variables
foreach var in netoperrev bene_tot beds_h  bene_rev bene_beds bene_fte qual_mcd {
	preserve
	
	collapse (mean) emr_miss emr_0 emr_25 emr_50 emr_75 emr_100 emr_frac mean=`var' ///
			(count) N=`var' ///
			(min) min=`var' ///
			(max) max=`var', ///
			by(`var'_group year)
			
	ren `var'_group quintile
	
		* Write own-variable summary tables to file
	local replace replace
	forval y=2008/2011 {
		sort quintile
		log using ../log/`var'_xtile_summ.txt, `replace' text
		
		list quintile mean N min max if year==`y' & quintile!=.
		log close
		local replace append
	}
	
		* Write EMR summary tables to file
	local replace replace
	forval y=2008/2011 {
		sort quintile
		
		log using ../log/`var'_emr_summ.txt, `replace' text
		list quintile emr_miss emr_0 emr_25 emr_50 emr_75 emr_100 emr_frac if year==`y' & quintile!=.
		log close
		local replace append
	}
	restore
}


*/


***********************
*	Pictures!
***********************

	* Collapse by Quintile bin of the given variable
foreach var in bene_tot beds_h netoperrev bene_rev bene_beds bene_fte {

		// Quintile basis labels
	if "`var'"=="bene_tot" local label "Total Program Pay"
	if "`var'"=="netoperrev" local label "Net Revenue"
	if "`var'"=="beds_h" local label "Beds (Hospital)"
	if "`var'"=="bene_rev" local label "Prog Pay per Net Rev"
	if "`var'"=="bene_beds" local label "Prog Pay per Bed (hospital)"
	if "`var'"=="bene_fte" local label "Prog Pay per FTE"
	if "`var'"=="qual_mcd" local label "Qualify for Medicaid Program"
		
		// Fix plot label options
	local mlabconfig "mlabel(`var'_group) mlabp(0) msize(medlarge) mc(white) mlabs(medlarge)"
	
	preserve
	
	keep if `var'_group!=.
*	collapse (mean) emr_frac emr_100 z_core z_read z_mort , by(year `var'_group)
	collapse (mean) emr_frac emr_100 z_core z_read z_mort , by(year)

	twoway connected emr_100 year
	asdf
	
	
		* Draw pictures for each y-axis variable
	foreach outcome in emr_frac emr_100 z_core z_read z_mort {
	
			// Outcome variable labels
		if "`outcome'"=="emr_frac" {
			local outcome_subtitle "Avg % of records electronic"
			local outcome_ytitle "Avg % EMR"
		}
		if "`outcome'"=="emr_100" {
			local outcome_subtitle "% of hospitals with >75% EMR"
			local outcome_ytitle "% with >75% EMR"
		}
		if "`outcome'"=="z_core" {
			local outcome_subtitle "Std Quality: Core measures"
			local outcome_ytitle "Avg z_core"
		}
		if "`outcome'"=="z_read" {
			local outcome_subtitle "Std Quality: Readmissions"
			local outcome_ytitle "Avg z_read"
		}
		if "`outcome'"=="z_mort" {
			local outcome_subtitle "Std Quality: Mortality"
			local outcome_ytitle "Avg z_mort"
		}
			// Plot and export
		twoway	(connected `outcome' year if `var'_group==1, `mlabconfig') ///
				(connected `outcome' year if `var'_group==2, `mlabconfig') ///
				(connected `outcome' year if `var'_group==3, `mlabconfig') ///
				(connected `outcome' year if `var'_group==4, `mlabconfig') ///
				(connected `outcome' year if `var'_group==5, `mlabconfig'), ///
			ti("`label', Quintiles") ///
			sub("`outcome_subtitle'") ///
			yti("`outcome_ytitle'") ///
			leg(	lab(1 "Quintile 1") ///
					lab(2 "Quintile 2") ///
					lab(3 "Quintile 3") ///
					lab(4 "Quintile 4") ///
					lab(5 "Quintile 5"))

		graph export ../gph/Quintiles-`outcome'-by-`var'.tif, replace
	}

	restore
	
}



