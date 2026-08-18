---
title: "Candela — macOS를 위한 무료 디스플레이 제어"
description: "외장 모니터를 위한 오픈 소스 macOS 메뉴 막대 앱: 또렷한 HiDPI 스케일링, DDC 하드웨어 밝기, 여러 디스플레이 밝기 동기화, 프리셋과 가상 디스플레이. 전부 무료이며 Pro 등급이 없습니다."
schema: |
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"SoftwareApplication","name":"Candela",
   "operatingSystem":"macOS 26","applicationCategory":"UtilitiesApplication",
   "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"},
   "url":"{{SITE}}/ko/",
   "downloadUrl":"https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg",
   "screenshot":"{{SITE}}/shots/panel-root.webp",
   "softwareLicense":"https://github.com/iamzifei/Candela/blob/main/LICENSE",
   "isAccessibleForFree":true}
  </script>
---

<div class="hero">

# macOS가 숨겨 둔 디스플레이 제어를, 메뉴 막대 패널 하나에

macOS가 내장 화면에만 남겨 둔 기능을 책상 위 모든 모니터로 —— DDC를 통한 실제 밝기 조절,
또렷한 HiDPI 스케일링, 그리고 어디서나 작동하는 밝기 키.

<div class="actions">
<a class="btn btn-dl" href="https://github.com/iamzifei/Candela/releases/latest/download/Candela.dmg">macOS용 다운로드</a>
<a class="btn btn-kofi" href="https://ko-fi.com/james_ai/tip" rel="noopener">Ko-fi에서 후원</a>
</div>

<p class="note">macOS 26 · Apple 실리콘 · MIT 라이선스 · Pro 등급도, 라이선스 키도 없음</p>
</div>

<figure class="film">
<video class="film-frame" poster="../video/poster.webp" width="1920" height="1080"
       autoplay muted loop playsinline preload="none"
       aria-label="Candela를 실제로 사용하는 60초 무음 녹화: 메뉴 막대에서 패널 열기, 한 대씩 그리고 전체 디스플레이를 한 번에 조절하는 밝기 슬라이더, 전체 HiDPI 해상도 목록, 밝기 키 대상, 도구 페이지, 시스템 전체 다크 모드 전환.">
<source src="../video/hero-1080.webm" type="video/webm">
<source src="../video/hero-1080.mp4" type="video/mp4">
</video>
<figcaption>60초, 소리 없음. 모든 장면이 실제 배포되는 앱을 실제 책상에서 찍은 것입니다.</figcaption>
</figure>

<div class="sect-label">01 · macOS가 빠뜨린 것</div>

## 세 가지가 작동하지 않습니다

<p class="sect-lede">Mac에 모니터를 연결하면 밝기 키는 아무것도 조절하지 못하고, 해상도 목록은 흐릿한 선택지 몇 개만
보여 주며 또렷한 모드는 숨깁니다. 게다가 모든 디스플레이를 한 번에 조절할 방법이 없습니다.
Candela는 이 세 가지를 되돌려 줍니다 — 환경설정 창이 아니라 제어 센터처럼 동작하는 패널로.</p>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-root.webp" alt="Candela 패널: 연결된 각 디스플레이의 밝기 슬라이더와 전체를 함께 움직이는 통합 슬라이더" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>백라이트까지 닿는 밝기</h3>

- 영상 케이블을 통한 DDC/CI —— 모니터 자체 버튼이 쓰는 것과 같은 경로
- DDC를 거부하는 디스플레이는 감마 디밍으로 대체되며 *Software*로 표시됩니다
- 응답하는 모니터라면 음량도 같은 패널에서

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-settings.webp" alt="Candela 설정 화면. 밝기 키 항목과 현재 대상이 보입니다" width="1380" height="934" loading="lazy" decoding="async"></figure>
<div>
<h3>어떤 디스플레이에서도 작동하는 밝기 키</h3>

- 포인터를 따라가거나, 모든 디스플레이를 조절하거나, 전부를 하나처럼 조절
- 원하는 디스플레이에만 적용해 TV나 색이 중요한 패널은 건드리지 않을 수도 있습니다
- 손쉬운 사용 권한 하나면 되고, 재시동은 필요 없습니다

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-allResolutions.webp" alt="한 디스플레이의 전체 해상도 목록. 또렷한 모드가 표시되어 있습니다" width="1380" height="1708" loading="lazy" decoding="async"></figure>
<div>
<h3>어떤 모니터에서도 또렷한 HiDPI</h3>

- macOS가 서드파티 디스플레이에서 숨기는 2× 렌더링 모드
- 1440p나 4K 패널이 가독성과 선명함 중 하나가 아니라 둘 다를 얻습니다
- 주사율도 같은 페이지에 있어, 스케일링 때문에 조용히 60 Hz로 떨어지는 일이 없습니다

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-display.webp" alt="Candela의 개별 디스플레이 페이지. 통합 밝기의 하한 설정이 있습니다" width="1380" height="1482" loading="lazy" decoding="async"></figure>
<div>
<h3>서로 맞아떨어지는 디스플레이</h3>

