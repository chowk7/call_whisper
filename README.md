# Call Whisper

모바일에서 음성 파일을 기기 내 Whisper 모델로 전사하는 오프라인 앱입니다.

## 현재 구현

- Base, Small, Medium Whisper 모델을 설정 화면에서 선택
- 버튼 한 번으로 모델 다운로드와 앱 전용 저장소 설치
- 설치 완료 모델 선택, 사용 중 모델 표시, 삭제, 실패 시 재시도
- 다운로드 중 진행률 표시와 부분 파일 보호
- Android 시스템 코덱으로 m4a/AAC를 16 kHz 모노 PCM으로 변환
- whisper.cpp의 타임스탬프와 TinyDiarize 화자 전환 감지로 `화자 1`, `화자 2` 구분
- 화자 이름 변경과 개별 발화 텍스트·화자 수정
- UTF-8 BOM TXT 및 SRT 자막 생성 후 기기 공유 메뉴로 내보내기

모델은 [whisper.cpp GGML 배포본](https://huggingface.co/ggerganov/whisper.cpp)에서 사용자의 명시적 클릭 후 내려받습니다. 저장 위치는 앱의 비공개 문서 폴더입니다.

## 실행

Flutter SDK 설치 후 아래를 실행합니다.

```bash
flutter pub get
scripts/bootstrap_native.sh
flutter run
```

Android 네이티브 빌드는 `third_party/whisper.cpp` 소스가 필요하므로 `scripts/bootstrap_native.sh`를 먼저 실행합니다. iOS 네이티브 연결과 화자 이름 편집·내보내기는 다음 단계입니다.

## GitHub에서 APK 빌드

`main` 브랜치에 푸시하면 GitHub Actions의 **Android debug build**가 실행됩니다. 완료 후 Actions 실행 화면의 `call-whisper-debug-apk` 아티팩트에서 디버그 APK를 받을 수 있습니다.
