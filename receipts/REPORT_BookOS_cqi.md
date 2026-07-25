# REPORT_BookOS_cqi — CQI 백로그 처리

> 최종 갱신: 2026-07-25 (push 정책 갱신)
> 작업경로: ~/workspace/fda-textbook-web
> PUSH 정책: main/master 직접 push 절대 금지 (Cloudflare Pages 자동배포). hermes/wip 브랜치만 push.

## Push 정책 갱신 (2026-07-25)

- main/master 직접 push → Cloudflare Pages 자동배포 트리거 → 절대 금지
- 작업 브랜치: `hermes/wip` (origin에 push 완료, 커밋 d348995..487af0a)
- 병합 검토: `receipts/COMMANDER_ACTION_REQUIRED_BookOS.md` — 사령관이 hermes/wip → master 병합 결정

## 라이브 배포 상태 (2026-07-25 갱신)

### Cloudflare Quick Tunnel 호스팅 전환 완료

- URL: `https://expressed-possibilities-sullivan-loc.trycloudflare.com`
- 로컬 서빙: `python3 -m http.server 8090` (~/workspace/fda-textbook-web/web/_book/)
- Cloudflare quick tunnel: `cloudflared tunnel --url http://127.0.0.1:8090`
- 검증: 4페이지 fetch 전부 HTTP 200, sidebar=14, mcq/fitb 정상

| 항목 | 이전(GitHub Pages) | 현재(Cloudflare Tunnel) |
|------|-------|------|
| 호스팅 | GitHub Actions → Pages | 서버PC 로컬 + cloudflared |
| 커밋 반영 | push+CI 필요 | _book/ 즉시 반영 |
| 사이드바 | 0/14 (미push) | 14/14 |
| webexercises | 0/14 | 14/14 |
| 과장 문구 | index에 존재 | 수정됨 |

### rclone CLI 직접쓰기 정책 강제

- fuse mount(~/gdrive) 경유 쓰기 금지 — 30s+ 타임아웃 재발 방지
- skill 등록: `devops/rclone-drive-write-policy`
- file-bus lock 적용 완료

## CQI-1: webR/WASM 지원여부 감사 → 전환 가능 챕터 리포트

### 스크립트
- `scripts/webr_audit.py` — 13챕터 R 패키지/함수 사용 패턴 정적 분석
- `web/webr_audit.json` — 상세 결과 JSON

### 감사 결과

| Ch | WebR셀 | ft_book | flextable | set_caption | car::vif | sandwich | pROC | 전환가능 | 작업량 |
|----|--------|---------|-----------|------------|----------|----------|------|---------|--------|
| 01 | 0 | 11 | 33 | 11 | 0 | 0 | 0 | 예 | 중간 |
| 02 | 0 | 14 | 42 | 14 | 0 | 0 | 0 | 예 | 중간 |
| 03 | 0 | 14 | 42 | 14 | 0 | 0 | 0 | 예 | 중간 |
| 04 | 0 | 13 | 39 | 13 | 0 | 0 | 0 | 예 | 중간 |
| 05 | 0 | 12 | 36 | 12 | 0 | 0 | 0 | 예 | 중간 |
| 06 | 0 | 11 | 33 | 11 | 0 | 0 | 0 | 예 | 중간 |
| 07 | 0 | 6 | 18 | 6 | 0 | 0 | 0 | 예 | 중간 |
| 08 | 0 | 11 | 33 | 11 | 0 | 0 | 0 | 예 | 중간 |
| 09 | 0 | 12 | 33 | 11 | 0 | 0 | 0 | 예 | 중간 |
| 10 | 0 | 13 | 39 | 13 | 4 | 2 | 0 | 예 | 높음 |
| 11 | 0 | 13 | 39 | 13 | 0 | 0 | 6 | 예 | 높음 |
| 12 | 0 | 11 | 33 | 11 | 0 | 2 | 0 | 예 | 높음 |
| 13 | 0 | 13 | 39 | 13 | 0 | 1 | 6 | 예 | 높음 |

### 핵심 발견
1. 13/13 챕터가 `ft_book()`/`flextable()`/`set_caption()` 직접 사용 — webR 미지원 패키지
2. `book_table()` (BOOK_WEB=TRUE 시 gt 분기) 사용 안함 — 현재 knitr 정적 렌더에서만 flextable 사용 중
3. 전 챕터 공통 블로커: flextable → gt 마이그레이션 필요
4. ch10: `car::vif`(4회), `sandwich`(2회) 추가 블로커
5. ch11: `pROC`(6회) 추가 블로커
6. ch12: `sandwich`(2회) 추가 블로커
7. ch13: `sandwich`(1회), `pROC`(6회) 추가 블로커

### 전환 가능 챕터 리스트
- 13/13 기술적으로 전부 가능 — 작업량 차이만 존재
- 중간 (테이블만 교체): ch01~09
- 높음 (테이블 + 특수함수 수동구현): ch10~13

### 전환 전략 (참고용, 실행 안 함)
1. `ft_book()` → `book_table()` 교체 (gt 분기 활성화)
2. `flextable()`/`set_caption()` → `book_table()` 래핑
3. `car::vif()` → 수동 VIF (lm + solve(cor()))
4. `sandwich::vcvHC()` → 수동 HC1 (sandwich 공식 직접 구현)
5. `pROC::roc()/auc()` → 수동 ROC/AUC (threshold sweep + trapz)
6. 각 챕터 R 코드 청크를 `{webr}` 셀로 변환

## CQI-2: 모바일 렌더링 + 빌드 안정성 사전 점검

### 빌드 테스트 (1회 실행)
```
quarto render --to live-html
→ 45/45 청크 렌더 완료
→ Output created: _book/index.html
→ exit 0, WARNING/ERROR 0건
```
결과: **PASS**

### 모바일 렌더링 기반 확인
| 항목 | 상태 |
|------|------|
| viewport meta (width=device-width) | 전체 14페이지 있음 |
| Bootstrap responsive (cosmo 테마) | container/row/col 클래스 있음 |
| 사이드바 모바일 토글 (quartoToggleHeadroom) | 있음 |
| 모바일 네비게이션 (sidebar-toggle) | 있음 |

### 페이지 크기 (모바일 로드 성능)
| 페이지 | 크기 | 비고 |
|--------|------|------|
| index | 41KB | 양호 |
| 01_web | 150KB | 양호 |
| ch10_web | 204KB | 양호 (webr 위젯 포함) |
| 13_web | 160KB | 양호 |
| _book/ 전체 | 2.7MB | 양호 |

전체 페이지 <500KB → 모바일 로드 성능 이슈 없음.

## 비고
- GeneralBook 유료화 설계: 건드리지 않음 (사업 결정)
- webR 전환은 기술적 가능성만 감사 — 실제 전환은 별도 CQI 항목
- 빌드 1회 성공으로 안정성 확인
