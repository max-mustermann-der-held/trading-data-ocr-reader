#!/usr/bin/env Rscript

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IMPORTS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

suppressMessages(library('DBI'));
suppressMessages(library('RSQLite'));

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# METHODS:
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

db_create_if_not_exists <- function(path, name, schema) {
    schema <- schema_as_string(schema);
    cursor <- DBI::dbConnect(
        RSQLite::SQLite(),
        dbname = path,
    );
    query <- sprintf('CREATE TABLE IF NOT EXISTS %s (%s)', name, schema);
    result <- DBI::dbSendQuery(cursor, query);
    return (cursor);
}

db_disconnect <- function(cursor) {
    DBI::dbDisconnect(cursor);
}

db_add_lines <- function(cursor, data, name, schema, overwrite = FALSE) {
    n <- base::nrow(data);
    for (k in c(1:n)) {
        row <- as.list(data[k, ]);
        # First remove all repeat occurrence:
        if (overwrite) {
            parts <- check_unique(row, schema);
            result <- db_remove_entry(cursor, parts=parts, name=name);
            while(!DBI::dbHasCompleted(result)) Sys.sleep(0.1);
        }
        # Now insert new data:
        parts <- prepare_row_for_insert(row, schema);
        result <- db_add_line(cursor, parts=parts, name=name);
        # Wait until query completed:
        while(!DBI::dbHasCompleted(result)) Sys.sleep(0.1);
    }
}

db_remove_entry <- function(cursor, parts, name) {
    query <- sprintf('DELETE FROM %s WHERE %s', name, paste0(parts, collapse=' AND '));
    result <- DBI::dbSendQuery(cursor, query);
    return(result);
}

db_add_line <- function(cursor, parts, name) {
    keys   <- paste(names(parts), collapse=', ');
    values <- paste(as.vector(unlist(parts)), collapse=', ');
    query <- sprintf(
        'INSERT INTO %s (%s) VALUES (%s)',
        name,
        keys,
        values
    );
    result <- DBI::dbSendQuery(cursor, query);
    return(result)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUXILIARY METHODS:
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

check_unique <- function(row, schema) {
    parts <- c();
    for (col in names(schema)) {
        value <- row[[col]];
        attributes <- schema[[col]];
        if (!attributes$insert) next;
        if (!attributes$unique) next;
        # Place non-numerical values in quotations:
        type <- attributes$type;
        if (type %in% c('TEXT', 'DATE', 'DATETIME')) {
            value <- sprintf('"%s"', value);
        }
        parts <- c(sprintf('%s = %s', col, value));
    }
    return (parts);
}

prepare_row_for_insert <- function(row, schema) {
    parts <- list();
    for (col in names(schema)) {
        value <- row[[col]];
        attributes <- schema[[col]];
        if (!attributes$insert) next;
        # Place non-numerical values in quotations:
        type <- attributes$type;
        if (type %in% c('TEXT', 'DATE', 'DATETIME')) {
            value <- sprintf('"%s"', value);
        }
        parts[[col]] <- value;
    }
    return (parts);
}

schema_as_string <- function(schema) {
    parts <- c();
    for (col in names(schema)) {
        attributes <- schema[[col]];
        type <- attributes$type;
        if ('define_type' %in% names(attributes)) type <- attributes$define_type;
        parts <- c(parts, sprintf('%s %s', col, type));
    }
    schema_as_text <- paste(parts, collapse=', ');
    return (schema_as_text);
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EXPORTS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

export('db_add_line');
export('db_add_lines');
export('db_create_if_not_exists');
export('db_disconnect');
