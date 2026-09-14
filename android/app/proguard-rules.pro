# ONNX Runtime JNI looks up Java classes by name (e.g. TensorInfo).
# R8 strips them in release unless they are kept.
# https://onnxruntime.ai/docs/build/android.html
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
