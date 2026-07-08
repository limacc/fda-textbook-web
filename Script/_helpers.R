suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(tidyr)
  library(stringr)
  library(tibble)
  library(broom)
  library(car)
  if (requireNamespace("sandwich", quietly = TRUE)) library(sandwich)
  library(patchwork)
  library(scales)
  library(knitr)
  library(kableExtra)
  library(flextable)
  library(officer)
})

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
  for (pat in names(review_label_map)) out <- gsub(pat, review_label_map[[pat]], out, fixed = TRUE)
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
  if (inherits(p, "ggplot")) {
    p <- p + ggplot2::labs(title = NULL, subtitle = NULL, caption = NULL) +
      ggplot2::theme(
        plot.title = ggplot2::element_blank(),
        plot.subtitle = ggplot2::element_blank(),
        plot.caption = ggplot2::element_blank()
      )
  }
  p
}

ft_style <- function(ft, num_j = NULL, center_j = NULL, bold_j1 = FALSE, hline_before = NULL) {
  thin  <- officer::fp_border(color = "black", width = 0.5)
  thick <- officer::fp_border(color = "black", width = 1.5)
  ft <- review_clean_flextable(ft)
  ft <- ft %>%
    flextable::font(fontname = "Cambria", part = "all") %>%
    flextable::fontsize(size = 8, part = "body") %>%
    flextable::fontsize(size = 8, part = "header") %>%
    flextable::bold(part = "header") %>%
    flextable::border_remove() %>%
    flextable::hline_top(part = "header", border = thick) %>%
    flextable::hline_bottom(part = "header", border = thin) %>%
    flextable::hline_bottom(part = "body", border = thick) %>%
    flextable::padding(padding.top = 2, padding.bottom = 2, padding.left = 4, padding.right = 4, part = "all") %>%
    flextable::align(align = "left", part = "all") %>%
    flextable::set_table_properties(layout = "fixed", width = 1)
  n_cols <- length(ft$col_keys)
  if (n_cols > 0) ft <- flextable::width(ft, j = ft$col_keys, width = 6.7 / n_cols)
  ft <- flextable::height_all(ft, height = 0.16, part = "all")
  if (!is.null(num_j))    ft <- flextable::align(ft, j = num_j, align = "right", part = "all")
  if (!is.null(center_j)) ft <- flextable::align(ft, j = center_j, align = "center", part = "all")
  if (isTRUE(bold_j1))    ft <- flextable::bold(ft, j = 1, bold = TRUE, part = "body")
  if (!is.null(hline_before)) for (i in hline_before) ft <- flextable::hline(ft, i = i - 1, border = thin, part = "body")
  ft
}

# ---------------------------------------------------------------
# ft_book(): 한글 교재용 표 스타일 (★ 본문 챕터는 반드시 이것을 사용)
# ft_style()은 review_translate()로 한글 라벨을 영어로 바꾸므로
# 한글 교재 본문에 사용 금지. ft_book()은 라벨을 보존한다.
# ---------------------------------------------------------------
ft_book <- function(ft, num_j = NULL, center_j = NULL, bold_j1 = FALSE, hline_before = NULL) {
  thin  <- officer::fp_border(color = "black", width = 0.5)
  thick <- officer::fp_border(color = "black", width = 1.5)
  ft <- ft %>%
    flextable::fontsize(size = 10, part = "all") %>%
    flextable::bold(part = "header") %>%
    flextable::border_remove() %>%
    flextable::hline_top(part = "header", border = thick) %>%
    flextable::hline_bottom(part = "header", border = thin) %>%
    flextable::hline_bottom(part = "body", border = thick) %>%
    flextable::padding(padding.top = 2, padding.bottom = 2,
                       padding.left = 4, padding.right = 4, part = "all") %>%
    flextable::align(align = "left", part = "all") %>%
    flextable::set_table_properties(layout = "fixed", width = 1)
  n_cols <- length(ft$col_keys)
  if (n_cols > 0) ft <- flextable::width(ft, j = ft$col_keys, width = 6.7 / n_cols)
  if (!is.null(num_j))    ft <- flextable::align(ft, j = num_j, align = "right", part = "all")
  if (!is.null(center_j)) ft <- flextable::align(ft, j = center_j, align = "center", part = "all")
  if (isTRUE(bold_j1))    ft <- flextable::bold(ft, j = 1, bold = TRUE, part = "body")
  if (!is.null(hline_before)) for (i in hline_before) ft <- flextable::hline(ft, i = i - 1, border = thin, part = "body")
  ft
}

