clear all
set more off

/*
	This file attempts to replicate the HIT variables in the ONCHIT March 2013 data brief.
*/

/*
	ONCHIT Data, 2012
		4539 hospitals surveyed, 2836 responses.
		
*/


use ../dta/himss_panel_full, clear

foreach var of varlist in_* {
	replace `var' = 0 if `var'==.
}



global IMPUTE = 2


***********************
** 		ONCHIT's definitions
***********************

/*	Sample:
	Acute care, non-federal general medical and surgical, children's general, and cancer hospitals.
*/

gen general = regexm(type,"General")
replace type = "General" if general==1
replace type = "Pedatric" if regexm(type,"edatric")
replace type = "Oncology" if regexm(type,"ncology")

keep if inlist(type,"Oncology","General","Pediatric") & haentitytype=="Hospital"






/* our_basic EHR (w/ clinician notes)
	Requires:
		Elect Clinic Info
		1) Patient demographics		[data repos]
		2) *Clinician notes			[phys document]
		3) Problem lists			[data repos]
		4) Medication lists			[data repos]
		
		CPOE
		5) Medications				[CPOE]
		
		Results Management (get from PACSInfo? UseofITComponent?)
		6) View lab reports			[]
		7) View radiology repots
		8) View diagnostic test results	
*/

if $IMPUTE>=1 {
	gen our_basic = app_data_repos==1 & app_cpoe==1 if in_app==1
	gen our_basic_notes = our_basic * (app_doc_doc==1) if in_app==1
}
else {
	gen our_basic = app_data_repos==1 & app_cpoe==1 if app_data_repos<. & app_cpoe<.
	gen our_basic_notes = our_basic * (app_doc_doc==1) if our_basic!=. & app_doc_doc<.
}

/* Certified EHR
	According to notes to Figure 1, "Certified" is "certified as meeting federal requirements for some or all of the hospital objectives of Meaningful Use."
*/

if $IMPUTE==2 gen our_certified = inlist(1,app_data_repos,app_cds,app_cpoe,app_doc_doc,app_nurs_doc,app_emar) if in_app==1
else if $IMPUTE==1 gen our_certified = inlist(1,app_data_repos,app_cds,app_cpoe,app_doc_doc,app_nurs_doc,app_emar) ///
	if !(app_data_repos==. & app_cds==. & app_cpoe==. & app_doc_doc==. & app_nurs_doc==. & app_emar==.)
else gen our_certified = inlist(1,app_data_repos,app_cds,app_cpoe,app_doc_doc,app_nurs_doc,app_emar) if !inlist(.,app_data_repos,app_cds,app_cpoe,app_doc_doc,app_nurs_doc,app_emar)



/* 					Comprehensive
	Requires:
		Elect Clinic Info
		1) Patient demographics		[app data repos]
		2) Physician notes			[app phys document]
		3) Nursing assessments		[app nurs_doc]
		4) Problem lists			[app data repos]
		5) Medication lists			[app data repos]
		6) Discharge summaries		
		7) Advance directives
		
		CPOE
		8) Lab reports				[comp_results]
		9) Radiology tests			[comp_results]
		10)Medications				[app_emar]
		11)Consultation requests
		12)Nursing orders			[app_emar]
		
		Results Management 				overall:[pacs_imgdist]
		13)View lab reports			
		14)View radiology repots
		15)View radiology images
		16)View diagnostic test results 
		17)View diagnostic test images
		18)View consultant report
		
		Decision support			overall: [cds]
		19)Clinical guidelines			[cdss_guide]
		20)Clinical reminders		
		21)Drug allergy results			[cdss_drug_inter]
		22)Drug-drug interactions		"
		23)Drug-lab interactions		"
		24)Drug dosing support			[cdss_dose]
		

	"our_comprehensive" must have following variables
	data_repos, doc_doc, nurs_doc, cpoe, pacs_imgdist, cds, 
	tables used : applications, pacs
	
	refinements:
	after 2009: cdss_guide, cdss_drug_inter, cdss_dose
	largely missing: comp_results
*/
if $IMPUTE==2 {
	gen our_comprehensive = app_data_repos==1 & app_doc_doc==1 & app_nurs_doc==1 & app_cpoe==1 & app_cds==1 & app_emar==1 & pacs_imgdist==1 if in_app==1 & in_pacs==1
	gen our_compre_2009 = our_comprehensive==1 & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 if our_comprehensive!=. & in_cdss==1
	gen our_compre_result = our_comprehensive==1 & inrange(comp_results,1,100) if our_comprehensive!=. & in_comp==1
	gen our_compre_result2009 = our_comprehensive==1 & inrange(comp_results,1,100) & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 if our_comprehensive!=. & in_cdss==1 & in_comp==1
}
else {
	gen our_comprehensive = app_data_repos==1 & app_doc_doc==1 & app_nurs_doc==1 & app_cpoe==1 & app_cds==1 & app_emar==1 & pacs_imgdist==1 ///
		if !inlist(.,app_data_repos,app_doc_doc,app_nurs_doc,app_cpoe) & pacs_imgdist!=.
	gen our_compre_2009 = our_comprehensive==1 & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 ///
		if our_comprehensive!=. & !inlist(.,cdss_guide,cdss_drug_int,cdss_dose)
	gen our_compre_result = our_comprehensive==1 & inrange(comp_results,1,100) ///
		if our_comprehensive!=. & comp_results!=.
	gen our_compre_result2009 = our_comprehensive==1 & inrange(comp_results,1,100) & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 ///
		if our_comprehensive!=. & comp_results!=. & !inlist(.,cdss_guide,cdss_drug_int,cdss_dose)
}


