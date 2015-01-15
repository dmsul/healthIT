set trace off
set more off
clear all

run src/globals

use $regready_dta
gen byte in_sys = sysid != ""
replace sysid = hosp_id if sysid == ""
bys sysid year: gen syssize = _N


