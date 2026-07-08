## Work/_common.R  — Universal helper file (paper + book)
## Source this from qmd files as: source("../Work/_common.R")
## Quarto runs knitr with cwd = qmd/ so paths are relative to qmd/.
##
## Behavior is selected by MODE in Work/paper_config.R.

suppressPackageStartupMessages({
  library(dplyr)
  library(knitr)
  library(kableExtra)
  library(flextable)
  library(officer)
})

# Book 모드: 챕터들이 사용하는 추가 패키지 자동 로드 (paper 모드는 영향 없음)
.book_extra_pkgs <- c("readr", "ggplot2", "tidyr", "stringr", "tibble",
                      "broom", "car", "patchwork", "scales")
for (.pkg in .book_extra_pkgs) {
  if (requireNamespace(.pkg, quietly = TRUE)) {
    suppressPackageStartupMessages(library(.pkg, character.only = TRUE))
  }
}
rm(.book_extra_pkgs, .pkg)

# ---------------------------------------------------------------------------
# Reviewer-facing output guards
# ---------------------------------------------------------------------------
# Tables and figures used for external review must not leak Korean labels from
# source CSVs or from intermediate teaching data. The map below is intentionally
# conservative: it translates recurring data labels while leaving firm names and
# free-form prose untouched.
review_label_map <- c(
  "상장폐지" = "Delisted",
  "정상" = "Normal",
  "주의" = "Watch",
  "경계" = "Alert",
  "심각" = "Severe",
  "위험관리군" = "Risk monitoring group",
  "대기업 (Large Cap)" = "Large cap",
  "중견기업 (Mid Cap)" = "Mid cap",
  "중소기업 (Small Cap)" = "Small cap",
  "등급없음" = "Unrated",
  "미공개" = "Not disclosed",
  "미분류" = "Unclassified",
  "자진상폐" = "Voluntary delisting",
  "보고서미제출" = "Non-submission of periodic report",
  "보고서 미제출" = "Non-submission of periodic report",
  "부도" = "Default",
  "부도기업" = "Default firms",
  "비부도기업" = "Non-default firms",
  "실질심사" = "Listing eligibility review",
  "코스닥" = "KOSDAQ",
  "유가증권" = "KOSPI",
  "완전자회사" = "Wholly owned subsidiary",
  "공개매수" = "Tender offer",
  "흡수합병" = "Merger absorption",
  "상장폐지기업" = "Delisted firms",
  "비평가 기업" = "Non-rated firms",
  "ESG 평가 기업" = "ESG-rated firms",
  "평가 기업" = "Rated firms",
  "원시" = "Raw",
  "정제 후" = "Cleaned",
  "정제 전" = "Before cleaning",
  "변환 전" = "Before transformation",
  "변환 후" = "After transformation",
  "유의함" = "Significant",
  "유의하지 않음" = "Not significant",
  "모형" = "Model",
  "변수" = "Variable",
  "변수명" = "Variable",
  "평균" = "Mean",
  "중앙값" = "Median",
  "표준편차" = "SD",
  "관측치" = "N",
  "그룹" = "Group",
  "구분" = "Group",
  "시점" = "Timing",
  "단계" = "Stage",
  "내용" = "Content",
  "정의" = "Definition",
  "통과 기준" = "Pass criterion",
  "점검 항목" = "Check item",
  "분야" = "Field",
  "장" = "Chapter",
  "산출 파일 (예시)" = "Output file (example)",
  "데이터 유형" = "Data type",
  "제목" = "Title",
  "포함 내용 (1~3개 항목)" = "Content (one to three items)",
  "슬라이드 #" = "Slide #",
  "수준" = "Level",
  "이 장의 통과 행동" = "Passing action",
  "나쁜 예" = "Poor practice",
  "좋은 예" = "Better practice",
  "원칙" = "Principle"
)

