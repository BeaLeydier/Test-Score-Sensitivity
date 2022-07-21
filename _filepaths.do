

/*******************************************************************************

		STEP : Define file paths and working directories
		
*******************************************************************************/

	/*______________
	|				|
	|	Github		|
	|_______________*/


* Define machine-specific file path 

if c(username)=="bl517" {
	global gituser "C:/Users/bl517/Documents/Github/Test-Score-Sensitivity"
}
else if c(username)=="" {
	global gituser ""
}
else {
	di as err "Please enter machine-specific path information for the git repo"
	exit
}


* Define relative file paths as globals


	/*______________
	|				|
	|	Dropbox		|
	|_______________*/


* Define machine-specific file path 

if c(username)=="bl517" {
	global dropboxuser "C:/Users/bl517/Dropbox"
}
else if c(username)=="Beatrice" {
	global dropboxuser "C:/Users/Beatrice/Dropbox"
}
else if c(username)=="" {
	global dropboxuser ""
}
else {
	di as err "Please enter machine-specific path information for the Dropbox files"
	exit
}


* Define relative file paths as globals

global public "LEAPS_data/Public_2021/data"
global RCT "LEAPS_data/Public_2021_ondemand/codes"
global census "LEAPS_data/Public_2021_ondemand/census"
global rawscores "LEAPS_data/Public_2021_ondemand/data"

global data "LEAPS Beatrice/TestScores_Sensitivity/Data"
global output "LEAPS Beatrice/TestScores_Sensitivity/Out"


cd "$gituser"
