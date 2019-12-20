# permuLite
Decrease run time for permutation analysis in r/qtl2 eQTL analysis by filtering phenotypes at a conservative threshold determined by quantile standard error. 


## Method
1. Submit phenotype matrix and build control file with permuLite.R for 50 permutations
2. Use control file to direct array job on cluster
3. Combine output into a pLite_thresh matrix
4. Calculate the quantile standard error at the 90th quantile
5. Set phenotype-specific thresholds at the 90th quantile of their pLite null distribution minus its quantile standard error
6. Perform a Genome scan 
7. Filter for phenotypes whose max genome scan lod score is greater than its threshold in step 5. 
8. Run 1,000 permutation on filtered phenotypes. 

## To Use
1. Git clone onto unix-based cluster
2. cd into permuLite
3. Rscript permuLite.R
- Inspect newly generated R and bash scripts in /scripts
4. cd scripts
5. Rscript SystemControl.R
- Runs 10 jobs, optimizes memory and time allocations based on logged outfiles, runs full job with optimized parameters. 
6. Test afterCare utility suite. 
- cd /results, remove files at random
- cd /scripts
- chmod 755 afterCare.R
- Rscript afterCare.R 
- Re-runs failed or missing runs, combines jobs into permutation matrix based on column name 