review_translate <- function(x) {
  if (!is.character(x)) return(x)
  out <- x
  for (pat in names(review_label_map)) {
    out <- gsub(pat, review_label_map[[pat]], out, fixed = TRUE)
  }
  out
}

review_clean_df <- function(df) {
  if (!is.data.frame(df)) return(df)
  names(df) <- review_translate(names(df))
  df[] <- lapply(df, review_translate)
  df
}

review_clean_flextable <- function(ft) {
  if (!inherits(ft, "flextable")) return(ft)
  if (!is.null(ft$body$dataset)) ft$body$dataset <- review_clean_df(ft$body$dataset)
  if (!is.null(ft$header$dataset)) ft$header$dataset <- review_clean_df(ft$header$dataset)
  ft
}

docx_plot <- function(p) {
  # Figure captions belong outside the bitmap. This removes plot-internal
  # titles/subtitles/captions even when an upstream chunk accidentally sets them.
  if (inherits(p, "ggplot")) {
    p <- p +
      ggplot2::labs(title = NULL, subtitle = NULL, caption = NULL) +
      ggplot2::theme(
        plot.title = ggplot2::element_blank(),
        plot.subtitle = ggplot2::element_blank(),
        plot.caption = ggplot2::element_blank()
      )
  }
  p
}


# ---------------------------------------------------------------------------
# Load project config (defines MODE + per-mode constants)
# ---------------------------------------------------------------------------
# 환경변수에 BOOK_DATA_ROOT가 있으면 우선 사용 (render.R이 미리 설정한 절대 경로)
.env_book_data_root <- Sys.getenv("BOOK_DATA_ROOT", unset = "")

# paper_config.R 위치 — qmd/ 또는 QMD_WORK/ 어디서 source되든 작동
.config_candidates <- c(
  "../Work/paper_config.R",   # cwd = qmd/
  "Work/paper_config.R",      # cwd = QMD_WORK/
  "paper_config.R"            # cwd = Work/
)
.config_path <- NA_character_
for (.cand in .config_candidates) {
  .full <- tryCatch(
    normalizePath(.cand, winslash = "/", mustWork = TRUE),
    error = function(e) NA_character_
  )
  if (!is.na(.full)) { .config_path <- .full; break }
}

if (!is.na(.config_path)) {
  source(.config_path, local = FALSE)
  # 환경변수가 우선 — paper_config.R이 잘못 평가됐을 가능성 차단
  if (nzchar(.env_book_data_root) && exists("MODE") && MODE == "book") {
    BOOK_DATA_ROOT <- .env_book_data_root
  }
} else {
  warning("paper_config.R not found; defaulting to MODE='paper'")
  MODE <- "paper"
}

# ---------------------------------------------------------------------------
# Journal-style flextable formatter (used in BOTH paper and book mode)
# ---------------------------------------------------------------------------
ft_style <- function(ft,
                     num_j       = NULL,
                     center_j    = NULL,
                     bold_j1     = FALSE,
                     hline_before = NULL) {
  thin  <- fp_border(color = "black", width = 0.5)
  thick <- fp_border(color = "black", width = 1.5)

  ft <- review_clean_flextable(ft)

  ft <- ft %>%
    font(fontname = "Cambria", part = "all") %>%
    fontsize(size = 8, part = "body") %>%
    fontsize(size = 8, part = "header") %>%
    bold(part = "header") %>%
    border_remove() %>%
    hline_top(part = "header", border = thick) %>%
    hline_bottom(part = "header", border = thin) %>%
    hline_bottom(part = "body",   border = thick) %>%
    padding(padding.top    = 2, padding.bottom = 2,
            padding.left   = 4, padding.right  = 4,
            part = "all") %>%
    align(align = "left", part = "all") %>%
    set_table_properties(layout = "fixed", width = 1)

  n_cols <- length(ft$col_keys)
  if (n_cols > 0) {
    ft <- width(ft, j = ft$col_keys, width = 6.7 / n_cols)
  }
  ft <- height_all(ft, height = 0.16, part = "all")

  if (!is.null(num_j))       ft <- align(ft, j = num_j,    align = "right",  part = "all")
  if (!is.null(center_j))    ft <- align(ft, j = center_j, align = "center", part = "all")
  if (isTRUE(bold_j1))       ft <- bold(ft, j = 1, bold = TRUE, part = "body")
  if (!is.null(hline_before)) {
    for (i in hline_before)
      ft <- hline(ft, i = i - 1, border = thin, part = "body")
  }
  ft
}

