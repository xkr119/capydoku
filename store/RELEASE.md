# Capydoku 출시 체크리스트

이 문서는 **다른 PC에서 업로드 작업만** 하면 되도록 남긴다.
코드·아이콘·스토어 문구는 이미 커밋되어 있고, 아래 두 가지만 사람이 채우면 된다.

---

## 🔴 올리기 전에 반드시 (이 둘 없이는 출시 불가)

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

### 2. 업로드 키스토어 만들기

`android/key.properties`와 `*.jks`는 `.gitignore`에 걸려 있어 저장소에 없다.
**작업 PC에서 한 번만** 만들고, 그 파일을 안전한 곳에 백업할 것 —
잃어버리면 이 앱을 **영영 업데이트할 수 없다**(Play 지원팀 통해 복구 요청은 가능하나 번거롭다).

```
keytool -genkey -v -keystore ~/capydoku-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

그다음 `android/key.properties.example`을 `android/key.properties`로 복사해 값을 채운다.
파일이 없으면 릴리스 빌드가 **디버그 키로 서명**되고, Play가 그런 AAB는 거부한다.

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

## Play Console 입력값

- 스토어 등록정보 문구 → `store/listing.md`
- 데이터 안전(Data safety) 답변 → `store/data_safety.md`
- 개인정보처리방침 → `store/privacy.md` (아래 "호스팅" 참고)
- 스크린샷 → `store/screenshots/`
- 아이콘 512×512 → `store/graphics/icon_512.png`
- 피처 그래픽 1024×500 → `store/graphics/feature_1024x500.png`

### 개인정보처리방침 호스팅

Play는 **공개 URL**을 요구한다. 파일만으로는 안 된다.
가장 싼 방법은 GitHub Pages다 — 이 저장소를 GitHub에 올린 뒤
`store/privacy.md`를 `docs/index.md`로 두고 Settings → Pages를 켜면
`https://<계정>.github.io/<저장소>/` 가 그대로 URL이 된다.

### 콘텐츠 등급 설문

퍼즐 게임, 폭력·성적 내용·도박 전부 "아니오".
광고 포함 = **예**. 결과는 전체이용가(3+)가 나온다.

### 광고 표시

"앱에 광고가 포함되어 있나요?" → **예**. 안 하면 정책 위반이다.
