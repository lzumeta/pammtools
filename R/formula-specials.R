#' Formula specials for defining  time-dependent covariates
#'
#' So far, two specials are implemented. \code{concurrent} is used when
#' the goal is to estimate a concurrent effect of the TDC. \code{cumulative}
#' is used when the goal is to estimate a cumulative effect of the TDC. These
#' should usually not be called directly but rather as part of the \code{formula}
#' argument to \code{as_ped}.
#' See the \href{https://adibender.github.io/pammtools//articles/data-transformation.html}{vignette on data transformation}
#' for details.
#'
#'
#' @rdname specials
#' @importFrom purrr map
#'
#' @param ... For \code{concurrent} variables that will be transformed to
#' covariate matrices. The number of columns of each covariate depends on \code{tz}.
#' Usually, elements that will be specified here are \code{time} (which should be
#' the name of the time-variable used on the LHS of the formula argument to
#' \code{as_ped}), \code{tz} which is the variable containing information on
#' the times at which the TDC was observed (can be wrapped in \code{latency}) and
#' the TDCs that share the same \code{tz} and Lag-lead window (\code{ll_fun}).
#' @param tz_var The name of the variable that stores information on the
#' times at which the TDCs specified in this term where observed.
#' @param lag a single positive number giving the time lag between for
#' a concurrent effect to occur (i.e., the TDC at time of exposure \code{t-lag}
#' affects the hazard in the interval containing follow-up time \code{t}).
#' Defaults to 0.
#'
#' @inheritParams get_laglead
#'
#' @export
#' @keywords internal
cumulative <- function(...,
                       tz_var,
                       ll_fun = function(t, tz) t >= tz,
                       suffix = NULL) {
  
  vars        <- as.list(substitute(list(...)))[-1]
  vars_chr    <- vars %>% map(~as.character(.))
  lgl_latency <- map_lgl(vars_chr, ~any(. %in% "latency"))
  
  if (any(lgl_latency)) {
    latency_var <- unlist(vars_chr)[unlist(vars_chr) != "latency"][lgl_latency]
    col_vars    <- unlist(vars_chr)[unlist(vars_chr) != "latency"]
  } else {
    latency_var <- ""
    col_vars    <- unlist(vars_chr)
  }
  
  list(
    col_vars    = col_vars,
    latency_var = latency_var,
    tz_var      = tz_var,
    suffix      = suffix,
    ll_fun      = ll_fun)
  
}


#' @rdname specials
#' @inherit cumulative
#' @keywords internal
concurrent <- function(...,
                       tz_var,
                       lag = 0,
                       suffix = NULL) {
  
  assert_number(lag, lower = 0)
  ll_fun = function(t, tz) {t > tz + lag}  ## Question: t >= tz + lag?
  vars     <- as.list(substitute(list(...)))[-1]
  vars_chr <- vars %>% map(~as.character(.)) %>% unlist()
  
  
  list(
    col_vars    = vars_chr,
    tz_var      = tz_var,
    suffix      = suffix,
    ll_fun      = ll_fun,
    lag         = lag)
  
}



#' Expand time-dependent covariates to functionals
#'
#' Given formula specification on how time-dependent covariates affect the
#' outcome, creates respective functional covariate as well as auxiliary
#' matrices for time/latency etc.
#'
#' @param data Data frame (or similar) in which variables specified in ...
#' will be looked for
#' @param formula  A formula containing \code{cumulative} specials,
#' that specify the type of cumulative effect one wants to estimate. For details
#' see the vignettes on data transformation and time-dependent covariates.
#' @importFrom purrr flatten map
#' @importFrom stats terms
#' @keywords internal
get_cumulative <- function(data, formula, ped, timescale = NULL) {
  
  stopifnot(has_tdc_form(formula))
  
  func_list <- eval_special(get_tdc_form(formula, data = data), data = data)
  
  n_func <- length(func_list)
  ll_funs <- map(func_list, ~.x[["ll_fun"]])
  tz_vars <- map(func_list, ~.x[["tz_var"]])
  tz <- map(tz_vars, ~pull(data, .x) %>% unlist() %>% unique() %>% sort())
  
  names(tz) <- names(tz_vars) <- names(ll_funs) <- tz_vars
  
  ## create matrices
  func_mats <- map(func_list,
                   ~ expand_cumulative(data = data, ., n_func = n_func,
                                       ped = ped, timescale = timescale)) %>%
    flatten()
  
  list(
    func_list = func_list,
    func_mats = func_mats,
    ll_funs   = ll_funs,
    tz_vars   = tz_vars,
    tz        = tz)
  
}