- 책상 전체를 슬라이더 하나로
- 여기에 디스플레이마다 눈으로 맞추는 하한값을 더합니다 —— 같은 퍼센트라도 두 패널이 같은 빛을
  내지는 않으니까요
- 옆 화면은 아직 켜져 있는데 한쪽만 캄캄해지는 일이 없습니다

</div>
</div>

<div class="row">
<figure class="row-figure"><img src="../shots/panel-tools.webp" alt="Candela 도구 페이지: 배열, 가상 디스플레이, Sidecar" width="1380" height="624" loading="lazy" decoding="async"></figure>
<div>
<h3>프리셋, 배열, 가상 화면</h3>

- 해상도·밝기·배열을 포함한 책상 전체를 저장하고 클릭 한 번으로 복원
- 시스템 설정을 열지 않고 디스플레이 위치를 드래그로 조정
- 녹화용 가상 화면을 만들거나 Sidecar로 iPad를 연결

</div>
</div>

<div class="sect-label">02 · 가격</div>

## 무료이고, 상위 등급도 없습니다

Pro 등급도, 라이선스 키도, 하루 사용 제한도, 잠가 둔 기능도 없습니다. 앱 전체가 MIT 라이선스이고
소스는 GitHub에 있습니다. 쓸모가 있었다면 [Ko-fi]가 있지만, 한 번도 누르지 않아도 앱에서 달라지는
것은 없습니다.

이것이 다른 선택지와의 가장 큰 차이입니다. [BetterDisplay]는 무료 등급도 훌륭하지만 유연한 HiDPI
스케일링, 가상 화면, 디스플레이 연결 해제, 고급 단축키는 21.99달러의 Pro에 남겨 둡니다. [Lunar]는
오픈 소스이고 평생 라이선스가 23달러이며, 무료 빌드는 밝기 조절이 하루 100회로 제한됩니다. 둘 다
좋은 소프트웨어입니다. "어떤 기능을 쓸 수 있나"라는 질문에 대한 Candela의 답은 그냥 "전부"입니다.

[전체 비교 읽기 →](../candela-vs-betterdisplay.html)(영어)

<div class="sect-label">03 · 가이드</div>

## 여기서 시작하세요

아래 가이드는 현재 영어와 중국어 간체로 제공됩니다:

- [외장 모니터가 흐릿할 때](../fix-blurry-external-monitor-macos.html) —— 1440p나 4K에서 글자가 뭉개져 보이는 이유와 실제로 효과가 있는 해결책
- [Mac에서 HiDPI 켜기](../enable-hidpi-mac.html) —— HiDPI란 무엇이며, macOS가 제안하지 않는 디스플레이에서 켜는 방법
- [외장 모니터에서 밝기 키 쓰기](../mac-brightness-keys-external-monitor.html) —— 어떤 디스플레이에서든 F1·F2를 쓰기 위한 권한
- [여러 모니터의 밝기 동기화](../sync-brightness-multiple-monitors-mac.html) —— 책상 전체를 슬라이더 하나로, 그리고 실제로 맞추는 방법

<div class="sect-label">04 · 설치</div>

## 두 가지 방법

DMG를 내려받아 Candela를 응용 프로그램으로 끌어다 놓거나 Homebrew를 씁니다:

```
brew install --cask iamzifei/tap/candela
```

Candela는 Developer ID로 서명되고 Apple의 공증을 받았기 때문에 오른쪽 클릭으로 우회할 필요 없이 열립니다.

<div class="sect-label">05 · 요구 사항</div>

## 필요한 것

- macOS 26 이상
- Apple 실리콘
- 밝기 키에는 손쉬운 사용 권한 하나가 필요하며, 기능을 처음 켤 때 macOS가 묻습니다
- 외장 디스플레이의 하드웨어 밝기에는 모니터 자체 OSD 메뉴에서 DDC/CI가 켜져 있어야 합니다.
  대부분의 모니터는 기본으로 켜져 있지만, 일부 기종과 일부 USB-C 독은 이 채널을 전달하지 않습니다

<div class="sect-label">06 · 제가 만든 다른 앱</div>

## 같은 메뉴 막대의 다른 앱

<a class="sibling" href="https://audioswitch.dev" rel="noopener">
<img src="../audioswitch.png" width="44" height="44" alt="" loading="lazy" decoding="async">
<span class="sibling-text">
<span class="sibling-name">AudioSwitch</span>
<span class="sibling-desc">모든 오디오 입력과 출력을 한 패널에 —— 장치 전환, 음량, 음소거, 실시간 마이크 레벨 미터, 마이크 완전 차단 스위치. 무료, MIT, Apple 실리콘 네이티브.</span>
</span>
<svg class="sibling-go" width="18" height="18" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5 10.5 8 6 12.5"/></svg>
</a>

[Ko-fi]: https://ko-fi.com/james_ai/tip
[BetterDisplay]: https://betterdisplay.pro/
[Lunar]: https://lunar.fyi/
