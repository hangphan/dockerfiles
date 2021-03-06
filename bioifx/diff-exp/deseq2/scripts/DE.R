#!/usr/bin/env Rscript
# vim: syntax=r tabstop=2 expandtab

#----------------------------------
# @author: Mahesh Vangala
# @email: vangalamaheshh@gmail.com
# @date: Mar, 10, 2017
#-----------------------------------

#library("BiocParallel")
library("DESeq2")
library("ggplot2")
library("ggrepel")
library("dplyr")

#register(MulticoreParam(6))

args <- commandArgs(trailingOnly = TRUE)

meta <- read.csv(args[1], header = TRUE, row.names = 1, sep = ",")
counts <- read.csv(args[2], header = TRUE, row.names = 1, sep = ",")

meta <- meta[, grepl("comp_*", colnames(meta)), drop = FALSE]

for (comp in colnames(meta)) {
  print(paste("Processing", comp, sep = " "))
  ctrl <- rownames(meta[meta[, comp] == 1, comp, drop = FALSE])
  treat <- rownames(meta[meta[, comp] == 2, comp, drop = FALSE])
  count_data <- counts[,c(treat, ctrl)]
  condition <- c(rep("treat", length(treat)), rep("ctrl", length(ctrl)))
  col_data <- as.data.frame(cbind(colnames(count_data), condition))
  dds <- DESeqDataSetFromMatrix(countData = count_data, colData = col_data, design = ~ condition)
  dds <- dds[rowSums(counts(dds)) > 0, ]
  dds <- DESeq(dds, parallel = FALSE)
  res <- results(dds, parallel = FALSE)
  res <- res[order(as.numeric(res[,"padj"])), ]
  results <- cbind(GENE_ID = rownames(res), as.matrix(res))
  write.table(results, paste(comp, "/", comp, ".deseq2.csv", sep = ""), sep = ',', 
              col.names = TRUE, row.names = FALSE, quote = FALSE)
  res$Gene <- rownames(res)
  res <- na.omit(res)
  rownames(res) <- NULL
  res <- mutate(as.data.frame(res), sig = ifelse(res$padj < 0.05, 'FDR < 0.05', "Not Significant"))
  volcano_plot <- ggplot(res, aes(log2FoldChange, -log10(pvalue))) +
    geom_point(aes(col = sig)) +
    scale_color_manual(values = c("red", "black"))
  volcano_plot <- volcano_plot + geom_text_repel(data = res[1:min(20, length(res)), ], 
    aes(label = factor(Gene)), size = 3, fontface = "bold", box.padding = unit(0.5, "lines"), 
    point.padding = unit(1.6, "lines"), segment.color = "#555555", segment.size = 0.5, 
    arrow = arrow(length = unit(0.01, "npc")), force = 1, max.iter = 2000)
  ggsave(file = paste(comp, "/", comp, ".volcano.png", sep = ""), volcano_plot) 
}

