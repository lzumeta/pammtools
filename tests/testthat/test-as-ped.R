context("Test as_ped functions")

test_that("Trafo works and attributes are appended", {
  # preparations
  data("tumor")
  tumor <- tumor[c(1:3, 135:137), ]
  ped <- as_ped(
    data    = tumor,
    formula = Surv(days, status)~ complications + age,
    cut     = c(0, 100, 400))
  # retransform to ped
  expect_data_frame(ped, nrow = 12L, ncols = 8L)
  expect_is(ped, "ped")
  expect_subset(c("ped_status", "tstart", "tend", "interval", "offset"),
                names(ped))
  expect_is(attr(ped, "breaks"), "numeric")
  expect_is(attr(ped, "intvars"), "character")
  expect_is(attr(ped, "id_var"), "character")
  expect_equal(attr(ped, "id_var"), "id")
  expect_equal(is.ped(ped), TRUE)
  
  ped <- as_ped(
    data = tumor,
    formula = Surv(days, status)~ complications + age)
  expect_data_frame(ped, nrows = 11L, ncols = 8L)
  
  
})

test_that("Trafo works for list objects (with TDCs)", {
  data("patient")
  event_df  <- filter(patient, CombinedID %in% c(1110, 1116))
  ped <- as_ped(data = list(event_df), formula = Surv(survhosp, PatientDied)~ .,
                cut = 0:30, id = "CombinedID")
  expect_data_frame(ped, nrows = 40, ncols = 15)
  tdc_df    <- filter(daily, CombinedID  %in% c(1110, 1116))
  ## check nesting
  expect_error(as_ped(
    data    = list(event_df, tdc_df),
    formula = Surv(survhosp, PatientDied) ~ .,
    cut     = 0:30,
    id  = "CombinedID"))
  ped <- as_ped(
    data    = list(event_df, tdc_df),
    formula = Surv(survhosp, PatientDied) ~ . +
      cumulative(survhosp, Study_Day, caloriesPercentage, tz_var = "Study_Day") +
      cumulative(proteinGproKG, tz_var = "Study_Day"),
    cut     = 0:30,
    id  = "CombinedID")
  expect_subset("survhosp_Study_Day_mat", colnames(ped))
  expect_data_frame(ped, nrows = 40L, ncols = 20L)
  expect_identical(any(is.na(ped$caloriesPercentage_Study_Day)), FALSE)
  expect_identical(colnames(ped$Study_Day), paste0("Study_Day", 1:12))
  ped <- as_ped(
    data    = list(event_df, tdc_df),
    formula = Surv(survhosp, PatientDied) ~ . +
      cumulative(Study_Day, caloriesPercentage, tz_var = "Study_Day") +
      cumulative(proteinGproKG, tz_var = "Study_Day"),
    id  = "CombinedID")
  expect_data_frame(ped, nrows = 2L, ncols = 19L)
  
})


test_that("Trafo works for left truncated data", {
  
  mort2 <- mort %>% group_by(id) %>% slice(1) %>% filter(id %in% c(1:3))
  mort_ped <- as_ped(Surv(tstart, exit, event) ~ ses, data = mort2)
  expect_data_frame(mort_ped, nrows = 8L, ncols = 7L)
  expect_identical(round(mort_ped$tstart, 2), c(0.00, 3.48, 13.46, 17.56, 3.48, 13.46, 0.00, 3.48))
  expect_identical(round(mort_ped$tend, 2), c(3.48, 13.46, 17.56, 20.00, 13.46, 17.56, 3.48, 13.46))
  expect_identical(round(mort_ped$offset, 2), c(1.25, 2.30, 1.41, 0.89, 2.30, 1.41, 1.25, 2.30))
  expect_identical(mort_ped$ped_status, c(rep(0, 5), 1, 0, 0))
  expect_identical(mort_ped$ses, factor(rep(c("upper", "lower", "upper"), times = c(4,2,2))))
  
})


