## Work/paper_config.R — Per-Project Configuration (paper OR book)
## ==========================================================================
## MODE SWITCH:
##   MODE <- "paper"   → SSCI single-author English paper (4 fixed qmd files)
##   MODE <- "book"    → Korean textbook (auto-discovered qmd/*.qmd, 1 combined docx)
##
## SELF-LOCATING: 이 파일은 source되는 cwd와 무관하게 자기 위치 기준으로
##                BOOK_DATA_ROOT 등 모든 경로를 절대 경로로 계산한다.
## ==========================================================================

MODE <- "book"   # ← THE switch.

# ---------------------------------------------------------------------------
# Self-locator — paper_config.R 자기 자신의 위치를 찾는다
# ---------------------------------------------------------------------------
.locate_paper_config <- function() {
  # source() 호출 스택에서 ofile 추출
  for (i in seq_along(sys.frames())) {
    ofile <- sys.frame(i)$ofile
    if (!is.null(ofile) && nzchar(ofile)) {
      ofile_norm <- tryCatch(
        normalizePath(ofile, winslash = "/", mustWork = FALSE),
        error = function(e) ofile
      )
      if (grepl("paper_config\\.R$", ofile_norm)) return(ofile_norm)
    }
  }
  # Fallback 1: cwd 기준 후보 경로
  for (cand in c("Work/paper_config.R",
                 "../Work/paper_config.R",
                 "paper_config.R")) {
    full <- tryCatch(
      normalizePath(cand, winslash = "/", mustWork = TRUE),
      error = function(e) NA_character_
    )
    if (!is.na(full)) return(full)
  }
  return(NA_character_)
}

.this_config <- .locate_paper_config()

# ---------------------------------------------------------------------------
# 절대 경로 계산 (cwd 무관)
# ---------------------------------------------------------------------------
if (!is.na(.this_config)) {
  .config_dir <- dirname(.this_config)         # …/QMD_WORK/Work
  .qmd_work   <- dirname(.config_dir)           # …/QMD_WORK
  .ai_sw      <- dirname(.qmd_work)              # …/AI_SW_Textbook
  .pbl_root   <- dirname(.ai_sw)                 # …/2026년 PBL
} else {
  # Ultimate fallback (warning)
  warning("paper_config.R: self-location 실패 — cwd 기준 상대경로 사용")
  .config_dir <- normalizePath("Work",        winslash = "/", mustWork = FALSE)
  .qmd_work   <- normalizePath(".",            winslash = "/", mustWork = FALSE)
  .ai_sw      <- normalizePath("..",           winslash = "/", mustWork = FALSE)
  .pbl_root   <- normalizePath("../..",        winslash = "/", mustWork = FALSE)
}

# ---------------------------------------------------------------------------
# Per-mode constants
# ---------------------------------------------------------------------------
if (MODE == "paper") {

  PAPER_TITLE    <- "Paper Title Here"
  PAPER_JOURNAL  <- "Target Journal Name Here"
  PAPER_DATE     <- format(Sys.Date(), "%Y-%m-%d")
  REPLICATION_PKG <- normalizePath(
    file.path(.qmd_work, "..", "Replication Package"),
    winslash = "/", mustWork = FALSE
  )
  TBL_DIR <- file.path(REPLICATION_PKG, "Output", "Table")
  FIG_DIR <- file.path(REPLICATION_PKG, "Output", "Figure")

} else if (MODE == "book") {

  BOOK_TITLE     <- "AI powered SW 기반 재무데이터분석"
  BOOK_AUTHOR    <- "임형주 (경기대학교)"
  BOOK_COURSE    <- "재무데이터분석론 (4학년)"
  BOOK_SEMESTER  <- "2026년 1학기"
  BOOK_CODE      <- "fda-textbook"
  BOOK_DATE      <- format(Sys.Date(), "%Y-%m-%d")

  # Self-located 절대 경로 — cwd 무관
  BOOK_DATA_ROOT <- normalizePath(
    file.path(.pbl_root, "In_class_R"),
    winslash = "/", mustWork = FALSE
  )
  BOOK_SSOT_DATA <- normalizePath(
    file.path(.pbl_root, "In_class_R", "11주차", "Derived_SSOT_Dataset.csv"),
    winslash = "/", mustWork = FALSE
  )
  BOOK_AUX_DATA_ROOT <- normalizePath(
    file.path(.pbl_root, "Data"),
    winslash = "/", mustWork = FALSE
  )

  TBL_DIR <- BOOK_AUX_DATA_ROOT
  FIG_DIR <- BOOK_AUX_DATA_ROOT

} else {
  stop("paper_config.R: MODE must be \"paper\" or \"book\". Got: ", MODE)
}

# ---------------------------------------------------------------------------
# Verification (interactive 또는 RENDER_MODE 미설정 시)
# ---------------------------------------------------------------------------
if (interactive() || !nzchar(Sys.getenv("RENDER_MODE"))) {
  cat("=== paper_config.R verification ===\n")
  cat("Self-located:", .this_config, "\n")
  cat("MODE:        ", MODE, "\n")

  if (MODE == "paper") {
    cat("Paper:       ", PAPER_TITLE,  "\n")
    cat("Journal:     ", PAPER_JOURNAL, "\n")
    cat("Replic. Pkg: ", normalizePath(REPLICATION_PKG, mustWork = FALSE), "\n")
  } else if (MODE == "book") {
    cat("Book:        ", BOOK_TITLE,    "\n")
    cat("Author:      ", BOOK_AUTHOR,   "\n")
    cat("Code:        ", BOOK_CODE,     "\n")
    cat("Data root:   ", BOOK_DATA_ROOT,
        if (dir.exists(BOOK_DATA_ROOT)) " ✓ EXISTS" else " ✗ NOT FOUND", "\n")
    cat("Sample path:",
        normalizePath(file.path(BOOK_DATA_ROOT, "11주차", "Derived_SSOT_Dataset.csv"),
                       winslash = "/", mustWork = FALSE),
        if (file.exists(file.path(BOOK_DATA_ROOT, "11주차", "Derived_SSOT_Dataset.csv")))
          " ✓ EXISTS" else " ✗ NOT FOUND", "\n")
  }
}
