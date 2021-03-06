
merge_lake_data <- function(out_ind, temp_data_ind, lake_names_ind, dow_cross_ind, state_cross_ind, MN_bathy_ind){
  temp_dat <- feather::read_feather(sc_retrieve(temp_data_ind))
  lakenames <- readRDS(sc_retrieve(lake_names_ind))
  dow <- get(load(sc_retrieve(dow_cross_ind)))
  lakestates <- readRDS(sc_retrieve(state_cross_ind))
  MN_bathy <- readRDS(sc_retrieve(MN_bathy_ind))

  total_obs <- temp_dat %>%
    group_by(nhd_id) %>%
    summarize(n_obs = n())

  lake_days <- temp_dat %>%
    group_by(nhd_id, date) %>%
    summarize(n_depths = n()) %>%
    filter(n_depths >= 5) %>%
    ungroup() %>%
    mutate(year = lubridate::year(date)) %>%
    group_by(nhd_id) %>%
    summarize(n_profiles = n())

  profile_years <- temp_dat %>%
    group_by(nhd_id, date) %>%
    summarize(n_depths = n()) %>%
    filter(n_depths >= 5) %>%
    ungroup() %>%
    mutate(year = lubridate::year(date)) %>%
    group_by(nhd_id, year) %>%
    summarize(n_profiles = n()) %>%
    filter(n_profiles >5) %>%
    group_by(nhd_id) %>%
    summarize(n_years_6profs = n())

  zmax_true <- unique(lakeattributes::zmax$site_id)

  all_lakes <- unique(lakenames$site_id)
  hypso_true <- function(lake_id) {
    temp_hypso <- lakeattributes::get_bathy(site_id = lake_id, cone_est = FALSE)
    return(ifelse(is.null(temp_hypso), FALSE, TRUE))
  }


  MN_bathy_NHDs <- dow %>%
    distinct() %>%
    filter(!is.na(site_id)) %>%
    filter(dowlknum %in% as.factor(MN_bathy$DOW)) %>%
    #group_by(dowlknum) %>%
    #summarize(site_id = first(site_id)) %>%
    dplyr::select(site_id)

  hypso_dat <- data.frame(site_id = all_lakes,
                          hypsometry = sapply(all_lakes, hypso_true))

  hypso_dat$hypsometry[hypso_dat$site_id %in% as.factor(MN_bathy_NHDs$site_id)] <- TRUE
  #sum(hypso_dat$hypsometry==TRUE) # 993 without MN_bathy; 1779 with


  dows_first_nhdid <- dow %>%
    filter(!is.na(site_id)) %>%
    #filter(site_id %in% total_obs$nhd_id) %>% # remove this line to list DOWs for NHD IDs without temp data in case we can find data
    distinct() %>%
    #group_by(dowlknum) %>% # Remove this line and one below to list all matching DOWs per NHD, even if DOWs appear multiple times in table
    #summarize(site_id = first(site_id)) %>% # see above
    group_by(site_id) %>%
    summarize(dowlknum = paste(dowlknum, collapse = ', '))

  lake_summary <- dplyr::select(lakenames, site_id, lake_name) %>%
    left_join(rename(total_obs, site_id = nhd_id)) %>%
    left_join(rename(lake_days, site_id = nhd_id)) %>%
    left_join(rename(profile_years, site_id = nhd_id)) %>%
    left_join(lakeattributes::location) %>%
    mutate(zmax = ifelse(site_id %in% zmax_true, TRUE, FALSE)) %>%
    left_join(hypso_dat) %>%
    left_join(distinct(dows_first_nhdid)) %>%
    left_join(lakestates)


  outfile <- as_data_file(out_ind)
  feather::write_feather(lake_summary, outfile)
  gd_put(out_ind)

}