test_that("Trafo works for recurrent events data", {
  
  test_df <- data.frame(
    id     = c(1,1, 2,2,2),
    tstart = c(0, .5, 0, .8, 1.2),
    tstop  = c(.5, 3, .8, 1.2, 3),
    status = c(1, 0, 1, 1, 0),
    enum   = c(1, 2, 1, 2, 3),
    age    = c(50, 50, 24, 24, 24))
  # GAP timescale
  gap_df <- as_ped(
    data       = test_df,
    formula    = Surv(tstart, tstop, status)~ enum + age,
    transition = "enum",
    id         = "id",
    timescale  = "gap")
  
  expect_data_frame(gap_df, nrows = 9L, ncols = 8L)
  expect_identical(
    round(gap_df$tstart, 1),
    c(0.0, 0.4, 0.0, 0.4, 0.5, 0.0, 0.4, 0.5, 0.0))
  expect_identical(
    round(gap_df$tend, 1),
    c(0.4, 0.5, 0.4, 0.5, 0.8, 0.4, 0.5, 0.8, 0.4))
  expect_identical(
    gap_df$ped_status,
    c(0, 1, 0, 0, 1, 0, 0, 0, 1)
  )
  expect_identical(
    gap_df$enum,
    rep(c(1, 2), times = c(5, 4))
  )
  
  ## CALENDAR timescale
  cal_df <- as_ped(
    data       = test_df,
    formula    = Surv(tstart, tstop, status)~ age,
    id         = "id",
    transition = "enum",
    timescale  = "calendar")
  
  expect_data_frame(cal_df, nrows = 6L, ncols = 8L)
  expect_identical(
    round(cal_df$tstart, 1),
    c(0.0, 0.0, 0.5, 0.5, 0.8, 0.8))
  expect_identical(
    round(cal_df$tend, 1),
    c(0.5, 0.5, 0.8, 0.8, 1.2, 1.2))
  expect_identical(
    cal_df$ped_status,
    c(1, 0, 1, 0, 0, 1)
  )
  expect_identical(
    cal_df$enum,
    rep(c(1, 2), each = 3)
  )
  
})

