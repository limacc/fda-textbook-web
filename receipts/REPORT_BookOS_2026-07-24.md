# REPORT_BookOS_2026-07-24 — 웹교재 문구 수정 + 네비게이션 추가

> 작업경로: ~/workspace/fda-textbook-web (git clone)
> 목적: 과장된 인터랙티브 문구 수정 + 챕터간 네비게이션 추가
> HARD LAW: git push 금지 · .py/.sh는 ~/workspace 안에서만

## P0-①: 과장된 인터랙티브 문구 수정

**문제**: index.qmd "각 장의 R 코드를 브라우저에서 직접 실행하며 학습할 수 있습니다" — 실제로는 ch10만 webr 셀 4개, 나머지 12개 장은 정적.

**수정**: web/index.qmd
- "각 장의 R 코드를 브라우저에서 직접 실행" → "10장은 브라우저에서 R 코드 직접 실행 가능(WebR), 나머지 12개 장은 정적 렌더링" 명시
- 목차에서 ch10에 "**인터랙티브(WebR)**" 표시 추가
- "웹판 안내" 섹션 신설: 인터랙티브/정적 구분 + 데이터 경로 안내

## P0-②: 13개 챕터에 사이드바/이전-다음/인덱스 링크 추가

**문제**: 개별 파일 렌더링(`quarto render NN_web.qmd`)은 Quarto book 사이드바/prev-next를 생성하지 않음.

**수정**: Quarto book 프로젝트로 전환
- `web/_quarto.yml` 신규 작성 (표준 Quarto 프로젝트 파일명)
  - `project: type: book` + `book: chapters:` 배열 (index + 13장)
- `_quarto-live.yml` 제거 (중복)
- `quarto render --to live-html` (book 프로젝트 렌더) → `_book/` 디렉토리에 자동 사이드바 + prev/next 네비게이션 생성
- CI 워크플로우 수정: `for` 루프 개별 렌더 → `quarto render --to live-html` (book 프로젝트), `upload-pages-artifact path: web/_book`

**결과**: 
- 모든 페이지에 14개 사이드바 링크 (index + 13장)
- 모든 챕터에 prev/next 네비게이션 (`rel="prev"` / `rel="next"`)
- 사이드바 챕터 제목: YAML `title:` 필드에서 정확히 표시 (setup chunk 코멘트 노출 문제 해결)

**사이드바 제목 수정**: webify.ts YAML 출력에 `title:` 필드 추가. ch10_web.qmd, index.qmd에도 `title:` 수동 추가.

## P1-①: read_book_csv 미정의 오류 수정

**문제**: 학생이 본문의 `read_book_csv(ssot_path)` 코드를 webr 셀에 복붙 시 "could not find function 'read_book_csv'" 에러. `_helpers.R`은 knitr 환경에서만 로드됨.

**수정**: ch10_web.qmd에 webr-setup 청크 추가
```{webr}
#| context: setup
#| include: false
read_book_csv <- function(path, ...) { read.csv(path, check.names = FALSE, ...) }
ssot_path <- "data/ssot_web.csv"
f2/f3/f4/fcomma/sig_label/pp/winsorize 함수 정의
```
- `context: setup` 속성으로 webr 환경 전역에 함수 등록
- 본문 코드 복붙 시 read_book_csv, winsorize, sig_label 등 즉시 사용 가능

## P1-②: URL 스킴 불일치

**조사**: ch10만 `ch10_web.html`, 나머지는 `NN_web.html` — 파일명 패턴 불일치 확인. 하지만 모든 참조(index.qmd, _quarto.yml chapters 배열, 사이드바 링크, prev/next)가 일관되게 `ch10_web` 사용 중. 불일치로 인한 broken link 없음. 파일명 자체는 변경하지 않음 (ch10이 원본 배포 검증된 챕터이므로).

## 로컬 렌더 검증 (1라운드)

`quarto render --to live-html` 성공. `_book/` 디렉토리에 14개 HTML 생성.

AD-HOC VERIFICATION (not test suite) — ALL PASS:
- index: 31KB, 13/13 챕터 링크, 14 사이드바 링크
- 01~13_web: 76KB~164KB, 모두 14 사이드바 링크, prev/next 존재
- ch10: webr 셀 + read_book_csv webr setup 확인
- 사이드바 제목: "분석 환경과 재현성...", "직선을 믿기 전에...", "최종 보고서..." (setup 코멘트 아님)

## 변경 파일
| 파일 | 변경 |
|---|---|
| web/index.qmd | 과장 문구 수정 + 웹판 안내 섹션 + title 필드 |
| web/_quarto.yml | 신규 (book 프로젝트, 14 chapters) |
| web/_quarto-live.yml | 제거 (_quarto.yml로 통합) |
| web/.gitignore | _book/, *.html 추가 |
| web/ch10_web.qmd | title 필드 + webr-setup 청크 (read_book_csv 등) |
| web/01~09,11~13_web.qmd | webify 재실행 (title 필드 추가) |
| web/03_web.qmd | stopifnot → warning 패치 재적용 |
| scripts/webify.ts | YAML 출력에 title 필드 추가 |
| .github/workflows/web-publish.yml | book 프로젝트 렌더 + _book 배포 |

## 비고
- git push 수행 안 함 (HARD LAW 준수)
- 로컬 렌더만 검증. 배포 URL 검증은 push 후 가능.
