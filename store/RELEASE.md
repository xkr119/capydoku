# Capydoku 출시 체크리스트

이 문서는 **다른 PC에서 업로드 작업만** 하면 되도록 남긴다.
코드·아이콘·스토어 문구는 이미 커밋되어 있고, 아래 두 가지만 사람이 채우면 된다.

---

## 🔴 올리기 전에 반드시

### 1. AdMob 실제 ID 교체 — **두 곳을 함께**

지금은 전부 구글 **테스트 ID**다. 테스트 ID로 출시하면 수익이 0이고,
반대로 실제 ID를 넣은 채 개발하며 자기 광고를 계속 누르면 **계정이 정지된다.**

| 파일 | 자리 |
|---|---|
| `lib/core/ads.dart` | `AdIds.banner` / `interstitial` / `rewarded` |
| `android/app/src/main/AndroidManifest.xml` | `com.google.android.gms.ads.APPLICATION_ID` |

두 곳이 어긋나면(앱 ID는 실제, 유닛 ID는 테스트 등) 광고가 아예 안 뜬다.
AdMob 콘솔에서 앱을 먼저 등록해야 유닛 ID가 나온다 —
스토어에 올리기 전이라도 "아직 스토어에 없음"으로 등록할 수 있다.

### 2. 업로드 키스토어 — **끝났다**

키는 저장소 **밖**, `/Users/tak/개발/keystore/`에 모아 두었다
(`capydoku-upload.jks`, alias `upload`). 그 폴더의 `README.md`에 왜 밖에
두는지와 백업 규칙이 적혀 있다.

`android/key.properties`(gitignore됨)가 그 경로를 가리키고, 있으면 자동으로
그 키로 서명한다. 없는 PC에서는 디버그 키로 떨어져 `flutter run --release`가
그냥 된다.

**다른 PC에서 작업하려면 `.jks`와 `key.properties`를 직접 옮겨야 한다** —
둘 다 git에 없다.

> **경로에 한글이 있다.** `Properties.load(InputStream)`의 기본 인코딩이
> ISO-8859-1이라 `개발`이 `ê°ë°`로 깨져 "키스토어 파일 없음"으로 빌드가
> 죽는다. `build.gradle.kts`가 **UTF-8로 읽도록** 고쳐져 있다
> (`f.reader(Charsets.UTF_8)`). 되돌리지 말 것.

