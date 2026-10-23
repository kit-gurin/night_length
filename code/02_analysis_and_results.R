library(tidyverse)
library(glmmTMB)
library(ggplot2)

# load data, tidy, scale variables
data <- readRDS("data/obs.rds")

all_sp <- data %>%
  mutate(nl.sc = scale(nl),
         ghm.sc = scale(gHM),
         nd.hr = nadir_diff/60) %>% 
  dplyr::group_by(sp,site,city,sample_period) %>% 
  dplyr::mutate(sp.site.city.sample = dplyr::cur_group_id())%>%
  mutate(nd.hr = (nd.hr+0.0000001))

# fit full model 
all_full <- glmmTMB(nd.hr ~ 1 + nl.sc * ghm.sc + (1 + nl.sc * ghm.sc |sp) + (1 | sp.site.city.sample),
                    data = all_sp,
                    family = Gamma(link = "log"))

# new data and predictions
# H1: long night expansion - Longer nights facilitate activity farther from middle of night

# "Average species" prediction for time from nadir ~ night length
avg.newdat1 <- tidyr::expand_grid(
  nl.sc = seq(from = min(all_sp$nl.sc, na.rm = TRUE),
              to = max(all_sp$nl.sc, na.rm = TRUE),
              length.out = 20),
  sp.site.city.sample = NA,
  ghm.sc = mean(all_sp$ghm.sc, na.rm = TRUE),
  sp = NA
)

avg.preds1 <- predict(all_full, avg.newdat1, re.form = NULL, type = "response", se = TRUE)

nl_scale <- scale(all_sp$nl)

avg.newdat1 <- avg.newdat1 %>% 
  dplyr::mutate(nl = nl.sc*attr(nl_scale, "scaled:scale") + attr(nl_scale, "scaled:center")) %>% 
  tibble::add_column(fit = avg.preds1$fit,
                     se = avg.preds1$se.fit
  ) 

# Calculate differences in time from nadir activity between long and short nights for "average" species
avg.results1 <- avg.newdat1 %>%
  select(-c(sp.site.city.sample,ghm.sc,sp)) %>%
  summarize(
    short_nl_fit  = fit[which.min(nl.sc)],
    short_nl_se   = se[which.min(nl.sc)],
    long_nl_fit = fit[which.max(nl.sc)],
    long_nl_se  = se[which.max(nl.sc)],
    diff_nl_fit = long_nl_fit - short_nl_fit
  )

# species level predictions for time from nadir ~ night length

sp.newdat1 <- all_sp %>%
  group_by(sp) %>%
  summarise(
    nl_min  = min(nl.sc, na.rm = TRUE),
    nl_max  = max(nl.sc, na.rm = TRUE),
    ghm_mean = 0) %>%
  rowwise() %>%
  mutate(grid = list(
    tidyr::expand_grid(
      nl.sc = seq(from = nl_min,
                  to   = nl_max,
                  length.out = 20),
      sp.site.city.sample = NA,
      ghm.sc = ghm_mean,
      sp = sp))) %>%
  ungroup() %>%
  select(grid) %>%
  unnest(grid)

sp.preds1 <- predict(all_full, sp.newdat1, re.form = NULL, type = "response", se = TRUE)

nl_scale <- scale(all_sp$nl)

sp.newdat1 <- sp.newdat1 %>% 
  dplyr::mutate(nl = nl.sc*attr(nl_scale, "scaled:scale") + attr(nl_scale, "scaled:center")) %>% 
  tibble::add_column(fit = sp.preds1$fit,
                     se = sp.preds1$se.fit
  ) 

# Calculate species level differences in time from nadir activity between long and short nights
sp.results1 <- sp.newdat1 %>%
  select(-c(sp.site.city.sample,ghm.sc)) %>%
  group_by(sp) %>%
  summarize(
    short_nl_fit  = fit[which.min(nl.sc)],
    short_nl_se   = se[which.min(nl.sc)],
    long_nl_fit = fit[which.max(nl.sc)],
    long_nl_se  = se[which.max(nl.sc)],
    diff_nl_fit = long_nl_fit - short_nl_fit
  )

