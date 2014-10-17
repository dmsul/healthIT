log using describe_bsf.log , replace
** by Jean Roth , 2013-11-12 , jroth@nber.org 
** You may want to compare the size of the file to the amount of memory available on the servers
** particularly for large files like Carrier and Outpatient 
set more off
program loop
local TYPE `1'
local SUBTYPE `2'
local FIRST_YEAR `3'
local LAST_YEAR `4'
local PCT `5'
local PARTS `6'
local PARTNAME `7'
foreach YEAR of num `FIRST_YEAR'/`LAST_YEAR' {
    local indir /disk/aging/medicare/data/`PCT'pct/`TYPE'/`YEAR'/1
    di "`SUBTYPE'`YEAR'  `PCT' PCT"
    local FILE `SUBTYPE'`YEAR'
    if ( length("`PARTS'") > 0 ) {
        local FILE `PARTNAME'
    }
    desc using `indir'/`FILE'
}

end
****************************
** 100 PCT
****************************
loop bsf bsfab 2006 2012 100
loop bsf bsfcc 2006 2012 100
loop bsf bsfcu 2006 2012 100
loop bsf bsfd  2006 2012 100
****************************
** 20 PCT
****************************
loop bsf bsfab 2006 2012 20
loop bsf bsfcc 2006 2012 20
loop bsf bsfcu 2006 2012 20
loop bsf bsfd  2006 2012 20
****************************
** 05 PCT
****************************
loop bsf bsfab 2006 2012 05
loop bsf bsfcc 2006 2012 05
loop bsf bsfcu 2006 2012 05
loop bsf bsfd  2006 2012 05
****************************
** 01 PCT
****************************
loop bsf bsfab 2006 2012 01
loop bsf bsfcc 2006 2012 01
loop bsf bsfcu 2006 2012 01
loop bsf bsfd  2006 2012 01
****************************
** 0001 PCT
****************************
loop bsf bsfab 2006 2012 0001
loop bsf bsfcc 2006 2012 0001
loop bsf bsfcu 2006 2012 0001
loop bsf bsfd  2006 2012 0001
