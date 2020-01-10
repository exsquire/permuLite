if(!file.exists("../test/mouse_genes.sqlite")){
   cat("Mouse gene database file not found in /test/.\n")
   cat("Downloading...\n")
   system("wget -O ../test/mouse_genes.sqlite  https://ndownloader.figshare.com/files/17609261")
}else{
   cat("mouse_genes.sqlite found.\n")
}
