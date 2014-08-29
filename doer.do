forval control=1/3 {
	do reg-1403-simpleDD `control'
}


/*
forval control=1/3 {
	foreach size in 0 1 2 3 {
		do reg-1403-plots `control' `size'
	}
}
*/
*do reg-1403-simpleDD

