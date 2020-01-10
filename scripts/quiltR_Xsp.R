cat("\nCombining runs into permutation matrix.")
quiltR <- function(pathIn, autosomal = TRUE){
  library(utils)
  files <- list.files(pathIn, full.names = T)
  #Init output list
  outList <- list()
  #Method: Pull in any tmp file, ask it for it's column names, loop through the column names
  #ask if the column name exists as a slot in the list. If it does, append, if not, add.
  pb <- txtProgressBar(min = 0, max = length(files), style = 3)
  for(i in seq_along(files)){
    #Pull the perm output
    if(autosomal == TRUE){
      tmp <- readRDS(files[i])$A
    }else{
      tmp <- readRDS(files[i])$X
    }
    #seq along the columns
    for(j in seq_along(colnames(tmp))){
      if(!colnames(tmp)[j] %in% names(outList)){
        outList[[colnames(tmp)[j]]] <- tmp[,colnames(tmp)[j]]
      }else{
        #concat output to slot data and set
        outList[[colnames(tmp)[j]]] <- c(outList[[colnames(tmp)[j]]],tmp[,colnames(tmp)[j]])
      }
    }
    setTxtProgressBar(pb, i)
  }
  close(pb)
  out <- do.call("cbind", outList)
}

permMatA <- quiltR("../results/", autosomal = TRUE)
permMatX <- quiltR("../results/", autosomal = FALSE)

saveRDS(permMatA, file = "../processed/permuLite_matrix_A.rds")
saveRDS(permMatX, file = "../processed/permuLite_matrix_X.rds")

cat("\nDone.\n")
