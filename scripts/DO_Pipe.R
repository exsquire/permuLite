#DO_PIPE
setwd(".")
#----------------
library(DBI)
library(qtl2)
library(dplyr)
library(httr)
library(RSQLite)
library(enrichR)
source("enrichRMod.R")

dir.create("../output/data/peak-genes", recursive = TRUE, showWarnings = FALSE)
dir.create("../output/data/enrichr-results", showWarnings = FALSE)
dir.create("../output/plots/lod/", recursive = TRUE, showWarnings = FALSE)

#Select threshold level: 1 = 63% (associative), 2 = 95% (significant), 3 = 99% (highly significant)
#If different thresholds are required, they can be generated from the full permutation matrix


cat("\nInput run name...\n")
con <- file("stdin")
prefix <- readLines(con, n=1)
close(con)

#Local testing only-----
#prefix <- "mixedCovar_Raw"
#stopifnot(!grepl(" ", prefix))
#-----------------------
saveRDS(prefix, "../processed/prefix.rds")

cat("Loading Autosomal Permutation Matrix...\n")
permMat <- readRDS("../processed/permuLite_matrix_A.rds")
permThresh <- apply(permMat, 2, quantile, probs = c(0.63, 0.9, 0.95, 0.99))
cat("Loading Physical Map...\n")
pmap <- readRDS(list.files(path = "../test/", pattern = "map", full.names = T))


#Result File Generation + Permutation Thresholding----------------
cat("Loading Genome Scan Outfile...\n")
scanOut <- readRDS("../processed/testOut.rds")
#IMPORTANT: align the order of the permThresh columns with the scanOut columns
permThresh <- permThresh[,match(colnames(scanOut), colnames(permThresh))]
stopifnot(colnames(permThresh) == colnames(scanOut))

cat("Writing out resfiles...\n")
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

#Visualization-----------------------------------------------------
#Analyze the 63rd (associative) quantile peak file 
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

#For this type of plot, x-axis never changes, but y-axis needs around 67 pixels per row to look good
estHeight <- length(unique(peaks_noX$lodcolumn)) * 67
estWidth <- estHeight * 1.5
png(paste0("../output/plots/lod/",prefix,"_peakSummary",".png"),
    res = 300,
    height = estHeight,
    width =  estWidth)
par(mar = c(4,15,4,2))
plot_peaks(peaks_noX, 
           map = pmap, 
           col = c("dodgerblue3"), 
           lwd = 3,
           cex.lab = 0.5,
           tick.height = 0.8,
           gap = 0, 
           main = paste0("Global Peak Summary - ",prefix),
           alt = "white")
box()
dev.off()

#Gene Query-------------------------------------------------------
#Check if "mouse_genes.sqlite" in the test folder, if not, download it
#wget is twice as fast when called from .sh compared to Rscript
system("chmod 755 getMouseGenes.sh")
system("./getMouseGenes.sh")

#MGI Database lookup - save RDSes of all genes within the CI of all peaks
#Submit peaks with CI - trim to the desired top x candidates
#Open a connection to the SQLdb
con <- dbConnect(SQLite(), "../test/mouse_genes.sqlite")
genes <- tbl(con, "genes")
stopifnot(nrow(peaks_noX) >= 10)
inPeaks <- top_n(peaks_noX, 10, lod)
for(i in 1:nrow(inPeaks)){
  tmp <- inPeaks[i,]
  tmp_chr <- as.character(tmp$chr)
  tmp_start <- tmp$ci_lo
  tmp_stop <- tmp$ci_hi
  desig <- paste0("peak",i,"-",tmp$lodcolumn,"-",
                  "chr",tmp$chr,
                  "-",floor(tmp$ci_lo),
                  "-",ceiling(tmp$ci_hi))
  if(tmp$pos < tmp_start | tmp$pos > tmp_stop){
    stop("Whoa there, marker isn't within CI!")
  }
  lookUp <- genes %>%  
    filter(chr == tmp_chr &
             type == "gene" &
             source == "MGI" &  
             start > tmp_start*10^6 &
             stop < tmp_stop*10^6) %>% #Get your rows
    dplyr::select(-ID, 
                  -score, 
                  -phase, 
                  -Parent, 
                  -Dbxref, 
                  -gene_id) %>% #Get your columns
    collect()
  
  lookUp <- lookUp[!grepl("^Gm",lookUp$Name),]
  lookUp <- lookUp[!grepl("riken",tolower(lookUp$description)),]
  if(nrow(lookUp) != 0){
    saveRDS(lookUp, 
            file =paste0("../output/data/peak-genes/",
                         desig,".rds"))
  }
}
#Close database connection
dbDisconnect(con)


#EnrichR Query-------------------------------------------------------
dbs <- as.character(listEnrichrDbs()[["libraryName"]])
dbNonGrata <- c("GeneSigDB",
                "GTEx_Tissue_Sample_Gene_Expression_Profiles_down",
                "GTEx_Tissue_Sample_Gene_Expression_Profiles_up",  
                "MSigDB_Computational",
                "NIH_Funded_PIs_2017_AutoRIF_ARCHS4_Predictions",
                "NIH_Funded_PIs_2017_GeneRIF_ARCHS4_Predictions",
                "DisGeNET",
                "SubCell_BarCode",
                "Chromosome_Location_hg19",
                "DSigDB",
                "Data_Acquisition_Method_Most_Popular_Genes",
                "Allen_Brain_Atlas_up",
                "Old_CMAP_up",
                "Old_CMAP_down"
)
dbs <- dbs[!dbs %in% dbNonGrata] #errors with dbGaP and 
#Loop through each file in peakGenes, query enrichr
peakCount <- length(list.files("../output/data/peak-genes/"))
peakFiles <- list.files("../output/data/peak-genes/", 
                        full.names = TRUE)
cat("Establishing connection...\n")
cat("Querying",peakCount,"QTL...\n")
pb <- txtProgressBar(min = 0, 
                     max = peakCount, 
                     style = 3)
for(i in seq_along(peakFiles)){
  tmp <- readRDS(peakFiles[i])
  lab <- paste0(gsub(".rds","",
                     basename(peakFiles[i])),"_enrich.rds")
  genes <- tmp$Name
  enriched <- enrichrMod(genes, dbs, quiet = TRUE)
  if(!is.null(enriched)){
    saveRDS(enriched, file = paste0("../output/data/enrichr-results/",lab))
  }
  setTxtProgressBar(pb, i)
}
close(pb)



