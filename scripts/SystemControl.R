#System Control - running system control assumes that the array job is functional
#I.E. properly parallelized, paths to inputs and outputs correct, first array check passed
library(lubridate)
#chmod the permuLite R and bash code
system("chmod 755 permuLite_Rcode.R permuLite_run.sh")

#Log and results folder must be empty
stopifnot(length(list.files("../log")) == 0 )
stopifnot(length(list.files("../results")) == 0 )

#Run 10 array jobs
system("sbatch -c 10 --array=1-10 permuLite_run.sh")

#Check for 20 out/err files in the log folder
#Wait loop
cat("\nWaiting for jobs to finish, updates every minute...")
while(length(list.files("../results")) != 10){
  Sys.sleep(60)
}
cat("\nJobs have completed. Gathering profile data for optimization...\n")
#Extract the SLURM job profiles
source("logCabin.R")
res <- logCabin("../log")
saveRDS(res, "../processed/profOut.rds")

#Note* 
#This method is based on minimizing the moving parts of resource
#allocation. So an appoximation of max mem-per-cpu (2500M) is used.
#The user then selects the number of cores required to run jobs,
#usually overshooting, then using the profile data, optimizes the 
#mem-per-cpu request while maintaining the number of cores for internal
#parallelism. 

#OPTIMIZATION INCORPORTATES SAFETY MARGINS IN RESOURCE REQUESTS
#Calculate optimal time  
#For completed runs only
isComp <- res[,"State"] == "COMPLETED" | res[,"State"] == "RUNNING"
pullTime <- strptime(res[isComp,"Used walltime"],'%H:%M:%S')
#convert to strptime
sec <- (pullTime$hour * 3600) + (pullTime$min * 60) + pullTime$sec

#Request twice the max
secForm <- seconds_to_period(ceiling(2*(max(sec))))
optTime <- sprintf('%02d:%02d:%02d', secForm@hour, minute(secForm), second(secForm))

#Calculate optimal memory
#Make sure it's in gigs and #cores are constant
stopifnot(all(grepl("G", res[isComp,"Max Mem used"])))
stopifnot(length(unique(res[isComp,"Cores"])) == 1)

#Pull mem and calc a "safe" value - 120% + 4sd
pullMem <- as.numeric(gsub("[A-Z].*$","",res[isComp,"Max Mem used"]))
optMem <- 1.2*(max(pullMem)) + 4*sd(pullMem)

#Adjust cores so optMem_perCore is close to max mem per core
#But not over max mem per core
#2500M is partition specific - enter your own partition's max if different
adjustCores <- 2
#round up to nearest half gig
optMem_perCore <- (ceiling(optMem * 2)/2)/adjustCores * 1000
#If 2 cores are enough, keep, but update mem request
#Else, increase cores and update mem request
if(optMem_perCore <=2500){
  optMem_perCore <- 2500
}else{
  while(optMem_perCore > 2500){
    adjustCores <- adjustCores + 1
    optMem_perCore <- ceiling((ceiling(optMem * 2)/2)/adjustCores * 1000)
  }
}
                                                                    
#Re-run sbatch using new mem-per-cpu and time override
cmd_override <- paste0("sbatch --mem-per-cpu=",optMem_perCore,
                       " --time=",optTime,
                       " -c ",adjustCores,
                       " permuLite_run.sh")
sink("../processed/opt_params.txt")
cat(cmd_override)
sink()
system(cmd_override)

