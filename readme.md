
## NBA Playoffs Forecast

This repository contains code for gathering data and producing a forecast for the NBA playoffs. Note that this is not a probabilistic forecast—though extending it in that direction would be straightforward with historical outcome data. Instead, teams are advanced based on their overall estimated rating, with higher-rated teams assumed to win each matchup. A detailed explanation of the methodology is provided below.

## Expected Minutes

This project collects and processes NBA team and player data from [Basketball-Reference](https://www.basketball-reference.com) to estimate expected playoff minutes for each team’s 10-man rotation. For each team in the 2024--25 season, the code scrapes roster information, advanced player statistics, and injury reports. Only players who have played more than 250 total minutes are considered for inclusion. To account for availability, players listed as "Out For Season" are removed. The top 10 players per team are selected based on their average minutes per game, calculated as total minutes played divided by games played:

$$
\text{MPG}_i = \frac{\text{MP}_i}{\text{G}_i}
$$

To better reflect playoff conditions---where star players see increased playing time and rotations shorten---a logistic transformation is applied to exaggerate differences in regular-season playing time. This transformation takes the form:

$$
w_i = \frac{1}{1 + \exp\left(-\alpha \cdot (\text{MPG}_i - \text{MedianMPG})\right)}
$$

where $\alpha$ controls the steepness and $\text{MedianMPG}$ is the median minutes per game among the top 10 players. These transformed values are then scaled so that their sum equals 240 minutes---the total minutes available per team per game:

$$
\text{Minutes}_i = w_i \cdot \frac{240}{\sum w_i}
$$

Finally, any player whose minutes exceed the 48-minute regulation limit is capped at 48, and the excess is proportionally redistributed to the remaining players. This iterative process continues until the distribution sums to exactly 240 minutes and no player exceeds the maximum.

## Player Productivities

To evaluate each team's overall productivity, I begin by collecting individual player statistics: Player Efficiency Rating (PER), Win Shares per 48 minutes (WS/48), and Box Plus/Minus (BPM). These three measures are extracted and renamed for standardization. For each metric, missing values are imputed using the league-wide mean, and the variables are then standardized to have a mean of zero and a standard deviation of one:

$$
z_{ij} = \frac{x_{ij} - \bar{x}_j}{\sigma_j}
$$

where $x_{ij}$ is player $i$'s value for statistic $j$, $\bar{x}_j$ is the league-wide mean of statistic $j$, and $\sigma_j$ is its standard deviation.

### Team Ratings Based on Projected Playoff Productivity

Next, I compute an average productivity score for each player by taking the mean of the three standardized metrics. This average is then weighted by the player’s projected playoff minutes (described in the previous section). For each team, I calculate a minutes-weighted average productivity:

$$
s_k = \text{TeamScore}_k = \frac{\sum \text{Productivity}_i \cdot \text{Minutes}_i}{\sum \text{Minutes}_i}
$$

for all players $i$ on team $k$ (github hates subset notation). Finally, these team scores are themselves standardized across the league to produce a relative team rating:

$$
\text{Rating}_k = \frac{s_k - \bar{s}}{\sigma_s}
$$

This rating captures how productive each team's playoff rotation is expected to be, relative to the league average, based on a composite of advanced player statistics and projected playing time.

### Projected Team Ratings by Conference

| Western Conf. | Rating | Eastern Conf. | Rating |
|:-------------:|:------:|:-------------:|:------:|
| OKC           |  2.05  | CLE           |  1.54  |
| DEN           |  1.24  | BOS           |  1.22  |
| LAC           |  0.83  | NYK           |  0.87  |
| GSW           |  0.75  | MIL           |  0.55  |
| MIN           |  0.62  | IND           |  0.29  |
| LAL           |  0.61  | DET           |  0.08  |
| MEM           |  0.61  | CHI           | -0.04  |
| HOU           |  0.38  | ORL           | -0.05  |
| SAC           |  0.15  | ATL           | -0.19  |
| DAL           | -0.36  | MIA           | -0.19  |
| PHO           | -0.51  | TOR           | -0.19  |
| POR           | -0.52  | BRK           | -1.26  |
| SAS           | -0.78  | PHI           | -1.33  |
| UTA           | -0.84  | CHO           | -1.66  |
| NOP           | -1.80  | WAS           | -2.07  |
