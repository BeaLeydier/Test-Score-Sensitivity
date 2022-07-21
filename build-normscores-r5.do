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

*Generate the z score (dev from the mean, IN standard deviations) for each topic
egen math_zscore = std(math_sum)
egen eng_zscore = std(eng_sum)
egen urdu_zscore = std(urdu_sum)
egen all_zscore = std(allsubjects_sum)

*Generate the scores with all items MINUS 1 item
	rename math_item01 math_item1
	rename math_item03 math_item3
	rename math_item09 math_item9
global itemnumbers 1 3 9 11 12 13 15 16 18 19 20 22 23 24 25 26 27 28 30 31 32 33 34 37 38 39 40 42 43 44 48 49 50 51 52 53 54 55 56 57 58 59 60 61
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

*Calculate the zscores limited to the selected items
forvalues v = 1/500 { //note: this loops takes about 1.5hours to run
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
	
*Collapse back to the child level to calculate the zscores 
keep district childcode mauzaid schoolid child_age child_panel math_zscore math_sum_5items*
duplicates drop
	
*Calculate zscores 
forvalues v = 1/283 {
	egen math_zscore_5items`v' = std(math_sum_5items`v')
}

*Analysis wrt RCT
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta"	
	
eststo clear
	
reg math_zscore reportcard i.district, cl(mauzaid)	
	eststo og
	
forvalues v=1/283 {		
reg math_zscore_5items`v' reportcard i.district, cl(mauzaid)	
	eststo chose5_`v'
}

speccurve, param(reportcard) main(og) title("283 models with 5 random math items")  addscalar(r2, graphopts(ytitle(R squared)))
		graph export "$dropboxuser/$output/speccurve_5items.png", as(png)

	
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
