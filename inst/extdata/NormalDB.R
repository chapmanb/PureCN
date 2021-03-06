suppressPackageStartupMessages(library(optparse))
suppressPackageStartupMessages(library(futile.logger))

### Parsing command line ------------------------------------------------------

option_list <- list(
    make_option(c("--coveragefiles"), action="store", type="character", default=NULL,
        help="List of input coverage files (supported formats: PureCN, GATK and CNVkit)"),
    make_option(c("--normal_panel"), action = "store", type = "character", default = NULL,
        help = "Input: VCF containing calls from a panel of normals, for example generated by GATK CombineVariants."),
    make_option(c("--maxmeancoverage"), action="store", type="integer", default=NULL,
        help="Maximum coverage (downscale samples exceeding this cutoff) [default auto]"),
    make_option(c("--assay"), action="store", type="character", default="",
        help="Optional assay name used in output names [default %default]"),
    make_option(c("--genome"), action="store", type="character", default=NULL,
        help="Genome version, used in output names [default %default]"),
    make_option(c("--outdir"), action="store", type="character", default=NULL,
        help="Output directory to which results should be written"),
    make_option(c("-v", "--version"), action="store_true", default=FALSE, 
        help="Print PureCN version"),
    make_option(c("-f", "--force"), action="store_true", default=FALSE, 
        help="Overwrite existing files")
)

opt <- parse_args(OptionParser(option_list=option_list))

if (opt$version) {
    message(as.character(packageVersion("PureCN")))
    q(status=1)
}    

.checkFileList <- function(file) {
    files <- read.delim(file, as.is=TRUE, header=FALSE)[,1]
    numExists <- sum(file.exists(files), na.rm=TRUE)
    if (numExists < length(files)) { 
        stop("File not exists in file ", file)
    }
    files
}

outdir <- opt$outdir
if (is.null(outdir)) {
    stop("need --outdir")
}
outdir <- normalizePath(outdir, mustWork=TRUE)
assay <- opt$assay
genome <- opt$genome
if (is.null(genome)) stop("Need --genome")

.getFileName <- function(outdir, prefix, suffix, assay, genome) {
    if (nchar(assay)) assay <- paste0("_", assay)
    if (nchar(genome)) genome <- paste0("_", genome)
    file.path(outdir, paste0(prefix, assay, genome, suffix))
}

flog.info("Loading PureCN %s...", Biobase::package.version("PureCN"))
if (!is.null(opt$normal_panel)) {
    output.file <- .getFileName(outdir,"mapping_bias",".rds", assay, genome)
    if (file.exists(output.file) && !opt$force) {
        flog.info("%s already exists. Skipping... (--force will overwrite)",
            output.file)
    } else {
        suppressPackageStartupMessages(library(PureCN))
        flog.info("Creating mapping bias database.")
        bias <- calculateMappingBiasVcf(opt$normal_panel, genome = genome)
        saveRDS(bias, file = output.file)
    }
}
    
if (is.null(opt$coveragefiles)) {
    if (is.null(opt$normal_panel)) stop("need --coveragefiles.")
    flog.warn("No --coveragefiles provided. Cannot generate normal database.")
    q(status=1)
}

coverageFiles <- .checkFileList(opt$coveragefiles)

if (length(coverageFiles)) {
    output.file <- .getFileName(outdir,"normalDB",".rds", assay, genome)
    if (file.exists(output.file) && !opt$force) {
        flog.info("%s already exists. Skipping... (--force will overwrite)",
            output.file)
    } else {
        suppressPackageStartupMessages(library(PureCN))
        flog.info("Creating normalDB. Assuming coverage files are GC-normalized.")
        normalDB <- createNormalDatabase(coverageFiles, max.mean.coverage=opt$maxmeancoverage)
        saveRDS(normalDB, file = output.file)
        if (length(normalDB$low.coverage.targets) > 0) {
            output.low.coverage.file <- .getFileName(outdir,"low_coverage_targets",".bed", assay, genome)
            suppressPackageStartupMessages(library(rtracklayer))
            export(normalDB$low.coverage.targets, output.low.coverage.file)
        }
    }
}

if (length(coverageFiles) > 3) {
    interval.weight.file <- .getFileName(outdir,"interval_weights",".txt", assay, 
        genome)
    if (file.exists(interval.weight.file) && !opt$force) {
        flog.info("%s already exists. Skipping... (--force will overwrite)",
            interval.weight.file)
    } else {
        suppressPackageStartupMessages(library(PureCN))
        outpng.file <- sub("txt$", "png", interval.weight.file)
        flog.info("Creating target weights.")
        png(outpng.file, width = 800, height = 400)
        calculateIntervalWeights(normalDB$normal.coverage.files, 
            interval.weight.file, plot = TRUE)
        dev.off()
   }     
} else {
    flog.warn("Not enough coverage files for creating interval_weights.txt")
}

