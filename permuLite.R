setwd(".")

#PermuLite: Lite version permutation test using quantile standard error
#method of selecting high confidence phenotypes for permutations
library(qtl2)

dir.create("processed")
dir.create("log")
dir.create("results")

#Set paths for cross-script accessibility 
probPath = "./test/oneChr_apr.rds"
phenPath = "./test/testPheno.rds"
kinPath = "./test/testKin.rds"
covPath = "./test/testCovar.rds"
mapPath = "./test/pmap.rds"
ctrlPath = "./processed/control.rds"

#present wd
pwd <- getwd()

#Load testing data for genome scan
apr <- readRDS(probPath)
pheno <- readRDS(phenPath)
kin <- readRDS(kinPath)
cov <- readRDS(covPath)
pmap <- readRDS(mapPath)


cat("\nBuilding control file...\n")
#Build a control file that maps your phenotype matrix to different
#runs on a research cluster parallel array job
source("./scripts/perminatorLite.R")
#Select single column, 50 permutations
ctrl <- perminatorL(pheno, ask = F)
saveRDS(ctrl, file = ctrlPath)

cat("\nRunning Full Genome Scan...\n")
#Run the full genome scan
out <- scan1(genoprobs = apr, 
             pheno = pheno, 
             kinship = kin, 
             addcovar = cov,
             cores = 4)

saveRDS(out,"./processed/testOut.rds")

#Set number of cores
useCores <- 2

invisible(gc())

cat("\nEstimating Time and Memory Allocation...\n")
t <- system.time(
  test <- scan1perm(apr, pheno[,1,drop = F],
                    kinship = kin,
                    addcovar = cov,
                    n_perm = 50,
                    cores = useCores)
)

#Estimate the amount of memory
#needMem = max mem since last gc() + max Mb used in scan
#times number of cores
needMem <- sum(gc()[,6]) * useCores
needMem <- round(needMem * 1.2)

#Estimate the run time in hours
needTime <- as.numeric(ceiling(t[3] / 60 /60) + 1)
needTime <- paste0("0", needTime, ":00:00")

cat("\nBuilding R script...\n")
#------------------------------------------------
#Build R script
sink("./scripts/permuLite_Rcode.R")
cat(
  "library(qtl2)
  #Read in inputs
  apr <- readRDS(",basename(probPath),")
  pheno <- readRDS(",basename(phenPath),")
  kLOCO <- readRDS(",basename(kinPath),")
  covar <- readRDS(",basename(covPath),")
  ctrl <- readRDS(",basename(ctrlPath),")
  pmap <- readRDS(",basename(mapPath),")
  ", sep = "'")

cat(
  "#Intialize array id - array id will only function as a sequential designation
  args<-as.integer(unlist(strsplit(commandArgs(TRUE),' ')))
  print(args)
  arrayid <-args[1]
  print(arrayid)
  #Cores controlled from command line
  #No longer a need for control file.
  start <- ctrl[arrayid, 2]
  stop  <- ctrl[arrayid, 3]
  #Run scan1perm
  perm <- scan1perm(apr,
  pheno[,start:stop, drop = FALSE],
  kinship = kLOCO,
  addcovar = covar,
  cores =",useCores,", 
  n_perm =",ctrl[1,4],")
  out <- data.frame(perm, check.names = F)
  saveRDS(out, file = paste0('permuLiteOut_',arrayid,'.rds'))
  ", sep = "")
sink()

cat("\nBuilding bash script...\n")
#------------------------------------------------
#Build batch script
sink("./scripts/permuLite_run.sh")
cat(
"#!/bin/bash -l
#SBATCH -J permuLite
#SBATCH -N 1
#SBATCH -c ",useCores,"
#SBATCH --mem-per-cpu=",needMem,"
#SBATCH --array=1-",attributes(ctrl)$numJobs,"
#SBATCH --partition=high
#SBATCH --time=",needTime,"
#Email me here when job starts, ends, or sh*ts the bed
#SBATCH --mail-user=excel.que@gmail.com
#SBATCH --mail-type=ALL
#SBATCH -o ",pwd,"/log/permuLite-%A_%a.out
#SBATCH -e ",pwd,"/log/permuLite-%A_%a.err
#scratch designation
export SCR_DIR=/scratch/$USER/$SLURM_JOBID/$SLURM_ARRAY_TASK_ID
#Use Full Paths
export OUTPUT_DIR=",pwd,"/results
# Load R
module load R
# Create scratch & copy everything over to scratch
mkdir -p $SCR_DIR
cd $SCR_DIR
#Copy over everything for permutation Run
cp -p ",pwd,gsub("^.","", probPath)," .
cp -p ",pwd,gsub("^.","", phenPath)," .
cp -p ",pwd,gsub("^.","", kinPath)," .
cp -p ",pwd,gsub("^.","", covPath)," .
cp -p ",pwd,gsub("^.","", ctrlPath)," .
cp -p ",pwd,gsub("^.","", mapPath)," . 
cp -p ",pwd,"/scripts/permuLite_Rcode.R .

#Confirm presence of input files in scratch
echo 'before srun in dir'
pwd
echo 'contents'
ls -al
# Termination Signal Trap - when a job goes over its walltime or user cancels job
termTrap()
{
echo 'Termination signal sent. Clearing scratch before exiting'
# do whatever cleanup you want here
rm -dr $SCR_DIR
exit -1
}
trap 'termTrap' TERM
#Run lightweight R instance
srun R --vanilla --args $SLURM_ARRAY_TASK_ID <  ./permuLite_Rcode.R

#Confirm that output made it
echo 'after srun, directory'
ls -al

echo work=$WORK_DIR
echo scr=$SCR_DIR

#Copy results over
cd $OUTPUT_DIR

#change to output directory (now the pwd)
cp -p $SCR_DIR/permuLiteOut_* .
#Routine Scratch Cleanup
rm -dr $SCR_DIR
echo 'End of program at '`date`''
", sep = "")
sink()

cat("\nDone.\n")
