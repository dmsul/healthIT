clear all
set more off
/*
	This file creates a panel abstract from the NBER stash of HIMSS data
	and puts it in the designated user fileon the NBER UNIX server.
	
	Basic CPOE and EHR variables first appear in 2008 data.

	
*/

* OS paths
global SRCPATH /homes/data/himss
global MY_SRCPATH /homes/nber/sullivan/himss.work/

* Data parameters
global STARTYEAR 2005 
global TABLES cpoedept order CDSS comp pacs

*********************
**	Dataset variables
*********************
/* Base global is for start year 2008. Other variables added as necessary */

	*HA Entity variables

global HAEntityKeep /// 
			uniqueid haentityid medicarenumber parentid /// ID: panel, x-sec, outside data
			name address1 city state zip cbsa parentid type profitstatus haentitytype ///
			nofbeds ftetotal 

global addToHAEntityKeep2006 phystotal

	* Parent Info variables
global ParentInfoKeep /// 
			annualopcost annualrevenue ///
			dateofdata /// 
			isplan isplanyear ///
			physft
			
global addToParentInfoKeep2011 isbudget

	* Acute Info variables
global AcuteInfoKeep haentityid ///
			nofadjpatientdays nofadjdischarge /// 
			netoperrevenue totaloperexpense 

global addToAcuteInfo2008 electronicmedrecperc cpoephysicianperc ///
							revmanagedcare revmedicaid revmedicare revother revtradcomm ///
							noftotpatientdays noftotdischarge
global addToAcuteInfo2009 nofnurses 
global addToAcuteInfo2010 ahaadmissions orgcontroldetail orgcontroloverall payrollexpense cdssdataintegrated
global addToAcuteInfo2011 isbudget



***************************************
* Load 'Use of IT Dept'
***************************************

/*
	Table discontinued after 2007
*/

clear all
tempfile cpoedept
save `cpoedept', emptyok

foreach year of numlist $STARTYEAR/2007 {
	
	di as err "On year `year'"
	
	use $SRCPATH/`year'/UseOfITDepartment, clear
	
	gen name = "oth"
	replace name = "all" if regexm(department,"All")
	
	
	keep haentityid name
	duplicates drop
	gen cpoedept_ = 1
	reshape wide cpoedept_, i(haentityid) j(name) string
	
	gen in_cpoedept = 1
	gen year = `year'
	
	append using `cpoedept'
	save `cpoedept', replace
	
}


***************************************
* Load 'Use of IT Order'
***************************************

/*
	Discontinued after 2007.
*/

clear all
tempfile order
save `order', emptyok

foreach year of numlist $STARTYEAR/2007 {
	
	di as err "On year `year'"
	
	use $SRCPATH/`year'/UseOfITOrder, clear
	
	gen order = "oth"
	replace order = "all" if regexm(orderdesc,"All")
	replace order = "diag" if regexm(orderdesc,"Diagnostic")
	replace order = "lab" if regexm(orderdesc,"Laboratory")
	replace order = "rx" if regexm(orderdesc,"Prescription")
	replace order = "care" if regexm(orderdesc,"Patient care")
	
	keep haentityid order
	duplicates drop
	gen order_ = 1
	reshape wide order_, i(haentityid) j(order) string
	
	gen in_order = 1
	gen year = `year'
	
	append using `order'
	save `order', replace
	
}

***************************************
* Load 'CDSS'
***************************************

/*
*/

clear all
tempfile CDSS
save `CDSS', emptyok

foreach year of numlist 2009/2011 {

	di as err "On year `year'"
	
	use $SRCPATH/`year'/CDSS, clear
	
	
	gen process = "oth"
	replace process = "guide" if regexm(processdesc,"guidelines")
	replace process = "dose" if regexm(processdesc,"dosing")
	replace process = "drug_int" if regexm(processdesc,"Drug inter")
	
	keep haentity process
	duplicates drop
	
	gen cdss_ = 1
	reshape wide cdss_, i(haentityid) j(process) string
	
	
	gen in_cdss = 1
	gen year = `year'
	
	append using `CDSS'
	save `CDSS', replace
	
}

***************************************
* Load 'UseofITComponents'
***************************************

/*
	Years 2006 and 2007 seem to have self-imputed missings as zeros.
	Other years have virtually no zeros.
*/

