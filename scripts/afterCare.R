#permuLite afterCare
#Check for missing files
missingNo <- function(pathIn, numJobs){
  actual <- as.numeric(gsub("[^0-9]*","",
                            gsub("^.*_perm_","",list.files(pathIn))))
  expected <- 1:numJobs
  return(expected[!expected %in% actual])
}

#Pull expected number of jobs from control file
ctrl <- readRDS("../processed/control.rds")


miss <- missingNo(pathIn = "../results/", numJobs = nrow(ctrl))

theDash <- function(x){
  status <- numeric(length(x))
  for(i in seq_along(x)){
    if(i == 1 | i == length(x)){
      status[i] <- x[i]
    }else if(x[i-1] == x[i]-1 & x[i+1] == x[i]+1){
      status[i] <- 0
    }else{
      status[i] <- x[i]
    }
  }
  #Compare to a single offset dummy
  collapseDupes <- status[status!=c(status[-1], FALSE)]
  res <- gsub(",0,","-",paste(collapseDupes, collapse = ","))
  return(res)
}

miss_resub <- theDash(miss)

if(length(miss) != 0){
  cat("\nMissing the following files:\n")
  cat(miss, sep = ",")
  cat("\nRe-running...\n")
  cmd_override <- readLines("../processed/opt_params.txt", warn = FALSE)
  re_run <- gsub("sbatch",paste0("sbatch --array=",miss_resub),cmd_override)
  cat("\nRe-running failed jobs.")
  system(re_run)
}

cat("n\Waiting for re-runs to finish...")
while(length(list.files("../results/")) != nrow(ctrl)){
  Sys.sleep(60)
}
cat("\nReruns finished.\n")
cat("\nCombining runs into permutation matrix.")
quiltR <- function(pathIn){
  library(utils)
  files <- list.files(pathIn, full.names = T)
  #Init output list
  outList <- list()
  #Method: Pull in any tmp file, ask it for it's column names, loop through the column names
  #ask if the column name exists as a slot in the list. If it does, append, if not, add.
  pb <- txtProgressBar(min = 0, max = length(files), style = 3)
  for(i in seq_along(files)){
    #Pull the perm output
    tmp <- readRDS(files[i])
    #seq along the columns
    for(j in seq_along(colnames(tmp))){
      if(!colnames(tmp)[j] %in% names(outList)){
        outList[[colnames(tmp)[j]]] <- tmp[[j]]
      }else{
        #concat output to slot data and set
        outList[[colnames(tmp)[j]]] <- c(outList[[colnames(tmp)[j]]],tmp[[j]])
      }
    }
    setTxtProgressBar(pb, i)
  }
  close(pb)
  out <- do.call("cbind", outList)
}

permMat <- quiltR("../results/")

saveRDS(permMat, file = "../processed/permuLite_matrix.rds")

cat("\nDone.\n")