# H2: Release hypothesis - night length modulates activity timing response of mammals to urbanization
# "Average species" prediction for time from nadir ~ night length * urbanization
avg.newdat2 <- all_sp %>% 
  filter(!is.na(ghm.sc)) %>%
  ungroup() %>%  
  select(nl.sc) %>% 
  filter(nl.sc == min(nl.sc) | nl.sc == max(nl.sc)) %>% 
  distinct() %>% 
  cross_join(tibble(ghm.sc = seq(from = min(all_sp$ghm.sc, na.rm = TRUE),
                                 to = max(all_sp$ghm.sc, na.rm = TRUE),
                                 length.out = 20))) %>% 
  add_column(sp.site.city.sample = NA,
             sp = NA)

avg.preds2 <- predict(all_full, avg.newdat2, type = "response", se = TRUE, re.form = NULL)

ghm_scale <- scale(all_sp$gHM)

avg.newdat2 <- avg.newdat2 %>% 
  add_column(fit = avg.preds2$fit,
             se = avg.preds2$se.fit) %>%
  mutate(nl.lab = ifelse(nl.sc < 0, 'lo', 'hi')) %>%
  mutate(lab = ifelse(nl.lab == 'lo', "short",
                      ifelse(nl.lab == 'hi', "long", 'whoops'))) %>%
  mutate(night_type = factor(lab, levels = c("long", "short"))) %>%
  mutate(ghm = ghm.sc*attr(ghm_scale, "scaled:scale") + attr(ghm_scale, "scaled:center"))


# species level predictions for time from nadir ~ night length * urbanization
sp.newdat2 <- all_sp %>%
  filter(!is.na(ghm.sc)) %>%
  group_by(sp) %>%
  summarise(
    nl_min  = min(nl.sc, na.rm = TRUE),
    nl_max  = max(nl.sc, na.rm = TRUE),
    ghm_min = min(ghm.sc, na.rm = TRUE),
    ghm_max = max(ghm.sc, na.rm = TRUE)) %>%
  pivot_longer(cols = c(nl_min, nl_max),
               names_to = "nl_type",
               values_to = "nl.sc") %>%
  mutate(nl_type = ifelse(nl_type == "nl_min", "min", "max")) %>%
  rowwise() %>%
  mutate(ghm_seq = list(seq(from = ghm_min,
                            to   = ghm_max,
                            length.out = 20))) %>%
  unnest(ghm_seq) %>%
  rename(ghm.sc = ghm_seq) %>%
  mutate(sp.site.city.sample = NA) %>%
  select(c("sp","nl.sc","ghm.sc","sp.site.city.sample"))

sp.preds2 <- predict(all_full, sp.newdat2, type = "response", se = TRUE, re.form = NULL)

ghm_scale <- scale(all_sp$gHM)

sp.newdat2 <- sp.newdat2 %>% 
  add_column(fit = sp.preds2$fit,
             se = sp.preds2$se.fit) %>%
  mutate(nl.lab = ifelse(nl.sc < 0, 'lo', 'hi')) %>%
  mutate(lab = ifelse(nl.lab == 'lo', "short",
                      ifelse(nl.lab == 'hi', "long", 'whoops'))) %>%
  mutate(night_type = factor(lab, levels = c("long", "short"))) %>%
  mutate(ghm = ghm.sc*attr(ghm_scale, "scaled:scale") + attr(ghm_scale, "scaled:center"))

# Sanity check - Animals generally active closer to nadir in urban areas
# "Average species" prediction for time from nadir ~ urbanization
avg.ghm.newdat <- tidyr::expand_grid(
  ghm.sc = seq(from = min(all_sp$ghm.sc, na.rm = TRUE),
               to = max(all_sp$ghm.sc, na.rm = TRUE),
               length.out = 20),
  sp.site.city.sample = NA,
  nl.sc = mean(all_sp$nl.sc, na.rm = TRUE),
  sp = NA
)

avg.ghm.preds <- predict(all_full, avg.ghm.newdat, re.form = NULL, type = "response", se = TRUE)

ghm_scale <- scale(all_sp$gHM)

avg.ghm.newdat <- avg.ghm.newdat %>% 
  dplyr::mutate(ghm = ghm.sc*attr(ghm_scale, "scaled:scale") + attr(ghm_scale, "scaled:center")) %>% 
  tibble::add_column(fit = avg.ghm.preds$fit,
                     se = avg.ghm.preds$se.fit
  ) 

# Calculate differences in time from nadir activity between high and low urban areas for "average" species
avg.ghm.results <- avg.ghm.newdat %>%
  select(-c(sp.site.city.sample, nl.sc)) %>%
  summarize(
    low_ghm_fit  = fit[which.min(ghm.sc)],
    low_ghm_se   = se[which.min(ghm.sc)],
    high_ghm_fit = fit[which.max(ghm.sc)],
    high_ghm_se  = se[which.max(ghm.sc)],
    diff_ghm_fit = high_ghm_fit - low_ghm_fit
  )

