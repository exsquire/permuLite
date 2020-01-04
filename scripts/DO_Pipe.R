#DO_PIPE
dir.create("../output")
dir.create("../output/data")
dir.create("../output/plots")
dir.create("../output/plots/lod/")

#Select threshold level: 1 = 63% (associative), 2 = 95% (significant), 3 = 99% (highly significant)
#If different thresholds are required, they can be generated from the full permutation matrix

prefix <- "DOWL_addCov_Raw"
permMat <- readRDS("../processed/permuLite_matrix_A.rds")
permThresh <- apply(permMat, 2, quantile, probs = c(0.63, 0.9, 0.95, 0.99))
pmap <- readRDS(list.files(path = "../test/", pattern = "map", full.names = T))


scanOut <- readRDS("../processed/testOut.rds")
#IMPORTANT: align the order of the permThresh columns with the scanOut columns
permThresh <- permThresh[,match(colnames(scanOut), colnames(permThresh))]
stopifnot(colnames(permThresh) == colnames(scanOut))
for(i in 1:nrow(permThresh)){
  desig <- paste0("signif_",gsub("%","",rownames(permThresh)[i]))
  thresh = permThresh[i,]
  peaks <- find_peaks(scanOut, pmap,
                      threshold = thresh,
                      drop = 1.8)
  for(j in 1:nrow(permThresh)){
    desig2 <- paste0("signif_",gsub("%","",rownames(permThresh)[j]))
    peaks[[desig2]] <- permThresh[j,][match(peaks$lodcolumn, colnames(permThresh))]
  }
  if(nrow(peaks) == 0){
    next()
  }
  saveRDS(peaks, file = paste0("../output/data/", prefix, "_peaks_",desig,".rds"))
}



#Analyze the 63 quantile peak file 
peaks <- readRDS(paste0("../output/data/",prefix,"_peaks_signif_63.rds"))
#Remove x chromosome peaks, then loop plot from the outfile
peaks_noX <- peaks[peaks$chr != "X",]
cat("Generating",nrow(peaks_noX),"plots...")
pb <- txtProgressBar(min = 1, 
                     max = nrow(peaks_noX), 
                     style = 3)
for(i in 1:nrow(peaks_noX)){
  tmp <- peaks_noX[i,]
  desig <- paste0(tmp$lodcolumn,"-",
                  "chr",tmp$chr,
                  "-",floor(tmp$ci_lo),
                  "-",ceiling(tmp$ci_hi))
  pheno <- which(colnames(scanOut) == tmp$lodcolumn)
  chr <- tmp$chr
  png(paste0("../output/plots/lod/",desig,".png"),
      res = 300,
      height = 1600,
      width = 2400)
  plot_scan1(scanOut, map = pmap, 
             lodcolumn = pheno,
             chr = chr,
             col = "dodgerblue2",
             bgcol="white",
             main = tmp$lodcolumn,
             cex = 1.5)
  dev.off()
  setTxtProgressBar(pb, i)
}
close(pb)
cat("Generating Global Peak Summary Plot...")
png(paste0("../output/plots/lod/",prefix,"_peakSummary",".png"),
    res = 300,
    height = 2400,
    width = 3000)
par(mar = c(4,15,4,2))
plot_peaks(peaks_noX, 
           map = pmap, 
           col = c("dodgerblue3"), 
           lwd = 3,
           cex.lab = 0.5,
           tick.height = 0.8,
           gap = 0, 
           main = "Global Peak Summary",
           alt = "white")
box()
dev.off()
