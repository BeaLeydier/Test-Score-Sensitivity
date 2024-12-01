/*******************************************************************************

	Create output from scale transformations

*******************************************************************************/

	////// Set up //////

* Load the file paths
do "$gituser/_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

* Define endline year
local endyear 2

* Define n of iterations
local iter 500

* Define subject (for iterations file name)
local subject math-

* Define subject (for test score variable name)
local subj math


/*******************************************************************************

	Save coefficients for optimized scale transformations found

*******************************************************************************/

///////// Explorations with math_mle 
 
* Load the output from the scale transformation
use "$gituser/2_build/testcores_y1y`endyear'_rescaled_`subject'`iter'.dta", clear

sort childuniqueid year

exit

** Regular gap growth
reg math_mle reportcard if year==1
reg math_mle reportcard if year==2

dis .0724007 - .0042483
//.0681524

** Rank preservation 

gsort year -math_mle childuniqueid
by year: gen rank_og = _n 

foreach transform in max min corr r2 {
	gsort year -math_mle_`transform' childuniqueid
	by year: gen rank_`transform' = _n	
}

sort year rank_og
br year childuniqueid rank_og rank_max math_mle math_mle_max
br year childuniqueid rank_og rank_min math_mle math_mle_min
br year childuniqueid rank_og rank_corr math_mle math_mle_corr
br year childuniqueid rank_og rank_r2 math_mle math_mle_r2




/////////////////////////////////////////////////////////////////

///////// Explorations with total_mle 

// Max gap growth between T and C

* Load the output from the scale transformation
use "$gituser/2_build/testcores_y1y`endyear'_rescaled.dta", clear

sort childuniqueid year

** Regular gap growth
reg total_mle reportcard if year==1
reg total_mle reportcard if year==2

dis .0533039 - .0086142
// 0.0446897

** Maximized gap growth
reg total_mle_max_std reportcard if year==1
reg total_mle_max_std reportcard if year==2

dis .049874 -  .0376256
// .0122484

** Minimized gap growth
reg total_mle_min_std reportcard if year==1
reg total_mle_min_std reportcard if year==2

dis  -.0592328 -  -.0373929
// -.0218399

** Correlation 
xtset childuniqueid year
sort childuniqueid year
	
reg total_mle L1.total_mle //0.68

reg total_mle_corr_std L1.total_mle_corr_std //0.79


** Regression with lagged coefficient 
xtset childuniqueid year
sort childuniqueid year

reg total_mle reportcard i.district L1.total_mle if year==2, vce(cluster mauzaid)

reg total_mle_max_std reportcard i.district L1.total_mle_max_std if year==2, vce(cluster mauzaid)

reg total_mle_corr_std reportcard i.district L1.total_mle_corr_std if year==2, vce(cluster mauzaid)


/// Check that it is rank preserving within year

gsort year -total_mle childuniqueid
by year: gen rank_og = _n 

foreach transform in max min corr r2 {
	gsort year -total_mle_`transform' childuniqueid
	by year: gen rank_`transform' = _n	
}

sort year rank_og
br year childuniqueid rank_og rank_max total_mle total_mle_max
br year childuniqueid rank_og rank_min total_mle total_mle_min
br year childuniqueid rank_og rank_corr total_mle total_mle_corr
br year childuniqueid rank_og rank_r2 total_mle total_mle_r2

sort total_mle_max 
gen test = (total_mle_max[_n] == total_mle_max[_n-1])
br total_mle total_mle_max test
gen test2 = (total_mle[_n] == total_mle[_n-1])
br total_mle total_mle_max test test2

/* Result : only the corr ones is perfectly rank preserving within year. */

/// Check that it is rank preserving across years

drop rank_*
gsort -total_mle childuniqueid
gen rank_og = _n 

foreach transform in max min corr r2 {
	gsort -total_mle_`transform' childuniqueid
	gen rank_`transform' = _n	
}

sort rank_og
br year childuniqueid rank_og rank_max total_mle total_mle_max
br year childuniqueid rank_og rank_min total_mle total_mle_min
br year childuniqueid rank_og rank_corr total_mle total_mle_corr
br year childuniqueid rank_og rank_r2 total_mle total_mle_r2
