library(rgbif)
library(httr2)

# retrieve last used doi
log <- read.csv("data_update/update.log")
log <- log[!is.na(log$doi),]
last_doi <- log[nrow(log),"doi"]

# request download of GBIF dataset by last used doi
req <- request(paste0("https://doi.org/", last_doi))
resp <- req_perform(req)
uuid <- gsub("https://www.gbif.org/occurrence/download/", "", resp$url)

d <- occ_download_get(uuid)
last_data <- occ_download_import(d)
unlink(d)

# check for new records
check <- occ_search(taxonKey = 1229)

check <- check$data
check_ids <- check[check$institutionCode != "iNaturalist",]$gbifID
check_ids <- as.numeric(na.omit(check_ids))

# return ids from check_ids that are not in last_data
new_ids <- check_ids[!check_ids %in% last_data$gbifID]

# download dataset if new records are found, update log file
if(length(new_ids) == 0) {
    stop("No new r ecords")
} else {
    print(paste("New records found: ", length(new_ids)))

    gbif_reuqest <- occ_download(pred("taxonKey",1229),
                              pred_not(pred("institutionCode","iNaturalist")))
    still_running <- TRUE
    while (still_running) {
        meta <- occ_download_meta(gbif_reuqest)
        status <- meta$status
        still_running <- status %in% c("PREPARING", "RUNNING")
        print(paste("Status: ", status))
        Sys.sleep(5)
    }

    gbif_reuqest

    d <- occ_download_get(gbif_reuqest[[1]])
    new_data <- occ_download_import(d)

    write.csv(new_data[new_data$gbifID %in% new_ids,],paste0("data_update/",gbif_reuqest[[1]],"_gbif.csv"))

    # update log file with actual date and source
    current_date <- Sys.Date()
    source <- "GBIF"
    doi <- attr(gbif_request,"doi")

    log_entry <- paste(current_date, source, doi, sep = ",")

    write(log_entry, "data_update/update.log", append = TRUE)
}

capture.output(devtools::session_info(),file="session_info/gbif_session.txt")