# ---------------------------------------------------------------------------
# Mode-specific path resolution
# ---------------------------------------------------------------------------
hn_file <- normalizePath("../Work/headline_numbers.yml", winslash = "/", mustWork = FALSE)

if (MODE == "paper") {

  # Paper mode: paths from paper_config.R (TBL_DIR, FIG_DIR)
  tbl_dir <- normalizePath(TBL_DIR, winslash = "/", mustWork = FALSE)
  fig_dir <- normalizePath(FIG_DIR, winslash = "/", mustWork = FALSE)

} else if (MODE == "book") {

  # Book mode: data root from paper_config.R (BOOK_DATA_ROOT)
  tbl_dir <- normalizePath(BOOK_DATA_ROOT, winslash = "/", mustWork = FALSE)
  fig_dir <- normalizePath(BOOK_DATA_ROOT, winslash = "/", mustWork = FALSE)

  # Convenience: locate week-specific Backup/ folder
  book_week_dir <- function(week) {
    dir <- file.path(BOOK_DATA_ROOT, paste0(week, "주차"))
    normalizePath(dir, winslash = "/", mustWork = FALSE)
  }
  book_week_backup <- function(week) {
    dir <- file.path(book_week_dir(week), "Backup")
    normalizePath(dir, winslash = "/", mustWork = FALSE)
  }
  book_derived_csv <- function() {
    normalizePath(BOOK_DERIVED_CSV, winslash = "/", mustWork = FALSE)
  }

} else {
  stop("_common.R: unknown MODE: ", MODE)
}

