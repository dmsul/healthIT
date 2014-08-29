clear all

use ../dta/himss_panel_full, clear

bys hosp_id: gen rep = _n==1

gen general = regexm(type,"General")
replace type = "General" if general==1
replace type = "Pedatric" if regexm(type,"edatric")
replace type = "Oncology" if regexm(type,"ncology")

gen keeper = inlist(type,"Oncology","General","Pediatric") & haentitytype=="Hospital"

tab rep keeper

tab year keeper
