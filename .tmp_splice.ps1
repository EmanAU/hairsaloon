param(
  [string]$File,
  [string]$StartPrefix,
  [string]$EndPrefix,
  [switch]$IncludeEnd
)
$p = (Resolve-Path $File).Path
$enc = New-Object Text.UTF8Encoding $false
$t = [IO.File]::ReadAllText($p, $enc)
$nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = $t -split "`r?`n"
$s = [array]::FindIndex($lines, [Predicate[string]] { param($l) $l.StartsWith($StartPrefix) })
if ($s -lt 0) { throw "start not found" }
$e = [array]::FindIndex($lines, $s + 1, [Predicate[string]] { param($l) $l.StartsWith($EndPrefix) })
if ($e -lt 0) { throw "end not found" }
if ($IncludeEnd) { $e = $e + 1 }
$new = ([IO.File]::ReadAllText((Resolve-Path ".tmp_splice.dart").Path, $enc)) -split "`r?`n"
if ($new[-1] -eq '') { $new = $new[0..($new.Length - 2)] }
$head = if ($s -gt 0) { $lines[0..($s - 1)] } else { @() }
$tail = $lines[$e..($lines.Length - 1)]
$out = $head + $new + $tail
[IO.File]::WriteAllText($p, ($out -join $nl), $enc)
"replaced lines $($s+1)..$e"
