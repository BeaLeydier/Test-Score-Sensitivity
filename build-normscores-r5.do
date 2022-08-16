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
keep childcode math_item* math_sum math_count

*Generate the z score (dev from the mean, IN standard deviations) for each topic
egen math_score = std(math_sum)
		*egen eng_zscore = std(eng_sum)
		*egen urdu_zscore = std(urdu_sum)
		*egen all_zscore = std(allsubjects_sum)

*Number the items consistently
	rename math_item01 math_item1
	rename math_item03 math_item3
	rename math_item09 math_item9
global itemnumbers 

*Generate score with 5 items

program fiveitems 
	* Select 5 items randomly
	local items "1 3 9 11 12 13 15 16 18 19 20 22 23 24 25 26 27 28 30 31 32 33 34 37 38 39 40 42 43 44 48 49 50 51 52 53 54 55 56 57 58 59 60 61"
	local nofitems : list sizeof items												//Obtain total item numbers
	local selecteditems ""															//Initialize list of selected items
	local len : list sizeof selecteditems											//Initialize lenght of list of selected items
	while `len' < 5 {																//Add a new item to the list until we reach the wanted size of the list
		local rand = floor(runiform()*`nofitems') + 1								//Select a random integer between 1 and the total number of items ( +1 because floor can select 0)
		local item : word `rand' of `items'											//Take the rand*th item from the list of items
		local selecteditems `selecteditems' `item'									//Add the selected item to the list of items
		local selecteditems : list uniq selecteditems								//Remove duplicates from the selected items list
		local len : list sizeof selecteditems										//Recalculate the size of the selected items list (so that the while ends when we reach the desired size)
	}
		
	* Store the index of each of the selected items								//make a loop
	dis "`selecteditems'"
	local j1 : word 1 of `selecteditems'
	local j2 : word 2 of `selecteditems'
	local j3 : word 3 of `selecteditems'
	local j4 : word 4 of `selecteditems'
	local j5 : word 5 of `selecteditems'

	* Calculate the score with these five items
	gen math_sum_5items_`1' = math_item`j1' + math_item`j2' + math_item`j3' + math_item`j4' + math_item`j5'
	egen math_score_5items_`1' = std(math_sum_5items_`1')	
end

forvalues i=1/500 {
	fiveitems `i'	
}

////////////////////////////////////////////////////////////////////////////////

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
