clear all


********************
**      I/O
********************

global SRC_96 $COSTREPORT_SRC/2552-96
global SRC_10 $COSTREPORT_SRC/2552-10


********************


use $SRC_96/hcris2009, clear

summ s3_1_c15_01200 /// 
    s3_1_c4_00100 ///
    s3_1_c4_00600 ///
    s3_1_c4_00700 ///
    s3_1_c4_00800 ///
    s3_1_c4_00900 ///
    s3_1_c4_01000 ///
    s3_1_c6_00100 ///
    s3_1_c6_00600 ///
    s3_1_c6_00700 ///
    s3_1_c6_00800 ///
    s3_1_c6_00900 ///
    s3_1_c6_01000

*use $SRC_10/hcris2011, clear



