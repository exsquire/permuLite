#The meat and potatoes of permuLite
#The man himself
library(broman)

#Load in the outfile from ../processed
out <- readRDS("../processed/testOut.rds")

maxLOD_fullOut <- apply(out, 2, max)
saveRDS(maxLOD_fullOut, file = "../processed/maxLOD_fullOut.rds")

#Load FullPerm threshfile
perms <- readRDS("../processed/permuLite_matrix_A.rds")
q <- apply(perms, 2, quantileSE, p = 0.9)
permQ <- q[1,]  
permSE  <- q[2,]


#Set the new perm threshold to the 90th quantile minus on SE for that quantile
permThresh <- permQ - (permSE)


#Match order
permThresh <- permThresh[match(names(maxLOD_fullOut), names(permThresh))]
#check
stopifnot(names(maxLOD_fullOut) == names(permThresh))


#Test
table(maxLOD_fullOut >= permThresh)
pLite_filter <- names(maxLOD_fullOut)[which(maxLOD_fullOut >= permThresh)]

#Write out the filter to be used in subsetting phenotype matrices for the full run. 
saveRDS(pLite_filter, "../processed/pLite_filter.rds")
