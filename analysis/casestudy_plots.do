/*
    Focus on systems that had large changes in within-system participation
    rates in the EHR incentives program.
*/

run src/globals
run main // Need `prep_hosp_data`

// Run the z_core etc raw means using hosp-level data only

// Plot patient outcomes after controlling for patient X's, etc.
