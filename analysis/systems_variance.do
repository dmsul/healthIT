set trace off
set more off
clear all

run src/globals

global out ../out/1501

global LHV_z z_core z_read z_mort
global LHV_hospcomp z_scipinf3 z_scipvte2 z_vte5 z_stk4 z_pn7
global LHV_1st our_basic_notes our_comprehensive

prog def _set_resid
    args suffix

    global r2_`suffix' = round(`e(r2)', .01)
    cap drop e_`suffix'
    predict e_`suffix' if e(sample), res
    qui summ e_`suffix', d
    replace e_`suffix'= . if !inrange(e_`suffix', `r(p1)', `r(p99)')
    global sig_`suffix' = round(`r(sd)', .001)
end

use $regready_dta

keep if year >= 2008

gen byte in_sys = sysid != ""
replace sysid = hosp_id if sysid == ""
bys sysid year: gen syssize = _N
bys sysid: egen syssizemin = min(syssize)
bys hosp_id: egen hosp_syssizemin = min(syssizemin)


* Restrict to big systems
gen is_bigsys = syssizemin >= 5
bys hosp_id: egen has_bigsys = max(is_bigsys)
keep if has_bigsys == 1

foreach lhv in $LHV_1st $LHV_z $LHV_hospcomp {

    capture { // XXX last minute fix for "no obs"
        reg `lhv' i.year
        _set_resid "std"

        areg `lhv' i.year, a(sysid)
        _set_resid "sys"

        areg `lhv' i.year, a(hosp_id)
        _set_resid "hosp"

        twoway (kdensity e_std) (kdensity e_sys) (kdensity e_hosp), ///
               title("`lhv'") legend(lab(1 "none") lab(2 "system") lab(3 "hosp") row(1)) ///
               caption("{&sigma}{sub:{&epsilon}}: $sig_std, $sig_sys, $sig_hosp") ///
               note("R{sup:2}: $r2_std, $r2_sys, $r2_hosp")
        graph export $out/sysvariance_`lhv'.png, replace width(1500)
    }
}
