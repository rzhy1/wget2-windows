# ============================================================
# github-proxy.ps1 —— GitHub 前缀代理「测速 + 选择 + 设置」
# 等价实现自 github-proxy.sh（独立工具，不改任何脚本内下载地址）
# ------------------------------------------------------------
# 说明：只通过 git config --global url."https://代理/https://github.com/".insteadOf 生效。
#       脚本操作「运行它所在环境的 git」：在 WSL 的 pwsh 中运行 → 操作 WSL git（影响
#       WSL 构建，等价于原 .sh）；在 Windows pwsh 中运行 → 操作 Windows git。
# 用法（pwsh 7.6）：
#   pwsh D:\wget2\github-proxy.ps1              测试全部候选 → 选最快 → 设置 git 代理
#   pwsh D:\wget2\github-proxy.ps1 --test       仅测速并输出排名（不设置）
#   pwsh D:\wget2\github-proxy.ps1 --set        跳过测速，直接用当前 FASTEST 设置
#   pwsh D:\wget2\github-proxy.ps1 --remove     移除所有 github / raw 代理
#   pwsh D:\wget2\github-proxy.ps1 --show       显示当前代理规则
# 产出物：本脚本所在目录/proxy-speed-report.txt（测速报告）
# ============================================================

$PROXIES = @(
  "cdn.crashmc.com","cdn.gh-proxy.org","cdn.moran233.xyz",
  "cors.isteed.cc","down.npee.cn","edgeone.gh-proxy.org",
  "fastgit.cc","g.blfrp.cn","gh-proxy.org","gh.api.99988866.xyz",
  "gh.catmak.name","gh.chjina.com","gh.ddlc.top","gh.h233.eu.org",
  "gh.idayer.com","gh.jasonzeng.dev","gh.monlor.com","gh.xxooo.cf",
  "gh.zwy.one","ghfast.top","ghfile.geekertao.top","ghp.keleyaa.com",
  "ghproxy.1888866.xyz","ghproxy.cxkpro.top","ghproxy.it",
  "ghproxy.monkeyray.net","ghproxy.net","ghpxy.hwinzniej.top",
  "git.yylx.win","gitdl.cn","github.boki.moe","github.ednovas.xyz",
  "github.geekery.cn","github.tbedu.top","gitproxy.click",
  "gitproxy.mrhjx.cn","hk.gh-proxy.org","hub.glowp.xyz",
  "proxy.yaoyaoling.net","rapidgit.jjda.de5.net","raw.bgithub.xyz",
  "raw.ihtw.moe","wget.la","xget.xi-xu.me"
)
$REPO    = 'facebook/zstd'                # 测速仓库（depth=1）
$FASTEST = 'github.boki.moe'              # 当前已知最快（--set/--ensure 使用；--test 更新）
$REPORT  = Join-Path $PSScriptRoot 'proxy-speed-report.txt'

function Remove-Proxy {
  Write-Host '== 移除现有 github/raw 代理 =='
  $rules = & git config --global --get-regexp url 2>$null
  if (-not $rules) { Write-Host '  (当前无代理规则)'; return }
  # 每行形如: url.https://host/https://github.com/.insteadof https://github.com/
  # 取空格分隔的左部分作为键名，直接 unset（不依赖预置列表，通用）
  foreach ($line in $rules) {
    $key = ($line -split ' ')[0]
    Write-Host "  移除: $key"
    $null = & git config --global --unset $key 2>$null
  }
  Write-Host '  已清理完毕'
}

function Show-Proxy {
  Write-Host '== 当前 github 代理规则 =='
  $rules = & git config --global --get-regexp url 2>$null
  if (-not $rules) { Write-Host '  (无 —— 直连)' } else { $rules }
}

function Set-Proxy([string]$hostname) {
  if (-not $hostname) { Write-Host 'ERROR: Set-Proxy 需要代理域名参数'; exit 1 }
  $null = & git config --global url."https://$hostname/https://github.com/".insteadOf 'https://github.com/'
  $null = & git config --global url."https://$hostname/https://raw.githubusercontent.com/".insteadOf 'https://raw.githubusercontent.com/'
  Write-Host "已设置 git 代理: $hostname"
  Write-Host "  url.https://$hostname/https://github.com/.insteadof  https://github.com/"
  Write-Host "  url.https://$hostname/https://raw.githubusercontent.com/.insteadof  https://raw.githubusercontent.com/"
}

function Test-Speed {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) 'ghproxy_sel'
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  Write-Host "== 测速开始：连通性预筛 $($PROXIES.Count) 个代理 =="
  $alive = @()
  foreach ($p in $PROXIES) {
    $null = & curl.exe -sI --max-time 8 "https://$p/https://github.com/" 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "  ALIVE  $p"; $alive += $p } else { Write-Host "  DEAD   $p" }
  }
  Write-Host "可达 $($alive.Count) 个，进行 git clone 实测（$REPO, depth=1, 45s 上限）..."
  '' | Set-Content -Encoding utf8 $REPORT
  $fastest=''; $fastestT=[double]::MaxValue
  foreach ($p in $alive) {
    $dest = Join-Path $tmp $p
    $st = [Environment]::TickCount
    $pr = Start-Process -FilePath git -ArgumentList @('clone','--depth=1','-q',"https://$p/https://github.com/$REPO",$dest) -NoNewWindow -PassThru
    if (-not $pr.WaitForExit(45000)) { $pr.Kill(); $rc=1 } else { $rc=$pr.ExitCode }
    $dur = ([Environment]::TickCount - $st)/1000.0
    if ($rc -eq 0) {
      $sz = [math]::Round(((Get-ChildItem $dest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)/1KB)
      Write-Host "  OK   $p  $($dur.ToString('0.00'))s  ${sz}KB"
      "OK   $p  $($dur.ToString('0.00'))s  ${sz}KB" | Add-Content -Encoding utf8 $REPORT
      if ($sz -gt 1024 -and $dur -lt $fastestT) { $fastestT=$dur; $fastest=$p }
    } else {
      Write-Host "  FAIL $p  rc=$rc"
      "FAIL $p  rc=$rc" | Add-Content -Encoding utf8 $REPORT
    }
  }
  if ($fastest) {
    $script:FASTEST = $fastest
    "`n推荐代理: $fastest （clone 实测 $($fastestT.ToString('0.00'))s）" | Add-Content -Encoding utf8 $REPORT
    Write-Host "== 测速完成：最快 = $fastest （$($fastestT.ToString('0.00'))s）=="
    Write-Host "报告已保存: $REPORT"
  } else {
    Write-Host '== 无可用代理 ==（可能网络异常，请稍后重试）'
    '推荐代理: none' | Add-Content -Encoding utf8 $REPORT
    $script:FASTEST = 'none'
  }
}

# ---------- 主流程 ----------
$arg = if ($args.Count -gt 0) { $args[0] } else { 'all' }
switch ($arg) {
  '--remove' { Remove-Proxy; Show-Proxy }
  '--show'   { Show-Proxy }
  '--test'   { Test-Speed }
  '--set'    { Remove-Proxy; Set-Proxy $FASTEST; Show-Proxy }
  '--ensure' { Remove-Proxy; Set-Proxy $FASTEST; Show-Proxy }
  default {
    Remove-Proxy
    Test-Speed
    if ($script:FASTEST -and $script:FASTEST -ne 'none') { Set-Proxy $script:FASTEST; Show-Proxy }
    else { Write-Host '测速未选到可用代理，未设置。' }
  }
}
