rm(list=ls())

require(RWeka)

# if (require('RWeka')) {
# 	# WPM("install-package", "XMeans")
# }

library(mclust)
library(fpc)

table <- read.csv('/251/binning/int24.csv', header=T, sep=";", stringsAsFactors=F );

nrow <- length(unlist(strsplit(table$fph[1], ",")))
apfunc <- function(x) {
	cc <- as.numeric( unlist(strsplit(x, ",")) )
	return(cc)
}

fph <- t(matrix(apply(  table[4], 1, apfunc ), nrow=nrow ))
ppf <- t(matrix(apply(  table[5], 1, apfunc ), nrow=nrow ))
bpp <- t(matrix(apply(  table[6], 1, apfunc ), nrow=nrow ))
bps <- t(matrix(apply(  table[7], 1, apfunc ), nrow=nrow ))

df <- data.frame(fph=fph, ppf=ppf, bpp=bpp, bps=bps)

print("Running XMeans algorithm...")
xmeans_clust <- XMeans(df, c("-L", 10, "-H", 100, "-use-kdtree", "-K", "weka.core.neighboursearch.KDTree -P"))
xmeans_summary <- table(predict(xmeans_clust))

print("Writing result...")
xmeans_table <- data.frame(src=table$src_ip,dst=table$dst_ip,port=table$dst_port,fph=table$fph,ppf=table$ppf,bpp=table$bpp,bps=table$bps,cluster_id=xmeans_clust$class_ids)
write.table(xmeans_table, file = "/251/clustering/xmeans/int24.csv", sep = ";", col.names = NA, qmethod = "double")
###### write.table(xmeans_summary, file = "xmeans_summary.csv", sep = ";", col.names = NA, qmethod = "double")
rm(xmeans_clust, xmeans_summary, xmeans_table)


print("Running DBSCAN algorithm...")
df <- data.frame(fph=fph, ppf=ppf, bpp=bpp, bps=bps)
dbsc_df <- as.matrix(df)
dbscan_clust <- dbscan(dbsc_df, 1.5, MinPts=4, seed=F)

print("Writing result...")
dbscan_table <- data.frame(src=table$src_ip,dst=table$dst_ip,port=table$dst_port,fph=table$fph,ppf=table$ppf,bpp=table$bpp,bps=table$bps,cluster_id=dbscan_clust$cluster)
write.table(dbscan_table, file = "/251/clustering/dbscan/int24.csv", sep = ";", col.names = NA, qmethod = "double")
rm(dbsc_df, dbscan_clust, dbscan_table)


print("Running EM algorithm...")
em_df <- as.matrix(df)
em_clust <- Mclust(em_df)
em_summary <- summary(em_clust);

print("Writing result...")
em_table <- data.frame(src=table$src_ip,dst=table$dst_ip,port=table$dst_port,fph=table$fph,ppf=table$ppf,bpp=table$bpp,bps=table$bps,cluster_id=em_clust$classification)
write.table(em_table, file = "/251/clustering/em/int24.csv", sep = ";", col.names = NA, qmethod = "double")
###### write.table(em_summary, file = "em_summary.txt", sep = ";", col.names = NA, qmethod = "double")
rm(em_df, em_clust, em_summary)
