#Submit a vector of genes to Ma'ayan Labs' EnrichR Tool
#Uses API query method from enrichR package: https://cran.r-project.org/package=enrichR. 
enrichrMod <- function (genes, alpha = 0.05, 
                        databases = as.character(listEnrichrDbs()[["libraryName"]]), quiet = F) 
{
  library(httr)
  library(enrichR)
  if(quiet == F){
    cat("Uploading data to Enrichr... ")
  }
  
  #Call and Response to EnrichR
  if (is.vector(genes)) {
    temp <- POST(url = "http://amp.pharm.mssm.edu/Enrichr/enrich", 
                 body = list(list = paste(genes, collapse = "\n")))
  }
  else {
    warning("genes must be a vector of gene names.")
  }
  GET(url = "http://amp.pharm.mssm.edu/Enrichr/share")
  if(quiet == F){
    cat("Done.\n")
  }
  
  #Load all available databases on enrichR
  dbs <- as.list(databases)
  dfSAF <- options()$stringsAsFactors
  options(stringsAsFactors = FALSE)
  
  #Pull query results and format
  result <- lapply(dbs, function(x) {
    if(quiet == F){
      cat("  Querying ", x, "... ", sep = "")
    }
    r <- GET(url = "http://amp.pharm.mssm.edu/Enrichr/export", 
             query = list(file = "API", backgroundType = x))
    r <- intToUtf8(r$content)
    tc <- textConnection(r)
    r <- read.table(tc, sep = "\t", header = TRUE, quote = "", fill = T)
    close(tc)
    if(quiet == F){
      cat("Done.\n")
    }  
    return(r)
  })
  
  options(stringsAsFactors = dfSAF)
  if(quiet == F){
    cat("Parsing results... ")
  }
  
  #Name for databases searched
  names(result) <- dbs
  if(quiet == F){
    cat("Done.\n")
  }
  
  #Cull searches with no results
  nullCull <- function(x, alpha = 0.05){
    #for each slot, check Adjusted.P.Value column
    #Null if greater than 0.05
    if(nrow(x) == 0){
      x <- NULL
    }else{
      x <- x[x$Adjusted.P.value <= alpha,-c(5,6)]
    }
  }
  res <- lapply(result, nullCull, alpha = alpha)
  if(any(sapply(res,is.null))){
    res <- res[sapply(res,is.null) != TRUE]
  }
    
  #Cull any empty dataframes after initial filter
  if(sum(sapply(res, nrow)) == 0){
    return(NULL)
  }else{
    sigRes <- res[sapply(res, nrow) != 0]
    outList <- list()
    for(j in 1:length(sigRes)){
        desig <- names(sigRes)[j]
        outList[[j]] <- cbind(data.frame(Library = desig,
                                     stringsAsFactors = F),
                          sigRes[[j]])
    }
    #Output as dataframe
    return(do.call("rbind",outList))
  }
}
