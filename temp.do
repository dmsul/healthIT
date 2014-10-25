run src/globals
cap prog drop check_for_duplicates
prog def check_for_duplicates
    foreach year of numlist 2010/2012 {
        use bene* using $CMS_SRC/bsf/`year'/bsfab`year', clear
        cap qui summ benedpsq
        if _rc!=0 {
            di "No benedpsq in `year'"
            bys bene_id: gen n = _N
            qui summ n
            if r(sd) == 0 di "No duplicates in `year'"
            else di "DUPLICATES in `year'!!!!"
        }
    }
end

cap prog drop tab_drg
prog def tab_drg
    args drg_cd
    cap qui describe dgnscd1
    if _rc ==0 local primary_diag dgnscd1
    else local primary_diag prncpal_dgns_cd
    tab `primary_diag' if drg_cd == "`drg_cd'", sort
end

cap prog drop check_drg_codes
prog def check_drg_codes
    args year drg_cd
    use $CMS_SRC/ip/`year'/ipc`year'
    tab_drg `drg_cd'
end

