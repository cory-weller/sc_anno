#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

# test if there is at least one argument: if not, return an error
if (length(args)==0) {
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

# MAx number of PCs to explore
MAX_PCS <- 60

# load libraries
lapply(c("dplyr","Seurat","HGNChelper", "openxlsx", "ggplot2"), library, character.only = T)
# test with SH-06-05
# params <- list()
# params$project_name <- 'SH-06-05'
project_name <- args[1]
batch <- args[2]
print(paste0("Sample name: ", project_name))
base_dir <- paste0('/data/CARD_singlecell/Brain_atlas/NABEC_multiome/', batch, '/RNAonly/',project_name, '/outs/filtered_feature_bc_matrix/')

# make directory in figures
batch_folder <- paste0('figures/', batch)
dir.create(batch_folder)
figure_folder <- paste0('figures/', batch, '/', project_name)
dir.create(figure_folder)

# Initialize the Seurat object with the raw (non-normalized data).
data <- Read10X(data.dir = base_dir)
# Initialize the Seurat object with the raw (non-normalized data).
#data <- CreateSeuratObject(counts = data$`Gene Expression`, project = project_name, min.cells = 3, min.features = 200)
data <- CreateSeuratObject(counts = data, project = project_name, min.cells = 3, min.features = 200)
data[["percent.mt"]] <- PercentageFeatureSet(data, pattern = "^MT-")
data <- NormalizeData(data, normalization.method = "LogNormalize", scale.factor = 10000)
data <- FindVariableFeatures(data, selection.method = "vst", nfeatures = 2000)

# scale and run PCA
data <- ScaleData(data, features = rownames(data))
data <- RunPCA(data, npcs = MAX_PCS, features = VariableFeatures(object = data))

# Check number of PC components (we selected 10 PCs for downstream analysis, based on Elbow plot)
pdf(paste0(figure_folder,'/', project_name, '_elbow', '.pdf'))
ElbowPlot(data, ndims=MAX_PCS,reduction='pca')
dev.off()

data <- JackStraw(data, dims=MAX_PCS, num.replicate=80, maxit=900)
data <- ScoreJackStraw(data, dims=1:MAX_PCS)
upper_b <- min(which(JS(data[['pca']], 'overall')[,2] >= 0.05))
print(paste0("total number of PCs used. 
            Make sense? : ", upper_b))
if (upper_b == 'Inf'){
    upper_b <- MAX_PCS
}
pdf(paste0(figure_folder,'/', project_name, '_jackstraw', '.pdf'))
JackStrawPlot(data,dims = 1:upper_b)
dev.off()


# cluster and visualize
data <- FindNeighbors(data, dims = 1:upper_b)
data <- FindClusters(data, resolution = 0.2)
data <- RunUMAP(data, dims = 1:upper_b)

pdf(paste0(figure_folder,'/', project_name, '_cluster', '.pdf'))
DimPlot(data, reduction = "umap")
dev.off()

# load gene set preparation function
source("https://raw.githubusercontent.com/IanevskiAleksandr/sc-type/master/R/gene_sets_prepare.R")
# load cell type annotation function
source("https://raw.githubusercontent.com/IanevskiAleksandr/sc-type/master/R/sctype_score_.R")

# DB file
#db_ = "https://raw.githubusercontent.com/IanevskiAleksandr/sc-type/master/ScTypeDB_full.xlsx";
db_ = "data/ScTypeDB_full.xlsx"
tissue = "Brain" # e.g. Immune system,Pancreas,Liver,Eye,Kidney,Brain,Lung,Adrenal,Heart,Intestine,Muscle,Placenta,Spleen,Stomach,Thymus 

# prepare gene sets
gs_list = gene_sets_prepare(db_, tissue)


# Celltype
es.max = sctype_score(scRNAseqData = data[["RNA"]]@scale.data, scaled = TRUE, 
                      gs = gs_list$gs_positive, gs2 = gs_list$gs_negative) 

# NOTE: scRNAseqData parameter should correspond to your input scRNA-seq matrix. 
# In case Seurat is used, it is either data[["RNA"]]@scale.data (default), data[["SCT"]]@scale.data, in case sctransform is used for normalization,
# or data[["integrated"]]@scale.data, in case a joint analysis of multiple single-cell datasets is performed.

# merge by cluster
cL_results = do.call("rbind", lapply(unique(data@meta.data$seurat_clusters), function(cl){
    es.max.cl = sort(rowSums(es.max[ ,rownames(data@meta.data[data@meta.data$seurat_clusters==cl, ])]), decreasing = !0)
    head(data.frame(cluster = cl, type = names(es.max.cl), scores = es.max.cl, ncells = sum(data@meta.data$seurat_clusters==cl)), 10)
}))

sctype_scores = cL_results %>% group_by(cluster) %>% top_n(n = 1, wt = scores)
markers <- FindAllMarkers(data, densify=TRUE, min.pct=0.18)
marker_scores <- merge(sctype_scores, markers, on="cluster")
marker_scores <- marker_scores[c('cluster','type','ncells','p_val','avg_log2FC','pct.1','pct.2','p_val_adj','gene')]
# sort by p_Adj_values
markers <- arrange(marker_scores, cluster, p_val_adj)
write.csv(markers, file=paste0(figure_folder, '/', project_name, '_markers', '.csv'), row.names=FALSE)

# set low-confident (low ScType score) clusters to "unknown"
sctype_scores$type[as.numeric(as.character(sctype_scores$scores)) < sctype_scores$ncells/4] = "Unknown"
print(sctype_scores[,1:3])

data@meta.data$customclassif = ""
for(j in unique(sctype_scores$cluster)){
  cl_type = sctype_scores[sctype_scores$cluster==j,]; 
  data@meta.data$customclassif[data@meta.data$seurat_clusters == j] = as.character(cl_type$type[1])
}
g3 <- DimPlot(data, reduction = "umap", label = TRUE, repel = TRUE, group.by = 'customclassif')
ggsave(g3, file=paste0(figure_folder,'/', project_name, '_umap', '.pdf'), width=25, height=18, units='cm')

# output the number of each cell type
cluster_counts <- data@meta.data %>%
    count(customclassif)
write.csv(cluster_counts, file=paste0(figure_folder, '/', project_name, '_type_counts', '.csv'), row.names=FALSE)

# load libraries
#
#
lapply(c("ggraph","igraph","tidyverse", "data.tree", "ggthemes"), library, character.only = T)

# prepare edges
cL_results=cL_results[order(cL_results$cluster),]
edges = cL_results
edges$type = paste0(edges$type,"_",edges$cluster)
edges$cluster = paste0("cluster ", edges$cluster)
edges = edges[,c("cluster", "type")]
colnames(edges) = c("from", "to")
rownames(edges) <- NULL

# prepare nodes
nodes_lvl1 = sctype_scores[,c("cluster", "ncells")]
nodes_lvl1$cluster = paste0("cluster ", nodes_lvl1$cluster)
nodes_lvl1$Colour = "#f1f1ef"
nodes_lvl1$ord = 1
nodes_lvl1$realname = nodes_lvl1$cluster
nodes_lvl1 = as.data.frame(nodes_lvl1)
nodes_lvl2 = c()

ccolss= c("#5f75ae","#92bbb8","#64a841","#e5486e","#de8e06","#eccf5a",
            "#b5aa0f","#e4b680","#7ba39d","#b15928","#ffff99", 
            "#6a3d9a","#cab2d6","#ff7f00","#fdbf6f","#e31a1c",
            "#fb9a99","#33a02c","#b2df8a","#1f78b4","#a6cee3")

for (i in 1:length(unique(cL_results$cluster))){
  dt_tmp = cL_results[cL_results$cluster == unique(cL_results$cluster)[i], ]
  nodes_lvl2 = rbind(nodes_lvl2, 
  data.frame(cluster = paste0(dt_tmp$type,"_",dt_tmp$cluster), ncells = dt_tmp$scores, Colour = ccolss[i], ord = 2, realname = dt_tmp$type))
}

nodes = rbind(nodes_lvl1, nodes_lvl2)

nodes$ncells[nodes$ncells<1] = 1

files_db = openxlsx::read.xlsx(db_)[,c("cellName","cellName")]
colnames(files_db) <- c('cellName','shortName')
files_db = unique(files_db)

nodes = merge(nodes, files_db, all.x = T, all.y = F, by.x = "realname", by.y = "cellName", sort = F)
nodes$shortName[is.na(nodes$shortName)] = nodes$realname[is.na(nodes$shortName)]
nodes = nodes[,c("cluster", "ncells", "Colour", "ord", "shortName", "realname")]

mygraph <- graph_from_data_frame(edges, vertices=nodes)

# Make the graph
gggr<- ggraph(mygraph, layout = 'circlepack', weight=I(ncells)) + 
  geom_node_circle(aes(filter=ord==1,fill=I("#F5F5F5"), colour=I("#D3D3D3")), alpha=0.9) +
  geom_node_circle(aes(filter=ord==2,fill=I(Colour), colour=I("#D3D3D3")), alpha=0.9) +
  theme_few() +
  geom_node_text(aes(filter=ord==2, label=shortName, colour=I("#ffffff"), fill="white", repel = !1, parse = T, size = I(log(ncells,25)*1.5))) +
  geom_node_label(aes(filter=ord==1,  label=shortName, colour=I("#000000"), size = I(3), fill="white", parse = T), repel = !0, segment.linetype="dotted") +
  theme(axis.text.x=element_blank(),
      axis.ticks.x=element_blank(),
      axis.text.y=element_blank(),
      axis.ticks.y=element_blank(),
      axis.title.x=element_blank(),
      axis.title.y=element_blank(),
      plot.background = element_blank())

ggsave(gggr, file=paste0(figure_folder, '/', project_name, '-bubble.png'), width=25, height=25, units='cm')

library(cowplot)
g4 <-  plot_grid(g3, gggr, labels = c('A', 'B'), label_size = 12, rel_widths=c(0.45, 0.55))
ggsave(g4, file=paste0(figure_folder, '/', project_name, '-clusters_combined.png'), width=45, height=25, units='cm')


if(FALSE){
  source("https://raw.githubusercontent.com/IanevskiAleksandr/sc-type/master/R/auto_detect_tissue_type.R")
  db_ = "data/ScTypeDB_full.xlsx";
  tissue_guess = auto_detect_tissue_type(path_to_db_file = db_, seuratObject = data, scaled = TRUE, assay = "RNA")
}

quit()