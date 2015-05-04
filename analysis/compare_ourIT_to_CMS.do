quiet {
set trace off
set more off
clear all

run src/globals

global out $OUT_PATH

prog def payments

    use $cms_ehr_payments_dta
    // Get total and 'normed to 4 years' pay
    /* Because we use total over 4 years in the other files */
    bys hosp_id: egen cms_tot_pay = total(cms_pay)
    bys hosp_id: gen T = _N
    gen cms_pay_4year = (cms_tot_pay/T)*4
    // Janky fillin/reshape because our only year of joint coverage is 2011
    foreach year in 2011 2012 {
        gen temp = cms_payment if year == `year'
        bys hosp_id: egen cms_pay`year' = max(temp)
        replace cms_pay`year' = 0 if cms_pay`year' == .
        drop temp
    }

    keep hosp_id cms_pay201* cms_pay_4year 
    duplicates drop

    tempfile cms_pay
    save `cms_pay'

    use $combined_dta
    merge m:1 hosp_id using `cms_pay', keep(1 3)

    gen our_ehrpay_1year = bene_tot/4
    gen our_ehrpay_4year = bene_tot
    foreach var of varlist cms_pay* {
        replace `var' = 0 if `var' == . & _merge == 1
    }

    _extensive_margin

    _intensive_margin

end
prog def _extensive_margin
    gen us_pay = our_ehrpay_1year > 0 if our_ehrpay_1year < .
    /* If the cms payment is missing, it's definitely 0 in a given year */
    gen them_pay = cms_pay2011 > 0 & cms_pay2011 <.
    tabout us_pay them_pay if year == 2011 using $out/usvcms_pay_tab.tex, ///
           style(tex) mi replace f(0)
end
prog def _intensive_margin

    local replace replace
    foreach use_zeros in 0 1 {
        foreach pay_time in 1 4 {
            if `pay_time' == 1 {
                local ourvar our_ehrpay_1year
                local theirvar cms_pay2011
            }
            else {
                local ourvar our_ehrpay_4year
                local theirvar cms_pay_4year
            }
            if `use_zeros' == 1 {
                local allow_zeros
                local has_zeros "yes"
            }
            else {
                local allow_zeros ///
                    & `ourvar' != 0 & `theirvar' != 0  & our_ehrpay_1year < 5e6
                local has_zeros "no"
            }

            local condition year == 2011 `allow_zeros'

            twoway  (scatter `theirvar' `ourvar' if `condition') ///
                    (lfit `theirvar' `ourvar' if `condition') ///
                    (function y = x, range(`theirvar')), ///
                    legend(row(1)) ///
                    xti(`ourvar') yti(`theirvar') ///
                    title("Predicted Pay v. Actual") ///
                    subti("`has_zeros' zeros, `pay_time' years")
            graph export $out/usvcms_scatter_pay_z`use_zeros'y`pay_time'.png, ///
                replace width(1500)

            reg `theirvar' `ourvar' if year == 2011 `allow_zeros'
            outreg2 using $out/usvcms_reg.tex, tex(frag) `replace' ///
                addtext("Zeros", "`use_zeros'", "Years", "`pay_time'")
            local replace
        }
    }

end

prog def mu_measures
    clear
    use $cms_MU_measures_dta
    drop if hosp_id == ""
    drop npi attest_date

    reshape wide CMS*, i(hosp_id) j(year)
    tempfile cms_mu
    save `cms_mu'

    use $combined_dta, clear

    /*
    Ours            Theirs
    -----           -------
    cdss_drug_int   CMS_drug_interact_check (all 1's!)
    app_cds         
     (or any cdss?)
    app_data_repos  CMS_rec_demogs (smoking, vitals)

    Summary: Very little variation in the CMS data. If they're in the data,
    they almost certainly have the IT. But if they're not in the data, we
    can't impute "no IT".
    */


    /* cdss variables are only in data if 1. Impute 0's */
    foreach var of varlist cdss* {
        assert `var' == 1 | `var' == .
        replace `var' = 0 if `var' == .
    }

    /* Flags for our finest IT measures */
    foreach var in app_data_repos {
        local newname = subinstr("`var'", "app", "our", 1)
        gen byte `newname' = `var' == 1 if !inlist(`var', ., 99)
    }
    egen has_any_cdss = rowmax(cdss*)
    egen has_num_cdss = rowtotal(cdss*)
    replace has_num_cdss = has_num_cdss / 4

    merge m:1 hosp_id using `cms_mu', keep(1 3)

    cap log close
    log using $out/usvcms_MU.txt, text replace
    foreach recvar in demogs vitals smoking {
        bys our_data_repos: summ CMS_rec_`recvar'2011 if year == 2011, d
    }

    tab has_any_cdss CMS_one_cds_rule2011 if year == 2011, miss cell
    tab has_any_cdss CMS_one_cds_rule2012 if year == 2011, miss cell
    /* Zero True's for CMS_one_cds_rule2013... */
    log close
end
} // End subroutine quiet

payments
mu_measures