#' @keywords internal
eval_special <- function(formula, special="cumulative", data = NULL) {
  
  tf  <- terms(formula, specials = special, data = data)
  ind_special <- attr(tf, "specials")[[special]]
  # extract components
  if (!is.null(ind_special)) {
    terms_vec <- attr(tf, "term.labels")
    map(terms_vec, ~eval(expr = parse(text = .x)))
  } else {
    NULL
  }
  
}


#' @rdname specials
#' @inheritParams as_ped
#' @param special The name of the special whose existence in the
#' \code{formula} should be checked
#' @keywords internal
has_special <- function(formula, special = "cumulative") {
  
  has_tdc_form(formula, tdc_specials = special)
  
}

#' @rdname get_cumulative
#' @inheritParams get_cumulative
#' @param func Single evaluated \code{\link{cumulative}} term.
#' @importFrom purrr map invoke_map
#' @keywords internal
expand_cumulative <- function(data, func, n_func, ped, timescale) {
  
  col_vars <- func$col_vars
  tz_var   <- func$tz_var
  tz       <- pull(data, tz_var) %>% unlist() %>% unique() %>% sort()
  time_var <- attr(data, "time_var")
  id_var   <- attr(data, "id_var")
  lgl_var_in_data <- map_lgl(col_vars, ~ . %in% colnames(data))
  if (!all(lgl_var_in_data)) {
    stop(paste0("The following variables provided to 'formula' are not contained
      in 'data': ", col_vars[!lgl_var_in_data]))
  }
  ncols_vars <- get_ncols(data, col_vars[!(col_vars == time_var)])
  if (!all(diff(ncols_vars) == 0)) {
    stop(paste0(
      "The following variables have unequal maximum number of elements per ",
      id_var, ": ", paste0(col_vars[!(col_vars == time_var)], sep = "; ")))
  } else {
    nz <- ncols_vars[1]
  }
  
  # create list of matrices for covariates/time matrices provided in func
  hist_mats <- list()
  for (i in seq_along(col_vars)) {
    hist_mats[[i]] <- if (col_vars[i] == attr(data, "time_var")) {
      make_time_mat(data, nz)
    } else if (col_vars[i] == func$latency_var) {
      make_latency_mat(data, tz, timescale)
    } else {
      make_z_mat(data, col_vars[i], nz, ped, timescale)
    }
  }
  
  if (any(c(time_var, tz_var) %in% col_vars)) {
    hist_mats <- c(hist_mats, list(make_lag_lead_mat(data, tz, func$ll_fun, timescale)))
    names(hist_mats) <- make_mat_names(c(col_vars, "LL"), func$latency_var,
                                       tz_var, func$suffix, n_func)
    time_mat_ind <- grepl(time_var, names(hist_mats))
    names(hist_mats)[time_mat_ind] <- paste0(names(hist_mats)[time_mat_ind],
                                             "_mat")
  } else {
    names(hist_mats) <- make_mat_names(col_vars, func$latency_var, tz_var,
                                       func$suffix, n_func)
  }
  
  hist_mats
  
}

#' Extract information on concurrent effects
#'
#' @keywords internal
#' @param x A suitable object from which variables contained in
#' \code{formula} can be extracted.
#' @param ... Further arguments passed to methods.
prep_concurrent <- function(x, formula, ...) {
  UseMethod("prep_concurrent", x)
}

#' @rdname prep_concurrent
#' @inherit prep_concurrent
#' @keywords internal
prep_concurrent.list <- function(x, formula, ...) {
  
  lgl_concurrent <- has_special(formula, "concurrent")
  
  if (lgl_concurrent) {
    ccr_list    <- eval_special(formula, special = "concurrent", x[[2]])
    ccr_tz_vars <- map_chr(ccr_list, ~.x[["tz_var"]]) %>% unique()
    ccr_time    <- map2(ccr_tz_vars, x, ~get_tz(.y, .x)) %>%
      keep(~ !is.null(.x)) %>%
      map2(ccr_list,
           ~ if(is.null(.x)) {
             .x
           } else {
             ifelse(.x == min(.x), .x, .x + .y$lag)
           }) %>%
      # leave time origin unchanged by lag
      # should just start modeling the hazard at t = lag?!?
      reduce(union) %>% sort()
  }
  
  list(
    ccr_list = ccr_list,
    ccr_time = ccr_time)
  
}


#' @keywords internal
get_tz <- function(data, tz_var) {
  if (tz_var %in% colnames(data)) {
    tz <- pull(data, tz_var) %>% unique()
  } else {
    tz <- NULL
  }
  tz
}

#' @keywords internal
#' @importFrom purrr map2
#' @importFrom tidyselect all_of
add_concurrent <- function(ped, data, id_var, ...) {
  
  ccr <- attr(data, "ccr")
  
  dots <- list(...)
  if (any(dots$transition %in% names(ped))) {
    
    if(dots$timescale == "gap") {
      ## create an auxiliary 'tend_aux' column, a not resetted copy of 'tend'
      tend_aux_df <- ped %>% 
        group_by(.data[[id_var]]) %>% 
        mutate(tend_aux = lag(.data$tend, default = 0)) %>% 
        ungroup() %>% 
        group_by(.data[[id_var]], .data[[dots$transition]]) %>%
        mutate(tend_aux = first(.data$tend_aux)) %>%
        ungroup() %>% 
        select(all_of(c(id_var, dots$transition)), "tend_aux") %>% 
        unique() %>%
        group_by(.data[[id_var]]) %>% 
        mutate(tend_aux = cumsum(.data$tend_aux)) %>% 
        ungroup()
      
      ped <- left_join(ped, tend_aux_df, by = c(id_var, dots$transition)) %>% 
        mutate(tend_aux = .data$tend + .data$tend_aux)
      
    } else {  ## if calendar
      ped <- mutate(ped, tend_aux = .data$tend)
    }
    ped_split <- split(ped$tend_aux, f = list(ped[[id_var]], ped[[dots$transition]]), 
                       drop = TRUE)
  } else {
    ped_split <- split(ped$tend, f = ped[[id_var]])
  }
  
  for (ccr_i in ccr[["ccr_list"]]) {
    tdc_vars_i <- ccr_i[["col_vars"]]
    tz_var_i   <- ccr_i[["tz_var"]]
    ccr_vars_i <- c(tz_var_i, tdc_vars_i)
    if (any(dots$transition %in% names(ped))) {
      ccr_i_df   <- data %>%
        select(one_of(c(id_var, dots$transition, ccr_vars_i))) %>% 
        unnest(cols = -one_of(id_var))
      ccr_i_df_split <- split(ccr_i_df, 
                              f = list(ccr_i_df[[id_var]], 
                                       ccr_i_df[[dots$transition]]), drop = TRUE)
    } else {
      ccr_i_df   <- data %>%
        select(one_of(c(id_var, ccr_vars_i))) %>% 
        unnest(cols = -one_of(id_var))
      
      ccr_i_df_split <- split(ccr_i_df, f = ccr_i_df[[id_var]])
    }
    
    li <- map2(ped_split, ccr_i_df_split,
               function(.x, .y) {
                 ll_ind <- rowSums(outer(.x, .y[[tz_var_i]], ccr_i$ll_fun))
                 .y[ll_ind, tdc_vars_i]
               }) %>% bind_rows() %>% as.data.frame()
    
    ## check that data contains baseline value
    if(nrow(ped) != nrow(li)) stop("Please, add baseline values to your data (i.e. TDC value at t = 0)")
    
    ped <- ped %>% bind_cols(li)
    # if (any(dots$transition %in% names(ped))) ped$tend_aux <- NULL
  }
  
  attr(ped, "ccr") <- ccr
  
  ped
  
  
}

#' @keywords internal
add_cumulative <- function(ped, data, formula, timescale) {
  
  func_components <- get_cumulative(data, formula, ped, timescale)
  func_matrices <- func_components$func_mats
  
  ## check that all individuals share same tz pattern
  tz_vars <- func_components$tz_vars ## a list
  id_var <- attr(ped, "id_var")
  has_common_tzset <- sapply(tz_vars, function(tz_var) 
    eval_common_tzset(data, id_var, tz_var))
  if (!all(has_common_tzset)) {
    stop("TDC values should be recorded at same tz times for all individuals") 
    ## if this error not fixed there will be problems with matrix dimensions
  }
  
  for (i in seq_along(func_matrices)) {
    ped[[names(func_matrices)[i]]] <- func_matrices[[i]]
  }
  attr(ped, "func")           <- func_components$func_list
  attr(ped, "ll_funs")        <- func_components$ll_funs
  attr(ped, "tz")             <- func_components$tz
  attr(ped, "tz_vars")        <- func_components$tz_vars
  
  ped
  
}

#' @keywords internal
#' @importFrom purrr map
#' @importFrom tibble is_tibble
eval_common_tzset <- function(data, id_var, tz_var) {
  tz_vectors <- data %>% 
    split(data[[id_var]])
  if (is_tibble(tz_vectors[[1]][[tz_var]][[1]])) {
    tz_vectors <- sapply(tz_vectors, function(elem) as.vector(elem[[tz_var]][[1]]))
  } else {
    tz_vectors <- lapply(tz_vectors, function(elem) elem[[tz_var]][[1]])
  }
  
  idx <- which.max(lapply(tz_vectors, length))
  largest_tz_vector <- tz_vectors[[idx]]
  
  has_common_tzset <- map(.x = tz_vectors,
                          .f = function(x) all(x == largest_tz_vector[seq_along(x)])) %>% 
    reduce(c) %>% 
    all()
  
  return(has_common_tzset)
}

make_mat_names <- function(x, ...) {
  UseMethod("make_mat_names", x)
}

#' @keywords internal
make_mat_names.default <- function(
    col_vars,
    latency_var = NULL,
    tz_var      = NULL,
    suffix      = NULL,
    nfunc       = 1) {
  
  if (!is.null(suffix)) {
    return(paste(col_vars, suffix, sep = "_"))
  } else {
    if (!is.null(tz_var) & nfunc > 1)  {
      tz_ind <- col_vars == tz_var
      col_vars[!tz_ind] <- paste(col_vars[!tz_ind], tz_var,  sep = "_")
    }
    if (!is.null(latency_var)) {
      latency_ind <- col_vars == latency_var
      col_vars[latency_ind] <- paste(col_vars[latency_ind], "latency",
                                     sep = "_")
    }
  }
  
  return(col_vars)
  
}

#' @keywords internal
make_mat_names.list <- function(func_list, time_var) {
  hist_names <- map(func_list, ~ make_mat_names(c(.x[["col_vars"]], "LL"),
                                                .x[["latency_var"]], .x[["tz_var"]], .x[["suffix"]],
                                                nfunc = length(func_list)))
  
  time_mat_ind <- map(hist_names, ~grepl(time_var, .))
  for (i in seq_along(time_mat_ind)) {
    hist_names[[i]][time_mat_ind[[i]]] <-
      paste0(hist_names[[i]][time_mat_ind[[i]]], "_mat")
  }
  
  hist_names
  
}

#' Create matrix components for cumulative effects
#'
#' These functions are called internally by \code{\link{get_cumulative}} and
#' should usually not be called directly.
#' @rdname elra_matrix
#' @param data A data set (or similar) from which meta information on cut-points,
#' interval-specific time, covariates etc. can be obtained.
#'
#' @keywords internal
make_time_mat <- function(data, nz) {
  
  brks    <- attr(data, "breaks")
  id_tseq <- attr(data, "id_tseq")
  Tmat    <- matrix(brks[id_tseq], nrow = length(id_tseq), ncol = nz)
  Tmat
  
}

#' @rdname elra_matrix
#' @inherit make_time_mat
#' @keywords internal
make_latency_mat <- function(data, tz, timescale = NULL) {
  
  time        <- attr(data, "breaks")
  id_tseq     <- attr(data, "id_tseq")
  Latency_mat <- outer(time, tz, FUN = "-")
  Latency_mat[Latency_mat < 0] <- 0
  if (!is.null(timescale)) {
    if (timescale == "gap") {
      idx <- unique(id_tseq[id_tseq > nrow(Latency_mat)])
      l_idx <- length(idx)
      if (l_idx) {
        Latency_mat <- Latency_mat[c(1:nrow(Latency_mat), rep(nrow(Latency_mat), l_idx)),]
        Latency_mat[idx,] <- map(idx, function(i) lag(Latency_mat[i,], n = order(i), default = 0)) %>% 
          reduce(rbind)
      }
    }
  }
  Latency_mat[id_tseq, , drop = FALSE]
  
}

#' @rdname elra_matrix
#' @inherit make_time_mat
#' @keywords internal
make_lag_lead_mat <- function(
    data,
    tz,
    ll_fun = function(t, tz) t >= tz, 
    timescale = NULL) {
  
  LL    <- outer(attr(data, "breaks"), tz, FUN = ll_fun) * 1L
  delta <- abs(diff(tz))
  IW    <- matrix(c(mean(delta), delta), ncol = length(tz), nrow = nrow(LL),
                  byrow = TRUE)
  LL    <- LL * IW
  if (!is.null(timescale)) {
    if (timescale == "gap") {
      id_tseq <- attr(data, "id_tseq")
      idx <- unique(id_tseq[id_tseq > nrow(LL)])
      l_idx <- length(idx)
      if (l_idx) {
        LL <- LL[c(1:nrow(LL), rep(nrow(LL), l_idx)),]
        LL[idx,] <- map(idx, function(i) lag(LL[i,], n = order(i), default = 0)) %>% 
          reduce(rbind)
      }
    }
  }
  LL[attr(data, "id_tseq"), , drop = FALSE]
  
}

#' @rdname elra_matrix
#' @inherit make_time_mat
#' @param z_var Which should be transformed into functional covariate format
#' suitable to fit cumulative effects in \code{mgcv::gam}.
#' @importFrom purrr map map_int
#' @importFrom dplyr pull
#' @keywords internal
make_z_mat <- function(data, z_var, nz, ped = NULL, timescale = NULL) {
  
  tz_ind <- seq_len(nz)
  Z <- map(data[[z_var]], .f = ~ unlist(.x)[tz_ind])
  Z <- do.call(rbind, Z)
  colnames(Z) <- paste0(z_var, tz_ind)
  Z[is.na(Z)] <- 0
  if (is.null(timescale)) { 
    Z[attr(data, "id_tz_seq"), , drop = FALSE]
  } else {
    Z <- Z[attr(data, "id_tz_seq"), , drop = FALSE]
    id_var <- attr(data, "id_var")
    ## reorder as in ped data frame!
    posx_df <- data.frame(pos_p = order(ped[[id_var]]), pos_Z = 1:nrow(ped))
    posx_df <- posx_df[order(posx_df$pos_p),]
    Z[posx_df$pos_Z,]
  }
}

get_ncols <- function(data, col_vars) {
  
  map(col_vars, ~pull(data, .x) %>% map_int(function(z)
    ifelse(is.atomic(z), length(z), nrow(z)))) %>%
    map_int(max)
  
}
