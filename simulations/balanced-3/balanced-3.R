import::from(magrittr, `%>%`)
import::from(foreach, foreach, `%do%`, `%dopar%`)
library(ggplot2)

setwd('~/dev/manifold-block-models')
source('functions.R')

n.vec <- 2 ^ c(7, 8, 9, 10, 11)
# n.vec <- sort(n.vec, decreasing = TRUE)
nsamp.vec <- c(0, 4, 8)
iter <- 32

p.list <- list(matrix(c(0, 1, 0, 
                        0, 0, 1,
                        0, 0, 0),
                      nrow = 3, ncol = 3),
               matrix(c(0, 0, 0, 
                        0, 0, 1,
                        0, 1, 0),
                      nrow = 3, ncol = 3),
               matrix(c(0, 1, 0, 
                        0, 0, 1,
                        0, 1, 0),
                      nrow = 3, ncol = 3))

doMC::registerDoMC(parallel::detectCores() - 0)

setwd('simulations/balanced-3')

clustering.df <- foreach(nsamp = nsamp.vec, .combine = dplyr::bind_rows) %do% {
  reorder.mat <- gtools::permutations(2, 2)
  out.df <- foreach(n = n.vec, .combine = dplyr::bind_rows) %do% {
    print(paste('nsamp =', nsamp, ', n = ', n))
    if (paste0('balanced_n_', n, '_nsamp_', nsamp, '.csv') %in% dir()) {
      out <- readr::read_csv(paste0('balanced_n_', n, '_nsamp_', nsamp, '.csv'))
    } else {
      out <- foreach(i = seq(iter), .combine = dplyr::bind_rows, .errorhandling = 'remove') %dopar% {
        clustering <- simulate.and.compute.error(
          n, 
          p.list = p.list, 
          p.intercept = TRUE, 
          initialization = 'ground truth',
          ground.truth.sample = nsamp,
          maxit = 16
        )
        error.rate <- clustering$error
        loss <- clustering$loss
        p <- clustering$p
        error.count = error.rate * n
        dplyr::tibble(n = n,
                      nsamp = nsamp,
                      error.rate = error.rate,
                      error.count = error.count,
                      loss = loss,
                      p121 = p[[1]][2, 1],
                      p122 = p[[1]][2, 2],
                      p131 = p[[1]][3, 1],
                      p132 = p[[1]][3, 2],
                      p221 = p[[2]][2, 1],
                      p222 = p[[2]][2, 2],
                      p231 = p[[2]][3, 1],
                      p232 = p[[2]][3, 2],
                      p321 = p[[3]][2, 1],
                      p322 = p[[3]][2, 2],
                      p331 = p[[3]][3, 1],
                      p332 = p[[3]][3, 2])
      }
      readr::write_csv(out, paste0('balanced_n_', n, '_nsamp_', nsamp, '.csv'))
    }
    return(out)
  }
  gc()
  return(out.df)
}

gc()

readr::write_csv(clustering.df, 'balanced-3.csv')

clust.summary.df <- clustering.df %>% 
  dplyr::group_by(n, nsamp) %>% 
  dplyr::summarise(
    med.count = median(error.count),
    first.q.count = quantile(error.count, .25),
    third.q.count = quantile(error.count, .75),
    med.rate = median(error.rate),
    first.q.rate = quantile(error.rate, .25),
    third.q.rate = quantile(error.rate, .75)
  ) %>% 
  dplyr::ungroup()

ggplot(clust.summary.df) + 
  theme_bw() + 
  theme(text = element_text(size = 10)) + 
  scale_y_log10() +
  scale_x_log10(breaks = n.vec) +
  labs(y = 'community detection error rate',
       colour = NULL, shape = NULL) + 
  geom_line(aes(x = n, y = med.rate, colour = factor(nsamp))) + 
  geom_point(aes(x = n, y = med.rate, colour = factor(nsamp))) + 
  geom_errorbar(aes(x = n, 
                    ymin = first.q.rate, ymax = third.q.rate, 
                    colour = factor(nsamp))) + 
  scale_colour_brewer(palette = 'Set1')
