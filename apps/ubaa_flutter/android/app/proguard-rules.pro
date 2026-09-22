# Called from Rust through JNI; R8 cannot discover these references.
-keep, includedescriptorclasses class org.rustls.platformverifier.** { *; }
