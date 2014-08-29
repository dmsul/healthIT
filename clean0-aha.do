clear all
set more off
/*
	This file cleans the AHA data extract provided 130712.

	full-time equivalent variables? E.g., FTED vs FTEMD.
	
	1) Merge on "id", AHA id key
		
*/

* Data paths
global AHA_PATH "/homes/nber/sullivan/aha.work/"


* Parameters
global YEARLIST 2005/2011



tempfile foundation
save `foundation', emptyok


global CORE_VARS id dtbeg dtend radmchi admtot ipdtot admh ipdh mcrdc mcripd mcddc mcdipd mcrdch mcripdh mcddch mcdipdh bdlt admlt ipdlt madmin mlocaddr mcrnum fcounty dbegm dbegy dendm dendy dcov cntrl serv mname mloczip mstate subs sunits hospbd paytot plnta adepra assnet gfeet ceamt fte* 

* keep mcrnum fcounty dbegm dbegy dendm dendy dcov cntrl serv mname mloczip mstate subs sunits hospbd paytot admtot ipdtot tehsp teint tetot  mmbtr ehlth plnta adepra assnet gfeet ceamt mmbtu fte*

foreach y of numlist $YEARLIST {
	di as err "******* YEAR PROCESSING: `y' ******"
	use "$AHA_PATH/data20130712/aha_extract`y'"
	
	cap summ ehlth
	
	**** Adapt to changing variables over years
	
	if `y' <2007 {
		keep $CORE_VARS hspft hsppt 
	}
	
	if `y'==2007 {
		/*  add 'ehlth' et al, electronic health records dummies
			add 'emeds' and 'elabs'
			add hospitalists FTE */
		keep $CORE_VARS  hsppt  ///
		hspft ///
		ehlth* emeds elabs ftehsp
	}
	
	if `y'==2008 {
		/* add intensivists */
		keep $CORE_VARS  hsppt  ///
		ehlth* emeds elabs ftehsp ///
		hspft ///
		fttinta pttinta fteint ///
		npi npinum
	}
	
	if `y'==2009 {
		/* remove 'emeds' */
		keep $CORE_VARS  hsppt  ///
		ehlth* ftehsp ///
		hspft ///
		fttinta pttinta fteint ///
		npi npinum
	}
	
	if `y'>=2010 {
		/* Change hospitalists from 'hspft' to 'ftehsp', FTE not FT 
			Remove 'hsppt', part time hospitalists 
			Remove intensivists, except FTE */
		keep $CORE_VARS   ///
		ftehsp ///
		ehlth* ftehsp ///
		npi npinum
		
	}
	
	
	***** (De)String stuff so data types match
	
	if `y'==2008 {
		destring ehlth* emeds elabs, replace
	}
	
	if inlist(`y',2009) {
		egen temp = ends(mloczip), h p("-")
		drop mloczip
		destring temp, gen(mloczip)
		drop temp
		
		destring ehlth* , replace
		
	}
	
	if inlist(`y',2010,2011) {
		egen temp = ends(mloczip), h p("-")
		drop mloczip
		destring temp, gen(mloczip)
		drop temp
		
		* Fix stupid ehlth entries for now
		replace ehlth = "3" if ehlth=="N"
		destring ehlth , replace
		label define ehlthcrap 3 "This was 'N' in raw data"
		label values ehlth ehlthcrap		
	}
	
	
	destring sunits subs serv cntrl mloczip radmchi , replace
	
	cap destring npinum, replace
	
	gen surveyyear = `y'
	
	append using `foundation'
	save `foundation', replace	
}

****************************************
**	Sample selection for healthIT project
****************************************
drop if inrange(cntrl,41,48)	// Federal hosptials



****************************************
**  Clean panel variables(id var and year var)
****************************************

ren mcrnum hosp_id
egen sid = group(id)
egen hid = group(hosp_id)
egen nameid = group(mname mstate)

* Assign correct year by data coverage

// Fix CCN data entry errors
replace hosp_id = "150151" if id=="6910014"


// Fix unambiguous data entry errors for data coverage dates
replace dtbeg = "07/01/2010" if dtbeg=="07/01/2110"
replace dtbeg = "10/01/2010" if dtbeg=="10/01/2020"

replace dtbeg = "10/01/2008" if id=="6370610" & surveyyear==2009
replace dtbeg = "07/01/2007" if id=="6810530" & surveyyear==2008
replace dtbeg = "01/01/2010" if id=="6370022" & surveyyear==2010
replace dtbeg = "10/01/2007" if id=="6549030" & surveyyear==2008
replace dtbeg = "10/01/2009" if id=="6549030" & surveyyear==2010
replace dtbeg = "04/01/2009" if id=="6210510" & surveyyear==2009

replace dtend = "12/31/2010" if id=="6370022" & surveyyear==2010
replace dtend = "12/31/2010" if id=="6459010" & surveyyear==2011
replace dtend = "12/31/2011" if id=="6611040" & surveyyear==2011
replace dtend = "12/31/2009" if id=="6540509" & surveyyear==2010
replace dtend = "09/30/2010" if id=="6540607" & surveyyear==2010
replace dtend = "09/30/2009" if id=="6540012" & surveyyear==2010
replace dtend = "07/31/2009" if id=="6540752" & surveyyear==2009
replace dtend = "09/30/2008" if id=="6549030" & surveyyear==2008
replace dtend = "09/30/2010" if id=="6549030" & surveyyear==2010
replace dtend = "03/31/2010" if id=="6210510" & surveyyear==2009


forval year=2007/2011 {
	local year1 = `y'+1
	local year_1 = `y'+1
	replace dtend = "09/30/`year1'" ///
		if dtbeg=="10/01/`year'" & dtend=="09/30/`year'" & surveyyear==`year'+1
	replace dtbeg = "10/01/`year_1'" ///
		if dtbeg=="10/01/`year'" & dtend=="09/30/`year'" & surveyyear==`year'
	
}

	***		 Make corrections to data year when possible
gen start = date(dtbeg,"MDY")
gen end = date(dtend,"MDY")
gen length = end - start

forval y=2006/2012 {
	gen front`y' = min(end,mdy(12,31,`y')) - start if year(end)>=`y' & year(start)==`y'
	gen back`y' = end - max(start,mdy(1,1,`y')) if year(end)==`y' & year(start)<=`y' & year(start)!=year(end)
	
	egen sum`y' = rowtotal(front`y' back`y')
	replace sum`y' = . if sum`y'==0
}
sort id surveyyear
//browse id surveyyear dtbeg dtend length sum* if dtbeg!=""