서명 확인:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
# 소유자에 CN=Android Debug 가 뜨면 디버그 키다 — key.properties를 다시 볼 것
```

### 3. 폐쇄 테스트 12명 × 14일 (개인 개발자 계정)

**2023-11-13 이후에 만든 개인 계정이면 이걸 통과해야 프로덕션에 올릴 수
있다.** 앱이 다 만들어져 있어도 소용없다 — 최소 인원이 **연속 14일** 옵트인
상태로 남아 있어야 "프로덕션 액세스 신청" 버튼이 열린다.

- 인원: **12명**(처음엔 20명이었다가 완화됐다. 콘솔이 지금 요구하는 숫자를
  반드시 직접 확인할 것 — 이 문서보다 콘솔이 최신이다).
- 테스터는 **각자 구글 계정으로 옵트인 링크를 눌러야** 인정된다. 중간에
  빠지면 14일이 다시 시작된다.
- 실제로 플레이할 필요까지는 없지만, 어차피 피드백이 필요하니 받는 게 낫다.

즉 **출시하고 싶은 날의 최소 3주 전**에 폐쇄 테스트를 시작해야 한다.
회사 계정(사업자 등록)이면 이 요구가 없다.

> 개발자 계정 등록비는 **1회 $25**다(구독 아님).

---

## 빌드

```
flutter build appbundle --release
```

산출물: `build/app/outputs/bundle/release/app-release.aab` (약 67MB)

**이 숫자에 놀라지 말 것.** AAB는 모든 CPU(arm64/arm32/x86)와 모든 화면
밀도를 한 봉투에 담은 것이고, Play는 기기마다 필요한 것만 잘라서 보낸다.
실제 사용자 다운로드는 **30MB 안팎**이 된다 — 정확한 값은 업로드 후 콘솔의
"다운로드 크기"에 뜬다. 에셋 자체는 15MB뿐이고 나머지는 Flutter 엔진과
광고 SDK다.

버전은 `pubspec.yaml`의 `version: 1.0.0+1` 한 줄에서 온다.
재업로드할 때마다 **`+` 뒤 빌드 번호를 올려야** Play가 받는다(같은 번호는 거부).

---

## 광고 ID 교체는 **프로덕션 직전에**

폐쇄 테스트는 **테스트 ID 그대로** 올린다. 실제 ID를 넣고 본인과 테스터가
광고를 누르면 그게 **무효 트래픽**이고 AdMob 계정 정지 사유다.

다만 교체는 "한 줄 고치기"가 아니라 **검증이 붙는 단계**로 잡을 것 —
매니페스트의 `APPLICATION_ID`가 빠지거나 어긋나면 **앱이 시작하자마자
죽는다.** 바꾼 뒤 릴리스 빌드를 실기기에서 한 번 띄워 보고 올린다.

"앱에 광고 포함" 선언은 **지금** 예로 답한다 — 코드가 아니라 스토어
설정이라 테스트 ID를 쓰더라도 해당된다.

## Play Console 입력값

- 스토어 등록정보 문구 → `store/listing.md`
- 데이터 안전(Data safety) 답변 → `store/data_safety.md`
- 개인정보처리방침 → `store/privacy.md` (아래 "호스팅" 참고)
- 스크린샷 → `store/screenshots/ko/`, `store/screenshots/en/` (언어별로 따로)
- 아이콘 512×512 → `store/graphics/icon_512.png` (**언어 공통** — 글자가 없다)
- 피처 그래픽 1024×500 → 세 장이 있다
  - `feature_any_1024x500.png` — **글자 없음(언어 공통).** 콘솔에서 그래픽
    이미지 칸이 **하나만** 보이면 이걸 쓴다. 어느 언어에서도 안 어긋난다.
  - `feature_ko_1024x500.png` / `feature_en_1024x500.png` — 부제가 들어간 판.
    언어별로 올릴 수 있을 때 쓴다.

  > 콘솔 UI가 개편을 여러 번 겪어서 그래픽 이미지가 언어별인지 앱 공통인지
  > 갈린다. **확실한 것은 스크린샷이 언어별이고 아이콘이 공통이라는 것뿐이다.**
  > 확인하려면 "기본 스토어 등록정보" 위쪽에서 언어를 `en-US`로 바꿔 보고,
  > 그래픽 칸이 비어 있으면 언어별이다.

### 개인정보처리방침 호스팅

Play는 **공개 URL**을 요구한다. 파일만으로는 안 된다.
GitHub Pages로 붙여 뒀다 — Play Console에 넣을 URL은 이것이다.

**https://xkr119.github.io/capydoku/**

- 실제 페이지는 `docs/index.html`이다(`store/privacy.md`가 원본, HTML은 사본).
  **문구를 고치면 두 파일을 함께 고칠 것** — Play가 보는 것은 HTML 쪽이다.
- `docs/.nojekyll`은 Jekyll 처리를 끄는 빈 파일이다. 지우지 말 것.
- 켜는 법: 저장소 Settings → Pages → Source `Deploy from a branch`,
  Branch `main` / 폴더 `/docs` → Save. 첫 배포까지 1~2분.
- **저장소가 public이어야 한다.** private에서 Pages를 쓰려면 유료 플랜이다.

### 스크린샷 다시 찍기

**1080×1920(9:16)이어야 한다.** 에뮬레이터가 1080×2400이면 9:20이라 Play가
거부한다. 크기를 먼저 맞출 것:

```bash
adb shell wm size 1080x1920 && adb shell wm density 420
# 끝나면: adb shell wm size reset && adb shell wm density reset
```

**`lib/core/flags.dart`의 `kShotMode`를 true로 두고 디버그 빌드를 올린다.**
광고 배너와 디버그 UI(⏩·레벨 점프·먹이 채우기)가 통째로 빠진다 — 이걸 몰라서
**테스트 광고와 ⏩ 버튼이 찍힌 스크린샷**을 만든 적이 있다.
단 완료 화면은 ⏩로 판을 끝내야 하므로 그때만 `kDebugStages`를 켠다
(⏩는 퍼즐 화면에만 있어서 완료 화면에는 안 찍힌다).
**찍고 나면 반드시 `kShotMode = false`로 되돌릴 것.**

상태는 **UI를 눌러 만들지 말고 저장값으로 직접** 만든다(레벨·언어·이름·먹이).
`run-as`는 디버그 빌드에서만 되고, 값은 `<int>`가 아니라 **`<long>`**으로
저장돼 있다(여기서 한 번 걸렸다):

```bash
P=/data/data/kr.tak.capydoku/shared_prefs/FlutterSharedPreferences.xml
adb shell "run-as kr.tak.capydoku cat $P" > p.xml
#   flutter.level.current / flutter.set.lang (0=기기,1=한국어,2=English)
#   flutter.pet.name(<string>) / flutter.inv.carrot / flutter.pet.sat
adb shell "run-as kr.tak.capydoku sh -c 'cat > $P'" < p.xml
```

지금 다섯 장의 구성(언어마다 같다):
`1_capy`(어린이 홈 — 목록 썸네일) · `2_puzzle` · `3_clear` ·
`4_baby`(성장의 시작) · `5_family`(성장의 끝).
**1번이 썸네일이라 판이 아니라 카피가 와야 한다** — 판을 앞에 두면
"또 스도쿠"로 읽힌다.

### 언어 코드 — `ko-KR` / `en-US`

Play에는 **그냥 `en`이 없다.** 영어 변형이 여럿인데(`en-GB`·`en-AU`·`en-IN`…)
**`en-US`가 나머지 영어권의 대체**라 하나만 넣을 거면 이것이다.

기본 언어는 `ko-KR`이다. 그래서 **한국어도 영어도 아닌 기기**(독일어·일본어
등)는 한국어 등록정보를 본다. 바꾸려면 스토어 설정 → 앱 세부정보(계정에 따라
잠겨 있기도 하다). 폐쇄 테스트에는 영향이 없다 — 테스터를 직접 고르므로.

**그림도 언어마다 따로 올린다.** 스크린샷과 피처 그래픽에는 **글자가 박혀
있어서** 기본 언어 것이 그대로 쓰이면 영어 목록에 한글이 뜬다. 아이콘만
글자가 없어 언어 공통이다. 안 올리면 기본 언어 것이 그대로 쓰여
영어 목록에 한국어 화면이 뜬다 — `store/screenshots/en/`을 `en-US`에 올릴 것.

출시 노트는 언어 탭을 하나씩 돌지 않고 **태그로 한 번에** 붙여 넣을 수 있다:

```
<ko-KR>
…한국어 노트…
</ko-KR>

<en-US>
…English notes…
</en-US>
```

### 콘텐츠 등급 설문

퍼즐 게임, 폭력·성적 내용·도박 전부 "아니오".
광고 포함 = **예**. 결과는 전체이용가(3+)가 나온다.

### 광고 표시

"앱에 광고가 포함되어 있나요?" → **예**. 안 하면 정책 위반이다.
