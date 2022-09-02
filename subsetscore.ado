/*******************************************************************************

	.ado file that defines subset of scores from longer list items of scores
	and returns one of three things
	
		1. a histogram of the population difference between subsetted scores and full score
		2. a histogram of the correlation between subsetted scores and full score
		3. a function of the correlation between subsetted scores and full score
			against the number of variables in the subsetted score
			
*******************************************************************************/
clear all
set maxvar 32767

program subsetscore 

	syntax namelist(max=1 id="stubname" local), ITERations(integer) OUTput(name) [SELECTed(integer 5) MINselected(integer 1) MAXselected(integer 10)]  

	if "`output'" == "diff" {
		
		selectitems_diff `namelist', selected(`selected') iterations(`iterations')
		
	}


	if "`output'" == "corr" {
		
		selectitems_corr `namelist', selected(`selected') iterations(`iterations')
		
	}
	

	if "`output'" == "allcorr" {
		
		selectitems_allcorr `namelist', minselected(`minselected') maxselected(`maxselected') iterations(`iterations')
		
	}
	
end


**** Program that (locally) generates the data needed for the output programs

program selectitems_data

		syntax namelist(max=1 id="stubname" local), SELECTed(integer) ITERations(integer) 
			
	*** Generate the n iterations of the score with a random subselection of n items

		* Extract the numbers at the end of math_item and put it into one local called items
		local var "`namelist'"															// Name of the stub/score variable
		local varlen = length("`var'")													// Length of the score variable without the number extension
		local items ""																	// Initialize the items list 
		foreach x of varlist `var'* {													// Loop through all the score variables with the * wildcard
			local n = substr("`x'", `varlen' + 1, length("`x'"))						// For each of the score variable, extract the portion that starts after the length of the score variable without the number extension (ie extarct the number extension)
			local items `items' `n' 													// Append it to the local items
		}
	
		* Loop through all iterations of the random selection and score calculation
		
		forvalues iteration = 1/`iterations' {

			* Select n (SELECT) items randomly from these list of items
			local nofitems : list sizeof items												//Obtain total item numbers
			local selecteditems ""															//Initialize list of selected items
			local len : list sizeof selecteditems											//Initialize length of list of selected items
			while `len' < `selected' {																//Add a new item to the list until we reach the wanted size of the list
				local rand = floor(runiform()*`nofitems') + 1								//Select a random integer between 1 and the total number of items ( +1 because floor can select 0)
				local item : word `rand' of `items'											//Take the rand*th item from the list of items
				local selecteditems `selecteditems' `item'									//Add the selected item to the list of items
				local selecteditems : list uniq selecteditems								//Remove duplicates from the selected items list
				local len : list sizeof selecteditems										//Recalculate the size of the selected items list (so that the while ends when we reach the desired size)
			}
				
			* Store the index of each of the selected items								
			dis "`selecteditems'"
			local itemstosum ""																// Prepare a list of variables to sum
			forvalues i = 1/`selected' {
				local j`i' : word `i' of `selecteditems'									// Extract the number at the end of the sub for each selected item
				local itemstosum `itemstosum' `namelist'`j`i''								// Add all the selected items into one list of variables
			}

			* Calculate the score with these n items
			egen sum_`selected'items_`iteration' = rowtotal(`itemstosum')			
			egen std_`selected'items_`iteration' = std(sum_`selected'items_`iteration')	
				
			* Store the selected items list in a macro
			global selecteditems_`iteration' = "`selecteditems'"
						
		}

end


**** Program that OUTPUTS the difference

program selectitems_diff

	syntax namelist(max=1 id="stubname" local), SELECTed(integer) ITERations(integer) 

preserve			// Preserve so that the original dataset comes back

	selectitems_data `namelist', selected(`selected') iterations(`iterations')

	*** Calc the score with all items, as well as the mean score in the whole population (should be 0, because scores are standardized)
	egen sum_total = rowtotal(`namelist'*)
	egen std_total = std(sum_total)
	egen mean = mean(std_total)

	*** Calculate the difference between subsetted score and full score
	forvalues i = 1/100 {
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


**** Program that OUTPUTS the correlation

program selectitems_corr

 		syntax namelist(max=1 id="stubname" local), SELECTed(integer) ITERations(integer) 

	preserve 																	// Preserve so that the original dataset comes back
		
		selectitems_data `namelist', selected(`selected') iterations(`iterations')
	
		*** Calc the score with all items
		egen sum_total = rowtotal(`namelist'*)
		egen std_total = std(sum_total)
	
		* Compare all scores with selected items to unique score with all items
		cpcorr std_`selected'items_* \ std_total
		
			* Save matrix of coefficients into a dataset
			svmat r(C), names(eqcol)														// Make the correlation coefficients into the dataset and use their equation name (ie a _ will be added at the beginning of the coefficient)
			keep _*																			// Only keep these variables
			duplicates drop																	// Delete all the empty obs (all duplicates, fully missing) : now the number of n is the number of correlation coefficients
			drop if _std_total == .															// Delete an empty obs

				/*TODO CHECK : _n here is number of simulations*/

			* Add back the item selected for each
			gen n = _n

			* Add back the list of selected items for each 
			gen selected_items = ""
			forvalues i = 1/`iterations' {
				replace selected_items = "${selecteditems_`i'}" if _n==`i'	
			}

			* Display histogram 
			hist _std_total, title("Correlations between Subsetted Score and Full Score") subtitle("Distribution of `iterations' iterations selecting a random subset of `selected' items") xtitle("Correlation Coefficient")
		
	restore
end	


**** Program that OUTPUTS all correlations as a function of the number of items selected

program selectitems_allcorr

 		syntax namelist(max=1 id="stubname" local), MINselected(integer) MAXselected(integer) ITERations(integer) 

		//TODO: error if max<min; check that max << number of items

	preserve 																	// Preserve so that the original dataset comes back

		*Calculate score with all items
		egen sum_total = rowtotal(`namelist'*)
		egen std_total = std(sum_total)
		
		forvalues i = `minselected' / `maxselected' {
			selectitems_data `namelist', selected(`i') iterations(`iterations')			
		}
		
		* Compare all scores with selected items to unique score with all items
		cpcorr std_*items_* \ std_total
		
		* Save matrix of coefficients into a dataset
		svmat2 r(C), names(eqcol) rnames(nitems)										// Make the correlation coefficients into the dataset and use their equation name (ie a _ will be added at the beginning of the coefficient) AND include row names
		keep _*	nitems																	// Only keep these variables
		duplicates drop																	// Delete all the empty obs (all duplicates, fully missing) : now the number of n is the number of correlation coefficients
		drop if _std_tot==.																// Delete an empty obs
		gen n_items = substr(nitems, 5, strpos(nitems, "items") - 5)					// Extract the number of items from the nitems var 
		destring(n_items), replace
		drop nitems																		// Drop the nitems var 
		bys n_items: egen meancorr=mean(_std_tot)										// Obtain the mean correlation for these number of items
		drop _std_tot																	// Collapse the dataset at the number of items level
		duplicates drop
		
		* Display relationship
		twoway (line meancorr n_items, sort), title("Mean Correlation Between Subsetted Score and Full Score") subtitle("As a Function of the Number of Items in the Subsetted Score") ytitle("Mean Correlation (across `iterations' iterations)") xtitle("Number of Items in the Subsetted Score")
		
	restore	
		
end		
