/*
	Cleans data of who got paid by Medicaid EMR program
*/

clear all

insheet using ../src/EHs_PaidByEHRProgram_March2013_FINAL.csv



ren providerccn hosp_id
tostring hosp_id, replace
replace hosp_id = "0" + hosp_id if length(hosp_id)<6
replace hosp_id = substr(hosp_id,1,6) if length(hosp_id)>6
count if length(hosp_id)!=6
drop if length(hosp_id)!=6

forval i=2011/2013 {
	gen temp`i' = programyear`i'!=.
	bys hosp_id: egen ehr_prog`i' = max(temp`i')
}

keep hosp_id ehr*

duplicates drop

gen year = 2011

save ../dta/temp-ehrprog, replace


