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


/*******************************************************************************

	Save coefficients for optimized scale transformations found

*******************************************************************************/

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
