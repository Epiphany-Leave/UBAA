//! Initialize Android's system certificate verifier before any HTTPS requests.

use jni::{Env, errors::Error, objects::JObject};

// The JNI macro generates the FFI export and catches panics at the JVM boundary.
#[allow(unsafe_code)]
const _: jni::NativeMethod = jni::native_method! {
    java_type = "cn.edu.ubaa.ubaa_flutter.MainActivity",
    extern fn initialize_tls(context: JObject) -> (),
};

fn initialize_tls<'local>(
    env: &mut Env<'local>,
    _this: JObject<'local>,
    context: JObject<'local>,
) -> Result<(), Error> {
    rustls_platform_verifier::android::init_with_env(env, context)
}