xtset sid surveyyear
xtdescribe

gen myyear = surveyyear

egen rowsum = rowtotal(sum*)
egen maxsum = rowtotal(sum*)


gen offyear = 0
forval y=2008/2011 {
	replace offyear = 1 if myyear==`y' & sum`y'<95 & sum`y'<maxsum
}
tab offyear
bys id: egen hasoff = max(offyear)

gen hasdate = dtbeg!=""
bys id: egen datecount = sum(hasdate)
bys id: egen offcount = sum(offyear)

// [This replace good, all survey dates ending Feb or March, DMS 8/26/13]
replace myyear = myyear - 1 if offcount==datecount & offcount>2 & offcount<.


replace offyear = 0
forval y=2008/2011 {
	replace offyear = 1 if myyear==`y' & sum`y'<95 & sum`y'<maxsum
}
tab offyear

// Replace all offyear guys with year - 1
replace myyear = myyear - 1 if offyear==1
**** If duplicate and previous year does have date, pick one that better represents that year.
bys id myyear: gen t = _N
tab t
drop if t==2
drop t

drop hasdate datecount offcount offyear

xtset sid myyear
xtdescribe
ren myyear year

***************************
**	Content variable cleaning
***************************

rename mname name_aha

* Fix weird ehlth values
replace ehlth = 0 if ehlth==3

replace mcripdh = -mcripdh if mcripdh<0
replace mcdipdh = . if mcdipdh<0

* Eliminate long-term care numbers
replace admh = admtot if admh==.
replace ipdh = ipdtot if ipdh==.
foreach var in mcrdc mcripd mcddc mcdipd {
	replace `var'h = `var' if `var'h==.
}
gen beds_h = hospbd
replace beds_h = beds_h - bdlt if bdlt!=.

summ admh ipdh mcrdc* mcripd* mcddc* mcdipd* beds_h


summ ehlth radmchi admh ipdh beds_h mcrdch mcripdh mcddch mcdipdh assnet

gen x=1

gen hasserv10 = serv==10

collapse	(mean) serv ///
			(sd) sdserv = serv ///
			(max) hasserv10 ehlth radmchi npi ///
			(rawsum) x paytot admh ipdh beds_h mcrdch mcripdh mcddch mcdipdh, ///
			[aw=beds_h] by(hosp_id year)



save $AHA_PATH/dta/hIT-aha-clean, replace

