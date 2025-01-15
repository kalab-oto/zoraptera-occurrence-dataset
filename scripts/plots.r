library(ggplot2)
library(sf)
library(smoothr)
library(spData)

zod <- read.csv("zoraptera_occs.csv")

zod$subfamily[zod$subfamily == ""] <- "not specified"
zod$subfamily <- factor(zod$subfamily, levels = c("Spermozorinae", "Latinozorinae", "Zorotypinae", "Spiralizorinae", "not specified"))

zod$family[zod$family == ""] <- "not specified"
zod$family <- factor(zod$family, levels = c("Zorotypidae", "Spiralizoridae", "not specified"))

# map

# load world map and reproject to robinson
robinson_crs <-  "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs"
world_robinson <- st_transform(st_union(world), crs = robinson_crs)

# make polygon enclosing for world map
w_bound <- st_polygon(list(rbind(c(-180, -90), c(180, -90), c(180, 90), c(-180, 90), c(-180, -90))))
w_bound <- st_sfc(w_bound)
st_crs(w_bound) <- 4326
w_bound <- densify(w_bound, max_distance = 5)
w_bound <- st_transform(w_bound, crs = robinson_crs)

# make graticules
graticules <- st_graticule(w_bound, lat = c(0, 30, -30, 60, -60))
gsub("degree", "°", graticules$degree_label) -> graticules$degree_label
gsub("\\*", "", graticules$degree_label) -> graticules$degree_label
gsub("\"", "", graticules$degree_label) -> graticules$degree_label

# make sf object from zoraptera
zod_sf <- st_as_sf(zod[!is.na(zod$decimalLongitude) & !is.na(zod$decimalLatitude),], coords = c("decimalLongitude", "decimalLatitude"))

# set crs
st_crs(zod_sf) <- 4326
zoraptera_sf <- st_transform(zod_sf, crs = robinson_crs)

# set subfamily order and colors

subf_colors <- c("Spermozorinae" = "#F8766D", "Latinozorinae" = "#00BFC4", "Zorotypinae" = "#C77CFF","Spiralizorinae" = "#7CAE00", "not specified" = "#929292")

# plot the map
ggplot() +
    geom_sf(data = world_robinson, color = "#a3a3a3", fill = "#fffde9") +
    geom_sf(data = graticules, color = "gray90", alpha = 0.7) +
    geom_sf(data = w_bound, fill = NA, color = "black") +
    geom_sf(data = zoraptera_sf[zoraptera_sf$subfamily == "not specified",], aes(color = subfamily), size = 3, alpha = 0.5) +
    geom_sf(data = zoraptera_sf[zoraptera_sf$subfamily == "Spiralizorinae",], aes(color = subfamily), size = 3, alpha = 0.5) +
    geom_sf(data = zoraptera_sf[zoraptera_sf$subfamily == "Spermozorinae",], aes(color = subfamily), size = 3, alpha = 0.5) +
    geom_sf(data = zoraptera_sf[zoraptera_sf$subfamily == "Latinozorinae",], aes(color = subfamily), size = 3, alpha = 0.5) +
    geom_sf(data = zoraptera_sf[zoraptera_sf$subfamily == "Zorotypinae",], aes(color = subfamily), size = 3, alpha = 0.5) +
    scale_color_manual(values = subf_colors, breaks = levels(zoraptera_sf$subfamily)) +
    geom_text(data = graticules[2:6,], aes(x = x_start, y = y_start, label = degree_label), size = 3, color = "gray", vjust = 2) +
    geom_text(data = graticules[8:12,], aes(x = x_start, y = y_start, label = degree_label), size = 3, color = "gray", hjust = 1.5) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(), 
          axis.title.x = element_blank(), 
          axis.title.y = element_blank(),
          legend.position = "bottom",
          legend.title = element_blank(),
          legend.text = element_text(margin = margin(l = -1), size = 12),
          legend.key.spacing.x = unit(10, "pt"))

# write the map
ggsave("plots/zoraptera_map.png", width = 12, height = 6, dpi = 100, bg = "white")

# histogram of years

# set family colors
f_colors <- c("Zorotypidae" = "#F8766D", "Spiralizoridae" = "#00BFC4", "not specified" = "#929292")

# plot the histogram
ggplot(zod, aes(x = year)) +
    geom_histogram(aes(fill = family), binwidth = 1, position = "stack") +
    scale_fill_manual(values = f_colors) +
    theme_minimal() +
    labs(x = "Year", y = "Count") +
    scale_x_continuous(breaks = c(1900, 1950, 2000), minor_breaks = seq(1890, 2020, by = 10)) +
    theme(panel.grid.major.x = element_line(color = "grey80"),
          legend.title = element_blank(),
          legend.text = element_text(size = 12),
          legend.position = c(0.05, 0.95),
          legend.justification = c("left", "top"),
          legend.background = element_rect(fill = "white", color = NA))

# write the histogram
ggsave("plots/zoraptera_years.png", width = 10, height = 3, dpi = 100, bg = "white")

capture.output(devtools::session_info(),file="session_info/plots_session.txt")