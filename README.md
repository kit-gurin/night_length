# Night length modulates species-level activity-timing responses of mammals to urbanization

### Data/code DOI: 
__________________________________________________________________________________________________________________________________________

## Abstract
**Aim.** Animal behavior, including activity timing, is a first line of defense against anthropogenic stressors. While many mammal species become more nocturnal in human-dominated landscapes, the degree to which night length constrains these responses remains unknown. Our goal was to establish the role—if any—of night length in modulating activity-timing responses of mammals to urbanization. 

**Location.** North America and Europe

**Time Period.** Contemporary. 

**Group.** Nocturnal and crepuscular mammals in urban areas (17 taxa). 

**Methods.** We used camera-trap data on seventeen nocturnal and crepuscular mammal taxa from 39 cities over eight years to model the relationship between time-from-nadir (hours from the darkest point of night) of wildlife photo-detections and night length along an urban gradient using generalized linear mixed-effects models. 

**Results.** On average, wildlife were active farther from solar nadir on long nights. Across species, there was no evidence that night length constrained activity-timing responses to urbanization. However, this lack of an effect at a cross-species level is due to variability among species. Five species, including cougar and striped skunk, showed stronger relationships between time-from-nadir and urbanization on short nights, supporting the release hypothesis. Six species, including Virginia opossum and bobcat, showed similar relationships between time-from-nadir and urbanization on nights of varying length, supporting the null hypothesis. And finally, six species, including nine-banded armadillo and gray fox, showed weaker relationships between time-from-nadir and urbanization on short nights, supporting neither of our hypotheses

**Main Conclusions.** For some species, night length is an important factor in modulating activity-timing responses of mammals to urbanization. Recognizing night length as a key driver will strength our understanding of how animals respond behaviorally to disturbance.

## Repository Directory
### Code

NOTE: Due to data sharing expectations of the Urban Wildlife Information Network, we cannot share the raw photo-detection data tables with geographic coordinates. Thus, we commented out the [first script that formats these data](./code/01_data_prep.R), and provide the [formatted data object](./data/obs.RDS) in this repository so it can be loaded to re-run analyses and produce visualizations.

* [01_data_prep.R](./code/01_data_prep.R). Formats raw detection data into the data object used for running analyses and producing visualizations. It also includes Google Earth Engine code (lines 55-90) to pull [Global Human Modification](https://doi.org/10.5281/zenodo.14449495) covariate data.
* [02_analysis_and_results.R](./code/02_analysis_and_results.R). Fits the multi-species GLMM, creates cross-species and species-level predictions based on the data, and produces results and visualizations.

### Data
* [ghm_values.csv](./data/ghm_values.csv). CSV file with ghm values for each site in the analysis. Code to create this data object is in [01_data_prep.R](./code/01_data_prep.R).
* [MamFuncDat.txt](./data/MamFuncDat.txt). Text file with [EltonTraits](https://doi.org/10.1890/13-1917.1) data. Activity.Nocturnal and Activity.Crepuscular columns were used to determine which taxa fit inclusion criteria for the study.
* [obs.rds](.data/obs.rds). RDS file of formatted species detection data and all covariates necessary to run [02_analysis_and_results.R](./code/02_analysis_and_results.R). Each row represents a single camera detection, and the following covariates:
    | column | description |
    |--------|---------|
    | city | UWIN city code  |
    | site | unique site identifier |
    | timestamp | time camera trap photo was taken |
    | sp | common name of taxa to family, genus or species level |
    | gHM | [global human modification](https://developers.google.com/earth-engine/datasets/catalog/CSP_HM_GlobalHumanModification) value at camera coordinates ranging from 0 (low human disturbance) to 1 (high human disturbance) |
    | season | sampling campaign season only (winter, spring, summer, fall |
    | sample_period | standardized sampling campaign (YYYY-MM-01) that aligns best with the start/end date of each camera deployment. |
    | nadir | closest solar nadir (darkest point of night) to the timestamp
    | nadir_diff | difference between nadir and timestamp in minutes |
    | nl | night length in hours |
