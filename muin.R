# Copyright 2019 Stefan Weigert
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



# devtools::install_github("rladies/meetupr")
library(meetupr)
library(plyr)
library(tidyverse)
library(lubridate)

# Obtain your key from <https://secure.meetup.com/meetup_api/key/>
KEY = "<KEY_TO_YOUR_MEETUP>"
# The URL is the part _after_ meetup.com
urlname <- "<URL_TO_YOUR_MEETUP>"
events <- get_events(urlname, c("past", "upcoming"), api_key = KEY)
members <- get_members(urlname, api_key = KEY)



#### Population structure ####
ggplot(data = members,
       aes(
         x = format(as.Date(joined), "%Y")
      )) +
  geom_bar() +
  scale_y_continuous("Number of members") +
  scale_x_discrete() +
  theme_minimal() +
  theme(
    panel.grid.major.x = element_blank(),
    axis.title.x = element_blank()
  )



#### Most senior member ####
senior_meetup_user <- members %>% arrange(joined) %>% slice(1)
senior_meetup_user$joined


#### Member growth over time ####
# for each meetup, take the time it was announced (x$created) and the time it happened (x$time) and
# put them in two seperate rows with the same name
# finally, add a third row, one day later, with the name "void" which marks the time period between two meetups
# then, use "complete" to fill the gaps in the date-column. the new rows will have "NA" in the name column.
# the latter is mitigated with fill
df_ev <- ldply(events$resource, function(x) data.frame(name = c(x$name, x$name, "Void"), ts = c(x$created/1000, x$time/1000, (x$time/1000 + 24)))) %>%
         mutate(ts = as_date(as_datetime(ts))) %>%
         complete(ts = seq.Date(from = min(ts), to = max(ts), by = "day")) %>%
         fill(name)

# create dataframe from lost similar to the one above
# since every new member is it's own row (id is the member's meetup.com id), the row_count is the total count of members.
# the use the same trick with complete and fill to add the missing dates
df <- ldply(members$resource, function(x) data.frame(id = x$id, ts = x$group_profile$created/1000)) %>%
      mutate(cnt = row_number(ts)) %>%
      mutate(ts = as_date(as_datetime(ts))) %>%
      complete(ts = seq.Date(from = min(ts), to = max(ts), by = "day")) %>%
      arrange(ts) %>%
      fill(id, cnt)

# now we have two dataframes with the dt column filled for every day since the start of the meetup
# join the members dataframe with the events dataframe on the date column
df <- left_join(df, df_ev, by = c("ts"))
# you'll need that if people joined your meetup before the first event was scheduled
df[is.na(df$name), ]$name <- "Void"


ggplot(data = df,
       aes(
         y = cnt,
         x = ts,
         color = name,
         group = name,
         fill = name,
         alpha = (name == "Void"),
         size = (name == "Void")
       )) +
  #stat_smooth(aes(group = 1), method = "lm", fill = "red", colour = "red", alpha = 1) +
  geom_point(shape = 21, fill = "white") +
  scale_x_date() +
  scale_y_continuous("#Members") +
  scale_color_brewer(type = "qual", palette = "Dark2") +
  scale_fill_brewer(type = "qual", palette = "Dark2") +
  scale_alpha_manual(values = c(0.75, 0.25)) +
  scale_size_manual(values = c(1.75, 0.75)) +
  guides(alpha = FALSE, size = FALSE) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 8),
    legend.title = element_blank(),
    axis.title.x = element_blank()
  )

geom#### Model growth ####
# create generalized linear model of the number of #mldd members as a function of time
mdl <- lm(cnt~as_datetime(ts), data = df)
predict(mdl, data.frame(ts = as_datetime("2020-01-29")))


#### Top 3 Countries ####
members %>% group_by(country) %>% summarise(n_obs = n()) %>% arrange(desc(n_obs)) %>% slice(1:3)


#### Top 10 Cities ####
ggplot(data = members %>% group_by(city) %>% summarise(n_obs = n()) %>% arrange(desc(n_obs)) %>% slice(1:10),
       aes(
         x = reorder(city, n_obs),
         y = n_obs,
         label = n_obs
       )) +
  geom_col() +
  geom_text(hjust = "right", nudge_y = 20) +
  scale_x_discrete() +
  scale_y_continuous() +
  coord_flip() +
  theme_minimal() +
  theme(panel.grid = element_blank(),
        axis.text.x = element_blank(),
        axis.title = element_blank())


#### Member Maps ####
library(mapdata)
world <- map_data("world")

ggplot() +
  geom_path(data = world, aes(x = long, y = lat, group = group), alpha = 0.5, size = 0.01) +
  geom_point(data = members, aes(x = lon, y = lat), colour = "purple", fill = "purple", alpha = 0.66, size = 2, shape = 21) +
  coord_map(xlim = c(-180, 180)) +
  theme_minimal() +
  theme(panel.border =  element_blank(),
        axis.text = element_blank(),
        panel.grid = element_blank(),
        axis.title = element_blank())


zoom <- world %>% filter(long >= -10, long <= 25, lat >= 40, lat <= 60)
ggplot() +
  geom_path(data = zoom, aes(x = long, y = lat, group = group), alpha = 0.5, size = 0.01) +
  geom_point(data = members, aes(x = lon, y = lat), colour = "purple", fill = "purple", alpha = 0.66, size = 2, shape = 21) +
  coord_map(xlim = c(-10, 25), ylim = c(40, 60)) +
  theme_minimal() +
  theme(panel.border =  element_blank(),
        axis.text = element_blank(),
        panel.grid = element_blank(),
        axis.title = element_blank())