# Species level predictions for time from nadir ~ urbanization
sp.ghm.newdat <- all_sp %>%
  group_by(sp) %>%
  summarise(
    ghm_min  = min(ghm.sc, na.rm = TRUE),
    ghm_max  = max(ghm.sc, na.rm = TRUE),
    nl_mean = mean(nl.sc, na.rm = TRUE)) %>%
  rowwise() %>%
  mutate(grid = list(
    tidyr::expand_grid(
      ghm.sc = seq(from = ghm_min,
                   to   = ghm_max,
                   length.out = 20),
      sp.site.city.sample = NA,
      nl.sc = nl_mean,
      sp = sp))) %>%
  ungroup() %>%
  select(grid) %>%
  unnest(grid)

sp.ghm.pred <- predict(all_full, sp.ghm.newdat, re.form = NULL, type = "response", se = TRUE)

ghm_scale <- scale(all_sp$gHM)

sp.ghm.newdat <- sp.ghm.newdat %>% 
  dplyr::mutate(ghm = ghm.sc*attr(ghm_scale, "scaled:scale") + attr(ghm_scale, "scaled:center")) %>% 
  tibble::add_column(fit = sp.ghm.pred$fit,
                     se = sp.ghm.pred$se.fit
  ) 

# Calculate species level differences in time from nadir activity between high and low urban areas
sp.ghm.results <- sp.ghm.newdat %>%
  select(-c(sp.site.city.sample,nl.sc)) %>%
  group_by(sp) %>%
  summarize(
    low_ghm_fit  = fit[which.min(ghm)],
    low_ghm_se   = se[which.min(ghm)],
    high_ghm_fit = fit[which.max(ghm)],
    high_ghm_se  = se[which.max(ghm)],
    diff_ghm_fit = high_ghm_fit - low_ghm_fit
  )

# Results plots
# H1: long night expansion - Longer nights facilitate activity farther from middle of night
# Figure 4a - "average species" response
avg.plot1 <- ggplot() +
  geom_ribbon(data = avg.newdat1, aes(x = nl,     
                                      ymin = fit - se, 
                                      ymax = fit + se), 
              color = NA, 
              alpha = 0.3) +
  geom_line(data = avg.newdat1, aes(x = nl, y = fit), linewidth = 2) + 
  scale_x_continuous(labels = function(x) ifelse(x %% 1 == 0, as.character(x), format(x, trim = TRUE))) +
  theme_minimal() +
  xlab("night length (hrs)") +
  ylab("time from nadir (hrs)") +
  theme(
    plot.background = element_rect(color = NA, fill = "white"),
    panel.grid = element_blank(), 
    axis.text = element_text(size = 9, color = "black"), 
    axis.title = element_text(size = 10, color = "black")
  )

# Figure 5 - species level responses
sp_labels <- c(
  "armadillo" = "Nine-banded\narmadillo",
  "bobcat" = "Bobcat",
  "rats" = "Rat spp.",
  "cougar" = "Cougar",
  "coyote" = "Coyote",
  "european_hedgehog" = "European\nhedgehog",
  "flying_squirrel_sp" = "Flying\nsquirrels",
  "gray_fox" = "Gray fox",
  "lagomorph" = "Rabbits\nand hares",
  "moose" = "Moose",
  "mule_deer" = "Mule deer",
  "north_american_mink" = "N. American\nmink",
  "raccoon" = "Raccoon",
  "red_fox" = "Red fox",
  "striped_skunk" = "Striped skunk",
  "virginia_opossum" = "Virginia\nopossum",
  "white_tailed_deer" = "White-tailed\ndeer")

refdat <- avg.newdat1 %>%
  select(-"sp")

