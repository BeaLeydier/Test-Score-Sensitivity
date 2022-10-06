/*******************************************************************************

	Create z-scores for round 5 tests

*******************************************************************************/
	////// Set up //////

* Load the file paths
do "_filepaths.do"

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

*Generate the z score (dev from the mean, IN standard deviations) for each topic
egen math_score = std(math_sum)
		*egen eng_zscore = std(eng_sum)
		*egen urdu_zscore = std(urdu_sum)
		*egen all_zscore = std(allsubjects_sum)

*Number the items consistently
	rename math_item01 math_item1
	rename math_item03 math_item3
	rename math_item09 math_item9


	exit
	
*** REGRESSION program	
	
cap program drop selectitemsreg	
program selectitemsreg

	syntax varlist(min=2 numeric fv ts) [if] [weight], SELECTed(integer) ITERations(integer) stub(namelist max=1 id="stubname" local)
	
	* Extrat the Y variable from the varlist, and the X vars from the varlist
	local yvar : word 1 of `varlist'		
	local xvars : list varlist - yvar
	
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

	
	
	
local varlist "math_score reportcard"
local yvar : word 1 of `varlist'		
local xvars : list varlist - yvar
local stub "math_item"
local selected 5
local iterations 50

local if ""
local weight ""

* Create the data simulations
selectitems_data `stub', selected(`selected') iterations(`iterations')

* Run the normal reg
reg `varlist' `if' `weight'

dis "`varlist'"
dis "`xvars'"
dis "`if'"
dis "`weight'"
dis "`selected'"
dis "`iterations'"		
		
forvalues i = 1/`iterations' {
		reg  std_`selected'items_`i' `xvars' `if' `weight'
	}
	

	
estimates clear	
	
reg math_score reportcard 
	estimates store total

reg std_5items_1 reportcard
	estimates store selection_1

reg std_5items_2 reportcard	
	estimates store selection_2
	
estimates table _all, keep(reportcard) se
mat list r(coef)	
	
local names : colfullnames r(coef)	
dis "`names'"
svmat r(coef), names("`names'")

/** TODO
	- Save in a dataset
	- Keep odd columns only (col 1, 3, 5, etc) = coef and not variances
	- Display 
**/
	
/********************

**** Program that OUTPUTS the difference : USELESS FOR NORMALIZED SCORES

program selectitems_diff

	syntax namelist(max=1 id="stubname" local), SELECTed(integer) ITERations(integer) 

preserve			// Preserve so that the original dataset comes back

	selectitems_data `namelist', selected(`selected') iterations(`iterations')

	*** Calc the score with all items, as well as the mean score in the whole population (should be 0, because scores are standardized)
	egen sum_total = rowtotal(`namelist'*)
	egen std_total = std(sum_total)
	egen mean = mean(std_total)

	*** Calculate the difference between subsetted score and full score
	forvalues i = 1/`iterations' {
			* difference for each individual for each simulation
		gen diff_`i' = std_total - std_`selected'items_`i' 
			* average difference for all individuals for a given simulation
		egen avg_diff_`i' = mean(diff_`i')	
	}
	

		*** Transform dataset to be at the simulation level, keeping only the average difference in that simulation (as well as the pop mean)
		keep mean avg_diff_* 
		duplicates drop
		reshape long avg_diff_, i(mean) j(n)
		label drop _all
		
		*** Plot histogram, 
		qui sum mean
		local mean = r(mean)
		hist avg_diff_, xline(`mean') title("Mean Differences between Subsetted Score and Full Score") subtitle("Distribution of `iterations' iterations selecting a random subset of `selected' items") xtitle("Population Mean Difference")
	
restore

end 
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
///////////////////////////////////////////////////////////////////////////////	
	
************ DRAFT	
	
	
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
