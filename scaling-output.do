/*******************************************************************************

	Create output from scale transformations

*******************************************************************************/

	////// Set up //////

* Load the file paths
do "$gituser/_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

	////// Clean the output //////

* Load the output from the scale transformation
use "$gituser/scaling/iterations100.dta", clear

* Add an identifier of iterations
gen i = _n

* Keep only the observations that are order preserving
keep if obj != .

* Store the names of the iterations in a global 
levelsof i, local(iterations)
gl iterations `iterations'

* This output is for maximizing gap : browse the gap results
sum obj, detail

* Store the maximizing obs in a global
egen double max = max(obj) 
	//note: we need to specify double as it is the format of the obj. var
gen max_iteration = (max == obj)
levelsof i if max_iteration==1, local(maxiteration)
gl maxiteration `maxiteration'
drop max max_iteration

* Store the different transformations in wide format 
keep obj b1 b2 b3 b4 b5 b6 c i
gen type = "max"
foreach var of varlist obj b1 b2 b3 b4 b5 b6 c {
	ren `var' `var'_
}
reshape wide obj b1 b2 b3 b4 b5 b6 c, i(type) j(i)

* Store the output in a tempfile to merge with test scores 
tempfile scalingoutput
save `scalingoutput'


	////// Add the outputs to the test scores //////

* Load test scores
use "$gituser/2_build/testcores_y1y2_wide.dta", clear 

* Merge the polynomial transformations outputed from the command
gen type = "max"
merge m:1 type using `scalingoutput', nogen assert(3)
 
* Calculate the new testscores
foreach i in $iterations {
	foreach year in 1 2 {
		gen total_mle`year'_`i' =  b1_`i' * (total_mle`year' - c_`i') + ///
			b2_`i' * (total_mle`year' - c_`i')^2 + b3_`i' * (total_mle`year' - c_`i')^3 + /// 
			b4_`i' * (total_mle`year' - c_`i')^4 + b5_`i' * (total_mle`year' - c_`i')^5 + /// 
			b6_`i' * (total_mle`year' - c_`i')^6  	
	}
}
** TODO: understand why some of the new test scores are missing???

* Store the non missing test scores in a global 
gl missing "78 79 86"
gl rescaled : list global(iterations) - global(missing)
dis "$rescaled"

* Drop the polynomial transformation coefficients
drop obj_* b*_* c_*

* Standardize the new test scores (periods 1 and 2 combined)
*** step 1 : list the variables to reshape
local varlist 
foreach i in $iterations {
	local varlist `varlist' total_mle@_`i'
}
gl vartoreshape `varlist'

*** step 2 : reshape at the individual-year level 
reshape long total_mle@ $vartoreshape, i(childuniqueid) j(year)

*** step 3 : standardize 
foreach i in $iterations {
	egen total_mle_`i'_std = std(total_mle_`i')
}


* Calculate and plot all the regressions 

	* Clear the eststo 
	eststo clear 
	
	* Run the normal reg
	eststo eq0: reg total_mle reportcard if year==2

	* Run the reg with the created variables
	foreach i in $rescaled {
		eststo eq`i': reg  total_mle_`i'_std reportcard if year==2
	}
	
	* Store the regression values
	estout _all, cells("b(fmt(%9.3f)) se(fmt(%9.3f)) p(fmt(%9.3f)) ci_l(fmt(%9.3f)) ci_u(fmt(%9.3f))") stats(N r2) 

	mat A = r(coefs)
	mat B = r(stats)

	* Store the regression stats (N and r2)
	preserve
		clear 
		svmat B, names(eqcol)

		local statnames : rownames B
		gen stat=""
		forvalues i=1/`: word count `statnames'' {
		  replace stat=`"`: word `i' of `statnames''"' in `i'
		}

		gen i = "stat"

		reshape wide _eq*, j(stat) i(i) string 

		reshape long _eq@N _eq@r2, i(i) j(iteration)
		drop i 
		
		foreach var of varlist _all {
			local varname = "`var'"
			local newname = subinstr("`varname'", "_eq", "", .)
			rename `var' `newname'
		}
		
		tempfile stats 
		save `stats'
	restore  

	* Store the regression coefficients 
	*preserve 
		clear 
		svmat A, names(eqcol)

		local coefnames : rownames A
		gen var=""
		forvalues i=1/`: word count `coefnames'' {
		  replace var=`"`: word `i' of `coefnames''"' in `i'
		}

		reshape long eq@b eq@se eq@p eq@ci_l eq@ci_u, i(var) j(iteration)
			
		* Add the regression stats to them	
		merge m:1 iteration using `stats', assert(3) nogen	
			
		foreach var in eqb eqse eqp eqci_l eqci_u {
			local varname = "`var'"
			local newname = subinstr("`varname'", "eq", "", .)
			rename `var' `newname'
		}

		* Only keep the relevant coefficients for plotting 
		local keep reportcard
		keep if strpos("`keep'", var) > 0
		
		* Gen the iteration id for x axis 
		sort b
		gen x = _n
		
		* Store the number of rescaled scores 
		local neqs = wordcount("$rescaled")
		dis "`neqs'"
		
		* Plot the regression coefficients and their CI 		
		twoway  (scatter b x if iteration==0, mcolor(gold)) (rcap ci_l ci_u x if iteration==0, lcolor(gold)) /// 	//reference reg
			(scatter b x if iteration==$maxiteration, mcolor(cranberry)) (rcap ci_l ci_u x if iteration==$maxiteration, lcolor(cranberry)) /// 	//maximizing gap growth reg
			(scatter b x if iteration>0 & iteration!=$maxiteration, mcolor(navy)) (rcap ci_l ci_u x if iteration>0 & iteration!=$maxiteration, lcolor(navy)) ///			//simulated regs
			, by(var, legend(off) title("Regression Coefficients On Re-Scaled Second Year Test Scores") subtitle("With `neqs' rescaled second year test scores") note("Yellow = original test score. Red = rescaled test scores maximizing the y1-y2 gap growth between T and C." "Blue = random rank-preserving rescaled test scores.")) ///
			 ytitle("Regression Coefficient") xtitle("Regression in Y2") yline(0)
		graph export "$gituser/img/rescaled.png", as(png) name("Graph")	 
	restore
	

	