# PASSTIME

세종대학교 구성원을 위한 **행사 입장권 발급·관리 애플리케이션**입니다.

참가자는 행사 입장권을 등록하고 납부 증빙 및 환불 요청을 제출할 수 있으며,
소속장과 임원은 행사, 참가자, 납부 내역, 환불 신청을 관리할 수 있습니다.

- 앱 버전: `1.2.1+23`
- 프레임워크: Flutter
- 주요 지원 플랫폼: Android
- 백엔드: [Sejong Ticket App Backend](https://github.com/SSONGDH/Sejong_Ticket_App_Backend_nodejs)

## 주요 기능

### 참가자

- 세종대학교 계정 로그인
- 행사 코드 또는 NFC 태그를 이용한 입장권 등록
- 보유 입장권 및 사용 상태 조회
  - 사용 가능
  - 승인 대기
  - 환불 중
  - 환불 완료
  - 만료
- 행사 일시, 장소, 설명 및 지도 확인
- 참가비 납부 증빙 이미지 제출
- 환불 사유, 계좌 정보, 방문 가능 일시를 포함한 환불 신청
- 마이페이지에서 소속 및 참여 행사 이력 확인
- 푸시 알림 수신 여부 설정

### 주최자

- 권한을 보유한 소속의 행사 생성·수정·삭제
- 카카오 장소 검색을 이용한 행사 장소 지정
- 행사 코드 관리
- 행사별 참가자 및 납부 승인 대기 현황 확인
- 납부 증빙 상세 확인, 승인 및 거절
- 납부 내역 BETA AI 일괄 판별
- 환불 신청 목록 확인, 승인 및 거절
- 참가자 모드와 주최자 모드 전환

### 소속장·임원·ROOT

| 역할 | 권한 |
| --- | --- |
| 일반 소속원 (`member`) | 참가자 기능 사용 |
| 임원 (`executive`) | 소속 행사 및 납부·환불 관리 |
| 소속장 (`leader`) | 임원 권한 부여·회수, 소속장 위임, 소속 관리 |
| ROOT | 소속 생성 및 주최자 권한 신청 승인·거절 |

## 주요 화면

| 구분 | 화면 |
| --- | --- |
| 인증 | 로그인, 자동 로그인 |
| 입장권 | 입장권 홈, 상세 정보, 코드 등록, NFC 등록 |
| 참가 신청 | 납부 증빙 제출, 환불 신청 |
| 사용자 | 마이페이지, 소속 관리, 참여 행사, 설정 |
| 행사 관리 | 행사 목록, 행사 생성·수정, 행사 삭제 |
| 승인 관리 | 납부 목록·상세, AI 판별, 환불 목록·상세 |
| 권한 관리 | 소속원 관리, 임원 지정, 소속장 위임, 권한 신청 관리 |

## 기술 스택

### App

- Flutter / Dart
- Material 3
- Kotlin MethodChannel

### Networking & State

- `dio`, `http`
- `cookie_jar`, `dio_cookie_manager`
- `provider`
- `shared_preferences`
- `flutter_dotenv`

### Firebase & Notification

- `firebase_core`
- `firebase_messaging`
- `flutter_local_notifications`

### Map & Location

- `kakao_maps_flutter`
- `kakao_map_plugin`
- `kakao_map_sdk`
- `kakao_flutter_sdk`
- Kakao Local REST API

### Device & Media

- `nfc_manager`
- `flutter_nfc_kit`
- `ndef`
- `image_picker`
- `webview_flutter`

### Monetization

- `google_mobile_ads`
- `in_app_purchase`

## 프로젝트 구조

```text
PASSTIME_Android/
├─ android/                      # Android 네이티브 설정 및 NFC MethodChannel
├─ ios/                          # iOS 프로젝트 설정
├─ assets/images/                # 로고와 앱 이미지
├─ lib/
│  ├─ main.dart                  # 앱, Firebase, FCM, Kakao, 광고 초기화
│  ├─ cookiejar_singleton.dart   # API 세션 쿠키 관리
│  ├─ admin/                     # 주최자·ROOT 행사 및 승인 관리 화면
│  ├─ menu/                      # 입장권 추가, 납부, 환불, 마이페이지
│  ├─ models/                    # 소속 및 권한 모델
│  ├─ screens/                   # 로그인, 입장권 홈·상세, 참여 행사
│  ├─ services/                  # 광고 및 인앱 후원 서비스
│  ├─ utils/                     # Kakao 장소 검색, 권한·화면 전환 유틸
│  └─ widgets/                   # 공통 UI 컴포넌트
├─ test/                         # Flutter 테스트
├─ pubspec.yaml                  # 패키지 및 자산 설정
└─ firebase.json                 # FlutterFire 설정
```

## 개발 환경

다음 환경을 권장합니다.

- Flutter `3.35` 이상
- Dart `3.9` 이상
- Java `17`
- Android SDK `36`
- Android NDK `28.2.13676358`

Android 설정:

- Minimum SDK: `26`
- Target / Compile SDK: `36`
- Release ABI: `arm64-v8a`

설치된 버전은 아래 명령으로 확인할 수 있습니다.

```bash
flutter --version
flutter doctor -v
java --version
```

## 시작하기

### 1. 저장소 복제

```bash
git clone https://github.com/SEJONG-PASSTIME/PASSTIME_Android.git
cd PASSTIME_Android
```

### 2. 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성합니다.

```dotenv
# Backend
API_BASE_URL=http://your-api-server:3000

# Kakao
KAKAO_NATIVE_APP_KEY=your_native_app_key
KAKAO_REST_API_KEY=your_rest_api_key
KAKAO_MAP_JS_KEY=your_javascript_key

# AdMob (선택)
ADMOB_SETTINGS_BANNER_ANDROID=your_android_banner_id
ADMOB_SETTINGS_BANNER_IOS=your_ios_banner_id

# In-App Purchase (선택)
IAP_DONATE_PRODUCT_ID=donate_support
IAP_DONATE_SUB_PRODUCT_ID=donate_monthly
```

`API_BASE_URL`은 마지막 `/` 없이 작성하는 것을 권장합니다.

> `.env`는 앱 번들에 포함될 수 있으므로 서버 비밀키나 관리자 인증정보를 넣지 마세요.
> 실제 키는 저장소에 커밋하지 않고 팀 내부의 안전한 방법으로 공유해야 합니다.

### 3. Firebase 설정

Firebase 프로젝트를 연결한 뒤 아래 설정 파일을 배치합니다.

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
```

필요하면 FlutterFire CLI로 설정을 다시 생성할 수 있습니다.

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Firebase Cloud Messaging을 사용하므로 Android 13 이상에서는 알림 권한 허용이
필요합니다.

### 4. Kakao 설정

Kakao Developers 애플리케이션에서 다음 키를 발급받아야 합니다.

- Native App Key
- REST API Key
- JavaScript Key

Android 패키지명과 키 해시, iOS Bundle ID 및 URL Scheme도 Kakao Developers에
등록해야 합니다.

### 5. 패키지 설치 및 실행

```bash
flutter pub get
flutter run
```

연결된 기기를 확인하려면 다음 명령을 사용합니다.

```bash
flutter devices
```

## 빌드

### Android Debug APK

```bash
flutter build apk --debug
```

### Android Release APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

릴리스 빌드에는 `android/key.properties`와 서명용 keystore가 필요합니다.

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=...
```

서명 파일과 비밀번호는 절대 Git에 커밋하지 마세요.

## 백엔드 연동

앱은 `.env`의 `API_BASE_URL`을 기준으로 백엔드 API를 호출합니다.
인증은 로그인 응답의 세션 쿠키를 사용하는 방식입니다.

### 주요 API

| 영역 | Method | Endpoint | 설명 |
| --- | --- | --- | --- |
| 인증 | POST | `/auth/login` | 로그인 |
| FCM | POST | `/fcm/tokenAdd` | FCM 토큰 등록 |
| 입장권 | GET | `/ticket/main` | 사용자 입장권 목록 |
| 입장권 | GET | `/ticket/detail` | 입장권 상세 |
| 입장권 | POST | `/ticket/add` | 행사 코드로 입장권 추가 |
| 입장권 | POST | `/ticket/addNFC` | NFC로 입장권 추가 |
| 행사 | GET | `/ticket/manageList` | 관리 가능한 행사 목록 |
| 행사 | POST | `/ticket/createTicket` | 행사 생성 |
| 행사 | PUT | `/ticket/modifyTicket` | 행사 수정 |
| 행사 | PUT | `/ticket/delete` | 행사 삭제 |
| 납부 | POST | `/payment/post` | 납부 증빙 제출 |
| 납부 | GET | `/payment/list` | 납부 목록 |
| 납부 | PUT | `/payment/permission` | 납부 승인 |
| 납부 | PUT | `/payment/deny` | 납부 거절 |
| AI | POST | `/payment/ai-review/batch` | 납부 내역 일괄 판별 |
| 환불 | POST | `/refund/request` | 환불 신청 |
| 환불 | GET | `/refund/list` | 환불 신청 목록 |
| 환불 | PUT | `/refund/permission` | 환불 승인 |
| 환불 | PUT | `/refund/deny` | 환불 거절 |
| 사용자 | GET | `/user/mypage` | 마이페이지 |
| 참여 이력 | GET | `/user/mypage/events` | 참여 행사 목록 |
| 소속 | POST | `/affiliation/request` | 소속·권한 신청 |
| 소속 | GET | `/affiliation/members/{affiliationId}` | 소속원 목록 |
| 소속 | POST | `/affiliation/permission/grant` | 임원 권한 부여 |
| 소속 | POST | `/affiliation/permission/revoke` | 임원 권한 회수 |
| 소속 | POST | `/affiliation/permission/delegate` | 소속장 위임 |

세부 요청·응답 규격은 백엔드 저장소를 참고하세요.

## 푸시 알림

로그인 성공 후 FCM 토큰을 백엔드에 등록합니다.

- Foreground: `flutter_local_notifications`로 로컬 알림 표시
- Background / Terminated: Android 시스템 알림 표시
- 알림 채널: `high_importance_channel`

알림이 오지 않는 경우 다음을 확인하세요.

1. 앱의 알림 권한이 허용되어 있는지
2. 앱 설정의 알림 수신 여부가 활성화되어 있는지
3. Firebase 설정 파일이 올바른 프로젝트의 파일인지
4. 로그인 후 FCM 토큰 등록 API가 성공했는지
5. 배터리 절전 정책이 앱의 백그라운드 실행을 제한하지 않는지

## NFC

- Android 기기의 NFC 기능과 NDEF 태그를 사용합니다.
- NFC 태그에서 행사 코드를 읽어 `/ticket/addNFC`로 등록합니다.
- NFC가 비활성화된 경우 Android 설정 화면을 열 수 있도록 Kotlin
  MethodChannel이 구현되어 있습니다.
- Android Manifest에서 NFC 하드웨어가 필수로 선언되어 있으므로 NFC 미지원
  기기에서는 설치 또는 스토어 노출이 제한될 수 있습니다.

## 검사 및 테스트

```bash
flutter analyze
flutter test
```

현재 `test/widget_test.dart`는 Flutter 기본 생성 테스트를 기반으로 하므로 실제 앱
UI 흐름에 맞게 보완이 필요합니다.

## 문제 해결

### `.env`를 찾을 수 없다는 오류

`pubspec.yaml`에서 `.env`를 asset으로 등록하고 있으므로 프로젝트 루트에 파일이
반드시 존재해야 합니다.

```bash
flutter clean
flutter pub get
flutter run
```

### API 연결 실패

- `API_BASE_URL`의 프로토콜, IP/도메인, 포트를 확인합니다.
- Android Emulator에서 PC의 localhost를 사용할 때는 `10.0.2.2`를 사용합니다.
- HTTP 서버를 사용하는 경우 Android 네트워크 보안 설정을 확인합니다.

### Firebase 알림 수신 실패

- `google-services.json`의 Android package name이
  `com.yoonjaemin.passtime`과 일치하는지 확인합니다.
- 알림 권한 및 FCM 토큰 등록 로그를 확인합니다.

### NFC 인식 실패

- 기기가 NFC를 지원하는지 확인합니다.
- NFC가 활성화되어 있는지 확인합니다.
- 태그가 NDEF 형식이며 유효한 행사 코드를 포함하는지 확인합니다.

### Release 빌드 실패

- Java 17과 Android SDK 36 설치 여부를 확인합니다.
- `android/key.properties`와 keystore 경로를 확인합니다.
- NDK `28.2.13676358` 설치 여부를 확인합니다.

## 구현 시 주의사항

- 자동 로그인 정보는 기기 로컬 저장소를 사용하므로 민감정보 저장 방식을 개선할
  필요가 있습니다.
- 세션 쿠키 및 인증 API 변경 시 로그인, 앱 재실행, 자동 로그인 흐름을 함께
  검증해야 합니다.
- 운영 키, Firebase 설정, keystore 및 계정정보를 로그나 Git에 노출하지 마세요.
- Android 릴리스는 현재 `arm64-v8a` ABI만 대상으로 합니다.
- Firebase 초기화 설정은 Android/iOS 기준이며 다른 플랫폼은 별도 구성이
  필요합니다.

## 기여 방법

1. 저장소를 Fork합니다.
2. 기능 브랜치를 생성합니다.
3. 변경 후 `flutter analyze`와 `flutter test`를 실행합니다.
4. 변경 이유와 테스트 결과를 포함해 Pull Request를 생성합니다.

```bash
git checkout -b feature/your-feature
git commit -m "FEAT: 변경 내용"
git push origin feature/your-feature
```

## 관련 저장소

- Android App: [SEJONG-PASSTIME/PASSTIME_Android](https://github.com/SEJONG-PASSTIME/PASSTIME_Android)
- Backend: [SSONGDH/Sejong_Ticket_App_Backend_nodejs](https://github.com/SSONGDH/Sejong_Ticket_App_Backend_nodejs)

## License

현재 저장소에 별도의 라이선스가 명시되어 있지 않습니다.
