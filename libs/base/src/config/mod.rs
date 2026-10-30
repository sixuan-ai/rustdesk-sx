pub mod keys;

/// Explicit opt-in: clearing an ID-server address alone falls back to public servers.
pub fn is_direct_only() -> bool {
    hbb_common::config::Config::get_option(keys::OPTION_DIRECT_ONLY) == "Y"
}
