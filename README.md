# permuLite
Decrease run time for permutation analysis in r/qtl2 eQTL analysis by filtering phenotypes at a conservative threshold determined by quantile standard error. 


## Method
1. Submit phenotype matrix and build control file with permuLite.R for 50 permutations
2. Use control file to direct array job on cluster
3. Combine output into a pLite_thresh matrix
4. Calculate the quantile standard error at the 90th quantile
5. Set phenotype-specific thresholds at the 90th quantile of their pLite null distribution minus its quantile standard error
6. Filter for phenotypes whose max genome scan lod score is greater than its threshold in step 5. 
7. Run 1,000 permutation on filtered phenotypes. 