clear all
tempfile comp
save `comp', emptyok

foreach year of numlist $STARTYEAR/2011 {

	di as err "On year `year'"
	
	use $SRCPATH/`year'/UseOfITComponent, clear
	
	gen my_comp = "oth"
	if `year' <2008 {
		replace my_comp = "chart" if component=="CDR"
		replace my_comp = "results" if component=="Laboratory"
		replace my_comp = "results" if component=="Radiology"
		replace my_comp = "orders" if regexm(component,"Order Entry")
	}
	else {
		replace my_comp = "results" if regexm(component,"Results")
		replace my_comp = "orders" if regexm(component,"Orders")
		replace my_comp = "chart" if regexm(component,"Chart")
	}
	
	if `year'>=2007 {
		replace perc = "17" if perc=="1-25%"
		replace perc = "33" if perc=="26-50%"
		replace perc = "67" if perc=="51-75%"
		replace perc = "92" if perc=="76-100%"
		destring perc, replace
	}
	
		
	collapse (max) perc , by(haentityid my_comp)
	
	rename perc comp_
	
	reshape wide comp_, i(haentityid) j(my_comp) string
	
	gen in_comp = 1
	gen year = `year'
	
	append using `comp'
	save `comp', replace
	
}


***************************************
* Load 'PACS info'
***************************************

/*
	Years 2006 and 2007 seem to have self-imputed missings as zeros.
	Other years have virtually no zeros.
*/

clear all
tempfile pacs
save `pacs', emptyok

foreach year of numlist $STARTYEAR/2011 {

	di as err "On year `year'"
	
	use $SRCPATH/`year'/PACSInfo, clear
	
	drop imgdistrothercomment 
	cap drop imgdistroutsideother

	if inlist(`year',2006,2007) egen img_dist = rowmax(imgdist*)
	else {
		egen img_dist = rowmin(imgdist*)
		replace img_dist = -1*img_dist
	}
	
	
	keep haentityid type img_dist
	reshape wide img_dist, i(haentityid) j(type) string
	
	egen pacs_imgdist = rowmax(img_dist*)
	
	keep haentityid pacs_imgdist
	gen in_pacs = 1
	gen year = `year'
	
	append using `pacs'
	save `pacs', replace	
}


***************************************
* Load software 'Application' table, make wide
***************************************
/*
/*			CHANGES IN THE DATA OVER TIME
	2007:
		'medical terminology' eliminated 
		'enterprise EMR' changed to 'EMR'
		
	2009:
		'EMR' eliminated
		'physician portal' added

*/
clear all
tempfile crap_data
save `crap_data', emptyok
summ

foreach year of numlist $STARTYEAR/2011 {

	di as err "On year `year'"
	
	use $SRCPATH/`year'/HAEntityApplication, clear
	
	keep haentityid application category status contractyear
	
	* Make strings uniform
	replace application = lower(application)
	replace status = lower(status)
	replace category = lower(category)
	
	* Consolated application names, will be variable names
	global EMRAPPS data_repos cds cpoe ent_emr order_entry doc_doc med_termin doc_portal nurs_doc lab_is
	
	gen myapp = "oth"
		// EMR apps
	replace myapp = "data_repos" if application=="clinical data repository"
	replace myapp = "cds" if regexm(application,"clinical decision support")
	replace myapp = "cpoe" if regexm(application,"computerized practitioner order entry")
	replace myapp = "ent_emr" if inlist(application,"enterprise emr","emr")
	replace myapp = "order_entry" if regexm(application,"order entry \(includes")
	replace myapp = "doc_doc" if application=="physician documentation"
	replace myapp = "med_termin" if regexm(application,"medical terminology")
	replace myapp = "doc_portal" if regexm(application,"physician portal")
	
		// Nursing apps
	replace myapp = "nurs_doc" if regexm(application,"nursing doc")
	replace myapp = "emar" if regexm(application,"(emar)")
	
		// Laboratory apps
	replace myapp = "lab_is" if regexm(application,"laboratory information")
	


	
	* Numerical status, higher number more "useful"
	gen app_ = .
	replace app_ = 1 if regexm(status,"live")
	replace app_ = 2 if regexm(status,"replaced")
	replace app_ = 3 if regexm(status,"installation in")
	replace app_ = 4 if regexm(status,"contracted/not")
	replace app_ = 5 if regexm(status,"not yet contracted")
	replace app_ = 6 if regexm(status,"not automated")
	replace app_ = 7 if regexm(status,"service not provided")
	replace app_ = 99 if regexm(status,"not reported")
	
	label def stati 1 "Live" 2 "To be Replaced" 3 "Installing" 4  "Contracted only" 5 "Not yet contracted" 6 "Not automated"  7 "Service not provided" 99 "Not reported" 9999 "Missing"
	label val app_ stati
		
	* Total obs in data
	egen apps_in_data = count(haentityid), by(haentityid)

	
	* Verify that nothing weird is happening
	/*
	tab status app_, miss
	tab application myapp, miss
	assert app_!=. if category=="electronic medical records"
	summ 
	*/
	quiet{
	* Eliminate duplicates, take "best" status
	duplicates drop
	bys haentityid myapp: gen myapp_n = _N
	
	bys haentity myapp (app_): keep if _n==1
	
	bys haentityid myapp: gen n2 = _N
	assert n2==1
	drop myapp_n n2
	
	
	* Reshape wide
	drop application category status
	
	ren contractyear contract_
	
	reshape wide app_ contract_ , i(haentityid) j(myapp) string
	
	gen in_app = 1
	
	summ
	}
	append using `crap_data'
	save `crap_data', replace
	
	di as err "This is after year `year' was appended to app data"
	summ
	
	
}
save ../dta/temp_app_data, replace
summ