multi.plots1 <- ggplot() +
  geom_ribbon(data = sp.newdat1, aes(x = nl,     
                                     ymin = fit - se, 
                                     ymax = fit + se), 
              color = NA, 
              alpha = 0.3) +
  geom_line(data = sp.newdat1, aes(x = nl, y = fit), linewidth = 1) + 
  geom_line(data = refdat, aes (x = nl, y = fit), color = "red", linetype = 2, linewidth = 0.15) +
  facet_wrap(~sp, ncol = 5, axes = "all", axis.labels = "margins", 
             labeller = as_labeller(sp_labels),
  ) +
  scale_x_continuous(labels = function(x) ifelse(x %% 1 == 0, as.character(x), format(x, trim = TRUE))) +
  scale_x_continuous(breaks = c(7.5, 11.5, 15.5)) +
  theme_minimal() +
  xlab("night length (hrs)") +
  ylab("time from nadir (hrs)") +
  theme(axis.line = element_line(color = "black", linewidth = 0.2),
        plot.background = element_rect(color = NA, fill = "white"),
        panel.grid = element_blank(), 
        strip.text = element_text(size = 9, hjust = 0, face = "bold"),
        axis.text = element_text(size = 9, color = "black"), 
        axis.title = element_text(size = 10, color = "black"),
  ) 

# H2: release hypothesis - night length modulates activity timing response of mammals to urbanization
# Figure 4b - "average species" response
avg.plot2 <- ggplot(data = sp.newdat2,
                           aes(x = ghm,
                               y = fit,
                               color = night_type,
                               fill = night_type)) +
  geom_ribbon(aes(ymin = fit - se, ymax = fit + se), alpha = 0.3, color = NA) +
  geom_line(linewidth = 2) +
  scale_x_continuous(breaks = c(0, 0.5, 1.0),
                     labels = function(x) sub("\\.?0+$", "", format(x, trim = TRUE))) +
  scale_color_manual(values = c("blue", "red")) +
  scale_fill_manual(values = c("blue", "red")) +
  guides(fill = "none") +
  theme_minimal() +
  labs( x = "urbanization",
        y = "time from nadir (hrs)",
        color = "night type",
        fill = NA) +
  theme(
    plot.background = element_rect(color = NA, fill = "white"),
    panel.grid = element_blank(),
    axis.text = element_text(size = 9, color = "black"),
    legend.position = "none",
    axis.title = element_text(size = 10, color = "black"),
  )

# Figure 6 - species level responses
multi.plots2 <- ggplot(data = sp.newdat2,
                              aes(x = ghm,
                                  y = fit,
                                  color = night_type,
                                  fill = night_type)) +
  geom_ribbon(aes(ymin = fit - se, ymax = fit + se), alpha = 0.3, color = NA) +
  geom_line(linewidth = 1) +
  scale_x_continuous(breaks = c(0, 0.5, 1.0),
                     labels = function(x) sub("\\.?0+$", "", format(x, trim = TRUE))) +
  scale_color_manual(values = c("blue", "red")) +
  scale_fill_manual(values = c("blue", "red")) +
  guides(fill = "none") +
  facet_wrap(~sp, ncol = 5, axes = "all", axis.labels = "margins",
             labeller = as_labeller(sp_labels),
  ) +
  theme_minimal() +
  labs( x = "urbanization",
        y = "time from nadir (hrs)",
        color = "night type",
        fill = NA) +
  theme(axis.line = element_line(color = "black", linewidth = 0.2),
        plot.background = element_rect(color = NA, fill = "white"),
        panel.grid = element_blank(),
        axis.text = element_text(size = 9, color = "black"),
        legend.position = "none",
        axis.title = element_text(size = 10, color = "black"),
        strip.text = element_text(size = 9, color = "black", hjust = 0, face = "bold")
  )


###########################################################################################
### Species-level coefficients
all_full_re <- ranef( all_full )

str(all_full_re)

fixef(all_full)$cond %>% 
  as_tibble(rownames = "param")

sp_coefs_intxn <- all_full_re$cond$sp %>% 
  as_tibble(rownames = "sp") %>% 
  pivot_longer(`(Intercept)`:`nl.sc:ghm.sc`, values_to = "estimate", names_to = "param") %>% 
  dplyr::full_join(
    fixef(all_full)$cond %>% 
      as_tibble(rownames = "param")) %>% 
  mutate(sp_level_coef = estimate + value) %>% 
  
  filter(param == "nl.sc:ghm.sc") %>% 
  arrange(sp_level_coef)

sp_coefs_nl <- all_full_re$cond$sp %>% 
  as_tibble(rownames = "sp") %>% 
  pivot_longer(`(Intercept)`:`nl.sc:ghm.sc`, values_to = "estimate", names_to = "param") %>% 
  dplyr::full_join(
    fixef(all_full)$cond %>% 
      as_tibble(rownames = "param")) %>% 
  mutate(sp_level_coef = estimate + value) %>% 
  
  filter(param == "nl.sc") %>% 
  # select(c(sp,param,estimate),sp_level_coef) %>%
  arrange(sp_level_coef)


