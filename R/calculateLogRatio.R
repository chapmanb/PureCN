calculateLogRatio <- structure(
function(# Calculate coverage log-ratio of tumor vs. normal
### This function is automatically called by \code{\link{runAbsoluteCN}} 
### when normal and tumor coverage are provided (and not a segmentation file 
### or target-level log-ratios). This function is therefore 
### normally not called by the user.
normal, 
### Normal coverage read in by the 
### \code{\link{readCoverageGatk}} function.
tumor, 
### Tumor coverage read in by the 
### \code{\link{readCoverageGatk}} function.
verbose=TRUE
### Verbose output.
) {
    # make sure that normal and tumor align
    if (!identical(as.character(normal[, 1]), as.character(tumor[, 1]))) {
        .stopUserError("Interval files in normal and tumor different.")
    }
    if (verbose) {
        message("Average coverage: ", 
            round(mean(tumor$average.coverage, na.rm=TRUE), digits=0), 
            "X (tumor), ",
            round(mean(normal$average.coverage, na.rm=TRUE), digits=0),
            "X (normal).")
    }    
    total.cov.normal <- sum(as.numeric(normal$coverage), na.rm = TRUE)
    total.cov.tumor <- sum(as.numeric(tumor$coverage), na.rm = TRUE)

    log.ratio <- log2(tumor$average.coverage/normal$average.coverage) + 
                 log2(total.cov.normal/total.cov.tumor)

    mean.log.ratio <- mean(subset(log.ratio, !is.infinite(log.ratio)), 
        na.rm = TRUE)
    # calibrate
    log.ratio <- log.ratio - mean.log.ratio
    log.ratio
### \code{numeric(nrow(tumor))}, tumor vs. normal copy number
### log-ratios for all targets.    
}, ex=function() {
normal.coverage.file <- system.file("extdata", "example_normal.txt", 
    package="PureCN")
tumor.coverage.file <- system.file("extdata", "example_tumor.txt", 
    package="PureCN")
normal <- readCoverageGatk(normal.coverage.file)
tumor <- readCoverageGatk(tumor.coverage.file)
log.ratio <- calculateLogRatio(normal, tumor, verbose=FALSE)
})    