*/




*************************************************************
** Load HAEntity to use as base, merge within year, append years
*************************************************************

set more off
clear all

tempfile base
save `base', emptyok

foreach year of numlist $STARTYEAR/2011 {

	di as err "*** LOOP YEAR: `year' *****"
	
	* Use 'HA Entity' as base
	use $SRCPATH/`year'/HAEntity, clear

	* Wanted variables
	global HAEntityKeep $HAEntityKeep ${addToHAEntityKeep`year'}
	keep $HAEntityKeep
	destring ftetotal, replace
	
		** Mergin in other tables **
		
	* AcuteInfo
	di as err "Merge table AcuteInfo"
	
		// Adjust variable list by year
	global AcuteInfoKeep $AcuteInfoKeep ${addToAcuteInfo`year'}
	
	merge 1:1 haentityid using $SRCPATH/`year'/AcuteInfo, keepusing($AcuteInfoKeep)
	assert _merge!=2
	rename _merge _m_HAEntity
	
	cap ren isbudget isbudget_own
	
	
	* Parent Info
	/*
			// Keep variable only in first year
		if `year'==2008 local datacenter datacenter
		else local datacenter
		
			// Add new variables each year as needed
		global ParentInfoKeep ${ParentInfoKeep} ${addToParentInfo`year'}
		
		* Merge in table'
		di "Merge table ParentInfo"
		merge m:1 parentid using $SRCPATH/`year'/ParentInfo, keepusing(${ParentInfoKeep} `datacenter')
		drop if _merge==2
		rename _merge _m_ParentInfo
	
	if `year' < 2011 {
		egen dateonly = ends(dateofdata), h p(" ")
		drop dateofdata
		gen dateofdata = date(dateonly,"mdy")
	}
	*/
	
	
	cap ren isbudget isbudget_parent
	cap ren isbudget_own isbudget
	
	gen year = `year'
	di as err "Append thru `year' to base"
	append using `base'
	save `base', replace
}


***************************
**	Merge on other tables
***************************


* Applications
merge 1:1 haentityid using ../dta/temp_app_data
assert _merge!=2
ren _merge _m_apps

