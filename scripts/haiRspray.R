#haiRspray
#setwd("D:/Parent/Testing/mixedCovar_Raw/permuLite/scripts")

#Copy permuLite control file as control_lite.rds
file.copy("../processed/control.rds", 
          "../processed/control_lite.rds")

#Overwrite control.rds with new control file
##Load control file
loadCtrl <- "../processed/control.rds"
newCtrl <- readRDS(loadCtrl)
oldRows <- nrow(newCtrl)

#Replicate 20 times: 50 x 20 = 1000
newCtrl <- do.call("rbind", replicate(20, newCtrl, simplify = F))
newCtrl$aID <- seq(1:nrow(newCtrl))

#Overwrite control.rds with fullPerm params
saveRDS(newCtrl, file = loadCtrl)

#Re-run sbatch using new mem-per-cpu and time override
fullPerm <- readLines("../processed/opt_params.txt",
                       n = 1, warn = F)

#Override the array parameters, skipping run jobs
fullPerm <- gsub("sbatch",paste0("sbatch --array=",oldRows,"-",nrow(newCtrl)),fullPerm)

#Sink it to processed
sink("../processed/fullPerm_params.txt")
cat(fullPerm)
sink()

system(fullPerm)