# ---------------------------------------------------------------
# theme_book(): 교재 그림 표준 테마 (CQI-013)
# - 한글 축/라벨 폰트 명시 (디바이스 폴백으로 한글 라벨이 사라지는 사고 방지)
# - 그림 자체에 테두리 내장 (사령관 표본 형식 — 수작업 불필요)
# ---------------------------------------------------------------
book_base_family <- function() {
  # CQI-020: 폰트는 디바이스를 따라간다.
  # knitr 렌더(ragg/png)에서는 한글 폰트 지정이 필요하지만,
  # 학생이 Rscript로 단독 실행하면 기본 pdf 디바이스라 "Malgun Gothic"이
  # '유효하지 않은 폰트타입' 오류를 던진다. 렌더 중일 때만 지정한다.
  in_knitr <- isTRUE(getOption("knitr.in.progress"))
  if (.Platform$OS.type == "windows" && in_knitr) {
    try(grDevices::windowsFonts(`Malgun Gothic` = grDevices::windowsFont("맑은 고딕")), silent = TRUE)
    return("Malgun Gothic")
  }
  ""   # 디바이스 기본 폰트 (단독 실행 시 오류 없음)
}

theme_book <- function(base_size = 11) {
  fam <- book_base_family()
  ggplot2::theme_minimal(base_size = base_size, base_family = fam) +
    ggplot2::theme(
      text = ggplot2::element_text(family = fam),
      plot.background = ggplot2::element_rect(color = "grey35", fill = "white", linewidth = 0.7),
      plot.margin = ggplot2::margin(10, 12, 10, 12),
      panel.grid.minor = ggplot2::element_blank()
    )
}

book_script_dir <- function() normalizePath(getwd(), winslash = "/", mustWork = FALSE)
book_root_dir <- function() normalizePath(file.path(book_script_dir(), ".."), winslash = "/", mustWork = FALSE)
book_data_root <- function() {
  env <- Sys.getenv("BOOK_DATA_ROOT", unset = "")
  if (nzchar(env)) return(normalizePath(env, winslash = "/", mustWork = FALSE))
  normalizePath(file.path(book_root_dir(), "..", "..", "In_class_R"), winslash = "/", mustWork = FALSE)
}
book_ssot_data <- function() {
  env <- Sys.getenv("BOOK_SSOT_DATA", unset = "")
  if (nzchar(env)) return(normalizePath(env, winslash = "/", mustWork = FALSE))
  normalizePath(file.path(book_data_root(), "Derived_SSOT_Dataset.csv"), winslash = "/", mustWork = FALSE)
}
book_week_dir <- function(week) normalizePath(file.path(book_data_root(), paste0(week, "주차")), winslash = "/", mustWork = FALSE)
book_week_backup <- function(week) normalizePath(file.path(book_week_dir(week), "Backup"), winslash = "/", mustWork = FALSE)
read_week_csv <- function(week, filename, ...) readr::read_csv(file.path(book_week_backup(week), filename), show_col_types = FALSE, name_repair = "unique_quiet", ...)
read_book_csv <- function(path, ...) readr::read_csv(path, show_col_types = FALSE, name_repair = "unique_quiet", ...)

# ---------------------------------------------------------------
# 웹트랙 — 출력 프로파일 감지 및 통합 표 함수 (PRD_WEBTRACK_v1 §1)
# ---------------------------------------------------------------
book_is_web <- function() {
  fmt <- tryCatch(knitr::opts_knit$get("rmarkdown.pandoc.to"), error = function(e) NULL)
  isTRUE(fmt %in% c("html")) && isTRUE(getOption("BOOK_WEB", FALSE))
}

book_table <- function(df, caption, ...) {
  if (book_is_web()) {
    if (!requireNamespace("gt", quietly = TRUE)) return(knitr::kable(df, caption = caption))
    gt::tab_header(gt::gt(df), title = caption)
  } else {
    ft_book(flextable::set_caption(flextable::flextable(df), caption = caption), ...)
  }
}
