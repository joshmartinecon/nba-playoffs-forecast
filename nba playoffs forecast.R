
rm(list = ls())
library(rvest)
'%ni%' <- Negate('%in%')

### Read in Schedle
x <- read_html("https://www.basketball-reference.com/leagues/NBA_2025.html")

### Extract Links for Each Team
x %>%
  html_nodes("a") %>%
  html_attr("href") -> linkz
unique(linkz[grepl("/teams/", linkz)]) -> linkz
linkz[grepl("2025.html", linkz)] -> linkz

### Loop: Grab Advanced Statistics for Each Team
y <- list()
for(i in 1:length(linkz)){
  
  x <- read_html(paste0("https://www.basketball-reference.com", linkz[i]))
  
  # roster
  x %>%
    html_node('#roster') %>%
    html_table() %>%
    as.data.frame() -> z1
  z1$Player %>%
    str_replace_all("\\(TW\\)", "") %>%
    str_replace_all("\\s+$", "") %>%  
    str_replace_all("^\\s+", "") -> z1
  
  # advanced stats
  x %>%
    html_nodes(xpath = '//comment()') %>%    # select comment nodes
    html_text() %>%    # extract comment text
    paste(collapse = '') %>%    # collapse to a single string
    read_html() %>%    # reparse to HTML
    html_node('#div_advanced') %>%
    html_table() %>%
    as.data.frame() -> z
  z <- z[z$Player %in% z1,]
  
  # injuries
  if(!grepl("No current injuries to report.", html_text(x))){
    x %>%
      html_nodes(xpath = '//comment()') %>%    # select comment nodes
      html_text() %>%    # extract comment text
      paste(collapse = '') %>%    # collapse to a single string
      read_html() %>%    # reparse to HTML
      html_node('#injuries') %>%
      html_table() %>%
      as.data.frame() -> z1
    
    z <- z[z$Player %ni% z1$Player[grepl("Out For Season", z1$Description)],]
  }
  
  # playoff minutes transformation
  z <- subset(z, z$MP > 250)
  z$minz <- z$MP / z$G
  z <- z[order(-z$minz),]
  z <- z[1:10,]
  
  # Step 1: Logistic transformation to exaggerate gaps
  logistic <- function(x) 1 / (1 + exp(-0.25 * (x - median(z$minz))))
  z$logit_weight <- logistic(z$minz)
  
  # Step 2: Initial scaling to sum to 240
  z$minz_scaled <- z$logit_weight / sum(z$logit_weight) * 48*5
  
  # Step 3: Iteratively cap at 40 and redistribute until everyone is ≤ 40
  repeat{
    
    if(all(z$minz_scaled <= 48) & sum(z$minz_scaled) == 240){
      break
    }
    
    over_48 <- z$minz_scaled > 48
    under_48 <- z$minz_scaled < 48
    
    if(sum(over_48) > 0){
      z$minz_scaled[!over_48] <- z$minz_scaled[!over_48] + 
        z$minz_scaled[!over_48] / sum(z$minz_scaled[!over_48]) * (sum(z$minz_scaled[over_48])-48*sum(over_48))
      z$minz_scaled[over_48] <- 48
    }
    
    if(all(!over_48)){
      z$minz_scaled[under_48] <- z$minz_scaled[under_48] / sum(z$minz_scaled[under_48]) * 
        (240 - sum(z$minz_scaled[z$minz_scaled == 48]))
    }
    
    if(all(!over_48) & sum(over_48) == 0){
      z$minz_scaled <- z$minz_scaled / sum(z$minz_scaled) * 48*5
      break
    }
    
  }
  
  # Final playoff minutes
  z$minz <- z$minz_scaled
  z <- z[,-30:-31]
  
  # team name
  z$team = linkz[i]
  gsub("/teams/", "", z$team) -> z$team
  gsub("/2025.html", "", z$team) -> z$team
  
  # store info, report progress, wait
  y[[length(y)+1]] <- z
  cat(i, "out of", length(linkz), "\r")
  Sys.sleep(5)
}
y <- as.data.frame(do.call(rbind, y))

