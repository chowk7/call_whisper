#include <jni.h>
#include <atomic>
#include <string>
#include <vector>
#include "whisper.h"

namespace {
std::atomic_bool g_cancelled = false;

void throw_java(JNIEnv * env, const char * message) {
  jclass exception = env->FindClass("java/lang/IllegalStateException");
  env->ThrowNew(exception, message);
}

jobject make_segment(JNIEnv * env, int start_ms, int end_ms, const char * speaker, const char * text) {
  jclass klass = env->FindClass("com/callwhisper/call_whisper/NativeSegment");
  jmethodID constructor = env->GetMethodID(klass, "<init>", "(IILjava/lang/String;Ljava/lang/String;)V");
  jstring speaker_value = env->NewStringUTF(speaker);
  jstring text_value = env->NewStringUTF(text);
  jobject result = env->NewObject(klass, constructor, start_ms, end_ms, speaker_value, text_value);
  env->DeleteLocalRef(speaker_value);
  env->DeleteLocalRef(text_value);
  return result;
}

bool should_abort(void *) { return g_cancelled.load(); }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_callwhisper_call_1whisper_NativeWhisper_transcribe(
    JNIEnv * env, jobject, jstring model_path, jshortArray pcm, jstring language, jboolean diarize) {
  const char * model = env->GetStringUTFChars(model_path, nullptr);
  const char * lang = env->GetStringUTFChars(language, nullptr);
  const jsize samples_count = env->GetArrayLength(pcm);
  std::vector<jshort> pcm16(samples_count);
  env->GetShortArrayRegion(pcm, 0, samples_count, pcm16.data());
  std::vector<float> audio(samples_count);
  for (int i = 0; i < samples_count; ++i) audio[i] = pcm16[i] / 32768.0f;

  whisper_context_params context_params = whisper_context_default_params();
  context_params.use_gpu = true;
  whisper_context * context = whisper_init_from_file_with_params(model, context_params);
  env->ReleaseStringUTFChars(model_path, model);
  env->ReleaseStringUTFChars(language, lang);
  if (context == nullptr) { throw_java(env, "Whisper 모델을 열 수 없습니다."); return nullptr; }

  g_cancelled.store(false);
  whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  params.language = "ko";
  params.n_threads = 4;
  // whisper.cpp TinyDiarize detects speaker-turn boundaries locally. Labels are
  // alternated only at detected turns; users can rename/edit labels in the UI.
  params.tdrz_enable = diarize == JNI_TRUE;
  params.abort_callback = should_abort;
  if (whisper_full(context, params, audio.data(), static_cast<int>(audio.size())) != 0 || g_cancelled.load()) {
    whisper_free(context);
    throw_java(env, g_cancelled.load() ? "전사가 취소되었습니다." : "Whisper 전사에 실패했습니다.");
    return nullptr;
  }

  jclass array_list = env->FindClass("java/util/ArrayList");
  jmethodID init = env->GetMethodID(array_list, "<init>", "()V");
  jmethodID add = env->GetMethodID(array_list, "add", "(Ljava/lang/Object;)Z");
  jobject output = env->NewObject(array_list, init);
  int speaker = 1;
  for (int i = 0; i < whisper_full_n_segments(context); ++i) {
    const int start_ms = static_cast<int>(whisper_full_get_segment_t0(context, i) * 10);
    const int end_ms = static_cast<int>(whisper_full_get_segment_t1(context, i) * 10);
    const std::string speaker_name = "화자 " + std::to_string(speaker);
    jobject segment = make_segment(env, start_ms, end_ms, speaker_name.c_str(), whisper_full_get_segment_text(context, i));
    env->CallBooleanMethod(output, add, segment);
    env->DeleteLocalRef(segment);
    if (diarize == JNI_TRUE && whisper_full_get_segment_speaker_turn_next(context, i)) speaker = speaker == 1 ? 2 : 1;
  }
  whisper_free(context);
  return output;
}

extern "C" JNIEXPORT void JNICALL
Java_com_callwhisper_call_1whisper_NativeWhisper_cancel(JNIEnv *, jobject) {
  g_cancelled.store(true);
}