test_that("Trafo works for recurrent events data and concurrent effects of TDCs", {
  
  test_event_df <- data.frame(
    id     = c(1,1,1, 2,2),
    tstart = c(0, 100, 250, 0, 300),
    tstop  = c(100, 250, 600, 300, 750),
    status = c(1, 1, 1, 1, 0),
    enum   = c(1, 2, 3, 1, 2))
  
  test_tdc_df <- data.frame(id  = rep(c(1, 2), times = c(7, 8)),
                            tz  = c(0, seq(100, 600, by = 100),
                                    0, seq(100, 700, by = 100)),
                            ztz = c(0, 5, 4, 6, 3, 8, 7,
                                    0, 3, 4, 4.5, 5, 6, 3, 4))
  
  test_df <- list(test_event_df, test_tdc_df)
  
  # GAP timescale
  gap_df <- as_ped(
    data       = test_df,
    formula    = Surv(tstart, tstop, status) ~ enum + concurrent(ztz, tz_var = "tz"),
    transition = "enum",
    id         = "id",
    timescale  = "gap")
  
  expect_data_frame(gap_df, nrows = 17L, ncols = 9L)
  expect_identical(
    round(gap_df$tstart, 1),
    c(0, 0, 100, 200, 250, 0, 100, 0, 100, 200, 250, 
      300, 0, 100, 200, 250, 300))
  expect_identical(
    round(gap_df$tend, 1),
    c(100, 100, 200, 250, 300, 100, 200, 100, 200, 250,
      300, 400, 100, 200, 250, 300, 400))
  expect_identical(
    gap_df$ped_status,
    c(1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
  )
  expect_identical(
    gap_df$enum,
    rep(c(1, 2, 3), times = c(5, 7, 5))
  )
  expect_identical(
    gap_df$tend_aux,
    c(100, 100, 200, 250, 300, 200, 300, 400, 500, 550, 
      600, 700, 400, 500, 550, 600, 700)
  )
  
  ## CALENDAR timescale
  cal_df <- as_ped(
    data       = test_df,
    formula    = Surv(tstart, tstop, status) ~ enum + concurrent(ztz, tz_var = "tz"),
    id         = "id",
    transition = "enum",
    timescale  = "calendar")
  
  expect_data_frame(cal_df, nrows = 14L, ncols = 9L)
  expect_identical(
    round(cal_df$tstart, 1),
    c(0, 0, 100, 200, 250, 100, 200, 300, 400, 500, 
      250, 300, 400, 500))
  expect_identical(
    round(cal_df$tend, 1),
    c(100, 100, 200, 250, 300, 200, 250, 400, 500, 
      600, 300, 400, 500, 600))
  expect_identical(
    cal_df$ped_status,
    c(1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1)
  )
  expect_identical(
    cal_df$enum,
    rep(c(1, 2, 3), times = c(5, 5, 4))
  )
  expect_identical(
    cal_df$tend_aux,
    c(100, 100, 200, 250, 300, 200, 250, 400, 500,
      600, 300, 400, 500, 600)
  )
  
})

test_that("Trafo works for recurrent events data and cumulative effects of TDCs", {
  
  test_event_df <- data.frame(
    id     = c(1,1,1, 2,2),
    tstart = c(0, 100, 250, 0, 300),
    tstop  = c(100, 250, 600, 300, 750),
    status = c(1, 1, 1, 1, 0),
    enum   = c(1, 2, 3, 1, 2))
  
  test_tdc_df <- data.frame(id  = rep(c(1, 2), times = c(7, 8)),
                            tz  = c(0, seq(100, 600, by = 100),
                                    0, seq(100, 700, by = 100)),
                            ztz = c(0, 5, 4, 6, 3, 8, 7,
                                    0, 3, 4, 4.5, 5, 6, 3, 4))
  
  test_df <- list(test_event_df, test_tdc_df)
  test_formula <- as.formula(
    Surv(tstart, tstop, status) ~ enum + cumulative(latency(tz), ztz, tz_var = "tz", 
                                                    ll_fun = function(t, tz) t >= tz)
  )
  
  # GAP timescale
  gap_df <- as_ped(
    data       = test_df,
    formula    = test_formula,
    transition = "enum",
    id         = "id",
    timescale  = "gap")
  
  expect_data_frame(gap_df, nrows = 14L, ncols = 10L)
  expect_identical(
    round(gap_df$tstart, 1),
    c(0, 0, 100, 250, 0, 100, 0, 100, 250, 300, 0, 100, 250, 300))
  expect_identical(
    round(gap_df$tend, 1),
    c(100, 100, 250, 300, 100, 250, 100, 250, 300, 600, 100, 250, 300, 600))
  expect_identical(
    gap_df$ped_status,
    c(1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1)
  )
  expect_identical(
    gap_df$enum,
    rep(c(1, 2, 3), times = c(4, 6, 4))
  )
  
  expect_subset("ztz", colnames(gap_df))
  expect_identical(colnames(gap_df$ztz), paste0("ztz", 1:8))
  expect_matrix(gap_df$ztz, nrows = 14, ncols = 8)
  expect_matrix(gap_df$tz_latency, nrows = 14, ncols = 8)
  expect_matrix(gap_df$LL, nrows = 14, ncols = 8)
  
  ## CALENDAR timescale
  cal_df <- as_ped(
    data       = test_df,
    formula    = test_formula,
    id         = "id",
    transition = "enum",
    timescale  = "calendar")
  
  expect_data_frame(cal_df, nrows = 8L, ncols = 10L)
  expect_identical(
    round(cal_df$tstart, 1),
    c(0, 0, 100, 250, 100, 300, 250, 300))
  expect_identical(
    round(cal_df$tend, 1),
    c(100, 100, 250, 300, 250, 600, 300, 600))
  expect_identical(
    cal_df$ped_status,
    c(1, 0, 0, 1, 1, 0, 0, 1)
  )
  expect_identical(
    cal_df$enum,
    rep(c(1, 2, 3), times = c(4, 2, 2))
  )
  
  expect_subset("ztz", colnames(cal_df))
  expect_identical(colnames(cal_df$ztz), paste0("ztz", 1:8))
  expect_matrix(cal_df$ztz, nrows = 8, ncols = 8)
  expect_matrix(cal_df$tz_latency, nrows = 8, ncols = 8)
  expect_matrix(cal_df$LL, nrows = 8, ncols = 8)
  
})

test_that("Trafo for recurrent events aborts when all obs. in the last spell are censored", {
  
  test_event_df <- data.frame(
    id     = c(1,1,1,1, 2,2),
    tstart = c(0, 100, 250, 300, 0, 300),
    tstop  = c(100, 250, 300, 600, 300, 750),
    status = c(1, 1, 1, 0, 1, 0),
    enum   = c(1, 2, 3, 4, 1, 2))
  test_tdc_df <- data.frame(id  = rep(c(1, 2), times = c(7, 8)),
                            tz  = c(0, seq(100, 600, by = 100),
                                    0, seq(100, 700, by = 100)),
                            ztz = c(0, 5, 4, 6, 3, 8, 7,
                                    0, 3, 4, 4.5, 5, 6, 3, 4))
  test_df <- list(test_event_df, test_tdc_df)
  
  expect_error(as_ped(
    data       = test_df,
    formula    = Surv(tstart, tstop, status) ~ enum + concurrent(ztz, tz_var = "tz"),
    transition = "enum",
    id         = "id",
    timescale  = "gap"), "are censored")         
})