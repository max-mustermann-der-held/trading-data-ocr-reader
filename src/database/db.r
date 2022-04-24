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

db_add_lines <- function(cursor, data, name, schema) {
    n <- base::nrow(data);
    for (k in c(1:n)) {
        row <- as.list(data[k, ]);
        row <- prepare_row_for_insert(row, schema);
        # Wait until query completed:
        result <- db_add_line(cursor, row, name);
        while(!DBI::dbHasCompleted(result)) Sys.sleep(0.1);
    }
}

db_add_line <- function(cursor, row, name) {
    keys   <- paste(names(row), collapse=', ');
    values <- paste(as.vector(unlist(row)), collapse=', ');
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

prepare_row_for_insert <- function(row, schema) {
    parts <- list();
    for (col in names(schema)) {
        value <- row[[col]];
        attributes <- schema[[col]];
        if (!attributes$insert) next;
        type <- attributes$type;
        # Place non-numerical values in quotations:
        if (type %in% c('TEXT', 'DATE')) {
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