foreach table in $TABLES {

	di as err "Merge in `table'"
	merge 1:1 haentityid using ``table''
	assert _merge!=2
	ren _merge _m_`table'
	
}

**********************
*	Variable Cleaning
**********************
* Rename to merge with other data
ren medicarenumber hosp_id

* Fill in CCN manually from AHA
replace hosp_id = "041331" if uniqueid==53159 & year==2008
replace hosp_id = "030123" if uniqueid==51023
replace hosp_id = "030128" if uniqueid==60424
replace hosp_id = "220074" if inlist(uniqueid,10133,10134)
replace hosp_id = "080001" if uniqueid==10679
replace hosp_id = "340141" if uniqueid==10916
replace hosp_id = "100316" if uniqueid==11189
replace hosp_id = "100088" if uniqueid==11214
replace hosp_id = "520021" if uniqueid==11395
replace hosp_id = "060031" if inlist(uniqueid,11522,56160,11524)
replace hosp_id = "420026" if uniqueid==11947
replace hosp_id = "050663" if uniqueid==12425
replace hosp_id = "450058" if inlist(uniqueid,12714,12716,12728,12729,64397)
replace hosp_id = "310039" if uniqueid==13499
replace hosp_id = "440168" if inlist(uniqueid,14538,14541,14542)
replace hosp_id = "440091" if uniqueid==14726
replace hosp_id = "040007" if uniqueid==14801
replace hosp_id = "150151" if uniqueid==56253
replace hosp_id = "190041" if uniqueid==14881
replace hosp_id = "450046" if inlist(uniqueid,14905,14904) // The second number is weird. It has a CCN listed here, but in no other dataset does it exist, even online.
replace hosp_id = "200039" if uniqueid==16982
replace hosp_id = "390156" if uniqueid==17096
replace hosp_id = "030126" if inlist(uniqueid,57679,62094)
replace hosp_id = "030129" if uniqueid==61436 & year==2010
replace hosp_id = "031316" if uniqueid==61436 & year==2011
replace hosp_id = "030120" if uniqueid==63660
replace hosp_id = "030130" if uniqueid==61846
replace hosp_id = "050295" if uniqueid==17721
replace hosp_id = "051325" if uniqueid==46873
replace hosp_id = "050454" if uniqueid==51403


* Keep only general hospitals
*keep if regexm(type,"General Medical")

* Ownership dummies
gen owner = .
replace owner = 1 if regexm(orgcontroloverall,"Investor")
replace owner = 2 if regexm(orgcontroloverall,"non-for")
replace owner = 3 if regexm(orgcontroloverall,"non-fed")


* Fill in missing Medicare ID's

bys uniqueid (year): gen rep = _n==1

// Test for changing Medicare ID. "test==." means only 1 non-miss ob
egen id = group(hosp_id)
bys uniqueid: egen testid = sd(id)	

bys uniqueid (hosp_id): replace hosp_id = hosp_id[_N] if hosp_id=="" & inlist(testid,0,.)
bys uniqueid (year): replace hosp_id = hosp_id[_n+1] if hosp_id=="" & hosp_id[_n+1]!="" & year==$STARTYEAR

// Check for remaining spots we can fill in
gen missid = hosp_id==""
bys uniqueid: egen hasmiss = max(missid)

bys uniqueid: gen N = _N
gen mid = hosp_id==""
order N unique hosp_id year name state zip address1
compress
sort state city uniqueid year

/*
browse N year name uniqueid hosp_id state city zip address1 parentid nofbeds if hasmiss
asdf // END HERE for manual matching of CCN's
*/


// Drop if Medicare ID missing from all years
*drop if allmiss
drop hasmiss missid id testid

* Fill in missing Ownership types
bys uniqueid: egen testown = sd(owner)
bys uniqueid (owner): replace owner = owner[1] if owner==. & inlist(testown,0,.)

gen miss = owner==.
bys uniqueid: egen hasmiss = max(miss)
bys uniqueid: egen allmiss = min(miss)

tab hasmiss if rep & !allmiss

drop hasmiss allmiss miss test

cap drop rep

* EMR & CPOE
egen emr_frac = ends(electronic), t p("-")
destring emr, replace i("%")

/*
egen cpoe_frac = ends(cpoe), t p("-")
destring cpoe_frac, replace i("%")
*/


**********************
* Final housekeeping
**********************
/*
foreach var in annualopcost annualrevenue dateofdata isplan isplanyear physft {
	rename `var' parent_`var'
}
*/


**********************
** Save files
**********************


save ../dta/himss_panel_full, replace

* Restrict sample
drop haentityid
bys uniqueid: egen wt = mean(totalopere)
gen y = 1

replace hosp_id = "MISS_" + string(uniqueid) if hosp_id==""

collapse (mean) emr_frac rev* (min) app_*  (max) contract_* pacs_* cdss_* comp_* max_cds=app_cds max_cpoe = app_cpoe max_emr=app_ent_emr in_* (count) n_noftotdischarge = noftotdischarge n_netoperr=netoperr n_totaloperexp = totaloperexp n_ftetotal = ftetotal (rawsum) y apps_in_data ftetotal phystotal netoperr totaloperexp nof* ahaadmissions [pw=wt], by(hosp_id year) // /* (mean) cpoe_frac parent_* */
*/
tab emr, miss

gen temp = emr/25
replace temp = round(temp,1)
replace emr = temp*25

tab emr, miss


save ../dta/himss-extract, replace
