#!/usr/bin/env python3
"""
webR/WASM 지원여부 감사 스크립트 — CQI-1
13챕터의 R 패키지/함수 사용 패턴 분석 → webR 전환 가능성 평가

webR 공식 지원 패키지: base, stats, utils, graphics, grDevices, datasets, methods,
dplyr, tidyr, ggplot2, stringr, gt, broom, readr, tibble, purrr, scales, patchwork, etc.

webR 미지원(시스템 의존): flextable, officer, kableExtra, car, sandwich, pROC,
systemfonts, textshaping, ragg, svglite, gdtools, htmlwidgets, reactable, V8, fs, etc.

핵심 발견:
- 13/13 챕터가 ft_book()/flextable/set_caption 직접 사용 (webR 불가)
- book_table() (BOOK_WEB=TRUE 시 gt 분기) 사용 안함 — 현재 knitr 정적 렌더에서만 flextable 사용
- ch10: car::vif(4), sandwich(2) 추가 블로커
- ch11: pROC(6) 추가 블로커
- ch12: sandwich(2) 추가 블로커
- ch13: sandwich(1), pROC(6) 추가 블로커

전환 전략 (실제 전환 시):
1. ft_book() → book_table() 함수명 교체 (gt 분기 활성화, BOOK_WEB=TRUE)
2. flextable()/set_caption() → book_table() 래핑으로 교체
3. car::vif → 수동 VIF 계산 (lm() + solve(cor()) 로 대체 가능)
4. sandwich::vcvHC → 수동 HC1 계산 (xts 계수 + sandwich 공식 직접 구현)
5. pROC::roc/auc → 수동 ROC/AUC 계산 (threshold sweep + trapz)
6. 각 챕터 R 코드 청크를 {webr} 셀로 변환
"""
import os, re, json

QMD = "/home/juicy/workspace/fda-textbook-web/qmd_v2"

chapters = [
    ("01_environment_v3", "01", "분석 환경과 재현성"),
    ("02_thinking_algorithm_v3", "02", "사고의 알고리즘"),
    ("03_ssot_v3", "03", "SSOT"),
    ("04_cleaning_v3", "04", "데이터 정제"),
    ("05_features_v3", "05", "파생변수"),
    ("06_method_choice_v3", "06", "방법 선택"),
    ("07_macro_view_v3", "07", "거시 관점"),
    ("08_descriptive_compare_v3", "08", "기술통계 비교"),
    ("09_correlation_v3", "09", "상관관계"),
    ("10_regression_diagnostics_v3", "10", "회귀분석 진단"),
    ("11_logistic_v3", "11", "로지스틱 회귀"),
    ("12_causal_topics_v3", "12", "인과추론"),
    ("13_final_report_v3", "13", "최종 보고서"),
]

webr_supported = {
    "base", "stats", "utils", "graphics", "grDevices", "datasets", "methods",
    "dplyr", "tidyr", "ggplot2", "stringr", "gt", "broom",
    "readr", "tibble", "purrr", "rlang", "cli", "vctrs", "lifecycle",
    "scales", "gtable", "isoband", "farver", "labeling", "RColorBrewer",
    "MASS", "Matrix", "lattice", "grid", "glue", "magrittr", "R6",
    "jsonlite", "yaml", "evaluate", "knitr", "mime",
    "stringi", "viridisLite", "munsell", "colorspace",
    "patchwork", "ggrepel", "ggridges",
}

