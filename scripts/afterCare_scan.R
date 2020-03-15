#permuLite afterCare for Genome Scan
#Check for missing files
missingNo <- function(pathIn, numJobs){
  actual <- as.numeric(gsub("[^0-9]*","",
                            gsub("^.*_perm_","",list.files(pathIn))))
  expected <- 1:numJobs
  return(expected[!expected %in% actual])
}

#Pull expected number of jobs from control file
ctrl <- readRDS("../processed/control.rds")


miss <- missingNo(pathIn = "../genScan/", numJobs = nrow(ctrl))

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
  cmd_override <- readLines("../processed/opt_ScanParams.txt", warn = FALSE)
  re_run <- gsub("sbatch",paste0("sbatch --array=",miss_resub),cmd_override)
  cat("\nRe-running failed jobs.\n")
  system(re_run)
}else{
  cat("\nAll jobs present and accounted for!\n")
  cat("\nBinding contents of genScan...\n")
  outlist <- list()
  path = "../genScan/"
  files = list.files(path, full.names = TRUE)
  for(i in seq_along(files)){tmp <- readRDS(files[i]); outlist[[i]] <- tmp}
  res <- do.call("cbind", outlist)
  cat("\nWriting output to /processed/testOut.rds\n")
  saveRDS(res,"../processed/testOut.rds")
}
