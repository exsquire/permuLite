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
0. Setup
 - module load R (must have all required packages in user lib)
 - Roll up bash pseudo terminal (prevent sysadmin toungue-lashing)
 - Git clone onto unix-based cluster (suggested branch: 1.0.0)
 - cd into permuLite
1. Rscript permuLite.R
 - exit pseudoterminal (downstream scripts request their own resources)  
 - cd scripts  
2. Rscript SystemControl.R
3. Rscript afterCare.R
4. Rscript quiltR_Xsp.R
5. Rscript DOpipe.R