results = []
for src, num, title in chapters:
    p = os.path.join(QMD, src + ".qmd")
    with open(p, encoding="utf-8") as f:
        txt = f.read()
    
    # Package usage
    libs = set()
    for m in re.finditer(r'library\((\w+)\)', txt):
        libs.add(m.group(1))
    for m in re.finditer(r'(\w+)::', txt):
        libs.add(m.group(1))
    
    # Function counts
    ft_book = len(re.findall(r'\bft_book\s*\(', txt))
    book_table = len(re.findall(r'\bbook_table\s*\(', txt))
    flextable = len(re.findall(r'\bflextable\s*[:\(]', txt))
    set_caption = len(re.findall(r'\bset_caption\s*\(', txt))
    vif = len(re.findall(r'\bcar::vif\b', txt))
    sandwich = len(re.findall(r'\bsandwich::', txt))
    proc = len(re.findall(r'\bpROC::|roc\(|roc\.test\(|auc\(', txt))
    webr = len(re.findall(r'```{webr', txt))
    ggplot = len(re.findall(r'\bggplot\s*\(', txt))
    
    # Blockers
    blockers = []
    if ft_book > 0: blockers.append(f"ft_book({ft_book})")
    if flextable > 0: blockers.append(f"flextable({flextable})")
    if set_caption > 0: blockers.append(f"set_caption({set_caption})")
    if vif > 0: blockers.append(f"car::vif({vif})")
    if sandwich > 0: blockers.append(f"sandwich({sandwich})")
    if proc > 0: blockers.append(f"pROC({proc})")
    
    # Migration effort estimate
    table_calls = ft_book + flextable + set_caption
    other_blockers = vif + sandwich + proc
    total_blockers = table_calls + other_blockers
    if webr > 0:
        effort = "완료"
        feasible = True
    elif total_blockers == 0:
        effort = "낮음"
        feasible = True
    elif other_blockers == 0:
        effort = f"중간 (테이블 {table_calls}개 → book_table/gt)"
        feasible = True  # 기술적으로 가능, 작업량만 많음
    else:
        effort = f"높음 (테이블 {table_calls}개 + 특수함수 {other_blockers}개 수동구현)"
        feasible = True  # 여전히 가능하지만 작업量大
    
    results.append({
        "chapter": num,
        "title": title,
        "has_webr_cells": webr > 0,
        "webr_cell_count": webr,
        "packages_used": sorted(libs),
        "table_calls": {
            "ft_book": ft_book,
            "book_table": book_table,
            "flextable": flextable,
            "set_caption": set_caption,
        },
        "blocked_functions": {
            "car::vif": vif,
            "sandwich": sandwich,
            "pROC": proc,
        },
        "ggplot_calls": ggplot,
        "blockers": blockers,
        "migration_effort": effort,
        "webr_feasible": feasible,
    })

# Summary
print("=" * 70)
print("webR/WASM 전환 감사 리포트 — CQI-1")
print("=" * 70)
print(f"총 {len(results)}개 챕터 분석")
print()

print(f"{'Ch':>3s} | {'WebR':>5s} | {'ft_book':>7s} | {'flex':>4s} | {'setcap':>6s} | {'vif':>3s} | {'sand':>4s} | {'pROC':>4s} | 전환가능 | 작업량")
print("-" * 90)
for r in results:
    t = r["table_calls"]
    b = r["blocked_functions"]
    print(f"{r['chapter']:>3s} | {r['webr_cell_count']:>5d} | {t['ft_book']:>7d} | {t['flextable']:>4d} | {t['set_caption']:>6d} | {b['car::vif']:>3d} | {b['sandwich']:>4d} | {b['pROC']:>4d} | {'예':>4s} | {r['migration_effort']}")

print()
print("핵심 발견:")
print("1. 13/13 챕터가 ft_book()/flextable/set_caption 직접 사용 → webR 미지원")
print("2. book_table() (BOOK_WEB=TRUE 시 gt 분기) 사용 안함")
print("3. 전 챕터 공통 블로커: flextable → gt 마이그레이션 필요")
print("4. ch10: car::vif(4), sandwich(2) 추가")
print("5. ch11: pROC(6) 추가")
print("6. ch12: sandwich(2) 추가")
print("7. ch13: sandwich(1), pROC(6) 추가")
print()
print("전환 가능 챕터: 13/13 (기술적으로 전부 가능, 작업량 차이만 존재)")
print("  - 낮음: 없음 (모든 챕터가 최소 flextable 마이그레이션 필요)")
print("  - 중간: ch01~09 (테이블만 교체)")
print("  - 높음: ch10~13 (테이블 + 특수함수 수동구현)")

# Save JSON
with open("/home/juicy/workspace/fda-textbook-web/web/webr_audit.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n상세 리포트: web/webr_audit.json")
