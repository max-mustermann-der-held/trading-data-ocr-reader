SHELL:=/usr/bin/env bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Makefile
# NOTE: Do not change the contents of this file!
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

################################
# VARIABLES
################################

R_COMMAND:=RScript --no-environ
URL_CRAN:=https://cran.ma.imperial.ac.uk

################################
# Macros
################################

define install_r_package_version
	${R_COMMAND} -e  " \
		options(warn = -1); \
		check_installed <- FALSE; \
		if (suppressMessages(require('$(1)'))) if (compareVersion(as.character(packageVersion('$(1)')), '$(2)') == 0) check_installed <- TRUE; \
		if (!check_installed) install.packages('$(1)', repos='${URL_CRAN}'); \
		if (!suppressMessages(require('$(1)'))) stop(1); \
		version <- as.character(packageVersion('$(1)')); \
		if (compareVersion(version, '$(2)') != 0) stop('\x1b[93;1m$(1)==$(2)\x1b[0m could not be installed.'); \
		message(paste0('Module \x1b[93;1m$(1)==$(2)\x1b[0m installed with version \x1b[93;1m',version,'\x1b[0m.')); \
	"
endef

define install_r_package_min_version
	${R_COMMAND} -e " \
		options(warn = -1); \
		check_installed <- FALSE; \
		if (suppressMessages(require('$(1)'))) if (compareVersion(as.character(packageVersion('$(1)')), '$(2)') >= 0) check_installed <- TRUE; \
		if (!check_installed) install.packages('$(1)', repos='${URL_CRAN}'); \
		if (!suppressMessages(require('$(1)'))) stop(1); \
		version <- as.character(packageVersion('$(1)')); \
		if (compareVersion(version, '$(2)') < 0) stop('\x1b[93;1m$(1)>=$(2)\x1b[0m could not be installed.'); \
		message(paste0('Module \x1b[93;1m$(1)>=$(2)\x1b[0m installed with version \x1b[93;1m',version,'\x1b[0m.')); \
	"
endef

define delete_if_file_exists
	@if [ -f "$(1)" ]; then rm "$(1)"; fi
endef

define delete_if_folder_exists
	@if [ -d "$(1)" ]; then rm -rf "$(1)"; fi
endef

define clean_all_files
	@find . -type f -name "$(1)" -exec basename {} \;
	@find . -type f -name "$(1)" -exec rm {} \; 2> /dev/null
endef

define clean_all_folders
	@find . -type d -name "$(1)" -exec basename {} \;
	@find . -type d -name "$(1)" -exec rm -rf {} \; 2> /dev/null
endef

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# TARGETS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

################################
# BASIC TARGETS: setup, run
################################
setup:
	@$(call install_r_package_min_version,DBI,1.1.2)
	@$(call install_r_package_min_version,devtools,2.4.3)
	@$(call install_r_package_min_version,dotenv,1.0.3)
	@$(call install_r_package_min_version,lubridate,1.8.0)
	@$(call install_r_package_min_version,magick,2.7.3)
	@$(call install_r_package_min_version,modules,0.10.0)
	@$(call install_r_package_min_version,purrr,0.3.4)
	@$(call install_r_package_min_version,R.oo,1.24.0)
	@$(call install_r_package_min_version,RSQLite,2.2.12)
	@$(call install_r_package_min_version,stringr,1.4.0)
	@$(call install_r_package_min_version,tesseract,5.0.0)
run:
	${R_COMMAND} main.r
################################
# MISC TARGETS: update R
################################
# Requires admin pw:
update:
	${R_COMMAND} -e "devtools::install_github('andreacirilloac/updateR', force = TRUE)"
	@# The following command requires admin pw:
	${R_COMMAND} -e "updateR::updateR()"
