#ClusterScan - running ClusterScan assumes that the array job is functional
#I.E. properly parallelized, paths to inputs and outputs correct, first array check passed
#chmod the permuLite R and bash code
system("chmod 755 genScan_Rcode.R genScan_run.sh")

#Log and results folder must be empty
stopifnot(length(list.files("../scanLogs")) == 0 )
stopifnot(length(list.files("../genScan")) == 0 )

#Run 10 array jobs
system("sbatch -c 10 --array=1-10 genScan_run.sh")

#Check for 20 out/err files in the log folder
#Wait loop
cat("\nWaiting for jobs to finish, updates every minute...")
while(length(list.files("../genScan")) != 10){
  Sys.sleep(60)
}
cat("\nJobs have completed. Gathering profile data for optimization...\n")
#Extract the SLURM job profiles
source("logCabin.R")
res <- logCabin("../scanLogs")
saveRDS(res, "../processed/scanProfOut.rds")

#Note* 
#This method is based on minimizing the moving parts of resource
#allocation. So an appoximation of max mem-per-cpu (2500M) is used.
#The user then selects the number of cores required to run jobs,
#usually overshooting, then using the profile data, optimizes the 
#mem-per-cpu request while maintaining the number of cores for internal
#parallelism. 

#OPTIMIZATION INCORPORTATES SAFETY MARGINS IN RESOURCE REQUESTS
#Calculate optimal time  
source("cmdOverride_scan.R")
