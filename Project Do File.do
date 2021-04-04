/*
This do file will load individual level census data, and merge cbsa level
black-white segregation indices, population, and income data.

The segregation index is an exposure index - how exposed to white people is the average black
person in a metro area. Lower values are more segregated.

It then runs a regression from Glaeser and Cutler https://www.nber.org/papers/w5163
that examines individual income as a function of metro level segregation and other
individual level and metro level controls. 

The variable of interest is the interaction between a race dummy and the segregation index.

The expect sign of the coefficient is positive, meaning that as a metro becomes less segregated
and the index increases, black income increases.

The result is the expected sign, but the result is insignificant

*/


**************************** Set up ***********************************

//directory
cd "/Users/petermannino/Documents/School/Classes/Statistics/Project/segregation"

capture log close
capture cmdlog close
log using segregation_log, text replace
cmdlog using segregation_cmdlog, replace
capture mkdir "working_data"


************************** Load and Merge Datasets ********************

*load individual census data and save

cd "raw_data/censusdt"
do usa_00008
cd "../../working_data"
save censusdata, replace
clear all

*load conspuma to cba crosswalk

cd "../raw_data/cbsaxwalk"
use data_xwalk_conspuma_cbsa, clear
rename conspuma cpuma0010 //rename this one column
cd "../../working_data"
save, replace
clear all

*merge the cbsa names and IDs into the census data

use censusdata
merge m:1 cpuma0010 using data_xwalk_conspuma_cbsa
keep if _merge == 3

describe
summarize

save, replace
clear all

*open segregation index data from Frey at Brookings and save

cd "../raw_data/segindex"
import excel using msa10p.xls, sheet("Sheet1") firstrow
rename metroid_cbsa_codes cbsa //rename a column
cd "../../working_data"
save segindex, replace
clear all

*merge the segregation indices into the individual census df

use censusdata
merge m:1 cbsa using segindex, generate(merge2)
drop if merge2 != 3
label variable m_xbw_a_10 "Black Exposure Index" //label variable of interest
rename m_xbw_a_10 black_exposure_index //rename variable
save, replace
clear all

*open population by cbsa and save

cd "../raw_data/popdata"
import excel using cbsa-est2013-alldata.xlsx, sheet("Sheet1") firstrow
cd "../../working_data"
save metropops, replace
clear all


*merge the cbsa population data into the individual census data

use censusdata
merge m:1 cbsa using metropops, generate(merge3)
keep if merge3 == 3
save, replace
clear all

*load median income for whole cbsa

cd "../raw_data/metroinc"
import excel using cbsaincome.xls, firstrow
cd "../../working_data"
save cbsaincome, replace
clear all

*merge median income into individual census data

use censusdata
merge m:1 cbsa using cbsaincome, generate(merge4)
keep if merge4 == 3
save,replace

********************** Sample restrictions and New variables **************

*Only keeping white and black individuals
keep if race == 1 | race == 2
keep if hispan == 0

*create a dummy variable for race - white=0, black=1
generate racedum = 1
replace racedum = 0 if race == 1
label variable racedum "Race dummy variable, 1 for black"

*create and interaction term for race and the seg index
generate race_seg = racedum*black_exposure_index
label variable race_seg "Race and Segregation Dummy"

*update gender dummy variable
replace sex = 0 if sex == 1
replace sex = 1 if sex == 2

*drop missing income data
drop if inctot == 9999999 | inctot == -009995 | inctot == -000001 | inctot == 0000000 | inctot == 0000001

bysort cbsa race: generate idnum2 = _N

save,replace

******************************** Summary Table *********************************

*Label race dummy variable
label define racedum 0 "White" 1 "Black"
label values racedum racedum


*dump a big summary table into excel
outreg2 using sum_stat.xls, replace sum(log)

*Create table by race with average characteristics
tabout racedum using summary.xls, c(mean inctot mean black_exposure_index mean censuspop2010 mean medhhinc oneway replace sum f(2m 0c 0c 2m) style(xlsx)



********************************** Graph ***************************************

*Scatterplot of black income on segregation index

preserve

collapse (mean) inctot black_exposure_index, by(cbsa racedum)

scatter inctot black_exposure_index if racedum==1 || lfit inctot black_exposure_index if racedum == 1

restore

******************************** Regression ************************************

*regression with SE clustered at metro level
eststo: regress inctot racedum black_exposure_index race_seg censuspop2010 medhhinc age sex, vce(cluster cbsa)

esttab using "regressions_output.csv", replace b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) addnotes("Standard errors clustered on Metro") scalars("N_clust Clusters") sfmt(0) 


