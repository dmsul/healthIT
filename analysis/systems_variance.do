args subroutine
set trace off
set more off
clear all

run src/globals
run main

global out $OUT_PATH

global LHV_z z_core z_read z_mort
global LHV_hospcomp z_scipinf3 z_scipvte2 z_vte5 z_stk4 z_pn7
global LHV_1st our_basic_notes our_comprehensive


prog def main_by_syssize
    /* For 150715 mtg */
    data_prep

    foreach minsize in 10 15 20 {
        foreach lhv in $LHV_1st $LHV_z $LHV_hospcomp {
            preserve
            local before = `=_N'
            _restrict_syssize, minsize(`minsize')
            local after = `=_N'
            noi di "Sample size before and after: `before' and `after'"
            plot_variance_guts `lhv' `minsize'
            restore
        }
    }

end

prog def main_by_ownership
    /* For 150715 mtg */
    data_prep

    * Fix ownership flags for mixed ownership types
    /* [5/14/15] 4 hospitals that are mostly local gov */
    foreach var in profit notprofit localgov {
        drop if !inlist(own_frac_`var', 0, 1)
    }

    foreach owner in profit notprofit localgov {
        foreach lhv in $LHV_1st $LHV_z $LHV_hospcomp {
            preserve
            keep if own_has_`owner' == 1
            plot_variance_guts `lhv' `owner'
            restore
        }
    }
end

prog def main_byITadopt
    data_prep

    /* This is (roughly) for 150507 mtg (untested) */
    foreach adopt_status in "all" "always" "adopt" {
        foreach lhv in $LHV_1st $LHV_z $LHV_hospcomp {
            if "`adopt_status'" == "always" keep if always == 1
            else if "`adopt_status'" == "adopt" keep if adopt == 1
            preserve
            plot_variance_guts `lhv' `adopt_status'
            restore
        }
    }
end

prog def main_basic
    /* This is (roughly) what generated figures for Jan 2015 mtg (untested) */
    data_prep

    foreach lhv in $LHV_1st $LHV_z $LHV_hospcomp {
        preserve
        plot_variance_guts `lhv' 
        restore
    }

end

prog def data_prep
    prep_hosp_data 2 0

    keep if year >= 2008
    * Gen system size variable
    gen byte in_sys = sysid != ""
    replace sysid = hosp_id if sysid == ""
    bys sysid year: gen syssize = _N
    bys hosp_id: egen hosp_syssizemin = min(syssizemin)
    * Restrict to big systems
    _restrict_syssize
  end
prog def _restrict_syssize
    syntax [varlist] [, minsize(integer 5)]
    tempvar is_bigsys has_bigsys
    gen `is_bigsys' = syssizemin >= `minsize'
    bys hosp_id: egen `has_bigsys' = max(`is_bigsys')
    keep if `has_bigsys' == 1
end

prog def plot_variance_guts
    args lhv file_infix
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
        graph export $out/sysvariance_`file_infix'_`lhv'.png, replace width(1500)
    }
end
prog def _set_resid
    args suffix

    global r2_`suffix' = round(`e(r2)', .01)
    cap drop e_`suffix'
    predict e_`suffix' if e(sample), res
    qui summ e_`suffix', d
    replace e_`suffix'= . if !inrange(e_`suffix', `r(p1)', `r(p99)')
    global sig_`suffix' = round(`r(sd)', .001)
end

`subroutine'
