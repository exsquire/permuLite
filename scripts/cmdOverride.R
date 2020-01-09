#Using SLURM job profile data, override sbatch resource requests with new values - for permuLite
#Cluster and run-specific variables
library(lubridate)
maxCoreMB <- 2500
coresPerUnit <- 2

if(!exists("res")){
  res <- readRDS("../processed/profOut.rds")
}

#Do calculations on profile data-----------------------------------
#Pull 
isComp <- res[,"State"] == "COMPLETED" | res[,"State"] == "RUNNING"
pullTime <- strptime(res[isComp,"Used walltime"],'%H:%M:%S')
#convert to strptime
sec <- (pullTime$hour * 3600) + (pullTime$min * 60) + pullTime$sec

#Request twice the max
secForm <- seconds_to_period(ceiling(2*(max(sec))))
optTime <- sprintf('%02d:%02d:%02d', secForm@hour, minute(secForm), second(secForm))

#Calculate optimal memory
#Make sure #cores are consistant
stopifnot(length(unique(res[isComp,"Cores"])) == 1)

#pull Max memory used
pullMem <- gsub("[A-Z].*$","",res[isComp,"Max Mem used"])
pullMem <- as.numeric(gsub("^.* .*$","0.00",pullMem))

  
#Allow for differentiation between M and G - potential lack of robustness depending on cpu name, e.g. M10-92 
if(!all(grepl("G", res[isComp,"Max Mem used"]))){
  inMb <- grepl("M", res[isComp, "Max Mem used"])
  pullMem[inMb] <- pullMem[inMb]/1000
}

#Safety margin is 120% + 4sd of max 'max mem used' 
optMem <- 1.2*(max(pullMem)) + 4*sd(pullMem)

#Optimize Resource Allocation---------------------------------------
#Start with minimum cores required by unit multicore parameters
adjustCores <- coresPerUnit
#distribute optMem allocation among cores, calculate mem per core, round up to the nearest half gig
optMem_perCore <- (ceiling(optMem * 2)/2)/adjustCores * 1000
#If minimum cores are enough, dedicate full resources to job, 
#Else, distribute optimal mem allocation among cores, increment cores and iterate until mem request dips below max per CPU limit
if(optMem_perCore <= maxCoreMB){
  optMem_perCore <- maxCoreMB
}else{
  while(optMem_perCore > maxCoreMB){
    adjustCores <- adjustCores + 1
    optMem_perCore <- ceiling((ceiling(optMem * 2)/2)/adjustCores * 1000)
  }
}
#--------------------------------------------------------------------                                                                    
#Re-run sbatch using new mem-per-cpu and time override
cmd_override <- paste0("sbatch --mem-per-cpu=",optMem_perCore,
                       " --time=",optTime,
                       " -c ",adjustCores,
                       " permuLite_run.sh")
#write out the optimal parameters                       
sink("../processed/opt_params.txt")
cat(cmd_override)
sink()
system(cmd_override)