************************
**	Re-create data brief
************************

ren state stateabb
merge m:1 stateabb using ../../state_xwalk
tab stateabb if _merge==1
keep if _merge==3
drop _merge

cap log close
log using ../out/onchit-main_impute$IMPUTE.txt, text replace
*****	FIGURE 1
di as err "Figure 1"
table year, c(mean our_basic_notes mean our_cert N haentityid)
/*
asdf
*/


****	TABLE 1
summ our_basic_note our_certified if year==2011
table state if year==2011, c(mean our_basic_note mean our_certified N haentityid)

asdf
*/

****	FIGURE 3
gen only_our_basic = our_basic==1 & our_basic_notes==0 & our_comprehensive==0 & !inlist(.,our_basic,our_basic_notes,our_comprehensive)
gen only_our_basic_notes = our_basic_notes==1 & our_comprehensive==0 & !inlist(.,our_basic,our_basic_notes,our_comprehensive)
gen only_our_comprehensive = our_comprehensive==1 & !inlist(.,our_basic,our_basic_notes,our_comprehensive)

table year if !inlist(.,our_basic,our_basic_notes,our_comprehensive), c(mean only_our_basic mean only_our_basic_notes mean only_our_comprehensive mean our_basic N haentityid) csepwidth(4) cellwidth(8)


table year, c(mean our_comprehensive N our_comprehensive mean our_compre_result N our_compre_result N haentityid) csepwidth(4) cellwidth(8)
table year if year>=2009, c(mean our_compre_2009 N our_compre_2009 mean our_compre_result2009 N our_compre_result2009 N haentityid) csepwidth(4) cellwidth(8)
/*

*/
log close
******************
**	Other tables and plots
******************

***		SUMMARY STATS
cap log close
log using ../out/onchit-summStats_impute$IMPUTE.txt, text replace

tab year type
table year, c(mean in_app mean in_cdss mean in_comp mean in_pacs N haentityid) csepwidth(3) cellwidth(6)
table year, c(mean in_cdss mean in_comp mean in_pacs N haentityid) by(type) csepwidth(3) cellwidth(6)

summ haentityid year nofbeds ftetotal payroll ahaadmiss emr rev* app_* pacs_* cdss_* comp_* our_* if year==2011

log close

/*
asdf
*/

***		Figure 1


collapse (mean) our_*, by(year)

/* Yearly plot from ONCHIT, our_basic w/ notes
	2008	9.4
	2009	12.2
	2010	15.6
	2011	27.6
	2012	44.4
*/

foreach var of varlist our_* {
	replace `var' = `var'*100
}

local onemoreob = `=_N' + 1
set obs `onemoreob'
replace year = 2012 if year==.

gen onchit_basic_notes = .
replace onchit_basic_notes = 9.4 if year==2008
replace onchit_basic_notes = 12.2 if year==2009
replace onchit_basic_notes = 15.6 if year==2010
replace onchit_basic_notes = 27.6 if year==2011
replace onchit_basic_notes = 44.4 if year==2012

twoway connected our_basic_notes onchit_basic_notes year
graph export ../gph/onchit-figure1_impute$IMPUTE.png, replace

twoway connected our_compre* year
graph export ../gph/onchit-comprehensives_impute$IMPUTE.png, replace

twoway connected our_basic* year
graph export ../gph/onchit-our_basics_impute$IMPUTE.png, replace