# ---------------------------------------------------------------------------
# Helper: read a CSV from tbl_dir (paper) or arbitrary path (book)
# ---------------------------------------------------------------------------
read_t <- function(name) {
  path <- file.path(tbl_dir, name)
  if (!file.exists(path)) {
    warning("Table file not found: ", path)
    return(data.frame(Note = paste("File not found:", name)))
  }
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

# Book-mode convenience: read CSV from any week's Backup/ folder
read_week_csv <- function(week, filename) {
  path <- file.path(book_week_backup(week), filename)
  if (!file.exists(path)) {
    warning("Week ", week, " CSV not found: ", path)
    return(data.frame(Note = paste("File not found:", filename)))
  }
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

# ---------------------------------------------------------------------------
# Helper: format numeric columns to specified digits
# ---------------------------------------------------------------------------
fmt_num_cols <- function(df, digits = 3) {
  df %>% mutate(across(where(is.numeric), ~ formatC(.x, format = "f", digits = digits)))
}

# ---------------------------------------------------------------------------
# Helper: read CSV and kable it
# ---------------------------------------------------------------------------
kable_csv <- function(file, caption, longtable = FALSE, digits = 3) {
  df <- read_t(file)
  knitr::kable(
    review_clean_df(fmt_num_cols(df, digits)),
    booktabs  = TRUE,
    longtable = longtable,
    caption   = caption
  )
}

# ---------------------------------------------------------------------------
# Headline numbers (used by both modes; book may use sparingly)
# ---------------------------------------------------------------------------
hn <- list()
if (file.exists(hn_file)) {
  hn <- yaml::yaml.load_file(hn_file)
}

# ---------------------------------------------------------------------------
# Paper-mode pre-loaded tables (skipped in book mode)
# ---------------------------------------------------------------------------
if (MODE == "paper") {

  .step_en <- c(
    "1. Raw firm-year rows (Input)"                       = "1. Raw firm-year observations (input)",
    "2. Analysis window 2011-2024"                        = "2. Analysis window 2011-2024",
    "3. With embezzlement disclosure variable"            = "3. With embezzlement disclosure variable",
    "4. First-ever disclosure firms"                      = "4. First-ever disclosure events",
    "5. Daily event data firms (with stock prices)"       = "5. Event firms with daily returns",
    "6. Regression sample (complete controls)"            = "6. Complete-controls regression sample"
  )

  tbl_sample <- if (file.exists(file.path(tbl_dir, "T1_sample_selection_enhanced.csv"))) {
    t <- read_t("T1_sample_selection_enhanced.csv")
    t$step <- ifelse(t$step %in% names(.step_en), .step_en[t$step], t$step)
    t
  } else NULL

  tbl_desc      <- if (file.exists(file.path(tbl_dir, "T2_descriptive_stats.csv")))   read_t("T2_descriptive_stats.csv")   else NULL
  tbl_corr      <- if (file.exists(file.path(tbl_dir, "T3_correlations.csv")))         read_t("T3_correlations.csv")         else NULL
  tbl_main      <- if (file.exists(file.path(tbl_dir, "T4_firmyear_enhanced.csv")))   read_t("T4_firmyear_enhanced.csv")   else NULL
  tbl_firth     <- if (file.exists(file.path(tbl_dir, "T4b_firth_logit.csv")))        read_t("T4b_firth_logit.csv")        else NULL
  tbl_car       <- if (file.exists(file.path(tbl_dir, "T5_event_study_CAR_with_stats.csv"))) read_t("T5_event_study_CAR_with_stats.csv") else NULL
  tbl_pretrend  <- if (file.exists(file.path(tbl_dir, "T5b_pre_event_trend.csv")))    read_t("T5b_pre_event_trend.csv")    else NULL
  tbl_sector    <- if (file.exists(file.path(tbl_dir, "T_sector_coverage.csv")))          read_t("T_sector_coverage.csv")          else NULL
  tbl_match_bal <- if (file.exists(file.path(tbl_dir, "T_matching_balance.csv")))         read_t("T_matching_balance.csv")         else NULL
  tbl_match_car <- if (file.exists(file.path(tbl_dir, "T_matched_CAR.csv")))              read_t("T_matched_CAR.csv")              else NULL
  tbl_illiq     <- if (file.exists(file.path(tbl_dir, "T_illiquidity_volatility.csv")))   read_t("T_illiquidity_volatility.csv")   else NULL
  tbl_selloss   <- if (file.exists(file.path(tbl_dir, "T_selection_loss_extended.csv")))  read_t("T_selection_loss_extended.csv")  else NULL

  tbl_placebo   <- if (file.exists(file.path(tbl_dir, "R8_placebo_CAR_full.csv")))    read_t("R8_placebo_CAR_full.csv")    else NULL
  tbl_delta_car <- if (file.exists(file.path(tbl_dir, "R8_delta_CAR.csv")))           read_t("R8_delta_CAR.csv")           else NULL
  tbl_size_het  <- if (file.exists(file.path(tbl_dir, "R7_size_heterogeneity.csv")))  read_t("R7_size_heterogeneity.csv")  else NULL
  tbl_log_ret   <- if (file.exists(file.path(tbl_dir, "R2_log_returns.csv")))         read_t("R2_log_returns.csv")         else NULL
  tbl_subwin    <- if (file.exists(file.path(tbl_dir, "R5_sub_window_analysis.csv"))) read_t("R5_sub_window_analysis.csv") else NULL
  tbl_match_rob <- if (file.exists(file.path(tbl_dir, "T_matching_balance.csv")))     read_t("T_matching_balance.csv")     else NULL

}
# In book mode, each chapter qmd loads its own week-specific data via:
#   df <- read_week_csv(5, "derived_variables.csv")
#   or sources its R script directly via:
#   source(file.path(book_week_dir(5), "Week5_Script.R"))
