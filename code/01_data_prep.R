# NOTE: input files for this preliminary data formatting script cannot be shared due to UWIN data agreements
# this script is here just so the initial data formatting code can be seen
# but this will not run since the files are not present in the repo

# library(tidyverse)
# library(janitor)
# library(lubridate)
# library(suncalc)
# 
# ### We began with two csvs full of camera trap photo records from multiple UWIN
# ### contributors who approved use of their cities' data for this project. Both files 
# ### included one observation per row, and the following variables per observation:
# ### "Species", "locationID", "visitID", "Site", "photoDatetime", "valStatID",
# ### "visitDateTime", "photoName", "ID", "city", "Lat", Long". 
# 
# # load and clean data
# # read in photo records 1
# pr1 <- read.csv("data/photo_records01.csv") %>%
#   select("city","Site","Lat","Long","visitDateTime","photoDatetime", "Species") %>%
#   rename(site = "Site",
#          lat = "Lat",
#          lon = "Long",
#          end = "visitDateTime",
#          timestamp = "photoDatetime",
#          sp = "Species") %>%
#   mutate(end = as_date(end)) %>%
#   filter(!is.na(city)) %>%
#   group_by(site, end) %>%
#   mutate(start = as_date(min(timestamp, na.rm = TRUE))) %>%
#   ungroup() %>%
#   relocate(start, .before = end) %>%
#   mutate(site = toupper(site),
#          city = toupper(city))
# 
# # read in photo records 2
# pr2 <- read.csv("data/photo_records02.csv") %>%
#   mutate(site = toupper(site),
#          city = toupper(city),
#          start = mdy(start),
#          end = mdy(end))
# 
# # combine photo records into one dataframe
# pr <- bind_rows(pr1,pr2) %>%
#   distinct() # remove duplicate observations (i.e. multiple photos from same photoburst)
# 
# # Gather covariate data 
# # Prepare data and pull CSP global human modification values
# unique_coords <- pr %>%
#   group_by(city,site,lat,lon) %>%
#   mutate(id = cur_group_id()) %>%
#   distinct(id, city, site, lat, lon)
# 
# write.csv(unique_coords, file = (here("data/unique_coords_for_ghm.csv")))
# 
# # Pull ghm values - run this code in GEE
# 
# # // Load Global Human Modification dataset (ImageCollection → Image)
# # var humanMod = ee.ImageCollection('CSP/HM/GlobalHumanModification')
# # .first()
# # .select('gHM');
# # 
# # // Visualization (optional)
# # var humanModVis = {
# #   min: 0,
# #   max: 1,
# #   palette: ['006400', 'ffff00', 'ff0000']
# # };
# # 
# # // Map setup
# # //Map.setCenter(-77.1056, 38.8904, 8);
# # Map.centerObject(pts, 10);
# # //Map.addLayer(humanMod, humanModVis, 'Human Modification');
# # Map.addLayer(pts, {color: 'red'}, 'My Points');
# # 
# # // Extract raster values at GPS points
# # var results = humanMod.reduceRegions({
# #   collection: pts,
# #   reducer: ee.Reducer.first().setOutputs(['gHM']),
# #   scale: 1000
# # });
# # 
# # print(results);
# # 
# # 
# # // Export to Drive
# # Export.table.toDrive({
# #   collection: results,
# #   description: 'human_modification_values',
# #   fileFormat: 'CSV'
# # });
# 
# # Load global human modification layer data and clean to join with photo record
# ghm <- read.csv("data/human_modification_values.csv") %>%
#   mutate(city = toupper(city),
#          site = toupper(site)) %>%
#   select("city","gHM","site") %>%
#   filter(!is.na(gHM)) %>%
#   distinct()
# 
# # Join gHM data w/ photo record, combine all lagomorph species and all rat species for analysis
# data1 <- pr %>% 
#   left_join(ghm, by = c("site","city")) %>%
#   mutate(
#     sp = if_else(
#       str_detect(sp, "rabbit|hare|cottontail"),"lagomorph", sp)) %>%
#   mutate(
#     sp = if_else(
#       str_detect(sp,"rat"),"rats",sp))
# 
# # Determine which taxa to include in analysis (taxa observed at >100 sites)
# # calculate number cities and sites each species was detected at
# species_counts <- data1 %>%
#   group_by(sp) %>%
#   summarise(
#     n_obs = n(),
#     n_sites = n_distinct(site),
#     n_cities = n_distinct(city),
#     .groups = "drop") 
# 
# # Make sure we're not including "lagomorph" group AND all individual lagomorph species
# # filter species observed >100 sites
# species_counts2 <- species_counts %>%
#   filter(grepl("rabbit|hare|cottontail", sp)) %>%
#   summarise(
#     sp = "lagomorphs",
#     n_obs = sum(n_obs, na.rm = TRUE),
#     n_sites = sum(n_sites, na.rm = TRUE),
#     n_cities = sum(n_cities, na.rm = TRUE)) %>%
#   bind_rows(species_counts) %>%
#   filter(!sp %in% c("hare_rabbit", "jackrabbit_sp", "european_hare",
#                     "european_rabbit", "snowshoe_hare", "swamp_rabbit",
#                     "cottontail_sp", "rabbit_hare")) %>%
#   filter(n_sites >= 100)
# 
# # load functional traits data from EltonTraits1.0
# MamFuncDat <- read.delim("data/MamFuncDat.txt") %>%                        
#   select(c("Scientific","Activity.Crepuscular","Activity.Nocturnal")) %>%
#   rename(sci_name = "Scientific",
#          crepuscular = "Activity.Crepuscular",
#          nocturnal = "Activity.Nocturnal") %>%
#   filter(!(crepuscular == 0 & nocturnal == 0)) %>%
#   mutate(sci_name = to_snake_case(sci_name)) %>%
#   filter(sci_name %in% c(
#     "dasypus_novemcinctus",      # armadillo
#     "rattus_norvegicus",         # rep for rats
#     "puma_concolor",             # cougar
#     "canis_latrans",             # coyote
#     "erinaceus_europaeus",       # european_hedgehog
#     "glaucomys_volans",          # rep for flying_squirrel_sp
#     "mephitis_mephitis",         # striped_skunk
#     "sylvilagus_floridanus",     # rep for lagomorphs
#     "alces_alces",               # moose
#     "odocoileus_hemionus",       # mule_deer
#     "neovison_vison",            # north_american_mink
#     "procyon_lotor",             # raccoon
#     "didelphis_virginiana",      # virginia_opossum
#     "odocoileus_virginianus",    # white_tailed_deer
#     "vulpes_vulpes",             # red_fox
#     "urocyon_cinereoargenteus",  # gray_fox
#     "lynx_rufus"                 # bobcat
#   ))
# 
# # Now that we've determined which species are crepuscular and/or nocturnal AND detected at >100 sites, filter data
# data2 <- data1 %>%
#   filter(sp %in% c("armadillo","rats", "cougar", "coyote","european_hedgehog", 
#                    "flying_squirrel_sp","striped_skunk","lagomorph","moose", 
#                    "mule_deer", "north_american_mink",       
#                    "raccoon","virginia_opossum","white_tailed_deer","red_fox",
#                    "gray_fox","bobcat")) %>%
#   distinct() %>%
#   filter(!city %in% "CTSA") #only includes 1 species and 4 observations. rm from dataset
# 
# # Calculate response variable (time from nadir) and explanatory variable (night length) using suncalc
# # Create data frames to hold suncalc input variables (sunrise, sunset, and solar nadir) for day before, day of, and day after photo detection
# sun_input <- data2 %>% 
#   dplyr::select(date, lat, lon) %>% 
#   dplyr::distinct() %>% 
#   dplyr::mutate(date = lubridate::ymd(date))
# 
# next_sun_input <- data2 %>% 
#   dplyr::select(next_day, lat, lon) %>% 
#   dplyr::distinct() %>% 
#   dplyr::mutate(date = lubridate::ymd(next_day))
# 
# prev_sun_input <- data2 %>% 
#   dplyr::select(prev_day, lat, lon) %>% 
#   dplyr::distinct() %>% 
#   dplyr::mutate(date = lubridate::ymd(prev_day))
# 
# # pull all sun times from suncalc for day of detection
# sun_times <- getSunlightTimes(
#   data = sun_input,
#   keep = c("sunrise", "sunset","nadir"),
#   tz = "UTC") %>% 
#   dplyr::select(date, lat, lon, nadir, sunrise, sunset) %>% 
#   tibble::as_tibble()
# 
# # pull solar nadir values for day after detection
# next_sun_times <- getSunlightTimes(
#   data = next_sun_input,
#   keep = c("nadir"),
#   tz = "UTC") %>%
#   rename(next_nadir = nadir,
#          next_day = date) %>% 
#   tibble::as_tibble()
# 
# # pull solar nadir values for day before detection
# prev_sun_times <- getSunlightTimes(
#   data = prev_sun_input,
#   keep = c("nadir"),
#   tz = "UTC") %>%
#   rename(prev_nadir = nadir,
#          prev_day = date) %>% 
#   tibble::as_tibble()
# 
# # join sun times data w/ photo record
# data3 <- data2 %>% 
#   dplyr::mutate(date = lubridate::ymd(date)) %>% 
#   left_join(sun_times) %>%
#   left_join(prev_sun_times ) %>%
#   left_join(next_sun_times)
# 
# # calculate time since nadir ("nadir_diff") for response variable
# data4 <- data3 %>%
#   mutate(
#     time_since_nadir = as.numeric(difftime(timestamp, nadir, units = "mins")),            # for date of observation
#     time_to_next_nadir = as.numeric(difftime(timestamp, next_nadir, units = "mins")),     # for following date
#     time_since_prev_nadir = as.numeric(difftime(timestamp, prev_nadir, units = "mins")),  # for previous date
#     nadir_diff = pmin(                                                                    # select closest time from nadir
#       abs(time_since_nadir),
#       abs(time_to_next_nadir),
#       abs(time_since_prev_nadir),
#       na.rm = TRUE))
# 
# # calculate night length (nl) for explanatory variable
# data5 <- data4 %>%
#   dplyr::mutate(dl = as.numeric(difftime(sunset, sunrise, units = "hours")),     # calculate day length
#                 nl = 24 - dl)                                                    # calculate night length
# 
# # create 'is_night' to ensure crepuscularity/nocturnality
# data6 <- data5 %>%
#   mutate(
#     is_night = if_else (
#       timestamp >= sunrise & timestamp <=sunset, 0, 1)) %>%
#   distinct(site, sp, timestamp, .keep_all = TRUE) %>%
#   filter(!is.na(timestamp))
# 
# # read data to csv for analysis in "analysis_and_results.R"
# write.csv(data6, ("data/obs.csv"))
# NOTE: this obs.csv is the main data file upon which analyses are based; we omitted some non-necessary columns
# and convered to RDS for the repo to stay within file-size limits

