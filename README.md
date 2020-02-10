# permuLite
Decrease run time for permutation analysis in r/qtl2 eQTL analysis by filtering phenotypes at a conservative threshold determined by quantile standard error. Includes cluster-array faciliation script for permutation validation, results processing, visuzalization, and enrichment of QTL peaks. 

## Pre-Reqs
1. qtl2, lubridate, dplyr, ggplot2, RSQLite, DBI, httr, and enrichR packages installed to local R bin (pty R, install.packages)

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

## Using your own data
Input files are loaded from the /test directory, which holds dummy data for testing purposes. Out-of-the-box version requires the following files in rds format:
- Allele probability object
- Numerical phenotype matrix
- Kinship matrix
- Covariate matrix (make sure categorical variables are dummy coded)
- Mouse Universal Genotyping Array physical map 

These objects are automatically loaded into the permuLite.R script by greping the following keywords:
- "apr", "pheno", "kin", "covar", and "pmap"
- Take care not to have duplicates of these keywords among filenames

Users that wish to load different inputs to perform an additive covariate genome scan using all columns in the covariate matrix need simply replace the default files in /test with their own.

If a user wishes to perform a different scan, add, or exclude one of the default parameters, they must change the following sections of permuLite.R to align with their changes: 

 1. Modify the keywords argument of the loadingBae call within permuLite.R
 2. Modify the loading paths to the genome scan
 3. Modify the arguments of the full genome scan function scan1()
 4. Modify the readRDS inputs and cp inputs in the "Build R script" and "Build batch script" sections, respectively. 

## To Use
0. Setup
 - module load R (must have all required packages in user lib)
 - Roll up bash pseudo terminal (prevent sysadmin toungue-lashing)
 - Git clone onto unix-based cluster (suggested branch: 1.0.0)
 - cd into permuLite
 - (optional) modify the email sbatch input within permuLite to receive run updates
1. Rscript permuLite.R
 - exit pseudoterminal (downstream scripts request their own resources)  
 - cd scripts  
2. Rscript SystemControl.R
 - Keep terminal open until end of script execution
 - User will be alerted to end of 50 permutation run by email
3. Rscript afterCare.R 
 - Users that wish to use the permuLite filtered phenotypes to subset the phenotype matrix to those likely to produce significant QTL can run Rscript permuLite_MainFunc.R to write the filtered phenotype names to /processed
 - Users that wish to forgo analysis of the 50 permutation run may run Rscript haiRspray.R to begin 1,000 permutation run
4. Rscript quiltR_Xsp.R
5. Rscript DOpipe.R
 - Requires user input for output prefix, e.g. "DOproject" -> "DOproject_visualization1, DOproject_visualization2,..."

