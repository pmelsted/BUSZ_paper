get_scale <- function(scale){
  switch(
    scale,
    "MB" = 2**20,
    "GB" = 2**30,
  )
}

plot.compression <- function(df, scalex="GB", scaley=NULL){
  scalex <- toupper(scalex)
  if (is.null(scaley)) scaley <- scalex
  scalex_num <- get_scale(scalex)
  scaley_num <- get_scale(scaley)
  
  mapping <- aes(x=full_size / scalex_num, y=compressed / scaley_num, color=res_type)
  p <- ggplot(df, mapping) +
    labs(
      x=sprintf("File size [%s]", scalex),
      y=sprintf("Compressed size [%s]", scaley)
    )
  p
}

plot.ratio <- function(df, scalex="GB", scaley=NULL){
  scalex <- toupper(scalex)
  if (is.null(scaley)) scaley <- scalex
  scalex_num <- get_scale(scalex)
  scaley_num <- get_scale(scaley)

  mapping <- aes(x=full_size / scalex_num, y=ratio, color=res_type)
  p <- ggplot(df, mapping) + 
    labs(
      x=sprintf("File size [%s]", scalex),
      y="Compression ratio"
    )
  p
}

plot.compression.time <- function(df, scalex="GB", scaley=NULL){
  scalex <- toupper(scalex)
  if (is.null(scaley)) scaley <- scalex
  scalex_num <- get_scale(scalex)
  scaley_num <- get_scale(scaley)
  
  mapping <- aes(x=full_size / scalex_num, y=compression_t, color=res_type)
  p <- ggplot(df, mapping) + 
    labs(
    x=sprintf("File size [%s]", scalex),
    y="Compression time [s]"
  )
  p
}

plot.decompression.time <- function(df, scalex="GB", scaley=NULL){
  scalex <- toupper(scalex)
  if (is.null(scaley)) scaley <- scalex
  scalex_num <- get_scale(scalex)
  scaley_num <- get_scale(scaley)
  
  mapping <- aes(x=full_size / scalex_num, y=decompression_t, color=res_type)
  p <- ggplot(df, mapping) + 
    labs(
      x=sprintf("File size [%s]", scalex),
      y="Decompression time [s]"
    )
  p
}

plot.compression.speed <- function(df, scalex="MB", scaley=NULL){
  scalex <- toupper(scalex)
  if (is.null(scaley)) scaley <- scalex
  scalex_num <- get_scale(scalex)
  scaley_num <- get_scale(scaley)
  
  mapping <- aes(
    y = (full_size / scaley_num) / compression_t,
    x = full_size / scalex_num,
    color=res_type
  )
  
  points <- ggplot(df, mapping) + 
    labs(
    x=sprintf("File size [%s]", scalex),
    y=sprintf("Compression speed [%s/s]", scaley)
  )
  points
}

plot.decompression.speed <- function(df, scalex="MB", scaley=NULL){
  scalex <- toupper(scalex)
  if (is.null(scaley)) scaley <- scalex
  scalex_num <- get_scale(scalex)
  scaley_num <- get_scale(scaley)

  mapping <- aes(
    y = (full_size / scaley_num) / decompression_t,
    x = full_size / scalex_num,
    color=res_type
  )
  
  points <- ggplot(df, mapping) + 
    labs(
    x=sprintf("File size [%s]", scalex),
    y=sprintf("Decompression Speed [%s/s]", scaley)
  )
  points
}


plot.times <- function (df, scalex = NULL, scaley=NULL){
  mapping <- aes(x=compression_t, y=decompression_t, color=res_type)
  p <- ggplot(df, mapping) +
    labs(
      x='Compression time [s]',
      y='Decompression time [s]',
      title=""
    ) + 
    geom_abline(slope=1, intercept = 0)
  p
}

get_slopes <- function(fit, name, invert=FALSE, bus.to.X.ratio=FALSE) {
  df <- as.data.frame(coef(fit))
  if(invert) df <- 1/df
  row.names <- rownames(df)
  rownames(df) <- lapply(stringr::str_split(row.names, ":"), function(x) x[length(x)]) %>%
    cbind %>% stringr::str_remove("res_type")
  
  colnames(df) <- name
  if(bus.to.X.ratio){
    df[paste(name, "ratio", sep='.')] <- df["bus",name] / df[, name]
  }
  df
}


# Wrapper functino for consistent plotting
do.plot <- function(fun, df, ignore=NULL, ...){
  fun <- match.fun(fun)
  
  # Constants for plotting
  point.size <- 0.8
  axis.text.size <- 14
  axis.title.size <- 16
  alpha <- 0.7
  
  okabe.ord <- get.color.ord(ignore)
  res_types <- sort(unique(df$res_type))
  
  ss <- df
  if(! is.null(ignore)){
    ss <- subset(df, ! res_type %in% ignore)
  }
  
  legend.labels <- get.legend.labels(ss)
  
  p <- fun(ss, ...) + 
    geom_point(alpha=alpha, size=point.size) +
    scale_color_okabeito(order=okabe.ord, labels=legend.labels) +
    labs(color="Compression method") +
    theme(axis.text = element_text(size=axis.text.size),
          axis.title = element_text(size=axis.title.size))
  p 
}

get.color.ord <- function(ignore=NULL){
  names <- sort(c(
    "bus", "gzip1","gzip9", "zst01","zst03", "zst10", "zst19"
  ))
  okabe.ord <- c(6, 1, 2, 3, 7, 5, 4, 8, 9)
  if(!is.null(ignore)){
    idx <- which(names %in% ignore)
    okabe.ord <- okabe.ord[-idx]
  }
  okabe.ord
}

get.legend.labels <- function(df, ignore=NULL){
  if(is.null(ignore)) ignore <- ""

  legend.labels <- (df %>% filter(res_type!=ignore))$res_type %>% 
    unique() %>% 
    sort() %>%
    lapply(get.label.from.res_type)

  legend.labels
}


get.label.from.res_type <- function(lab){
  match <- stringr::str_extract(lab, "([a-zA-Z]+)(\\d*)", group=c(1,2))
  if(match[2] != ""){
    level <- as.integer(match[2])
    lab <- paste(match[1], level, sep=" -")
  } else if (stringr::str_starts(lab, "bus")){
    lab <- "BUStools"
  }
  lab
}

get_legend <- function(df, a.gplot){ 
  tmp <- ggplot_gtable(ggplot_build(a.gplot)) 
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box") 
  legend <- tmp$grobs[[leg]] 
  legend
}
