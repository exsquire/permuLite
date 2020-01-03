loadingBae <- function(path, key){
  pathIn <- list()
  for(i in seq_along(key)){
    pathIn[[key[i]]] = list.files(path = path,
                                  pattern = key[i],
                                  full.names = TRUE,
                                  ignore.case = TRUE)
  }

  #Check
  if(!all(sapply(pathIn, function(x) length(x) > 0))){
    cat("Error: One or more input(s) could not be found.\n")
    print(sapply(pathIn, function(x) length(x) > 0))
    stop()
  }else{
    cat("\nFound the following inputs: \n")
    print(sapply(pathIn, function(x) length(x) > 0))
  }
  return(pathIn)               
}
