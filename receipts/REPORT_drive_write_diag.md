# REPORT — Drive 파일쓰기 실패 원인 규명 + 1회 쓰기 성공 확인

> 일시: 2026-07-25T06:45:04Z
> STOP 조건: 3회 재시도 (1회 fuse timeout, 2회 rclone CLI 성공)

## 원인: rclone fuse mount 동기 I/O 지연

- fuse mount 경유 쓰기(mkdir/cat) → Drive API 동기 대기 → 30s+ 타임아웃
- rclone CLI 직접(copyto/lsjson/cat) → 정상 작동
- 인프라 자체(연결/권한/할당량/rclone binary/vfs cache) 전부 정상
- 근본: `--vfs-cache-mode full` + `--dir-cache-time 24h` 조합의 메타데이터 동기화 지연

## 1회 쓰기 성공 검증

| 항목 | 값 |
|------|-----|
| 파일 | `gdrive:01 Obsidian_OS/_AIOS/_hermes_write_test/write_verified.txt` |
| 크기 | 37 bytes |
| mtime | 2026-07-25T06:45:04.815Z |
| 내용 | `write_test_2026-07-25T06:45:04+00:00` |
| 쓰기 방식 | `rclone copyto` (CLI 직접, fuse mount 경유 안 함) |
| Drive File ID | 1h_FwZUNovUvn2fo4kY8sQiQvlc01vRyL |

## 진단 상세

| 테스트 | 결과 | 비고 |
|--------|------|------|
| mkdir via fuse mount | TIMEOUT 30s | Drive API 동기 호출 지연 |
| rclone mkdir (CLI) | PASS exit 0 | 정상 |
| rclone copyto (CLI) | PASS exit 0 | 정상 |
| rclone lsjson (CLI) | PASS | mtime/size/File ID 확인 |
| rclone cat (CLI, --timeout 10s) | PASS | 내용 readback 확인 |

## rclone mount 상태

- PID 1079, since Jun07
- `--vfs-cache-mode full --vfs-cache-max-size 8G --dir-cache-time 24h --poll-interval 15s`
- vfs cache: 471MB / 8GB (정상)
- 로그 에러: 없음

## COMMANDER_ACTION 필요

1. rclone mount 옵션 조정: `--vfs-cache-mode writes` 또는 `--attr-timeout 1s`로 메타데이터 캐시 단축 검토
2. 또는 Hermes Agent 정책: Drive 쓰기 시 fuse mount 경유 금지, rclone CLI 직접 사용 의무화
