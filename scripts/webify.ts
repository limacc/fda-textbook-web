#!/usr/bin/env tsx
/**
 * webify.ts — qmd_v2/NN_*.qmd → web/NN_web.qmd 변환 (규칙 기반, DB 미사용)
 *
 * 원본 PRD_WEBIFY_v1.md는 LLM(runClaude) 기반이었으나, Windows PC 미커밋으로
 * MiniPC에서 접근 불가. ch10_web.qmd 실물 예시를 역분석하여 규칙 기반으로 재작성.
 *
 * 변환 규칙 (ch10_web.qmd 역분석):
 *   1. YAML frontmatter 교체: docx → live-html + webr packages + resources
 *   2. include 경로 수정: _common.qmd → ../qmd_v2/_common.qmd
 *   3. setup chunk 재작성: BOOK_WEB=TRUE, data/ssot_web.csv 사용, book_data_root 의존 제거
 *   4. 본문 R 코드는 그대로 유지 (정적 렌더 시 knitr가 실행)
 *   5. 실패 시 원본을 그대로 출력 경로로 복사 (정적 폴백)
 *
 * 사용법: npx tsx scripts/webify.ts <입력.qmd> <출력.qmd>
 */
import * as fs from "fs";
import * as path from "path";

function main(): void {
  const [inPath, outPath] = process.argv.slice(2);
  if (!inPath || !outPath) {
    console.error("Usage: webify.ts <input.qmd> <output.qmd>");
    process.exit(1);
  }
  if (!fs.existsSync(inPath)) {
    console.error(`ERROR: input not found: ${inPath}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(inPath, "utf-8").replace(/\r\n/g, "\n");

  // YAML frontmatter 추출 (--- ... ---)
  const yamlMatch = raw.match(/^---\n([\s\S]*?)\n---\n/);
  if (!yamlMatch) {
    console.warn(`WARN: no YAML frontmatter in ${inPath} — static fallback`);
    fs.copyFileSync(inPath, outPath);
    console.log(`FALLBACK: ${inPath} → ${outPath}`);
    return;
  }

  const yamlText = yamlMatch[1];
  const body = raw.slice(yamlMatch[0].length);

  // 챕터 정보 추출
  const chId = yamlText.match(/chapter-id:\s*"([^"]+)"/)?.[1] ?? "";
  const chNum = yamlText.match(/chapter-num:\s*"([^"]+)"/)?.[1] ?? "";
  const chTitle = yamlText.match(/chapter-title:\s*"([^"]+)"/)?.[1] ?? "";

  // 새 YAML (live-html, ch10_web.qmd와 동일 구조)
  const newYaml = [
    "---",
    `chapter-id: "${chId}"`,
    `chapter-num: "${chNum}"`,
    `chapter-title: "${chTitle}"`,
    "format:",
    "  live-html:",
    "    theme: cosmo",
    "    toc: true",
    "lang: ko",
    "engine: knitr",
    "filters: [live]",
    "execute:",
    "  echo: false",
    "  warning: false",
    "  message: false",
    "  error: false",
    "webr:",
    "  packages: [dplyr, tidyr, ggplot2, stringr, gt, broom]",
    "resources: [data/]",
    "---",
    "",
  ].join("\n");

  // 본문 변환
  let newBody = body;

  // 1. include 경로 수정: {{< include _common.qmd >}} → {{< include ../qmd_v2/_common.qmd >}}
  newBody = newBody.replace(
    /\{\{<\s*include\s+_common\.qmd\s*>\}\}/g,
    "{{< include ../qmd_v2/_common.qmd >}}"
  );

  // 2. setup chunk 내 ssot_path 로직을 web용으로 패치 (chunk 자체는 유지 — 챕터 고유 헬퍼 보존)
  //    패턴 A: ssot_path <- Sys.getenv("BOOK_SSOT_DATA", unset = "") ... if (!file.exists(ssot_path)) { stop(...) }
  //    → ssot_path <- "data/ssot_web.csv" 한 줄로 교체 (file.exists 체크 포함)
  const ssotBlockPattern = /ssot_path\s*<-\s*Sys\.getenv\([\s\S]*?if\s*\(!file\.exists\(ssot_path\)\)\s*\{[\s\S]*?\n\}\n/s;
  if (ssotBlockPattern.test(newBody)) {
    newBody = newBody.replace(ssotBlockPattern, 'ssot_path <- "data/ssot_web.csv"\n');
  } else {
    // 패턴 B: ssot_path <- Sys.getenv(...) ... } (file.exists 없는 변형)
    const ssotBlockB = /ssot_path\s*<-\s*Sys\.getenv\([\s\S]*?\n\}\n/s;
    if (ssotBlockB.test(newBody)) {
      newBody = newBody.replace(ssotBlockB, 'ssot_path <- "data/ssot_web.csv"\n');
      // 별도 file.exists 체크도 제거
      const fileExistsBlock = /if\s*\(!file\.exists\(ssot_path\)\)\s*\{[\s\S]*?\n\}\n/s;
      newBody = newBody.replace(fileExistsBlock, '');
    } else {
      // 대체 패턴: ssot_path <- ... (단일 라인)
      const ssotLinePattern = /ssot_path\s*<-\s*[^\n]+/;
      if (ssotLinePattern.test(newBody)) {
        newBody = newBody.replace(ssotLinePattern, 'ssot_path <- "data/ssot_web.csv"');
      }
    }
  }

  // 3. setup chunk 시작 직후에 options(BOOK_WEB = TRUE) 주입 (gt 분기 활성화)
  //    패턴: ```{r chNN-setup, include=FALSE}\n 다음 라인에 삽입
  const setupStartPattern = /(```{r\s+\w+-setup,\s*include=FALSE}\n)/;
  if (setupStartPattern.test(newBody)) {
    newBody = newBody.replace(
      setupStartPattern,
      '$1options(BOOK_WEB = TRUE)\n'
    );
  }

  const output = newYaml + newBody;

  try {
    fs.writeFileSync(outPath, output, "utf-8");
    console.log(`OK: ${inPath} → ${outPath} (${output.length} bytes)`);
  } catch (e) {
    console.error(`ERROR writing ${outPath}: ${e}`);
    fs.copyFileSync(inPath, outPath);
    console.log(`FALLBACK: ${inPath} → ${outPath}`);
  }
}

main();
