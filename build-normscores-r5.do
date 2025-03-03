/*******************************************************************************

	Output results for round 5 test scores

*******************************************************************************/
	////// Set up //////

clear all
set maxvar 32767	
	
* Load the file paths
do "_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

* Upload raw test scores
use "$dropboxuser/$rawscores/public_child_tests_data_5yrs.dta", clear

* Keep round 5 scores only
keep if year==5

* Count number of items, and keep only the children with the max
egen math_count = anycount(math_item*), values(0 1)
tab math_count
keep if math_count==44

*Drop all the variables that have missing values for everybody
missings dropvars, force

* Keep variables of interest only
keep childcode math_item* math_sum math_count mauzaid child_age child_female 

* Add the RCT data 
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta", nogen

* Add the calculated baseline scores from study at the village level 
preserve 
	use "/Users/bl517/Dropbox/LEAPS_ReportCards_2011/2_data_constructed/child_inclr5sibs_wide.dta", clear
	
	bys mauzaid: egen base_math = mean(math_mle1)
		
	keep mauzaid base_math
	
	duplicates drop
		
	tempfile scores
	save `scores'
restore 

merge m:1 mauzaid using `scores', assert(3) nogen

** Store the baseline (year 1) mle score for each village 
ren base_math base_mauza_math_mle 

** Add in village globals
merge m:1 mauzaid using "$dropboxuser/LEAPS_ReportCards_2011/2_data_constructed/basemau.dta"
drop _merge
global vilcontrols "mau_avg_hh_perc_literate m_HHI vil_median_expenditure vil_n_households"
	

*Generate the z score (dev from the mean, IN standard deviations) for each topic
egen math_score = std(math_sum)
		*egen eng_zscore = std(eng_sum)
		*egen urdu_zscore = std(urdu_sum)
		*egen all_zscore = std(allsubjects_sum)

*Number the items consistently
	rename math_item01 math_item1
	rename math_item03 math_item3
	rename math_item09 math_item9
	
** Test the subsetscore program 

/* takes a while to run
subsetscore math_item, min(2) max(44) iterations(100) output(allcorr)
graph export "$gituser/img/allcorr-y5.png", replace
*/ 

** Run the subsetscore_reg program for two item sizes

subsetscore_reg	math_score reportcard i.district base_m_math_mle $vilcontrols using "$gituser/img/reg-y5-5items.png", selected(5) iterations(100) stubname(math_item) cluster(mauzaid) keep(reportcard)

subsetscore_reg	math_score reportcard i.district base_m_math_mle $vilcontrols using "$gituser/img/reg-y5-20items.png", selected(20) iterations(100) stubname(math_item)	cluster(mauzaid) keep(reportcard)	

exit 


** Run the subsetscore_reg for all item sizes 

