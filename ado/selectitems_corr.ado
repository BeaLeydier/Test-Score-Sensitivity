

**** Program that OUTPUTS the correlation

program define selectitems_corr

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
