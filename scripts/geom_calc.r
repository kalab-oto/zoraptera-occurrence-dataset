library(sf)
library(lwgeom)

# load data
zod <- read.csv("zoraptera_occs.csv")

zora_geom <- st_read('geom/geom.gpkg', fid_column_name = "polygon_fid")

# get coordinates and uncertainty
for (i in seq(nrow(zora_geom))){ 

    print(paste0(i, "/", nrow(zora_geom)))

    tp <- zora_geom[i,"geom"]
    
    # make enclosing circle and its centroid
    tp_circle <- st_minimum_bounding_circle(tp)
    tp_cc <- st_centroid(tp_circle)

    # if that centroid dont intersect find nearest point on polygon

    if (is.na(as.numeric(st_intersects(tp_cc$geom, tp)))){
        tp_cor_c <- st_endpoint(st_nearest_points(tp_cc, tp))
        tp_cc <- tp_cor_c
    }
    
    # calculate the ellipsoidal distance to most distant vertex from that point (radius)
    tp_cc <- st_transform(tp_cc, st_crs(4326))
    
    # densify polygon
    tp <- st_cast(tp, "MULTILINESTRING")
    tp <- st_cast(tp, "LINESTRING")
    tp <- st_line_sample(tp, density = 1/100)
    tp <- st_cast(tp, "POINT")

    # calculate maximum geodetic distance from the center point to each vertex
    tp <- st_transform(tp, st_crs(4326))
    distance <- max(na.omit(c(st_geod_distance(tp_cc, tp))))
    
    # write values
    zora_geom[i,"decimalLongitude"] <- st_coordinates(tp_cc)[, "X"]
    zora_geom[i,"decimalLatitude"] <- st_coordinates(tp_cc)[, "Y"]
    zora_geom[i,"coordinateUncertaintyInMeters"] <- as.integer(distance)
    zora_geom[i,"footprintWKT"] <- NA
    }

# get WKT footprint
zora_geom <- st_transform(zora_geom, st_crs(4326))
zora_geom$footprintWKT <- st_astext(zora_geom, 10)

# merge data
zora_geom <- zora_geom[,c("polygon_fid", "decimalLongitude", "decimalLatitude", "coordinateUncertaintyInMeters", "footprintWKT")]

zora_m <- merge(zod,zora_geom,by = "polygon_fid", all=T)

# remove excess columns
zora_m$decimalLongitude.x <- ifelse(is.na(zora_m$decimalLongitude.x), zora_m$decimalLongitude.y, zora_m$decimalLongitude.x)
zora_m$decimalLatitude.x <- ifelse(is.na(zora_m$decimalLatitude.x), zora_m$decimalLatitude.y, zora_m$decimalLatitude.x)
zora_m$coordinateUncertaintyInMeters.x <- ifelse(is.na(zora_m$coordinateUncertaintyInMeters.x), zora_m$coordinateUncertaintyInMeters.y, zora_m$coordinateUncertaintyInMeters.x)

zora_m$footprintWKT.x <- ifelse(!is.na(zora_m$footprintWKT.y) & zora_m$footprintWKT.y != zora_m$footprintWKT.x, zora_m$footprintWKT.y, zora_m$footprintWKT.x)

zora_m[c("coordinateUncertaintyInMeters.y", "decimalLongitude.y", "decimalLatitude.y", "footprintWKT.x", "geom")] <- list(NULL)

# fix column names
names(zora_m)[names(zora_m) == "coordinateUncertaintyInMeters.x"] <- 'coordinateUncertaintyInMeters'
names(zora_m)[names(zora_m) == "decimalLongitude.x"] <- 'decimalLongitude'
names(zora_m)[names(zora_m) == "decimalLatitude.x"] <- 'decimalLatitude'
names(zora_m)[names(zora_m) == "footprintWKT.y"] <- 'footprintWKT'

# reorder columns
zora_m <- zora_m[,c("zodID", "order", "family", "subfamily", "genus", "specificEpithet", "scientificName", "taxonRank", "scientificNameAuthorship", "identificationQualifier", "originalNameUsage", "nomenclaturalStatus", "country", "locality", "verbatimElevation", "verbatimLatitude", "verbatimLongitude", "osmID", "decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters", "habitat", "eventDate", "day", "month", "year", "organismRemarks", "typeStatus", "recordedBy", "identifiedBy", "associatedReferences", "taxonRemarks", "gbifID", "inatID", "license","georeferenceRemarks", "georeferenceSources", "georeferencedBy", "georeferencedDate", "polygon_fid", "footprintWKT")]

# fill empty footprintWKT with MULTIPOLYGON EMPTY to make it valid
zora_m$footprintWKT <- ifelse(is.na(zora_m$footprintWKT), "MULTIPOLYGON EMPTY", zora_m$footprintWKT)

#order dataset by zodID
zora_m <- zora_m[order(zora_m$zodID),]

# write to file
write.csv(zora_m, file = "zoraptera_occs.csv", row.names = FALSE, na = "")

capture.output(devtools::session_info(),file="session_info/geom_calc_session.txt")
