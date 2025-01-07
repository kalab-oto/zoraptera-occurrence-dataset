library(rinat)

inat_zor <- get_inat_obs(taxon_id = 83200, maxresults = 10000)

inat_zor <- inat_zor[inat_zor$license %in% c("CC-BY", "CC-BY-NC", "CC0"),]

inat_zor <- inat_zor[,c("scientific_name", "latitude", "longitude", "url", "id", "observed_on", "public_positional_accuracy", "user_name","license")]

inat_zor$license <- gsub("-", "_", inat_zor$license)

# for each record check if defined user (4936724 is Petr Kocarek) identified it, if so, add the name of the identifier and the scientific name
inat_zor$rev_user <- NA
inat_zor$taxonRank <- NA
inat_zor$order <- "Zoraptera"
inat_zor$family <- NA
inat_zor$subfamily <- NA
inat_zor$genus <- NA
inat_zor$specificEpithet <- NA
inat_zor$locality <- NA

for (i in seq(nrow(inat_zor))) {
   
    id <- inat_zor$id[[i]]
    obs <- get_inat_obs_id(id)

    if (4936724 %in% obs$identifications$user_id){
        ident <- obs$identifications
        ident <- ident[obs$identifications$user_id == 4936724, ]
        id_rev <- ident[nrow(ident),]
        inat_zor$rev_user[i] <- id_rev$user$login
        inat_zor$scientific_name[i] <- id_rev$taxon$name
        inat_zor$taxonRank[i] <- id_rev$taxon$rank
        inat_zor$locality[i] <- obs$place_guess
        
    }
}

# rename columns to match the current dataset
names(inat_zor)[names(inat_zor) == "latitude"] <- "decimalLatitude"
names(inat_zor)[names(inat_zor) == "longitude"] <- "decimalLongitude"
names(inat_zor)[names(inat_zor) == "public_positional_accuracy"] <- "coordinateUncertaintyInMeters"
names(inat_zor)[names(inat_zor) == "user_name"] <- "recordedBy"
names(inat_zor)[names(inat_zor) == "rev_user"] <- "identifiedBy"
names(inat_zor)[names(inat_zor) == "scientific_name"] <- "scientificName"
names(inat_zor)[names(inat_zor) == "id"] <- "inatID"
names(inat_zor)[names(inat_zor) == "url"] <- "associatedReferences"
names(inat_zor)[names(inat_zor) == "observed_on"] <- "eventDate"

# split eventDate into seperate columns day, month and year
inat_zor$eventDate <- as.Date(inat_zor$eventDate)
inat_zor$day <- as.numeric(format(inat_zor$eventDate, "%d"))
inat_zor$month <- as.numeric(format(inat_zor$eventDate, "%m"))
inat_zor$year <- as.numeric(format(inat_zor$eventDate, "%Y"))

# remove records wheere the identifier is NA
inat_zor <- inat_zor[!is.na(inat_zor$identifiedBy),]

# rename user pkocare1 to Petr Kočárek
inat_zor$identifiedBy <- ifelse(inat_zor$identifiedBy == "pkocare1", "Petr Kočárek", inat_zor$identifiedBy)


# fill taxons ranks of records
taxon_ranks <- read.csv("taxon_ranks.csv")

for (i in seq(nrow(inat_zor))) {
    taxon_info <- taxon_ranks[taxon_ranks$scientificName == inat_zor$scientificName[i], ]
    
    inat_zor[i, names(taxon_info)] <- taxon_info
}

# compare with current dataset
zod <- read.csv("zoraptera_occs.csv")

# fill the columns that are not in the inat data with NA
inat_zor[setdiff(names(zod), names(inat_zor))] <- NA

# check for any new inatID from the inat records compared to current dataset. If tehere is new record, add it to dataset. Check the rest of records for updates in scientifcName. If the scientific name differs, update the record including taxon ranks.

for (i in seq(nrow(inat_zor)) ) {
    id <- inat_zor$inatID[i]
   
    if (!id %in% zod$inatID) {
        zod <- rbind(zod, inat_zor[i,])
    } else {
        if (inat_zor[i, "scientificName"] != zod[zod$inatID == id& !is.na(zod$inatID), "scientificName"]) {
            taxon_info <- taxon_ranks[taxon_ranks$scientificName == inat_zor[i, "scientificName"], ]
            for (col in names(taxon_info)) {
                zod[zod$inatID == id& !is.na(zod$inatID), col] <- taxon_info[col]
            }
        }
    }
}

# generate new zodIDs
max_id <- max(zod$zodID, na.rm = TRUE)
zod$zodID[is.na(zod$zodID)] <- seq(max_id + 1, max_id + sum(is.na(zod$zodID)))

# write updated dataset to file
write.csv(zod, "zoraptera_occs.csv", row.names = FALSE, na = "")

# update log file with actual date and source (inaturalist)
current_date <- Sys.Date()
source <- "iNaturalist"

log_entry <- paste(current_date, source, sep = ",")

write(log_entry, "data_update/update.log", append = TRUE)
