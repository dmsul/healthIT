/*
	This file tries to replicate other paper's summary stats of HIMSS data.

	
*/


use ../dta/himss_panel_full, clear

*****************************
*	Agha's Data
*****************************


/*
	Agha says "HIT=1 if CDS or EMR is contracted"
	We'll say, roughly, CDS or EMR is live, to be replaced, installing, or contracted only. Impossible to know for sure.
	
	Agha gives a value of roughly 78% for 2004, see Table 1, (always have IT + switchers) / total
	
*/

tab cds ent_emr if year==2005, cell nofreq
gen agha_hit = inlist(cds,1,2,3,4) | inlist(ent_emr,1,2,3,4)

tab year agha_hit if regexm(type,"General"), row nofreq


*****************************
*	McCullough et al's Data
*****************************

/*
	McCullough, Parente, and Town (2013 working) treat EMR and CPOE separately. Again, I assume they use the straight "EMR" variable. I'm also not sure exactly which status they use. Different subsample?

	Their figure 1 gives roughly the following
			EMR		CPOE
	2005	32%		15%
	2006	33%		17%
	
*/

*****************************
**		Sample Selection
*****************************
/*
	They exclude critical access, veterans, psychiatric, and sub-acute hospitals. "Panel of about 4,000 hospitals." They use 2,953 (see Table 3), from AHA and HIMSS.

*/

drop if regexm(haentitytype,"Data Center") | haentitytype=="Sub-Acute"
drop if type=="Critical Access"


tab year if hosp_id!=""

tab ent_emr year if hosp_id!="", col nofreq miss
tab cpoe year if hosp_id!="", col nofreq miss 


tab ent_emr year if hosp_id!="" if regexm(type,"General"), col nofreq miss
tab cpoe year if hosp_id!="" if regexm(type,"General"), col nofreq miss 