foreach item in 2 3 4 6 7 8 9 10 11 12 13 14 15 16 17 18 19 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 {
	subsetscore_reg	math_score reportcard i.district base_m_math_mle $vilcontrols using "$gituser/img/reg-y5-`item'items.png", selected(`item') iterations(100) stubname(math_item)	cluster(mauzaid) keep(reportcard)
}

** Append all the intermediate output files 

use "$gituser/2_temp/output_reg_2.dta", clear
foreach item in 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 {
	append using "$gituser/2_temp/output_reg_`item'.dta"
}

destring(n_items), replace

graph box b, over(n_items, label(labsize(small))) title("Variance of coefficients over 100 iterations") subtitle("As a function of the number of items in the test score") ytitle("Coefficient estimates") 
graph export "$gituser/img/var-coeff-100regs-over-n-items.png", replace

graph box se, over(n_items, label(labsize(small))) title("Variance of standard errors over 100 iterations") subtitle("As a function of the number of items in the test score") ytitle("Standard errors of coefficients") 
graph export "$gituser/img/var-se-100regs-over-n-items.png", replace



/*
subsetscore_reg	math_score reportcard schoolgrant if district != "RAHIM YAR KHAN", selected(5) iterations(50) stubname(math_item)	
graph export "$gituser/img/reg-2coefs.png", replace
*/	
	exit
	
	
//////////////////////////////////////////////	
	
	
/******
	Reproduce the main reportcard result 
*******/

** Load the item level test score data
use "$dropboxuser/LEAPS_ItemBank/2_data_constructed/Item_TestScores_LEAPS.dta", clear

keep uniqueid year mauzaid schoolid child_age child_enrolled child_class child_panel child_absent child_id child_female hhid mid id math_item*

** Merge the 5year MLE theta for math 
merge 1:1 id using "C:/Users/bl517/Documents/leaps-itembank/temp/math-traits-5years.dta", assert(3) nogen

** Keep the math theta
ren theta_mle math_mle 
ren theta_eap math_eap 
drop theta_pv1 theta_pv2 theta_pv3 theta_pv4 theta_pv5 theta_mle_se

** Store the baseline (year 1) mle score for each village 
bys mauzaid year: egen m_score = mean(math_mle)
gen temp = m_score if year==1
bys mauzaid: egen base_mauza_math_mle = min(temp)
drop temp

** Add in village globals
merge m:1 mauzaid using "$dropboxuser/LEAPS_ReportCards_2011/2_data_constructed/basemau.dta"
drop _merge
global vilcontrols "mau_avg_hh_perc_literate m_HHI vil_median_expenditure vil_n_households"
	
	
subsetscore_reg	math_mle reportcard i.district base_m_math_mle $vilcontrols if child_panel == 3, selected(5) iterations(50) stubname(math_item)	keep(reportcard) cluster(mauzaid)
	
	
	
	
///////////////////////////////////////////////////////////////////////////////	
	
************ DRAFT	
	
/*	
	local varlist math_score reportcard schoolgrant
	local selected 5
	local iterations 10 
	local stubname math_item
	
	
	
	/*



/// Program that takes the simulated data and returns regression results

program selectitemsreg

	syntax varlist(min=2 numeric fv ts) [if] [weight], SELECTed(integer) ITERations(integer) stub(namelist max=1 id="stubname" local)
	
	* Extrat the Y variable from the varlist, and the X vars from the varlist
	local yvar : word 1 of `varlist'		
	local xvars : `varlist' - `yvar'
	
	* Create the data simulations
	selectitems_data `stub', selected(`selected') iterations(`iterations')
	
	* Run the normal reg
	reg `varlist' `if' `weight'

	* Run the reg with the created variables
	forvalues i = 1/`iterations' {
		reg  std_`selected'items_* `xvars' `if' `weight'
	}
	
end 

selectitemsreg math_score reportcard, select(5) iter(10) stub(math_item)



	* Extrat the Y variable from the varlist, and the X vars from the varlist
	local varlist = "math_score reportcard"
	local yvar : word 1 of "`varlist'"		
	local xvars : list "`varlist'" - "`yvar'"
	
	dis "`varlist'"
	dis "`yvar'"
	dis "`xvars'"


exit
/*

		local namelist math_item
		local select 5
		local selecteditems "1 3 9 11 12"
		
		forvalues iteration = 1/10 {

			* Calculate the score with these five items
		}


exit

forvalues i=1/500 {
	fiveitems `i'	
}

* Save the dataset generated
save "$dropboxuser/$data/int/5items_data.dta", replace

cpcorr math_score_5items_* \ math_score

* Save matrix of coefficients into a dataset

svmat r(C), names(eqcol)														// Make the correlation coefficients into the dataset and use their equation name (ie a _ will be added at the beginning of the coefficient)
keep _*																			// Only keep these variables
duplicates drop																	// Delete all the empty obs (all duplicates, fully missing) : now the number of n is the number of correlation coefficients
drop if _math_score == .														// Delete an empty obs

	/*TODO CHECK : _n here is number of simulations*/

* Add back the item selected for each
gen n = _n

* Add back the list of selected items for each 
gen selected_items = ""
forvalues i = 1/500 {
	replace selected_items = "${selecteditems_`i'}" if _n==`i'	
}

* Display histogram 

hist _math_score 

exit












////////////////////////////////////////////////////////////////////////////////

**************** ARCHIVE

	/* OBTAIN THE LIST OF SELECTED ITEMS
	keep selected_5items*
	duplicates drop
	gen i = 1
	reshape long selected_5items_, i(i) j(n)
	label drop childactivity
	*/


*pwcorr math_score math_score_5items_*, sig star(.05)


*Generate the scores with all items MINUS 1 item
foreach i in $itemnumbers {
	gen math_sum_wo`i' = math_sum - math_item`i'
	egen math_zscore_wo`i' = std(math_sum_wo`i')
}

save "$dropboxuser/$data/int/zscores_r5.dta", replace

	////// Graphs for a given child //////

preserve
	use "$dropboxuser/$data/int/zscores_r5.dta", clear

	*Reshape on items to show the distribution of zscores for a given person
	keep childcode mauzaid schoolid child_age child_panel math_zscore*
	reshape long math_zscore_wo, i(childcode) j(j)
	label drop childactivity //for some reason j takes the value label childactivity, which we drop

	*Generate historgrams for each person
	bys childcode: gen n = _n

	histogram math_zscore_wo if childcode==500102001, frequency addplot((line n math_zscore if childcode==500102001)) legend(order( 1 "Distribution of 43-item z-scores" 2 "Full 44-item z-score")) title("Distribution of z-scores for Child 500102001")
		graph export "$dropboxuser/$output/math_zscore_wo_child500102001.png", as(png) replace
	histogram math_zscore_wo if childcode==500102002, frequency addplot((line n math_zscore if childcode==500102002)) legend(order( 1 "Distribution of 43-item z-scores" 2 "Full 44-item z-score")) title("Distribution of z-scores for Child 500102002")
		graph export "$dropboxuser/$output/math_zscore_wo_child500102002.png", as(png) replace
	histogram math_zscore_wo if childcode==500102003, frequency addplot((line n math_zscore if childcode==500102003)) legend(order( 1 "Distribution of 43-item z-scores" 2 "Full 44-item z-score")) title("Distribution of z-scores for Child 500102003")
		graph export "$dropboxuser/$output/math_zscore_wo_child500102003.png", as(png) replace
	

	graph box math_zscore_wo math_zscore if childcode==500102001, legend(order(1 "43-item zscores" 2 "Full 44-item z-score")) title("Box chart of 43-item z-scores for Child 500102001")
		graph export "$dropboxuser/$output/math_zscore_wo_child500102001_box.png", as(png) replace
	graph box math_zscore_wo math_zscore if childcode==500102002, legend(order(1 "43-item zscores" 2 "Full 44-item z-score")) title("Box chart of 43-item z-scores for Child 500102002")
		graph export "$dropboxuser/$output/math_zscore_wo_child500102002_box.png", as(png) replace
	graph box math_zscore_wo math_zscore if childcode==500102003, legend(order(1 "43-item zscores" 2 "Full 44-item z-score")) title("Box chart of 43-item z-scores for Child 500102003")
		graph export "$dropboxuser/$output/math_zscore_wo_child500102003_box.png", as(png) replace
restore

	////// Analysis wrt RC intervention //////

use "$dropboxuser/$data/int/zscores_r5.dta", clear
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta"	
	
	eststo clear
reg math_zscore reportcard i.district, cl(mauzaid)	
	eststo og
	
foreach i in $itemnumbers {		
reg math_zscore_wo`i' reportcard i.district, cl(mauzaid)	
	eststo wo`i'
}

speccurve, param(reportcard) main(og) title("43 models excluding ONE math item")  addscalar(r2, graphopts(ytitle(R squared)))
		graph export "$dropboxuser/$output/speccurve_-1item.png", as(png)


********** Generate the score for 5 random items out of the 44

*Select 5 items randomly
import excel "$dropboxuser/$data/math_items.xlsx", clear firstrow

set seed 1
isid n

forvalues v = 1/500 {
	sort n
	gen r`v' = runiform()
	sort r`v' 
	egen rank`v'=rank(r`v')
	gen selected`v'=rank`v'<=5	
}

keep j_item selected*
isid j_item

save "$dropboxuser/$data/int/choose5math.dta", replace

*Load raw scores and reshape on items to be able to merge with the selected items 
use "$dropboxuser/$data/int/zscores_r5.dta", clear
keep district childcode mauzaid schoolid child_age child_panel math_item* math_zscore

reshape long math_item, i(childcode) j(j_item)
label drop childactivity //for some reason j takes the value label childactivity, which we drop

merge m:1 j_item using "$dropboxuser/$data/int/choose5math.dta", nogen

* Calculate the test scores for each child on the selected items only
forvalues v=1/500 {
	bys childcode selected`v' : egen temp`v'=total(math_item)
	gen uniquetemp`v' = temp`v' if selected`v'==1
	bys childcode: egen math_sum_5items`v'=max(uniquetemp`v')
	drop temp`v' uniquetemp`v'
}

* Collpase back at the child level
keep district childcode mauzaid schoolid child_age child_panel math_zscore math_sum_5items*
duplicates drop 

		{ /* OLD (LONGER) CALCULATION
		*Calculate the zscores limited to the selected items
		forvalues v = 1/100 { //note: this loops takes about 20min to run
			preserve
				keep if selected`v' == 1
				bys childcode: egen math_sum_5items`v'=total(math_item)
				keep childcode math_sum_5items`v'
				duplicates drop
				
				tempfile s`v'
				save `s`v''
			restore
			
			merge m:1 childcode using `s`v'', nogen	
		}	
		
		save "$dropboxuser/$data/int/zscores_choose5math.dta", replace	
		
		*Collapse back to the child level to calculate the zscores 
		keep district childcode mauzaid schoolid child_age child_panel math_zscore math_sum_5items*
		duplicates drop		
		
			*/
		}


*Calculate zscores 
forvalues v = 1/500 {
	egen math_zscore_5items`v' = std(math_sum_5items`v')
}

*Analysis wrt RCT
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta"	
	
eststo clear
	
reg math_zscore reportcard i.district, cl(mauzaid)	
	eststo og
	
forvalues v=1/100 {		
reg math_zscore_5items`v' reportcard i.district, cl(mauzaid)	
	eststo chose5_`v'
}

speccurve, param(reportcard) main(og) title("100 models with 5 random math items")  addscalar(r2, graphopts(ytitle(R squared)))
		graph export "$dropboxuser/$output/speccurve_5items.png", as(png) replace

		
		
********** Generate the score for 10 random items out of the 44

*Select 10 items randomly
import excel "$dropboxuser/$data/math_items.xlsx", clear firstrow

set seed 2
isid n

forvalues v = 1/100 {
	sort n
	gen r`v' = runiform()
	sort r`v' 
	egen rank`v'=rank(r`v')
	gen selected`v'=rank`v'<=10	
}

keep j_item selected*
isid j_item

save "$dropboxuser/$data/int/choose10math.dta", replace

*Load raw scores and reshape on items to be able to merge with the selected items 
use "$dropboxuser/$data/int/zscores_r5.dta", clear
keep district childcode mauzaid schoolid child_age child_panel math_item* math_zscore

reshape long math_item, i(childcode) j(j_item)
label drop childactivity //for some reason j takes the value label childactivity, which we drop

merge m:1 j_item using "$dropboxuser/$data/int/choose10math.dta", nogen

*Calculate the zscores limited to the selected items
forvalues v = 1/100 { //note: this loops takes about 5min to run
	preserve
		keep if selected`v' == 1
		bys childcode: egen math_sum_10items`v'=total(math_item)
		keep childcode math_sum_10items`v'
		duplicates drop
		
		tempfile s`v'
		save `s`v''
	restore
	
	merge m:1 childcode using `s`v'', nogen	
}	

save "$dropboxuser/$data/int/zscores_choose10math.dta", replace
	
*Collapse back to the child level to calculate the zscores 
keep district childcode mauzaid schoolid child_age child_panel math_zscore math_sum_10items*
duplicates drop
	
*Calculate zscores 
forvalues v = 1/100 {
	egen math_zscore_10items`v' = std(math_sum_10items`v')
}

*Analysis wrt RCT
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta"	
	
eststo clear
	
reg math_zscore reportcard i.district, cl(mauzaid)	
	eststo og
	
forvalues v=1/100 {		
reg math_zscore_5items`v' reportcard i.district, cl(mauzaid)	
	eststo chose5_`v'
}

speccurve, param(reportcard) main(og) title("100 models with 10 random math items")  addscalar(r2, graphopts(ytitle(R squared)))
		graph export "$dropboxuser/$output/speccurve_10items.png", as(png)

		
		
*Reshape by permutation (long) to regress how zscore_wo is predicted by z_score (with child fixed effects)
reshape long math_sum_10items math_zscore_10items, i(childcode) j(n_perm)

xtset childcode n_perm
xtreg math_zscore_10items math_zscore
		
save "$dropboxuser/$data/int/long_perms_choose10math.dta", replace
		
	
/////////////////////////////////////////////


/* Explorations that led nowhere	



*Regress how zscore_wo is predicted by z_score (with child fixed effects)
xtset childcode n
xtreg math_zscore_wo math_zscore, fe
	//too similar to yield any results?
		
*Manually calculate mean and stddev of math_zscore_wo for each kid
bys childcode: egen mean = mean(math_zscore_wo)
bys childcode: egen sd = sd(math_zscore_wo)

*Collapse back at child level
keep childcode mauzaid schoolid math_zscore mean sd
duplicates drop

gen meanplus = mean+sd
gen meanminus = mean-sd

twoway (scatter meanplus childcode if childcode<=500102010, sort) (scatter mean childcode if childcode<=500102010, sort) (scatter meanminus childcode if childcode<=500102010, sort)
