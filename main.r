#!/usr/bin/env Rscript

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IMPORTS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

options(warn = -1);

suppressMessages(library('dplyr'));
suppressMessages(library('magick'));
suppressMessages(library('modules'));
suppressMessages(library('purrr'));
suppressMessages(library('R.oo'));
suppressMessages(library('readr'));
suppressMessages(library('stringr'));
suppressMessages(library('tesseract'));
suppressMessages(library('tibble'));

module_utils  <- modules::use('src/core/utils.r');
module_secret <- modules::use('src/setup/secret.r');
module_config <- modules::use('src/setup/config.r');
module_db     <- modules::use('src/database/db.r');

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CONSTANTS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FILENAME_ENV <- '.env';
FILENAME_CONFIG <- 'config.yml';

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MAIN METHOD
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

main <- function() {
    # immediately capture the current moment:
    date_now <- Sys.Date();

    # extract private + public settings:
    secrets <- step_get_secrets();
    config  <- step_get_config(date=date_now);

    # clear temp folder:
    remove_temp_folder(config);
    # perform main steps:
    fp   <- step_get_inputs(config=config);
    data <- step_extract_data(config=config);
    step_update_data(config=config, data=data, fp=fp);
    # clear temp folder again:
    remove_temp_folder(config);

    # Perform private actions:
    step_notify_user(secrets=secrets, config=config);

    return (0);
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SECONDARY METHODS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Extracts private settings from .env
step_get_secrets <- function() {
    secrets <- as.list(module_secret$get_secret(FILENAME_ENV, c('name', 'email')));
    return (secrets);
}

# Extracts settings from config.yml
step_get_config <- function(date) {
    module_utils$return.multiple(list(
        info     = 'info',
        settings = 'settings'
    ), module_config$get_config)(FILENAME_CONFIG);

    settings$path <- base::tempfile(
        pattern = 'scrape_',
        tmpdir  = settings$paths$temp,
        fileext = '.pdf'
    );
    settings$paths$csv <- file.path(settings$paths$data, paste0('data_', date, '.csv'));
    settings$date <- date;

    return (settings);
}

step_get_inputs <- function(config) {
    url <- config$url;
    path <- config$path;

    module_utils$create_folder(config$paths$temp);

    message(paste0('Downloading from url to ', path, '.'));
    fp <- download.file(url,  path, mode = 'wb');
    return (fp);
}

# NOTE: Table in the PDF appears as an image. Thus ocr required to extract data.
step_extract_data <- function(config) {
    # date_now <- lubridate::my(config$date); # FIXME: this does not work!
    date_now <- config$date;
    geometry <- config$ocr$geometry;
    dx <- geometry$dx;
    w <- geometry$width;
    h <- geometry$width;
    x0 <- geometry$x_off;
    y0 <- geometry$y_off;

    # extract image
    image <- image_read_pdf(config$path) |>
        magick::image_crop(
            geometry = geometry_area(
                width  = w * dx,
                height = h * dx,
                x_off  = x0 * dx,
                y_off  = y0 * dx
            )
        ) |>
        magick::image_quantize(
            colorspace = config$ocr$colour_space
        ) |>
        magick::image_transparent(
            color = config$ocr$transparency$colour,
            fuzz = config$ocr$transparency$fuzz
        );

    # Extract text
    text <- image |>
        tesseract::ocr() |>
        stringr::str_split(pattern = '\n') |>
        unlist();
    text <- text[text != ''];
    text_parts <- map(text, ~(stringr::str_split(.x, '\\s+')[[1]]));
    text_parts <- pad_data(text_parts);

    # Format text as table.
    N <- length(text_parts[[1]]);
    data <- tibble::tibble(
        scrape_date = rep(date_now, N),
        date        = text_parts[[1]],
        cash_rate   = text_parts[[2]]
    );
    # force this regardless:
    data <- data |> mutate(cash_rate = gsub('^0(\\d+)$', '0.\\1', cash_rate));
    # for other numbers force this too, if set in config:
    if (config$ocr$force_decimal) {
        data <- data |> mutate(cash_rate = gsub('^\\d(\\d+)$', '0.\\1', cash_rate));
    }
    data <- data |> mutate(cash_rate = as.numeric(cash_rate));
}

step_update_data <- function(config, data, fp) {
    path_data <- config$paths$data
    path_db   <- config$paths$db
    db_name <- config$database$name;
    schema  <- config$database$schema;
    columns <- config$database$columns;

    # store extracted data to csv:
    module_utils$create_folder(path_data);
    readr::write_csv(data, config$paths$csv);

    # add extracted date to db:
    cursor <- module_db$db_create_if_not_exists(
        path   = path_db,
        name   = db_name,
        schema = schema
    );
    module_db$db_add_lines(cursor = cursor, data = data, name = db_name, schema = schema);
    module_db$db_disconnect(cursor);
}

## TODO: write method!
step_notify_user <- function(secrets, config) {
    message(sprintf(
        'Sending notification about extracted data to \x1b[1m%s <%s>\x1b[0m.',
        secrets$name,
        secrets$email
    ));
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUXILIARY METHODS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

remove_temp_folder <- function(config) {
    module_utils$remove_folder(config$paths$temp);
}

pad_data <- function(data, default = NA) {
    N <- 0;
    # compute maximal length of columns:
    for (col in names(data)) N <- max(N, length(data[[col]]));
    # pad shorter columns by default value:
    for (col in names(data)) {
        n <- length(data[[col]]);
        if (n < N) data[[col]] <- c(data[[col]], rep(default, N-n));
    }
    return (data);
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EXECUTION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

main();