### Productivity Statistics
y$PERz <- y$PER
y$WS.48z <- y$`WS/48`
y$BPMz <- y$BPM
loopz <- (1:ncol(y))[grepl("PERz|WS.48z|BPMz", colnames(y))]
for(i in loopz){
  y[,i][is.na(y[,i])] <- mean(y[,i], na.rm = TRUE)
  y[,i] <- (y[,i] - mean(y[,i])) / sd(y[,i])
}
y$av <- rowMeans(y[,min(loopz):max(loopz)])
z <- aggregate(av*minz ~ team, y, sum)
z1 <- aggregate(minz ~ team, y, sum)
z[,2] <- z[,2] / z1[,2]
colnames(z) <- c("team", "rating")
z$rating <- (z$rating - mean(z$rating)) / sd(z$rating)

### seeding
x <- data.frame(
  team = c("SAC", "DAL", "GSW", "MEM", "OKC", "DEN", "LAC", "LAL", "MIN", "HOU",
           "CHI", "MIA", "ORL", "ATL", "CLE", "IND", "MIL", "NYK", "DET", "BOS"),
  conf = c(rep("West", 10), rep("East", 10)),
  seed = rep(c(9:10, 7:8, 1, 4:5, 3, 6, 2), 2)
)
z <- as.data.frame(cbind(z, x[match(z$team, x$team), 2:3]))
x <- z[!is.na(z$conf),]
row.names(x) <- 1:nrow(x)

