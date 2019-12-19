#System Control - running system control assumes that the array job is functional
#I.E. properly parallelized, paths to inputs and outputs correct, first array check passed
library(lubridate)
setwd("./scripts/")
#chmod the permuLite R and bash code
system("chmod 755 permuLite_Rcode.R permuLite_run.sh")

#Run 10 array jobs
system("sbatch --array=1-10 permuLite_run.sh")

#Check for 20 out/err files in the log folder
stopifnot(length(list.files("../log")) == 0 )

#Wait loop
cat("\nWaiting for jobs to finish, updates every minute...")
while(length(list.files("../results")) != 10){
  Sys.sleep(60)
}
cat("\nJobs have completed. Profiling jobs for optimization...\n")


#Extract the SLURM job profiles
outfiles <- list.files("../log/", pattern = ".out", full.names = TRUE)
outlist <- list()
for(i in seq_along(outfiles)){
  tmp <- readLines(outfiles[i])
  if(length(tmp) < grep("End of program", tmp)+1){
      outlist[[i]] <- NULL
  }else{
      split <- strsplit(tmp[(grep("End of program", tmp)+1):length(tmp)], ": ")
      trim <- lapply(split, trimws)
      outlist[[i]] <- setNames(sapply(trim, function(x)x[2]),sapply(trim, function(x)x[1]))
  }
  
}
outlist[sapply(outlist, is.null)] <- NULL
res <- do.call("rbind",outlist)

#Note* 
#This method is based on minimizing the moving parts of resource
#allocation. So an appoximation of max mem-per-cpu (2500M) is used.
#The user then selects the number of cores required to run jobs,
#usually overshooting, then using the profile data, optimizes the 
#mem-per-cpu request while maintaining the number of cores for internal
#parallelism. 

#OPTIMIZATION INCORPORTATES SAFETY MARGINS IN RESOURCE REQUESTS
#Calculate optimal time  
pullTime <- strptime(res[,"Used walltime"],'%H:%M:%S')
#convert to strptime
sec <- (pullTime$hour * 3600) + (pullTime$min * 60) + pullTime$sec

#Request twice the average + 3sd time
secForm <- seconds_to_period(ceiling(2*(mean(sec) + 3*sd(sec))))
optTime <- sprintf('%02d:%02d:%02d', secForm@hour, minute(secForm), second(secForm))

#Calculate optimal memory
#Make sure it's in gigs and #cores are constant
stopifnot(all(grepl("G", res[,"Max Mem used"])))
stopifnot(length(unique(res[,"Cores"])) == 1)

#Pull mem and cores and calc a "safe" value
cores <- as.numeric(res[,"Cores"][1])
pullMem <- as.numeric(gsub("[A-Z].*$","",res[,"Max Mem used"]))
optMem <- mean(pullMem) + 4*sd(pullMem)
#round up to nearest half gig
optMem_perCore <- (ceiling(optMem * 2)/2)/cores * 1000

#Re-run sbatch using new mem-per-cpu and time override
cmd_override <- paste0("sbatch --mem-per-cpu=",optMem_perCore,
                       " --time=",optTime,
                       " permuLite_run.sh")
system(cmd_override)

