perminatorL <- function(x, defCol = 1, defPerm = 50, ask = FALSE){
  if(ask){
      #Submit phenotype matrix - ask for the col and perm parameters
      askCols <- as.numeric(readline("Columns per chunk: "))
      askPerms <- as.numeric(readline("Permutations per chunk: "))
  }else{
    cat("Using default parameters, single phenotype, 50 permutations\n")
    askCols = defCol
    askPerms = defPerm
  }
  #define cuts 
  starts <- seq(1,ncol(x), askCols)
  stops <-  c(starts[-length(starts)] + (askCols - 1), ncol(x))
  #No need for seed if the permutations aren't split
  aID <- seq(1, length(starts))
  
  #build control object
  ctrl <- data.frame(aID = aID,
                     start = starts,
                     stop = stops,
                     n_perm = askPerms)
  #Output messages
  cat("\nControl file will generate [", nrow(ctrl), "] jobs.")
  cat("\nA single job consists of [", askCols, "] phenotype(s),\nand [",askPerms,"] permutations.\n")
  attr(ctrl, "numPerm") <- askPerms
  attr(ctrl, "numJobs") <- nrow(ctrl)
  return(ctrl)
}
