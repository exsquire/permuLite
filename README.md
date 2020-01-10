# permuLite
Decrease run time for permutation analysis in r/qtl2 eQTL analysis by filtering phenotypes at a conservative threshold determined by quantile standard error. 

## Pre-Reqs
1. qtl2, lubridate, dplyr, ggplot, RSQLite, httr, and EnrichR packages installed to local R bin (pty R, install.packages)

## Method
0. git clone -b 1.0.0 --single-branch https://github.com/exsquire/permuLite.git
1. Submit phenotype matrix and build control file with permuLite.R for 50 permutations
2. Use control file to direct array job on cluster
3. Combine output into a pLite_thresh matrix
4. Calculate the quantile standard error at the 90th quantile
5. Set phenotype-specific thresholds at the 90th quantile of their pLite null distribution minus its quantile standard error
6. Perform a Genome scan 
7. Filter for phenotypes whose max genome scan lod score is greater than its threshold in step 5. 
8. Run 1,000 permutation on filtered phenotypes. 

## To Use
0. Roll up bash pseudo terminal (prevent sysadmin toungue-lashing)
1. Git clone onto unix-based cluster (suggested branch: 1.0.0)
2. cd into permuLite
 - module load R (must have all required packages in user lib)
3. Rscript permuLite.R
- Inspect newly generated R and bash scripts in /scripts
4. exit pseudoterminal (downstream scripts request their own resources)  
5. cd scripts  
6. Rscript SystemControl.R
- Runs 10 jobs at "max" resource allocation, collect profile data, re-runs all jobs with optimized resource requests. 
7. Rscript afterCare.R
- afterCare.R identifies missing jobs in sequentially named runs (i.e. runA_job1, runA_job2, etc.)
- then re-runs the failed jobs with an additional core of memory
8. Rscript quiltR_Xsp.R
- sticks array job together into permutation matrices, one for Autosomes and one for X chromosome
