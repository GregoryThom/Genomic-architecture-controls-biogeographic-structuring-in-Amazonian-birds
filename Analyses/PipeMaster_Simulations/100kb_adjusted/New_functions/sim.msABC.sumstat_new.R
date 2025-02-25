sim.msABC.sumstat_new <- function (model, nsim.blocks, path = getwd(), use.alpha = F, 
          mu.rates = NULL, append.sims = F, block.size = 10, msABC.call = "/home/gthom/R/x86_64-pc-linux-gnu-library/3.6/PipeMaster/msABClinux", 
          output.name, ncores) 
{
  WD <- getwd()
  if (class(model) != "Model") {
    stop("First arguments should be an object of class Model generated by the main.menu() function.")
  }
  if (model$I[1, 1] == "genomic") {
    stop("You need to get the data structure first. See function get.data.structure")
  }
  setwd(path)
  locfile <- PipeMaster:::get.locfile(model)
  msABC.path <- find.package("PipeMaster")
  if (append.sims == F) {
    com <- msABC.commander_new(model, use.alpha = use.alpha, 
                                        arg = 1)
    write.table(locfile, paste(".", 1, "locfile.txt", sep = ""), 
                row.names = F, col.names = T, quote = F, sep = " ")
    options(warn = -1)
    x <- strsplit(system2(msABC.call, args = com[[1]], stdout = T, 
                          stderr = T, wait = T), "\t")
    options(warn = 0)
    nam <- x[1][[1]]
    cols <- grep("fwh", nam)
    cols <- c(cols, grep("thomson", nam))
    cols <- c(cols, grep("ZnS", nam))
    cols <- c(cols, grep("_FayWuH", nam))
    if (length(cols) != 0) 
      nam <- nam[-cols]
    nam <- c(com[[2]][1, ], "mean.rate", "sd.rate", nam)
    write.table(t(nam), file = paste("SIMS_", output.name, 
                                     ".txt", sep = ""), quote = F, row.names = F, col.names = F, 
                append = F, sep = "\t")
  }
  write(paste("arg <- commandArgs(TRUE)", "cat(paste(\"Core\",arg),sep=\"\\n\")", 
              "suppressMessages(library(PipeMaster))", "load(file=\".PM_objects.RData\")", 
              "res<-sim.func(arg)", "save(res,file=paste(\".\",arg,\"_SIMS.rda\",sep=\"\"))", 
              "write(1,\".log\",append=T,sep=\"\\n\")", "invisible(file.remove(paste(\".\",arg,\"locfile.txt\",sep=\"\")))", 
              "quit(save='no')", sep = "\n"), ".script_parallel.R")
  sim.func <- function(arg) {
    simulations <- NULL
    
    #I had to put this here again because IDK how to call a function inside a finction insde a finction
    msABC.commander_new <- function (model, use.alpha = use.alpha, arg) 
    {
      parameters <- vector()
      size.pars <- rbind(model$flags$n, model$flags$en$size)
      mig.pars <- rbind(model$flags$m, model$flags$em$size)
      time.pars <- rbind(model$flags$ej, model$flags$en$time, model$flags$em$time)
      reco.pars <- t(as.matrix(c("recomb", "-r", "1", "10", "20", "runif")))
      
      size.pars <- PipeMaster:::sample.w.cond(par.matrix = size.pars, 
                                              cond.matrix = model$conds$size.matrix)
      parameters <- rbind(parameters, size.pars[, c(1, 4)])
      
      reco.pars <- PipeMaster:::sample.pars(reco.pars)
      parameters <- rbind(parameters, reco.pars[, c(1, 4)])
      
      if (is.null(time.pars) == F) {
        time.pars <- PipeMaster:::sample.w.cond(par.matrix = time.pars, 
                                                cond.matrix = model$conds$time.matrix)
        parameters <- rbind(parameters, time.pars[, c(1, 4)])
      }
      loci <- model$loci
      if (is.null(mig.pars) == F) {
        mig.pars <- sample.w.cond(par.matrix = mig.pars, cond.matrix = model$conds$mig.matrix)
        parameters <- rbind(parameters, mig.pars[, c(1, 4)])
      }
      
      
      Ne0 <- 1e+05
      ms.scalar <- 4 * Ne0
      size.pars[, 4:5] <- as.numeric(size.pars[, 4])/Ne0
      time.pars[, 4:5] <- as.numeric(time.pars[, 4])/ms.scalar
      commands <- list(NULL, NULL)
      string <- ms.string.generator_new(model, size.pars, 
                                        mig.pars, time.pars, reco.pars, use.alpha = use.alpha, scalar = as.numeric(loci[1, 
                                                                                                                        3]))
      
      y <- paste(sum(as.numeric(model$I[1, 4:ncol(model$I)])), 
                 1, paste(model$I[1, 2:ncol(model$I)], collapse = " "), 
                 collapse = " ")
      loc.string <- paste("100 --frag-begin --finp .", arg, "locfile.txt --N ", 
                          Ne0, " --frag-end", sep = "")
      commands[[1]] <- paste(y, string, loc.string, collapse = " ")
      commands[[2]] <- t(parameters)
      return(commands)
    }
    
    #I had to put this here again because IDK how to call a function inside a finction insde a finction
    
    ms.string.generator_new <- function (model, size.pars, mig.pars, time.pars, reco.pars, use.alpha, scalar = 1) 
    {
      size.pars[, 4:5] <- as.numeric(size.pars[, 4]) * scalar
      mig.pars[, 4:5] <- as.numeric(mig.pars[, 4]) * scalar
      string <- list()
      curr.Ne <- subset(size.pars, size.pars[, 2] == "-n")
      ent <- subset(time.pars, time.pars[, 2] == "-en")
      en <- subset(size.pars, size.pars[, 2] == "-en")
      if (model$I[1, 3] != "1") {
        if (nrow(curr.Ne) == 1) {
          string[[1]] <- paste(curr.Ne[2:4], collapse = " ")
        }
        else {
          l <- apply(curr.Ne[, c(2:4)], 1, paste, collapse = " ")
          string[[1]] <- paste(l, collapse = " ")
        }
      }
      if (use.alpha[1] == T) {
        alpha <- NULL
        for (i in as.numeric(unique(en[, 3]))) {
          eg <- subset(size.pars, size.pars[, 3] == i)[1:2, 
                                                       ]
          eg <- rbind(eg, subset(ent, ent[, 3] == i))
          alpha <- c(alpha, paste("-g", i, -(1/as.numeric(eg[3, 
                                                             4])) * log(as.numeric(eg[2, 4])/as.numeric(eg[1, 
                                                                                                           4]))))
        }
        string[[2]] <- paste(alpha[use.alpha[2:length(use.alpha)]], 
                             collapse = " ")
      }
      if (nrow(en) != 0) {
        if (nrow(en) > 1) {
          n <- apply(cbind(ent[, c(2, 4)], en[, 3:4]), 1, paste, 
                     collapse = " ")
          string[[3]] <- paste(n, collapse = " ")
        }
        else {
          string[[3]] <- paste(c(ent[c(2, 4)], en[3:4]), collapse = " ")
        }
      }
      if (is.null(mig.pars) == F) {
        curr.mig <- subset(mig.pars, mig.pars[, 2] == "-m")
        for (i in 1:nrow(curr.mig)) {
          curr.mig[i, 3] <- strsplit(curr.mig[i, 3], " ")[[1]][1]
        }
        curr.mig[, 4] <- as.numeric(curr.mig[, 4])/as.numeric(curr.Ne[match(curr.mig[, 
                                                                                     3], curr.Ne[, 3]), 4])
        curr.mig[, 3] <- mig.pars[1:nrow(curr.mig), 3]
        m <- apply(curr.mig[, c(2:4)], 1, paste, collapse = " ")
        string[[4]] <- paste(m, collapse = " ")
        emt <- subset(time.pars, time.pars[, 2] == "-em")
        em <- subset(mig.pars, mig.pars[, 2] == "-em")
        if (nrow(em) != 0) {
          for (i in 1:nrow(emt)) {
            emt[i, 3] <- strsplit(emt[i, 3], " ")[[1]][1]
          }
          if (nrow(en) == 0) {
            em[, 4] <- as.numeric(em[, 4])/as.numeric(curr.Ne[match(emt[, 
                                                                        3], curr.Ne[, 3]), 4])
          }
          else {
            if (sum(as.numeric(em[, 4])) > 0) {
              for (j in 1:nrow(em)) {
                x <- which(ent[, 3] == emt[j, 3])
                if (length(x) == 0) {
                  em[j, 4] <- as.numeric(em[i, 4])/as.numeric(curr.Ne[match(emt[j, 
                                                                                3], curr.Ne[, 3]), 4])
                }
                else {
                  y <- which(as.numeric(ent[x, 4]) <= as.numeric(emt[j, 
                                                                     4]))
                  if (length(y) == 0) {
                    em[j, 4] <- as.numeric(em[j, 4])/as.numeric(curr.Ne[match(emt[j, 
                                                                                  3], curr.Ne[, 3]), 4])
                  }
                  else {
                    y <- which(as.numeric(ent[x, 4]) == max(as.numeric(ent[x[y], 
                                                                           4])))
                    em[j, 4] <- as.numeric(em[j, 4])/as.numeric(en[x[y], 
                                                                   4])
                  }
                }
              }
            }
          }
          m <- apply(cbind(emt[, c(2, 4)], em[, 3:4]), 1, paste, 
                     collapse = " ")
          string[[5]] <- paste(m, collapse = " ")
        }
      }
      if (is.null(time.pars) == F) {
        ej <- subset(time.pars, time.pars[, 2] == "-ej")
        if (nrow(ej) == 1) {
          string[[6]] <- paste(ej[c(2, 4, 3)], collapse = " ")
        }
        else {
          j <- apply(ej[, c(2, 4, 3)], 1, paste, collapse = " ")
          string[[6]] <- paste(j, collapse = " ")
        }
      }
      if (is.null(reco.pars) == F) {
        r <- subset(reco.pars, reco.pars[, 2] == "-r")
        if (nrow(r) == 1) {
          string[[7]] <- paste(r[c(2, 4)], collapse = " ")
        }
      }
      
      
      
      
      string <- paste(unlist(string), collapse = " ")
      return(string)
    }
    
    #begin code again
        for (i in 1:block.size) {
      if (!(is.null(mu.rates))) {
        rates <- do.call(mu.rates[[1]], args = mu.rates[2:length(mu.rates)])
        rates <- rep(rates, each = as.numeric(model$I[1, 
                                                      3]))
        rates <- list(rates, c(0, 0))
      } else {
        rates <- PipeMaster:::sample.mu.rates(model)
      }
      locfile[, 5] <- rates[[1]]
      write.table(locfile, paste(".", arg, "locfile.txt", 
                                 sep = ""), row.names = F, col.names = T, quote = F, 
                  sep = " ")
      com <- msABC.commander_new(model, use.alpha = use.alpha, 
                             arg = arg)
      options(warn = -1)
      sumstat <- read.table(text = system2(msABC.call, 
                                           args = com[[1]], stdout = T, stderr = T, wait = T), 
                            header = T, sep = "\t")
      #system(paste(msABC.call, " ", com[[1]], sep = ""))
      
      options(warn = 0)
      sumstat <- subset(sumstat, select = -c(X))
      cols <- grep("fwh", colnames(sumstat))
      cols <- c(cols, grep("thomson", colnames(sumstat)))
      cols <- c(cols, grep("ZnS", colnames(sumstat)))
      cols <- c(cols, grep("_FayWuH", colnames(sumstat)))
      if (length(cols) != 0) 
        sumstat <- sumstat[, -cols]
      param <- c(com[[2]][2, ], rates[[2]])
      names(param) <- c(com[[2]][1, ], "mean.rate", "sd.rate")
      simulations <- rbind(simulations, c(param, sumstat))
    }
    return(simulations)
  }
  parentls <- function() ls(envir = parent.frame())
  save(list = parentls(), file = ".PM_objects.RData")
  total.sims <- 0
  for (j in 1:nsim.blocks) {
    start.time <- Sys.time()
    write(0, ".log")
    for (c in 1:ncores) {
      system(paste("Rscript .script_parallel.R", c), wait = F)
    }
    l <- "0"
    while (sum(as.numeric(unlist(strsplit(l, "")))) < ncores) {
      Sys.sleep(5)
      l <- readLines(".log")
    }
    file.remove(".log")
    simulations <- NULL
    cat("Reading simulations from worker nodes", sep = "\n")
    for (c in 1:ncores) {
      load(file = paste(".", c, "_SIMS.rda", sep = ""))
      simulations <- rbind(simulations, res)
    }
    cat("Writing simulations to file", sep = "\n")
    write.table(simulations, file = paste("SIMS_", output.name, 
                                          ".txt", sep = ""), quote = F, row.names = F, col.names = F, 
                append = T, sep = "\t")
    cat("Removing old simulations", sep = "\n")
    for (t in 1:ncores) {
      file.remove(paste(".", t, "_SIMS.rda", sep = ""))
    }
    end.time <- Sys.time()
    total.sims <- total.sims + (block.size * ncores)
    cycle.time <- (as.numeric(end.time) - as.numeric(start.time))/60/60
    total.time <- cycle.time * nsim.blocks
    passed.time <- cycle.time * j
    remaining.time <- round(total.time - passed.time, 3)
    cat(paste("PipeMaster:: ", total.sims, " (~", round((block.size * 
                                                           ncores)/cycle.time), " sims/h) | ~", remaining.time, 
              " hours remaining", sep = ""), "\n")
  }
  setwd(WD)
}
