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