### results
results <- list()
for(i in c("West", "East")){
  if(x$rating[x$conf == i & x$seed == 7] - x$rating[x$conf == i & x$seed == 8] > 0){
    win_78 <- x$team[x$conf == i & x$seed == 7]
    lose_78 <- x$team[x$conf == i & x$seed == 8]
    results[[length(results)+1]] <- paste0(x$team[x$conf == i & x$seed == 7], 
                                           " defeats ", 
                                           x$team[x$conf == i & x$seed == 8],
                                           " in the Play-In Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_78 <- x$team[x$conf == i & x$seed == 8]
    lose_78 <- x$team[x$conf == i & x$seed == 7]
    results[[length(results)+1]] <- paste0(x$team[x$conf == i & x$seed == 8], 
                                           " defeats ", 
                                           x$team[x$conf == i & x$seed == 7],
                                           " in the Play-In Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$conf == i & x$seed == 9] - x$rating[x$conf == i & x$seed == 10] > 0){
    win_910 <- x$team[x$conf == i & x$seed == 9]
    results[[length(results)+1]] <- paste0(x$team[x$conf == i & x$seed == 9], 
                                           " defeats ", 
                                           x$team[x$conf == i & x$seed == 10],
                                           " in the Play-In Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_910 <- x$team[x$conf == i & x$seed == 10]
    results[[length(results)+1]] <- paste0(x$team[x$conf == i & x$seed == 10], 
                                           " defeats ", 
                                           x$team[x$conf == i & x$seed == 9],
                                           " in the Play-In Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$team == win_910] - x$rating[x$team == lose_78] > 0){
    win_89 <- x$team[x$team == win_910]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_910], 
                                           " defeats ", 
                                           x$team[x$team == lose_78],
                                           " in the Play-In Round 2 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_89 <- x$team[x$team == lose_78]
    results[[length(results)+1]] <- paste0(x$team[x$team == lose_78], 
                                           " defeats ", 
                                           x$team[x$team == win_910],
                                           " in the Play-In Round 2 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$seed == 1 & x$conf == i] - x$rating[x$team == win_89] > 0){
    
    win_18 <- x$team[x$seed == 1 & x$conf == i]
    results[[length(results)+1]] <- paste0(x$team[x$seed == 1 & x$conf == i], 
                                           " defeats ", 
                                           x$team[x$team == win_89],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_18 <- x$team[x$team == win_89]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_89], 
                                           " defeats ", 
                                           x$team[x$seed == 1 & x$conf == i],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$seed == 4 & x$conf == i] - x$rating[x$seed == 5 & x$conf == i] > 0){
    
    win_45 <- x$team[x$seed == 4 & x$conf == i]
    results[[length(results)+1]] <- paste0(x$team[x$seed == 4 & x$conf == i], 
                                           " defeats ", 
                                           x$team[x$seed == 5 & x$conf == i],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_45 <- x$team[x$seed == 5 & x$conf == i]
    results[[length(results)+1]] <- paste0(x$team[x$seed == 5 & x$conf == i], 
                                           " defeats ", 
                                           x$team[x$seed == 4 & x$conf == i],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$seed == 3 & x$conf == i] - x$rating[x$seed == 6 & x$conf == i] > 0){
    
    win_36 <- x$team[x$seed == 3 & x$conf == i]
    results[[length(results)+1]] <- paste0(x$team[x$seed == 3 & x$conf == i], 
                                           " defeats ", 
                                           x$team[x$seed == 6 & x$conf == i],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_36 <- x$team[x$seed == 6 & x$conf == i]
    results[[length(results)+1]] <- paste0(x$team[x$seed == 6 & x$conf == i], 
                                           " defeats ", 
                                           x$team[x$seed == 3 & x$conf == i],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$seed == 2 & x$conf == i] - x$rating[x$team == win_78] > 0){
    
    win_27 <- x$team[x$seed == 2 & x$conf == i]
    results[[length(results)+1]] <- paste0(x$team[x$seed == 2 & x$conf == i], 
                                           " defeats ", 
                                           x$team[x$team == win_78],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_27 <- x$team[x$team == win_78]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_78], 
                                           " defeats ", 
                                           x$team[x$seed == 2 & x$conf == i],
                                           " in Round 1 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$team == win_18] - x$rating[x$team == win_45] > 0){
    win_14 <- x$team[x$team == win_18]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_18], 
                                           " defeats ", 
                                           x$team[x$team == win_45],
                                           " in Round 2 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_14 <- x$team[x$team == win_45]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_45], 
                                           " defeats ", 
                                           x$team[x$team == win_18],
                                           " in Round 2 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$team == win_27] - x$rating[x$team == win_36] > 0){
    win_23 <- x$team[x$team == win_27]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_27], 
                                           " defeats ", 
                                           x$team[x$team == win_36],
                                           " in Round 2 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_23 <- x$team[x$team == win_36]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_36], 
                                           " defeats ", 
                                           x$team[x$team == win_27],
                                           " in Round 2 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$rating[x$team == win_14] - x$rating[x$team == win_23] > 0){
    win_12 <- x$team[x$team == win_14]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_14], 
                                           " defeats ", 
                                           x$team[x$team == win_23],
                                           " in Round 3 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }else{
    win_12 <- x$team[x$team == win_23]
    results[[length(results)+1]] <- paste0(x$team[x$team == win_23], 
                                           " defeats ", 
                                           x$team[x$team == win_14],
                                           " in Round 3 of the ",
                                           unique(x$conf[x$conf == i]), "ern Conference")
  }
  
  if(x$conf[x$team == win_12] == "West"){
    win_west <- win_12
  }else{
    win_east <- win_12
  }
}
if(x$rating[x$team == win_west] - x$rating[x$team == win_east] > 0){
  win <- x$team[x$team == win_west]
  results[[length(results)+1]] <- paste0(x$team[x$team == win_west], 
                                         " defeats ", 
                                         x$team[x$team == win_east],
                                         " in the NBA Finals")
}else{
  win <- x$team[x$team == win_east]
  results[[length(results)+1]] <- paste0(x$team[x$team == win_east], 
                                         " defeats ", 
                                         x$team[x$team == win_west],
                                         " in the NBA Finals")
}
unlist(results)
