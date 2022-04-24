#!/usr/bin/env Rscript

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IMPORTS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

suppressMessages(import('R.oo'));

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# METHODS:
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

remove_folder <- function(path) {
    if (dir.exists(path)) unlink(path, recursive = TRUE);
    if (dir.exists(path)) R.oo::throw(paste0('Could not remove folder ',path,'!'));
}

create_folder <- function(path) {
    if (!dir.exists(path)) dir.create(path);
    if (!dir.exists(path)) R.oo::throw(paste0('Could not create folder ',path,'!'));
}

return.multiple <- function(map, f) {
    FUN <- f;
    return (function(...) {
        env <- parent.frame();
        args <- as.list(sys.call())[-1L];
        len <- length(args);
        if(len > 1L) {
            last <- args[[len]];
            if(missing(last)) args <- args[-len];
        }
        obj <- do.call(FUN, args, envir=env);
        if(!is.list(map) && !is.vector(map)) map <- list();
        for(key in names(map)) {
            val <- NULL;
            if(key %in% names(map)) val <- obj[[map[[key]]]];
            assign(key, val, env);
        }
        invisible(NULL);
    });
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EXPORTS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

export('create_folder');
export('remove_folder');
export('return.multiple');
