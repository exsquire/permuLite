setwd(".")

#PermuLite: Lite version permutation test using quantile standard error
#method of selecting high confidence phenotypes for permutations
library(qtl2)

dir.create("genScan")
dir.create("scanLogs")
dir.create("processed")
dir.create("log")
dir.create("results")

#Set paths for cross-script accessibility
source("./scripts/loadingBae.R")
pathIn <- loadingBae("./test", key = c("apr",
                                       "pheno",
                                       "kin",
                                       "covar",
                                       "map"))

#present wd
pwd <- getwd()

#Load testing data for genome scan
apr <- readRDS(pathIn[["apr"]])
pheno <- readRDS(pathIn[["pheno"]])
kin <- readRDS(pathIn[["kin"]])
cov <- readRDS(pathIn[["covar"]])
pmap <- readRDS(pathIn[["map"]])
ctrlPath <- "./processed/control.rds"

cat("\nBuilding control file...\n")
#Build a control file that maps your phenotype matrix to different
#runs on a research cluster parallel array job
source("./scripts/perminatorLite.R")
#Select single column, 50 permutations
ctrl <- perminatorL(pheno, ask = F)
saveRDS(ctrl, file = ctrlPath)

################Script Inputs############################

#Set number of cores
useCores <- 2
#Fudge the memory and time allocations
#needMem = use max mem per core for your cluster partition
needMem <- 2500
#Assumes maxCores * needMem is >>> required memory per job, if not, chop up job
maxCores <- 10
#24 hours default
needTime <- "24:00:00"

#########Genome Scan Partner Scripts#####################
#Build R script------------------------------------------------
cat("\nBuilding R script for Genome Scan...\n")
sink("./scripts/genScan_Rcode.R")
cat(
  "library(qtl2)
  #Read in inputs
  apr <- readRDS(",basename(pathIn[["apr"]]),")
  pheno <- readRDS(",basename(pathIn[["pheno"]]),")
  kLOCO <- readRDS(",basename(pathIn[["kin"]]),")
  covar <- readRDS(",basename(pathIn[["covar"]]),")
  pmap <- readRDS(",basename(pathIn[["map"]]),")
  ctrl <- readRDS(",basename(ctrlPath),")
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
  out <- scan1(apr,
  pheno[,start:stop, drop = FALSE],
  kinship = kLOCO,
  addcovar = covar, 
  cores =",useCores,")
  saveRDS(out, file = paste0('genScanOut_',arrayid,'.rds'))
  ", sep = "")
sink()

#Build batch script------------------------------------------------
cat("\nBuilding bash script for Genome Scan...\n")
sink("./scripts/genScan_run.sh")
cat(
"#!/bin/bash -l
#SBATCH -J genScan
#SBATCH -N 1
#SBATCH -c ",maxCores,"
#SBATCH --mem-per-cpu=",needMem,"
#SBATCH --array=1-",nrow(ctrl),"
#SBATCH --partition=med
#SBATCH --time=",needTime,"
#Email me here when job starts, ends, or sh*ts the bed
#SBATCH --mail-user=excel.que@gmail.com
#SBATCH --mail-type=ALL
#SBATCH -o ",pwd,"/scanLogs/genScan-%A_%a.out
#SBATCH -e ",pwd,"/scanLogs/genScan-%A_%a.err
#scratch designation
export SCR_DIR=/scratch/$USER/$SLURM_JOBID/$SLURM_ARRAY_TASK_ID
#Use Full Paths
export OUTPUT_DIR=",pwd,"/genScan
# Load R
module load R
# Create scratch & copy everything over to scratch
mkdir -p $SCR_DIR
cd $SCR_DIR
#Copy over everything for permutation Run
cp -p ",pwd,gsub("^.","", pathIn[["apr"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["pheno"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["kin"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["covar"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["map"]])," . 
cp -p ",pwd,gsub("^.","", ctrlPath)," .
cp -p ",pwd,"/scripts/genScan_Rcode.R .

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
srun R --vanilla --args $SLURM_ARRAY_TASK_ID <  ./genScan_Rcode.R

#Confirm that output made it
echo 'after srun, directory'
ls -al

echo work=$WORK_DIR
echo scr=$SCR_DIR

#Copy results over
cd $OUTPUT_DIR

#change to output directory (now the pwd)
cp -p $SCR_DIR/genScanOut_* .
#Routine Scratch Cleanup
rm -dr $SCR_DIR
echo 'End of program at '`date`''
", sep = "")
sink()

#########Permutation Partner Scripts#####################
#Build R script------------------------------------------------
cat("\nBuilding R script for Permutations...\n")
sink("./scripts/permuLite_Rcode.R")
cat(
  "library(qtl2)
  #Read in inputs
  apr <- readRDS(",basename(pathIn[["apr"]]),")
  pheno <- readRDS(",basename(pathIn[["pheno"]]),")
  kLOCO <- readRDS(",basename(pathIn[["kin"]]),")
  covar <- readRDS(",basename(pathIn[["covar"]]),")
  pmap <- readRDS(",basename(pathIn[["map"]]),")
  ctrl <- readRDS(",basename(ctrlPath),")
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
  perm_Xsp = TRUE, 
  chr_lengths = chr_lengths(pmap),
  cores =",useCores,", 
  n_perm =",ctrl[1,4],")
  saveRDS(perm, file = paste0('permuLiteOut_',arrayid,'.rds'))
  ", sep = "")
sink()

#Build batch script------------------------------------------------
cat("\nBuilding bash script for Permutations...\n")
sink("./scripts/permuLite_run.sh")
cat(
"#!/bin/bash -l
#SBATCH -J permuLite
#SBATCH -N 1
#SBATCH -c ",maxCores,"
#SBATCH --mem-per-cpu=",needMem,"
#SBATCH --array=1-",attributes(ctrl)$numJobs,"
#SBATCH --partition=med
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
cp -p ",pwd,gsub("^.","", pathIn[["apr"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["pheno"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["kin"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["covar"]])," .
cp -p ",pwd,gsub("^.","", pathIn[["map"]])," . 
cp -p ",pwd,gsub("^.","", ctrlPath)," .
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
