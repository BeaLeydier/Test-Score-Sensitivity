**** Program that (locally) generates the data needed for the output programs

program define selectitems_data
			
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
		dis "`items'"
	
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
			egen mean_`selected'items_`iteration' = rowmean(`itemstosum')			
			egen std_`selected'items_`iteration' = std(mean_`selected'items_`iteration')	
				
			* Store the selected items list in a macro
			global selecteditems_`iteration' = "`selecteditems'"
						
		}

end
